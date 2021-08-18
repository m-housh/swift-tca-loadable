import ComposableArchitecture
@_exported import EditModeModifier
@_exported import LoadableView
import SwiftUI

/// Represents the environment for a loadable list view.
public struct LoadableListViewEnvironment<Element, LoadRequest, Failure: Error> {
  
  /// Load the items.
  public var load: (LoadRequest) -> Effect<[Element], Failure>
  
  /// The main dispatch queue.
  public var mainQueue: AnySchedulerOf<DispatchQueue>
  
  /// Create a new environment.
  ///
  /// - Parameters:
  ///   - load: Load the items.
  ///   - mainQueue: The main dispatch queue.
  public init(
    load: @escaping (LoadRequest) -> Effect<[Element], Failure>,
    mainQueue: AnySchedulerOf<DispatchQueue>
  ) {
    self.load = load
    self.mainQueue = mainQueue
  }
}
extension LoadableListViewEnvironment: LoadableEnvironmentRepresentable { }
public typealias LoadableListViewEnvironmentFor = LoadableListViewEnvironment

#if DEBUG
extension LoadableListViewEnvironment {
  public static var failing: LoadableListViewEnvironment {
    .init(
      load: { _ in .failing("\(Self.self).load is unimplemented") },
      mainQueue: .failing("\(Self.self).mainQueue is unimplemented")
    )
  }
}
#endif

extension LoadableListViewEnvironment {
  public static var noop: LoadableListViewEnvironment {
    .init(
      load: { _ in .none },
      mainQueue: .main
    )
  }
}

// MARK: - State

/// Represents the state of a loadable list view.
public struct LoadableListViewState<Element, Failure: Error> {
  
  /// The current edit mode of the view.
  public var editMode: EditMode
  
  /// The loadable items.
  public var loadable: Loadable<[Element], Failure>
  
  /// Create a new loadable list view state.
  ///
  /// - Parameters:
  ///   - editMode: The current edit mode.
  ///   - loadable: The loadable items.
  public init(
    editMode: EditMode = .inactive,
    loadable: Loadable<[Element], Failure> = .notRequested
  ) {
    self.editMode = editMode
    self.loadable = loadable
  }
}
extension LoadableListViewState: Equatable where Element: Equatable, Failure: Equatable { }
public typealias LoadableListViewStateFor = LoadableListViewState

// MARK: - Action

/// Represents common actions that can be taken on lists.
public enum ListAction: Equatable {
  
  /// Delete rows from the list.
  case delete(IndexSet)
  
  /// Move rows in the list.
  case move(IndexSet, Int)
}

/// Represents the actions that can be taken on a loadable list view.
public enum LoadableListViewAction<Element, Failure: Error> where Element: Equatable {
  case editMode(EditModeAction)
  case list(ListAction)
  case load(LoadableAction<[Element], Failure>)
}
extension LoadableListViewAction: Equatable where Failure: Equatable { }
public typealias LoadableListViewActionFor = LoadableListViewAction

extension Reducer {
  
  /// Enhances a reducer with list actions.
  ///
  /// - Parameters:
  ///   - state: The list state.
  ///   - action: The list actions.
  public func list<Element>(
    state: WritableKeyPath<State, [Element]>,
    action: CasePath<Action, ListAction>
  ) -> Reducer {
    .combine(
      Reducer<[Element], ListAction, Void> { state, action, _ in
        switch action {
        case let .delete(indexSet):
          state.remove(atOffsets: indexSet)
          return .none
          
        case let .move(source, destination):
          state.move(fromOffsets: source, toOffset: destination)
          return .none
        }
      }
        .pullback(state: state, action: action, environment: { _ in }),
      self
    )
  }
  
  /// Enhances a reducer with list actions for an optional list.
  ///
  /// - Parameters:
  ///   - state: The list state.
  ///   - action: The list actions.
  public func list<Element>(
    state: WritableKeyPath<State, [Element]?>,
    action: CasePath<Action, ListAction>
  ) -> Reducer {
    .combine(
      Reducer<[Element], ListAction, Void>.empty
        .list(state: \.self, action: /ListAction.self)
        .optional()
        .pullback(state: state, action: action, environment: { _ in }),
      self
    )
  }
  
