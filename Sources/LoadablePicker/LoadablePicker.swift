import ComposableArchitecture
@_exported import struct LoadableList.LoadableListViewEnvironment
@_exported import struct LoadableList.LoadableListViewEnvironmentFor
@_exported import LoadableView
import SwiftUI

// MARK: - State

/// Represents the state of a loadable picker view.
public struct LoadablePickerState<Element, Id: Hashable, Failure: Error> {
  
  /// The loadable items.
  public var loadable: Loadable<[Element], Failure>
  
  public var id: KeyPath<Element, Id>
  
  /// The picker selection.
  public var selection: Element.ID?
  
  /// Create a new loadable picker state
  ///
  /// - Parameters:
  ///   - loadable: The loadable items.
  ///   - selection: The picker selection.
  public init(
    id: KeyPath<Element, Id>,
    loadable: Loadable<[Element], Failure> = .notRequested,
    selection: Id? = nil
  ) {
    self.loadable = loadable
    self.selection = selection
  }
}
extension LoadablePickerState: Equatable where Element: Equatable, Failure: Equatable { }
extension LoadablePickerState where Element: Identifiable, Id == Element.ID {
  
  public init(
    loadable: Loadable<[Element], Failure> = .notRequested,
    selection: Element.ID? = nil
  ) {
    self.init(
      id: \.id,
      loadable: loadable,
      selection: selection
    )
  }
}

// MARK: - Action

/// Represents the actions take by a loadable picker view.
public enum LoadablePickerAction<Element: Identifiable, Failure: Error> {
  
  /// Changes to the picker state.
  case binding(BindingAction<LoadablePickerState<Element, Failure>>)
  
  /// Load actions.
  case loadable(LoadableAction<[Element], Failure>)
}
extension LoadablePickerAction: Equatable where Element: Equatable, Failure: Equatable { }

extension Reducer {
  
  /// Enhances a reducer with loadable picker actions.
  ///
  /// When using this overload, the caller is responsible for implementing / calling the `loadable(.load)` action with the appropriate request type.
  /// However it handles setting the state appropriately on the loadable value.
  ///
  /// - Parameters:
  ///   - state: The loadable picker state.
  ///   - action: The loadable picker action.
  public func loadablePicker<Element: Identifiable, Failure: Error>(
    state: WritableKeyPath<State, LoadablePickerState<Element, Failure>>,
    action: CasePath<Action, LoadablePickerAction<Element, Failure>>
  ) -> Reducer {
    .combine(
      Reducer<LoadablePickerState<Element, Failure>, LoadablePickerAction<Element, Failure>, Void>
        .empty
        .binding(action: /LoadablePickerAction.binding)
        .loadable(state: \.loadable, action: /LoadablePickerAction.loadable)
        .pullback(state: state, action: action, environment: { _ in }),
      self
    )
  }
  
  /// Enhances a reducer with loadable picker actions.
  ///
  /// - Parameters:
  ///   - state: The loadable picker state.
  ///   - action: The loadable picker action.
  ///   - environment: The loadable picker environment.
  public func loadablePicker<Element: Identifiable, Failure: Error>(
    state: WritableKeyPath<State, LoadablePickerState<Element, Failure>>,
    action: CasePath<Action, LoadablePickerAction<Element, Failure>>,
    environment: @escaping (Environment) -> LoadableListViewEnvironment<Element, EmptyLoadRequest, Failure>
  ) -> Reducer {
    .combine(
      Reducer<
        LoadablePickerState<Element, Failure>,
        LoadablePickerAction<Element, Failure>,
        LoadableListViewEnvironment<Element, EmptyLoadRequest, Failure>
      >.empty
        .binding(action: /LoadablePickerAction.binding)
        .loadable(state: \.loadable, action: /LoadablePickerAction.loadable, environment: { $0 })
        .pullback(state: state, action: action, environment: environment),
      self
    )
  }
}

// MARK: - View

/// A picker whose elements can be loaded.
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
/// let usersPickerReducer = Reducer<
///    LoadablePickerState<User, LoadError>,
///    LoadablePickerAction<User, LoadError>,
///    LoadableListViewEnvironmentFor<User, EmptyLoadRequest, LoadError>
/// >.empty
///   .loadablePicker(
///      state: \.self,
///      action: /LoadablePickerAction.self,
///      environment: { $0 }
///   )
///
/// struct LoadableUserPicker: View {
///   let store: Store<LoadablePickerState<User, LoadError>, LoadablePickerAction<User, LoadError>>
///
///   var body: some View {
///     NavigationView {
///       Form {
///         LoadablePicker(
///          "User",
///          store: store,
///          allowNilSelection: true
///         ) { user in
///           Text(user.name)
///        }
///      }
///     }
///   }
/// }
// TODO: Remove Identifiable requirement.
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct LoadablePicker<
  Element: Identifiable,
  Failure: Error,
  Row: View
