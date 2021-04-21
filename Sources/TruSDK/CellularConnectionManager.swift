#if canImport(UIKit)
import UIKit
#else
import Foundation
#endif
import Network
import os

typealias ResultHandler = (ConnectionResult<URL, [String : Any], Error>) -> Void
//
// Force connectivity to cellular only
// Open the "check url" and follows all redirects
// CellularConnectionManager might switch from tls to non-tls between redirects
//
@available(macOS 10.14, *)
@available(iOS 13.0, *)
class CellularConnectionManager: ConnectionManager, InternalAPI {

    let traceLog = OSLog(subsystem: "id.tru.sdk", category: "trace")
    //os_log("", log: traceLog, type: .fault, "")

    let truSdkVersion = "0.1.1"
    var connection: NWConnection?

    //Mitigation for tcp timeout not triggering any events.
    private var timer: Timer?
    private let CONNECTION_TIME_OUT = 20.0
    private let MAX_REDIRECTS = 10
    private var pathMonitor: NWPathMonitor?
    private var checkResponseHandler: ResultHandler!

    // MARK: - New methods
    func check(url: URL, completion: @escaping (Error?) -> Void) {

        guard let _ = url.scheme, let _ = url.host else {
            completion(NetworkError.other("No scheme or host found"))
            return
        }

        var redirectCount = 0
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
                    self.createTimer()
                    self.activateConnection(url: url, completion: self.checkResponseHandler)
                } else {
                    os_log("MAX Redirects reached %s", String(self.MAX_REDIRECTS))
                    self.fireTimer()
                }
            case .complete(let error):
                if let err = error {
                    os_log("Check completed with %s", err.localizedDescription)
                }
                self.cleanUp()
                completion(error)
            case .data(_):
                //ignore, check method is not fetching for data
                os_log("Data received - this method should not be handling data")
            }

        }

        os_log("opening %s", url.absoluteString)
        self.startMonitoring()
        self.createTimer()
        activateConnection(url: url, completion: checkResponseHandler)

    }

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
            completion(.complete(NetworkError.other("URL has no Host or Scheme")))
            return
        }

        guard let command = createHttpCommand(url: url),
              let data = command.data(using: .utf8) else {
            completion(.complete(NetworkError.other("Unable to create HTTP Request command")))
            return
        }

        os_log("sending data:\n%s", command)

        connection = createConnection(scheme: scheme, host: host)
        if let connection = connection {
            connection.stateUpdateHandler = createConnectionUpdateHandler(completion: completion, readyStateHandler: { [weak self] in
                self?.sendAndReceive(requestUrl: url, data: data, completion: completion)
            })
            // All connection events will be delivered on this queue.
            connection.start(queue: .main)
        } else {
            os_log("Problem creating a connection ", url.absoluteString)
            completion(.complete(NetworkError.connectionCantBeCreated("Problem creating a connection \(url.absoluteString)")))
        }
    }

    func createConnectionUpdateHandler(completion: @escaping ResultHandler, readyStateHandler: @escaping ()-> Void) -> (NWConnection.State) -> Void {
        return { [weak self] (newState) in
            switch (newState) {
            case .setup:
                os_log("Connection State: Setup\n")
            case .preparing:
                os_log("Connection State: Preparing\n")
            case .ready:
                os_log("Connection State: Ready %s\n", self?.connection.debugDescription ?? "No connection details")
                readyStateHandler() //Send and Receive
            case .waiting(let error):
                os_log("Connection State: Waiting %s \n", error.localizedDescription)
            case .cancelled:
                os_log("Connection State: Cancelled\n")
            case .failed(let error):
                os_log("Connection State: Failed ->%s", type:.error, error.localizedDescription)
                completion(.complete(error))
            @unknown default:
                os_log("Connection ERROR State not defined\n")
                completion(.complete(NetworkError.other("Connection State: Unknown \(newState)")))
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
        cmd += "\r\nUser-Agent: tru-sdk-ios/\(truSdkVersion) "
        #if canImport(UIKit)
        cmd += UIDevice.current.systemName + "/" + UIDevice.current.systemVersion
        #elseif os(macOS)
        cmd += "macOS / Unknown"
        #endif
        cmd += "\r\nAccept: */*"
        cmd += "\r\nConnection: close\r\n\r\n"

        return cmd
    }

    func createConnection(scheme: String, host: String) -> NWConnection? {
        if scheme.isEmpty || host.isEmpty ||
            !(scheme.hasPrefix("http") || scheme.hasPrefix("https")) {
            return nil
        }

        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = 5 //Secs
        tcpOptions.enableKeepalive = false

        var tlsOptions: NWProtocolTLS.Options?
        var port = NWEndpoint.Port.http

        if (scheme.starts(with:"https")) {
            port = NWEndpoint.Port.https
            tlsOptions = .init()
            tcpOptions.enableFastOpen = true //Save on tcp round trip by using first tls packet
        }

        os_log("connection scheme %s %s", scheme, String(port.rawValue))
        let params = NWParameters(tls: tlsOptions , tcp: tcpOptions)
        params.serviceClass = .responsiveData
        // force network connection to cellular only
        params.requiredInterfaceType = .cellular
        params.prohibitExpensivePaths = false
        params.prohibitedInterfaceTypes = [.wifi]

        connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: params)

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
            if let redirectURL =  URL(string: String(redirect)) {
                return redirectURL.host == nil ? URL(string: redirectURL.path, relativeTo: requestUrl) : redirectURL
            } else {
                return nil
            }
        }
        return nil
    }

    func createTimer() {
        if let timer = timer, timer.isValid {
            os_log("Invalidating the existing timer", type: .debug)
            timer.invalidate()
        }

        os_log("Starting a new timer", type: .debug)
        timer = Timer.scheduledTimer(timeInterval: self.CONNECTION_TIME_OUT,
                                    target: self,
                                    selector: #selector(self.fireTimer),
                                    userInfo: nil,
                                    repeats: false)
    }

    @objc func fireTimer() {
        os_log("Connection time out.", type: .debug)
        timer?.invalidate()
        checkResponseHandler(.complete(NetworkError.other("Connection cancelled - either due to time out, or MAC Redirect reached")))
    }

    func startMonitoring() {

        if let monitor = pathMonitor { monitor.cancel() }

        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { path in
            let interfaceTypes = path.availableInterfaces.map { $0.type }
            for interfaceType in interfaceTypes {
                switch interfaceType {
                case .wifi:
                    os_log("Path is Wi-Fi")
                case .cellular:
                    os_log("Path is Cellular ipv4 %s ipv6 %s", path.supportsIPv4.description, path.supportsIPv6.description)
                case .wiredEthernet:
                    os_log("Path is Wired Ethernet")
                case .loopback:
                    os_log("Path is Loopback")
                case .other:
                    os_log("Path is other")
                default:
                    os_log("Path is unknown")
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
        os_log("Performing clean-up.")
        self.timer?.invalidate()
        self.stopMonitoring()
        self.cancelExistingConnection()
    }

    func sendAndReceive(requestUrl: URL, data: Data, completion: @escaping ResultHandler) {
        connection?.send(content: data, completion: NWConnection.SendCompletion.contentProcessed({ (error) in
            if let err = error {
                os_log("Sending error %s", type: .error, err.localizedDescription)
                completion(.complete(err))

            }
        }))

        // only reading the first 4Kb to retreive the Status & Location headers, not interested in the body
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, context, isComplete, error in

            os_log("Receive isComplete: %s", isComplete.description)
            if let err = error {
                completion(.complete(err))
                return
            }

            if let d = data, !d.isEmpty, let response = self.decodeResponse(data: d) {

                os_log("Response:\n %s", response)

                let status = self.httpStatusCode(response: response)
                os_log("\n----\nHTTP status: %s", String(status))

                switch status {
                case 301...303, 307...308:
                    guard let url = self.parseRedirect(requestUrl: requestUrl, response: response) else {
                        completion(.complete(NetworkError.invalidRedirectURL("Invalid URL - unable to parseRecirect")))
                        return
                    }
                    completion(.follow(url))
                case 400...451:
                    completion(.complete(NetworkError.httpClient("HTTP Client Error:\(status)")))
                case 500...511:
                    completion(.complete(NetworkError.httpServer("HTTP Server Error:\(status)")))
                case 200...206:
                    completion(.complete(nil))
                default:
                    completion(.complete(NetworkError.other("HTTP Status can't be parsed \(status)")))
                }
            } else {
                completion(.complete(NetworkError.noData("Response has no data or corrupt")))
            }
        }
    }

    // MARK: - Data fetch
    /// Quite similar to check(..)
    func jsonResponse(url: URL, completion: @escaping ([String : Any]?) -> Void)  {

        guard let _ = url.scheme, let _ = url.host else {
            completion(nil)
            return
        }

        var redirectCount = 0
        checkResponseHandler = { [weak self] (response) -> Void in

            guard let self = self else {
                completion(nil)
                return
            }

            switch response {
            case .follow(let url):
                redirectCount+=1
                if redirectCount <= self.MAX_REDIRECTS {
                    os_log("Redirect found: %s", url.absoluteString)
                    self.createTimer()
                    self.activateConnectionForDataFetch(url: url, completion: self.checkResponseHandler)
                } else {
                    os_log("MAX Redirects reached %s", String(self.MAX_REDIRECTS))
                    self.fireTimer()
                }
            case .complete(let error):
                if let err = error {
                    os_log("Check completed with %s", err.localizedDescription)
                }
                self.cleanUp()
                completion(nil)
            case .data(let data):
                os_log("Data received")
                self.cleanUp()
                completion(data)
            }

        }

        os_log("opening %s", url.absoluteString)
        self.startMonitoring()
        self.createTimer()
        activateConnectionForDataFetch(url: url, completion: checkResponseHandler)
    }

    /// Quite similar to activateConnection(..)
    func activateConnectionForDataFetch(url: URL, completion: @escaping ResultHandler) {
        self.cancelExistingConnection()
        guard let scheme = url.scheme,
              let host = url.host else {
            completion(.complete(NetworkError.other("URL has no Host or Scheme")))
            return
        }

        guard let command = createHttpCommand(url: url),
              let data = command.data(using: .utf8) else {
            completion(.complete(NetworkError.other("Unable to create HTTP Request command")))
            return
        }

        os_log("sending data:\n%s", command)

        connection = createConnection(scheme: scheme, host: host)
        if let connection = connection {
            connection.stateUpdateHandler = createConnectionUpdateHandler(completion: completion, readyStateHandler: { [weak self] in
                self?.sendAndReceiveDictionary(requestUrl: url, data: data, completion: completion)
            })
            // All connection events will be delivered on this queue.
            connection.start(queue: .main)
        } else {
            os_log("Problem creating a connection ", url.absoluteString)
            completion(.complete(NetworkError.connectionCantBeCreated("Problem creating a connection \(url.absoluteString)")))
        }
    }

    /// Quite similar to sendAndReceiveDictionary
    func sendAndReceiveDictionary(requestUrl: URL, data: Data,  completion: @escaping ResultHandler) {
        connection?.send(content: data, completion: NWConnection.SendCompletion.contentProcessed({ (error) in
            if let err = error {
                os_log("Sending error %s", type: .error, err.localizedDescription)
                completion(.complete(err))

            }
        }))

        //Read the entire response body of if 200
        connection?.receiveMessage { data, context, isComplete, error in

            os_log("Receive isComplete: %s", isComplete.description)
            if let err = error {
                completion(.complete(err))
                return
            }

            if let d = data, !d.isEmpty, let response = self.decodeResponse(data: d) {

                os_log("Response:\n %s", response)

                let status = self.httpStatusCode(response: response)
                os_log("\n----\nHTTP status: %s", String(status))

                switch status {
                case 301...303, 307...308:
                    guard let url = self.parseRedirect(requestUrl: requestUrl, response: response) else {
                        completion(.complete(NetworkError.invalidRedirectURL("Invalid URL - unable to parseRecirect")))
                        return
                    }
                    completion(.follow(url))
                case 400...451:
                    completion(.complete(NetworkError.httpClient("HTTP Client Error:\(status)")))
                case 500...511:
                    completion(.complete(NetworkError.httpServer("HTTP Server Error:\(status)")))
                case 200...206:
                    let dict = self.parseJsonResponse(response: response)
                    completion(.data(dict))
                default:
                    completion(.complete(NetworkError.other("HTTP Status can't be parsed \(status)")))
                }
            } else {
                completion(.complete(NetworkError.noData("Response has no data or corrupt")))
            }
        }
    }

    func parseJsonResponse(response: String) -> [String : Any]? {
        let status = httpStatusCode(response: response)
        // check HTTP status
        if (status == 200) {
            if let rangeContentType = response.range(of: #"Content-Type: (.*)\r\n"#, options: .regularExpression) {
                // retrieve content type
                let contentType = response[rangeContentType]
                let type = contentType[contentType.index(contentType.startIndex, offsetBy: 9)..<contentType.index(contentType.endIndex, offsetBy: -1)]
                if (type.contains("application/json")) {
                    // retrieve content
                    if let range = response.range(of: "\r\n\r\n") {
                        let content = response[range.upperBound..<response.index(response.endIndex, offsetBy: 0)]
                        let jsonString = String(content)
                        var dict: [String : Any]?
                        guard let data = jsonString.data(using: .utf8) else {
                            return nil
                        }
                        do {
                            // load JSON response into a dictionary
                            dict = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String : Any]
                            if let dict = dict {
                                os_log("Dictionary: %s", dict.description)
                            }
                        } catch {
                            let msg = error.localizedDescription
                            os_log("JSON serialisation error: %s", type:.error, msg)
                        }
                        return dict
                    }
                }
            }
        }

        return nil
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

    // MARK: - Soon to be deprecated
    func openCheckUrl(url: URL, completion: @escaping (Any?, Error?) -> Void) {

        guard let scheme = url.scheme, let host = url.host else {
            completion(nil, NetworkError.other("No scheme or host found"))
            return
        }

        os_log("opening %s", url.absoluteString)
        startMonitoring()
        startConnection(scheme: scheme, host: host)

        guard let command = createHttpCommand(url: url),
              let data = command.data(using: .utf8) else {
            completion(nil, NetworkError.other("Unable to create HTTP Request command"))
            return
        }

        os_log("sending data:\n%s", command)

        let responseHandler: ResultHandler = { [weak self] (result) -> Void in

            guard let self = self else {
                completion(nil, NetworkError.other("Unable to carry on"))
                return
            }

            self.stopMonitoring()
            self.connection?.cancel()

            switch result {
            case .follow(let url):
                os_log("redirect found: %s", url.absoluteString)
                self.openCheckUrl(url: url, completion: completion)
            case .complete(let error):
                os_log("openCheckUrl is done")
                completion(nil, error)
            case .data(_):
                os_log("data received")
            }

        }

        //This method needs to be called after connection state == .ready
        //URL is guaranteed to have host and scheme at this point
        sendAndReceive(requestUrl: url, data: data, completion: responseHandler)

    }

    func startConnection(scheme: String, host: String) {
        connection = createConnection(scheme: scheme, host: host)
        connection?.stateUpdateHandler = { [weak self] (newState) in
            switch (newState) {
            case .ready:
                os_log("Connection State: Ready %s\n", self?.connection.debugDescription ?? "No connection details")
            case .setup:
                os_log("Connection State: Setup\n")
            case .cancelled:
                os_log("Connection State: Cancelled\n")
            case .preparing:
                os_log("Connection State: Preparing\n")
                self?.createTimer()
            case .failed(let error):
                os_log("Connection State: Failed ->%s", type:.error, error.localizedDescription)
                self?.connection?.cancel()
            default:
                os_log("Connection ERROR State not defined\n")
                self?.connection?.cancel()
                break
            }
        }
        // All connection events will be delivered on this queue.
        connection?.start(queue: .main)
    }

}

protocol InternalAPI {
    func startConnection(scheme: String, host: String)
    func sendAndReceive(requestUrl: URL, data: Data, completion: @escaping (ConnectionResult<URL,[String:Any], Error>) -> Void)
    func parseRedirect(requestUrl: URL, response: String) -> URL?
    func sendAndReceiveDictionary(requestUrl: URL, data: Data,  completion: @escaping ResultHandler)
    func parseJsonResponse(response: String) -> [String : Any]?
    func createHttpCommand(url: URL) -> String?
    func startMonitoring()
    func stopMonitoring()
}

// MARK: - Internal API
protocol ConnectionManager {
    func check(url: URL, completion: @escaping (Error?) -> Void)
    func openCheckUrl(url: URL, completion: @escaping (Any?, Error?) -> Void)
    func jsonResponse(url: URL, completion: @escaping ([String : Any]?) -> Void)
    func jsonPropertyValue(for key: String, from url: URL, completion: @escaping (String) -> Void)
}

enum ConnectionResult<URL, Data, Failure> where Failure: Error {
    case complete(Failure?)
    case data(Data?)
    case follow(URL)
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


