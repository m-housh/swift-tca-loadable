import ComposableArchitecture
import IdentifiedCollections
import LoadableList
import LoadableView
import SwiftUI
import XCTestDynamicOverlay

// MARK: Environment

/// Represents the environment for a `LoadableForEach` view.
public struct LoadableForEachEnvironment<Element, Id: Hashable, LoadRequest, Failure: Error> {

  /// Load the elements.
  public var load: (LoadRequest) -> Effect<IdentifiedArray<Id, Element>, Failure>

  /// The main dispatch queue.
  public var mainQueue: AnySchedulerOf<DispatchQueue>

  /// Create a new environment.
  ///
  /// - Parameters:
  ///   - load: Load the elements.
  ///   - mainQueue: The main dispatch queue.
  public init(
    load: @escaping (LoadRequest) -> Effect<IdentifiedArray<Id, Element>, Failure>,
    mainQueue: AnySchedulerOf<DispatchQueue>
  ) {
    self.load = load
    self.mainQueue = mainQueue
  }
}
extension LoadableForEachEnvironment: LoadableEnvironmentRepresentable {}

/// A convenience for when the element is `Identifiable` and there is an `EmptyLoadRequest`.
public typealias LoadableForEachEnvironmentFor<Element, Failure: Error> =
  LoadableForEachEnvironment<Element, Element.ID, EmptyLoadRequest, Failure>
where Element: Identifiable

extension LoadableForEachEnvironment {

  // MARK: - LoadableListEnvironment Support

  /// Wraps a `LoadableListEnvironment` and returns an `IdentifiedArray` to be used in for each stores.
  ///
  /// - Parameters:
  ///   - id: The key path to the id of the element.
  ///   - listEnvironment: The list environment to derive our `load` method from.
  public init(
    id: KeyPath<Element, Id>,
    environment listEnvironment: LoadableListEnvironment<Element, LoadRequest, Failure>
  ) {
    self.init(
      load: { request in
        listEnvironment.load(request)
          .map { IdentifiedArray.init(uniqueElements: $0, id: id) }
      },
      mainQueue: listEnvironment.mainQueue
    )
  }

  /// Wraps a `LoadableListEnvironment` and returns an `IdentifiedArray` to be used in for each stores, when the element is `Identifiable`.
  ///
  /// - Parameters:
  ///   - listEnvironment: The list environment to derive our `load` method from.
  public init(
    environment listEnvironment: LoadableListEnvironment<Element, LoadRequest, Failure>
  ) where Element: Identifiable, Id == Element.ID {
    self.init(id: \.id, environment: listEnvironment)
  }

  // MARK: LoadableEnvironmentRepresentable Support
  
  /// Wraps a `LoadableEnvironmentRepresentable` in a `LoadableForEachEnvironment`.
  ///
  /// - Parameters:
  ///   - loadableEnvironment: The loadable environment to transform to a for each environment.
  public init<Environment: LoadableEnvironmentRepresentable>(
    environment loadableEnvironment: Environment
  )
  where
    Environment.LoadedValue == IdentifiedArray<Id, Element>,
    Environment.Failure == Failure,
    Environment.LoadRequest == LoadRequest
  {
    self.init(load: loadableEnvironment.load, mainQueue: loadableEnvironment.mainQueue)
  }
}

#if DEBUG
  extension LoadableForEachEnvironment {
    
    /// A concrete `LoadableForEachEnvironment` that fails.
    public static var failing: Self {
      .init(
        load: { _ in
          XCTFail("\(Self.self).load is unimplemented")
          return .none
        },
        mainQueue: .failing("\(Self.self).mainQueue is unimplemented")
      )
    }
  }
#endif

extension LoadableForEachEnvironment {
  
  /// A concrete `LoadableForEachEnvironment` that does nothing.
  public static var noop: Self {
    .init(
      load: { _ in
        return .none
      },
      mainQueue: .main
    )
  }
}
// MARK: State

/// Represents the state for a loadable for each view.
public struct LoadableForEachState<Element, Id: Hashable, Failure: Error> {

  /// The edit mode of the view.
  public var editMode: EditMode

  /// The key path for an element's id.
  public var id: KeyPath<Element, Id>

  /// The loadable elements.
  public var loadable: Loadable<IdentifiedArray<Id, Element>, Failure>

