import ComposableArchitecture
import Loadable
import SwiftUI

@available(iOS 16, *)
struct App: ReducerProtocol {
  struct State: Equatable {
    @LoadableState var int: Int?
    var orientation: IsLoadingOrientation = .horizontal()
  }

  enum Action: Equatable {
    case int(LoadingAction<Int, Never>)
    case toggleHorizontalOrVertical
    case toggleSecondaryOrientation
  }

  @Dependency(\.continuousClock) var clock;
  var body: some ReducerProtocolOf<Self> {
    Reduce { state, action in
      switch action {
      case .int(.load):
        return .task {
          await .int(.receiveLoaded(
            TaskResult {
              /// sleep to act like data is loading from a remote.
              try await clock.sleep(for: .seconds(2))
              return 42
            }
          ))
        }
      case .int:
        return .none
      case .toggleHorizontalOrVertical:
        switch state.orientation {
        case .horizontal:
          state.orientation = .vertical()
        case .vertical:
          state.orientation = .horizontal()
        }
        return .none
      case .toggleSecondaryOrientation:
        switch state.orientation {
        case .horizontal(.leading):
          state.orientation = .horizontal(.trailing)
        case .horizontal(.trailing):
          state.orientation = .horizontal(.leading)
        case .vertical(.above):
          state.orientation = .vertical(.below)
        case .vertical(.below):
          state.orientation = .vertical(.above)
        }
        return .none
      }
    }
    .loadable(state: \.$int, action: /Action.int) {
      EmptyReducer<Int, Never>()
    }
  }
}

struct ContentView: View {
  let store: StoreOf<App>

  var body: some View {
    VStack {
//      LoadablePickerView_Previews.previews
      WithViewStore(store, observe: { $0 }) { viewStore in
        LoadableView(
          store: store.scope(state: \.$int, action: App.Action.int),
          orientation: viewStore.orientation
        ) {
          WithViewStore($0, observe: { $0 }) { viewStore in
            Text("Loaded: \(viewStore.state)")
          }
        }
        Button(action: { viewStore.send(.int(.load)) }) {
          Text("Reload")
        }
        .padding(.top)
      }
    }
    .padding()
  }
}

//struct ContentView: View {
//  let store: StoreOf<App>
//  var body: some View {
//    VStack {
//      WithViewStore(store, observe: { $0 }) { viewStore in
//        LoadableView(store: store.scope(state: \.$int, action: App.Action.int)) {
//          WithViewStore($0, observe: { $0 }) { viewStore in
//            Text("Loaded: \(viewStore.state)")
//          }
//        } notRequested: {
//          ProgressView()
//        } isLoading: {
//          IfLetStore($0) { intStore in
//            // Show this view if we have loaded a value in the past.
//            VStack {
//              ProgressView()
//                .padding()
//              Text("Loading...")
//            }
//          } else: {
//            // Show this view when we have not loaded a value in the past, but our state `.isLoading`
//            ProgressView()
//          }
//        }
//        Button(action: { viewStore.send(.int(.load)) }) {
//          Text("Reload")
//        }
//        .padding(.top)
//      }
//    }
//    .padding()
//  }
//}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView(
      store: .init(
        initialState: App.State(),
        reducer: App()
      )
    )
  }
}
