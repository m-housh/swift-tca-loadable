import ComposableArchitecture
import LoadableView

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
  ) -> Reducer
  where
    State == LoadableForEachState<Element, Id, Failure>,
    Action == LoadableForEachAction<Element, ElementAction, Id, Failure>
  {
    combined(
      with:
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
  ) -> Reducer
  where
    State == LoadableForEachState<Element, Id, Failure>,
    Action == LoadableForEachAction<Element, ElementAction, Id, Failure>
  {
    forEach(elementReducer: elementReducer, environment: { _ in })
  }
}

// MARK: - LoadableForEachStore

extension Reducer {

  // Adds minimal functionality / excludes `forEach` / excludes loading.  Includes loadable state changes, edit mode, and list actions.
  public func loadableForEachStore<
    Element,
    ElementAction,
    Id: Hashable,
    Failure: Error
  >(
    state: WritableKeyPath<State, LoadableForEachState<Element, Id, Failure>>,
    action: CasePath<Action, LoadableForEachAction<Element, ElementAction, Id, Failure>>
  ) -> Reducer {
    .combine(
      Reducer<
        LoadableForEachState<Element, Id, Failure>,
        LoadableForEachAction<Element, ElementAction, Id, Failure>,
        Void
      >.empty
        .editMode(state: \.editMode, action: /LoadableForEachAction.editMode)
        .list(state: \.loadable.rawValue, action: /LoadableForEachAction.list)
        .loadable(state: \.loadable, action: /LoadableForEachAction.loadable)
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
    state: WritableKeyPath<State, LoadableForEachState<Element, Id, Failure>>,
    action: CasePath<Action, LoadableForEachAction<Element, ElementAction, Id, Failure>>,
    environment: @escaping (Environment) -> LoadableForEachEnvironment<
      Element, Id, EmptyLoadRequest, Failure
    >
  ) -> Reducer {
    .combine(
      Reducer<
        LoadableForEachState<Element, Id, Failure>,
        LoadableForEachAction<Element, ElementAction, Id, Failure>,
        LoadableForEachEnvironment<Element, Id, EmptyLoadRequest, Failure>
      >.empty
        .editMode(state: \.editMode, action: /LoadableForEachAction.editMode)
        .list(state: \.loadable.rawValue, action: /LoadableForEachAction.list)
        .loadable(state: \.loadable, action: /LoadableForEachAction.loadable, environment: { $0 })
        .pullback(state: state, action: action, environment: environment),
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
    state: WritableKeyPath<State, LoadableForEachState<Element, Id, Failure>>,
    action: CasePath<Action, LoadableForEachAction<Element, ElementAction, Id, Failure>>,
    environment: @escaping (Environment) -> LoadableForEachEnvironment<
      Element, Id, EmptyLoadRequest, Failure
    >,
    forEach elementReducer: Reducer<Element, ElementAction, ElementEnvironment>,
    elementEnvironment: @escaping (Environment) -> ElementEnvironment
  ) -> Reducer {
    .combine(
      // Add the for each actions to the reducer.
      Reducer<
        LoadableForEachState<Element, Id, Failure>,
        LoadableForEachAction<Element, ElementAction, Id, Failure>,
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
    state: WritableKeyPath<State, LoadableForEachState<Element, Id, Failure>>,
    action: CasePath<Action, LoadableForEachAction<Element, ElementAction, Id, Failure>>,
    environment: @escaping (Environment) -> LoadableForEachEnvironment<
      Element, Id, EmptyLoadRequest, Failure
    >,
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
    state: WritableKeyPath<State, LoadableForEachStateFor<Element, Failure>>,
    action: CasePath<Action, LoadableForEachStoreActionFor<Element, ElementAction, Failure>>,
    environment: @escaping (Environment) -> LoadableForEachEnvironmentFor<Element, Failure>,
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
    state: WritableKeyPath<State, LoadableForEachStateFor<Element, Failure>>,
    action: CasePath<Action, LoadableForEachStoreActionFor<Element, ElementAction, Failure>>,
    environment: @escaping (Environment) -> LoadableForEachEnvironmentFor<Element, Failure>,
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
    state: WritableKeyPath<State, LoadableForEachStateFor<Element, Failure>>,
    action: CasePath<Action, LoadableForEachStoreActionFor<Element, ElementAction, Failure>>,
    environment: @escaping (Environment) -> LoadableForEachEnvironmentFor<Element, Failure>
  ) -> Reducer {
    loadableForEachStore(
      id: \.id,
      state: state,
      action: action,
      environment: environment
    )
  }
}
