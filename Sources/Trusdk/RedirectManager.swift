import Foundation
import Network


//
// Force connectivity to cellular only
// Open the "check url" and follows all redirects
// we might switch from tls to non-tls between redirects
//
@available(iOS 12.0, *)
class RedirectManager {
    
    var connection: NWConnection?

    private func startConnection(url: URL) {
        let pathMonitor = NWPathMonitor()
        pathMonitor.pathUpdateHandler = { path in
            if path.usesInterfaceType(.wifi) {
                print("Path is Wi-Fi")
            } else if path.usesInterfaceType(.cellular) {
                print("Path is Cellular")
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
        var tlsOptions: NWProtocolTLS.Options?
        var port = 80
        if (url.scheme!.starts(with:"https")) {
            port = 443
            tlsOptions = .init()
        }
        print("connection scheme \(url.scheme!) \(port)")
        // force network connection to cellular only
        let params = NWParameters(tls: tlsOptions , tcp: tcpOptions)
        params.requiredInterfaceType = .cellular
        params.prohibitExpensivePaths = false
        params.prohibitedInterfaceTypes = [.wifi]
        // create network connection
        connection = NWConnection(host: NWEndpoint.Host(url.host!), port: NWEndpoint.Port(rawValue: UInt16(port))!, using: params)
        connection?.stateUpdateHandler = { (newState) in
            switch (newState) {
                case .ready:
                    print("State: Ready \(self.connection.debugDescription)\n")
                case .setup:
                    print("State: Setup\n")
                case .cancelled:
                    print("State: Cancelled\n")
                case .preparing:
                    print("State: Preparing\n")
                default:
                    print("ERROR! State not defined!\n")
            }
        }
        connection?.start(queue: .main)
    }

    private func sendAndReceive(data: Data, completion: @escaping (String?) -> ()) {
        self.connection!.send(content: data, completion: NWConnection.SendCompletion.contentProcessed({ (error) in
            if let err = error {
                print("Sending error \(err)")
            }
        }))
        self.connection!.receiveMessage { data, context, isComplete, error in
              print("Receive isComplete: " + isComplete.description)
              guard let d = data else {
                  print("Error: Received nil Data")
                  return
              }
              let r = String(data: d, encoding: .utf8)!
              print(r)
              completion(self.parseRedirect(response: r))
        }
    }
    
    private func parseRedirect(response: String) -> String? {
        let status = response[response.index(response.startIndex, offsetBy: 9)..<response.index(response.startIndex, offsetBy: 12)]
        print("\n----\nparseRedirect status: \(status)")
        if (status == "302") {
            if let range = response.range(of: #"Location: (.*)\r\n"#,
            options: .regularExpression) {
                let location = response[range];
                let redirect = location[location.index(location.startIndex, offsetBy: 10)..<location.index(location.endIndex, offsetBy: -1)]
                return String(redirect)
            }
        }
        return nil
    }

    func openCheckUrl(link: String) {
        print("opening \(link)")
        let url = URL(string: link)!
        startConnection(url: url)
        var str = String(format: "GET %@", url.path)
        if (url.query != nil) {
            str = str + String(format:"?%@", url.query!)
        }
        str = str + String(format:" HTTP/1.1\r\nHost: %@", url.host!)
        let port = url.scheme!.starts(with:"https") ? 443 : 80
        str = str + String(format:":%d", port)
        str = str + " \r\nConnection: close\r\n\r\n"
        print("sending data:\n\(str)")
        let data: Data? = str.data(using: .utf8)
        sendAndReceive(data: data!) { (result) -> () in
            if let r = result {
                print("redirect found: \(r)")
                self.openCheckUrl(link: r)
            }
        }
    }
}


