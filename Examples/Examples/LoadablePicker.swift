import ComposableArchitecture
import Loadable
import SwiftUI

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

private struct UserLoaderKey: DependencyKey {
  
  var loadUsers: () async throws -> IdentifiedArrayOf<User>
  
  static var liveValue: UserLoaderKey {
    @Dependency(\.continuousClock) var clock;
    
    return self.init(loadUsers: {
      // Simulate loading the users from a remote.
      try await clock.sleep(for: .seconds(2))
      return .mocks
    })
  }
}

extension DependencyValues {
  var loadUsers: () async throws -> IdentifiedArrayOf<User> {
    get { self[UserLoaderKey.self].loadUsers }
    set { self[UserLoaderKey.self].loadUsers = newValue }
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
  
  @Dependency(\.loadUsers) var loadUsers;

  var body: some ReducerProtocolOf<Self> {
    
    Reduce { state, action in
      switch action {
//      case .loadable(.load):
      case .load:
        return .load { try await .init(users: loadUsers()) }
      case .loadable:
        return .none
      case .picker:
        return .none
      }
    }
    .loadable(state: \.$userPicker,then: /Action.picker) {
      UserPicker()
    }
  }
}

struct LoadablePicker: View {
  
  let store: StoreOf<UserLoader>
  
  var body: some View {
//    WithViewStore(self.store, observe: { $0 }) { viewStore in
      LoadableView(
        self.store.scope(state: \.$userPicker.loadingState),
        action: UserLoader.Action.picker
      ) {
        UserPickerView(store: $0, reload: { ViewStore(store).send(.load) })
      }
//    }
  }
  
  struct UserPickerView: View {
    let store: StoreOf<UserPicker>
    let reload: () -> Void
    
    var body: some View {
      WithViewStore(self.store, observe: { $0 }) { viewStore in
        VStack {
          Picker("User", selection: viewStore.binding(\.$selected)) {
            ForEach(viewStore.users) {
              Text($0.name)
                .tag(Optional($0.id))
            }
          }
          Button(action: { self.reload() }) {
            Text("Reload")
          }
          .padding(.top)
        }
      }
    }
  }
}

struct LoadablePicker_Previews: PreviewProvider {
  static var previews: some View {
    LoadablePicker(
      store: .init(
        initialState: UserLoader.State(),
        reducer: UserLoader()._printChanges()
      )
    )
  }
}
