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
        
        let reachabilityDetails = ReachabilityDetails(countryCode: "GB", networkId: "2334", networkName: "EE", products: [Product(productId: "SIM777", productType: .SIMCheck)])
        
        let reachabilityError = ReachabilityError(type: "HTTP", title: "Redirect", status: 302, detail: "Some description")
        let expectedValue = """
{"country_code":"GB","network_id":"2334","network_name":"EE","products":[{"product_id":"SIM777","product_name":"Sim Check"}]}
"""
        let actualValue = reachabilityDetails.toJsonString()
        
        //Create a ReachabilityDetails instance
        //Create an "Expected" json/string version of the reachability object
        //call toJsonString()
        //Compare the output of the method to the expected string
        XCTAssertEqual(actualValue, expectedValue)
        
        let expectedValueError = """
            {"detail":"Some description","status":302,"title":"Redirect","type":"HTTP"}
            """
        let actualValueError = reachabilityError.toJsonStringError()
        
        XCTAssertEqual(actualValueError, expectedValueError)
    }
    
}
