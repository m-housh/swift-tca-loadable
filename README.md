# TCALoadable

A swift package for handling loadable items using [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture).

### Installation
-------------------
Install this package in your project using `swift package manager`.

### Usage
-------------

This package provides a basic loadable view to use or to create a more specific view for your use case.

We will start by creating an environment that implements the `LoadableEnvironment` protocol.

```swift
import ComposableArchitecture
import TCALoadable
import Combine
import SwiftUI

struct AppEnvironment: LoadableEnvironment {
    
    typealias LoadedValue = Int
    
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
.loadable( // Enhance the app reducer with the default loadable action reducer.
    state: \.score,
    action: /AppAction.loadActions,
    environment: { $0 }
)

```

Now we can create our app's content view.

```swift
struct ContentView: View {

    let store: Store<AppState, AppAction>
    
    var body: some View {
        WithViewStore(store) { viewStore in 
            LoadableView(
                store: store.scope(
                    state: { $0.score },
                    action: { .loadActions($0) }
                ),
                autoLoad: true
            ) { loadedScore in 
                Text("Congratulations your score is: \(loadedScore)")
            }
            notRequestedView: { ProgressView() }
            isLoadingView: { _ in ProgressView() }
            errorView: { error in
                VStack {
                    Text("Oops, something went wrong!")
                    Text(error.localizedDescription)
                        .font(.callout)
                        
                    Button(action: { viewStore.send(.loadActions(.load)) }) {
                        Text("Retry")
                    }
                }
            }
        }
    }
}
```
If you are targeting `iOS: 14, macOS: 11,  tvOS: 14.0, watchOS: 7.0` or later then there is a convience for using a progress view, so we could rewrite our content view as follows.

```swift
struct ContentView: View {

    let store: Store<AppState, AppAction>
    
    var body: some View {
        WithViewStore(store) { viewStore in 
            LoadableProgressView(
                store: store.scope(
                    state: { $0.score },
                    action: { .loadActions($0) }
                ),
                autoLoad: true
            ) { loadedScore in 
                Text("Congratulations your score is: \(loadedScore)")
            }
            errorView: { error in
                VStack {
                    Text("Oops, something went wrong!")
                    Text(error.localizedDescription)
                        .font(.callout)
                        
                    Button(action: { viewStore.send(.loadActions(.load)) }) {
                        Text("Retry")
                    }
                }
            }
        }
    }
}
```
Then build and run our application.
