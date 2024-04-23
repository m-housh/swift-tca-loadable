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
}

@Reducer
struct EnvisionedUsage {
  struct State: Codable, Equatable {
    var user: LoadableState<User> = .notRequested
  }

  enum Action: Equatable {
    case user(LoadableAction<User>)
    case task
  }

  @Dependency(\.continuousClock) var clock

  var body: some Reducer<State, Action> {
    Reduce<State, Action> { state, action in
      switch action {
      case .user:
        return .none

      case .task:
        return .none
      }

    }
    .loadable(state: \.user, action: \.user, on: \.task) {
      try await clock.sleep(for: .seconds(1))
      return User.mock
    }
  }
}

@Reducer
struct LoadOnlyReducer {
  struct State: Codable, Equatable {
    var user: LoadableState<User> = .notRequested
  }

  enum Action: Equatable {
    case user(LoadableAction<User>)
    case task
  }

  @Dependency(\.continuousClock) var clock

  var body: some Reducer<State, Action> {
    Reduce<State, Action> { state, action in
      switch action {
      case .user:
        return .none

      case .task:
        return .send(.user(.load))
      }

    }
    .loadable(state: \.user, action: \.user) {
      try await clock.sleep(for: .seconds(1))
      return User.mock
    }
  }
}

@Reducer
struct ParentOnlyReducer {
  struct State: Codable, Equatable {
    var user: LoadableState<User> = .notRequested
  }

  enum Action: Equatable {
    case user(LoadableAction<User>)
    case task
  }

  @Dependency(\.continuousClock) var clock

  var body: some Reducer<State, Action> {
    Reduce<State, Action> { state, action in
      switch action {
      case .user(.load):
        return .load(\.user) {
          try await clock.sleep(for: .seconds(1))
          return User.mock
        }
      case .user:
        return .none

      case .task:
        return .send(.user(.load))
      }

    }
    .loadable(state: \.user, action: \.user)
  }
}

final class TCA_LoadableTests: XCTestCase {

  override func invokeTest() {
    withDependencies {
      $0.uuid = .incrementing
      $0.continuousClock = ImmediateClock()
    } operation: {
      super.invokeTest()
    }
  }

  @MainActor
  func test_loadable() async {
    
    let store = TestStore(
      initialState: EnvisionedUsage.State(),
      reducer: EnvisionedUsage.init
    )

    let mock = User(id: UUID(0), name: "Blob")

    await store.send(.task)
    await store.receive(.user(.load)) {
      $0.user = .isLoading(previous: nil)
    }
    await store.receive(.user(.receiveLoaded(.success(mock)))) {
      $0.user = .loaded(mock)
    }
    await store.send(.user(.load)) {
      $0.user = .isLoading(previous: mock)
    }

    let mock2 = User(id: UUID(1), name: "Blob")
    await store.receive(.user(.receiveLoaded(.success(mock2)))) {
      $0.user = .loaded(mock2)
    }
  }

  @MainActor
  func test_load_only_handler() async {

    let store = TestStore(
      initialState: LoadOnlyReducer.State(),
      reducer: LoadOnlyReducer.init
    )

    let mock = User(id: UUID(0), name: "Blob")

    await store.send(.task)
    await store.receive(.user(.load)) {
      $0.user = .isLoading(previous: nil)
    }
    await store.receive(.user(.receiveLoaded(.success(mock)))) {
      $0.user = .loaded(mock)
    }
    await store.send(.user(.load)) {
      $0.user = .isLoading(previous: mock)
    }

    let mock2 = User(id: UUID(1), name: "Blob")
    await store.receive(.user(.receiveLoaded(.success(mock2)))) {
      $0.user = .loaded(mock2)
    }
  }

  @MainActor
  func test_parent_only_handler() async {

    let store = TestStore(
      initialState: ParentOnlyReducer.State(),
      reducer: ParentOnlyReducer.init
    )

    let mock = User(id: UUID(0), name: "Blob")

    await store.send(.task)
    await store.receive(.user(.load)) {
      $0.user = .isLoading(previous: nil)
    }
    await store.receive(.user(.receiveLoaded(.success(mock)))) {
      $0.user = .loaded(mock)
    }
    await store.send(.user(.load)) {
      $0.user = .isLoading(previous: mock)
    }

    let mock2 = User(id: UUID(1), name: "Blob")
    await store.receive(.user(.receiveLoaded(.success(mock2)))) {
      $0.user = .loaded(mock2)
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