  // allows the for each to work on reducers, could not find an easy way
  // to get to work with the optional identified array that's
  // returned from the loadable, so we return an empty identified
  // array until we have loaded.
  internal var identifiedArray: IdentifiedArray<Id, Element> {
    get { loadable.rawValue ?? .init(uniqueElements: [], id: id) }
    set { loadable.rawValue = newValue }
  }

  /// Create a new state.
  ///
  /// - Parameters:
  ///   - editMode: The edit mode of the view.
  ///   - id: The key path for an element's id.
  ///   - loadable: The loadable elements..
  public init(
    editMode: EditMode = .inactive,
    id: KeyPath<Element, Id>,
    loadable: Loadable<IdentifiedArray<Id, Element>, Failure> = .notRequested
  ) {
    self.editMode = editMode
    self.id = id
    self.loadable = loadable
  }
}
extension LoadableForEachState: Equatable where Element: Equatable, Failure: Equatable {}

// MARK: - State + Identifiable Support

/// Convenience for when the element is `Identifiable`.
public typealias LoadableForEachStateFor<Element, Failure: Error> = LoadableForEachState<
  Element, Element.ID, Failure
>
where Element: Identifiable

extension LoadableForEachState where Element: Identifiable, Id == Element.ID {

  /// Convenience for when the element is `Identifiable`.
  ///
  /// - Parameters:
  ///   - editMode: The edit mode of the view.
  ///   - loadable: The loadable elements..
  public init(
    editMode: EditMode = .inactive,
    loadable: Loadable<IdentifiedArray<Element.ID, Element>, Failure> = .notRequested
  ) {
    self.init(
      editMode: editMode,
      id: \.id,
      loadable: loadable
    )
  }
}

// MARK: - Action

/// Represents the actions taken on a loadable for each view.
public enum LoadableForEachAction<
  Element,
  ElementAction,
  Id: Hashable,
  Failure: Error
> {

  /// The edit mode actions.
  case editMode(EditModeAction)

  /// The list actions.
  case list(ListAction)

  /// The loadable element actions.
  case loadable(LoadableAction<IdentifiedArray<Id, Element>, Failure>)

  /// The for each actions for an individual element.
  case element(id: Id, action: ElementAction)
}
extension LoadableForEachAction: Equatable
where Element: Equatable, ElementAction: Equatable, Failure: Equatable {}

// MARK: - Action + Identifiable Support

/// Convenience for when the element is `Identifiable`.
public typealias LoadableForEachStoreActionFor<
  Element,
  ElementAction,
  Failure: Error
> = LoadableForEachAction<Element, ElementAction, Element.ID, Failure> where Element: Identifiable

// MARK: - View

/// A loadable list view that gives the caller access to a `ForEachStore`, once the elements have loaded.
///
/// **Example**
/// ```swift
///
/// // setup types.
/// public struct User: Equatable, Identifiable {
///    public let id: UUID = UUID()
///    public var name: String
///    public var isFavorite: Bool
///
///    public init(name: String, isFavorite: Bool = false) {
///      self.name = name
///      self.isFavorite = isFavorite
///    }
///
///    public static let blob = User.init(name: "blob")
///    public static let blobJr = User.init(name: "blob-jr")
///    public static let blobSr = User.init(name: "blob-sr")
/// }
///
/// extension Array where Element == User {
///   public static let users: Self = [.blob, .blobJr, .blobSr]
/// }
///
/// public enum UserAction: Equatable {
///   case binding(BindingAction<User>)
/// }
///
/// public let userReducer = Reducer<User, UserAction, Void>.empty
///   .binding(action: /UserAction.binding)
///
/// public enum LoadError: Error, Equatable {
///   case loadingFailed
/// }
///
/// // Create the environment dependency.
/// extension LoadableForEachEnvironment where
///   Element == User,
///   Id = User.ID,
///   LoadRequest = EmptyLoadRequest,
///   Failure == LoadError
/// {
///   state let live = Self.init(
///     load: { _ in
///       Just(.init(uniqueElements: .users))
///         .delay(for: .seconds(1), scheduler: DispatchQueue.main) // simulate loading.
///         .setFailureType(to: LoadError.self)
///         .eraseToEffect()
///     },
///     mainQueue: .main
///   )
/// }
///
///
/// // Create the reducer.
/// let appReducer = Reducer<
///   LoadableForEachStateFor<User, LoadError>,
///   LoadableForEachStoreActionFor<User, UserAction, LoadError>,
///   LoadableForEachEnvironmentFor<User, LoadError>
/// >.empty
///   .loadableForEachStore(
///     state: \.self,
///     action: /LoadableForEachAction.self,
///     environment: { $0 },
///     forEach: userReducer
///   )
///
/// // Use the for each view, you would typically not create the store inside the body, but just
/// // an example of what it looks like.
/// struct AppView: View {
///   var body: some View {
///     LoadableForEachStore(
///       store: .init(
///         initialState: .init(),
///         reducer: appReducer,
///         environment: .live
///       )
///     ) { store in
///       WithViewStore(store) { viewStore in
///         HStack {
///           Text(viewStore.name)
///           Spacer()
///           Toggle(
///             "Favorite"
///              isOn: viewStore.binding(keyPath: \.isFavorite, send: UserAction.binding)
///           )
///         }
///       }
///     }
///   }
/// }
/// ```
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct LoadableForEachStore<
  Element: Equatable,
  ElementAction: Equatable,
  Id: Hashable,
  Failure: Error,
  Row: View
