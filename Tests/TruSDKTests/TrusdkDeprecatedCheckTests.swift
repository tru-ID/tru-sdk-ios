//
//  TrusdkCheckTests.swift
//  
//
//  Created by Murat Yakici on 19/04/2021.
//

import XCTest
@testable import TruSDK

typealias Result = (ConnectionResult<URL, Data, Error>) -> Void

final class TrusdkDeprecatedCheckTests: XCTestCase {

    var connectionManager: CellularConnectionManager!

    static var allTests = [
        ("testCheck_ShouldComplete_WithoutErrors", testCheck_ShouldComplete_WithoutErrors),
        ("testCheck_ShouldComplete_WithError_AfterRedirect", testCheck_ShouldComplete_WithError_AfterRedirect),
        ("testCheck_3Redirects_ShouldComplete_WithoutErrors", testCheck_3Redirects_ShouldComplete_WithoutError),
        ("testCheck_3Redirects_WithRelativePath_ShouldComplete_WithError", testCheck_3Redirects_WithRelativePath_ShouldComplete_WithError),
        ("testCheck_StartsStopConnectionCalls_ShouldBeInCorrectOrder", testCheck_StartsStopConnectionCalls_ShouldBeInCorrectOrder),
        ("testCheck_StartsStopConnectionCalls_ShouldBeInCorrectOrder_AfterRedirect",testCheck_StartsStopConnectionCalls_ShouldBeInCorrectOrder_AfterRedirect),
        ("testCheck_WithNoSchemeOrHost_ShouldComplete_WithError",testCheck_WithNoSchemeOrHost_ShouldComplete_WithError),
        ("testCheck_WithNoHTTPCommand_ShouldComplete_WithError", testCheck_WithNoHTTPCommand_ShouldComplete_WithError)
    ]

    override func setUpWithError() throws {
           // It is called before each test method begins.
        connectionManager = CellularConnectionManager()
    }

    override func tearDownWithError() throws {
        // It is called after each test method completes.
    }


}

extension TrusdkDeprecatedCheckTests {

