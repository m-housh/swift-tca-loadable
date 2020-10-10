import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(TCA_LoadableTests.allTests),
    ]
}
#endif
