#if canImport(UIKit)
import UIKit
#else
import Foundation
#endif
import Network
import os

typealias ResultHandler = (ConnectionResult2<URL, Data, Error>) -> Void
let TruSdkVersion = "0.2.7"
let DEVICE_IP_URL = "https://eu.api.tru.id/public/coverage/v0.1/device_ip"

//
// Force connectivity to cellular only
// Open the "check url" and follows all redirects
// CellularConnectionManager might switch from tls to non-tls between redirects
//
@available(macOS 10.14, *)
@available(iOS 12.0, *)
class CellularConnectionManager: ConnectionManager, InternalAPI {

    private var connection: NWConnection?

    //Mitigation for tcp timeout not triggering any events.
    private var timer: Timer?
    private let CONNECTION_TIME_OUT = 20.0
    private let MAX_REDIRECTS = 10
    private var pathMonitor: NWPathMonitor?
    private var checkResponseHandler: ResultHandler!
    private var debugInfo = DebugInfo()


    lazy var traceCollector: TraceCollector = {
        TraceCollector()
    }()

    // MARK: - New methods
    func check(url: URL, completion: @escaping (Error?) -> Void) {

        guard let _ = url.scheme, let _ = url.host else {
            completion(NetworkError.other("No scheme or host found"))
            return
        }

        var redirectCount = 0
        // This closuser will be called on main thread
        checkResponseHandler = { [weak self] (response) -> Void in

            guard let self = self else {
                completion(NetworkError.other("Unable to carry on"))
                return
            }

            switch response {
            case .follow(let url):
                redirectCount+=1
                if redirectCount <= self.MAX_REDIRECTS {
                    os_log("Redirect found: %s", url.absoluteString)
                    self.traceCollector.addDebug(log: "Redirect found: \(url.absoluteString)")
                    self.traceCollector.addTrace(log: "\nfound redirect: \(url) - \(self.traceCollector.now())")
                    self.createTimer()
                    self.activateConnection(url: url, completion: self.checkResponseHandler)
                } else {
                    self.traceCollector.addDebug(log: "MAX Redirects reached \(String(self.MAX_REDIRECTS))")
                    self.fireTimer()
                }
            case .err(let error):
                if let err = error {
                    self.traceCollector.addDebug(log: "Check completed with \(err.localizedDescription)")
                }
                self.cleanUp()
                completion(error)
            case .dataOK(let data):
                if let json = self.decodeResponse(data:data!) {
                    self.traceCollector.addDebug(log: "json: \(json)\n")
                    self.activateConnectionForDataPatch(url: url, payload: json, completion:self.checkResponseHandler)
                }
            case .dataErr(_):
                os_log("Data err received")
                self.traceCollector.addDebug(log: "Data err received - this method should not be handling data")
            }
        }

        os_log("opening %s", url.absoluteString)
        self.traceCollector.addDebug(log: "url: \(url) - \(self.traceCollector.now())")
        //Initiating on the main thread to synch, as all connection update/state events will also be called on main thread
        DispatchQueue.main.async {
            self.startMonitoring()
            self.createTimer()
            self.activateConnection(url: url, completion: self.checkResponseHandler)
        }

    }
    
    func checkWithTrace(url: URL, completion: @escaping (Error?, TraceInfo?) -> Void) {
        traceCollector.isDebugInfoCollectionEnabled = true
        traceCollector.isConsoleLogsEnabled = true
        traceCollector.startTrace()
        check(url: url) { [weak self] error in
            completion(error, self?.traceCollector.traceInfo())
            self?.traceCollector.stopTrace()
        }
    }

