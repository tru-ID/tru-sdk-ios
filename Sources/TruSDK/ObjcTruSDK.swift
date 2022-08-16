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

    @objc public func openWithDataCellular(url: URL, debug: Bool, completion: @escaping ([String : Any]) -> Void) {
        connectionManager.open(url: url, debug: debug, operators: self.operators, completion: completion)
    }
    
}

