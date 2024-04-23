import CasePaths
import ComposableArchitecture
import CustomDump
import Foundation

/// Represents different states of a loadable value.
///
@CasePathable
@ObservableState
public enum LoadableState<Value> {

  /// Set when the value has not been requested / loaded yet.
  case notRequested

  /// Set when the value is loading, but has been requested previously.
  case isLoading(previous: Value?)

  /// Set when the value is loaded.
  case loaded(Value)

  /// Access the loaded value if it's been set.
  public var rawValue: Value? {
    get {
      switch self {
      case .notRequested:
        return nil
      case .isLoading(previous: let last):
        return last
      case .loaded(let value):
        return value
      }
    }
    set {
      guard let value = newValue else {
        self = .notRequested
        return
      }
      self = .loaded(value)
    }
  }
}
extension LoadableState: Equatable where Value: Equatable {}

extension LoadableState: Hashable where Value: Hashable {}

extension LoadableState: Decodable where Value: Decodable {
  public init(from decoder: Decoder) throws {
    do {
      let decoded = try decoder.singleValueContainer().decode(Value.self)
      self = .loaded(decoded)
    } catch {
      let decoded = try Value.init(from: decoder)
      self = .loaded(decoded)
    }
  }
}
extension LoadableState: Encodable where Value: Encodable {
  public func encode(to encoder: Encoder) throws {
    do {
      var container = encoder.singleValueContainer()
      try container.encode(self.rawValue)
    } catch {
      try self.rawValue?.encode(to: encoder)
    }
  }
}

/// Represents the actions for a loadable value.
@CasePathable
public enum LoadableAction<State> {

  /// Represents when the value should be loaded from a remote source.
  case load

  /// Receive a loaded value from a remote source.
  case receiveLoaded(TaskResult<State>)

}
extension LoadableAction: Equatable where State: Equatable {}

extension Reducer {

  /// Enhances a reducer with the default ``LoadableAction`` implementations.
  ///
  /// The default implementation will handle setting the ``LoadableState`` appropriately
  /// when a value has been loaded from a remote and use the `loadOperation` passed in
  /// to load the value when the `triggerAction` is received.
  ///
  /// > Note: The default implementation does not handle failures during loading, to handle errors
  /// > your parent reducer should handle the `.receiveLoaded(.failure(let error))`.
  ///
  ///
  /// - Parameters:
  ///   - toLoadableState: The key path from the parent state to a ``LoadableState`` instance.
  ///   - toLoadableAction: The case path from the parent action to a ``LoadableAction`` case.
  ///   - triggerAction: The case path from the parent action that triggers loading the value.
  ///   - loadOperation: The operation used to load the value when the `.load` action is received.
  public func loadable<Value: Equatable, TriggerAction>(
    state toLoadableState: WritableKeyPath<State, LoadableState<Value>>,
    action toLoadableAction: CaseKeyPath<Action, LoadableAction<Value>>,
    on triggerAction: CaseKeyPath<Action, TriggerAction>,
    operation loadOperation: @Sendable @escaping () async throws -> Value
  ) -> _LoadableReducer<Self, Value, TriggerAction> {
    .init(
      parent: self,
      toLoadableState: toLoadableState,
      toLoadableAction: AnyCasePath(toLoadableAction),
      loadOperation: loadOperation,
      triggerAction: AnyCasePath(triggerAction)
    )
  }

  /// Enhances a reducer with the default ``LoadableAction`` implementations.
  ///
  /// The default implementation will handle setting the ``LoadableState`` appropriately
  /// when a value has been loaded from a remote and calls the ``LoadableAction/load`` action
  /// to load the value when the `triggerAction` is received.
  ///
  /// > Note: The default implementation does not handle failures during loading, to handle errors
  /// > your parent reducer should handle the `.receiveLoaded(.failure(let error))`.
  ///
  ///
  /// - Parameters:
  ///   - toLoadableState: The key path from the parent state to a ``LoadableState`` instance.
  ///   - toLoadableAction: The case path from the parent action to a ``LoadableAction`` case.
  ///   - triggerAction: The case path from the parent action that triggers loading the value.
  public func loadable<Value: Equatable, TriggerAction>(
    state toLoadableState: WritableKeyPath<State, LoadableState<Value>>,
    action toLoadableAction: CaseKeyPath<Action, LoadableAction<Value>>,
    on triggerAction: CaseKeyPath<Action, TriggerAction>
  ) -> _LoadableReducer<Self, Value, TriggerAction> {
    .init(
      parent: self,
      toLoadableState: toLoadableState,
      toLoadableAction: AnyCasePath(toLoadableAction),
      loadOperation: nil,
      triggerAction: AnyCasePath(triggerAction)
    )
  }

  /// Enhances a reducer with the default ``LoadableAction`` implementations. Requires
  /// manually handling the loadable actions in the parent reducer.
  ///
  ///
  /// The default implementation will handle setting the ``LoadableState`` appropriately
  /// when a value has been loaded from a remote. This overload requires you to manage calling
  /// the `.load` action from the parent reducer
  ///
  /// > Note: The default implementation does not handle failures during loading, to handle errors
  /// > your parent reducer should handle the `.receiveLoaded(.failure(let error))`.
  ///
  ///
  /// - Parameters:
  ///   - toLoadableState: The key path from the parent state to a ``LoadableState`` instance.
  ///   - toLoadableAction: The case path from the parent action to a ``LoadableAction`` case.
  ///   - loadOperation: The operation used to load the value when the `.load` action is received.
  public func loadable<Value: Equatable>(
    state toLoadableState: WritableKeyPath<State, LoadableState<Value>>,
    action toLoadableAction: CaseKeyPath<Action, LoadableAction<Value>>,
    operation loadOperation: @Sendable @escaping () async throws -> Value
  ) -> _LoadableReducer<Self, Value, LoadableAction<Value>> {
    .init(
      parent: self,
      toLoadableState: toLoadableState,
      toLoadableAction: AnyCasePath(toLoadableAction),
      loadOperation: loadOperation,
      triggerAction: nil
    )
  }