    func isReachable(completion: @escaping (ConnectionResult<URL, ReachabilityDetails, ReachabilityError>) -> Void) {
        let url = URL(string: DEVICE_IP_URL)!

        // This closuser will be called on main thread
        checkResponseHandler = { [weak self] (response) -> Void in

            guard let self = self else {
                completion(.failure(ReachabilityError(type: "Unknown", title: "No Error type", status: -1, detail: "Received an error with no known type")))
                return
            }

            switch response {
            case .follow(_):
                os_log("Unexpected redirect received")
                self.cleanUp()
                completion(.failure(ReachabilityError(type: "HTTP", title: "Redirect", status: 302, detail: "Unexpected Redirect found!")))
            case .err(let error):
                if let err = error {
                    os_log("isReachable completed with %s", err.localizedDescription)
                }
                self.cleanUp()
                completion(.failure(ReachabilityError(type: "Unknown", title: "No Error type", status: -1, detail: "Received an error with no known type")))
            case .dataOK(let data):
                os_log("Data received")
                self.cleanUp()
                do {
                    let model = try JSONDecoder().decode(ReachabilityDetails.self, from: data!)
                    completion(.success(model))
                } catch {
                    completion(.failure(ReachabilityError(type: "Unknown", title: "No Error type", status: -1, detail: "Received an error with no known type")))
                }
            case .dataErr(let data):
                os_log("Data err received")
                self.cleanUp()
                do {
                    let model = try JSONDecoder().decode(ReachabilityDetails.self, from: data!)
                    completion(.success(model))
                } catch {
                    completion(.failure(ReachabilityError(type: "Unknown", title: "No Error type", status: -1, detail: "Received an error with no known type")))
                }
            }

        }

        os_log("opening %s", url.absoluteString)
        //Initiating on the main thread to synch, as all connection update/state events will also be called on main thread
        DispatchQueue.main.async {
            self.startMonitoring()
            self.createTimer()
            self.activateConnectionForDataFetch(url: url, completion: self.checkResponseHandler)
        }
    }
    
    // MARK: - Data fetch
    func jsonResponse(url: URL, completion: @escaping ([String : Any]?) -> Void)  {

        guard let _ = url.scheme, let _ = url.host else {
            completion(nil)
            return
        }

        // This closuser will be called on main thread
        checkResponseHandler = { [weak self] (response) -> Void in

            guard let self = self else {
                completion(nil)
                return
            }

            switch response {
            case .follow(_):
                os_log("Unexpected redirect received")
                self.cleanUp()
                completion(nil)
            case .err(let error):
                if let err = error {
                    os_log("jsonResponse completed with %s", err.localizedDescription)
                }
                self.cleanUp()
                completion(nil)
            case .dataOK(let data):
                os_log("Data received")
                self.cleanUp()
                var dict: [String : Any]?
                do {
                    // load JSON response into a dictionary
                    dict = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as? [String : Any]
                    if let dict = dict {
                        os_log("dict %s",dict.description)
                    }
                } catch {
                    let msg = error.localizedDescription
                    os_log("jsonResponse completed with %s", msg)
                }
                completion(dict)
            case .dataErr(_):
                os_log("Data err received")
                self.cleanUp()
                completion(nil)
            }

        }

        os_log("opening %s", url.absoluteString)
        //Initiating on the main thread to synch, as all connection update/state events will also be called on main thread
        DispatchQueue.main.async {
            self.startMonitoring()
            self.createTimer()
            self.activateConnectionForDataFetch(url: url, completion: self.checkResponseHandler)
        }
    }
    
    func jsonPropertyValue(for key: String, from url: URL, completion: @escaping (String) -> Void)  {
        self.jsonResponse(url: url) { (result) in
            guard let r = result, let value = r[key] as? String else {
                completion("")
                return
            }
            completion(value)
        }
    }

    // MARK: - Internal
    func cancelExistingConnection() {
        if self.connection != nil {
            self.connection?.cancel() // This should trigger a state update
            self.connection = nil
        }
    }
    
