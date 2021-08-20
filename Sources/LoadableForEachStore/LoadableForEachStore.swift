import ComposableArchitecture
@_exported import EditModeModifier
@_exported import struct LoadableList.LoadableListEnvironment
@_exported import ListAction
@_exported import enum LoadableView.LoadableAction
@_exported import enum LoadableView.Loadable
import LoadableView
import SwiftUI
import IdentifiedCollections

// MARK: State
public struct LoadableForEachStoreState<Element, Id: Hashable, Failure: Error> {
  
  public var editMode: EditMode
  public var id: KeyPath<Element, Id>
  public var loadable: Loadable<IdentifiedArray<Id, Element>, Failure>
  
  // allows the for each to work on reducers, could not find an easy way
  // to get to work with the optional identified array that's
  // returned from the loadable, so we return an empty identified
  // array until we have loaded.
  internal var identifiedArray: IdentifiedArray<Id, Element> {
    get { loadable.rawValue ?? .init(uniqueElements: [], id: id) }
    set { loadable.rawValue = newValue }
  }
  
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
extension LoadableForEachStoreState: Equatable where Element: Equatable, Failure: Equatable { }
public typealias LoadableForEachStoreStateFor<Element, Failure: Error> = LoadableForEachStoreState<Element, Element.ID, Failure>
where Element: Identifiable

extension LoadableForEachStoreState where Element: Identifiable, Id == Element.ID {
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
public enum LoadableForEachStoreAction<
  Element,
  ElementAction,
  Id: Hashable,
  Failure: Error
> {
  case editMode(EditModeAction)
  case list(ListAction)
  case loadable(LoadableAction<IdentifiedArray<Id, Element>, Failure>)
  case element(id: Id, action: ElementAction)
}
extension LoadableForEachStoreAction: Equatable where Element: Equatable, ElementAction: Equatable, Failure: Equatable { }
public typealias LoadableForEachStoreActionFor<Element, ElementAction, Failure: Error> = LoadableForEachStoreAction<Element, ElementAction, Element.ID, Failure>
where Element: Identifiable

// MARK: - View
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct LoadableForEachStore<
  Element: Equatable,
  ElementAction: Equatable,
  Id: Hashable,
  Failure: Error,
  Row: View
>: View where Failure: Equatable {
  
  public let store: Store<
    LoadableForEachStoreState<Element, Id, Failure>,
    LoadableForEachStoreAction<Element, ElementAction, Id, Failure>
  >
  let autoLoad: Bool
  let row: (Store<Element, ElementAction>) -> Row
  
  /// Create a new loadable list view.
  ///
  /// - Parameters:
  ///   - store: The store for the view state.
  ///   - autoLoad: Whether we automatically load items when the view first appears.
  ///   - row: The view builder for an individual row in the list.
  public init(
    store: Store<
      LoadableForEachStoreState<Element, Id, Failure>,
      LoadableForEachStoreAction<Element, ElementAction, Id, Failure>
    >,
    autoLoad: Bool = true,
    @ViewBuilder row: @escaping (Store<Element, ElementAction>) -> Row
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
              store.scope(state: { $0 }, action: LoadableForEachStoreAction.element(id:action:)),
              content: row
            )
            .onDelete { loadedViewStore.send(.list(.delete($0))) }
            .onMove { loadedViewStore.send(.list(.move($0, $1))) }
          }
        }
      }
      .editMode(
        store.scope(state: \.editMode, action: LoadableForEachStoreAction.editMode)
      )
    }
  }
}

// MARK: - Identfiable Support
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension LoadableForEachStore where Element: Identifiable, Id == Element.ID {
  
  /// Create a new loadable list view.
  ///
  /// - Parameters:
  ///   - store: The store for the view state.
  ///   - autoLoad: Whether we automatically load items when the view first appears.
  ///   - row: The view builder for an individual row in the list.
  public init(
    store: Store<
      LoadableForEachStoreStateFor<Element, Failure>,
      LoadableForEachStoreActionFor<Element, ElementAction, Failure>
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
    LoadableForEachStoreState<User, User.ID, LoadError>,
    LoadableForEachStoreAction<User, UserAction, User.ID, LoadError>,
    LoadableListEnvironment<User, EmptyLoadRequest, LoadError>
  >.empty
    .loadableForEachStore(
      state: \.self,
      action: /LoadableForEachStoreAction.self,
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
          environment: .users
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
