import XCTest
import ComposableArchitecture
import Loadable

struct User: Codable, Identifiable, Equatable {
  let id: UUID
  let name: String

  static var mock: Self {
    return Self.init(
      id: UUID(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!,
      name: "Blob"
    )
  }
  
  static var mocks: [Self] {
    return [
      .mock,
      .init(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
        name: "Blob Jr."
      ),
      .init(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Blob Sr."
      ),
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

  enum Action: Equatable, LoadableAction {
    case loadable(LoadingAction<User>)
  }

  var body: some ReducerProtocolOf<Self> {

    Reduce { state, action in
      switch action {
      case .loadable(.load):
        return .load {
          return User.mock
        }
      case .loadable:
        return .none
      }
    }
    .loadable(state: \.$user)
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
    .loadable(state: \.$userPicker, action: /Action.loadable, then: /Action.picker) {
      UserPicker()
    }
  }
}

@MainActor
final class TCA_LoadableTests: XCTestCase {
  
  func test_loadable() async {

    let store = TestStore(
      initialState: EnvisionedUsage.State(),
      reducer: EnvisionedUsage()
    )

    await store.send(.loadable(.load)) {
      $0.$user.loadingState = .isLoading(previous: nil)
    }
    await store.receive(.loadable(.receiveLoaded(.success(.mock))), timeout: 1) {
      $0.$user.loadingState = .loaded(.mock)
    }

    await store.send(.load) {
      $0.$user.loadingState = .isLoading(previous: .mock)
    }
    
    await store.receive(.receiveLoaded(.success(.mock)), timeout: 1) {
      $0.$user.loadingState = .loaded(.mock)
      $0.user = .mock
    }

  }

  func test_codable() throws {
    let json = """
    {
      "user" : {
        "id" : "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF",
        "name" : "Blob"
      }
    }
    """
    let decoded = try JSONDecoder().decode(EnvisionedUsage.State.self, from: Data(json.utf8))

    let state = EnvisionedUsage.State(user: .mock)
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
    )
    
    await store.send(.loadable(.load)) {
      $0.$userPicker.loadingState = .isLoading(previous: nil)
    }
    await store.receive(.loadable(.receiveLoaded(.success(.init(users: .mocks)))), timeout: 1) {
      $0.userPicker = .init(users: .mocks)
    }
    await store.send(.loadable(.load)) {
      $0.$userPicker.loadingState = .isLoading(previous: .init(users: .mocks))
    }
    await store.receive(.loadable(.receiveLoaded(.success(.init(users: .mocks)))), timeout: 1) {
      $0.$userPicker.loadingState = .loaded(.init(users: .mocks))
    }
    await store.send(.picker(.set(\.$selected, User.mocks[0].id))) {
      $0.userPicker?.selected = User.mocks[0].id
    }

  }
}
