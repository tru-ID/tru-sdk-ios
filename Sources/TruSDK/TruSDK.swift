import Foundation
@available(macOS 10.15, *)
@available(iOS 13.0, *)
open class TruSDK {
    
    private let connectionManager: ConnectionManager;

    init(connectionManager: ConnectionManager) {
        self.connectionManager = connectionManager
    }

    public convenience init() {
        self.init(connectionManager: CellularConnectionManager())
    }

    /// This method perform a check request given a URL
    /// - Parameters:
    ///   - url: URL provided by Tru.Id
    ///   - completion: closure to report check result. Note that, this closure will be called on the Main Thread.
    public func check(url: URL, completion: @escaping (Error?) -> Void) {
        connectionManager.check(url: url, completion: completion)
    }

    /// This method perform a check request given a URL
    /// - Parameters:
    ///   - url: URL provided by Tru.Id
    ///   - completion: closure to report check result and the trace information. Note that, this closure will be called on the Main Thread.
    public func checkWithTrace(url: URL, completion: @escaping (Error?, TraceInfo?) -> Void) {
        connectionManager.checkWithTrace(url: url, completion: completion)
    }
    
    /// This method perform a request to a TruId enpoint and reports back the details if the connection was made over
    /// cellular.
    /// - Parameters:
    ///   - completion: closure to report check result. Note that, this closure will be called on the Main Thread.
    public func isReachable(completion: @escaping (Result<ReachabilityDetails?, ReachabilityError>) -> Void) {
        connectionManager.isReachable { connectionResult in
            switch connectionResult {
            case .complete(let reachabilityError): do {
                if let error = reachabilityError {
                    completion(.failure(error))
                } else {
                    completion(.failure(ReachabilityError(type: "Unknown", title: "No Error type", status: -1, detail: "Received an error with no known type")))
                }
            }
            case .data(let reachabilityDetails): completion(.success(reachabilityDetails))
            case .follow(_): completion(.failure(ReachabilityError(type: "HTTP", title: "Redirect", status: 302, detail: "Unexpected Redirect found!")))
            }
        }
    }

    @available(*, deprecated, renamed: "isReachable(completion:)")
    public func jsonResponse(for url: URL, completion: @escaping ([String : Any]?) -> Void) {
        connectionManager.jsonResponse(url: url, completion: completion)
    }

    @available(*, deprecated, renamed: "isReachable(completion:)")
    public func jsonPropertyValue(for key: String, from url: URL, completion: @escaping  (String) -> Void) {
        connectionManager.jsonPropertyValue(for: key, from: url, completion: completion)
    }

    @available(*, deprecated, renamed: "check(url:completion:)")
    public func check(url: URL, completion: @escaping (Any?, Error?) -> Void) {
        connectionManager.openCheckUrl(url: url, completion: completion)
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

    @available(*, deprecated, renamed: "isReachable(completion:)")
    public func getJsonResponse(url: String, completion: @escaping ([String : Any]?) -> Void) {
        guard let url = URL(string: url) else {
            completion(nil)
            return
        }
        connectionManager.jsonResponse(url: url, completion: completion)
    }

    @available(*, deprecated, renamed: "isReachable(completion:)")
    public func getJsonPropertyValue(url: String, key: String, completion: @escaping  (String) -> Void) {
        guard let url = URL(string: url) else {
            // TODO: We need to return some thing meaningful
            completion("")
            return
        }
        connectionManager.jsonPropertyValue(for: key, from: url, completion: completion)
    }
}
