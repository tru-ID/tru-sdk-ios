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

    public func check(url: URL, completion: @escaping (Any?, Error?) -> Void) {
        //TODO: We need to define a better contract and expectation, as this doesn't mean a call is a success
        connectionManager.openCheckUrl(url: url, completion: completion)
    }

    public func jsonResponse(for url: URL, completion: @escaping ([String : Any]?) -> Void) {
        connectionManager.jsonResponse(url: url, completion: completion)
    }

    public func jsonPropertyValue(for key: String, from url: URL, completion: @escaping  (String) -> Void) {
        connectionManager.jsonPropertyValue(for: key, from: url, completion: completion)
    }

    @available(*, deprecated, renamed: "check(url:completion:)")
    public func openCheckUrl(url: String , completion: @escaping (Any?) -> Void) {
        guard let url = URL(string: url) else {
            completion(nil)
            return
        }
        
        let com: ((Any?, Error?) -> Void) = { (result, error) in
            completion(result)
        }

        connectionManager.openCheckUrl(url: url, completion: com)
    }

    @available(*, deprecated, renamed: "jsonResponse(for:completion:)")
    public func getJsonResponse(url: String, completion: @escaping ([String : Any]?) -> Void) {
        guard let url = URL(string: url) else {
            completion(nil)
            return
        }
        connectionManager.jsonResponse(url: url, completion: completion)
    }

    @available(*, deprecated, renamed: "jsonPropertyValue(for:from:completion:)")
    public func getJsonPropertyValue(url: String, key: String, completion: @escaping  (String) -> Void) {
        guard let url = URL(string: url) else {
            // TODO: We need to return some thing meaningful
            completion("")
            return
        }
        connectionManager.jsonPropertyValue(for: key, from: url, completion: completion)
    }
}
