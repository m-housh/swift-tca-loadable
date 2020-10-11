import XCTest
import Combine
import ComposableArchitecture
import SwiftUI
import SnapshotTesting
@testable import TCALoadable

final class TCA_LoadableTests: XCTestCase {
    
    func test_loadable_equality() {
        XCTAssertEqual(Loadable<Int>.notRequested, Loadable<Int>.notRequested)
        XCTAssertEqual(Loadable<Int>.loaded(1), Loadable<Int>.loaded(1))
        XCTAssertEqual(Loadable<Int>.isLoading(previous: nil), Loadable<Int>.isLoading(previous: nil))
        XCTAssertEqual(Loadable<Int>.isLoading(previous: 1), Loadable<Int>.isLoading(previous: 1))
        XCTAssertEqual(Loadable<Int>.failed(TestError.failed), Loadable<Int>.failed(TestError.failed))

        XCTAssertNotEqual(Loadable<Int>.loaded(1), Loadable<Int>.isLoading(previous: 1))

    }
    
    func test_loadable_value() {
        XCTAssertEqual(Loadable<Int>.loaded(1).value, 1)
        XCTAssertEqual(Loadable<Int>.isLoading(previous: 1).value, 1)
        XCTAssertNil(Loadable<Int>.isLoading(previous: nil).value)
        XCTAssertNil(Loadable<Int>.notRequested.value)
        XCTAssertNil(Loadable<Int>.failed(TestError.failed).value)
    }
    
    func test_loadable_action_equality() {
        XCTAssertEqual(LoadableAction<Int>.load, LoadableAction<Int>.load)
        XCTAssertEqual(LoadableAction<Int>.loadingCompleted(.success(1)), LoadableAction<Int>.loadingCompleted(.success(1)))
        XCTAssertEqual(LoadableAction<Int>.loadingCompleted(.failure(TestError.failed)), LoadableAction<Int>.loadingCompleted(.failure(TestError.failed)))
        
        XCTAssertNotEqual(LoadableAction<Int>.load, LoadableAction.loadingCompleted(.success(1)))
    }
    
    func test_loadable_actions() {
        let scheduler = DispatchQueue.testScheduler
        
        let store = TestStore(
            initialState: Loadable<[Int]>.notRequested,
            reducer: Reducer.empty.loadable(
                state: \.self,
                action: /LoadableAction.self,
                environment: { $0 }
            ),
            environment: TestEnvironment(
                mainQueue: scheduler.eraseToAnyScheduler(),
                failOnLoad: false
            )
            .eraseToAnyLoadableEnvironment()
        )
        
        store.assert(
            .send(.load) {
                $0 = .isLoading(previous: nil)
            },
            .do { scheduler.advance(by: .seconds(1)) },
            .receive(.loadingCompleted(.success([1, 2, 3]))) {
                $0 = .loaded([1, 2, 3])
            }
        )
    }
    
