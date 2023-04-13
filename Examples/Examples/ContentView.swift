import ComposableArchitecture
import Loadable
import SwiftUI

//struct Preview: Reducer {
//  struct State: Equatable {
//    @LoadableState var int: Int?
//  }
//
//  enum Action: Equatable {
//    case int(LoadingAction<Int>)
//  }
//
//  @Dependency(\.continuousClock) var clock;
//
//  var body: some ReducerOf<Self> {
//    Reduce { state, action in
//      switch action {
//      case .int(.load):
//        return .task {
//          await .int(.receiveLoaded(
//            TaskResult {
//              try await clock.sleep(for: .seconds(3))
//              return 42
//            }
//          ))
//        }
//      case .int:
//        return .none
//      }
//    }
//    .loadable(state: \.$int, action: /Action.int)
//  }
//}
//
//struct ContentView: View {
//  let store: StoreOf<Preview>
//
//  var body: some View {
//    VStack {
//      WithViewStore(store, observe: { $0 }) { viewStore in
//        LoadableView(store: store.scope(state: \.$int, action: Preview.Action.int)) {
//          WithViewStore($0, observe: { $0 }) { viewStore in
//            Text("Loaded: \(viewStore.state)")
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

@available(iOS 16, *)
struct App: ReducerProtocol {
  struct State: Equatable {
    @LoadableState var int: Int?
  }

  enum Action: Equatable {
    case int(LoadingAction<Int>)
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
      }
    }
    .loadable(state: \.$int, action: /Action.int)
  }
}

struct ContentView: View {
  let store: StoreOf<App>
  var body: some View {
    VStack {
      WithViewStore(store, observe: { $0 }) { viewStore in
        LoadableView(store: store.scope(state: \.$int, action: App.Action.int)) {
          WithViewStore($0, observe: { $0 }) { viewStore in
            Text("Loaded: \(viewStore.state)")
          }
        } notRequested: {
          ProgressView()
        } isLoading: {
          IfLetStore($0) { intStore in
            // Show this view if we have loaded a value in the past.
            VStack {
              ProgressView()
                .padding()
              Text("Loading...")
            }
          } else: {
            // Show this view when we have not loaded a value in the past, but our state `.isLoading`
            ProgressView()
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
