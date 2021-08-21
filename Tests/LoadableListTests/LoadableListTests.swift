import XCTest
import Combine
import ComposableArchitecture
import PreviewSupport
import SnapshotTesting
import SwiftUI

@testable import LoadableList
import LoadableView

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
final class LoadableListTests: XCTestCase {
  
  // allow some deviation because test environments, ci, M1 mac's, etc.
  var precision: Float!
  
  override func setUp() {
    super.setUp()
    self.precision = 0.99
//    isRecording = true
  }
  
  func test_loadable_list_load_actions() {
    let scheduler = DispatchQueue.test
    let store = TestStore(
      initialState: .init(),
      reducer: usersReducer,
      environment: .test(scheduler: scheduler.eraseToAnyScheduler())
    )
    
    store.send(.loadable(.load)) {
      $0.loadable = .isLoading(previous: nil)
    }
    scheduler.advance()
    store.receive(.loadable(.loadingCompleted(.success([.blob, .blobJr, .blobSr])))) {
      $0.loadable = .loaded([.blob, .blobJr, .blobSr])
    }
    store.send(.loadable(.loadingCompleted(.failure(.loadingFailed)))) {
      $0.loadable = .failed(.loadingFailed)
    }
  }
  
  func test_loadable_list_list_actions() {
    let store = TestStore(
      initialState: .init(loadable: .loaded([User.blob, .blobJr, .blobSr])),
      reducer: usersReducer,
      environment: .failing
    )
    store.send(.list(.move(.init(integer: 0), 2))) {
      $0.loadable = .loaded([
        .blobJr, .blob, .blobSr
      ])
    }
    store.send(.list(.delete(.init(integer: 0)))) {
      $0.loadable = .loaded([.blob, .blobSr])
    }
  }
  
  func test_loadable_list_editMode_actions() {
    let store = TestStore(
      initialState: .init(),
      reducer: usersReducer,
      environment: .failing
    )

    store.send(.editMode(.binding(.set(\.self, .active)))) {
      $0.editMode = .active
    }
    
  }
  
  func test_loadable_list_with_custom_load_request() {
    let scheduler = DispatchQueue.test
    let store = TestStore(
      initialState: UserStateWithCustomRequesState(list: .init(), nameQuery: nil),
      reducer: userReducerWithCustomRequest,
      environment: .testWithCustomRequest(scheduler: scheduler.eraseToAnyScheduler())
    )
    store.send(.loadable(.load)) {
      $0.list.loadable = .isLoading(previous: nil)
    }
    scheduler.advance()
    store.receive(.loadable(.loadingCompleted(.success([.blob, .blobJr, .blobSr])))) {
      $0.list.loadable = .loaded([.blob, .blobJr, .blobSr])
    }
  }
  
  func test_loadable_list_with_custom_load_request_and_query() {
    let scheduler = DispatchQueue.test
    let store = TestStore(
      initialState: UserStateWithCustomRequesState(list: .init(), nameQuery: "blob"),
      reducer: userReducerWithCustomRequest,
      environment: .testWithCustomRequest(scheduler: scheduler.eraseToAnyScheduler())
    )
    store.send(.loadable(.load)) {
      $0.list.loadable = .isLoading(previous: nil)
    }
    scheduler.advance()
    store.receive(.loadable(.loadingCompleted(.success([.blob])))) {
      $0.list.loadable = .loaded([.blob])
    }
  }
  
  func test_loadable_list_while_not_editing() {
    
    let view = LoadableView(
      store: .init(
        initialState: .init(),
        reducer: usersReducer,
        environment: .test(scheduler: .immediate)
      )
    ) { user in
      Text(user.name)
    }
    
    #if os(macOS)
    let vc = NSHostingController(rootView: view)
    assertSnapshot(matching: vc, as: .image(precision: precision, size: CGSize(width: 300, height: 300)))
    #endif
    #if os(iOS)
    assertSnapshot(matching: view, as: .image(precision: precision, layout: .fixed(width: 300, height: 300), traits: .init(userInterfaceStyle: .light)), named: "ios-not-editing")
    #endif
  }
  
  func test_loadable_list_while_editing() {
    
    let view = LoadableView(
      store: .init(
        initialState: .init(editMode: .active),
        reducer: usersReducer,
        environment: .test(scheduler: .immediate)
      )
    ) { user in
      Text(user.name)
    }
    
    #if os(macOS)
    let vc = NSHostingController(rootView: view)
    assertSnapshot(matching: vc, as: .image(precision: precision, size: CGSize(width: 300, height: 300)))
    #endif
    #if os(iOS)
    assertSnapshot(matching: view, as: .image(layout: .fixed(width: 300, height: 300), traits: .init(userInterfaceStyle: .light)), named: "ios-editing")
    #endif
  }
}

struct TestUserLoadRequest {
  var name: String?
}

extension LoadableListEnvironment where Element == User, LoadRequest == TestUserLoadRequest, Failure == LoadError {
  static func testWithCustomRequest(scheduler: AnySchedulerOf<DispatchQueue>) -> Self {
    .init(
      load: { request in
        var users = [User].users
        if let name = request.name {
          users = users.filter({ $0.name == name })
        }
        return Just(users)
          .setFailureType(to: LoadError.self)
          .eraseToEffect()
        
      },
      mainQueue: scheduler
    )
  }
}

struct UserStateWithCustomRequesState: Equatable {
  var list: LoadableListState<User, LoadError>
  var nameQuery: String?
}


let userReducerWithCustomRequest = Reducer<
  UserStateWithCustomRequesState,
  LoadableListAction<User, LoadError>,
  LoadableListEnvironment<User, TestUserLoadRequest, LoadError>
> { state, action, environment in
  switch action {
  case .editMode:
    return .none
  case .list:
    return .none
  case .loadable(.load):
    return environment.load(.init(name: state.nameQuery))
      .receive(on: environment.mainQueue)
      .catchToEffect()
      .map { .loadable(.loadingCompleted($0)) }
  case .loadable:
    return .none
  }
}
.loadableList(
  state: \.list,
  action: /LoadableListAction.self
//  environment: { $0 }
)

extension LoadableListEnvironment where Element == User, LoadRequest == EmptyLoadRequest, Failure == LoadError {
  
  public static func test(scheduler: AnySchedulerOf<DispatchQueue>) -> Self {
    
    Self.init(
      load: { _ in
        Just([User].users)
          .setFailureType(to: LoadError.self)
          .eraseToEffect()
      },
      mainQueue: scheduler
    )
  }
}
