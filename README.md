# TCALoadable

A swift package for handling loadable items using [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture).

### Installation
-------------------
Install this package in your project using `swift package manager`.

```swift
let package = Package(
  ...
  dependencies: [
    ...
    .package(url: "https://github.com/m-housh/swift-tca-loadable.git", from: "1.0.0")
  ]
  ...
)

```

### Notes
----------

Version 1.0.0 brings breaking changes from the previous 0.1.0 versions.  Now we are using `CaseLet` and
`SwitchStore` under the hood, so that there is access to a `Store` in all of the different view states
of a `Loadable` item.

### Basic Usage
----------------

This package provides a basic loadable view to use or to create a more specific view for your use case.

We will start by creating an environment that implements the `LoadableEnvironment` protocol.

```swift
import ComposableArchitecture
import TCALoadable
import Combine
import SwiftUI

public enum LoadError: Equatable, Error {
  case loadingFailed
}

struct AppEnvironment: LoadableEnvironmentRepresentable {
    
    typealias LoadedValue = Int
    typealias LoadRequest = EmptyLoadRequest
    typealias Failure = LoadError
    
    let load: (EmptyLoadRequest) -> Effect<Int, Failure>
    let mainQueue: AnySchedulerOf<DispatchQueue>
}

// Create the live environment
extension AppEnvironment {
  static let live = Self.init(
    load: { _ in 
      Just(42)
        .delay(for: .seconds(1), scheduler: DispatchQueue.main) // simulate loading.
        .setFailureType(to: LoadError.self)
        .eraseToEffect()
    },
    mainQueue: .main
  )
}

```

Next we will create our app state that holds our `Loadable` item and our app actions.

```swift
struct AppState: Equatable {
    /// A score loaded from the environment.
    var score: Loadable<Int, LoadError> = .notRequested
}

enum AppAction: Equatable {
    case loadable(LoadAction<Int, LoadError>)
}

let appReducer = Reducer<AppState, AppAction, AppEnvironment>
  .empty
  .loadable( // Enhance the app reducer with the default loadable action reducer.
      state: \.score,
      action: /AppAction.loadable,
      environment: { $0 }
  )

```

Now we can create our app's content view.

```swift
struct ContentView: View {

  let store: Store<AppState, AppAction>
    
  var body: some View {
    LoadableView(
      store: store.scope(state: \.score, action: AppAction.loadable)
    ) { scoreStore in
      WithViewStore(scoreStore) { viewStore in
        Text("Your score is: \(viewStore.state)")
      }
    }
  }
}
```

The above uses the default `ProgressView`'s when the items are in a `notRequested` or
`isLoading` state.  And a default error view that displays the error and a button to retry
the loading action.  But you can override each view.

```swift
struct ContentView: View {

  let store: Store<AppState, AppAction>
    
  var body: some View {
    LoadableView(
      store: store.scope(state: \.score, action: AppAction.loadable)
    ) { scoreStore in
      WithViewStore(scoreStore) { viewStore in
        Text("Your score is: \(viewStore.state)")
      }
    }
    .notRequested { (notRequestedStore: Store<Void, AppAction>) in 
      MyCustomNotRequestedView(store: notRequestedStore)
    }
    .isLoading { (isLoadingStore: Store<Int?, AppAction) in 
      MyCustomIsLoadingView(store: isLoadingStore)
    }
    .error { (errorStore: Store<LoadError, AppAction) in 
      MyCustomErrorView(store: errorStore)
    }
  }
}
```

![Example Screenshot](https://github.com/m-housh/TCALoadable/blob/main/TCALoadable_Example.gif)
