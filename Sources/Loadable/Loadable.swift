import ComposableArchitecture
import CustomDump
import Foundation

/// A property wrapper that wraps an item in a ``LoadingState`` that can be loaded from a remote process.
///
/// `@LoadableState var int: Int?`
///
/// See ``LoadableView`` for a more concrete usage.
///
@dynamicMemberLookup
@propertyWrapper
public struct LoadableState<Value> {

  /// Storage for the loading state.
  private var boxedValue: [LoadingState<Value>]

  /// Create a new ``LoadableState`` wrapping the passed in value (generally nil until loaded).
  ///
  /// - Parameters:
  ///   - wrappedValue: The value type that is loadable.
  public init(wrappedValue: Value?) {
    self.boxedValue = wrappedValue.map { [.loaded($0)] } ?? []
  }

  /// Access the wrapped value if it's available / been loaded.
  ///
  public var wrappedValue: Value? {
    _read { yield self.boxedValue.first?.rawValue }
    _modify {
      var state = self.boxedValue.first?.rawValue
      yield &state
      switch (state, self.boxedValue.isEmpty) {
      case (nil, true):
        return
      case (nil, false):
        self.boxedValue = []
      case let (.some(state), true):
        self.boxedValue.insert(.loaded(state), at: 0)
      case let (.some(state), false):
        self.boxedValue[0] = .loaded(state)
      }
    }
  }

  var loadingState: LoadingState<Value> {
    _read { yield self.boxedValue.first ?? .notRequested }
    _modify {
      var state = self.boxedValue.first ?? .notRequested
      yield &state
      switch self.boxedValue.isEmpty {
      case (true):
        self.boxedValue.insert(state, at: 0)
      case (false):
        self.boxedValue[0] = state
      }
    }
  }

  /// Access to the ``LoadingState``.
  public var projectedValue: LoadingState<Value> {
    get { self.loadingState }
    set { self.loadingState = newValue }
    _modify { yield &self.loadingState }
  }

  public subscript<A>(
    dynamicMember keyPath: WritableKeyPath<Value, A>
  ) -> A? {
    get { self.wrappedValue?[keyPath: keyPath] }
    set {
      guard self.wrappedValue != nil,
        let newValue
      else { return }
      self.wrappedValue![keyPath: keyPath] = newValue
    }
  }

  var _id: StableID? {
    self.wrappedValue.map(StableID.init(base:))
  }

  public var id: AnyHashable {
    self._id
  }
}
extension LoadableState: Equatable where Value: Equatable {}
extension LoadableState: Hashable where Value: Hashable {}
extension LoadableState: Identifiable where Value: Identifiable {}

extension LoadableState: Decodable where Value: Decodable {
  public init(from decoder: Decoder) throws {
    do {
      self.init(wrappedValue: try decoder.singleValueContainer().decode(Value.self))
    } catch {
      self.init(wrappedValue: try .init(from: decoder))
    }
  }
}

extension LoadableState: Encodable where Value: Encodable {
  public func encode(to encoder: Encoder) throws {
    try self.loadingState.encode(to: encoder)
  }
}

/// Represents different states of a loadable value.
///
public enum LoadingState<Value> {

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
extension LoadingState: Equatable where Value: Equatable {}

extension LoadingState: Hashable where Value: Hashable {}

extension LoadingState: Decodable where Value: Decodable {
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
extension LoadingState: Encodable where Value: Encodable {
  public func encode(to encoder: Encoder) throws {
    do {
      var container = encoder.singleValueContainer()
      try container.encode(self.rawValue)
    } catch {
      try self.rawValue?.encode(to: encoder)
    }
  }
}

#warning("This needs re-thought-out.")
/// Represents the actions for a loadable value.
public enum LoadingAction<State, Action> {

  /// Represents when the value should be loaded from a remote source.
  case load

  #warning("Should this just handle the success / not be a TaskResult?")
  /// Receive a loaded value from a remote source.
  case receiveLoaded(TaskResult<State>)

  /// Child actions for when the state has loaded.
  case loaded(Action)
}
extension LoadingAction: Equatable where State: Equatable, Action: Equatable {}

extension Reducer {

  /// Enhances a reducer with the default ``LoadingAction`` implementations.
  ///
  /// The default implementation will handle setting the ``LoadingState`` appropriately
  /// when a value has been loaded from a remote.
  ///
  /// > Note: The default implementation does not handle failures during loading, to handle errors
  /// > your parent reducer should handle the `.receiveLoaded(.failure(let error))`.
  ///
  ///
  /// - Parameters:
  ///   - toLoadableState: The key path from the parent state to a ``LoadingState`` instance.
  ///   - toLoadableAction: The case path from the parent action to a ``LoadingAction`` case.
  public func loadable<Child: Reducer>(
    state toLoadableState: WritableKeyPath<State, LoadingState<Child.State>>,
    action toLoadableAction: CasePath<Action, LoadingAction<Child.State, Child.Action>>,
    @ReducerBuilder<Child.State, Child.Action> then child: () -> Child
  ) -> _LoadableReducer<Self, Child> {
    .init(
      parent: self,
      child: child(),
      toLoadableState: toLoadableState,
      toLoadableAction: toLoadableAction
    )
  }

  // When we don't have a nested actions.
  public func loadable(
    state toLoadableState: WritableKeyPath<State, LoadingState<State>>,
    action toLoadableAction: CasePath<Action, LoadingAction<State, Action>>
  ) -> _LoadableReducer<Self, EmptyReducer<State, Action>> {
    .init(
      parent: self,
      child: EmptyReducer(),
      toLoadableState: toLoadableState,
      toLoadableAction: toLoadableAction
    )
  }
}

/// The concrete reducer used for the default loading implementation.
///
/// This should not be used directly, instead use the ``Reducer/loadable``.
///
public struct _LoadableReducer<Parent: Reducer, Child: Reducer>: Reducer {

  @usableFromInline
  let parent: Parent

  @usableFromInline
  let child: Child

  @usableFromInline
  let toLoadableState: WritableKeyPath<Parent.State, LoadingState<Child.State>>

  @usableFromInline
  let toLoadableAction: CasePath<Parent.Action, LoadingAction<Child.State, Child.Action>>

  @inlinable
  public func reduce(
    into state: inout Parent.State,
    action: Parent.Action
  ) -> Effect<Parent.Action> {
    let currentState = state[keyPath: toLoadableState]

    let parentEffects: Effect<Parent.Action> = self.parent.reduce(into: &state, action: action)
    let childEffects: Effect<Parent.Action>

    if let loadableAction = toLoadableAction.extract(from: action) {
      switch (currentState.rawValue, loadableAction) {
      case let (childState, .load):
        state[keyPath: toLoadableState] = .isLoading(previous: childState)
        childEffects = .none
      case let (_, .receiveLoaded(.success(childState))):
        state[keyPath: toLoadableState] = .loaded(childState)
        childEffects = .none
      case (_, .receiveLoaded):
        // What do we do when an error is recieved?
        childEffects = .none
      case (.some(var childState), .loaded(let childAction)):
        childEffects = self.child.reduce(into: &childState, action: childAction)
          .map { self.toLoadableAction.embed(.loaded($0)) }
      case (.none, .loaded(_)):
        XCTFail(
          """
          A loading action was recieved before the state has been loaded.
          """
        )
        childEffects = .none
      }
    } else {
      childEffects = .none
    }

    return .merge(
      childEffects,
      parentEffects
    )
  }
}