>: View where Failure: Equatable {

  /// The store for our state and actions.
  public let store:
    Store<
      LoadableForEachState<Element, Id, Failure>,
      LoadableForEachAction<Element, ElementAction, Id, Failure>
    >

  /// Flag for if we automatically load the elements when the view appears.
  let autoLoad: Bool

  /// Create the content / row for the given element.
  let row: (Store<Element, ElementAction>) -> Row

  /// Create a new loadable list view.
  ///
  /// - Parameters:
  ///   - store: The store for the view state.
  ///   - autoLoad: Whether we automatically load items when the view first appears.
  ///   - row: The view builder for an individual row in the list.
  public init(
    store: Store<
      LoadableForEachState<Element, Id, Failure>,
      LoadableForEachAction<Element, ElementAction, Id, Failure>
    >,
    autoLoad: Bool = true,
    @ViewBuilder content row: @escaping (Store<Element, ElementAction>) -> Row
  ) {
    self.autoLoad = autoLoad
    self.store = store
    self.row = row
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
            ForEachStore(
              store.scope(state: { $0 }, action: LoadableForEachAction.element(id:action:)),
              content: row
            )
            .onDelete { loadedViewStore.send(.list(.delete($0))) }
            .onMove { loadedViewStore.send(.list(.move($0, $1))) }
          }
        }
      }
      .editMode(
        store.scope(state: \.editMode, action: LoadableForEachAction.editMode)
      )
    }
  }
}

// MARK: - View + Identfiable Support
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension LoadableForEachStore where Element: Identifiable, Id == Element.ID {

  /// Create a new loadable list view, where the element is `Identifiable`.
  ///
  /// - Parameters:
  ///   - store: The store for the view state.
  ///   - autoLoad: Whether we automatically load items when the view first appears.
  ///   - row: The view builder for an individual row in the list.
  public init(
    store: Store<
      LoadableForEachState<Element, Element.ID, Failure>,
      LoadableForEachAction<Element, ElementAction, Element.ID, Failure>
    >,
    autoLoad: Bool = true,
    @ViewBuilder row: @escaping (Store<Element, ElementAction>) -> Row
  ) {
    self.autoLoad = autoLoad
    self.store = store
    self.row = row
  }
}

// MARK: - Preview
#if DEBUG
  import PreviewSupport

  let previewReducer = Reducer<
    LoadableForEachStateFor<User, LoadError>,
    LoadableForEachStoreActionFor<User, UserAction, LoadError>,
    LoadableForEachEnvironmentFor<User, LoadError>
  >.empty
    .loadableForEachStore(
      state: \.self,
      action: /LoadableForEachAction.self,
      environment: { $0 },
      forEach: userReducer
    )

  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  struct LoadableForEachStore_Previews: PreviewProvider {
    static var previews: some View {
      LoadableForEachStore(
        store: .init(
          initialState: .init(),
          reducer: previewReducer,
          environment: .init(environment: .users)
        ),
        autoLoad: true
      ) { store in
        WithViewStore(store) { viewStore in
          HStack {
            Text(viewStore.name)
            Spacer()
            Toggle(
              "Favorite",
              isOn: viewStore.binding(keyPath: \.isFavorite, send: UserAction.binding)
            )
          }
        }
      }
    }
  }

#endif
