# Error Handling

This article describes error handling for loadable views.

## Overview

If an error is thrown in the task that loads your content they are ignored by default.
You can handle the error in your reducer logic by matching on the ``LoadableAction/receiveLoaded(_:)``
for your loadable item.

This allows you to display an alert or a different view based on the error that is thrown.

## Example
```swift
@Reducer
struct App {

  struct State {
    var int: LoadableState<Int> = .notRequested
    var error: Error?
  }

  enum Action: Equatable {
    case int(LoadableAction<Int>)
  }

  @Dependency(\.continuousClock) var clock;

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      // Handle the error here.
      case .int(.receiveLoaded(.failure(let error))):
        state.error = error
        return .none

      case .int:
        return .none
      }
    }
    .loadable(state: \.int, action: \.int) {
      /// sleep to act like data is loading from a remote.
      try await clock.sleep(for: .seconds(2))
      return 42
    }
  }
}
```
