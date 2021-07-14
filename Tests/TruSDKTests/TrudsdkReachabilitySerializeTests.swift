//
//  TrusdkReachabilitySerializeTests.swift
//  
//
//  Created by Didem Yakici on 14/07/2021.
//

import XCTest
@testable import TruSDK

final class TrusdkReachabilitySerializeTests: XCTestCase {

    static var allTests = [
        ("testReachability_WithoutErrors", testReachability_WithoutErrors),
    ]

    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
        // It is called after each test method completes.
    }

}

extension TrusdkReachabilitySerializeTests {
    func testReachability_WithoutErrors() {
        //Create a ReachabilityDetails instance
        //Create an "Expected" json/string version of the reachability object
        //call toJsonString()
        //Compare the output of the method to the expected string
        XCTAssertEqual("", "")
    }
}