>: View where Failure: Equatable, Element: Equatable {
  
  /// The store  for the view.
  public let store: Store<LoadablePickerState<Element, Failure>, LoadablePickerAction<Element, Failure>>
  
  /// Flag for if we allow a nil selection.
  let allowNilSelection: Bool
  
  /// Flag for if we automatically load items when the view appears.
  let autoLoad: Bool
  
  /// The title used for a row used to set the selection to `nil`.  Will default to `"None"` if not supplied.
  let nilSelectionTitle: String?
  
  /// Creates a view for an element.
  let row: (Element) -> Row
  
  /// Creates the picker title based on the current state.
  let title: (LoadablePickerState<Element, Failure>) -> String
  
  /// Create a new loadable picker view.
  ///
  /// - Parameters:
  ///   - store: The store for the view.
  ///   - allowNilSelection: Flag for if we allow a nil selection.
  ///   - autoLoad: Flag for if we automatically load items when the view appears.
  ///   - title: The picker title based on the current state.
  ///   - nilSelectionTitle: The title used for a row used to set the selection to `nil`.  Will default to `"None"` if not supplied.
  ///   - row: Creates a view for an element.
  public init(
    store: Store<LoadablePickerState<Element, Failure>, LoadablePickerAction<Element, Failure>>,
    allowNilSelection: Bool = false,
    autoLoad: Bool = true,
    title: @escaping (LoadablePickerState<Element, Failure>) -> String = { _ in "" },
    nilSelectionTitle: String? = "None",
    @ViewBuilder row: @escaping (Element) -> Row
  ) {
    self.store = store
    self.allowNilSelection = allowNilSelection
    self.autoLoad = autoLoad
    self.title = title
    self.row = row
    self.nilSelectionTitle = allowNilSelection ?
      (nilSelectionTitle == nil ? "None" : nilSelectionTitle) :
      nilSelectionTitle
  }
  
  public var body: some View {
    WithViewStore(store) { viewStore in
      LoadableView(
        store: store.scope(state: \.loadable),
        autoLoad: autoLoad,
        onLoad: .loadable(.load)
      ) { loadedStore in
        WithViewStore(loadedStore) { loadedViewStore in
          Picker(
            title(viewStore.state),
            selection: viewStore.binding(keyPath: \.selection, send: LoadablePickerAction.binding)
          ) {
            List {
              if allowNilSelection, let nilSelectionTitle = nilSelectionTitle {
                Text(nilSelectionTitle)
                  .tag(nil as Element.ID?)
              }
              
              ForEach(loadedViewStore.state) {
                row($0)
                  .tag($0.id as Element.ID?)
              }
            }
          }
        }
      }
    }
  }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension LoadablePicker {
  
  /// Create a new loadable picker view.
  ///
  /// - Parameters:
  ///   - title: The picker title
  ///   - store: The store for the view.
  ///   - allowNilSelection: Flag for if we allow a nil selection.
  ///   - autoLoad: Flag for if we automatically load items when the view appears.
  ///   - nilSelectionTitle: The title used for a row used to set the selection to `nil`.  Will default to `"None"` if not supplied.
  ///   - row: Creates a view for an element.
  public init(
    _ title: String,
    store: Store<LoadablePickerState<Element, Failure>, LoadablePickerAction<Element, Failure>>,
    allowNilSelection: Bool = false,
    autoLoad: Bool = true,
    nilSelectionTitle: String? = nil,
    @ViewBuilder row: @escaping (Element) -> Row
  ) {
    self.init(
      store: store,
      allowNilSelection: allowNilSelection,
      autoLoad: autoLoad,
      title: { _ in title },
      nilSelectionTitle: nilSelectionTitle,
      row: row
    )
  }
}

#if DEBUG
  import PreviewSupport

  let userPickerReducer = Reducer<
    LoadablePickerState<User, LoadError>,
    LoadablePickerAction<User, LoadError>,
    LoadableListViewEnvironmentFor<User, EmptyLoadRequest, LoadError>
  >.empty
    .loadablePicker(
      state: \.self,
      action: /LoadablePickerAction.self,
      environment: { $0 }
    )

  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  struct LoadablePicker_Previews: PreviewProvider {
    static var previews: some View {
      NavigationView {
        Form {
          LoadablePicker(
            "User",
            store: .init(
              initialState: .init(),
              reducer: userPickerReducer,
              environment: .users
            ),
            allowNilSelection: true
          ) { user in
            Text(user.name)
          }
        }
      }
      NavigationView {
        Form {
          LoadablePicker(
            "User",
            store: .init(
              initialState: .init(),
              reducer: userPickerReducer,
              environment: .users
            ),
            allowNilSelection: false
          ) { user in
            Text(user.name)
          }
        }
      }
    }
  }
#endif
