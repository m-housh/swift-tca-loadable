import XCTest
import ComposableArchitecture
import Loadable

//struct User: Codable, Identifiable, Equatable {
//  let id: UUID
//  let name: String
//
//  static var mock: Self {
//    return Self.init(
//      id: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!,
//      name: "Blob"
//    )
//  }
//  
//  static var mocks: [Self] {
//    return [
//      .mock,
//      .init(
//        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
//        name: "Blob Jr."
//      ),
//      .init(
//        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
//        name: "Blob Sr."
//      ),
//    ]
//  }
//}
//
//extension IdentifiedArray where ID == User.ID, Element == User {
//  
//  static var mocks: Self { .init(uniqueElements: User.mocks) }
//}
//
//@Reducer
//struct EnvisionedUsage {
//  struct State: Codable, Equatable {
//    var user: LoadableState<User> = .notRequested
//  }
//
//  enum Action: Equatable, LoadingAction {
//    case loadable(LoadableAction<User>)
//  }
//
//  var body: some ReducerOf<Self> {
//
//    Reduce { state, action in
//      switch action {
//      case .loadable(.load):
//        return .load {
//          return User.mock
//        }
//      case .loadable:
//        return .none
//      }
//    }
//    .loadable(state: \.user, action: \.loadable)
//  }
//}
//
//@Reducer
//struct UserPicker: Reducer {
//  
//  @ObservableState
//  struct State: Equatable {
//    var selected: User.ID?
//    var users: IdentifiedArrayOf<User>
//  }
//  
//  enum Action: Equatable, BindableAction {
//    case binding(BindingAction<State>)
//  }
//  
//  var body: some ReducerOf<Self> {
//    BindingReducer()
//  }
//}
//
//@Reducer
//struct UserLoader: Reducer {
//  struct State: Equatable {
//    var userPicker: LoadableState<UserPicker.State> = .notRequested
//  }
//  
//  enum Action: Equatable, LoadingAction {
//    case loadable(LoadableAction<UserPicker.State>)
//    case picker(UserPicker.Action)
//  }
//  
//  var body: some ReducerOf<Self> {
//    
//    Reduce { state, action in
//      switch action {
//      case .loadable(.load):
//        return .load { .init(users: .mocks) }
//      case .loadable:
//        return .none
//      case .picker:
//        return .none
//      }
//    }
//    .loadable(state: \.userPicker, action: \.loadable) 
////    {
////      UserPicker()
////    }
//  }
//}

//final class TCA_LoadableTests: XCTestCase {
//  
//  @MainActor
//  func test_loadable() async {
//
//    let store = TestStore(
//      initialState: EnvisionedUsage.State(),
//      reducer: EnvisionedUsage.init
//    )
//
//    await store.send(.loadable(.load)) {
//      $0.user = .isLoading(previous: nil)
//    }
//    await store.receive(.loadable(.receiveLoaded(.success(.mock))), timeout: 1) {
//      $0.user = .loaded(.mock)
//    }
//
//    await store.send(.load) {
//      $0.user = .isLoading(previous: .mock)
//    }
//    
//    await store.receive(.receiveLoaded(.success(.mock)), timeout: 1) {
//      $0.user = .loaded(.mock)
//    }
//
//  }
//
//  @MainActor
//  func test_codable() throws {
//    let json = """
//    {
//      "user" : {
//        "id" : "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF",
//        "name" : "Blob"
//      }
//    }
//    """
//    let decoded = try JSONDecoder().decode(EnvisionedUsage.State.self, from: Data(json.utf8))
//
//    let state = EnvisionedUsage.State(user: .loaded(.mock))
//    XCTAssertEqual(decoded, state)
//
//    let encoder = JSONEncoder()
//    encoder.outputFormatting = [.prettyPrinted]
//    let encoded = try encoder.encode(state)
//
//    let string = String(data: encoded, encoding: .utf8)!
//    XCTAssertEqual(string, json)
//  }
//  
//  #warning("Fix me.")
//  func test_userLoader() async {
//    let store = TestStore(
//      initialState: UserLoader.State(),
//      reducer: UserLoader.init
//    )
//    
//    await store.send(.loadable(.load)) {
//      $0.userPicker = .isLoading(previous: nil)
//    }
//    await store.receive(.loadable(.receiveLoaded(.success(.init(users: .mocks)))), timeout: 1) {
//      $0.userPicker = .loaded(.init(users: .mocks))
//    }
//    await store.send(.loadable(.load)) {
//      $0.userPicker = .isLoading(previous: .init(users: .mocks))
//    }
//    await store.receive(.loadable(.receiveLoaded(.success(.init(users: .mocks)))), timeout: 1) {
//      $0.userPicker = .loaded(.init(users: .mocks))
//    }
////    await store.send(.picker(.set(\.$selected, User.mocks[0].id))) {
////      $0.userPicker.selected = User.mocks[0].id
////    }
//
//  }
//}
struct User: Codable, Identifiable, Equatable {
  let id: UUID
  let name: String

  static var mock: Self {
    @Dependency(\.uuid) var uuid;
    return Self.init(
      id: uuid(),
      name: "Blob"
    )
  }
}

@Reducer
struct EnvisionedUsage {
  struct State: Codable, Equatable {
    var user: LoadableState<User> = .notRequested
  }

  enum Action: Equatable {
    case user(LoadableAction<User>)
    case foo
  }

  var body: some Reducer<State, Action> {
    EmptyReducer()
      .loadable(state: \.user, action: \.user)
  }
}


final class TCA_LoadableTests: XCTestCase {
  
  @MainActor
  func test_loadable() async {
    
    let store = TestStore(
      initialState: EnvisionedUsage.State(),
      reducer: EnvisionedUsage.init
    )
    
    let mock = withDependencies {
      $0.uuid = .incrementing
    } operation: {
      return User.mock
    }
    
    await store.send(.user(.receiveLoaded(.success(mock)))) {
      $0.user = .loaded(mock)
    }
    await store.send(.user(.load)) {
      $0.user = .isLoading(previous: mock)
    }
  }

  @MainActor
  func test_codable() throws {
    let json = """
    {
      "user" : {
        "id" : "00000000-0000-0000-0000-000000000000",
        "name" : "Blob"
      }
    }
    """
    let decoded = try JSONDecoder()
      .decode(EnvisionedUsage.State.self, from: Data(json.utf8))

    let mock = withDependencies {
      $0.uuid = .incrementing
    } operation: {
      User.mock
    }

    let state = EnvisionedUsage.State(user: .loaded(mock))
    XCTAssertEqual(decoded, state)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let encoded = try encoder.encode(state)

    let string = String(data: encoded, encoding: .utf8)!
    XCTAssertEqual(string, json)
  }
}
