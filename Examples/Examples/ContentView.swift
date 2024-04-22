import ComposableArchitecture
import Loadable
import SwiftUI

@available(iOS 16, *)
struct App: Reducer {
  @ObservableState
  struct State: Equatable {
    var int: LoadableState<Int> = .notRequested
    var orientation: IsLoadingOrientation = .horizontal()

    var currentOrientation: String {
      switch orientation {
      case let .horizontal(horizontal):
        switch horizontal {
        case .leading:
          return "Horizontal Leading"
        case .trailing:
          return "Horizontal Trailing"
        }
      case let .vertical(vertical):
        switch vertical {
        case .above:
          return "Vertical Above"
        case .below:
          return "Vertical Below"
        }
      }
    }
  }

  @CasePathable
  enum Action: Equatable {
    case int(LoadableAction<Int>)
    case toggleHorizontalOrVertical
    case toggleSecondaryOrientation
  }

  @Dependency(\.continuousClock) var clock;
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .int(.load):
        return .run { send in
          await send(.int(.receiveLoaded(
            TaskResult {
              /// sleep to act like data is loading from a remote.
              try await clock.sleep(for: .seconds(2))
              return 42
            }
          )))
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
    .loadable(state: \.int, action: \.int)
  }
}

struct ContentView: View {
  let store: StoreOf<App>

  var body: some View {
    VStack {
      Text("Toggle orientation and press reload button.")
        .padding(.bottom, 40)

      LoadableView(
        store: store.scope(state: \.int, action: \.int),
        orientation: store.orientation
      ) { state in
        Text("Loaded: \(state)")
      }
      Button(action: { store.send(.int(.load)) }) {
        Text("Reload")
      }
      .buttonStyle(.borderedProminent)
      .padding()


      Text("Current Progress View Orientation")
        .font(.callout)

      Text("\(store.currentOrientation)")
        .font(.caption)
        .foregroundStyle(Color.secondary)
        .padding(.bottom)

      Button(action: { store.send(.toggleHorizontalOrVertical) }) {
        Text("Toggle primary orientation")
      }
      Button(action: { store.send(.toggleSecondaryOrientation) }) {
        Text("Toggle secondary orientation")
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
        reducer: App.init
      )
    )
  }
}
