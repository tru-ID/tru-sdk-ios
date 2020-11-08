@available(iOS 12.0, *)
open class TruSdk {
    
    var redirectManager: RedirectManager = RedirectManager();
    
    public init() {}

    public func openCheckUrl(url: String , completion: @escaping () -> ()) {
        redirectManager.openCheckUrl(link: url, completion: completion)
    }
}