    func testCheck_ShouldComplete_WithoutErrors() {
        //results will be processes from last to first
        let results: [ConnectionResult<URL, Data, Error>] = [
            .complete(nil),
            .follow(URL(string: "https://www.tru.id")!)
        ]

        let mock = MockConnectionManager(playList: results)
        let sdk = TruSDK(connectionManager: mock)

        let expectation = self.expectation(description: "CheckURL straight execution path")
        sdk.check(url: URL(string: "http://tru.id/check_url")!) { (result, error)  in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        addTeardownBlock {
            // Rollback state after this test completes
        }
    }

    func testCheck_ShouldComplete_WithError_AfterRedirect() {
        runCheckTestWith(error: .other("Error when sending"))
        runCheckTestWith(error: .other("Error when receiving"))
        runCheckTestWith(error: .noData("Error when response is empty"))
        runCheckTestWith(error: .invalidRedirectURL("Location is empty"))
        runCheckTestWith(error: .httpClient("Error HTTP client"))
        runCheckTestWith(error: .httpServer("Error HTTP server"))
        runCheckTestWith(error: .other("Error when parsing HTTP status"))
    }

    func testCheck_3Redirects_ShouldComplete_WithoutError() {
        let startURL = URL(string: "http://tru.id")!

        let results: [ConnectionResult<URL, Data, Error>] = [
            .complete(nil),
            .follow(URL(string: "https://www.tru.id/uk")!),
            .follow(URL(string: "https://www.tru.id")!),
            .follow(URL(string: "https://tru.id")!)
        ]

        let mock = MockConnectionManager(playList: results)
        let sdk = TruSDK(connectionManager: mock)

        let expectation = self.expectation(description: "3 Redirects")
        sdk.check(url: startURL) { (result, error)  in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        addTeardownBlock {
            // Rollback state after this test completes
        }
    }

    func testCheck_3Redirects_WithRelativePath_ShouldComplete_WithError() {
        let startURL = URL(string: "http://tru.id")!
        let results: [ConnectionResult<URL, Data, Error>] = [
            .complete(nil),
            .follow(URL(string: "/uk")!), //This shouldn't happen, we are covering this in parseRedirect test
            .follow(URL(string: "https://tru.id")!),
            .follow(URL(string: "https://www.tru.id")!)
        ]
        let mock = MockConnectionManager(playList: results)
        let sdk = TruSDK(connectionManager: mock)

        let expectation = self.expectation(description: "3 Redirects, 1 of which is relative")
        sdk.check(url: startURL) { (result, error)  in
            XCTAssertNotNil(error)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testCheck_StartsStopConnectionCalls_ShouldBeInCorrectOrder() {
        let startURL = URL(string: "http://tru.id")!
        let results: [ConnectionResult<URL, Data, Error>] = [.complete(nil)]

        let mock = MockConnectionManager(playList: results)
        let sdk = TruSDK(connectionManager: mock)

        let expectation = self.expectation(description: "Start/Stop connection calls")
        sdk.check(url: startURL) { (result, error)  in
            XCTAssertNil(error)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)

        let callOrder = mock.connectionLifecycle
        XCTAssertEqual(callOrder[0], "startMonitoring")
        XCTAssertEqual(callOrder[1], "startConnection")
        XCTAssertEqual(callOrder[2], "stopMonitoring")
    }

    func testCheck_StartsStopConnectionCalls_ShouldBeInCorrectOrder_AfterRedirect() {
        let startURL = URL(string: "http://tru.id")!
        let results: [ConnectionResult<URL, Data, Error>] = [.complete(nil),
                                                              .follow(URL(string: "https://www.tru.id")!)]

        let mock = MockConnectionManager(playList: results)
        let sdk = TruSDK(connectionManager: mock)

        let expectation = self.expectation(description: "Start/Stop connection calls")
        sdk.check(url: startURL) { (result, error)  in
            XCTAssertNil(error)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 3, handler: nil)

        let callOrder = mock.connectionLifecycle
        XCTAssertEqual(callOrder[0], "startMonitoring")
        XCTAssertEqual(callOrder[1], "startConnection")
        XCTAssertEqual(callOrder[2], "stopMonitoring")
        XCTAssertEqual(callOrder[3], "startMonitoring")
        XCTAssertEqual(callOrder[4], "startConnection")
        XCTAssertEqual(callOrder[5], "stopMonitoring")
    }

    func testCheck_WithNoSchemeOrHost_ShouldComplete_WithError() {
        let startURL = URL(string: "/")!
        let results: [ConnectionResult<URL, Data, Error>] = []

        let mock = MockConnectionManager(playList: results)
        let sdk = TruSDK(connectionManager: mock)
        
        let expectation = self.expectation(description: "No Scheme or Host")
        sdk.check(url: startURL) { (result, error)  in
            XCTAssertNotNil(error)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 3, handler: nil)

    }

    func testCheck_WithNoHTTPCommand_ShouldComplete_WithError() {
        let startURL = URL(string: "http://tru.id")!
        let results: [ConnectionResult<URL, Data, Error>] = []

        let mock = MockConnectionManager(playList: results, shouldFailCreatingHttpCommand: true)
        let sdk = TruSDK(connectionManager: mock)

        let expectation = self.expectation(description: "No HTTP Command")
        sdk.check(url: startURL) { (result, error)  in
            XCTAssertNotNil(error)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 3, handler: nil)
    }

}

extension TrusdkDeprecatedCheckTests {
    
    func runCheckTestWith(error: NetworkError) {
        let startURL = URL(string: "http://tru.id")!
        let results: [ConnectionResult<URL, Data, Error>] = [
            .complete(error),
            .follow(URL(string: "https://www.tru.id/uk")!)
        ]

        let mock = MockConnectionManager(playList: results)
        let sdk = TruSDK(connectionManager: mock)

        let expectation = self.expectation(description: "Checking errors")
        sdk.check(url: startURL) { (result, err)  in
            XCTAssertNotNil(err)
            XCTAssertEqual(error, err as! NetworkError)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }
}
