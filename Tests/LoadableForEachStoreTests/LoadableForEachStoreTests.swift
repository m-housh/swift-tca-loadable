import XCTest
import IdentifiedCollections
import Combine
import ComposableArchitecture
import PreviewSupport
import SnapshotTesting
import SwiftUI
@testable import LoadableList
@testable import LoadableForEachStore


final class LoadableForEachStoreTests: XCTestCase {
  
  var precision: Float!
  
  override func setUp() {
    super.setUp()
    
    self.precision = 0.99
//    isRecording = true
  }
  
  func test_environment_initialized_with_list_environment() throws {
    
    var listEnvironment = LoadableListEnvironmentFor<User, LoadError>.users
    listEnvironment.mainQueue = .immediate
    let environment = LoadableForEachEnvironment(environment: listEnvironment)
    var loaded: IdentifiedArrayOf<User>!
    let expectation = XCTestExpectation(description: "Load Users")
    var cancellable: AnyCancellable
    
    cancellable = environment.load(.init()).sink(
      receiveCompletion: { completion in
        switch completion {
        case .finished:
          break
        case let .failure(error):
          XCTFail(error.localizedDescription)
          expectation.fulfill()
        }
      },
      receiveValue: {
        loaded = $0
        expectation.fulfill()
      })
    
    wait(for: [expectation], timeout: 1)
    XCTAssertEqual(loaded, IdentifiedArrayOf<User>.init(uniqueElements: [User].users))
    cancellable.cancel()
  }
  
  func test_edit_mode_actions() {
    let scheduler = DispatchQueue.test
    let store = TestStore(
      initialState: .init(),
      reducer: testReducer,
      environment: .test(scheduler: scheduler.eraseToAnyScheduler())
    )
    store.send(.editMode(.binding(.set(\.self, .active)))) {
      $0.editMode = .active
    }
    store.send(.editMode(.binding(.set(\.self, .transient)))) {
      $0.editMode = .transient
    }
  }
  
  func test_list_actions() {
    let scheduler = DispatchQueue.test
    let store = TestStore(
      initialState: .init(loadable: .loaded(.init(uniqueElements: [User].users))),
      reducer: testReducer,
      environment: .test(scheduler: scheduler.eraseToAnyScheduler())
    )
    store.send(.list(.move(.init(integer: 0), 2))) {
      $0.loadable = .loaded([.blobJr, .blob, .blobSr])
    }
    store.send(.list(.delete(.init(integer: 1)))) {
      $0.loadable = .loaded([.blobJr, .blobSr])
    }
  }
  
  func test_loadable_actions() {
    let scheduler = DispatchQueue.test
    let store = TestStore(
      initialState: .init(),
      reducer: testReducer,
      environment: .test(scheduler: scheduler.eraseToAnyScheduler())
    )
    store.send(.loadable(.load)) {
      $0.loadable = .isLoading(previous: nil)
    }
    scheduler.advance()
    store.receive(.loadable(.loadingCompleted(.success(.init(uniqueElements: [User].users))))) {
      $0.loadable = .loaded(.init(uniqueElements: [User].users))
    }
    store.send(.loadable(.loadingCompleted(.failure(.loadingFailed)))) {
      $0.loadable = .failed(.loadingFailed)
    }
  }
  
  func test_element_actions() {
    let scheduler = DispatchQueue.test
    let store = TestStore(
      initialState: .init(loadable: .loaded(.init(uniqueElements: [User].users))),
      reducer: testReducer,
      environment: .test(scheduler: scheduler.eraseToAnyScheduler())
    )
    store.send(.element(id: User.blob.id, action: .binding(.set(\.isFavorite, true)))) {
      var users = [User].users
      users[0].isFavorite = true
      $0.loadable = .loaded(.init(uniqueElements: users))
    }
  }
  
  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  func test_snapshot() {
    let scheduler = DispatchQueue.test
    let view = LoadableForEachStore(
      store: .init(
        initialState: .init(loadable: .loaded(.init(uniqueElements: [User].users))),
        reducer: testReducer,
        environment: .test(scheduler: scheduler.eraseToAnyScheduler())
      )
    ) { store in
      WithViewStore(store) { viewStore in
        HStack {
          Text(viewStore.name)
          Spacer()
          Toggle(
            "Favorite",
            isOn: viewStore.binding(keyPath: \.isFavorite, send: UserAction.binding))
        }
      }
    }
    #if os(macOS)
    let vc = NSHostingController(rootView: view)
    assertSnapshot(
      matching: vc,
      as: .image(precision: precision, size: CGSize(width: 300, height: 300)),
      named: "macOS"
    )
    #endif
    #if os(iOS)
    assertSnapshot(
      matching: view,
      as: .image(precision: precision, layout: .fixed(width: 300, height: 300), traits: .init(userInterfaceStyle: .light)),
      named: "ios"
    )
    #endif
  }
  
  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  func test_snapshot_with_favorite() {
    let scheduler = DispatchQueue.test
    var users = [User].users
    users[0].isFavorite = true
    let view = LoadableForEachStore(
      store: .init(
        initialState: .init(loadable: .loaded(.init(uniqueElements: users))),
        reducer: testReducer,
        environment: .test(scheduler: scheduler.eraseToAnyScheduler())
      )
    ) { store in
      WithViewStore(store) { viewStore in
        HStack {
          Text(viewStore.name)
          Spacer()
          Toggle(
            "Favorite",
            isOn: viewStore.binding(keyPath: \.isFavorite, send: UserAction.binding))
        }
      }
    }
    #if os(macOS)
    let vc = NSHostingController(rootView: view)
    assertSnapshot(
      matching: vc,
      as: .image(precision: precision, size: CGSize(width: 300, height: 300)),
      named: "macOS"
    )
    #endif
    #if os(iOS)
    assertSnapshot(
      matching: view,
      as: .image(precision: precision, layout: .fixed(width: 300, height: 300), traits: .init(userInterfaceStyle: .light)),
      named: "ios"
    )
    #endif
  }
}

// MARK: - Helpers
extension LoadableForEachEnvironment where
  Element == User,
  Id == User.ID,
  LoadRequest == EmptyLoadRequest,
  Failure == LoadError
{
  static func test(scheduler: AnySchedulerOf<DispatchQueue>) -> Self {
    .init(
      load: { _ in
        Just(IdentifiedArray(uniqueElements: [User].users))
          .setFailureType(to: LoadError.self)
          .eraseToEffect()
      },
      mainQueue: scheduler
    )
  }
}

let testReducer = Reducer<
  LoadableForEachStateFor<User, LoadError>,
  LoadableForEachStoreActionFor<User, UserAction, LoadError>,
  LoadableForEachEnvironmentFor<User, LoadError>
>.empty
  .loadableForEachStore(
    state: \.self,
    action: /LoadableForEachAction.self,
    environment: { $0 },
    forEach: userReducer
  )
