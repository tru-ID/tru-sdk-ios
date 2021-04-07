@available(macOS 10.14, *)
@available(iOS 13.0, *)
open class TruSDK {
    
    private let redirectManager = CellularConnectionManager();

    public func openCheckUrl(url: String , completion: @escaping (Any?) -> Void) {
        redirectManager.openCheckUrl(link: url, completion: completion)
    }
    
    public func jsonResponse(for url: String, completion: @escaping ([String : Any]?) -> Void) {
        redirectManager.jsonResponse(endPoint: url, completion: completion)
    }
    
    public func jsonPropertyValue(for key: String, from url: String, completion: @escaping  (String) -> Void) {
        redirectManager.jsonPropertyValue(for: key, from: url, completion: completion)
    }
}
