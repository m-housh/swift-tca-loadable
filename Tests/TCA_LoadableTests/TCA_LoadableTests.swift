import XCTest
@testable import TCA_Loadable

final class TCA_LoadableTests: XCTestCase {
    
    func test_loadable_equality() {
        XCTAssertEqual(Loadable<Int>.notRequested, Loadable<Int>.notRequested)
        XCTAssertEqual(Loadable<Int>.loaded(1), Loadable<Int>.loaded(1))
        XCTAssertEqual(Loadable<Int>.isLoading(previous: nil), Loadable<Int>.isLoading(previous: nil))
        XCTAssertEqual(Loadable<Int>.isLoading(previous: 1), Loadable<Int>.isLoading(previous: 1))
        XCTAssertEqual(Loadable<Int>.failed(TestError.failed), Loadable<Int>.failed(TestError.failed))

        XCTAssertNotEqual(Loadable<Int>.loaded(1), Loadable<Int>.isLoading(previous: 1))

    }
    
    func test_loadable_action_equality() {
        XCTAssertEqual(LoadableAction<Int>.load, LoadableAction<Int>.load)
        XCTAssertEqual(LoadableAction<Int>.loadingCompleted(.success(1)), LoadableAction<Int>.loadingCompleted(.success(1)))
        XCTAssertEqual(LoadableAction<Int>.loadingCompleted(.failure(TestError.failed)), LoadableAction<Int>.loadingCompleted(.failure(TestError.failed)))
        
        XCTAssertNotEqual(LoadableAction<Int>.load, LoadableAction.loadingCompleted(.success(1)))


    }

    static var allTests = [
        ("test_loadable_equality", test_loadable_equality),
    ]
}

enum TestError: Error {
    case failed
}
