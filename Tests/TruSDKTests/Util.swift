//
//  File 2.swift
//  
//
//  Created by Murat Yakici on 19/04/2021.
//

import XCTest
@testable import TruSDK

func deviceString() -> String {
    var device: String
    #if canImport(UIKit)
    device = UIDevice.current.systemName + "/" + UIDevice.current.systemVersion
    #elseif os(macOS)
    device = "macOS / Unknown"
    #endif
    return device
}

func httpCommand(url: URL, sdkVersion: String) -> String {
    let device = deviceString()
    var query = ""
    if let q = url.query {
        query = "?\(q)"
    }
    let expectation = """
    GET \(url.path)\(query) HTTP/1.1\
    \r\nHost: \(url.host!)\
    \r\nUser-Agent: tru-sdk-ios/\(sdkVersion) \(device)\
    \r\nAccept: */*\
    \r\nConnection: close\r\n\r\n
    """
    return expectation
}

enum HTTPStatus: Int {
    case multipleChoices = 300
    case movedPermanently = 301
    case found = 302
    case seeOther = 303
    case notModified = 304
    case useProxy = 305
    case switchProxy = 306
    case temporaryRedirect = 307
    case permenantRedirect = 308


    var statusMessage: String {
        switch self {
        case .multipleChoices:
            return "Multiple Choice"
        case .movedPermanently:
            return "Moved Permanently"
        case .found:
            return "Found"
        case .seeOther:
            return "See Other"
        case .notModified:
            return "Not Modified"
        case .useProxy:
            return "Use Proxy"
        case .temporaryRedirect:
            return "Temporary Redirect"
        case .permenantRedirect:
            return "Permanent Redirect"
        case .switchProxy:
            return "Switch Proxy"
        }
    }
}


// MARK: - Default HTTP Responses
func http2xxResponse() -> String {
    return """
    HTTP/1.1 200 OK\r\n \
    Date: Mon, 19 April 2021 22:04:35 GMT\r\n\
    Server: Apache/2.2.8 (Ubuntu) mod_ssl/2.2.8 OpenSSL/0.9.8g\r\n\
    Last-Modified: Mon, 19 April 2021 22:04:35 GMT\r\n\
    ETag: "45b6-834-49130cc1182c0"\r\n\
    Accept-Ranges: bytes\r\n\
    Content-Length: 12\r\n\
    Connection: close\r\n\
    Content-Type: text/html\r\n\
    \r\n\
    Hello world!\r\n
    """
}

func http3XXResponse(code: HTTPStatus, url: String) -> String {
    return """
    HTTP/1.1 \(code.rawValue) \(code.statusMessage)\r\n\
    Server: AkamaiGHost\r\n \
    Content-Length: 0\r\n\
    Location: \(url)\r\n\
    Date: Thu, 15 Apr 2021 19:09:15 GMT\r\n\
    Connection: keep-alive\r\n\
    Cache-Control: no-store, no-cache, must-revalidate, post-check=0, pre-check=0\r\n\r\n
    """
}

func http3XXResponseWith(code: HTTPStatus, locationString: String) -> String {
    return """
    HTTP/1.1 \(code.rawValue) \(code.statusMessage)\r\n\
    Server: AkamaiGHost\r\n \
    Content-Length: 0\r\n\
    \(locationString)\r\n\
    Date: Thu, 15 Apr 2021 19:09:15 GMT\r\n\
    Connection: keep-alive\r\n\
    Cache-Control: no-store, no-cache, must-revalidate, post-check=0, pre-check=0\r\n\r\n
    """
}

func http400Response() -> String {
    ""
}

func http500Response() -> String {
    ""
}

func corruptHTTPResponse() -> String {
    return """
    Accept-Ranges: bytes\r\n\
    WWEHTTP><><>/1.1 sdkasdh OK203\r\n \
    il 2021 22:0Date: Mon, 19 Apr4:35 GMT\r\n\
    Server: Apac19 April 2021 22:04:35 GMT\r\n\
    ETag: "45b6-834-4913he/2.2.8 (Ubuntu) mod_ssl/2.2.8 OpenSSL/0.9.8g\r\n\
    Last-Modified: Mon, 0cc1182c0"\r\n\
    asd;lkasdk,
    asdk;lasd
    kqeiqwe
    \r\n\
    Hello world!\r\n
    """
}


class MockConnectionManager: CellularConnectionManager {
    typealias CompletionHandler = (Any?, Error?) -> Void

    // For testing multiple redirects
    private var results: [ConnectionResult<URL, NetworkError>]

    var isStartMonitorCalled: Bool = false
    var isStopMonitorCalled: Bool = false
    var isStartConnectionCalled: Bool = false
    var connectionLifecycle = [String]()
    let shouldFailCreatingHttpCommand: Bool

    init(result: [ConnectionResult<URL, NetworkError>], shouldFailCreatingHttpCommand: Bool = false) {
        self.results = result
        self.shouldFailCreatingHttpCommand = shouldFailCreatingHttpCommand
    }

    override func openCheckUrl(url: URL, completion: @escaping CompletionHandler) {
        super.openCheckUrl(url: url, completion: completion)
    }

    override func startConnection(scheme: String, host: String) {
        // As with the current implementation this won't trigger anything?
        // We can check is this is called or not
        self.isStartConnectionCalled = true
        self.connectionLifecycle.append("startConnection")
    }

    override func sendAndReceive(requestUrl: URL, data: Data, completion: @escaping (ConnectionResult<URL, NetworkError>) -> Void) {
        if let result = results.popLast() {
            completion(result)
        } else {
            XCTFail("Exhasuted sending all Mock Test results with closure, and still sendAndReceive is being called.")
        }

    }

    override func createHttpCommand(url: URL) -> String? {
        if shouldFailCreatingHttpCommand {
            return nil
        } else {
            return super.createHttpCommand(url: url)
        }
    }
    override func startMonitoring() {
        self.isStartMonitorCalled = true
        self.connectionLifecycle.append("startMonitoring")
    }

    override func stopMonitoring() {
        self.isStopMonitorCalled = true
        self.connectionLifecycle.append("stopMonitoring")
    }

}
