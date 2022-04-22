#if canImport(UIKit)
import UIKit
#else
import Foundation
#endif
import os

/// Collects trace and debugging information for each 'check' session.
@objc final class TraceCollector: NSObject {

    let queue = DispatchQueue(label: "id.tru.tracecollector.queue")

    private var trace = ""
    private var isTraceEnabled = false
    private var body: [String : Any]? = nil

    private var debugInfo = DebugInfo()
    var isDebugInfoCollectionEnabled = false
    var isConsoleLogsEnabled = false

    /// Stops trace and clears the internal buffer
    func startTrace() {
        queue.sync() {
            if !isTraceEnabled {
                isTraceEnabled = true
                //
                trace.removeAll()
                debugInfo.clear()
                //
                trace.append("\(debugInfo.deviceString())\n")
                debugInfo.add(log:"\(debugInfo.deviceString())\n")
            } else {
                os_log("%s", type:.error, "Trace already started. Use stopTrace before restaring..")
            }
        }
    }

    /// Stops trace and clears the internal buffer. Collection of debug information also stops, if enabled prior to startTrace().
    func stopTrace() {
        queue.sync() {
            isTraceEnabled = false
            isDebugInfoCollectionEnabled = false
            isConsoleLogsEnabled = false
            //
            trace.removeAll()
            debugInfo.clear()
        }
    }

    /// Provides the TraceInfo recorded
    func traceInfo() -> TraceInfo {
        queue.sync() {
            return TraceInfo(trace: trace, debugInfo: debugInfo, responseBody: body)
        }
    }

    /// Records a trace. Add a newline at the end of the log.
    func addTrace(log: String) {
        queue.async {
            if self.isTraceEnabled {
                self.trace.append("\(log)\n")
            }
        }
    }

    func addDebug(type: OSLogType = .debug, tag: String? = "Tru.ID", log: String) {
        queue.async {
            if self.isDebugInfoCollectionEnabled {
                self.debugInfo.add(tag: tag, log: log)
            }
        }
        if self.isConsoleLogsEnabled {
            os_log("%s", type:type, log)
        }
    }

    func addBody(body: [String : Any]?) {
        self.body = body
    }

    func now() -> String {
        debugInfo.dateUtils.now()
    }

}

@objc public class DebugInfo: NSObject {

    internal let dateUtils = DateUtils()
    private var bufferMap = Dictionary<String, String>()

    internal func add(tag: String? = nil, log: String) {
        guard let tag = tag else {
            self.bufferMap[dateUtils.now()] = "\(log)"
            return
        }
        self.bufferMap[dateUtils.now()] = "\(tag) - \(log)"
    }

    internal func clear() {
        bufferMap.removeAll()
    }

    public func toString() -> String {
        var stringBuffer = ""
        for key in bufferMap.keys.sorted() {
            guard let value = bufferMap[key] else { break }
            stringBuffer += "\(key): \(value)"
        }
        return stringBuffer
    }
    
    public func userAgent(sdkVersion: String) -> String {
        return "tru-sdk-ios/\(sdkVersion) \(deviceString())"
    }

    public func deviceString() -> String {
        var device: String = ""
        #if canImport(UIKit)
        device = UIDevice.current.systemName + "/" + UIDevice.current.systemVersion
        #elseif os(macOS)
        device = "macOS / Unknown"
        #endif
        return device
    }
}

@objc public class TraceInfo: NSObject {
    @objc public let trace: String
    @objc public let debugInfo: DebugInfo
    @objc public let responseBody: [String : Any]?
    
    public init(trace: String, debugInfo: DebugInfo, responseBody: [String : Any]?) {
        self.trace = trace
        self.debugInfo = debugInfo
        self.responseBody = responseBody
    }
}

func isoTimestampUsingCurrentTimeZone() -> String {
    let isoDateFormatter = ISO8601DateFormatter()
    isoDateFormatter.timeZone = TimeZone.current
    let timestamp = isoDateFormatter.string(from: Date())
    return timestamp
}

class DateUtils {

    lazy var df: ISO8601DateFormatter = {
        let d = ISO8601DateFormatter()
        d.formatOptions = [
            .withInternetDateTime,
            .withDashSeparatorInDate,
            .withFullDate,
            .withFractionalSeconds,
            .withColonSeparatorInTimeZone
        ]
        return d
    }()

    func now() -> String {
        df.string(from: Date())
    }
}
