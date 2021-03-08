@available(iOS 12.0, *)
open class TruSDK {
    
    var redirectManager: RedirectManager = RedirectManager();
    
    public init() {}

    public func openCheckUrl(url: String , completion: @escaping (Any?) -> Void) {
        redirectManager.openCheckUrl(link: url, completion: completion)
    }
    
    public func getJsonResponse(url: String, completion:@escaping ([String : Any]?) -> ()) {
        redirectManager.getJsonResponse(endPoint: url, completion: completion)
    }
    
    public func getJsonPropertyValue(url: String, key: String, completion:@escaping  (String) -> ()) {
        redirectManager.getJsonPropertyValue(endPoint: url, key: key, completion: completion)
    }
}
