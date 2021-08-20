import ComposableArchitecture
import LoadableView
import SwiftUI

// MARK: - Environment

/// Represents the environment for a loadable list.
public struct LoadableListEnvironment<Element, LoadRequest, Failure: Error> {

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
extension LoadableListEnvironment: LoadableEnvironmentRepresentable {}
public typealias LoadableListEnvironmentFor<Element, Failure: Error> = LoadableListEnvironment<
  Element, EmptyLoadRequest, Failure
>

// MARK: - LoadableEnvironmentRepresentable Support
extension LoadableListEnvironment {
  
  /// Wraps a `LoadableEnvironmentRepresentable` in a `LoadableListEnvironment`
  ///
  /// - Parameters:
  ///   - environment: The loadable environment to transform into a list environment.
  public init<Environment: LoadableEnvironmentRepresentable>(
    environment loadableEnvironment: Environment
  )
  where
    Environment.LoadedValue == [Element],
    Environment.LoadRequest == LoadRequest,
    Environment.Failure == Failure
  {
    self.init(load: loadableEnvironment.load, mainQueue: loadableEnvironment.mainQueue)
  }
}

#if DEBUG
  extension LoadableListEnvironment {
    
    /// A concrete `LoadableListEnvironment` that fails when used.
    public static var failing: Self {
      .init(
        load: { _ in .failing("\(Self.self).load is unimplemented") },
        mainQueue: .failing("\(Self.self).mainQueue is unimplemented")
      )
    }
  }
#endif

extension LoadableListEnvironment {
  
  /// A concrete `LoadableListEnvironment` that does nothing.
  public static var noop: Self {
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
extension LoadableListViewState: Equatable where Element: Equatable, Failure: Equatable {}
public typealias LoadableListViewStateFor = LoadableListViewState

// MARK: - Action

/// Represents the actions that can be taken on a loadable list view.
public enum LoadableListViewAction<Element, Failure: Error> {
  case editMode(EditModeAction)
  case list(ListAction)
  case loadable(LoadableAction<[Element], Failure>)
}
extension LoadableListViewAction: Equatable where Element: Equatable, Failure: Equatable {}
public typealias LoadableListViewActionFor = LoadableListViewAction

extension Reducer {

  /// Enhances a reducer with loadable list actions.
  ///
  /// When using this overload the caller still needs to implement / override the `loadable(.load)`, however it handles
  /// setting the state appropriately on the loadable.
  ///
  /// - Parameters:
  ///   - state: The loadable list state.
  ///   - action: The loadable list actions.
  public func loadableList<Element, Failure>(
    state: WritableKeyPath<State, LoadableListViewState<Element, Failure>>,
    action: CasePath<Action, LoadableListViewAction<Element, Failure>>
  ) -> Reducer {
    .combine(
      Reducer<
        LoadableListViewState<Element, Failure>,
        LoadableListViewAction<Element, Failure>,
        Void
      >.empty
        .editMode(state: \.editMode, action: /LoadableListViewAction.editMode)
        .list(state: \.loadable.rawValue, action: /LoadableListViewAction.list)
        .loadable(state: \.loadable, action: /LoadableListViewAction.loadable)
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
    environment: @escaping (Environment) -> LoadableListEnvironmentFor<Element, Failure>
  ) -> Reducer where Failure: Equatable, Failure: Error {
    .combine(
      Reducer<
        LoadableListViewState<Element, Failure>,
        LoadableListViewAction<Element, Failure>,
        LoadableListEnvironment<Element, EmptyLoadRequest, Failure>
      >.empty
        .loadableList(state: \.self, action: /LoadableListViewAction.self)
        .loadable(state: \.loadable, action: /LoadableListViewAction.loadable, environment: { $0 })
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

  public let store:
    Store<LoadableListViewStateFor<Element, Failure>, LoadableListViewActionFor<Element, Failure>>

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
    store: Store<
      LoadableListViewStateFor<Element, Failure>, LoadableListViewActionFor<Element, Failure>
    >,
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
        onLoad: .loadable(.load)
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
    store: Store<
      LoadableListViewStateFor<Element, Failure>, LoadableListViewActionFor<Element, Failure>
    >,
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

  extension LoadableListEnvironment
  where Element == User, LoadRequest == EmptyLoadRequest, Failure == LoadError {
    public static let users = Self.init(
      load: { _ in
        Just([User].users)
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
    LoadableListEnvironmentFor<User, LoadError>
  >.empty
    .loadableList(
      state: \.self,
      action: /LoadableListViewActionFor.self,
      environment: { $0 }
    )

  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  struct LoadableListViewPreviewWithEditModeButton: View {
    let store:
      Store<LoadableListViewStateFor<User, LoadError>, LoadableListViewActionFor<User, LoadError>>

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
