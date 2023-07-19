import Foundation
import CoreTelephony
@available(iOS 12.0, *)
open class TruSDK {
    
    private let connectionManager: ConnectionManager
    private let operators: String?

    init(connectionManager: ConnectionManager) {
        self.connectionManager = connectionManager
        // retrieve operators associated with handset:
        // a commas separated list of mobile operators (MCCMNC)
        let t = CTTelephonyNetworkInfo()
        var ops: Array<String> = Array()
        for (_, carrier) in t.serviceSubscriberCellularProviders ?? [:] {
            let op: String = String(format: "%@%@",carrier.mobileCountryCode ?? "", carrier.mobileNetworkCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if (op.lengthOfBytes(using: .utf8)>0) {
                ops.append(op)
            }
        }
        if (!ops.isEmpty) {
            self.operators = ops.joined(separator: ",")
        } else {
            self.operators = nil
        }
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
    ///   - debug A flag to include or not the url trace in the response
    ///   - accessToken Optional Access Token to be added in the Authorization header (Bearer)
    ///   - completion: closure to report the URL response. Note that, this closure will be called on the Main Thread.
    public func openWithDataCellular(url: URL, debug: Bool, completion: @escaping ([String : Any]) -> Void) {
        connectionManager.open(url: url, accessToken: nil, debug: debug, operators: self.operators, completion: completion)
    }

    /// This method perform open a given a URL over a data cellular connectivity
    /// - Parameters:
    ///   - url: URL provided by tru.ID
    ///   - accessToken Optional Access Token to be added in the Authorization header (Bearer)
    ///   - debug A flag to include or not the url trace in the response
    ///   - completion: closure to report the URL response. Note that, this closure will be called on the Main Thread.
    public func openWithDataCellularAndAccessToken(url: URL, accessToken: String?, debug: Bool, completion: @escaping ([String : Any]) -> Void) {
        connectionManager.open(url: url, accessToken: accessToken, debug: debug, operators: self.operators, completion: completion)
    }

    /// Convenience method to perform a POST request over  a data cellular connectivity
    public func  postWithCellularData(url: URL, headers: [String : Any], body: String?, completion: @escaping ([String : Any]) -> Void) {
        connectionManager.post(url: url, headers: headers, body: body, completion: completion)
    }
}
