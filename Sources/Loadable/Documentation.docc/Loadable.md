# ``Loadable``

A swift package for handling loadable items using `The Composable Architecture`.

## Installation
-------------------
Install this package in your project using `swift package manager`.

```swift
let package = Package(
  ...
  dependencies: [
    ...
    .package(url: "https://github.com/m-housh/swift-tca-loadable.git", from: "0.2.0")
  ]
  ...
)

```

## Notes
----------

Version `0.3.*` brings breaking changes from the previous versions. Version `0.3.*` updates to using the
`Reducer` from the composable architecture.

## Basic Usage
----------------

This package provides a `LoadableView` and several types that are used inside of your `Reducer`
implementations.

### LoadableView

Below shows an example `Reducer` and uses the `LoadableView`.

```swift
import ComposableArchitecture
import Loadable
import SwiftUI

struct App: Reducer {
  struct State: Equatable {
    var int: LoadableState<Int> = .notRequested
  }

  enum Action: Equatable {
    case int(LoadableAction<Int>)
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
      }
    }
    .loadable(state: \.int, action: \.int)
  }
}

struct ContentView: View {
  let store: StoreOf<App>
  var body: some View {
    VStack {
        LoadableView(store: store.scope(state: \.int, action: \.int)) { loaded in
          Text("Loaded: \(loaded)")
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
```

The above uses the default `ProgressView`'s when the items are in a `notRequested` or
`isLoading` state, but you can override each view.

```swift
struct ContentView: View {

  let store: StoreOf<App>

  var body: some View {
    LoadableView(
      store: store.scope(state: \.$score, action: App.Action.int)
    ) { loadedScore in
      // The view when we have loaded content.
      Text("Your score is: \(loadedScore)")
    } isLoading: { optionalLastLoadedValue in 
      MyCustomIsLoadingView(optionalLastLoadedValue)
    } notRequested: { 
      MyCustomNotRequestedView()
    }
  }
}
```

## Topics

- ``LoadableState``
- ``LoadableAction``
- ``LoadableView``