  /// Enhances a reducer with loadable list actions.
  ///
  /// - Parameters:
  ///   - state: The loadable list state.
  ///   - action: The loadable list actions.
  public func loadableList<Element, Failure>(
    state: WritableKeyPath<State, LoadableListViewState<Element, Failure>>,
    action: CasePath<Action, LoadableListViewAction<Element, Failure>>
  ) -> Reducer {
    .combine(
      Reducer<LoadableListViewState<Element, Failure>, LoadableListViewAction<Element, Failure>, Void> { state, action, _ in
        switch action {
          
        case .editMode:
          return .none
          
        case .list:
          return .none

        case .load:
          return .none
        }
      }
        .editMode(state: \.editMode, action: /LoadableListViewAction.editMode)
        .list(state: \.loadable.rawValue, action: /LoadableListViewAction.list)
        .loadable(state: \.loadable, action: /LoadableListViewAction.load)
        .pullback(state: state, action: action, environment: { _ in }),
      self
    )
  }
  
  /// Enhances a reducer with loadable list actions.
  ///
  /// - Parameters:
  ///   - state: The loadable list state.
  ///   - action: The loadable list actions.
  ///   - environment: The loadable list environment.
  public func loadableList<Element, Failure>(
    state: WritableKeyPath<State, LoadableListViewStateFor<Element, Failure>>,
    action: CasePath<Action, LoadableListViewActionFor<Element, Failure>>,
    environment: @escaping (Environment) -> LoadableListViewEnvironmentFor<Element, EmptyLoadRequest, Failure>
  ) -> Reducer where Failure: Equatable, Failure: Error {
    .combine(
      Reducer<
        LoadableListViewState<Element, Failure>,
        LoadableListViewAction<Element, Failure>,
        LoadableListViewEnvironment<Element, EmptyLoadRequest, Failure>
      >.empty
        .loadableList(state: \.self, action: /LoadableListViewAction.self)
        .loadable(
          state: \.loadable,
          action: /LoadableListViewAction.load,
          environment: { $0 }
        )
        .pullback(state: state, action: action, environment: environment),
      self
    )
  }
  
  /// Enhances a reducer with loadable list actions.
  ///
  /// - Parameters:
  ///   - state: The loadable list state.
  ///   - action: The loadable list actions.
  ///   - environment: The loadable list environment.
  public func loadableList<Element, Failure: Error, Request>(
    state: WritableKeyPath<State, LoadableListViewStateFor<Element, Failure>>,
    action: CasePath<Action, LoadableListViewActionFor<Element, Failure>>,
    environment: @escaping (Environment) -> LoadableListViewEnvironmentFor<Element, Request, Failure>
  ) -> Reducer where Failure: Equatable {
    .combine(
      Reducer<
        LoadableListViewState<Element, Failure>,
        LoadableListViewAction<Element, Failure>,
        LoadableListViewEnvironment<Element, Request, Failure>
      >.empty
        .loadableList(state: \.self, action: /LoadableListViewAction.self)
        .loadable(
          state: \.loadable,
          action: /LoadableListViewAction.load,
          environment: { $0 }
        )
        .pullback(state: state, action: action, environment: environment),
      self
    )
  }
}

// MARK: - View

/// A loadable view that shows a list of items once they've been loaded.
///
/// **Example**:
/// ```swift
/// struct User: Equatable, Identifiable {
///   let id: UUID = UUID()
///   var name: String
///
///   static let blob = User.init(name: "blob")
///   static let blobJr = User.init(name: "blob-jr")
///   static let blobSr = User.init(name: "blob-sr")
/// }
///
/// enum LoadError: Error, Equatable {
///   case loadingFailed
/// }
///
/// extension LoadableListViewEnvironment where Element == User, LoadRequest == EmptyLoadRequest, Failure == LoadError {
///   static let users = Self.init(
///     load: { _ in
///        Just([User.blob, .blobJr, .blobSr])
///          .delay(for: .seconds(1), scheduler: DispatchQueue.main) // simulate a database call
///          .setFailureType(to: LoadError.self)
///          .eraseToEffect()
///     },
///     mainQueue: .main
///   )
/// }
///
/// let usersReducer = Reducer<
///    LoadableListViewStateFor<User, LoadError>,
///   LoadableListViewActionFor<User, LoadError>,
///    LoadableListViewEnvironmentFor<User, EmptyLoadRequest, LoadError>
/// >.empty
///   .loadableList(
///      state: \.self,
///      action: /LoadableListViewActionFor<User, LoadError>.self,
///      environment: { $0 }
///   )
///
/// struct LoadableListViewPreviewWithEditModeButton: View {
///   let store: Store<LoadableListViewStateFor<User, LoadError>, LoadableListViewActionFor<User, LoadError>>
///
///   var body: some View {
///     NavigationView {
///        LoadableListView(store: store, autoLoad: true) { user in
///          Text(user.name)
///        }
///        .toolbar {
///           ToolbarItemGroup(placement: .confirmationAction) {
///              EditButton(
///               store: store.scope(state: \.editMode, action: LoadableListViewAction.editMode)
///              )
///           }
///       }
///      }
///   }
/// }
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct LoadableListView<
  Element: Equatable,
  Id: Hashable,
  Failure: Error,
  Row: View