    func test_loadable_actions_fail_on_load() {
        let scheduler = DispatchQueue.testScheduler
        
        let store = TestStore(
            initialState: Loadable<[Int]>.notRequested,
            reducer: Reducer.empty.loadable(
                state: \.self,
                action: /LoadableAction.self,
                environment: { $0 }
            ),
            environment: TestEnvironment(
                mainQueue: scheduler.eraseToAnyScheduler(),
                failOnLoad: true
            )
        )
        
        store.assert(
            .send(.load) {
                $0 = .isLoading(previous: nil)
            },
            .do { scheduler.advance(by: .seconds(1)) },
            .receive(.loadingCompleted(.failure(TestError.failed))) {
                $0 = .failed(TestError.failed)
            }
        )
    }
    
    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    func test_loadable_progress_view_when_notRequested() {
        let scheduler = DispatchQueue.testScheduler
        let store = Store(
            initialState: Loadable<[Int]>.notRequested,
            reducer: Reducer.empty.loadable(
                state: \.self,
                action: /LoadableAction.self,
                environment: { $0 }
            ),
            environment: TestEnvironment(
                mainQueue: scheduler.eraseToAnyScheduler(),
                failOnLoad: false
            )
        )

        let view = LoadableProgressView(store: store) { numbers in
            List {
                ForEach(numbers, id: \.self) { number in
                    Text("\(number)")
                }
            }
        }
        errorView: {
            Text($0.localizedDescription)
        }
        
        let vc = NSHostingController(rootView: view)
        
        assertSnapshot(matching: vc, as: .image(precision: 1, size: CGSize(width: 100, height: 100)))
        
    }
    
    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    func test_loadable_progress_view_when_loaded() {
        let scheduler = DispatchQueue.testScheduler
        let store = Store(
            initialState: Loadable<[Int]>.loaded([1, 2, 3]),
            reducer: Reducer.empty.loadable(
                state: \.self,
                action: /LoadableAction.self,
                environment: { $0 }
            ),
            environment: TestEnvironment(
                mainQueue: scheduler.eraseToAnyScheduler(),
                failOnLoad: false
            )
        )

        let view = LoadableProgressView(store: store) { numbers in
            List {
                ForEach(numbers, id: \.self) { number in
                    Text("\(number)")
                }
            }
        }
        errorView: {
            Text($0.localizedDescription)
        }
        
        let vc = NSHostingController(rootView: view)
        
        assertSnapshot(matching: vc, as: .image(precision: 1, size: CGSize(width: 100, height: 100)))
        
    }
    
    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    func test_loadable_progress_view_when_isLoading_with_no_previous_state() {
        let scheduler = DispatchQueue.testScheduler
        let store = Store(
            initialState: Loadable<[Int]>.isLoading(previous: nil),
            reducer: Reducer.empty.loadable(
                state: \.self,
                action: /LoadableAction.self,
                environment: { $0 }
            ),
            environment: TestEnvironment(
                mainQueue: scheduler.eraseToAnyScheduler(),
                failOnLoad: false
            )
        )

        let view = LoadableProgressView(store: store) { numbers in
            List {
                ForEach(numbers, id: \.self) { number in
                    Text("\(number)")
                }
            }
        }
        errorView: {
            Text($0.localizedDescription)
        }
        
        let vc = NSHostingController(rootView: view)
        
        assertSnapshot(matching: vc, as: .image(precision: 1, size: CGSize(width: 100, height: 100)))
        
    }
    
    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    func test_loadable_progress_view_when_isLoading_with_previous_state() {
        let scheduler = DispatchQueue.testScheduler
        let store = Store(
            initialState: Loadable<[Int]>.isLoading(previous: [1, 2, 3]),
            reducer: Reducer.empty.loadable(
                state: \.self,
                action: /LoadableAction.self,
                environment: { $0 }
            ),
            environment: TestEnvironment(
                mainQueue: scheduler.eraseToAnyScheduler(),
                failOnLoad: false
            )
        )

        let view = LoadableProgressView(store: store) { numbers in
            List {
                ForEach(numbers, id: \.self) { number in
                    Text("\(number)")
                }
            }
        }
        errorView: {
            Text($0.localizedDescription)
        }
        
        let vc = NSHostingController(rootView: view)
        
        assertSnapshot(matching: vc, as: .image(precision: 1, size: CGSize(width: 100, height: 100)))
        
    }
    
    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    func test_loadable_progress_view_when_failed() {
        let scheduler = DispatchQueue.testScheduler
        let store = Store(
            initialState: Loadable<[Int]>.failed(TestError.failed),
            reducer: Reducer.empty.loadable(
                state: \.self,
                action: /LoadableAction.self,
                environment: { $0 }
            ),
            environment: TestEnvironment(
                mainQueue: scheduler.eraseToAnyScheduler(),
                failOnLoad: false
            )
        )

        let view = LoadableProgressView(store: store) { numbers in
            List {
                ForEach(numbers, id: \.self) { number in
                    Text("\(number)")
                }
            }
        }
        errorView: {
            Text($0.localizedDescription)
        }
        
        let vc = NSHostingController(rootView: view)
        
        assertSnapshot(matching: vc, as: .image(precision: 1, size: CGSize(width: 100, height: 100)))
        
    }

    static var allTests = [
        ("test_loadable_equality", test_loadable_equality),
    ]
}

enum TestError: Error {
    case failed
}

struct TestEnvironment: LoadableEnvironment {
    typealias LoadedValue = [Int]
    
    let mainQueue: AnySchedulerOf<DispatchQueue>
    let failOnLoad: Bool
    
    func load() -> Effect<[Int], Error> {
        guard !failOnLoad else {
            return Fail(error: TestError.failed)
                .delay(for: .seconds(1), scheduler: mainQueue)
                .eraseToEffect()
        }
        
        return Just([1, 2, 3])
            .delay(for: .seconds(1), scheduler: mainQueue)
            .setFailureType(to: Error.self)
            .eraseToEffect()
    }
    
}
