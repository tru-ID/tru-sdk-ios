import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(TrusdkHTTPCommandTests.allTests),
        testCase(TrusdkParseResponseTests.allTests),
        testCase(TrusdkCheckTests.allTests),
    ]
}
#endif
