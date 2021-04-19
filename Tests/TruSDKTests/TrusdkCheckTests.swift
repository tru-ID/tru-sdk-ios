//
//  TrusdkCheckTests.swift
//  
//
//  Created by Murat Yakici on 19/04/2021.
//

import XCTest
@testable import TruSDK

final class TrusdkCheckTests: XCTestCase {

    var connectionManager: CellularConnectionManager!

    static var allTests = [
        ("testCheck_ShouldComplete_WithoutErrors", testCheck_ShouldComplete_WithoutErrors),
        ("testCheck_3Redirects_ShouldComplete_WithoutErrors", testCheck_3Redirects_ShouldComplete_WithoutErrors),
        ("testCheck_3Redirects_With_RelativePath_ShouldComplete_WithError", testCheck_3Redirects_With_RelativePath_ShouldComplete_WithError),
        ("testCheck_StartsStopConnectionCalls_ShouldBeInCorrectOrder", testCheck_StartsStopConnectionCalls_ShouldBeInCorrectOrder),
        ("testCheck_StartsStopConnectionCalls_ShouldBeInCorrectOrder_AfterRedirect",testCheck_StartsStopConnectionCalls_ShouldBeInCorrectOrder_AfterRedirect),
        ("testCheck_WithNoSchemeOrHost_ShouldReturnError",testCheck_WithNoSchemeOrHost_ShouldReturnError),
        ("testCheck_WithNoHTTPCommand_ShouldReturnError", testCheck_WithNoHTTPCommand_ShouldReturnError)
    ]

    override func setUpWithError() throws {
           // It is called before each test method begins.
        connectionManager = CellularConnectionManager()
    }

    override func tearDownWithError() throws {
        // It is called after each test method completes.
    }


}

extension TrusdkCheckTests {

    func testCheck_ShouldComplete_WithoutErrors() {
        let results: [ConnectionResult<URL, NetworkError>] = [
            .complete(nil),
            .redirect(URL(string: "https://www.newlook.com")!)
        ]

        let mock = MockConnectionManager(result: results)
        let sdk = TruSDK(connectionManager: mock)
        let expectation = self.expectation(description: "CheckURL Incorrect URL")
        sdk.check(url: URL(string: "http://newlook.com")!) { (result, error)  in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        addTeardownBlock {
            // Rollback state after this test completes
        }
    }

    func testCheck_3Redirects_ShouldComplete_WithoutErrors() {
        let startURL = URL(string: "http://newlook.com")!

        let results: [ConnectionResult<URL, NetworkError>] = [
            .complete(nil),
            .redirect(URL(string: "https://newlook.com")!),
            .redirect(URL(string: "https://www.newlook.com/uk")!),
            .redirect(URL(string: "https://www.newlook.com")!)
        ]

        let mock = MockConnectionManager(result: results)
        let sdk = TruSDK(connectionManager: mock)
        let expectation = self.expectation(description: "CheckURL Incorrect URL")
        sdk.check(url: startURL) { (result, error)  in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        addTeardownBlock {
            // Rollback state after this test completes
        }
    }

    func testCheck_3Redirects_With_RelativePath_ShouldComplete_WithError() {
        let startURL = URL(string: "http://newlook.com")!
        let results: [ConnectionResult<URL, NetworkError>] = [
            .complete(nil),
            .redirect(URL(string: "/uk")!), //This shouldn't happen, we are covering this in parseRedirect
            .redirect(URL(string: "https://newlook.com")!),
            .redirect(URL(string: "https://www.newlook.com")!)
        ]
        let mock = MockConnectionManager(result: results)
        let sdk = TruSDK(connectionManager: mock)
        let expectation = self.expectation(description: "CheckURL Incorrect URL")
        sdk.check(url: startURL) { (result, error)  in
            XCTAssertNotNil(error)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testCheck_StartsStopConnectionCalls_ShouldBeInCorrectOrder() {
        let startURL = URL(string: "http://newlook.com")!
        let results: [ConnectionResult<URL, NetworkError>] = [.complete(nil)]

        let mock = MockConnectionManager(result: results)
        let sdk = TruSDK(connectionManager: mock)
        let expectation = self.expectation(description: "CheckURL Incorrect URL")
        sdk.check(url: startURL) { (result, error)  in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        let callOrder = mock.connectionLifecycle

        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(callOrder[0], "startMonitoring")
        XCTAssertEqual(callOrder[1], "startConnection")
        XCTAssertEqual(callOrder[2], "stopMonitoring")
    }

    func testCheck_StartsStopConnectionCalls_ShouldBeInCorrectOrder_AfterRedirect() {
        let startURL = URL(string: "http://newlook.com")!
        let results: [ConnectionResult<URL, NetworkError>] = [.complete(nil),
                                                              .redirect(URL(string: "https://www.newlook.com")!)]

        let mock = MockConnectionManager(result: results)
        let sdk = TruSDK(connectionManager: mock)
        let expectation = self.expectation(description: "CheckURL Incorrect URL")
        sdk.check(url: startURL) { (result, error)  in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        let callOrder = mock.connectionLifecycle

        waitForExpectations(timeout: 3, handler: nil)
        XCTAssertEqual(callOrder[0], "startMonitoring")
        XCTAssertEqual(callOrder[1], "startConnection")
        XCTAssertEqual(callOrder[2], "stopMonitoring")
        XCTAssertEqual(callOrder[3], "startMonitoring")
        XCTAssertEqual(callOrder[4], "startConnection")
        XCTAssertEqual(callOrder[5], "stopMonitoring")
    }

    func testCheck_WithNoSchemeOrHost_ShouldReturnError() {
        let startURL = URL(string: "/")!
        let results: [ConnectionResult<URL, NetworkError>] = []

        let mock = MockConnectionManager(result: results)
        let sdk = TruSDK(connectionManager: mock)
        let expectation = self.expectation(description: "No Scheme or Host")
        sdk.check(url: startURL) { (result, error)  in
            XCTAssertNotNil(error)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 3, handler: nil)

    }

    func testCheck_WithNoHTTPCommand_ShouldReturnError() {
        let startURL = URL(string: "http://newlook.com")!
        let results: [ConnectionResult<URL, NetworkError>] = []

        let mock = MockConnectionManager(result: results, shouldFailCreatingHttpCommand: true)
        let sdk = TruSDK(connectionManager: mock)
        let expectation = self.expectation(description: "CheckURL Incorrect URL")
        sdk.check(url: startURL) { (result, error)  in
            XCTAssertNotNil(error)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 3, handler: nil)
    }

}
