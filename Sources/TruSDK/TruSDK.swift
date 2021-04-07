import Foundation
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

    public func check(url: URL , completion: @escaping (Any?) -> Void) {
        connectionManager.openCheckUrl(url: url, completion: completion)
    }

    public func jsonResponse(for url: URL, completion: @escaping ([String : Any]?) -> Void) {
        connectionManager.jsonResponse(url: url, completion: completion)
    }

    public func jsonPropertyValue(for key: String, from url: URL, completion: @escaping  (String) -> Void) {
        connectionManager.jsonPropertyValue(for: key, from: url, completion: completion)
    }

    @available(*, deprecated, renamed: "check")
    public func openCheckUrl(url: String , completion: @escaping (Any?) -> Void) {
        guard let url = URL(string: url) else {
            //TODO: We need to correct this, as this doesn't mean call is a success
            completion(nil)
            return
        }
        connectionManager.openCheckUrl(url: url, completion: completion)
    }

    @available(*, deprecated, renamed: "jsonResponse")
    public func getJsonResponse(url: String, completion: @escaping ([String : Any]?) -> Void) {
        guard let url = URL(string: url) else {
            completion(nil)
            return
        }
        connectionManager.jsonResponse(url: url, completion: completion)
    }

    @available(*, deprecated, renamed: "jsonPropertyValue")
    public func getJsonPropertyValue(url: String, key: String, completion: @escaping  (String) -> Void) {
        guard let url = URL(string: url) else {
            // TODO: We need to return some thing meaningful
            completion("")
            return
        }
        connectionManager.jsonPropertyValue(for: key, from: url, completion: completion)
    }
}
