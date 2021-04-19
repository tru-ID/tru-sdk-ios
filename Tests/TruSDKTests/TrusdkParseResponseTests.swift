//
//  TrusdkParseResponseTests.swift
//  
//
//  Created by Murat Yakici on 19/04/2021.
//

import XCTest
@testable import TruSDK
#if canImport(UIKit)
import UIKit
#endif

final class TrusdkParseResponseTests: XCTestCase {
    static var allTests = [
        ("testParseRedirect_ShouldReturn_CorrectRedirectURL",testParseRedirect_ShouldReturn_CorrectRedirectURL),
    ]

    override func setUpWithError() throws {
           // It is called before each test method begins.
    }

    override func tearDownWithError() throws {
        // It is called after each test method completes.
    }
    
}

extension TrusdkParseResponseTests {
    func testParseRedirect_ShouldReturn_CorrectRedirectURL() {
        let connectionManager = CellularConnectionManager()
        let expectedRedirectURL = "https://www.newlook.com/uk"
        let response = http3XXResponse(code: .movedPermanently, url: expectedRedirectURL)
        let actualRedirectURL = connectionManager.parseRedirect(requestUrl: URL(string:"https://newlook.com")!, response: response)
        XCTAssertNotNil(actualRedirectURL)
        XCTAssertEqual(actualRedirectURL?.absoluteString, expectedRedirectURL)
    }
}
