//
//  TrusdkCheckTests.swift
//
//
//  Created by Murat Yakici on 20/04/2021.
//

import XCTest
@testable import TruSDK

final class TrusdkDecodeTests: XCTestCase {

    var connectionManager: CellularConnectionManager!

    static var allTests = [
        ("testDecode_Given_ResponseWithUTF8Encoding_ShouldReturn_Response", testDecode_Given_ResponseWithUTF8Encoding_ShouldReturn_Response),

    ]

    override func setUpWithError() throws {
           // It is called before each test method begins.
        connectionManager = CellularConnectionManager()
    }

    override func tearDownWithError() throws {
        // It is called after each test method completes.
    }


}

extension TrusdkDecodeTests {

    func testDecode_Given_ResponseWithUTF8Encoding_ShouldReturn_Response() {
        let data = "🙃".data(using: .utf8)
        let decodedReponse = connectionManager.decodeResponse(data: data!)
        XCTAssertNotNil(decodedReponse)
        XCTAssertEqual("🙃", decodedReponse)
    }

    func testDecode_Given_ResponseWithNonUTF8Encoding_ShouldFallbackTo_ASCII() {
        // Given a Non UTF-8 encoded response
        // Call the decode method
        //Test if actual is ASCII
        let data = generateNONEncodedData()
        let decodedReponse = connectionManager.decodeResponse(data: data)
        XCTAssertNotNil(decodedReponse)
    }

}


func generateASCIIEncodedData() -> Data {
    let respose = """
    HTTP/1.1 400 Peticion incorrecta
    Server: Apache-Coyote/1.1
    date: Tue, 20 Apr 2021 15:57:49 GMT
    content-language: en
    Content-Type: text/html;charset=utf-8
    Content-Length: 435
    Connection: close
    """
    return respose.data(using: .ascii)!
}


func generateNONEncodedData() -> Data {
    let response = String("7ビット及び8ビットの2バイト情報交換用符号化漢字集合")
    return response.data(using: .japaneseEUC)!
}

