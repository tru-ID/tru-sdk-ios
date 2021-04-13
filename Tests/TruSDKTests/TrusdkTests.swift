import XCTest
@testable import TruSDK

final class TrusdkTests: XCTestCase {
    func testDeprecatedOpenChecUrl_WithIncorrectURL() {
        let mock = MockConnectionManager()
        let sdk = TruSDK(connectionManager: mock)
        let actual = 6
        let expected = 6
        let expectation = self.expectation(description: "CheckURL Incorrect URL")
        sdk.openCheckUrl(url: "") { (result) in
            expectation.fulfill()
            
        }
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertEqual(expected, actual)
    }

    static var allTests = [
        ("testDeprecatedOpenChecUrl_WithIncorrectURL", testDeprecatedOpenChecUrl_WithIncorrectURL),
    ]
}

class MockConnectionManager: ConnectionManager {
    func openCheckUrl(url: URL, completion: @escaping (Any?) -> Void) {
        //
    }

    func jsonResponse(url: URL, completion: @escaping ([String : Any]?) -> Void) {
        //
    }

    func jsonPropertyValue(for key: String, from url: URL, completion: @escaping (String) -> Void) {
        //
    }

}

