import Foundation
import CoreTelephony
@available(macOS 10.15, *)
@available(iOS 12.0, *)
open class TruSDK {
    
    private let connectionManager: ConnectionManager
    private let operators: String?

    init(connectionManager: ConnectionManager) {
        self.connectionManager = connectionManager
        // retreive operators associated with handset:
        // a commas separated list of mobile operators (MCCMNC)
        let t = CTTelephonyNetworkInfo()
        var ops: Array<String> = Array()
        for (_, carrier) in t.serviceSubscriberCellularProviders ?? [:] {
            let op: String = String(format: "%@%@",carrier.mobileCountryCode ?? "", carrier.mobileNetworkCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if (op.lengthOfBytes(using: .utf8)>0) {
                ops.append(op)
            }
        }
        self.operators = ops.joined(separator: ",")
    }

    public convenience init() {
        self.init(connectionManager: CellularConnectionManager())
    }

    /// This method perform a check request given a URL
    /// - Parameters:
    ///   - url: URL provided by tru.ID
    ///   - completion: closure to report check result. Note that, this closure will be called on the Main Thread.
    public func checkUrlWithResponseBody(url: URL, completion: @escaping (Error?, [String : Any]?) -> Void) {
        connectionManager.check(url: url, operators: self.operators, completion: completion)
    }

    /// This method perform a check request given a URL
    /// - Parameters:
    ///   - url: URL provided by tru.ID
    ///   - completion: closure to report check result and the trace information. Note that, this closure will be called on the Main Thread.
    public func checkWithTrace(url: URL, completion: @escaping (Error?, TraceInfo?) -> Void) {
        connectionManager.checkWithTrace(url: url, operators: self.operators, completion: completion)
    }
    
    
    /// This method perform a request to a TruId enpoint and reports back the details if the connection was made over
    /// cellular.
    /// - Parameters:
    ///   - dataResidency: the data residency associated with your tru.ID project
    ///   - completion: closure to report check result. Note that, this closure will be called on the Main Thread.
    public func isReachable(dataResidency: String?, completion: @escaping (Result<ReachabilityDetails?, ReachabilityError>) -> Void) {
        connectionManager.isReachable(dataResidency: dataResidency, operators: self.operators) { connectionResult in
            switch connectionResult {
            case .failure(let reachabilityError): do {
                if let error = reachabilityError {
                    completion(.failure(error))
                } else {
                    completion(.failure(ReachabilityError(type: "Unknown", title: "No Error type", status: -1, detail: "Received an error with no known type")))
                }
            }
            case .success(let reachabilityDetails): completion(.success(reachabilityDetails))
            }
        }
    }
    
    public func isReachable(completion: @escaping (Result<ReachabilityDetails?, ReachabilityError>) -> Void) {
        isReachable(dataResidency: nil) { connectionResult in
            completion(connectionResult)
        }
    }

    @available(*, deprecated, renamed: "checkUrlWithResponseBody(url:completion:)")
    public func check(url: URL, completion: @escaping (Error?) -> Void) {
        connectionManager._check(url: url, operators: self.operators, completion: completion)
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
