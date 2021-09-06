//
//  Test.m
//  
//
//  Created by Murat Yakici on 07/06/2021.
//

import XCTest
import Network
@testable import TruSDK

final class TrusdkDeviceIPTests: XCTestCase {

    static var allTests = [
        ("testDeviceIP_Given_NoErrors_isReachable_ShouldReturn_Details", testDeviceIP_Given_NoErrors_isReachable_ShouldReturn_Details),
    ]

    var reachabilityDetails = ReachabilityDetails(countryCode: "GB", networkId: "2334", networkName: "EE", products: [Product(productId: "SIM777", productType: .SIMCheck)])

    var reachabilityError = ReachabilityError(type: "HTTP", title: "Redirect", status: 302, detail: "Some description")
    

    lazy var playList: [ConnectionResult<URL, ReachabilityDetails, ReachabilityError>] = {
        [
         .success(reachabilityDetails),
         .failure(reachabilityError)
        ]
    }()

    override func setUpWithError() throws {
        // It is called before each test method begins.
    }

    override func tearDownWithError() throws {
        // It is called after each test method completes.
    }


}

extension TrusdkDeviceIPTests {

    func testDeviceIP_Given_NoErrors_isReachable_ShouldReturn_Details() {
        let mock = MockDeviceIPConnectionManager(result: playList[0])
        let sdk = TruSDK(connectionManager: mock)
        let expectation = self.expectation(description: "Device IP Request")

        sdk.isReachable { [self] result in
            switch result {
            case .success(let details): do {
                XCTAssertNotNil(details)
                XCTAssertEqual(reachabilityDetails, details)
            }
            case .failure(_): XCTFail()
            }

            expectation.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testDeviceIP_Given_NotReachable_ShouldReturn_Error() {
        let mock = MockDeviceIPConnectionManager(result: playList[1])
        let sdk = TruSDK(connectionManager: mock)
        let expectation = self.expectation(description: "Device IP Request")

        sdk.isReachable { [self] result in
            switch result {
            case .success(_): XCTFail()
            case .failure(let error): do {
                XCTAssertNotNil(error)
                XCTAssertEqual(reachabilityError, error)
            }
            }

            expectation.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }


    func testDeviceIP_Given_ReceivedARedirect_ShouldReturn_Error() {
        let mock = MockDeviceIPConnectionManager(result: playList[1])
        let sdk = TruSDK(connectionManager: mock)
        let expectation = self.expectation(description: "Device IP Request")

        sdk.isReachable { result in
            switch result {
            case .success(_): XCTFail()
            case .failure(let error): do {
                XCTAssertNotNil(error)
            }
            }

            expectation.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testDeviceIP_Given_UnknownProblem_ShouldReturn_Error() {
        let mock = MockDeviceIPConnectionManager(result: playList[1])
        let sdk = TruSDK(connectionManager: mock)
        let expectation = self.expectation(description: "Device IP Request")

        sdk.isReachable { result in
            switch result {
            case .success(_): XCTFail()
            case .failure(let error): do {
                XCTAssertNotNil(error)
            }
            }

            expectation.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testDeviceIP_isReachableClosure_ShouldBeCalled_OnMainThread() {
        let mock = MockDeviceIPConnectionManager(result: playList[0])
        let sdk = TruSDK(connectionManager: mock)
        let expectation = self.expectation(description: "Device IP Request")

        sdk.isReachable { result in
            XCTAssertTrue(Thread.isMainThread)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

}
