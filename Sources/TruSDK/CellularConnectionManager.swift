#if canImport(UIKit)
import UIKit
#else
import Foundation
#endif
import Network

//
// Force connectivity to cellular only
// Open the "check url" and follows all redirects
// Redirect Manager might switch from tls to non-tls between redirects
//
@available(macOS 10.14, *)
@available(iOS 13.0, *)
class CellularConnectionManager {

    let truSdkVersion = "0.0.13"
    private var connection: NWConnection?

    // MARK: - Private utility methods
    private func startConnection(url: URL) {
        let pathMonitor = NWPathMonitor()

        pathMonitor.pathUpdateHandler = { path in
            let interfaceTypes = path.availableInterfaces.map { $0.type }
            for interfaceType in interfaceTypes {
                switch interfaceType {
                case .wifi:
                    print("Path is Wi-Fi")
                case .cellular:
                    print("Path is Cellular ipv4 \(path.supportsIPv4) ipv6 \(path.supportsIPv6)")
                case .wiredEthernet:
                    print("Path is Wired Ethernet")
                case .loopback:
                    print("Path is Loopback")
                case .other:
                    print("Path is other")
                default:
                    print("Path is unknown")
                }
            }
        }

        pathMonitor.start(queue: DispatchQueue(label: "tru.id.monitor"))
        
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = 5 //Secs
        tcpOptions.enableKeepalive = false

        var tlsOptions: NWProtocolTLS.Options?
        var port = NWEndpoint.Port.http
        if (url.scheme!.starts(with:"https")) {
            port = NWEndpoint.Port.https
            tlsOptions = .init()
        }

        TruIDLog(message: "connection scheme \(url.scheme!) \(port)")
        // force network connection to cellular only
        let params = NWParameters(tls: tlsOptions , tcp: tcpOptions)
        params.requiredInterfaceType = .cellular
        params.prohibitExpensivePaths = false
        params.prohibitedInterfaceTypes = [.wifi]
        // create network connection
        connection = NWConnection(host: NWEndpoint.Host(url.host!), port: port, using: params)
        connection?.stateUpdateHandler = { (newState) in
            switch (newState) {
            case .ready:
                TruIDLog(message: "Connection State: Ready \(self.connection.debugDescription)\n")
            case .setup:
                TruIDLog(message: "Connection State: Setup\n")
            case .cancelled:
                TruIDLog(message: "Connection State: Cancelled\n")
            case .preparing:
                TruIDLog(message: "Connection State: Preparing\n")
            default:
                TruIDLog(message: "Connection ERROR State not defined\n")
                self.connection?.cancel()
                break
            }
        }
        // All connection events will be delivered on this queue.
        connection?.start(queue: .main)
    }

    private func sendAndReceive(data: Data, completion: @escaping (URL?) -> Void) {
        self.connection!.send(content: data, completion: NWConnection.SendCompletion.contentProcessed({ (error) in
            if let err = error {
                TruIDLog(message: "Sending error \(err)")
                completion(nil)
            }
        }))
        // only reading the first 4Kb to retreive the Status & Location headers, not interested in the body
        self.connection!.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, error in
            TruIDLog(message: "Receive isComplete: " + isComplete.description)
            if let d = data, !d.isEmpty {
                let r = String(data: d, encoding: .utf8)!
                print(r)
                completion(self.parseRedirect(response: r))
            }
        }
    }
    
    private func parseRedirect(response: String) -> URL? {
        let status = httpStatusCode(response: response)
        TruIDLog(message: "\n----\nparseRedirect status: \(status)")
        if 301...303 ~= status || 307...308 ~= status {
            //header could be named "Location" or "location"
            if let range = response.range(of: #"ocation: (.*)\r\n"#, options: .regularExpression) {
                let location = response[range]
                let redirect = location[location.index(location.startIndex, offsetBy: 9)..<location.index(location.endIndex, offsetBy: -1)]
                return URL(string: String(redirect))
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
    
    private func sendAndReceiveDictionary(data: Data, completion: @escaping ([String : Any]?) -> Void) {
        self.connection!.send(content: data, completion: NWConnection.SendCompletion.contentProcessed({ (error) in
            if let err = error {
                TruIDLog(message: "Sending error \(err)")
                completion(nil)
            }
        }))

        self.connection!.receiveMessage { data, context, isComplete, error in
            TruIDLog(message: "Receive isComplete: " + isComplete.description)
            guard let d = data else {
                TruIDLog(message: "Error: Received nil data")
                completion(nil)
                return
            }
            let response = String(data: d, encoding: .utf8)!
            print(response)
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
                        let json = String(content)
                        let data = json.data(using: .utf8)
                        var dict: [String : Any]? = nil
                        // load JSON response into a dictionary
                        do {
                            if let data = data {
                                dict = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String : Any]
                            }
                        } catch {
                            //TODO: Let's catch
                            TruIDLog(message: "JSON serialisation error: \(error)")
                        }
                        if let dict = dict {
                            print("\(dict)")
                        }
                        return dict
                    }
                }
            }
        }
        
        return nil
    }

    private func httpStatusCode(response: String) -> Int {
        let status = response[response.index(response.startIndex, offsetBy: 9)..<response.index(response.startIndex, offsetBy: 12)]
        return Int(status) ?? 0
    }

}

// MARK: - Internal API
extension CellularConnectionManager: ConnectionManager {

    func openCheckUrl(url: URL, completion: @escaping (Any?) -> Void) {
        TruIDLog(message: "opening \(url.absoluteString)")
        startConnection(url: url)
        let str = createHttpCommand(url: url)
        TruIDLog(message: "sending data:\n\(str)")
        let data: Data? = str.data(using: .utf8)

        sendAndReceive(data: data!) { (result) -> Void in
            if let r = result {
                TruIDLog(message: "redirect found: \(r)")
                self.connection?.cancel()
                self.openCheckUrl(url: r, completion: completion)
            } else {
                TruIDLog(message: "openCheckUrl done")
                self.connection?.cancel()
                completion({})
            }
        }

    }

    func jsonResponse(url: URL, completion: @escaping ([String : Any]?) -> Void)  {
        startConnection(url: url)
        let str = createHttpCommand(url: url)
        TruIDLog(message: "sending data:\n\(str)")

        guard let data = str.data(using: .utf8) else {
            completion(nil)
            return
        }

        sendAndReceiveDictionary(data: data) { (result) -> () in
            completion(result)
        }
    }

    func jsonPropertyValue(for key: String, from url: URL, completion: @escaping (String) -> Void)  {
        startConnection(url: url)
        let str = createHttpCommand(url: url)
        TruIDLog(message: "sending data:\n\(str)")

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

func TruIDLog(message: String) {
    #if DEBUG
    NSLog("[Tru.Id SDK] " + message)
    #endif
}

protocol ConnectionManager {
    func openCheckUrl(url: URL, completion: @escaping (Any?) -> Void)
    func jsonResponse(url: URL, completion: @escaping ([String : Any]?) -> Void)
    func jsonPropertyValue(for key: String, from url: URL, completion: @escaping (String) -> Void)
}


