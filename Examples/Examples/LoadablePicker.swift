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
  
  @Dependency(\.continuousClock) var clock;

  var body: some ReducerProtocolOf<Self> {
    
    Reduce { state, action in
      switch action {
      case .loadable(.load):
        return .load {
          // Simulate loading the users from a remote.
          try await clock.sleep(for: .seconds(2))
          return .init(users: .mocks)
        }
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

struct LoadablePicker: View {
  
  let store: StoreOf<UserLoader>
  
  var body: some View {
    LoadableView(
      self.store.scope(state: \.$userPicker),
      loadedAction: UserLoader.Action.picker
    ) {
      UserPickerView(store: $0)
    }
  }
  
  struct UserPickerView: View {
    let store: StoreOf<UserPicker>
    
    var body: some View {
      WithViewStore(self.store, observe: { $0 }) { viewStore in
        VStack {
          Picker("User", selection: viewStore.binding(\.$selected)) {
            ForEach(viewStore.users) {
              Text($0.name)
                .tag(Optional($0.id))
            }
          }
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
        reducer: UserLoader()
      )
    )
  }
}
