#if canImport(UIKit)
import UIKit
#else
import Foundation
#endif
import Network
import os

//
// Force connectivity to cellular only
// Open the "check url" and follows all redirects
// CellularConnectionManager might switch from tls to non-tls between redirects
//
@available(macOS 10.14, *)
@available(iOS 13.0, *)
class CellularConnectionManager {

    let traceLog = OSLog(subsystem: "id.tru.sdk", category: "trace")
    //os_log("", log: traceLog, type: .fault, "")

    let truSdkVersion = "0.0.13"
    private var connection: NWConnection?

    //Mitigation for tcp timeout not triggering any events.
    private var timer: Timer?
    private let CONNECTION_TIME_OUT = 20.0
    private var pathMonitor: NWPathMonitor?

    // MARK: - Private utility methods
    private func startConnection(scheme: String, host: String) {
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = 5 //Secs
        tcpOptions.enableKeepalive = false

        var tlsOptions: NWProtocolTLS.Options?
        var port = NWEndpoint.Port.http
        if (scheme.starts(with:"https")) {
            port = NWEndpoint.Port.https
            tlsOptions = .init()
        }
        os_log("connection scheme %s %s", scheme, String(port.rawValue))
        // force network connection to cellular only
        let params = NWParameters(tls: tlsOptions , tcp: tcpOptions)
        params.requiredInterfaceType = .cellular
        params.prohibitExpensivePaths = false
        params.prohibitedInterfaceTypes = [.wifi]
        // create network connection
        connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: params)
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