    func activateConnection(url: URL, completion: @escaping ResultHandler) {
        self.cancelExistingConnection()

        guard let scheme = url.scheme,
              let host = url.host else {
            completion(.err(NetworkError.other("URL has no Host or Scheme")))
            return
        }

        guard let command = createHttpCommand(url: url),
              let data = command.data(using: .utf8) else {
            completion(.err(NetworkError.other("Unable to create HTTP Request command")))
            return
        }

        self.traceCollector.addDebug(log: "sending data:\n\(command)")
        self.traceCollector.addTrace(log: "\ncommand:\n\(command)")

        connection = createConnection(scheme: scheme, host: host, port: url.port)
        if let connection = connection {
            connection.stateUpdateHandler = createConnectionUpdateHandler(completion: completion, readyStateHandler: { [weak self] in
                self?.sendAndReceive(requestUrl: url, data: data, completion: completion)
            })
            // All connection events will be delivered on the main thread.
            connection.start(queue: .main)
        } else {
            os_log("Problem creating a connection ", url.absoluteString)
            completion(.err(NetworkError.connectionCantBeCreated("Problem creating a connection \(url.absoluteString)")))
        }
    }
    
    func createConnectionUpdateHandler(completion: @escaping ResultHandler, readyStateHandler: @escaping ()-> Void) -> (NWConnection.State) -> Void {
        return { [weak self] (newState) in
            switch (newState) {
            case .setup:
                self?.traceCollector.addDebug(log: "Connection State: Setup\n")
            case .preparing:
                self?.traceCollector.addDebug(log: "Connection State: Preparing\n")
            case .ready:
                let msg = self?.connection.debugDescription ?? "No connection details"
                self?.traceCollector.addDebug(log: "Connection State: Ready \(msg)\n")
                readyStateHandler() //Send and Receive
            case .waiting(let error):
                self?.traceCollector.addDebug(log: "Connection State: Waiting \(error.localizedDescription) \n")
            case .cancelled:
                self?.traceCollector.addDebug(log: "Connection State: Cancelled\n")
            case .failed(let error):
                self?.traceCollector.addDebug(type:.error, log:"Connection State: Failed ->\(error.localizedDescription)")
                completion(.err(error))
            @unknown default:
                self?.traceCollector.addDebug(log: "Connection ERROR State not defined\n")
                completion(.err(NetworkError.other("Connection State: Unknown \(newState)")))
            }
        }
    }

    // MARK: - Utility methods
    func createHttpCommand(url: URL) -> String? {
        guard let host = url.host else {
            return nil
        }

        var cmd = String(format: "GET %@", url.path)

        if let q = url.query {
            cmd += String(format:"?%@", q)
        }

        cmd += String(format:" HTTP/1.1\r\nHost: %@", host)
        cmd += "\r\nUser-Agent: \(debugInfo.userAgent(sdkVersion: TruSdkVersion)) "
        #if canImport(UIKit)
        cmd += UIDevice.current.systemName + "/" + UIDevice.current.systemVersion
        #elseif os(macOS)
        cmd += "macOS / Unknown"
        #endif
        cmd += "\r\nAccept: */*"
        cmd += "\r\nConnection: close\r\n\r\n"

        return cmd
    }
    
    func createConnection(scheme: String, host: String, port: Int? = nil) -> NWConnection? {
        if scheme.isEmpty ||
            host.isEmpty ||
            !(scheme.hasPrefix("http") ||
                scheme.hasPrefix("https")) {
            return nil
        }

        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = 5 //Secs
        tcpOptions.enableKeepalive = false

        var tlsOptions: NWProtocolTLS.Options?
        var fport = (port != nil ? NWEndpoint.Port(integerLiteral: NWEndpoint.Port.IntegerLiteralType(port!)) : NWEndpoint.Port.http)

        if (scheme.starts(with:"https")) {
            fport = (port != nil ? NWEndpoint.Port(integerLiteral: NWEndpoint.Port.IntegerLiteralType(port!)) : NWEndpoint.Port.https)
            tlsOptions = .init()
            tcpOptions.enableFastOpen = true //Save on tcp round trip by using first tls packet
        }

        self.traceCollector.addTrace(log: "Start connection \(host) \(fport.rawValue) \(scheme) \(self.traceCollector.now())\n")
        self.traceCollector.addDebug(log: "connection scheme \(scheme) \(String(fport.rawValue))")
        let params = NWParameters(tls: tlsOptions , tcp: tcpOptions)
        params.serviceClass = .responsiveData
        // force network connection to cellular only
        params.requiredInterfaceType = .cellular
        params.prohibitExpensivePaths = false
        params.prohibitedInterfaceTypes = [.wifi]

        connection = NWConnection(host: NWEndpoint.Host(host), port: fport, using: params)

        return connection
    }

