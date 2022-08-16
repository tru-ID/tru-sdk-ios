//
//  TrusdkCheckTests.swift
//  
//
//  Created by Murat Yakici on 21/04/2021.
//

import XCTest
import Network
@testable import TruSDK

final class TrusdkCheckTests: XCTestCase {

    var connectionManager: CellularConnectionManager!

    static var allTests = [
        ("testCheck_ShouldComplete_WithoutErrors", testCheck_ShouldComplete_WithoutErrors),
        ("testCheck_Given3Redirects_ShouldComplete_WithoutError", testCheck_Given3Redirects_ShouldComplete_WithoutError),
        ("testCheck_GivenExceedingMAXRedirects_ShouldComplete_WithError", testCheck_GivenExceedingMAXRedirects_ShouldComplete_WithError),
        ("testCheck_Given3Redirects_WithRelativePath_ShouldComplete_WithError", testCheck_Given3Redirects_WithRelativePath_ShouldComplete_WithError),
        ("testCheck_GivenWithNoSchemeOrHost_ShouldComplete_WithError",testCheck_GivenNoSchemeOrHost_ShouldComplete_WithError),
        ("testCheck_GivenWithNoHTTPCommand_ShouldComplete_WithError", testCheck_GivenNoHTTPCommand_ShouldComplete_WithError),
        ("testCheck_AfterRedirect_ShouldComplete_WithError", testCheck_AfterRedirect_ShouldComplete_WithError),

        ("testConnectionStateSeq_GivenSetupPreparingReady_ShouldComplete_WithoutError", testConnectionStateSeq_GivenSetupPreparingReady_ShouldComplete_WithoutError),
        ("testConnectionStateSeq_GivenSetupPreparingFailed_ShouldComplete_WithError", testConnectionStateSeq_GivenSetupPreparingFailed_ShouldComplete_WithError),
        ("testConnectionStateSeq_GivenSetupPreparingCancelled_ShouldComplete_WithError", testConnectionStateSeq_GivenSetupPreparingCancelled_ShouldComplete_WithError),
        ("testConnectionStateSeq_GivenSetupPreparingWaitingPreparingReady_ShouldComplete_WithoutError", testConnectionStateSeq_GivenSetupPreparingWaitingPreparingReady_ShouldComplete_WithoutError),
        ("testConnectionStateSeq_GivenSetupPreparingWaitingPreparingCancelled_ShouldComplete_WithoutError", testConnectionStateSeq_GivenSetupPreparingWaitingPreparingCancelled_ShouldComplete_WithoutError),

        ("testCreateConnection_GivenWellFormedURL_ShouldReturn_ValidConnection", testCreateConnection_GivenWellFormedURL_ShouldReturn_ValidConnection),
        ("testCreateConnection_GivenNonHTTPScheme_ShouldReturn_Nil", testCreateConnection_GivenNonHTTPScheme_ShouldReturn_Nil),
        ("testCreateConnection_GivenEmptySchemOrHost_ShouldReturn_Nil", testCreateConnection_GivenEmptySchemOrHost_ShouldReturn_Nil),
        ("testCreateConnection_ShouldReturn_CellularOnlyConnection", testCreateConnection_ShouldReturn_CellularOnlyConnection),
        ("testCreateConnection_ShouldReturn_WifiProhibitedConnection", testCreateConnection_ShouldReturn_WifiProhibitedConnection),
    ]

    override func setUpWithError() throws {
           // It is called before each test method begins.
        connectionManager = CellularConnectionManager()
    }

    override func tearDownWithError() throws {
        // It is called after each test method completes.
    }


}

// MARK: - Check tests
extension TrusdkCheckTests {

