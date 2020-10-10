import XCTest
@testable import TCA_Loadable

final class TCA_LoadableTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(TCA_Loadable().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