    func httpStatusCode(response: String) -> Int {
        let status = response[response.index(response.startIndex, offsetBy: 9)..<response.index(response.startIndex, offsetBy: 12)]
        return Int(status) ?? 0
    }
    
    /// Decodes a response, first attempting with UTF8 and then fallback to ascii
    /// - Parameter data: Data which contains the response
    /// - Returns: decoded response as String
    func decodeResponse(data: Data) -> String? {
        guard let response = String(data: data, encoding: .utf8) else {
            return String(data: data, encoding: .ascii)
        }
        return response
    }

    func parseRedirect(requestUrl: URL, response: String) -> URL? {
        guard let _ = requestUrl.host else {
            return nil
        }
        //header could be named "Location" or "location"
        if let range = response.range(of: #"ocation: (.*)\r\n"#, options: .regularExpression) {
            let location = response[range]
            let redirect = location[location.index(location.startIndex, offsetBy: 9)..<location.index(location.endIndex, offsetBy: -1)]
            // some location header are not properly encoded
            let cleanRedirect = redirect.replacingOccurrences(of: " ", with: "+")
            if let redirectURL =  URL(string: String(cleanRedirect)) {
                return redirectURL.host == nil ? URL(string: redirectURL.path, relativeTo: requestUrl) : redirectURL
            } else {
                self.traceCollector.addDebug(log: "URL malformed \(cleanRedirect)")
                return nil
            }
        }
        return nil
    }

    func createTimer() {

        if let timer = self.timer, timer.isValid {
            os_log("Invalidating the existing timer", type: .debug)
            timer.invalidate()
        }

        os_log("Starting a new timer", type: .debug)
        self.timer = Timer.scheduledTimer(timeInterval: self.CONNECTION_TIME_OUT,
                                          target: self,
                                          selector: #selector(self.fireTimer),
                                          userInfo: nil,
                                          repeats: false)
    }

    @objc func fireTimer() {
        self.traceCollector.addDebug(log: "Connection time out.")
        timer?.invalidate()
        checkResponseHandler(.err(NetworkError.other("Connection cancelled - either due to time out, or MAX Redirect reached")))
    }

    func startMonitoring() {

        if let monitor = pathMonitor { monitor.cancel() }

        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { path in
            let interfaceTypes = path.availableInterfaces.map { $0.type }
            for interfaceType in interfaceTypes {
                switch interfaceType {
                case .wifi:
                    self.traceCollector.addDebug(log: "Path is Wi-Fi")

                case .cellular:
                    self.traceCollector.addDebug(log: "Path is Cellular ipv4 \(path.supportsIPv4.description) ipv6 \(path.supportsIPv6.description)")

                case .wiredEthernet:
                    self.traceCollector.addDebug(log: "Path is Wired Ethernet")

                case .loopback:
                    self.traceCollector.addDebug(log: "Path is Loopback")

                case .other:
                    self.traceCollector.addDebug(log: "Path is other")

                default:
                    self.traceCollector.addDebug(log: "Path is unknown")

                }
            }
        }

        pathMonitor?.start(queue: .main)
    }

    func stopMonitoring() {
        if let monitor = pathMonitor {
            monitor.cancel()
            pathMonitor = nil
        }
    }