    func testCheck_ShouldComplete_WithoutErrors() {
        //results will be processes from last to first
        let playList: [ConnectionResult] = [
            .err(NetworkError.other("error")),
            .follow(RedirectResult(url:URL(string: "https://www.tru.id")!, cookies:nil))
        ]

        let mock = MockConnectionManager(playList: playList)
        let sdk = TruSDK(connectionManager: mock)

        let expectation = self.expectation(description: "CheckURL straight execution path")
        let url =  URL(string: "http://tru.id/check_url")!
        sdk.openWithDataCellular(url: url, debug: false) { (r) in
            XCTAssertNotNil(r)
            XCTAssertEqual("sdk_error", r["error"] as! String)
            XCTAssertEqual("error", r["error_description"] as! String)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)

        let callOrder = mock.connectionLifecycle
        XCTAssertEqual(callOrder[0], "startMonitoring")
        XCTAssertEqual(callOrder[1], "activateConnection")
        XCTAssertEqual(callOrder[2], "activateConnection")
        XCTAssertEqual(callOrder[3], "stopMonitoring")
        XCTAssertTrue(mock.isStopMonitorCalled)
        XCTAssertTrue(mock.isCleanUpCalled)
    }

    func testCheck_Given3Redirects_ShouldComplete_WithoutError() {
        let playList: [ConnectionResult] = [
            .err(NetworkError.other("error")),
            .follow(RedirectResult(url:URL(string: "https://www.tru.id/uk")!, cookies:nil)),
            .follow(RedirectResult(url:URL(string: "https://www.tru.id")!, cookies:nil)),
            .follow(RedirectResult(url:URL(string: "https://tru.id")!, cookies:nil))
        ]

        let mock = MockConnectionManager(playList: playList)
        let sdk = TruSDK(connectionManager: mock)

        let expectation = self.expectation(description: "3 Redirects")
        let url = URL(string: "http://tru.id")!

        sdk.openWithDataCellular(url: url, debug: false) { (r) in
            XCTAssertNotNil(r)
            XCTAssertEqual("sdk_error", r["error"] as! String)
            XCTAssertEqual("error", r["error_description"] as! String)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)

        let callOrder = mock.connectionLifecycle
        XCTAssertEqual(callOrder[0], "startMonitoring")
        XCTAssertEqual(callOrder[1], "activateConnection")
        XCTAssertEqual(callOrder[2], "activateConnection")
        XCTAssertEqual(callOrder[3], "activateConnection")
        XCTAssertEqual(callOrder[4], "activateConnection")
        XCTAssertEqual(callOrder[5], "stopMonitoring")
        XCTAssertTrue(mock.isStopMonitorCalled)
        XCTAssertTrue(mock.isCleanUpCalled)
        addTeardownBlock {
            // Rollback state after this test completes
        }
    }

    func testCheck_GivenExceedingMAXRedirects_ShouldComplete_WithError() {
        let playList: [ConnectionResult] = [
            .err(NetworkError.tooManyRedirects),
            .follow(RedirectResult(url:URL(string: "https://www.tru.id/12")!, cookies:nil)),
            .follow(RedirectResult(url:URL(string: "https://www.tru.id/11")!, cookies:nil)),
            .follow(RedirectResult(url:URL(string: "https://www.tru.id/10")!, cookies:nil)), //MAX Redirects is 10
            .follow(RedirectResult(url:URL(string: "https://www.tru.id/9")!, cookies:nil)),
            .follow(RedirectResult(url:URL(string: "https://www.tru.id/8")!, cookies:nil)),
            .follow(RedirectResult(url:URL(string: "https://www.tru.id/7")!, cookies:nil)),
            .follow(RedirectResult(url:URL(string: "https://www.tru.id/6")!, cookies:nil)),
            .follow(RedirectResult(url:URL(string: "https://www.tru.id/5")!, cookies:nil)),
            .follow(RedirectResult(url:URL(string: "https://www.tru.id/4")!, cookies:nil)),
            .follow(RedirectResult(url:URL(string: "https://www.tru.id/3")!, cookies:nil)),
            .follow(RedirectResult(url:URL(string: "https://www.tru.id/2")!, cookies:nil)),
            .follow(RedirectResult(url:URL(string: "https://www.tru.id/1")!, cookies:nil))
        ]

        let mock = MockStateHandlingConnectionManager(playList: playList)
        let sdk = TruSDK(connectionManager: mock)

        let expectation = self.expectation(description: "11 Redirects")
        let url = URL(string: "http://tru.id")!

        sdk.openWithDataCellular(url: url, debug: false) { (r) in
            XCTAssertNotNil(r)
            XCTAssertEqual("sdk_redirect_error", r["error"] as! String)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 3, handler: nil)
    }

