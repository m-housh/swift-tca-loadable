import ComposableArchitecture
import Loadable
import SwiftUI

struct User: Equatable, Identifiable {
  let id: Int
  let name: String

  static let mocks: [Self] = [
    .init(id: 1, name: "Blob"),
    .init(id: 2, name: "Blob Jr."),
    .init(id: 3, name: "Blob Sr.")
  ]
}

extension IdentifiedArray where Element == User, ID == Int {
  static var mocks = Self.init(uniqueElements: User.mocks)
}

@Reducer
struct LoadablePicker {

  @ObservableState
  struct State: Equatable {
    var selection: Int? = nil
    var users: LoadableState<IdentifiedArrayOf<User>> = .notRequested
  }

  @CasePathable
  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case users(LoadableAction<IdentifiedArrayOf<User>>)
  }

  @Dependency(\.continuousClock) var clock;

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case .users(.load):
        return .run { send in
          await send(.users(.receiveLoaded(
            TaskResult {
              try await clock.sleep(for: .milliseconds(300))
              return IdentifiedArray.mocks
            }
          )))
        }

      case .users:
        return .none
      }
    }
    .loadable(state: \.users, action: \.users)
  }
}

struct LoadablePickerView: View {
  @Perception.Bindable var store: StoreOf<LoadablePicker>

  var body: some View {
    LoadableView(store: store.scope(state: \.users, action: \.users)) { state in
      Picker("User", selection: $store.selection) {
        ForEach(state) { user in
          Text(user.name)
            .tag(Optional(user.id))

        }
      }
    }
  }
}

#Preview {
  LoadablePickerView(
    store: Store(initialState: LoadablePicker.State()) {
      LoadablePicker()._printChanges()
    }
  )
}
