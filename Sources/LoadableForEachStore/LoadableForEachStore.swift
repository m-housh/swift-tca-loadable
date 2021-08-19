import ComposableArchitecture
@_exported import EditModeModifier
@_exported import LoadableList
@_exported import LoadableView
import SwiftUI
import IdentifiedCollections

fileprivate struct LoadableForEachEnvironment<Element, Id: Hashable, LoadRequest, Failure: Error> {
  var load: (LoadRequest) -> Effect<IdentifiedArray<Id, Element>, Failure>
  var mainQueue: AnySchedulerOf<DispatchQueue>
  
  init(
    listEnv: LoadableListViewEnvironment<Element, LoadRequest, Failure>,
    id: KeyPath<Element, Id>
  ) {
    self.load = { request in
      listEnv.load(request)
        .map { IdentifiedArray.init(uniqueElements: $0, id: id) }
    }
    self.mainQueue = listEnv.mainQueue
  }
}
extension LoadableForEachEnvironment: LoadableEnvironmentRepresentable { }

// MARK: State
public struct LoadableForEachStoreState<Element, Id: Hashable, Failure: Error> {
  
  public var editMode: EditMode
  public var id: KeyPath<Element, Id>
  public var loadable: Loadable<IdentifiedArray<Id, Element>, Failure>
  
