import ComposableArchitecture
import LoadableView
@_exported import typealias LoadableList.LoadableListEnvironmentFor
@_exported import ListAction

// MARK: - ForEach
extension Reducer {
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
    combined(with:
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
    forEach(elementReducer: elementReducer, environment: { _ in })
  }
}

// MARK: - LoadableForEachStore

// A wrapper around a list environment, converting the loaded list into an IdentifiedArray.
fileprivate struct LoadableForEachEnvironment<Element, Id: Hashable, LoadRequest, Failure: Error> {
  
  var load: (LoadRequest) -> Effect<IdentifiedArray<Id, Element>, Failure>
  var mainQueue: AnySchedulerOf<DispatchQueue>
  
  init(
    listEnv: LoadableListEnvironment<Element, LoadRequest, Failure>,
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

extension Reducer {
  
  // Adds minimal functionality / excludes `forEach` / excludes loading.  Includes loadable state changes, edit mode, and list actions.
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
  
  // Adds all functionality except for `forEach`.
  public func loadableForEachStore<
    Element,
    ElementAction,
    Id: Hashable,
    Failure: Error
  >(
    id: KeyPath<Element, Id>,
    state: WritableKeyPath<State, LoadableForEachStoreState<Element, Id, Failure>>,
    action: CasePath<Action, LoadableForEachStoreAction<Element, ElementAction, Id, Failure>>,
    environment: @escaping (Environment) -> LoadableListEnvironment<Element, EmptyLoadRequest, Failure>
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
  
  // Adds all the functionality.
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
    environment: @escaping (Environment) -> LoadableListEnvironment<Element, EmptyLoadRequest, Failure>,
    forEach elementReducer: Reducer<Element, ElementAction, ElementEnvironment>,
    elementEnvironment: @escaping (Environment) -> ElementEnvironment
  ) -> Reducer {
    .combine(
      // Add the for each actions to the reducer.
      Reducer<
        LoadableForEachStoreState<Element, Id, Failure>,
        LoadableForEachStoreAction<Element, ElementAction, Id, Failure>,
        Environment
      >.empty
        .forEach(elementReducer: elementReducer, environment: elementEnvironment)
        .pullback(state: state, action: action, environment: { $0 })
        .loadableForEachStore(id: id, state: state, action: action, environment: environment),
      self
    )
  }
  
  // Adds all the functionality, when element environment is `Void`.
  public func loadableForEachStore<
    Element,
    ElementAction,
    Id: Hashable,
    Failure: Error
  >(
    id: KeyPath<Element, Id>,
    state: WritableKeyPath<State, LoadableForEachStoreState<Element, Id, Failure>>,
    action: CasePath<Action, LoadableForEachStoreAction<Element, ElementAction, Id, Failure>>,
    environment: @escaping (Environment) -> LoadableListEnvironment<Element, EmptyLoadRequest, Failure>,
    forEach elementReducer: Reducer<Element, ElementAction, Void>
  ) -> Reducer {
    loadableForEachStore(
      id: id,
      state: state,
      action: action,
      environment: environment,
      forEach: elementReducer,
      elementEnvironment: { _ in }
    )
  }
}

// MARK: - LoadableForEachStore - Identifiable Support
extension Reducer {
  
  // Adds all functionality, when the element is `Identifiable`.
  public func loadableForEachStore<
    Element: Identifiable,
    ElementAction,
    ElementEnvironment,
    Failure: Error
  >(
    state: WritableKeyPath<State, LoadableForEachStoreState<Element, Element.ID, Failure>>,
    action: CasePath<Action, LoadableForEachStoreAction<Element, ElementAction, Element.ID, Failure>>,
    environment: @escaping (Environment) -> LoadableListEnvironment<Element, EmptyLoadRequest, Failure>,
    forEach elementReducer: Reducer<Element, ElementAction, ElementEnvironment>,
    elementEnvironment: @escaping (Environment) -> ElementEnvironment
  ) -> Reducer {
    loadableForEachStore(
      id: \.id,
      state: state,
      action: action,
      environment: environment,
      forEach: elementReducer,
      elementEnvironment: elementEnvironment
    )
  }
  
  // Adds all functionality, when the element is `Identifiable` and element environment is `Void`.
  public func loadableForEachStore<
    Element: Identifiable,
    ElementAction,
    Failure: Error
  >(
    state: WritableKeyPath<State, LoadableForEachStoreState<Element, Element.ID, Failure>>,
    action: CasePath<Action, LoadableForEachStoreAction<Element, ElementAction, Element.ID, Failure>>,
    environment: @escaping (Environment) -> LoadableListEnvironmentFor<Element, Failure>,
    forEach elementReducer: Reducer<Element, ElementAction, Void>
  ) -> Reducer {
    loadableForEachStore(
      id: \.id,
      state: state,
      action: action,
      environment: environment,
      forEach: elementReducer
    )
  }
  
  // Adds all functionality except for `forEach`, when the element is `Identifiable`.
  public func loadableForEachStore<
    Element: Identifiable,
    ElementAction,
    Failure: Error
  >(
    state: WritableKeyPath<State, LoadableForEachStoreStateFor<Element, Failure>>,
    action: CasePath<Action, LoadableForEachStoreActionFor<Element, ElementAction, Failure>>,
    environment: @escaping (Environment) -> LoadableListEnvironmentFor<Element, Failure>
  ) -> Reducer {
    loadableForEachStore(
      id: \.id,
      state: state,
      action: action,
      environment: environment
    )
  }
}