  /// Enhances a reducer with the default ``LoadableAction`` implementations. Requires
  /// manually handling the loadable actions in the parent reducer.
  ///
  ///
  /// The default implementation will handle setting the ``LoadableState`` appropriately
  /// when a value has been loaded from a remote. This overload requires you to manage calling
  /// the `.load` action from the parent reducer as well as supplying the operation to load the
  /// value when the `.load` action is called.
  ///
  /// > Note: The default implementation does not handle failures during loading, to handle errors
  /// > your parent reducer should handle the `.receiveLoaded(.failure(let error))`.
  ///
  ///
  /// - Parameters:
  ///   - toLoadableState: The key path from the parent state to a ``LoadableState`` instance.
  ///   - toLoadableAction: The case path from the parent action to a ``LoadableAction`` case.
  public func loadable<Value: Equatable>(
    state toLoadableState: WritableKeyPath<State, LoadableState<Value>>,
    action toLoadableAction: CaseKeyPath<Action, LoadableAction<Value>>
  ) -> _LoadableReducer<Self, Value, LoadableAction<Value>> {
    .init(
      parent: self,
      toLoadableState: toLoadableState,
      toLoadableAction: AnyCasePath(toLoadableAction),
      loadOperation: nil,
      triggerAction: nil
    )
  }
}

extension Effect {

  /// A convenience extension to call a ``LoadableAction/receiveLoaded(_:)`` with the given
  /// operation.
  ///
  /// This is useful if you are managing the ``LoadableAction`` in the parent reducer or using one of
  /// the more basic ``ComposableArchitecture/Reducer/loadable(state:action:)`` modifiers.
  ///
  /// **Example**
  /// ```swift
  /// @Reducer
  /// struct AppReducer {
  ///   struct State {
  ///     var int: LoadableState<Int> = .notRequested
  ///   }
  ///
  ///   enum Action {
  ///     case int(LoadableAction<Int>)
  ///     case task
  ///   }
  ///
  ///   var body: some ReducerOf<Self> {
  ///     Reduce<State, Action> { state, action in
  ///       switch action {
  ///       case .int:
  ///         return .none
  ///       case .task:
  ///        return .load(\.int) {
  ///           try await myIntLoader()
  ///         }
  ///       }
  ///     }
  ///     .loadable(state: \.int, action: \.int)
  ///   }
  /// ```
  ///
  /// - Parameters:
  ///   - toLoadableAction: The loadable action to call the `receiveLoaded` on.
  ///   - operation: The operation used to load the value.
  @inlinable
  public static func load<Value>(
    _ toLoadableAction: CaseKeyPath<Action, LoadableAction<Value>>,
    operation: @Sendable @escaping () async throws -> Value
  ) -> Self {
    .load(AnyCasePath(toLoadableAction), operation)
  }

  @usableFromInline
  static func load<Value>(
    _ toLoadableAction: AnyCasePath<Action, LoadableAction<Value>>,
    _ operation: @Sendable @escaping () async throws -> Value
  ) -> Self {
    .run { send in
      await send(
        toLoadableAction.embed(
          .receiveLoaded(
            TaskResult { try await operation() }
          ))
      )
    }
  }
}

/// The concrete reducer used for the default loading implementation.
///
/// This should not be used directly, instead use the ``Reducer/loadable``.
///
public struct _LoadableReducer<Parent: Reducer, Value, TriggerAction>: Reducer {

  @usableFromInline
  let parent: Parent

  @usableFromInline
  let toLoadableState: WritableKeyPath<Parent.State, LoadableState<Value>>

  @usableFromInline
  let toLoadableAction: AnyCasePath<Parent.Action, LoadableAction<Value>>

  @usableFromInline
  let loadOperation: (@Sendable () async throws -> Value)?

  @usableFromInline
  let triggerAction: AnyCasePath<Parent.Action, TriggerAction>?

  @inlinable
  public func reduce(
    into state: inout Parent.State,
    action: Parent.Action
  ) -> Effect<Parent.Action> {

    let parentEffects: Effect<Parent.Action> = self.parent.reduce(into: &state, action: action)

    // Short circuit if we are handling the trigger action.
    if let triggerAction,
      triggerAction.extract(from: action) != nil
    {
      return .merge(
        .send(toLoadableAction.embed(.load)),
        parentEffects
      )
    }

    // Handle default loadable actions, setting the loadable state
    // appropriately for the different actions.
    let currentState = state[keyPath: toLoadableState]
    var childEffects: Effect<Action> = .none

    if let loadableAction = toLoadableAction.extract(from: action) {
      switch (currentState.rawValue, loadableAction) {
      case let (childState, .load):
        state[keyPath: toLoadableState] = .isLoading(previous: childState)
        if let loadOperation {
          childEffects = .load(toLoadableAction, loadOperation)
        }
      case let (_, .receiveLoaded(.success(childState))):
        state[keyPath: toLoadableState] = .loaded(childState)
      case (_, .receiveLoaded):
        break
      }
    }

    return .merge(childEffects, parentEffects)
  }
}