    func cleanUp() {
        self.traceCollector.addDebug(log: "Performing clean-up.")

        self.timer?.invalidate()
        self.stopMonitoring()
        self.cancelExistingConnection()
    }

    // NEW - BEGIN
    func activateConnectionForDataPatch(url: URL, payload: String,  completion: @escaping ResultHandler) {
        self.cancelExistingConnection()
        guard let scheme = url.scheme,
              let host = url.host else {
            completion(.err(NetworkError.other("URL has no Host or Scheme")))
            return
        }

        guard let command = createHttpPatchCommand(url: url, payload:payload),
              let data = command.data(using: .utf8) else {
            completion(.err(NetworkError.other("Unable to create HTTP Request command")))
            return
        }

        self.traceCollector.addDebug(log: "sending data:\n\(command)")
        self.traceCollector.addTrace(log: "\ncommand:\n\(command)")

        connection = createConnection(scheme: scheme, host: host, port: url.port)
        if let connection = connection {
            connection.stateUpdateHandler = createConnectionUpdateHandler(completion: completion, readyStateHandler: { [weak self] in
                self?.sendAndReceive(requestUrl: url, data: data, completion: completion)
            })
            // All connection events will be delivered on the main thread.
            connection.start(queue: .main)
        } else {
            os_log("Problem creating a connection ", url.absoluteString)
            completion(.err(NetworkError.connectionCantBeCreated("Problem creating a connection \(url.absoluteString)")))
        }
    }
    
    func createHttpPatchCommand(url: URL, payload:String) -> String? {
        guard let host = url.host else {
            return nil
        }

        var cmd = String(format: "PATCH %@", url.path)

        if let q = url.query {
            cmd += String(format:"?%@", q)
        }
    
        let body = "[{\"op\": \"add\",\"path\":\"/payload\",\"value\": \(payload) }]"

        cmd += String(format:" HTTP/1.1\r\nHost: %@", host)
        cmd += "\r\nUser-Agent: tru-sdk-ios/\(debugInfo.userAgent(sdkVersion: TruSdkVersion)) "
        #if canImport(UIKit)
        cmd += UIDevice.current.systemName + "/" + UIDevice.current.systemVersion
        #elseif os(macOS)
        cmd += "macOS / Unknown"
        #endif
        cmd += "\r\nAccept: */*"
        cmd += "\r\nContent-Type: application/json-patch+json"
        cmd += "\r\nContent-Length: \(body.count)\r\n"
        cmd += "\r\n" + body
        return cmd
    }

    // NEW - END

