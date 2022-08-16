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
    
    public convenience init(connectionTimeout: Double) {
        self.init(connectionManager: CellularConnectionManager(connectionTimeout: connectionTimeout))
    }
    
    /// This method perform open a given a URL over a data cellular connectivity
    /// - Parameters:
    ///   - url: URL provided by tru.ID
    ///   - completion: closure to report the URL response. Note that, this closure will be called on the Main Thread.
    public func openWithDataCellular(url: URL, debug: Bool, completion: @escaping ([String : Any]) -> Void) {
        connectionManager.open(url: url, debug: debug, operators: self.operators, completion: completion)
    }
}
