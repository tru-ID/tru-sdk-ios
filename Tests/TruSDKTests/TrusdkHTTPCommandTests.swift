//
//  TrusdkHTTPCommandTests.swift
//
//
//  Created by Murat Yakici on 19/04/2021.
//

//
//  TrusdkHTTPCommandTests.swift
//
//
//  Created by Murat Yakici on 19/04/2021.
//

import XCTest
@testable import TruSDK
#if canImport(UIKit)
import UIKit
#endif

final class TrusdkHTTPCommandTests: XCTestCase {

    var connectionManager: CellularConnectionManager!

    static var allTests = [
        ("testCreateHTTPCommand_ShouldReturn_URL", testCreateHTTPCommand_ShouldReturn_URL),
        ("testCreateHTTPCommand_URLWithQuery_ShouldReturn_URL", testCreateHTTPCommand_URLWithQuery_ShouldReturn_URL),
        ("testCreateHTTPCommand_PathOnlyURL_ShouldReturn_Nil", testCreateHTTPCommand_PathOnlyURL_ShouldReturn_Nil),
        ("testCreateHTTPCommand_SchemeOnlyURL_ShouldReturn_Nil", testCreateHTTPCommand_SchemeOnlyURL_ShouldReturn_Nil),
        ("testCreateHTTPCommand_URLWithOutAHost_ShouldReturn_Nil", testCreateHTTPCommand_URLWithOutAHost_ShouldReturn_Nil),
    ]

    override func setUpWithError() throws {
           // It is called before each test method begins.
        connectionManager = CellularConnectionManager()
    }

    override func tearDownWithError() throws {
        // It is called after each test method completes.
    }

}

// MARK: - Unit Tests for createHttpCommand(..)
extension TrusdkHTTPCommandTests {

    func testCreateHTTPCommand_ShouldReturn_URL() {

        let urlString = "https://swift.org"
        let url = URL(string: urlString)!
        let expectation = httpCommand(url: url, sdkVersion: connectionManager.truSdkVersion)

        let httpCommand = connectionManager.createHttpCommand(url: url)
        XCTAssertEqual(expectation, httpCommand)
    }

    func testCreateHTTPCommand_URLWithQuery_ShouldReturn_URL() {

        let urlString = "https://swift.org/index.html?search=keyword"

        let url = URL(string: urlString)!

        let expectation = httpCommand(url: url, sdkVersion: connectionManager.truSdkVersion)

        let httpCommand = connectionManager.createHttpCommand(url: url)
        XCTAssertEqual(expectation, httpCommand)
    }

    func testCreateHTTPCommand_PathOnlyURL_ShouldReturn_Nil() {

        let urlString = "/"

        let url = URL(string: urlString)!

        let command = connectionManager.createHttpCommand(url: url)

        XCTAssertNil(command)
    }

    func testCreateHTTPCommand_SchemeOnlyURL_ShouldReturn_Nil() {
        let urlString = "http://"

        let url = URL(string: urlString)!

        let command = connectionManager.createHttpCommand(url: url)

        XCTAssertNil(command)
    }

    func testCreateHTTPCommand_URLWithOutAHost_ShouldReturn_Nil() {
        let connectionManager = CellularConnectionManager()

        let urlString = "/user/comments/msg?q=key"

        let url = URL(string: urlString)!

        let command = connectionManager.createHttpCommand(url: url)

        XCTAssertNil(command)
    }

}
