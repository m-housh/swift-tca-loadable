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
    switch self {
    case .notRequested:
      return nil
    case .isLoading(previous: let last):
      return last
    case .loaded(let value):
      return value
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
  /// when a value has been loaded from a remote.
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
  ) -> _LoadableReducer<Self, Value> {
    .init(
      parent: self,
      toLoadableState: toLoadableState,
      toLoadableAction: AnyCasePath(toLoadableAction)
    )
  }
}

/// The concrete reducer used for the default loading implementation.
///
/// This should not be used directly, instead use the ``Reducer/loadable``.
///
public struct _LoadableReducer<Parent: Reducer, Value>: Reducer {

  @usableFromInline
  let parent: Parent

  @usableFromInline
  let toLoadableState: WritableKeyPath<Parent.State, LoadableState<Value>>

  @usableFromInline
  let toLoadableAction: AnyCasePath<Parent.Action, LoadableAction<Value>>

  @inlinable
  public func reduce(
    into state: inout Parent.State,
    action: Parent.Action
  ) -> Effect<Parent.Action> {
    let currentState = state[keyPath: toLoadableState]

    let parentEffects: Effect<Parent.Action> = self.parent.reduce(into: &state, action: action)

    if let loadableAction = toLoadableAction.extract(from: action) {
      switch (currentState.rawValue, loadableAction) {
      case let (childState, .load):
        state[keyPath: toLoadableState] = .isLoading(previous: childState)
      case let (_, .receiveLoaded(.success(childState))):
        state[keyPath: toLoadableState] = .loaded(childState)
      case (_, .receiveLoaded):
        break

      }
    } 

    return parentEffects
  }
}