  fileprivate var identifiedArray: IdentifiedArray<Id, Element> {
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
  Element: Equatable,
  ElementAction,
  Id: Hashable,
  Failure: Error
> {
  case editMode(EditModeAction)
  case list(ListAction)
  case loadable(LoadableAction<IdentifiedArray<Id, Element>, Failure>)
  case element(id: Id, action: ElementAction)
}
extension LoadableForEachStoreAction: Equatable where ElementAction: Equatable, Failure: Equatable { }

extension Reducer {
  
  public func list<Element, Id: Hashable>(
    state: WritableKeyPath<State, IdentifiedArray<Id, Element>>,
    action: CasePath<Action, ListAction>
  ) -> Reducer {
    .combine(
      Reducer<IdentifiedArray<Id, Element>, ListAction, Void> { state, action, _ in
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
  
  public func list<Element, Id: Hashable>(
    state: WritableKeyPath<State, IdentifiedArray<Id, Element>?>,
    action: CasePath<Action, ListAction>
  ) -> Reducer {
    .combine(
      Reducer<IdentifiedArray<Id, Element>, ListAction, Void>
        .empty
        .list(state: \.self, action: /ListAction.self)
        .optional()
        .pullback(state: state, action: action, environment: { _ in }),
      self
    )
  }
  
  public func loadableForEachStore<
    Element,
    ElementAction,
    Id: Hashable,
    Failure: Error
  >(
    state: WritableKeyPath<State, LoadableForEachStoreState<Element, Id, Failure>>,
    action: CasePath<Action, LoadableForEachStoreAction<Element, ElementAction, Id, Failure>>
  ) -> Reducer {
    .combine(
      Reducer<
        LoadableForEachStoreState<Element, Id, Failure>,
        LoadableForEachStoreAction<Element, ElementAction, Id, Failure>,
        Void
      >.empty
        .editMode(state: \.editMode, action: /LoadableForEachStoreAction.editMode)
        .list(state: \.loadable.rawValue, action: /LoadableForEachStoreAction.list)
        .loadable(state: \.loadable, action: /LoadableForEachStoreAction.loadable)
        .pullback(state: state, action: action, environment: { _ in }),
      self
    )
  }
  
  public func loadableForEachStore<
    Element,
    ElementAction,
    Id: Hashable,
    Failure: Error
  >(
    id: KeyPath<Element, Id>,
    state: WritableKeyPath<State, LoadableForEachStoreState<Element, Id, Failure>>,
    action: CasePath<Action, LoadableForEachStoreAction<Element, ElementAction, Id, Failure>>,
    environment: @escaping (Environment) -> LoadableListViewEnvironment<Element, EmptyLoadRequest, Failure>
  ) -> Reducer {
    .combine(
      Reducer<
        LoadableForEachStoreState<Element, Id, Failure>,
        LoadableForEachStoreAction<Element, ElementAction, Id, Failure>,
        LoadableForEachEnvironment<Element, Id, EmptyLoadRequest, Failure>
      >.empty
        .editMode(state: \.editMode, action: /LoadableForEachStoreAction.editMode)
        .list(state: \.loadable.rawValue, action: /LoadableForEachStoreAction.list)
        .loadable(state: \.loadable, action: /LoadableForEachStoreAction.loadable, environment: { $0 })
        .pullback(state: state, action: action, environment: { LoadableForEachEnvironment(listEnv: environment($0), id: id) }),
      self
    )
  }
  
  public func loadableForEachStore<
    Element,
    ElementAction,
    Failure: Error
  >(
    state: WritableKeyPath<State, LoadableForEachStoreState<Element, Element.ID, Failure>>,
    action: CasePath<Action, LoadableForEachStoreAction<Element, ElementAction, Element.ID, Failure>>,
    environment: @escaping (Environment) -> LoadableListViewEnvironment<Element, EmptyLoadRequest, Failure>
  ) -> Reducer where Element: Identifiable {
    .combine(
      Reducer<
        LoadableForEachStoreState<Element, Element.ID, Failure>,
        LoadableForEachStoreAction<Element, ElementAction, Element.ID, Failure>,
        LoadableListViewEnvironment<Element, EmptyLoadRequest, Failure>
      >.empty
        .loadableForEachStore(id: \Element.id, state: \.self, action: /LoadableForEachStoreAction.self, environment: { $0 })
        .pullback(state: state, action: action, environment: environment),
      self
    )
  }
  
  public func loadableForEachStore<
    Element,
    ElementAction,
    ElementEnvironment,
    Id: Hashable,
    Failure: Error
  >(
    id: KeyPath<Element, Id>,
    state: WritableKeyPath<State, LoadableForEachStoreState<Element, Id, Failure>>,
    action: CasePath<Action, LoadableForEachStoreAction<Element, ElementAction, Id, Failure>>,
    environment: @escaping (Environment) -> LoadableListViewEnvironment<Element, EmptyLoadRequest, Failure>,
    forEach elementReducer: Reducer<Element, ElementAction, ElementEnvironment>,
    elementEnvironment: @escaping (Environment) -> ElementEnvironment
  ) -> Reducer {
    
    let reducer = Reducer<
      LoadableForEachStoreState<Element, Id, Failure>,
      LoadableForEachStoreAction<Element, ElementAction, Id, Failure>,
      LoadableForEachEnvironment<Element, Id, EmptyLoadRequest, Failure>
    >.empty
      .editMode(state: \.editMode, action: /LoadableForEachStoreAction.editMode)
      .list(state: \.loadable.rawValue, action: /LoadableForEachStoreAction.list)
      .loadable(state: \.loadable, action: /LoadableForEachStoreAction.loadable, environment: { $0 })
      .pullback(state: state, action: action, environment: { LoadableForEachEnvironment(listEnv: environment($0), id: id) })
    
    
    return .combine(
      reducer.forEach(elementReducer: elementReducer, environment: elementEnvironment),
      self
    )
  }
  
  public func loadableForEachStore<
    Element,
    ElementAction,
    ElementEnvironment,
    Failure: Error
  >(
    state: WritableKeyPath<State, LoadableForEachStoreState<Element, Element.ID, Failure>>,
    action: CasePath<Action, LoadableForEachStoreAction<Element, ElementAction, Element.ID, Failure>>,
    environment: @escaping (Environment) -> LoadableListViewEnvironment<Element, EmptyLoadRequest, Failure>,
    forEach elementReducer: Reducer<Element, ElementAction, ElementEnvironment>,
    elementEnvironment: @escaping (Environment) -> ElementEnvironment
  ) -> Reducer where Element: Identifiable {
    loadableForEachStore(
      id: \.id,
      state: state,
      action: action,
      environment: environment,
      forEach: elementReducer,
      elementEnvironment: elementEnvironment
    )
  }
  
  public func loadableForEachStore<
    Element,
    ElementAction,
    Failure: Error
  >(
    state: WritableKeyPath<State, LoadableForEachStoreState<Element, Element.ID, Failure>>,
    action: CasePath<Action, LoadableForEachStoreAction<Element, ElementAction, Element.ID, Failure>>,
    environment: @escaping (Environment) -> LoadableListViewEnvironment<Element, EmptyLoadRequest, Failure>,
    forEach elementReducer: Reducer<Element, ElementAction, Void>
  ) -> Reducer where Element: Identifiable {
    loadableForEachStore(
      id: \.id,
      state: state,
      action: action,
      environment: environment,
      forEach: elementReducer,
      elementEnvironment: { _ in }
    )
  }
  
  
  public func loadableForEachStore<
    Element,
    ElementAction,
    Id: Hashable,
    Failure: Error
  >(
    id: KeyPath<Element, Id>,
    state: WritableKeyPath<State, LoadableForEachStoreState<Element, Id, Failure>>,
    action: CasePath<Action, LoadableForEachStoreAction<Element, ElementAction, Id, Failure>>,
    environment: @escaping (Environment) -> LoadableListViewEnvironment<Element, EmptyLoadRequest, Failure>,
    forEach elementReducer: Reducer<Element, ElementAction, Void>
  ) -> Reducer {
    self.loadableForEachStore(
      id: id,
      state: state,
      action: action,
      environment: environment,
      forEach: elementReducer,
      elementEnvironment: { _ in }
    )
  }
  
  // These cause crashes for some reason in previews, but work in an application.
  public func forEach<
   Element,
   ElementAction,
   ElementEnvironment,
   Id: Hashable,
   Failure: Error
  >(
    elementReducer: Reducer<Element, ElementAction, ElementEnvironment>,
    environment: @escaping (Environment) -> ElementEnvironment
  ) -> Reducer where State == LoadableForEachStoreState<Element, Id, Failure>,
                     Action == LoadableForEachStoreAction<Element, ElementAction, Id, Failure>
  {
    self.combined(with:
      elementReducer.forEach(
        state: \.identifiedArray,
        action: /Action.element(id:action:),
        environment: { environment($0) }
      )
    )
  }
  
  public func forEach<
   Element,
   ElementAction,
   Id: Hashable,
   Failure: Error
  >(
    elementReducer: Reducer<Element, ElementAction, Void>
  ) -> Reducer where State == LoadableForEachStoreState<Element, Id, Failure>,
                     Action == LoadableForEachStoreAction<Element, ElementAction, Id, Failure>
  {
    self.forEach(elementReducer: elementReducer, environment: { _ in })
  }
}

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
      LoadableForEachStoreState<Element, Element.ID, Failure>,
      LoadableForEachStoreAction<Element, ElementAction, Element.ID, Failure>
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

  // Crashes in previews, but works in a real application.
//  let previewReducer = Reducer<
//    LoadableForEachStoreState<User, User.ID, LoadError>,
//    LoadableForEachStoreAction<User, UserAction, User.ID, LoadError>,
//    LoadableListViewEnvironment<User, EmptyLoadRequest, LoadError>
//  >.empty
//    .loadableForEachStore(
//      state: \.self,
//      action: /LoadableForEachStoreAction.self,
//      environment: { $0 }
//    )
//    .forEach(elementReducer: userReducer)
    
let previewReducer = Reducer<
  LoadableForEachStoreState<User, User.ID, LoadError>,
  LoadableForEachStoreAction<User, UserAction, User.ID, LoadError>,
  LoadableListViewEnvironment<User, EmptyLoadRequest, LoadError>
>.combine(
  userReducer.forEach(
    state: \LoadableForEachStoreState<User, User.ID, LoadError>.identifiedArray,
    action: /LoadableForEachStoreAction<User, UserAction, User.ID, LoadError>.element(id:action:),
    environment: { _ in }
  ),
  Reducer<
    LoadableForEachStoreState<User, User.ID, LoadError>,
    LoadableForEachStoreAction<User, UserAction, User.ID, LoadError>,
    LoadableListViewEnvironment<User, EmptyLoadRequest, LoadError>
  >.empty
    .loadableForEachStore(
      state: \.self,
      action: /LoadableForEachStoreAction.self,
      environment: { $0 }
    )
//    .forEach(elementReducer: userReducer, environment: { _ in })
)

  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  public struct LoadableForEachStore_Previews: PreviewProvider {
    public static var previews: some View {
      LoadableForEachStore<
        User,
        UserAction,
        User.ID,
        LoadError,
        WithViewStore<
          User,
          UserAction,
          AnyView
        >
      >(
        store: .init(
          initialState: LoadableForEachStoreState<User, User.ID, LoadError>(),
          reducer: previewReducer.debug(),
          environment: LoadableListViewEnvironment.users
        ),
        autoLoad: true
      ) { store in
        WithViewStore(store) { viewStore in
          AnyView(HStack {
            Text(viewStore.name)
            Spacer()
            Toggle(
              "Favorite",
              isOn: viewStore.binding(keyPath: \.isFavorite, send: UserAction.binding)
            )
          })
        }
      }
//      LoadableForEachStore(
//        store: .init(
//          initialState: .init(),
//          reducer: previewReducer,
//          environment: .users
//        ),
//        autoLoad: true
//      ) { store in
//        WithViewStore(store) { viewStore in
//          HStack {
//            Text(viewStore.name)
//            Spacer()
//            Toggle("Favorite", isOn: viewStore.binding(keyPath: \.isFavorite, send: UserAction.binding))
//          }
//        }
//      }
    }
  }

#endif
