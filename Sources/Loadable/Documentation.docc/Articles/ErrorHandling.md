# Error Handling

This article describes error handling for loadable views.

## Overview

If an error is thrown in the task that loads your content they are ignored by default.
You can handle the error in your reducer logic by matching on the ``LoadingAction/receiveLoaded(_:)``
for your loadable item.

This allows you to display an alert or a different view based on the error that is thrown.

## Example
```swift
struct App: Reducer {
  struct State: Equatable {
    @LoadableState var int: Int?
    var error: Error?
  }

  enum Action: Equatable, LoadableAction {
    case loadable(LoadingAction<Int>)
  }

  @Dependency(\.continuousClock) var clock;

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .loadable(.load):
        return .load {
          /// sleep to act like data is loading from a remote.
          try await clock.sleep(for: .seconds(2))
          return 42
        }
      case .loadable(.receiveLoaded(.failure(let error))):
        state.error = error
        return .none
      case .loadable:
        return .none
      }
    }
    .loadable(state: \.$int)
  }
}
```