    private func sendAndReceive(requestUrl: URL, data: Data, completion: @escaping (ConnectionResult<URL, NetworkError>) -> Void) {
        connection?.send(content: data, completion: NWConnection.SendCompletion.contentProcessed({ (error) in
            if let err = error {
                os_log("Sending error %s", type: .error, err.localizedDescription)
                completion(.complete(.other(err.localizedDescription)))

            }
        }))

        // only reading the first 4Kb to retreive the Status & Location headers, not interested in the body
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, context, isComplete, error in

            os_log("Receive isComplete: %s", isComplete.description)
            if let err = error {
                completion(.complete(.other(err.localizedDescription)))
                return
            }

            if let d = data, !d.isEmpty {
                let response = String(data: d, encoding: .utf8)!

                os_log("Response:\n %s", response)

                let status = self.httpStatusCode(response: response)
                os_log("\n----\nHTTP status: %s", String(status))

                switch status {
                case 301...303, 307...308:
                    guard let url = self.parseRedirect(requestUrl: requestUrl, response: response) else {
                        completion(.complete(.invalidRedirectURL))
                        return
                    }
                    completion(.redirect(url))
                case 400...451:
                    completion(.complete(.httpClient("HTTP Client Error:\(status)")))
                case 500...511:
                    completion(.complete(.httpServer("HTTP Server Error:\(status)")))
                case 200...206:
                    completion(.complete(nil))
                default:
                    completion(.complete(.other("HTTP Status can't be parsed \(status)")))
                }
            } else {
                completion(.complete(.noData))
            }
        }
    }
    
    private func parseRedirect(requestUrl: URL, response: String) -> URL? {
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

    private func sendAndReceiveDictionary(data: Data, completion: @escaping ([String : Any]?) -> Void) {
        connection?.send(content: data, completion: NWConnection.SendCompletion.contentProcessed({ (error) in
            if let err = error {
                os_log("Sending error %", type:.error, err.localizedDescription)
                completion(nil)
            }
        }))

        connection?.receiveMessage { data, context, isComplete, error in
            os_log("Receive isComplete: %s", isComplete.description)
            guard let d = data else {
                os_log("Error: Received nil data")
                completion(nil)
                return
            }
            let response = String(data: d, encoding: .utf8)!
            os_log("Response:\n%s", response)
            completion(self.parseJsonResponse(response: response))
        }
    }
    
    private func parseJsonResponse(response: String) -> [String : Any]? {
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

    private func createHttpCommand(url: URL) -> String {
        var cmd = String(format: "GET %@", url.path)

        if (url.query != nil) {
            cmd += String(format:"?%@", url.query!)
        }

        cmd += String(format:" HTTP/1.1\r\nHost: %@", url.host!)
        cmd += " \r\nUser-Agent: tru-sdk-ios/\(truSdkVersion) "
        #if canImport(UIKit)
        cmd += UIDevice.current.systemName + "/" + UIDevice.current.systemVersion
        #elseif os(macOS)
        cmd += "macOS / Unknown"
        #endif
        cmd += "\r\nAccept: */*"
        cmd += "\r\nConnection: close\r\n\r\n"

        return cmd
    }

    private func httpStatusCode(response: String) -> Int {
        let status = response[response.index(response.startIndex, offsetBy: 9)..<response.index(response.startIndex, offsetBy: 12)]
        return Int(status) ?? 0
    }

    func createTimer() {
        if timer != nil {
            timer?.invalidate()
        }

        timer = Timer.scheduledTimer(timeInterval: self.CONNECTION_TIME_OUT,
                                    target: self,
                                    selector: #selector(self.fireTimer),
                                    userInfo: nil, repeats: false)
    }

    @objc func fireTimer() {
        timer?.invalidate()
        connection?.cancel()
    }

    private func startMonitoring() {

        if let monitor = pathMonitor {
            monitor.cancel()
        }

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

    private func stopPathMonitor() {
        if let monitor = pathMonitor {
            monitor.cancel()
            pathMonitor = nil
        }
    }
}

// MARK: - Internal API
extension CellularConnectionManager: ConnectionManager {
    
    func openCheckUrl(url: URL, completion: @escaping (Any?, Error?) -> Void) {
        guard let scheme = url.scheme, let host = url.host else {
            completion(nil, nil)
            return
        }

        os_log("opening %s", url.absoluteString)
        startMonitoring()
        startConnection(scheme: scheme, host: host)
        let command = createHttpCommand(url: url)
        os_log("sending data:\n%s", command)
        let data = command.data(using: .utf8)

        //This method needs to be called after connection state == .ready
        //URL is guaranteed to have host and scheme at this point
        sendAndReceive(requestUrl: url, data: data!) { (result) -> Void in

            switch result {
            case .redirect(let url):
                os_log("redirect found: %s", url.absoluteString)
                self.connection?.cancel()
                self.openCheckUrl(url: url, completion: completion)
            case .complete(let error):
                os_log("openCheckUrl is done")
                self.stopPathMonitor()
                self.connection?.cancel()
                completion(nil, error)
            }

        }

    }

    func jsonResponse(url: URL, completion: @escaping ([String : Any]?) -> Void)  {
        guard let scheme = url.scheme, let host = url.host else {
            completion(nil)
            return
        }

        startConnection(scheme: scheme, host: host)
        let str = createHttpCommand(url: url)
        os_log("sending data:\n", str)

        guard let data = str.data(using: .utf8) else {
            completion(nil)
            return
        }

        sendAndReceiveDictionary(data: data) { (result) -> () in
            completion(result)
        }
    }

    func jsonPropertyValue(for key: String, from url: URL, completion: @escaping (String) -> Void)  {
        guard let scheme = url.scheme, let host = url.host else {
            completion("")
            return
        }

        startConnection(scheme: scheme, host: host)
        let str = createHttpCommand(url: url)
        os_log("sending data:\n", str)

        guard let data = str.data(using: .utf8) else {
            completion("")
            return
        }

        sendAndReceiveDictionary(data: data) { (result) -> () in
            guard let r = result, let value = r[key] as? String else {
                completion("")
                return
            }
            completion(value)
        }
    }
}

protocol ConnectionManager {
    func openCheckUrl(url: URL, completion: @escaping (Any?, Error?) -> Void)
    func jsonResponse(url: URL, completion: @escaping ([String : Any]?) -> Void)
    func jsonPropertyValue(for key: String, from url: URL, completion: @escaping (String) -> Void)
}

enum ConnectionResult<URL, Failure> where Failure: Error {
    case complete(Failure?)
    case redirect(URL)
}

enum NetworkError: Error {
    case invalidRedirectURL
    case tooManyRedirects
    case connectionFailed(String)
    case connectionCantBeCreated(String)
    case noData
    case httpClient(String)
    case httpServer(String)
    case other(String)
}


