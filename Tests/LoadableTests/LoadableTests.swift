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
}
