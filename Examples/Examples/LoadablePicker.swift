import ComposableArchitecture
import Loadable
import SwiftUI

//struct User: Equatable, Identifiable {
//  let id: Int
//  let name: String
//
//  static let mocks: [Self] = [
//    .init(id: 1, name: "Blob"),
//    .init(id: 2, name: "Blob Jr."),
//    .init(id: 3, name: "Blob Sr.")
//  ]
//}
//
//extension IdentifiedArray where Element == User, ID == Int {
//  static var mocks = Self.init(uniqueElements: User.mocks)
//}
//
//struct LoadablePicker: ReducerProtocol {
//  struct State: Equatable {
//    @BindingState var selection: Int? = nil
//    @LoadableState var users: IdentifiedArrayOf<User>?
//  }
//
//  enum Action: BindableAction, Equatable {
//    case binding(BindingAction<State>)
//    case users(LoadingAction<IdentifiedArrayOf<User>, Never>)
//  }
//
//  @Dependency(\.continuousClock) var clock;
//
//  var body: some ReducerProtocolOf<Self> {
//    BindingReducer()
//    Reduce { state, action in
//      switch action {
//      case .binding:
//        return .none
//
//      case .users(.load):
//        return .task {
//          await .users(.receiveLoaded(
//            TaskResult {
//              try await clock.sleep(for: .milliseconds(300))
//              return IdentifiedArray.mocks
//            }
//          ))
//        }
//
//      case .users:
//        return .none
//      }
//    }
//    .loadable(state: \.$users, action: /Action.users) { EmptyReducer() }
//  }
//}
//
//struct LoadablePickerView: View {
//  let store: StoreOf<LoadablePicker>
//
//  var body: some View {
//    WithViewStore(self.store, observe: { $0 }) { viewStore in
//      LoadableView(
//        store: self.store.scope(state: \.$users, action: LoadablePicker.Action.users)
//      ) { loadedStore in
//        WithViewStore(loadedStore, observe: { $0 }) { loadedViewStore in
//          Picker("User", selection: viewStore.binding(\.$selection)) {
//            ForEach(loadedViewStore.state) { user in
//              Text(user.name)
//                .tag(Optional(user.id))
//            }
//          }
//        }
//      }
//    }
//  }
//}
//
//struct LoadablePickerView_Previews: PreviewProvider {
//  static var previews: some View {
//    LoadablePickerView(
//      store: .init(
//        initialState: LoadablePicker.State(),
//        reducer: LoadablePicker()._printChanges()
//      )
//    )
//  }
//}
