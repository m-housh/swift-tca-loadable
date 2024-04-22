# General Usage

This article describes the basic general usage of this package. 
## Overview

This article describes the basic general usage of this package.

## Modeling State

Loadable state is modeled as an optional value that is marked with the ``LoadableState`` property
wrapper.

#### Example

```swift
struct AppReducer: Reducer { 
  struct State: Equatable { 
    @LoadableState var users: IdentifiedArrayOf<User>?
    ...
  }
  ...
  
}
```

The state will be non-nil when it has been loaded from a remote / external source.  The property
wrapper allows you to access the `user` variable above like it's an `IdentifiedArray`, but under
the hood it is a ``LoadingState`` variable.

You can access items on the property wrapper type by it's `projectedValue` property by prefixing
with a property with the `$`.  For example, to access the ``LoadingState`` property on an instance of
state in a reducer.

```swift
if state.$user.loadingState == .notRequested {
...
}
```

## Modeling Actions

You model your actions as a case in your action that accepts a ``LoadingAction``.
In general it is easiest to conform your action enum to the ``LoadableAction`` type.

The ``LoadableAction`` type requires the ``LoadingAction`` case to be under the case
`loadable(LoadingAction<Value>)`.  

#### Example
```swift
struct AppReducer: Reducer { 
  ...
  enum Action: Equatable, LoadableAction { 
    case loadable(LoadingAction<User>)
  }
}
```

And gives your action enum some extra convenience properties allowing you to match on 
actions at both the root of your action enum or through the `loadable` case.

```swift

struct AppReducer: Reducer { 
  ...
  enum Action: Equatable, LoadableAction { 
    case loadable(LoadingAction<User>)
  }
  
  var body: some ReducerOf<Self> { 
 
    Reduce { state, action in 
      switch action { 
      case .loadable(.load):
        return .load { try await loadUsers() }
      case .loadable:
        return .none
      }
    }
  }
}

```

The above is equivalent to the below matching of the ``LoadingAction/load`` action.

```swift
struct AppReducer: Reducer { 
  ...
  enum Action: Equatable, LoadableAction { 
    case loadable(LoadingAction<User>)
  }
  
  var body: some ReducerOf<Self> { 
    Reduce { state, action in 
      switch action { 
      case .load:
        return .load { try await loadUsers() }
      case .loadable:
        return .none
      }
    }
  }
}
```

In general it is preferred to match inside your reducer through the `loadable` case to be
more clear in your pattern matching, and use the properties on the root in your view layer 
(button clicks, page loads, etc.).

## Reducers

The library ships with the ``LoadableReducer`` however it is more common to use one of the
method extensions on the ``Reducer``.  When your action type conforms to the
``LoadableAction`` type the methods are more ergonomic.

#### Example

```swift
struct AppReducer: Reducer { 
  ...
  enum Action: Equatable, LoadableAction { 
    case loadable(LoadingAction<User>)
  }
  
  var body: some ReducerOf<Self> { 
    Reduce { state, action in 
      switch action { 
      case .loadable(.load):
        return .load { try await loadUsers() }
      case .loadable:
        return .none
      }
    }
    .loadable(state: \.$users)
  }
}
```

The reducers that are shipped with the library handle setting the ``LoadableState`` variable
correctly, but you need to handle the ``LoadingAction/load`` in your reducer to actually load
the data from an external source.  

Upon a successful result the reducer will set the loading state to ``LoadingState/loaded(_:)``
and the state property will be non-nil.

You can handle the failed result by matching on the ``LoadingAction/receiveLoaded(_:)`` case.
See <doc:ErrorHandling>

When your action type conforms to the ``LoadableAction`` type then you can use the `load` 
effect (as shown above).  The `load` effect will wrap the asynchronous block of code into a
`TaskResult` and call the ``LoadingAction/receiveLoaded(_:)`` with the result.

If your action type does not conform to the ``LoadableAction`` type then you will have need
to wrap your loading task into the ``LoadingAction/receiveLoaded(_:)`` for your given case.
See <doc:AdvancedUsage> 

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
        self.store.scope(state: \.$users, action: AppReducer.Action.loadable)
      ) { (usersStore: Store<IdentifiedArrayOf<User>, LoadingAction<IdentifiedArrayOf<User>>>) in
        // Show your loaded view
        // The store gets handed a non-nil value of your loadable state.
        UsersView(store: usersStore)
      }
      Button(action: ViewStore(self.store).send(.load)) { 
        Text("Reload")
      }
      .padding(.top)
    } 
  }
}

```

The most basic / default initializers of the view will show a ``ProgressView`` when the
state is ``LoadingState/notRequested`` until that state changes to ``LoadingState/loaded(_:)``.

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

<doc:AdvancedUsage>
<doc:ErrorHandling>
