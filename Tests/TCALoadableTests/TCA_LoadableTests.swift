import XCTest
import Combine
import ComposableArchitecture
import SwiftUI
import SnapshotTesting
@testable import TCALoadable


final class TCA_LoadableTests: XCTestCase {
  
  func test_loadable_equality() {
    XCTAssertEqual(Loadable<Int, TestError>.notRequested, Loadable<Int, TestError>.notRequested)
    XCTAssertEqual(Loadable<Int, TestError>.loaded(1), Loadable<Int, TestError>.loaded(1))
    XCTAssertEqual(Loadable<Int, TestError>.isLoading(previous: nil), Loadable<Int, TestError>.isLoading(previous: nil))
    XCTAssertEqual(Loadable<Int, TestError>.isLoading(previous: 1), Loadable<Int, TestError>.isLoading(previous: 1))
    XCTAssertEqual(Loadable<Int, TestError>.failed(TestError.failed), Loadable<Int, TestError>.failed(TestError.failed))
    
    XCTAssertNotEqual(Loadable<Int, TestError>.loaded(1), Loadable<Int, TestError>.isLoading(previous: 1))
    
  }
  
  func test_loadable_value() {
    XCTAssertEqual(Loadable<Int, TestError>.loaded(1).rawValue, 1)
    XCTAssertEqual(Loadable<Int, TestError>.isLoading(previous: 1).rawValue, 1)
    XCTAssertNil(Loadable<Int, TestError>.isLoading(previous: nil).rawValue)
    XCTAssertNil(Loadable<Int, TestError>.notRequested.rawValue)
    XCTAssertNil(Loadable<Int, TestError>.failed(TestError.failed).rawValue)
  }
  
  func test_loadable_action_equality() {
    XCTAssertEqual(LoadableAction<Int, TestError>.load, LoadableAction<Int, TestError>.load)
    XCTAssertEqual(LoadableAction<Int, TestError>.loadingCompleted(.success(1)), LoadableAction<Int, TestError>.loadingCompleted(.success(1)))
    XCTAssertEqual(LoadableAction<Int, TestError>.loadingCompleted(.failure(TestError.failed)), LoadableAction<Int, TestError>.loadingCompleted(.failure(TestError.failed)))
    
    XCTAssertNotEqual(LoadableAction<Int, TestError>.load, LoadableAction.loadingCompleted(.success(1)))
  }
  