    func testCheck_Given3Redirects_WithRelativePath_ShouldComplete_WithError() {

        let playList: [ConnectionResult] = [
            .err(NetworkError.other("error")),
            .follow(RedirectResult(url:URL(string: "/uk")!,cookies:nil)), //This shouldn't happen, we are covering this in parseRedirect test
            .follow(RedirectResult(url:URL(string: "https://tru.id/uk")!, cookies:nil)),
            .follow(RedirectResult(url:URL(string: "https://www.tru.id/uk")!, cookies:nil))
        ]
        let mock = MockConnectionManager(playList: playList)
        let sdk = TruSDK(connectionManager: mock)

        let expectation = self.expectation(description: "3 Redirects, 1 of which is relative")

        let url = URL(string: "http://tru.id")!

        sdk.openWithDataCellular(url: url, debug: false) { (r) in
            XCTAssertNotNil(r)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testCheck_GivenNoSchemeOrHost_ShouldComplete_WithError() {

        let playList: [ConnectionResult] = []

        let mock = MockConnectionManager(playList: playList)
        let sdk = TruSDK(connectionManager: mock)

        let expectation = self.expectation(description: "No Scheme or Host")
        let url = URL(string: "/")!
        sdk.openWithDataCellular(url: url, debug: false) { (r) in
            XCTAssertNotNil(r)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 3, handler: nil)

    }

    func testCheck_GivenNoHTTPCommand_ShouldComplete_WithError() {

        let playList: [ConnectionResult] = []

        let mock = MockConnectionManager(playList: playList, shouldFailCreatingHttpCommand: true)
        let sdk = TruSDK(connectionManager: mock)

        let expectation = self.expectation(description: "No HTTP Command")
        let url = URL(string: "http://tru.id")!
        sdk.openWithDataCellular(url: url, debug: false) { (r) in
            XCTAssertNotNil(r)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 3, handler: nil)
    }

    func testCheck_AfterRedirect_ShouldComplete_WithError() {
        runCheckTestWith(expectedError: .other("Error when sending"))
        runCheckTestWith(expectedError: .other("Error when receiving"))
//        runCheckTestWith(expectedError: .invalidRedirectURL("Location is empty"))
        runCheckTestWith(expectedError: .other("Error when parsing HTTP status"))
    }
}

extension TrusdkCheckTests {

    func runCheckTestWith(expectedError: NetworkError) {

        let playList: [ConnectionResult] = [
            .err(expectedError),
            .follow(RedirectResult(url:URL(string: "https://www.tru.id/uk")!,cookies:nil))
        ]

        let mock = MockConnectionManager(playList: playList)
        let sdk = TruSDK(connectionManager: mock)

        let expectation = self.expectation(description: "Checking errors")
        let url = URL(string: "http://tru.id")!
        sdk.openWithDataCellular(url: url, debug: false) { (r)  in
            XCTAssertNotNil(r)
            XCTAssertEqual("sdk_error", r["error"] as! String)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }
}

// MARK: - CreateStateHandler Tests
// The following possible state changes are tested
// Set-up -> Preparing -> Ready (Which should complete as normal)
// Set-up -> Preparing -> Failed (? -> Cancelled)
// Set-up -> Preparing -> Cancelled (Triggered by Timer)
// Set-up -> Preparing -> Waiting -> Preparing -> Ready (Wait only can go to Preparing or Cancel)
// Set-up -> Preparing -> Waiting -> Preparing -> Cancelled (Triggered by Timer)

// The connection executes, send a success but perhaps during receive we may get Failed or Time out just kicks in
// Difficult to test
// Set-up -> Preparing -> Ready -> Cancelled (Triggered by Timer)
// Set-up -> Preparing -> Ready -> Failed (? -> Cancelled)

extension TrusdkCheckTests {

    func testConnectionStateSeq_GivenSetupPreparingReady_ShouldComplete_WithoutError() {
        let playList: [ConnectionResult] = [
            .err(NetworkError.other("error")),
            .follow(RedirectResult(url:URL(string: "https://www.tru.id")!,cookies: nil))
        ]

        let mock = MockConnectionManager(playList: playList)
        let sdk = TruSDK(connectionManager: mock)

        mock.connectionStateHandlerPlaylist = [.setup, .preparing, .ready]

        let expectation = self.expectation(description: "2 Redirects, with connection state changes")

        let url = URL(string: "http://tru.id")!

        sdk.openWithDataCellular(url: url, debug: false) { (r) in
            XCTAssertNotNil(r)
            XCTAssertEqual("sdk_error", r["error"] as! String)
            XCTAssertEqual("error", r["error_description"] as! String)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testConnectionStateSeq_GivenSetupPreparingFailed_ShouldComplete_WithError() {
        let playList: [ConnectionResult] = [
            .err(NetworkError.other("error")),
            .follow(RedirectResult(url:URL(string: "https://www.tru.id")!,cookies: nil))
        ]

        let mock = MockConnectionManager(playList: playList)
        let sdk = TruSDK(connectionManager: mock)

        let dnsError: NWError = .dns(.zero)
        mock.connectionStateHandlerPlaylist = [.setup, .preparing, .failed(dnsError)]

        let expectation = self.expectation(description: "2 Redirects, with connection state changes")

        let url = URL(string: "http://tru.id")!

        sdk.openWithDataCellular(url: url, debug: false) { (r) in
            XCTAssertNotNil(r)
            XCTAssertEqual("sdk_error", r["error"] as! String)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testConnectionStateSeq_GivenSetupPreparingCancelled_ShouldComplete_WithError() {
        let playList: [ConnectionResult] = [
            .err(NetworkError.other("error")),
            .follow(RedirectResult(url:URL(string: "https://www.tru.id")!,cookies: nil))
        ]

        let mock = MockConnectionManager(playList: playList)
        let sdk = TruSDK(connectionManager: mock)

        mock.connectionStateHandlerPlaylist = [.setup, .preparing, .cancelled]

        let expectation = self.expectation(description: "2 Redirects, with connection state changes")

        let url = URL(string: "http://tru.id")!

        sdk.openWithDataCellular(url: url, debug: false) { (r) in
            XCTAssertNotNil(r)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testConnectionStateSeq_GivenSetupPreparingWaitingPreparingReady_ShouldComplete_WithoutError() {
        let playList: [ConnectionResult] = [
            .err(NetworkError.other("error")),
            .follow(RedirectResult(url:URL(string: "https://www.tru.id")!,cookies: nil))
        ]

        let mock = MockConnectionManager(playList: playList)
        let sdk = TruSDK(connectionManager: mock)

        mock.connectionStateHandlerPlaylist = [.setup, .preparing, .waiting(.tls(.max)), .preparing, .ready]

        let expectation = self.expectation(description: "2 Redirects, with connection state changes")

        let url = URL(string: "http://tru.id")!

        sdk.openWithDataCellular(url: url, debug: false) { (r) in
            XCTAssertNotNil(r)
            XCTAssertEqual("sdk_error", r["error"] as! String)
            XCTAssertEqual("error", r["error_description"] as! String)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testConnectionStateSeq_GivenSetupPreparingWaitingPreparingCancelled_ShouldComplete_WithoutError() {
        let playList: [ConnectionResult] = [
            .err(NetworkError.other("error")),
            .follow(RedirectResult(url:URL(string: "https://www.tru.id")!,cookies: nil))
        ]

        let mock = MockConnectionManager(playList: playList)
        let sdk = TruSDK(connectionManager: mock)

        mock.connectionStateHandlerPlaylist = [.setup, .preparing, .waiting(.tls(.max)), .preparing, .cancelled]

        let expectation = self.expectation(description: "2 Redirects, with connection state changes")

        let url = URL(string: "http://tru.id")!

        sdk.openWithDataCellular(url: url, debug: false) { (r) in
            XCTAssertNotNil(r)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }
    
}

// MARK: - CreateConnection Tests
extension TrusdkCheckTests {

    func testCreateConnection_GivenWellFormedURL_ShouldReturn_ValidConnection() {
        let url = URL(string: "https://trud.id")!
        
        var connection = connectionManager.createConnection(scheme: url.scheme!, host: url.host!)
        XCTAssertNotNil(connection)

        connection = connectionManager.createConnection(scheme: "http", host: "tru.id")
        XCTAssertNotNil(connection)

        connection = connectionManager.createConnection(scheme: "https", host: "tru.id")
        XCTAssertNotNil(connection)
    }

    func testCreateConnection_GivenNonHTTPScheme_ShouldReturn_Nil() {
        let connection = connectionManager.createConnection(scheme: "ftp", host: "tru.id")
        XCTAssertNil(connection)
    }

    func testCreateConnection_GivenDefaultPorts_ShouldReturn_Nil() {
        let expectedTLSPort = 443
        let expectedTCPPort = 80
        let expectedHost = "trud.id"

        // Test HTTP
        var connection = connectionManager.createConnection(scheme: "https",
                                                            host: expectedHost)

        XCTAssertNotNil(connection)
        var conDebug = connection!.debugDescription
        XCTAssertTrue(conDebug.contains("\(expectedHost):\(expectedTLSPort)"), "Port value is NOt as expected")

        // Test HTTP
        connection = connectionManager.createConnection(scheme: "http",
                                                        host: expectedHost)
        XCTAssertNotNil(connection)
        conDebug = connection!.debugDescription
        XCTAssertTrue(conDebug.contains("\(expectedHost):\(expectedTCPPort)"), "Port value is NOt as expected")
    }

    func testCreateConnection_GivenArbitraryPort_ShouldReturn_Nil() {
        let expectedTLSPort = 71
        let expectedTCPPort = 553
        let expectedHost = "trud.id"

        // Test HTTP
        var connection = connectionManager.createConnection(scheme: "https",
                                                            host: expectedHost,
                                                            port: expectedTLSPort)
        
        XCTAssertNotNil(connection)
        var conDebug = connection!.debugDescription
        XCTAssertTrue(conDebug.contains("\(expectedHost):\(expectedTLSPort)"), "Port value is NOt as expected")

        // Test HTTP
        connection = connectionManager.createConnection(scheme: "http",
                                                        host: expectedHost,
                                                        port: expectedTCPPort)
        XCTAssertNotNil(connection)
        conDebug = connection!.debugDescription
        XCTAssertTrue(conDebug.contains("\(expectedHost):\(expectedTCPPort)"), "Port value is NOt as expected")
    }

    func testCreateConnection_GivenEmptySchemOrHost_ShouldReturn_Nil() {
        var connection = connectionManager.createConnection(scheme: "", host: "")
        XCTAssertNil(connection)

        connection = connectionManager.createConnection(scheme: "", host: "tru.id")
        XCTAssertNil(connection)

        connection = connectionManager.createConnection(scheme: "https", host: "")
        XCTAssertNil(connection)

        connection = connectionManager.createConnection(scheme: "http", host: "")
        XCTAssertNil(connection)
    }

    func testCreateConnection_ShouldReturn_CellularOnlyConnection() {
        let url = URL(string: "https://trud.id")!
        let connection = connectionManager.createConnection(scheme: url.scheme!, host: url.host!)

        XCTAssertNotNil(connection)
        #if !targetEnvironment(simulator)
        XCTAssertEqual(connection?.parameters.requiredInterfaceType,  NWInterface.InterfaceType.cellular)
        #endif
    }

    func testCreateConnection_ShouldReturn_WifiProhibitedConnection() {
        let url = URL(string: "https://trud.id")!
        let connection = connectionManager.createConnection(scheme: url.scheme!, host: url.host!)

        XCTAssertNotNil(connection)
        XCTAssertFalse(connection!.parameters.prohibitExpensivePaths)
    }
}
