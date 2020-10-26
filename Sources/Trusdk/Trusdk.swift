@available(iOS 12.0, *)
open class TruSdk {
    
    public init() {}

    public func openCheckUrl(url: String , completion: (Bool) -> ()) {
        let redirectManager: RedirectManager = RedirectManager()
        redirectManager.openCheckUrl(link: url)
        return completion(true)
    }
}
