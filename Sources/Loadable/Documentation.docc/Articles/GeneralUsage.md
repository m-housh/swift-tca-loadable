# General Usage

This article describes the basic general usage of this package. 

## Overview

This article describes the basic general usage of this package.

## Modeling State

Loadable state is modeled with the ``LoadableState`` property type.

#### Example

```swift
@Reducer
struct AppReducer { 
  @ObservableState
  struct State: Equatable { 
    var users: LoadableState<IdentifiedArrayOf<User>> = .notRequested
    ...
  }
  ...
  
}
```

You can access the loaded state using the ``LoadableState/rawValue`` property on the ``LoadableState``.

The ``LoadableState/rawValue`` will be non-nil when it has been loaded from a remote / external source.  

## Modeling Actions

You model your actions as a case in your action that accepts a ``LoadableAction``. Then enhance your
reducer with one of the ``ComposableArchitecture/Reducer/loadable(state:action:on:operation:)`` modifiers.

#### Example
```swift
@Reducer
struct AppReducer { 
  ...
  enum Action: Equatable, LoadableAction { 
    case users(LoadableAction<IdentifiedArrayOf<User>>)
    case task
  }
  
  var body: some ReducerOf<Self> { 
    Reduce { state, action in 
      switch action { 
      ...
      case .users:
        return .none

      case .task:
        return .none
      ...
      }
    }
    .loadable(state: \.users, action: \.users, on: \.task) {
      // The operation that is called to load the users when
      // the trigger action of `.task` is received by the parent.
      try await loadUsers()
    }
  }
}
```

## Reducers

The reducers that are shipped with the library handle setting the ``LoadableState`` variable
correctly, but you need to handle the ``LoadableAction/load`` in your reducer to actually load
the data from an external source.  

Upon a successful result the reducer will set the loading state to ``LoadableState/loaded(_:)``
and the ``LoadableState/rawValue`` property will be non-nil.

You can handle the failed result by matching on the ``LoadableAction/receiveLoaded(_:)`` case.
See <doc:ErrorHandling>

## Loadable View

The library ships with a ``LoadableView`` that can be used to handle a piece of loadable
state, giving you control of the views based on the given state.

#### Example
```swift
struct ContentView: View {
  let store: StoreOf<AppReducer>
  
  var body: some View { 
    VStack {
      LoadableView(
        self.store.scope(state: \.users, action: \.users)
      ) { users in
        // Show your loaded view
        UsersView(users)
      }
      Button(action: { store.send(.users(.load)) }) { 
        Text("Reload")
      }
      .padding(.top)
    } 
  }
}

```

The most basic / default initializers of the view will show a `ProgressView` when the
state is ``LoadableState/notRequested`` until that state changes to ``LoadableState/loaded(_:)``.

If the `load` action gets called when the state has been previously loaded then the `NotRequested`
view (`ProgressView` by default) will show along with the previously loaded value.  The default
is to show the `ProgressView` in an `HStack` with the previously loaded view, but you can specify
a `vertical` orientation in the initializer if that fits your use case better.

```swift
  LoadableView(
    store.scope(...),
    orientation: .vertical(.above)
  )
```

The default is to call the `load` action when a view appears, however you can control that by
specifying an ``Autoload`` value during initialization of the view.

```swift
  LoadableView(
    store.scope(...),
    autoload: .never, // or .always or .whenNotRequested (default)
    orientation: .vertical(.above)
  )
```

See ``LoadableView`` for more initializers.

## Related Articles

- <doc:ErrorHandling>
