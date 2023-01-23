//
//  Util.swift
//  
//
//  Created by Murat Yakici on 19/04/2021.
//

import XCTest
import Network

@testable import TruSDK

private var debugInfo = DebugInfo()

func httpCommand(url: URL, sdkVersion: String) -> String {
    var query = ""
    if let q = url.query {
        query = "?\(q)"
    }

    var system = ""
    #if canImport(UIKit)
    system = UIDevice.current.systemName + "/" + UIDevice.current.systemVersion
    #elseif os(macOS)
    system = "macOS / Unknown"
    #endif

    let expectation = """
    GET \(url.path)\(query) HTTP/1.1\
    \r\nHost: \(url.host!)\
    \r\nx-tru-mode: sandbox\
    \r\nUser-Agent: \(debugInfo.userAgent(sdkVersion: sdkVersion)) \
    \r\nAccept: text/html,application/xhtml+xml,application/xml,*/*\
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

// The purpose of this mock is to better support the testing of complex state connection changes
class MockStateHandlingConnectionManager: CellularConnectionManager {
    typealias CompletionHandler = (Any?, Error?) -> Void

    // For testing multiple redirects
    private var playList: [ConnectionResult]
    // This would help us simulate connection state changes
    var connectionStateHandlerPlaylist: [NWConnection.State] = [.setup, .preparing, .ready]
    var stateUpdateHandler: ((NWConnection.State) -> Void)!

    init(playList: [ConnectionResult]) {
        self.playList = playList
    }

    override func open(url: URL, accessToken: String?, debug: Bool, operators: String?, completion: @escaping ([String : Any]) -> Void) {
        super.open(url: url, accessToken: accessToken, debug: debug, operators: operators, completion: completion)
    }

    override func activateConnectionForDataFetch(url: URL,accessToken: String?, operators: String?, cookies: [HTTPCookie]?, requestId: String?, completion: @escaping ResultHandler) {
        let url = URL(string: "https://www.tru.id")!
        let mockCommand = createHttpCommand(url: url, accessToken:accessToken, operators: operators, cookies: cookies, requestId: nil)
        let mockData = mockCommand?.data(using: .utf8)
        guard let data = mockData else {
            return
        }

        stateUpdateHandler = createConnectionUpdateHandler(completion: completion) {
            self.sendAndReceiveWithBody(requestUrl: url, data: data, cookies: cookies, completion: completion)
        }

        //Simulate state changes
        for state in connectionStateHandlerPlaylist {
            stateUpdateHandler(state)
        }
    }

    override func sendAndReceiveWithBody(requestUrl: URL, data: Data, cookies: [HTTPCookie]?, completion: @escaping ResultHandler) {
        if let result = playList.popLast() {
            completion(result)
        } else {
            XCTFail("Exhasuted sending all Mock Test results with closure, and still sendAndReceive is being called.")
        }

    }

    // MARK: - Utility methods
    override func createTimer() {
        //Empty implementation to avoid accidental triggers
    }
    
    override func cancelExistingConnection() {
        self.stateUpdateHandler(.cancelled)
    }

}

class MockConnectionManager: CellularConnectionManager {
    typealias CompletionHandler = (Any?, Error?) -> Void

    // For testing multiple redirects
    private var playList: [ConnectionResult]
    // This would help us simulate connection state changes
    var connectionStateHandlerPlaylist: [NWConnection.State] = [.setup, .preparing, .ready]

    var isStartMonitorCalled: Bool = false
    var isStopMonitorCalled: Bool = false
    var isStartConnectionCalled: Bool = false
    var connectionLifecycle = [String]()
    let shouldFailCreatingHttpCommand: Bool

    // Support for new tests
    var isCleanUpCalled: Bool = false
    var isActivateConnectionCalled: Bool = false


    init(playList: [ConnectionResult], shouldFailCreatingHttpCommand: Bool = false) {
        self.playList = playList
        self.shouldFailCreatingHttpCommand = shouldFailCreatingHttpCommand
    }

    override func open(url: URL, accessToken: String?, debug: Bool, operators: String?, completion: @escaping ([String : Any]) -> Void) {
        super.open(url: url, accessToken: accessToken, debug: debug, operators: operators, completion: completion)
    }

    override func activateConnectionForDataFetch(url: URL,accessToken: String?, operators: String?, cookies: [HTTPCookie]?, requestId: String?, completion: @escaping ResultHandler) {
        self.isActivateConnectionCalled = true
        self.connectionLifecycle.append("activateConnection")
        let mockCommand = createHttpCommand(url: url, accessToken: accessToken, operators: operators, cookies: cookies, requestId: nil)
        let mockData = mockCommand?.data(using: .utf8)
        guard let data = mockData else {
            completion(.err(NetworkError.other("")))
            return
        }
        let stateUpdateHandler = createConnectionUpdateHandler(completion: completion) {
            self.sendAndReceiveWithBody(requestUrl: url, data: data, cookies:cookies, completion: completion)
        }

        //Simulate state changes
        for state in connectionStateHandlerPlaylist {
            if state == .cancelled {
                self.fireTimer()
            } else {
                stateUpdateHandler(state)
            }
        }
    }

    override func cleanUp() {
        isCleanUpCalled = true
        self.stopMonitoring()
    }
    
    // MARK: - Soon to be deprecated

    override func createConnection(scheme: String, host: String, port: Int? = nil) -> NWConnection? {
        // As with the current implementation this won't trigger anything?
        // We can check is this is called or not
        self.isStartConnectionCalled = true
        self.connectionLifecycle.append("startConnection")
        return nil
    }

    override func sendAndReceiveWithBody(requestUrl: URL, data: Data, cookies: [HTTPCookie]?, completion: @escaping ResultHandler) {
        if let result = playList.popLast() {
            completion(result)
        } else {
            XCTFail("Exhasuted sending all Mock Test results with closure, and still sendAndReceive is being called.")
        }

    }

    // MARK: - Utility methods
    override func createTimer() {
        //Empty implementation to avoid accidental triggers
    }
    
    override func createHttpCommand(url: URL, accessToken: String?, operators: String?, cookies: [HTTPCookie]?, requestId: String?) -> String? {
        if shouldFailCreatingHttpCommand {
            return nil
        } else {
            return super.createHttpCommand(url: url, accessToken: accessToken, operators: operators, cookies: cookies, requestId: nil)
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