>: View where Failure: Equatable {
  
  public let store: Store<LoadableListViewStateFor<Element, Failure>, LoadableListViewActionFor<Element, Failure>>
  
  let autoLoad: Bool
  let id: KeyPath<Element, Id>
  let row: (Element) -> Row
  
  /// Create a new loadable list view.
  ///
  /// - Parameters:
  ///   - store: The store for the view state.
  ///   - autoLoad: Whether we automatically load items when the view first appears.
  ///   - id: The id used to identify the row.
  ///   - row: The view builder for an individual row in the list.
  public init(
    store: Store<LoadableListViewStateFor<Element, Failure>, LoadableListViewActionFor<Element, Failure>>,
    autoLoad: Bool = true,
    id: KeyPath<Element, Id>,
    @ViewBuilder row: @escaping (Element) -> Row
  ) {
    self.autoLoad = autoLoad
    self.store = store
    self.row = row
    self.id = id
  }
  
  public var body: some View {
    WithViewStore(store) { viewStore in
      LoadableView(
        store: store.scope(state: \.loadable),
        autoLoad: autoLoad,
        onLoad: .load(.load)
      ) { store in
        WithViewStore(store) { loadedViewStore in
          List {
            ForEach(loadedViewStore.state, id: id) {
              row($0)
            }
            .onDelete { loadedViewStore.send(.list(.delete($0))) }
            .onMove { loadedViewStore.send(.list(.move($0, $1))) }
          }
        }
      }
      .editMode(
        store.scope(state: \.editMode, action: LoadableListViewAction.editMode)
      )
    }
  }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension LoadableListView where Element: Identifiable, Id == Element.ID {
  /// Create a new loadable list view.
  ///
  /// - Parameters:
  ///   - store: The store for the view state.
  ///   - autoLoad: Whether we automatically load items when the view first appears.
  ///   - row: The view builder for an individual row in the list.
  public init(
    store: Store<LoadableListViewStateFor<Element, Failure>, LoadableListViewActionFor<Element, Failure>>,
    autoLoad: Bool = true,
    @ViewBuilder row: @escaping (Element) -> Row
  ) {
    self.init(
      store: store,
      autoLoad: autoLoad,
      id: \.id,
      row: row
    )
  }
}

// MARK: - Preview
#if DEBUG
  import Combine
  import PreviewSupport

  extension LoadableListViewEnvironment where Element == User, LoadRequest == EmptyLoadRequest, Failure == LoadError {
    public static let users = Self.init(
      load: { _ in
        Just([User.blob, .blobJr, .blobSr])
          .delay(for: .seconds(1), scheduler: DispatchQueue.main)
          .setFailureType(to: LoadError.self)
          .eraseToEffect()
      },
      mainQueue: .main
    )
  }

  let usersReducer = Reducer<
    LoadableListViewStateFor<User, LoadError>,
    LoadableListViewActionFor<User, LoadError>,
    LoadableListViewEnvironmentFor<User, EmptyLoadRequest, LoadError>
  >.empty
    .loadableList(
      state: \.self,
      action: /LoadableListViewActionFor<User, LoadError>.self,
      environment: { $0 }
    )

  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  struct LoadableListViewPreviewWithEditModeButton: View {
    let store: Store<LoadableListViewStateFor<User, LoadError>, LoadableListViewActionFor<User, LoadError>>

    var body: some View {
      NavigationView {
        LoadableListView(store: store, autoLoad: true) { user in
          Text(user.name)
        }
        .toolbar {
          ToolbarItemGroup(placement: .confirmationAction) {
            EditButton(
              store: store.scope(state: \.editMode, action: LoadableListViewAction.editMode)
            )
          }
        }
      }
    }
  }

  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  struct LoadableListView_Previews: PreviewProvider {
    static var previews: some View {
      LoadableListViewPreviewWithEditModeButton(
        store: .init(
          initialState: .init(),
          reducer: usersReducer,
          environment: .users
        )
      )
    }
  }
#endif
