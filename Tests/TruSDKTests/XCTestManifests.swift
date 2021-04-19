import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(TrusdkHTTPCommandTests.allTests),
        testCase(TrusdkParseRedirectTests.allTests),
        testCase(TrusdkCheckTests.allTests),
    ]
}
#endif
