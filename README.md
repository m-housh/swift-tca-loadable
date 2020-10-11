# TCALoadable

A swift package for handling loadable items using [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture).

### Installation
-------------------
Install this package in your project using `swift package manager`.

### Usage
-------------

This package provides a basic loadable view that you would typically use to create a more specific view for your use case.

We will start by creating an environment that implements the `LoadableEnvironment` protocol.

```swift
import ComposableArchitecture
import TCALoadable

struct AppEnvironment: LoadableEnvironment {
    
    typealias LoadedValue: Int
    
    let mainQueue: AnySchedulerOf<DispatchQueue>
    
    func load() -> Effect<Int, Error> {
        Just(100)
            .setFailureType(to: Error.self)
            // Simulate a network call or loading from disk.
            .delay(for: .seconds(1), scheduler: mainQueue)
            .eraseToEffect()
    }
}

```

Next we will create our app state that holds our `Loadable` item and our app actions.

```swift
struct AppState: Equatable {
    /// A score loaded from the environment.
    var score: Loadable<Int> = .notRequested
}

enum AppAction: Equatable {
    case loadActions(LoadableActionsFor<Int>)
}

let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, environment in 
    switch action {
    
    case .loadActions(_):
        return .none
    }
}
.loadable(
    state: \.score,
    action: /AppAction.loadActions,
    environment: { $0 }
)

```

Now we can create our view.
