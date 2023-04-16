import CasePaths
import ComposableArchitecture
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

  /// Access to the ``LoadingState``.
  public var loadingState: LoadingState<Value> {
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

  public var projectedValue: Self {
    get { self }
    set { self = newValue }
    _modify { yield &self }
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

  /// A convenience for setting the `isLoading` state appropriately, if the item has been
  /// loaded in the past, then it will set it's current value while the request to reload is in-flight.
  ///
  @discardableResult
  public mutating func setIsLoading() -> Self {
    self = .isLoading(previous: rawValue)
    return self
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

// MARK: - Actions

/// Represents the actions for a loadable value.
public enum LoadingAction<Value> {

  /// Represents when the value should be loaded from a remote source.
  case load

  /// Receive a loaded value from a remote source.
  case receiveLoaded(TaskResult<Value>)
}
extension LoadingAction: Equatable where Value: Equatable {}

/// Represents the actions for a loadable value.  When you mark your `Reducer`'s action as
/// a ``LoadableAction``, it unlocks some conveniences for working with loadable values.
/// While allowing your other actions to work.
///
/// In general it is best to use this on your actions instead of relying on the ``LoadingAction``, unless
/// your reducer is small and focused in only on a loadable type.
///
public protocol LoadableAction<State> {
  associatedtype State
  static func loadable(_ action: LoadingAction<State>) -> Self
}

extension LoadableAction {

  /// Represents when the value should be loaded from a remote source.
  public static var load: Self {
    .loadable(.load)
  }

  /// Receive a loaded value from a remote source.
  public static func receiveLoaded(_ result: TaskResult<State>) -> Self {
    .loadable(.receiveLoaded(result))
  }
}

extension EffectPublisher where Action: LoadableAction, Failure == Never {

  /// A convenience for calling an asynchronous block of code for a ``LoadableAction`` and wrapping it
  /// into a `TaskResult`, ulitmatily calling the ``LoadableAction/receiveLoaded(_:)`` with the result.
  ///
  /// - Parameters:
  ///   - task: The asynchronous call that should load the value.
  public static func load(_ task: @escaping () async throws -> Action.State) -> Self {
    return .task {
      .loadable(
        await .receiveLoaded(TaskResult { try await task() })
      )
    }
  }
}

// MARK: - Reducers

/// A `Reducer` for a loadable item.
///
/// This is used for basic use cases, in general / most situations you probably want to use one of the
/// `loadable` method extension on the `ReducerProtocol` on your `Reduce`.
///
/// **Example**
/// ```swift
/// struct MyReducer: ReducerProtocol {
///   struct State: Equatable {
///     @LoadableState var int: Int?
///   }
///
///   enum Action: Equatable {
///     case int(LoadingAction<Int>)
///   }
///
///   var body: some ReducerProtocolOf<Self> {
///     LoadableReducer(state: \.$int, action: /Action.int)
///     Reduce { state, action in
///       switch action {
///         case .int(.load):
///           // perform loading.
///           return .none
///         case .int:
///           return .none
///       }
///     }
///   }
///
/// }
/// ```
public struct LoadableReducer<State, Action, Child>: ReducerProtocol {

  @usableFromInline
  let toLoadableState: WritableKeyPath<State, LoadableState<Child>>

  @usableFromInline
  let toChildAction: CasePath<Action, LoadingAction<Child>>

  /// Create a ``LoadableReducer`` for a loadable item.
  ///
  /// This is used for basic use cases, in general / most situations you probably want to use one of the
  /// `loadable` method extension on the `ReducerProtocol` on your `Reduce`.
  ///
  /// **Example**
  /// ```swift
  /// struct MyReducer: ReducerProtocol {
  ///   struct State: Equatable {
  ///     @LoadableState var int: Int?
  ///   }
  ///
  ///   enum Action: Equatable {
  ///     case int(LoadingAction<Int>)
  ///   }
  ///
  ///   var body: some ReducerProtocolOf<Self> {
  ///     LoadableReducer(state: \.$int, action: /Action.int)
  ///     Reduce { state, action in
  ///       switch action {
  ///         case .int(.load):
  ///           // perform loading.
  ///           return .none
  ///         case .int:
  ///           return .none
  ///       }
  ///     }
  ///   }
  ///
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - toLoadableState: The key path to the ``LoadingState``
  ///   - toChildAction: The case path to the ``LoadingAction``
  @inlinable
  public init(
    state toLoadableState: WritableKeyPath<State, LoadableState<Child>>,
    action toChildAction: CasePath<Action, LoadingAction<Child>>
  ) {
    self.toLoadableState = toLoadableState
    self.toChildAction = toChildAction
  }

  @inlinable
  public func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    guard let loadingAction = toChildAction.extract(from: action)
    else { return .none }

    switch loadingAction {
    case .load:
      state[keyPath: toLoadableState].loadingState.setIsLoading()
      return .none
    case .receiveLoaded(.success(let child)):
      state[keyPath: toLoadableState].loadingState = .loaded(child)
      return .none
    case .receiveLoaded:
      return .none
    }
  }
}

extension LoadableReducer where Action: LoadableAction, Child == Action.State {

  /// Create a ``LoadableReducer`` for a loadable item.
  ///
  /// This is used for basic use cases, in general / most situations you probably want to use one of the
  /// `loadable` method extension on the `ReducerProtocol` on your `Reduce`.
  ///
  /// **Example**
  /// ```swift
  /// struct MyReducer: ReducerProtocol {
  ///   struct State: Equatable {
  ///     @LoadableState var int: Int?
  ///   }
  ///
  ///   enum Action: Equatable, LoadableAction {
  ///     case loadable(LoadingAction<Int>)
  ///   }
  ///
  ///   var body: some ReducerProtocolOf<Self> {
  ///     LoadableReducer(state: \.$int)
  ///     Reduce { state, action in
  ///       switch action {
  ///         case .loadable(.load):
  ///           // perform loading.
  ///           return .none
  ///         case .loadable:
  ///           return .none
  ///       }
  ///     }
  ///   }
  ///
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - toLoadableState: The key path to the ``LoadingState``
  @inlinable
  public init(state toLoadableState: WritableKeyPath<State, LoadableState<Child>>) {
    self.init(
      state: toLoadableState,
      action: /Action.loadable
    )
  }
}

extension ReducerProtocol {

  /// Enhances a reducer with the default ``LoadingAction`` implementations and when loaded,
  /// will call the passed in child action and reducer.
  ///
  /// The default implementation will handle setting the ``LoadingState`` appropriately
  /// when a value has been loaded from a remote.
  ///
  /// > Note: The default implementation does not handle failures during loading, to handle errors
  /// > your parent reducer should handle the `.receiveLoaded(.failure(let error))`.
  ///
  /// **Example**
  /// ```swift
  ///  struct UserPicker: ReducerProtocol {
  ///
  ///    struct State: Equatable {
  ///      @BindingState var selected: User.ID?
  ///      var users: IdentifiedArrayOf<User>
  ///    }
  ///
  ///    enum Action: Equatable, BindableAction {
  ///      case binding(BindingAction<State>)
  ///    }
  ///
  ///    var body: some ReducerProtocolOf<Self> {
  ///      BindingReducer()
  ///    }
  ///  }
  ///
  ///  struct UserLoader: ReducerProtocol {
  ///    struct State: Equatable {
  ///      @LoadableState var userPicker: UserPicker.State?
  ///    }
  ///
  ///    enum Action: Equatable, LoadableAction {
  ///      case loadable(LoadingAction<UserPicker.State>)
  ///      case picker(UserPicker.Action)
  ///    }
  ///
  ///    var body: some ReducerProtocolOf<Self> {
  ///
  ///      Reduce { state, action in
  ///        switch action {
  ///        case .loadable(.load):
  ///          return .load { .init(users: .mocks) }
  ///        case .loadable:
  ///          return .none
  ///        case .picker:
  ///          return .none
  ///        }
  ///      }
  ///      .loadable(state: \.$userPicker, action: /Action.loadable, then: /Action.picker) {
  ///        UserPicker()
  ///      }
  ///    }
  ///  }
  /// ```
  ///
  /// - Parameters:
  ///   - toLoadableState: The key path from the parent state to a ``LoadingState`` instance.
  ///   - toLoadingAction: The case path from the parent action to a ``LoadingAction`` case.
  ///   - toChildAction: The action for when the state is loaded.
  ///   - child: The reducer to use when the state is loaded.
  @inlinable
  public func loadable<ChildState: Equatable, ChildAction: Equatable, Child: ReducerProtocol>(
    state toLoadableState: WritableKeyPath<State, LoadableState<ChildState>>,
    action toLoadingAction: CasePath<Action, LoadingAction<ChildState>>,
    then toChildAction: CasePath<Action, ChildAction>,
    @ReducerBuilder<ChildState, ChildAction> child: () -> Child,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _LoadableChildReducer<Self, ChildState, ChildAction, Child>
  where ChildState == Child.State, ChildAction == Child.Action {
    .init(
      parent: self,
      child: child(),
      loadableReducer: .init(state: toLoadableState, action: toLoadingAction),
      toChildAction: toChildAction,
      file: file,
      fileID: fileID,
      line: line
    )
  }

  /// Enhances a reducer with the default ``LoadingAction`` implementations.
  ///
  /// The default implementation will handle setting the ``LoadingState`` appropriately
  /// when a value has been loaded from a remote.
  ///
  /// > Note: The default implementation does not handle failures during loading, to handle errors
  /// > your parent reducer should handle the `.receiveLoaded(.failure(let error))`.
  ///
  /// **Example**
  /// ```swift
  /// struct MyReducer: ReducerProtocol {
  ///   struct State: Equatable {
  ///     @LoadableState var int: Int?
  ///   }
  ///
  ///   enum Action: Equatable {
  ///     case int(LoadingAction<Int>)
  ///   }
  ///
  ///   var body: some ReducerProtocolOf<Self> {
  ///     Reduce { state, action in
  ///       switch action {
  ///         case .int(.load):
  ///           // perform loading.
  ///           return .none
  ///         case .int:
  ///           return .none
  ///       }
  ///     }
  ///     .loadable(state: \.$int, action: /Action.int)
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - toLoadableState: The key path from the parent state to a ``LoadingState`` instance.
  ///   - toLoadableAction: The case path from the parent action to a ``LoadingAction`` case.
  @inlinable
  public func loadable<ChildState: Equatable>(
    state toLoadableState: WritableKeyPath<State, LoadableState<ChildState>>,
    action toLoadingAction: CasePath<Action, LoadingAction<ChildState>>
  ) -> LoadableReducer<State, Action, ChildState> {
    .init(state: toLoadableState, action: toLoadingAction)
  }

}

extension ReducerProtocol where Action: LoadableAction {
  /// Enhances a reducer with the default ``LoadingAction`` implementations and when loaded,
  /// will call the passed in child action and reducer.
  ///
  /// The default implementation will handle setting the ``LoadingState`` appropriately
  /// when a value has been loaded from a remote.
  ///
  /// > Note: The default implementation does not handle failures during loading, to handle errors
  /// > your parent reducer should handle the `.receiveLoaded(.failure(let error))`.
  ///
  /// **Example**
  /// ```swift
  ///  struct UserPicker: ReducerProtocol {
  ///
  ///    struct State: Equatable {
  ///      @BindingState var selected: User.ID?
  ///      var users: IdentifiedArrayOf<User>
  ///    }
  ///
  ///    enum Action: Equatable, BindableAction {
  ///      case binding(BindingAction<State>)
  ///    }
  ///
  ///    var body: some ReducerProtocolOf<Self> {
  ///      BindingReducer()
  ///    }
  ///  }
  ///
  ///  struct UserLoader: ReducerProtocol {
  ///    struct State: Equatable {
  ///      @LoadableState var userPicker: UserPicker.State?
  ///    }
  ///
  ///    enum Action: Equatable, LoadableAction {
  ///      case loadable(LoadingAction<UserPicker.State>)
  ///      case picker(UserPicker.Action)
  ///    }
  ///
  ///    var body: some ReducerProtocolOf<Self> {
  ///
  ///      Reduce { state, action in
  ///        switch action {
  ///        case .loadable(.load):
  ///          return .load { .init(users: .mocks) }
  ///        case .loadable:
  ///          return .none
  ///        case .picker:
  ///          return .none
  ///        }
  ///      }
  ///      .loadable(state: \.$userPicker, then: /Action.picker) {
  ///        UserPicker()
  ///      }
  ///    }
  ///  }
  /// ```
  ///
  /// - Parameters:
  ///   - toLoadableState: The key path from the parent state to a ``LoadingState`` instance.
  ///   - toChildAction: The action for when the state is loaded.
  ///   - child: The reducer to use when the state is loaded.
  @inlinable
  public func loadable<ChildState: Equatable, ChildAction: Equatable, Child: ReducerProtocol>(
    state toLoadableState: WritableKeyPath<State, LoadableState<ChildState>>,
    then toChildAction: CasePath<Action, ChildAction>,
    @ReducerBuilder<ChildState, ChildAction> child: () -> Child,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _LoadableChildReducer<Self, ChildState, ChildAction, Child>
  where ChildState == Child.State, ChildAction == Child.Action, Action.State == ChildState {
    .init(
      parent: self,
      child: child(),
      loadableReducer: .init(state: toLoadableState, action: /Action.loadable),
      toChildAction: toChildAction,
      file: file,
      fileID: fileID,
      line: line
    )
  }

  /// Enhances a reducer with the default ``LoadingAction`` implementations.
  ///
  /// The default implementation will handle setting the ``LoadingState`` appropriately
  /// when a value has been loaded from a remote.
  ///
  /// > Note: The default implementation does not handle failures during loading, to handle errors
  /// > your parent reducer should handle the `.receiveLoaded(.failure(let error))`.
  ///
  /// **Example**
  /// ```swift
  /// struct MyReducer: ReducerProtocol {
  ///   struct State: Equatable {
  ///     @LoadableState var int: Int?
  ///   }
  ///
  ///   enum Action: Equatable, LoadableAction {
  ///     case loadable(LoadingAction<Int>)
  ///   }
  ///
  ///   var body: some ReducerProtocolOf<Self> {
  ///     Reduce { state, action in
  ///       switch action {
  ///         case .loadable(.load):
  ///           // perform loading.
  ///           return .none
  ///         case .loadable:
  ///           return .none
  ///       }
  ///     }
  ///     .loadable(state: \.$int)
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - toLoadableState: The key path from the parent state to a ``LoadingState`` instance.
  @inlinable
  public func loadable<ChildState: Equatable>(
    state toLoadableState: WritableKeyPath<State, LoadableState<ChildState>>
  ) -> _LoadableReducer<Self, ChildState> where Action.State == ChildState {
    .init(
      parent: self,
      loadableReducer: .init(state: toLoadableState, action: /Action.loadable)
    )
  }
}

/// A concrete reducer used for the default loading implementation.
///
/// This should not be used directly, instead use the ``ReducerProtocol/loadable(state:action)``.
///
public struct _LoadableReducer<Parent: ReducerProtocol, Value: Equatable>: ReducerProtocol {

  @usableFromInline
  let parent: Parent

  @usableFromInline
  let loadableReducer: LoadableReducer<Parent.State, Parent.Action, Value>

  @inlinable
  init(
    parent: Parent,
    loadableReducer: LoadableReducer<Parent.State, Parent.Action, Value>
  ) {
    self.parent = parent
    self.loadableReducer = loadableReducer
  }

  @inlinable
  public func reduce(
    into state: inout Parent.State,
    action: Parent.Action
  ) -> EffectTask<Parent.Action> {
    let parentEffects = parent.reduce(into: &state, action: action)
    let loadingEffects = loadableReducer.reduce(into: &state, action: action)
    return .merge(loadingEffects, parentEffects)
  }
}

public struct _LoadableChildReducer<
  Parent: ReducerProtocol,
  ChildState,
  ChildAction,
  Child: ReducerProtocol
>: ReducerProtocol where Child.State == ChildState, Child.Action == ChildAction {

  @usableFromInline
  let parent: Parent

  @usableFromInline
  let child: Child

  @usableFromInline
  let loadableReducer: LoadableReducer<Parent.State, Parent.Action, ChildState>

  @usableFromInline
  let toChildAction: CasePath<Parent.Action, ChildAction>

  @usableFromInline
  let file: StaticString

  @usableFromInline
  let fileID: StaticString

  @usableFromInline
  let line: UInt

  @inlinable
  init(
    parent: Parent,
    child: Child,
    loadableReducer: LoadableReducer<Parent.State, Parent.Action, ChildState>,
    toChildAction: CasePath<Parent.Action, ChildAction>,
    file: StaticString = #file,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.parent = parent
    self.child = child
    self.loadableReducer = loadableReducer
    self.toChildAction = toChildAction
    self.file = file
    self.fileID = fileID
    self.line = line
  }

  @inlinable
  public func reduce(
    into state: inout Parent.State,
    action: Parent.Action
  ) -> EffectTask<Parent.Action> {
    let parentEffects = parent.reduce(into: &state, action: action)
    let loadableEffects = loadableReducer.reduce(into: &state, action: action)
    let childEffects: EffectTask<Parent.Action>

    let toLoadableState = loadableReducer.toLoadableState

    let childState = state[keyPath: toLoadableState].wrappedValue
    let childAction = toChildAction.extract(from: action)

    switch (childState, childAction) {
    case (.some, .some(let action)):
      childEffects = child.reduce(
        into: &state[keyPath: toLoadableState].wrappedValue!,
        action: action
      )
      .map { toChildAction.embed($0) }
    case (.none, .some(let action)):
      XCTFail(
        """
        A child action at \(self.fileID):\(self.line) was sent when the child value
        has not yet been loaded or is nil.

        Action: \(debugCaseOutput(action))


        This is generally considered an application logic error.

        """
      )
      childEffects = .none
    case (.none, .none):
      childEffects = .none
    case (.some, .none):
      childEffects = .none
    }

    return .merge(
      loadableEffects,
      childEffects,
      parentEffects
    )
  }
}
