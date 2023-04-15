import XCTest
import ComposableArchitecture
import Loadable

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
  
  static var mocks: [Self] {
    @Dependency(\.uuid) var uuid;
    return [
      .init(id: uuid(), name: "Blob"),
      .init(id: uuid(), name: "Blob Jr."),
      .init(id: uuid(), name: "Blob Sr."),
    ]
  }
}

extension IdentifiedArray where ID == User.ID, Element == User {
  
  static var mocks: Self { .init(uniqueElements: User.mocks) }
}

struct EnvisionedUsage: ReducerProtocol {
  struct State: Codable, Equatable {
    @LoadableState var user: User? = nil
  }

  enum Action: Equatable {
    case user(LoadingAction<User>)
  }

  var body: some ReducerProtocolOf<Self> {
    EmptyReducer()
      .loadable(state: \.$user, action: /Action.user)
  }
}

struct UserPicker: ReducerProtocol {
  
  struct State: Equatable {
    @BindingState var selected: User.ID?
    var users: IdentifiedArrayOf<User>
  }
  
  enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
  }
  
  var body: some ReducerProtocolOf<Self> {
    BindingReducer()
  }
}

struct UserLoader: ReducerProtocol {
  struct State: Equatable {
    @LoadableState var userPicker: UserPicker.State?
  }
  
  enum Action: Equatable, LoadableAction {
    case loadable(LoadingAction<UserPicker.State>)
    case picker(UserPicker.Action)
  }
  
  var body: some ReducerProtocolOf<Self> {
    
    Reduce { state, action in
      switch action {
      case .loadable(.load):
        return .load { .init(users: .mocks) }
      case .loadable:
        return .none
      case .picker:
        return .none
      }
    }
//    .loadable(state: \.$userPicker, toChildAction: /Action.picker) {
//      UserPicker()
//    }
    .loadable(state: \.$userPicker)
    .ifLet(\.userPicker, action: /Action.picker) {
      UserPicker()
    }
  }
}

//let reducer = EmptyReducer<UserLoader.State, UserLoader.Action>()
//  .loadable(
//    state: \.$userPicker,
//    toChildAction: /UserLoader.Action.picker
//  ) {
//    UserPicker()
//  }
//  .loadable(state: \.$userPicker)
//  .ifLet(\.userPicker, action: /UserLoader.Action.picker) {
//    UserPicker()
//  }

@MainActor
final class TCA_LoadableTests: XCTestCase {
  
  func test_loadable() async {
    
    let store = TestStore(
      initialState: EnvisionedUsage.State(),
      reducer: EnvisionedUsage()
    )
    
    let mock = withDependencies {
      $0.uuid = .incrementing
    } operation: {
      return User.mock
    }
    
    await store.send(.user(.receiveLoaded(.success(mock)))) {
      $0.user = mock
    }
    await store.send(.user(.load)) {
      $0.$user = .isLoading(previous: mock)
    }
  }

  func test_codable() throws {
    let json = """
    {
      "user" : {
        "id" : "00000000-0000-0000-0000-000000000000",
        "name" : "Blob"
      }
    }
    """
    let decoded = try JSONDecoder().decode(EnvisionedUsage.State.self, from: Data(json.utf8))

    let mock = withDependencies {
      $0.uuid = .incrementing
    } operation: {
      User.mock
    }

    let state = EnvisionedUsage.State(user: mock)
    XCTAssertEqual(decoded, state)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted]
    let encoded = try encoder.encode(state)

    let string = String(data: encoded, encoding: .utf8)!
    XCTAssertEqual(string, json)
  }
  
  func test_userLoader() async {
    let store = TestStore(
      initialState: UserLoader.State(),
      reducer: UserLoader()
    ) {
      $0.uuid = .incrementing
    }
    
    let mocks = withDependencies {
      $0.uuid = .incrementing
    } operation: {
      return IdentifiedArrayOf<User>.mocks
    }
    
    await store.send(.loadable(.load)) {
      $0.$userPicker = .isLoading(previous: nil)
    }
    await store.receive(.loadable(.receiveLoaded(.success(.init(users: mocks)))), timeout: 1) {
      $0.userPicker = .init(users: mocks)
    }
    await store.send(.picker(.set(\.$selected, mocks[0].id))) {
      $0.userPicker?.selected = mocks[0].id
    }
  }
}
