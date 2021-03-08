import Foundation
import Network
import UIKit


//
// Force connectivity to cellular only
// Open the "check url" and follows all redirects
// we might switch from tls to non-tls between redirects
//
@available(OSX 10.14, *)
@available(iOS 12.0, *)
class RedirectManager {
        
    var truSdkVersion = "0.0.11"
    var connection: NWConnection?
    
    private func startConnection(url: URL) {
        let pathMonitor = NWPathMonitor()
        pathMonitor.pathUpdateHandler = { path in
            if path.usesInterfaceType(.wifi) {
                print("Path is Wi-Fi")
            } else if path.usesInterfaceType(.cellular) {
                print("Path is Cellular ipv4 \(path.supportsIPv4) ipv6 \(path.supportsIPv6)")
            } else if path.usesInterfaceType(.wiredEthernet) {
                print("Path is Wired Ethernet")
            } else if path.usesInterfaceType(.loopback) {
                print("Path is Loopback")
            } else if path.usesInterfaceType(.other) {
                print("Path is other")
            }
        }
        pathMonitor.start(queue: .main)
        
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = 5
        tcpOptions.enableKeepalive = false

        var tlsOptions: NWProtocolTLS.Options?
        var port = NWEndpoint.Port.http
        if (url.scheme!.starts(with:"https")) {
            port = NWEndpoint.Port.https
            tlsOptions = .init()
        }
        NSLog("connection scheme \(url.scheme!) \(port)")
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
                    NSLog("Connection State: Ready \(self.connection.debugDescription)\n")
                case .setup:
                    NSLog("Connection State: Setup\n")
                case .cancelled:
                    NSLog("Connection State: Cancelled\n")
                case .preparing:
                    NSLog("Connection State: Preparing\n")
                default:
                    NSLog("Connection ERROR State not defined\n")
                    self.connection?.cancel()
                    break
            }
        }
        connection?.start(queue: .main)
    }

    private func sendAndReceive(data: Data, completion: @escaping (String?) -> ()) {
        self.connection!.send(content: data, completion: NWConnection.SendCompletion.contentProcessed({ (error) in
            if let err = error {
                NSLog("Sending error \(err)")
            }
        }))
        // only reading the first 4Kb to retreive the Status & Location headers, not interested in the body
        self.connection!.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, error in
            NSLog("Receive isComplete: " + isComplete.description)
            if let d = data, !d.isEmpty {
                let r = String(data: d, encoding: .utf8)!
                print(r)
                completion(self.parseRedirect(response: r))
            }
        }
    }
    
    private func parseRedirect(response: String) -> String? {
        let status = response[response.index(response.startIndex, offsetBy: 9)..<response.index(response.startIndex, offsetBy: 12)]
        NSLog("\n----\nparseRedirect status: \(status)")
        if (status == "302" || status == "307") {
            //header could be named "Location" or "location"
            if let range = response.range(of: #"ocation: (.*)\r\n"#,
            options: .regularExpression) {
                let location = response[range];
                let redirect = location[location.index(location.startIndex, offsetBy: 9)..<location.index(location.endIndex, offsetBy: -1)]
                return String(redirect)
            }
        }
        return nil
    }

    func openCheckUrl(link: String, completion: @escaping(Any?) -> Void) {
         NSLog("opening \(link)")
         let url = URL(string: link)!
         startConnection(url: url)
         let str = createHttpCommand(url: url)
         NSLog("sending data:\n\(str)")
         let data: Data? = str.data(using: .utf8)
         sendAndReceive(data: data!) { (result) -> () in
             if let r = result {
                NSLog("redirect found: \(r)")
                self.connection?.cancel()
                self.openCheckUrl(link: r, completion: completion)
             } else {
                NSLog("openCheckUrl done")
                self.connection?.cancel()
                completion({});
             }
         }
     }
    
    private func createHttpCommand(url: URL) -> String {
        var cmd = String(format: "GET %@", url.path)
        if (url.query != nil) {
            cmd = cmd + String(format:"?%@", url.query!)
        }
        cmd = cmd + String(format:" HTTP/1.1\r\nHost: %@", url.host!)
        cmd = cmd + " \r\nUser-Agent: tru-sdk-ios/\(truSdkVersion) "
        cmd = cmd +  UIDevice.current.systemName + "/" + UIDevice.current.systemVersion
        cmd = cmd + "\r\nAccept: */*"
        cmd = cmd + "\r\nConnection: close\r\n\r\n"
        return cmd;
    }
    
    private func sendAndReceiveDictionary(data: Data, completion: @escaping ([String : Any]?) -> ()) {
        self.connection!.send(content: data, completion: NWConnection.SendCompletion.contentProcessed({ (error) in
            if let err = error {
                NSLog("Sending error \(err)")
            }
        }))
        self.connection!.receiveMessage { data, context, isComplete, error in
            NSLog("Receive isComplete: " + isComplete.description)
            guard let d = data else {
                NSLog("Error: Received nil Data")
                completion(nil)
                return
            }
            let r = String(data: d, encoding: .utf8)!
            print(r)
            completion(self.parseJsonResponse(response: r))
        }
    }
    
    private func parseJsonResponse(response: String) -> [String : Any]? {
        let status = response[response.index(response.startIndex, offsetBy: 9)..<response.index(response.startIndex, offsetBy: 12)]
        // check HTTP status
        if (status == "200") {
            if let rangeContentType = response.range(of: #"Content-Type: (.*)\r\n"#,
            options: .regularExpression) {
                // retreive content type
                let contentType = response[rangeContentType];
                let type = contentType[contentType.index(contentType.startIndex, offsetBy: 9)..<contentType.index(contentType.endIndex, offsetBy: -1)]
                if (type.contains("application/json")) {
                    // retreive content
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
    
    func getJsonResponse(endPoint: String, completion:@escaping ([String : Any]?) -> ())  {
        let url = URL(string: endPoint)!
        startConnection(url: url)
        let str = createHttpCommand(url: url)
        NSLog("sending data:\n\(str)")
        let data: Data? = str.data(using: .utf8)
        sendAndReceiveDictionary(data: data!) { (result) -> () in
            completion(result)
        }
    }
    
    func getJsonPropertyValue(endPoint: String, key: String, completion:@escaping  (String) -> ())  {
        let url = URL(string: endPoint)!
        startConnection(url: url)
        let str = createHttpCommand(url: url)
        NSLog("sending data:\n\(str)")
        let data: Data? = str.data(using: .utf8)
        sendAndReceiveDictionary(data: data!) { (result) -> () in
            if let r = result {
                completion(r[key] as? String ?? "")
            } else {
                completion("")
            }
        }
    }
}


