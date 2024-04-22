import CasePaths
import ComposableArchitecture
import Foundation

/// Represents different states of a loadable value.
///
///
@ObservableState
@CasePathable
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

  /// A convenience for setting the `isLoading` state appropriately, if the item has been
  /// loaded in the past, then it will set it's current value while the request to reload is in-flight.
  ///
  @discardableResult
  public mutating func setIsLoading() -> Self {
    self = .isLoading(previous: rawValue)
    return self
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

// MARK: - Actions

/// Represents the actions for a loadable value.
///
@CasePathable
public enum LoadableAction<Value> {

  /// Represents when the value should be loaded from a remote source.
  case load

  /// Receive a loaded value from a remote source.
  case receiveLoaded(TaskResult<Value>)
}
extension LoadableAction: Equatable where Value: Equatable {}

/// Represents the actions for a loadable value.  When you mark your `Reducer`'s action as
/// a ``LoadableAction``, it unlocks some conveniences for working with loadable values.
/// While allowing your other actions to work.
///
/// In general it is best to use this on your actions instead of relying on the ``LoadingAction``, unless
/// your reducer is small and focused in only on a loadable type.
///
public protocol LoadingAction<State>: CasePathable {
  associatedtype State
  static func loadable(_ action: LoadableAction<State>) -> Self
}

extension LoadingAction {

  /// Represents when the value should be loaded from a remote source.
  public static var load: Self {
    .loadable(.load)
  }

  /// Receive a loaded value from a remote source.
  public static func receiveLoaded(_ result: TaskResult<State>) -> Self {
    .loadable(.receiveLoaded(result))
  }
}

extension Effect where Action: LoadingAction {

  /// A convenience for calling an asynchronous block of code for a ``LoadableAction`` and wrapping it
  /// into a `TaskResult`, ulitmatily calling the ``LoadableAction/receiveLoaded(_:)`` with the result.
  ///
  /// - Parameters:
  ///   - task: The asynchronous call that should load the value.
  public static func load(_ task: @escaping () async throws -> Action.State) -> Self {
    return .run { send in
      await send(.loadable(.receiveLoaded(
        TaskResult { try await task() }
      )))
    }
  }
}

// MARK: - Reducers

/// A `Reducer` for a loadable item.
///
/// This is used for basic use cases, in general / most situations you probably want to use one of the
/// `loadable` method extension on the `Reducer` on your `Reduce`.
///
/// **Example**
/// ```swift
/// struct MyReducer: Reducer {
///   struct State: Equatable {
///     @LoadableState var int: Int?
///   }
///
///   enum Action: Equatable {
///     case int(LoadingAction<Int>)
///   }
///
///   var body: some ReducerOf<Self> {
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
public struct LoadableReducer<State, Action, Child>: Reducer {

  @usableFromInline
  let toLoadableState: WritableKeyPath<State, LoadableState<Child>>

  @usableFromInline
  let toChildAction: AnyCasePath<Action, LoadableAction<Child>>

  /// Create a ``LoadableReducer`` for a loadable item.
  ///
  /// This is used for basic use cases, in general / most situations you probably want to use one of the
  /// `loadable` method extension on the `Reducer` on your `Reduce`.
  ///
  /// **Example**
  /// ```swift
  /// struct MyReducer: Reducer {
  ///   struct State: Equatable {
  ///     @LoadableState var int: Int?
  ///   }
  ///
  ///   enum Action: Equatable {
  ///     case int(LoadingAction<Int>)
  ///   }
  ///
  ///   var body: some ReducerOf<Self> {
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
    action toChildAction: CaseKeyPath<Action, LoadableAction<Child>>
  ) {
    self.toLoadableState = toLoadableState
    self.toChildAction = AnyCasePath(toChildAction)
  }

  @inlinable
  public func reduce(into state: inout State, action: Action) -> Effect<Action> {
    guard let loadingAction = toChildAction.extract(from: action)
    else { return .none }

    switch loadingAction {
    case .load:
      state[keyPath: toLoadableState].setIsLoading()
      return .none
    case .receiveLoaded(.success(let child)):
      state[keyPath: toLoadableState] = .loaded(child)
      return .none
    case .receiveLoaded:
      return .none
    }
  }
}