  func test_loadable_actions() {
    let scheduler = DispatchQueue.test
    let environment = TestEnvironment(
      mainQueue: scheduler.eraseToAnyScheduler(),
      failOnLoad: false
    )
    let store = TestStore(
      initialState: Loadable<[Int], TestError>.notRequested,
      reducer: Reducer.empty.loadable(
        state: \.self,
        action: /LoadableAction<[Int], TestError>.self,
        environment: { _ in environment }
      ),
      environment: environment
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
    let scheduler = DispatchQueue.test
    let environment = TestEnvironment(mainQueue: scheduler.eraseToAnyScheduler(), failOnLoad: true)
    let store = TestStore(
      initialState: Loadable<[Int], TestError>.notRequested,
      reducer: Reducer.empty.loadable(
        state: \.self,
        action: /LoadableAction.self,
        environment: { _ in environment }
      ),
      environment: environment
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
    let scheduler = DispatchQueue.test
    let environment = TestEnvironment(
      mainQueue: scheduler.eraseToAnyScheduler(),
      failOnLoad: false
    )
    let store = Store(
      initialState: Loadable<[Int], TestError>.notRequested,
      reducer: Reducer.empty.loadable(
        state: \.self,
        action: /LoadableAction.self,
        environment: { _ in environment }
      ),
      environment: environment
    )
    
    let view = LoadableView(store: store, failure: TestError.self) { store in
      WithViewStore(store) { viewStore in
        List {
          ForEach(viewStore.state, id: \.self) { number in
            Text("\(number)")
          }
        }
      }
    }
//    errorView: {
//      Text($0.localizedDescription)
//    }
    
    let vc = NSHostingController(rootView: view)
    
    assertSnapshot(matching: vc, as: .image(precision: 1, size: CGSize(width: 100, height: 100)), record: false)
    
  }
  
  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  func test_loadable_progress_view_when_loaded() {
    let scheduler = DispatchQueue.test
    let store = Store(
      initialState: Loadable<[Int], TestError>.loaded([1, 2, 3]),
      reducer: Reducer.empty.loadable(
        state: \.self,
        action: /LoadableAction.self
      ),
      environment: TestEnvironment(
        mainQueue: scheduler.eraseToAnyScheduler(),
        failOnLoad: false
      )
    )
    
    let view = LoadableView(store: store) { store in
      WithViewStore(store) { viewStore in
        List {
          ForEach(viewStore.state, id: \.self) { number in
            Text("\(number)")
          }
        }
      }
    }
    
    let vc = NSHostingController(rootView: view)
    
    assertSnapshot(matching: vc, as: .image(precision: 1, size: CGSize(width: 100, height: 100)), record: false)
    
  }
  
  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  func test_loadable_progress_view_when_isLoading_with_no_previous_state() {
    let scheduler = DispatchQueue.test
    let environment = TestEnvironment(
      mainQueue: scheduler.eraseToAnyScheduler(),
      failOnLoad: false
    )
    let store = Store(
      initialState: Loadable<[Int], TestError>.isLoading(previous: nil),
      reducer: Reducer.empty.loadable(
        state: \.self,
        action: /LoadableAction<[Int], TestError>.self,
        environment: { _ in environment }
      ),
      environment: environment
    )
    
    let view = LoadableView(store: store) { store in
      WithViewStore(store) { viewStore in
        List {
          ForEach(viewStore.state, id: \.self) { number in
            Text("\(number)")
          }
        }
      }
    }
    
    let vc = NSHostingController(rootView: view)
    
    assertSnapshot(matching: vc, as: .image(precision: 1, size: CGSize(width: 100, height: 100)), record: false)
    
  }
  
  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  func test_loadable_progress_view_when_isLoading_with_previous_state() {
    let scheduler = DispatchQueue.test
    let store = Store(
      initialState: Loadable<[Int], TestError>.isLoading(previous: [1, 2, 3]),
      reducer: Reducer.empty.loadable(
        state: \.self,
        action: /LoadableAction.self
      ),
      environment: TestEnvironment(
        mainQueue: scheduler.eraseToAnyScheduler(),
        failOnLoad: false
      )
    )
    
    let view = LoadableView(store: store) { store in
      WithViewStore(store) { viewStore in
        List {
          ForEach(viewStore.state, id: \.self) { number in
            Text("\(number)")
          }
        }
      }
    }

    let vc = NSHostingController(rootView: view)
    
    assertSnapshot(matching: vc, as: .image(precision: 1, size: CGSize(width: 100, height: 100)), record: false)
    
  }
  
  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  func test_loadable_progress_view_when_failed() {
    let scheduler = DispatchQueue.test
    let store = Store(
      initialState: Loadable<[Int], TestError>.failed(TestError.failed),
      reducer: Reducer.empty.loadable(
        state: \.self,
        action: /LoadableAction.self
      ),
      environment: TestEnvironment(
        mainQueue: scheduler.eraseToAnyScheduler(),
        failOnLoad: false
      )
    )
    
    let view = LoadableView(store: store) { store in
      WithViewStore(store) { viewStore in
        List {
          ForEach(viewStore.state, id: \.self) { number in
            Text("\(number)")
          }
        }
      }
    }
    
    let vc = NSHostingController(rootView: view)
    
    assertSnapshot(matching: vc, as: .image(precision: 1, size: CGSize(width: 100, height: 100)), record: false)
    
  }
  
  func test_loadable_dynamic_lookup() {
    struct User: Equatable {
      var name: String
    }
    let user = User(name: "blob")
    
    let loaded = Loadable<User, TestError>.loaded(user)
    XCTAssertEqual(loaded.name, "blob")
    
    let isLoading = Loadable<User, TestError>.isLoading(previous: user)
    XCTAssertEqual(isLoading.name, "blob")
  }
}

enum TestError: Error, Equatable {
  case failed
}

struct TestEnvironment: LoadableEnvironmentRepresentable {
  
  typealias LoadedValue = [Int]
  typealias LoadRequest = EmptyLoadRequest
  typealias Failure = TestError

  
  let mainQueue: AnySchedulerOf<DispatchQueue>
  let failOnLoad: Bool
  var load: (EmptyLoadRequest) -> Effect<[Int], Failure>
  
  init(
    mainQueue: AnySchedulerOf<DispatchQueue>,
    failOnLoad: Bool = false
  ) {
    self.failOnLoad = failOnLoad
    self.mainQueue = mainQueue
    self.load = { _ in
      guard !failOnLoad else {
        return Fail(error: TestError.failed)
          .delay(for: .seconds(1), scheduler: mainQueue)
          .eraseToEffect()
      }
      
      return Just([1, 2, 3])
        .delay(for: .seconds(1), scheduler: mainQueue)
        .setFailureType(to: TestError.self)
        .eraseToEffect()
    }
  }
}

//struct TestEnvironmentWithStringRequest: LoadableEnvironmentRepresentable {
//
//  typealias LoadedValue = String
//  typealias LoadRequest = String?
//
//  let mainQueue: AnySchedulerOf<DispatchQueue>
//  let failOnLoad: Bool
//  var load: (String?) -> Effect<String, Error>
//
//  init(
//    mainQueue: AnySchedulerOf<DispatchQueue>,
//    failOnLoad: Bool = false
//  ) {
//    self.failOnLoad = failOnLoad
//    self.mainQueue = mainQueue
//    self.load = { string in
//      guard !failOnLoad else {
//        return Fail(error: TestError.failed)
//          .delay(for: .seconds(1), scheduler: mainQueue)
//          .eraseToEffect()
//      }
//
//      guard let string = string else {
//        return Fail(error: TestError.failed)
//          .delay(for: .seconds(1), scheduler: mainQueue)
//          .eraseToEffect()
//      }
//
//      return Just(string)
//        .delay(for: .seconds(1), scheduler: mainQueue)
//        .setFailureType(to: Error.self)
//        .eraseToEffect()
//    }
//  }
//}
//struct LoadableView2Environment {
//  let load: () -> Effect<[Int], Error>
//  let failOnLoad: Bool
//  let mainQueue: AnySchedulerOf<DispatchQueue>
//
//  init(
//    failOnLoad: Bool = false,
//    mainQueue: AnySchedulerOf<DispatchQueue>
//  ) {
//    self.failOnLoad = failOnLoad
//    self.mainQueue = mainQueue
//
//    if failOnLoad {
//      self.load = { Fail(error: TestError.failed)
//        .delay(for: .seconds(1), scheduler: mainQueue)
//        .eraseToEffect()
//      }
//    } else {
//      self.load = {
//        Just([1, 2, 3])
//          .delay(for: .seconds(1), scheduler: mainQueue)
//          .setFailureType(to: Error.self)
//          .eraseToEffect()
//      }
//    }
//  }
//}
//
//enum LoadableView2Action: Equatable {
//  case load
//  case loadingCompleted(Result<[Int], TestError>)
//}
//
//let loadableView2Reducer = Reducer<
//  Loadable<[Int], TestError>,
//  LoadableView2Action,
//  LoadableView2Environment
//> { state, action, environment in
//  switch action {
//  case .load:
//    return environment.load()
//      .mapError({ _ in TestError.failed })
//      .catchToEffect()
//      .map(LoadableView2Action.loadingCompleted)
//
//  case let .loadingCompleted(.success(values)):
//    state = .loaded(values)
//    return .none
//
//  case let .loadingCompleted(.failure(error)):
//    state = .failed(error)
//    return .none
//  }
//}

struct User: Equatable, Identifiable {
  let id: UUID = UUID()
  var name: String
  
  static let blob = User.init(name: "blob")
  static let blobJr = User.init(name: "blob-jr")
  static let blobSr = User.init(name: "blob-sr")
}

struct UserEnvironment {
  
  let load: (String?) -> Effect<[User], Error> = { query in
    let users = [User.blob, .blobJr, .blobSr]
    if let query = query {
      return Effect(value: users.filter({ $0.name == query }))
    }
    return Effect(value: users)
  }
  
  let mainQueue: AnySchedulerOf<DispatchQueue>
  
}

//var loadedView3 = LoadableView3.init(
//  store: .init(
//    initialState: Loadable<[Int], TestError>.notRequested,
//    reducer: loadableView2Reducer,
//    environment: LoadableView2Environment.init(mainQueue: .main)
//  ),
//  onLoad: .load,
//  failure: TestError.self,
//  loadedView: { store in
//    WithViewStore(store) { viewStore in
//      List(viewStore.state, id: \.self) { num in
//        Text("\(num)")
//      }
//    }
//  })
//  .notRequested { _ in EmptyView() }
//  .isLoading { _ in EmptyView() }
//  .error { _ in EmptyView() }