    func sendAndReceive(requestUrl: URL, data: Data, completion: @escaping ResultHandler) {
        connection?.send(content: data, completion: NWConnection.SendCompletion.contentProcessed({ (error) in
            if let err = error {
                self.traceCollector.addDebug(type: .error, log: "Sending error \(err.localizedDescription)")
                self.traceCollector.addTrace(log:"send: error \(err.localizedDescription) - \(self.traceCollector.now())")
                completion(.err(err))
            }
        }))

        // only reading the first 4Kb to retreive the Status & Location headers, not interested in the body
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, context, isComplete, error in

            self.traceCollector.addDebug(log: "Receive isComplete: \(isComplete.description)")

            self.traceCollector.addTrace(log:"\nreceive: complete \(String(describing: isComplete.description)) - \(self.traceCollector.now())")
            if let err = error {
                self.traceCollector.addTrace(log:"receive: error \(err.localizedDescription) - \(self.traceCollector.now())")
                completion(.err(err))
                return
            }

            if let d = data, !d.isEmpty, let response = self.decodeResponse(data: d) {

                self.traceCollector.addDebug(log: "Response:\n \(response)")
                self.traceCollector.addTrace(log:"\nresponse:\n\(String(describing: response))")

                let status = self.httpStatusCode(response: response)
                self.traceCollector.addDebug(log: "\n----\nHTTP status: \(String(status))")

                self.traceCollector.addTrace(log:"receive: status \(status) - \(self.traceCollector.now())")

                switch status {
                case 200: // NEW
                    if let payload = self.getResponseBody(response: response){
                        completion(.dataOK(payload))
                        return
                    }
                    completion(.err(nil))
                case 301...303, 307...308:
                    guard let url = self.parseRedirect(requestUrl: requestUrl, response: response) else {
                        completion(.err(NetworkError.invalidRedirectURL("Invalid URL - unable to parseRecirect")))
                        return
                    }
                    completion(.follow(url))
                case 400...451:
                    completion(.err(NetworkError.httpClient("HTTP Client Error:\(status)")))
                case 500...511:
                    completion(.err(NetworkError.httpServer("HTTP Server Error:\(status)")))
                case 201...206:
                    completion(.err(nil))
                default:
                    completion(.err(NetworkError.other("HTTP Status can't be parsed \(status)")))
                }
            } else {
                self.traceCollector.addTrace(log:"receive: no data - \(self.traceCollector.now())")
                completion(.err(NetworkError.noData("Response has no data or corrupt")))
            }
        }
    }

    // UPDATED to use sendAndReceiveWithBody
    func activateConnectionForDataFetch(url: URL, completion: @escaping ResultHandler) {
        self.cancelExistingConnection()
        guard let scheme = url.scheme,
              let host = url.host else {
            completion(.err(NetworkError.other("URL has no Host or Scheme")))
            return
        }

        guard let command = createHttpCommand(url: url),
              let data = command.data(using: .utf8) else {
            completion(.err(NetworkError.other("Unable to create HTTP Request command")))
            return
        }

        self.traceCollector.addDebug(log: "sending data:\n\(command)")
        self.traceCollector.addTrace(log: "\ncommand:\n\(command)")

        connection = createConnection(scheme: scheme, host: host, port: url.port)
        if let connection = connection {
            connection.stateUpdateHandler = createConnectionUpdateHandler(completion: completion, readyStateHandler: { [weak self] in
                self?.sendAndReceiveWithBody(requestUrl: url, data: data, completion: completion)
            })
            // All connection events will be delivered on the main thread.
            connection.start(queue: .main)
        } else {
            os_log("Problem creating a connection ", url.absoluteString)
            completion(.err(NetworkError.connectionCantBeCreated("Problem creating a connection \(url.absoluteString)")))
        }
    }

    // NEW
    func sendAndReceiveWithBody(requestUrl: URL, data: Data,  completion: @escaping ResultHandler) {
        connection?.send(content: data, completion: NWConnection.SendCompletion.contentProcessed({ (error) in
            if let err = error {
                os_log("Sending error %s", type: .error, err.localizedDescription)
                completion(.err(err))

            }
        }))

        //Read the entire response body
        connection?.receiveMessage { data, context, isComplete, error in

            os_log("Receive isComplete: %s", isComplete.description)
            if let err = error {
                completion(.err(err))
                return
            }

            if let d = data, !d.isEmpty, let response = self.decodeResponse(data: d) {

                os_log("Response:\n %s", response)

                let status = self.httpStatusCode(response: response)
                os_log("\n----\nHTTP status: %s", String(status))

                switch status {
                case 301...303, 307...308:
                    completion(.err(NetworkError.other("Unexpected HTTP Status\(status)")))
                case 400...451:
                    if let r = self.getResponseBody(response: response) {
                        completion(.dataErr(r))
                    } else {
                        completion(.err(NetworkError.other("HTTP Status can't be parsed \(status)")))
                    }
                case 500...511:
                    if let r = self.getResponseBody(response: response) {
                        completion(.dataErr(r))
                    } else {
                        completion(.err(NetworkError.other("HTTP Status can't be parsed \(status)")))
                    }
                case 200...206:
                    if let r = self.getResponseBody(response: response) {
                        completion(.dataOK(r))
                    } else {
                        completion(.err(NetworkError.other("HTTP Status can't be parsed \(status)")))
                    }
                default:
                    completion(.err(NetworkError.other("HTTP Status can't be parsed \(status)")))
                }
            } else {
                completion(.err(NetworkError.noData("Response has no data or corrupt")))
            }
        }
    }
    
    func getResponseBody(response: String) -> Data? {
        if let rangeContentType = response.range(of: #"Content-Type: (.*)\r\n"#, options: .regularExpression) {
            // retrieve content type
            let contentType = response[rangeContentType]
            let type = contentType[contentType.index(contentType.startIndex, offsetBy: 9)..<contentType.index(contentType.endIndex, offsetBy: -1)]
            if (type.contains("application/json") || type.contains("application/hal+json")) {
                if let range = response.range(of: "\r\n\r\n") {
                    if let rangeTransferEncoding = response.range(of: #"Transfer-Encoding: chunked\r\n"#, options: .regularExpression) {
                        if (!rangeTransferEncoding.isEmpty) {
                            if let r1 = response.range(of: "\r\n\r\n") , let r2 = response.range(of:"\r\n0\r\n") {
                                let c = response[r1.upperBound..<r2.lowerBound]
                                if let start = c.firstIndex(of: "{") {
                                    let json = c[start..<c.index(c.endIndex, offsetBy: 0)]
                                    os_log("json: [%s]",  String(json))
                                    let jsonString = String(json)
                                    os_log("jsonString: [%s]", jsonString)
                                    guard let data = jsonString.data(using: .utf8) else {
                                        return nil
                                    }
                                    return data
                                }
                            }
                        }
                    }
                    let content = response[range.upperBound..<response.index(response.endIndex, offsetBy: 0)]
                    if let start = content.firstIndex(of: "{") {
                        let json = content[start..<response.index(response.endIndex, offsetBy: 0)]
                        os_log("json: [%s]",  String(json))
                        let jsonString = String(json)
                        os_log("jsonString: [%s]", jsonString)
                        guard let data = jsonString.data(using: .utf8) else {
                            return nil
                        }
                        return data
                    }
                }
            }
        }
        return nil
    }

    // MARK: deprecated
    func openCheckUrl(url: URL, completion: @escaping (Any?, Error?) -> Void) {
        check(url: url) { (error) in
            completion("", error)
        }
    }

}