extension LoadableReducer where Action: LoadingAction, Child == Action.State {

  /// Create a ``LoadableReducer`` for a loadable item.
  ///
  /// This is used for basic use cases, in general / most situations you probably want to use one of the
  /// `loadable` method extension on the `Reducer` on your `Reduce`.
  ///
  /// **Example**
  /// ```swift
  /// struct MyReducer: Reducer {
  ///   struct State: Equatable {
  ///     @LoadableState var int: Int?
  ///   }
  ///
  ///   enum Action: Equatable, LoadableAction {
  ///     case loadable(LoadingAction<Int>)
  ///   }
  ///
  ///   var body: some ReducerOf<Self> {
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
//  @inlinable
//  public init(state toLoadableState: WritableKeyPath<State, LoadableState<Child>>) {
//    self.init(
//      state: toLoadableState,
//      action: \Action.loadable
//    )
//  }
}

extension Reducer {

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
  ///  struct UserPicker: Reducer {
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
  ///    var body: some ReducerOf<Self> {
  ///      BindingReducer()
  ///    }
  ///  }
  ///
  ///  struct UserLoader: Reducer {
  ///    struct State: Equatable {
  ///      @LoadableState var userPicker: UserPicker.State?
  ///    }
  ///
  ///    enum Action: Equatable, LoadableAction {
  ///      case loadable(LoadingAction<UserPicker.State>)
  ///      case picker(UserPicker.Action)
  ///    }
  ///
  ///    var body: some ReducerOf<Self> {
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
//  @inlinable
//  public func loadable<ChildState: Equatable, ChildAction: Equatable, Child: Reducer>(
//    state toLoadableState: WritableKeyPath<State, LoadableState<ChildState>>,
//    action toLoadingAction: CaseKeyPath<Action, LoadableAction<ChildState>>,
//    then toChildAction: CaseKeyPath<Action, ChildAction>,
//    @ReducerBuilder<ChildState, ChildAction> child: () -> Child,
//    file: StaticString = #file,
//    fileID: StaticString = #fileID,
//    line: UInt = #line
//  ) -> _LoadableChildReducer<Self, ChildState, ChildAction, Child>
//  where ChildState == Child.State, ChildAction == Child.Action {
//    .init(
//      parent: self,
//      child: child(),
//      loadableReducer: .init(state: toLoadableState, action: toLoadingAction),
//      toChildAction: AnyCasePath(toChildAction),
//      file: file,
//      fileID: fileID,
//      line: line
//    )
//  }

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
  /// struct MyReducer: Reducer {
  ///   struct State: Equatable {
  ///     @LoadableState var int: Int?
  ///   }
  ///
  ///   enum Action: Equatable {
  ///     case int(LoadingAction<Int>)
  ///   }
  ///
  ///   var body: some ReducerOf<Self> {
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
    action toLoadingAction: CaseKeyPath<Action, LoadableAction<ChildState>>
  ) -> LoadableReducer<State, Action, ChildState> {
    .init(state: toLoadableState, action: toLoadingAction)
  }

}

extension Reducer where Action: LoadingAction {
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
  ///  struct UserPicker: Reducer {
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
  ///    var body: some ReducerOf<Self> {
  ///      BindingReducer()
  ///    }
  ///  }
  ///
  ///  struct UserLoader: Reducer {
  ///    struct State: Equatable {
  ///      @LoadableState var userPicker: UserPicker.State?
  ///    }
  ///
  ///    enum Action: Equatable, LoadableAction {
  ///      case loadable(LoadingAction<UserPicker.State>)
  ///      case picker(UserPicker.Action)
  ///    }
  ///
  ///    var body: some ReducerOf<Self> {
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
//  @inlinable
//  public func loadable<ChildState: Equatable, ChildAction: Equatable, Child: Reducer>(
//    state toLoadableState: WritableKeyPath<State, LoadableState<ChildState>>,
//    then toChildAction: CaseKeyPath<Action, ChildAction>,
//    @ReducerBuilder<ChildState, ChildAction> child: () -> Child,
//    file: StaticString = #file,
//    fileID: StaticString = #fileID,
//    line: UInt = #line
//  ) -> _LoadableChildReducer<Self, ChildState, ChildAction, Child>
//  where ChildState == Child.State, ChildAction == Child.Action, Action.State == ChildState {
//    .init(
//      parent: self,
//      child: child(),
//      loadableReducer: .init(state: toLoadableState, action: \Action.loadable),
//      toChildAction: AnyCasePath(toChildAction),
//      file: file,
//      fileID: fileID,
//      line: line
//    )
//  }

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
  /// struct MyReducer: Reducer {
  ///   struct State: Equatable {
  ///     @LoadableState var int: Int?
  ///   }
  ///
  ///   enum Action: Equatable, LoadableAction {
  ///     case loadable(LoadingAction<Int>)
  ///   }
  ///
  ///   var body: some ReducerOf<Self> {
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
//  @inlinable
//  public func loadable<ChildState: Equatable>(
//    state toLoadableState: WritableKeyPath<State, LoadableState<ChildState>>
//  ) -> _LoadableReducer<Self, ChildState> where Action.State == ChildState {
//    .init(
//      parent: self,
//      loadableReducer: .init(state: toLoadableState, action: \Action.loadable)
//    )
//  }
}

