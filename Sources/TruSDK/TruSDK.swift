@available(macOS 10.14, *)
@available(iOS 13.0, *)
open class TruSDK {
    
    private let connectionManager: ConnectionManager;

    init(connectionManager: ConnectionManager) {
        self.connectionManager = connectionManager
    }

    public convenience init() {
        self.init(connectionManager: CellularConnectionManager())
    }
    
    public func openCheckUrl(url: String , completion: @escaping (Any?) -> Void) {
        connectionManager.openCheckUrl(link: url, completion: completion)
    }
    
    public func jsonResponse(for url: String, completion: @escaping ([String : Any]?) -> Void) {
        connectionManager.jsonResponse(endPoint: url, completion: completion)
    }
    
    public func jsonPropertyValue(for key: String, from url: String, completion: @escaping  (String) -> Void) {
        connectionManager.jsonPropertyValue(for: key, from: url, completion: completion)
    }
}
