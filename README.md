[![CI](https://github.com/m-housh/swift-tca-loadable/actions/workflows/ci.yml/badge.svg)](https://github.com/m-housh/swift-tca-loadable/actions/workflows/ci.yml)

# swift-tca-loadable

A swift package for handling loadable items using [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture).

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

Version 0.2.0 brings breaking changes from the previous 0.1.0 versions.  Now we are using `CaseLet` and
`SwitchStore` under the hood, so that there is access to a `Store` in all of the different view states
of a `Loadable` item.

## Basic Usage
----------------

This package provides several loadable view types to use or to help create a more specific view for your use case.
The most versatile / flexible view is a `LoadableView`.  It allows customization of the views for all the states
a `Loadable` item can be in.  We also provide ways to enhance a reducer with the default functionality for each
view type.

### LoadableView

We will start by creating an environment that implements the `LoadableEnvironmentRepresentable` protocol, you
could also use the concrete `LoadableEnvironment` implementation as well.

```swift
import ComposableArchitecture
import LoadableView
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

### LoadableList

We also provide a `LoadableList` which can be used to display a list of items.  It does not support custom
views for the `notRequested`, `isLoading`, or `failed` states.  It uses the default `ProgressView` during
`notRequested` or `isLoading`.

It does provide `delete`, `editMode`, and `move` functionality for the list out of the box.

First we will create some supporting type that we want to load / view in the list

```swift
struct User: Equatable, Identifiable {
  let id: UUID = UUID()
  var name: String
  var isFavorite: Bool = false
}

extension User {
  static let blob = User(name: "blob")
  static let blobJr = User(name: "blob-jr")
  static let blobSr = User(name: "blob-sr")
}
```

Next we will create the state, action, and environment for our list view.

```swift

struct AppState: Equatable {
  var users: LoadableListStateFor<User, LoadError>
}

enum AppAction: Equatable {
  case users(LoadableListActionFor<User, LoadError>)
}

extension LoadableListEnvironment where Element == User, LoadRequest == EmptyLoadRequest, Failure == LoadError {
  static var live = Self.init(
    load: { _ in 
      Just([User.blob, .blobJr, .blobSr])
        .delay(for: .seconds(1), scheduler: DispatchQueue.main) // simulate loading
        .setFailureType(to: LoadError.self)
        .eraseToEffect()
    },
    mainQueue: .main
  )
}

let appReducer = Reducer<AppState, AppAction, LoadableListEnvironmentFor<User, LoadError>
  .empty
  .loadableList(
    state: \.users,
    action: /AppAction.users,
    environment: .live
  )
```

And now we can create a our loadable list view.

```swift
  
struct ContentView: View {
  let store: Store<AppState, AppAction>
  
  var body: some View {
    UsersView(store: store.scope(state: \.users, action: AppAction.users)
  }
  
  struct UsersView: View {
    store: Store<LoadableListStateFor<User, LoadError>, LoadableListActionFor<User, LoadError>>
    
    var body: some View {
      LoadableList(store: store) { userStore in 
        WithViewStore(userStore) { userViewStore in 
          Text(userViewStore.name)
        }
      }
      .toolbar {
        // Add edit mode toggle button
        ToolbarItemGroup(placement: .confirmationAction) {
          EditButton(
            store: store.scope(state: \.editMode, action: LoadableListAction.editMode)
          )
        }
      }
    }
  }
}

```

### LoadablePicker

There is also a `LoadablePicker` view for loading content into a picker.  This view also does not support
customizing the different states of the loadable items and uses the default `ProgressView`.

```swift
struct AppState: Equatable {
  var userPicker: LoadablePickerStateFor<User, LoadError> = .init()
}

enum AppAction: Equatable {
  case userPicker(LoadablePickerActionFor<User, LoadError>)
}

let appReducer = Reducer<AppState, AppAction, LoadablePickerEnvironmentFor<User, LoadError>>
  .empty
  .loadablePicker(
    state: \.userPicker,
    action: /AppAction.userPicker,
    environment: { $0 }
  )
 
struct ContentView: View {
  
  let store: Store<AppState, AppAction>
  
  var body: some View {
    UserPicker(store: store.scope(state: \.userPicker, action: AppAction.userPicker)
  }
  
  struct UserPicker: View {
    let store: Store<LoadablePickerStateFor<User, LoadError>, LoadablePickerActionFor<User, LoadError>>
    
    var body: some View {
      LoadablePicker(
        "User",
        store: store,
        allowNilSelection: true
      ) { user in 
        Text(user.name)
      }
    }
  }
}

```

### LoadableForEach

We also provide a `LoadableForEach` view that uses `ForEachStore` under the hood to give access to a store
for each element of the list view.  This view also supports the `delete`, `editMode`, and `move` actions
similar to a `LoadableList` view.  Like the other views this does not support customization of the views for
different states of the loadable items.

We will create our state, action, and environment.

```swift

enum UserAction: Equatable {
  case binding(BindingAction<User>)
}

let userReducer = Reducer<User, UserAction, Void>
  .empty
  .binding(action: /UserAction.binding)

struct AppState: Equatable {
  var users: LoadableForEachStateFor<User, LoadError> = .init()
}

enum AppAction: Equatable {
  case users(LoadableForEachActionFor<User, UserAction, LoadError>)
}

extension LoadableForEachEnvironment where Element == User, Id == User.ID, LoadRequest == EmptyLoadRequest, Failure == LoadError {

  static let live = Self.init(
    load: { _ in 
      Just([User.blob, .blobJr, .blobSr])
        .delay(for: .seconds(1), scheduler: DispatchQueue.main)
        .setFailureType(to: LoadError.self)
        .eraseToEffect()
    },
    mainQueue: .main
  )
}

let appReducer = Reducer<AppState, AppAction, LoadableForEachEnvironmentFor<User, EmptyLoadRequest, LoadError>>
  .empty
  .loadableForEach(
    state: \.users,
    action: /AppAction.users,
    environment: { $0 },
    forEach: userReducer
  )

```

Next we will create our loadable for each view.

```swift

struct ContentView: View {
  let store: Store<AppState, AppAction>
  
  var body: some View {
    UsersView(store: store.scope(state: \.users, action: AppAction.users)
  }
  
  struct UsersView: View {
    let store = Store<LoadableForEachStateFor<User, LoadError>, LoadableForEachActionFor<User, UserAction, LoadError>>
    
    var body: some View {
      LoadableForEach(store) { userStore in 
        WithViewStore(userStore) { userViewStore in 
          HStack {
            Text(userViewStore.name)
            Spacer()
            Toggle(
              "Favorite",
              isOn: userViewStore.binding(
                keyPath: \.isFavorite,
                action: UserAction.binding
              )
            )
          }
        }
      }
      .toolbar {
        // Add edit mode button
        ToolbarItemGroup(placement: .confirmationAction) {
          EditButton(
            store: store.scope(state: \.editMode, action: LoadableForEachAction.editMode)
          )
        }
      }
    }
  }
}
```

## Documentation
---------------------

You can view the api documentation on the [wiki](https://github.com/m-housh/swift-tca-loadable/wiki) page.

![Example Screenshot](https://github.com/m-housh/TCALoadable/blob/main/TCALoadable_Example.gif)