/// A concrete reducer used for the default loading implementation.
///
/// This should not be used directly, instead use the ``Reducer/loadable(state:action)``.
///
public struct _LoadableReducer<Parent: Reducer, Value: Equatable>: Reducer {

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
  ) -> Effect<Parent.Action> {
    let parentEffects = parent.reduce(into: &state, action: action)
    let loadingEffects = loadableReducer.reduce(into: &state, action: action)
    return .merge(loadingEffects, parentEffects)
  }
}

//public struct _LoadableChildReducer<
//  Parent: Reducer,
//  ChildState,
//  ChildAction,
//  Child: Reducer
//>: Reducer where Child.State == ChildState, Child.Action == ChildAction {
//
//  @usableFromInline
//  let parent: Parent
//
//  @usableFromInline
//  let child: Child
//
//  @usableFromInline
//  let loadableReducer: LoadableReducer<Parent.State, Parent.Action, ChildState>
//
//  @usableFromInline
//  let toChildAction: AnyCasePath<Parent.Action, ChildAction>
//
//  @usableFromInline
//  let file: StaticString
//
//  @usableFromInline
//  let fileID: StaticString
//
//  @usableFromInline
//  let line: UInt
//
//  @inlinable
//  init(
//    parent: Parent,
//    child: Child,
//    loadableReducer: LoadableReducer<Parent.State, Parent.Action, ChildState>,
//    toChildAction: CaseKeyPath<Parent.Action, ChildAction>,
//    file: StaticString = #file,
//    fileID: StaticString = #fileID,
//    line: UInt = #line
//  ) {
//    self.parent = parent
//    self.child = child
//    self.loadableReducer = loadableReducer
//    self.toChildAction = AnyCasePath(toChildAction)
//    self.file = file
//    self.fileID = fileID
//    self.line = line
//  }
//
//  @inlinable
//  public func reduce(
//    into state: inout Parent.State,
//    action: Parent.Action
//  ) -> Effect<Parent.Action> {
//    let parentEffects = parent.reduce(into: &state, action: action)
//    let loadableEffects = loadableReducer.reduce(into: &state, action: action)
//    let childEffects: Effect<Parent.Action>
//
//    let toLoadableState = loadableReducer.toLoadableState
//
//    let childState = state[keyPath: toLoadableState]
//    let childAction = toChildAction.extract(from: action)
//
//    switch childAction {
//    case .some(let action):
//      childEffects = child.reduce(
//        into: &state[keyPath: toLoadableState],
//        action: action
//      )
//      .map { toChildAction.embed($0) }
////    case .some(let action):
////      XCTFail(
////        """
////        A child action at \(self.fileID):\(self.line) was sent when the child value
////        has not yet been loaded or is nil.
////
////        Action: \(debugCaseOutput(action))
////
////
////        This is generally considered an application logic error.
////
////        """
////      )
////      childEffects = .none
//    case .none:
//      childEffects = .none
////    case (.some, .none):
////      childEffects = .none
//    }
//
//    return .merge(
//      loadableEffects,
//      childEffects,
//      parentEffects
//    )
//  }
//}
