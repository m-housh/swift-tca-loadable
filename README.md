[![CI](https://github.com/m-housh/swift-tca-loadable/actions/workflows/ci.yml/badge.svg)](https://github.com/m-housh/swift-tca-loadable/actions/workflows/ci.yml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fm-housh%2Fswift-tca-loadable%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/m-housh/swift-tca-loadable)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fm-housh%2Fswift-tca-loadable%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/m-housh/swift-tca-loadable)

# swift-tca-loadable

A swift package for handling loadable items using [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture).
 
 - [Installation](#installation)
 - [Basic Usage](#basic-usage)
 - [Documenation](#documenation)

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

Version 0.3.+ brings breaking changes from the previous versions. Version `0.3.*` updates to using the
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
    @LoadableState var int: Int?
  }

  enum Action: Equatable {
    case int(LoadingAction<Int>)
  }

  @Dependency(\.continuousClock) var clock;
  
  var body: some ReducerOf<Self> {
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
        LoadableView(store: store.scope(state: \.$int, action: Preview.Action.int)) {
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
```

The above uses the default `ProgressView`'s when the items are in a `notRequested` or
`isLoading` state, but you can override each view.

```swift
struct ContentView: View {

  let store: StoreOf<App>
    
  var body: some View {
    LoadableView(
      store: store.scope(state: \.$score, action: App.Action.int)
    ) { scoreStore in
      // The view when we have loaded content.
      WithViewStore(scoreStore) { viewStore in
        Text("Your score is: \(viewStore.state)")
      }
    } isLoading: { (isLoadingStore: Store<Int?, App.Action>) in 
      MyCustomIsLoadingView(store: isLoadingStore)
    } notRequested: { (notRequestedStore: Store<Void, App.Action>) in 
      MyCustomNotRequestedView(store: notRequestedStore)
    }
  }
}
```
 
## Documentation
---------------------

You can view the api documentation on the 
[here](https://m-housh.github.io/swift-tca-loadable/documentation/loadable/).

![Example Screenshot](https://github.com/m-housh/TCALoadable/blob/main/TCALoadable_Example.gif)