protocol InternalAPI {
    func parseRedirect(requestUrl: URL, response: String) -> URL?
    func sendAndReceiveWithBody(requestUrl: URL, data: Data,  completion: @escaping ResultHandler)
    func createHttpCommand(url: URL) -> String?
    func startMonitoring()
    func stopMonitoring()
}

// MARK: - Internal API
protocol ConnectionManager {
    func check(url: URL, completion: @escaping (Error?) -> Void)
    func checkWithTrace(url: URL, completion: @escaping (Error?, TraceInfo?) -> Void)
    func isReachable(completion: @escaping (ConnectionResult<URL, ReachabilityDetails, ReachabilityError>) -> Void)

    //The following methods are deprecated
    func openCheckUrl(url: URL, completion: @escaping (Any?, Error?) -> Void)
    func jsonResponse(url: URL, completion: @escaping ([String : Any]?) -> Void)
    func jsonPropertyValue(for key: String, from url: URL, completion: @escaping (String) -> Void)
}

//NEW
enum ConnectionResult2<URL, Data, Failure> where Failure: Error {
    case err(Failure?)
    case dataOK(Data?)
    case dataErr(Data?)
    case follow(URL)
}

enum ConnectionResult<URL, Data, Failure> where Failure: Error {
    case failure(Failure?)
    case success(Data?)
}


enum NetworkError: Error, Equatable {
    case invalidRedirectURL(String)
    case tooManyRedirects
    case connectionFailed(String)
    case connectionCantBeCreated(String)
    case noData(String)
    case httpClient(String)
    case httpServer(String)
    case other(String)
}


