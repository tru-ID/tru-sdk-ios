import Foundation
import CoreTelephony

/// This class is only to be used by KMM (Kotlin Multiplatform) developers as Pure Swift dependencies are not yet supported. (v1.6.20 14/4/21)
/// Kotlin supports interoperability with Objective-C dependencies and Swift dependencies if their APIs are exported to Objective-C with the @objc attribute.

@available(macOS 10.15, *)
@available(iOS 12.0, *)
@objc open class ObjcTruSDK: NSObject {
    
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

    public override convenience init() {
        self.init(connectionManager: CellularConnectionManager())
    }

    /// This method performs a check request given a URL
    /// - Parameters:
    ///   - url: URL provided by tru.ID
    ///   - completion: closure to report check result. Note that, this closure will be called on the Main Thread.
    @objc public func checkUrlWithResponseBody(url: URL, completion: @escaping (Error?, [String : Any]?) -> Void) {
        connectionManager.check(url: url, operators: self.operators, completion: completion)
    }

    /// This method performs a check request given a URL
    /// - Parameters:
    ///   - url: URL provided by tru.ID
    ///   - completion: closure to report check result and the trace information. Note that, this closure will be called on the Main Thread.
    @objc public func checkWithTrace(url: URL, completion: @escaping (Error?, TraceInfo?) -> Void) {
        connectionManager.checkWithTrace(url: url, operators: self.operators, completion: completion)
    }
    
    /// This method performs a request to a TruId enpoint and reports back the details if the connection was made over
    /// cellular.
    /// - Parameters:
    ///   - dataResidency: the data residency associated with your tru.ID project
    ///   - completion: closure to report check result. Note that, this closure will be called on the Main Thread.
    @objc public func isReachable(dataResidency: String?, completion: @escaping (ReachabilityDetails?, ReachabilityError?) -> Void) {
        connectionManager.isReachable(dataResidency: dataResidency, operators: self.operators) { connectionResult in
            switch connectionResult {
            case .failure(let reachabilityError): do {
                if let error = reachabilityError {
                    let err = ReachabilityError(type: error.type, title: error.title, status: -1, detail: error.detail)
                    completion(nil, err)
                } else {
                    completion(nil, ReachabilityError(type: "Unknown", title: "No Error type", status: -1, detail: "Received an error with no known type"))
                }
            }
            case .success(let reachabilityDetails): completion(reachabilityDetails, nil)
            }
        }
    }
    
    /// This method performs a request to a TruId enpoint and reports back the details if the connection was made over
    /// cellular.
    @objc public func isReachable(completion: @escaping (ReachabilityDetails?, ReachabilityError?) -> Void) {
        isReachable(dataResidency: nil) { connectionResult, error in
            completion(connectionResult, error)
        }
    }

    
}

