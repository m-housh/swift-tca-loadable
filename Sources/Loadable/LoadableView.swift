@_spi(Reflection) import CasePaths
import ComposableArchitecture
import SwiftUI

/// A view that can handle loadable items using the `ComposableArchitecture` pattern.
///
/// Although this looks pretty gnarly, it is not that bad from the call-site and allows customization of the views for each state of a ``LoadingState``
/// item, and also includes default views (i.e. `ProgressView`'s) for when the item(s) are loading.
///
/// **Example**:
/// ``` swift
///  struct App: Reducer {
///     struct State: Equatable {
///       @LoadableState var int: Int?
///     }
///
///     enum Action: Equatable, LoadableAction {
///       case loadable(LoadingAction<Int>)
///     }
///
///     @Dependency(\.continuousClock) var clock;
///     var body: some ReducerOf<Self> {
///       Reduce { state, action in
///         switch action {
///         case .loadable(.load):
///           return .load {
///               /// sleep to act like data is loading from a remote.
///               try await clock.sleep(for: .seconds(2))
///               return 42
///             }
///           }
///         case .loadable:
///           return .none
///         }
///       }
///       .loadable(state: \.$loadable)
///     }
///  }
///
///  struct ContentView: View {
///    let store: StoreOf<App>
///    var body: some View {
///      VStack {
///        WithViewStore(store, observe: { $0 }) { viewStore in
///          LoadableView(store: store.scope(state: \.$int, action: App.Action.int)) {
///            WithViewStore($0, observe: { $0 }) { viewStore in
///              Text("Loaded: \(viewStore.state)")
///            }
///          } notRequested: {
///            ProgressView()
///          } isLoading: {
///             IfLetStore($0) { intStore in
///               // Show this view if we have loaded a value in the past.
///               VStack {
///                 ProgressView()
///                   .padding()
///                  Text("Loading...")
///               }
///             } else: {
///               // Show this view when we have not loaded a value in the past, but our state `.isLoading`
///               ProgressView()
///             }
///          }
///          Button(action: { viewStore.send(.int(.load)) }) {
///            Text("Reload")
///          }
///          .padding(.top)
///        }
///      }
///      .padding()
///    }
///  }
///```
///
///
public struct LoadableView<
  State: Equatable,
  Action: LoadableAction,
  LoadedAction: Equatable,
  NotRequested: View,
  Loaded: View,
  IsLoading: View
>: View where Action.State == State, Action: Equatable {

  private let autoload: Autoload

  private let isLoading: (Store<State?, Action>) -> IsLoading

  private let loaded: (Store<State, LoadedAction>) -> Loaded

  private let notRequested: () -> NotRequested

  private let store: Store<LoadingState<State>, Action>

  private let fromLoadedAction: (LoadedAction) -> Action

  /// Create a ``LoadableView`` without any default view implementations for the ``LoadingState``.
  ///
  /// - Parameters:
  ///   - store: The store of the ``LoadingState`` and ``LoadingAction``
  ///   - autoload: A flag for if we should call ``LoadingAction/load`` when the view appears.
  ///   - action: A transfromation action used for when the state is ``LoadingState/loaded(_:)``, allows the loaded view to work on a different domain.
  ///   - loaded: The view to show when the state is ``LoadingState/loaded(_:)``
  ///   - notRequested: The view to show when the state is ``LoadingState/notRequested``
  ///   - isLoading: The view to show when the state is ``LoadingState/isLoading(previous:)``
  public init(
    _ store: Store<LoadingState<State>, Action>,
    autoload: Autoload = .whenNotRequested,
    action fromLoadedAction: @escaping (LoadedAction) -> Action,
    @ViewBuilder loaded: @escaping (Store<State, LoadedAction>) -> Loaded,
    @ViewBuilder notRequested: @escaping () -> NotRequested,
    @ViewBuilder isLoading: @escaping (Store<State?, Action>) -> IsLoading
  ) {
    self.autoload = autoload
    self.store = store
    self.notRequested = notRequested
    self.isLoading = isLoading
    self.loaded = loaded
    self.fromLoadedAction = fromLoadedAction
  }

  struct ViewState: Equatable {
    let hasLoaded: Bool

    init(state: LoadingState<State>) {
      self.hasLoaded = state == .notRequested
    }
  }

  public var body: some View {
    WithViewStore(self.store, observe: ViewState.init(state:)) { viewStore in
      SwitchStore(self.store) {
        CaseLet<
          LoadingState<State>,
          Action,
          Void,
          Action,
          NotRequested
        >(
          state: /LoadingState<State>.notRequested
        ) { _ in
          notRequested()
        }
        CaseLet<
          LoadingState<State>,
          Action,
          State?,
          Action,
          IsLoading
        >(
          state: /LoadingState<State>.isLoading(previous:)
        ) {
          isLoading($0)
        }
        CaseLet<
          LoadingState<State>,
          Action,
          State,
          LoadedAction,
          Loaded
        >(
          state: /LoadingState<State>.loaded,
          action: fromLoadedAction
        ) {
          loaded($0)
        }
      }
      .onAppear {
        if self.autoload.shouldLoad(viewStore.hasLoaded) {
          viewStore.send(.load)
        }
      }
    }
  }
}

extension LoadableView where LoadedAction == Action {

  /// Create a ``LoadableView`` without any default view implementations for the ``LoadingState``,
  /// when the loaded action is in the same domain as the current context.
  ///
  /// - Parameters:
  ///   - store: The store of the ``LoadingState`` and ``LoadingAction``
  ///   - autoload: A flag for if we should call ``LoadingAction/load`` when the view appears.
  ///   - loaded: The view to show when the state is ``LoadingState/loaded(_:)``
  ///   - notRequested: The view to show when the state is ``LoadingState/notRequested``
  ///   - isLoading: The view to show when the state is ``LoadingState/isLoading(previous:)``
  public init(
    _ store: Store<LoadingState<State>, Action>,
    autoload: Autoload = .whenNotRequested,
    @ViewBuilder loaded: @escaping (Store<State, LoadedAction>) -> Loaded,
    @ViewBuilder notRequested: @escaping () -> NotRequested,
    @ViewBuilder isLoading: @escaping (Store<State?, Action>) -> IsLoading
  ) {
    self.autoload = autoload
    self.store = store
    self.notRequested = notRequested
    self.isLoading = isLoading
    self.loaded = loaded
    self.fromLoadedAction = { $0 }
  }

}

/// Represents when / if we should call the ``LoadingAction/load`` when a view appears.
///
public enum Autoload: Equatable {

  /// Always call load when a view appears.
  case always

  /// Never call load when a view appears.
  case never

  /// Only call load when the state is ``LoadingState/notRequested``.
  case whenNotRequested

  func shouldLoad(_ state: Bool) -> Bool {
    switch self {
    case .always:
      return true
    case .never:
      return false
    case .whenNotRequested:
      return state
    }
  }
}

@available(iOS 14.0, macOS 11, tvOS 14, watchOS 7, *)
extension LoadableView where NotRequested == ProgressView<EmptyView, EmptyView> {

  /// Create a ``LoadableView`` that uses a `ProgressView` for the ``LoadingState/notRequested`` state,
  /// allowing customization of the other view's for ``LoadingState``.
  ///
  /// - Parameters:
  ///   - store: The store of the ``LoadingState`` and ``LoadingAction``
  ///   - autoload: A flag for if we should call ``LoadingAction/load`` when the view appears.
  ///   - loaded: The view to show when the state is ``LoadingState/loaded(_:)``
  ///   - isLoading: The view to show when the state is ``LoadingState/isLoading(previous:)``
  public init(
    _ store: Store<LoadingState<State>, Action>,
    autoload: Autoload = .whenNotRequested,
    @ViewBuilder loaded: @escaping (Store<State, Action>) -> Loaded,
    @ViewBuilder isLoading: @escaping (Store<State?, Action>) -> IsLoading
  ) where LoadedAction == Action {
    self.init(
      store,
      autoload: autoload,
      loaded: loaded,
      notRequested: { ProgressView() },
      isLoading: isLoading
    )
  }

  /// Create a ``LoadableView`` that uses a `ProgressView` for the ``LoadingState/notRequested`` state,
  /// allowing customization of the other view's for ``LoadingState``.
  ///
  /// - Parameters:
  ///   - store: The store of the ``LoadingState`` and ``LoadingAction``
  ///   - autoload: A flag for if we should call ``LoadingAction/load`` when the view appears.
  ///   - action: A transfromation action used for when the state is ``LoadingState/loaded(_:)``, allows the loaded view to work on a different domain.
  ///   - loaded: The view to show when the state is ``LoadingState/loaded(_:)``
  ///   - isLoading: The view to show when the state is ``LoadingState/isLoading(previous:)``
  public init(
    _ store: Store<LoadingState<State>, Action>,
    autoload: Autoload = .whenNotRequested,
    action fromLoadedAction: @escaping (LoadedAction) -> Action,
    @ViewBuilder loaded: @escaping (Store<State, Action>) -> Loaded,
    @ViewBuilder isLoading: @escaping (Store<State?, Action>) -> IsLoading
  ) where LoadedAction == Action {
    self.init(
      store,
      autoload: autoload,
      action: fromLoadedAction,
      loaded: loaded,
      notRequested: { ProgressView() },
      isLoading: isLoading
    )
  }
}

@available(iOS 14.0, macOS 11, tvOS 14, watchOS 7, *)
extension LoadableView
where
  NotRequested == ProgressView<EmptyView, EmptyView>
{

  /// Create a ``LoadableView`` that uses the default `ProgressView` for when an item is ``LoadingState/notRequested``.
  /// And uses an `HStack` or a `VStack` with the `ProgressView` and the `LoadedView` for when an
  /// item is in the ``LoadingState/isLoading(previous:)`` state.
  ///
  /// With this initializer overload, you can specify the `NotRequested` view by using a closure that get's passed a
  /// boolean, which is `false`  when the loading state is ``LoadingState/notRequested`` or  `true` when
  /// the loading state is ``LoadingState/isLoading(previous:)``.
  ///
  ///  **Example**
  /// ```swift
  ///  struct ContentView: View {
  ///    let store: StoreOf<App>
  ///    var body: some View {
  ///      VStack {
  ///        WithViewStore(store, observe: { $0 }) { viewStore in
  ///          LoadableView(
  ///           store: store.scope(state: \.$int, action: Preview.Action.int),
  ///           orientation: .vertical
  ///          ) {
  ///            WithViewStore($0, observe: { $0 }) { viewStore in
  ///              Text("Loaded: \(viewStore.state)")
  ///            }
  ///          } notRequested: { isLoading in
  ///             ProgressView()
  ///               .scaleEffect(x: isLoading ? 1 : 2, y: isLoading ? 1 : 2, anchor: .center)
  ///          }
  ///          Button(action: { viewStore.send(.int(.load)) }) {
  ///            Text("Reload")
  ///          }
  ///          .padding(.top)
  ///        }
  ///      }
  ///      .padding()
  ///    }
  ///  }
  /// ```
  ///
  /// - Parameters:
  ///   - store: The store of the ``LoadingState`` and ``LoadingAction``
  ///   - autoload: A flag for if we should call ``LoadingAction/load`` when the view appears.
  ///   - isLoadingOrientation: A flag for whether to show the not requested view in an `HStack` or a `VStack`.
  ///   - loaded: The view to show when the state is ``LoadingState/loaded(_:)``
  ///   - notRequested: The view to show when the state is ``LoadingState/notRequested``
  public init(
    _ store: Store<LoadingState<State>, Action>,
    autoload: Autoload = .whenNotRequested,
    orientation isLoadingOrientation: IsLoadingOrientation = .horizontal(),
    @ViewBuilder loaded: @escaping (Store<State, Action>) -> Loaded,
    @ViewBuilder notRequested: @escaping (Bool) -> NotRequested
  )
  where
    IsLoading == IsLoadingView<State, Action, Action, NotRequested, Loaded>, LoadedAction == Action
  {
    self.init(
      store,
      autoload: autoload,
      loaded: loaded,
      notRequested: { notRequested(false) },
      isLoading: {
        IsLoadingView(
          $0,
          orientation: isLoadingOrientation,
          notRequested: notRequested,
          loaded: loaded
        )
      }
    )
  }
  // TODO: Better example for using a different domain for the loaded view
  /// Create a ``LoadableView`` that uses the default `ProgressView` for when an item is ``LoadingState/notRequested``.
  /// And uses an `HStack` or a `VStack` with the `ProgressView` and the `LoadedView` for when an
  /// item is in the ``LoadingState/isLoading(previous:)`` state.
  ///
  /// With this initializer overload, you can specify the `NotRequested` view by using a closure that get's passed a
  /// boolean, which is `false`  when the loading state is ``LoadingState/notRequested`` or  `true` when
  /// the loading state is ``LoadingState/isLoading(previous:)``.
  ///
  ///  **Example**
  /// ```swift
  ///  struct ContentView: View {
  ///    let store: StoreOf<App>
  ///    var body: some View {
  ///      VStack {
  ///        WithViewStore(store, observe: { $0 }) { viewStore in
  ///          LoadableView(
  ///           store: store.scope(state: \.$int, action: Preview.Action.int),
  ///           orientation: .vertical
  ///          ) {
  ///            WithViewStore($0, observe: { $0 }) { viewStore in
  ///              Text("Loaded: \(viewStore.state)")
  ///            }
  ///          } notRequested: { isLoading in
  ///             ProgressView()
  ///               .scaleEffect(x: isLoading ? 1 : 2, y: isLoading ? 1 : 2, anchor: .center)
  ///          }
  ///          Button(action: { viewStore.send(.int(.load)) }) {
  ///            Text("Reload")
  ///          }
  ///          .padding(.top)
  ///        }
  ///      }
  ///      .padding()
  ///    }
  ///  }
  /// ```
  ///
  /// - Parameters:
  ///   - store: The store of the ``LoadingState`` and ``LoadingAction``
  ///   - autoload: A flag for if we should call ``LoadingAction/load`` when the view appears.
  ///   - isLoadingOrientation: A flag for whether to show the not requested view in an `HStack` or a `VStack`.
  ///   - action: A transfromation action used for when the state is ``LoadingState/loaded(_:)``, allows the loaded view to work on a different domain.
  ///   - loaded: The view to show when the state is ``LoadingState/loaded(_:)``
  ///   - notRequested: The view to show when the state is ``LoadingState/notRequested``
  public init(
    _ store: Store<LoadingState<State>, Action>,
    autoload: Autoload = .whenNotRequested,
    orientation isLoadingOrientation: IsLoadingOrientation = .horizontal(),
    action fromLoadedAction: @escaping (LoadedAction) -> Action,
    @ViewBuilder loaded: @escaping (Store<State, LoadedAction>) -> Loaded,
    @ViewBuilder notRequested: @escaping (Bool) -> NotRequested
  )
  where IsLoading == IsLoadingView<State, Action, LoadedAction, NotRequested, Loaded> {
    self.init(
      store,
      autoload: autoload,
      action: fromLoadedAction,
      loaded: loaded,
      notRequested: { notRequested(false) },
      isLoading: {
        IsLoadingView(
          $0,
          orientation: isLoadingOrientation,
          action: fromLoadedAction,
          notRequested: notRequested,
          loaded: loaded
        )
      }
    )
  }

  /// Create a ``LoadableView`` that uses the default `ProgressView` for when an item is ``LoadingState/notRequested``.
  /// And uses an `HStack` or a `VStack` with the `ProgressView` along with the `LoadedView` for when an
  /// item is in the ``LoadingState/isLoading(previous:)`` state.
  ///
  /// ```swift
  ///  struct ContentView: View {
  ///    let store: StoreOf<App>
  ///    var body: some View {
  ///      VStack {
  ///        WithViewStore(store, observe: { $0 }) { viewStore in
  ///          LoadableView(store: store.scope(state: \.$int, action: Preview.Action.int)) {
  ///            WithViewStore($0, observe: { $0 }) { viewStore in
  ///              Text("Loaded: \(viewStore.state)")
  ///            }
  ///          }
  ///          Button(action: { viewStore.send(.int(.load)) }) {
  ///            Text("Reload")
  ///          }
  ///          .padding(.top)
  ///        }
  ///      }
  ///      .padding()
  ///    }
  ///  }
  /// ```
  /// - Parameters:
  ///   - store: The store of the ``LoadingState`` and ``LoadingAction``
  ///   - autoload: A flag for if we should call ``LoadingAction/load`` when the view appears.
  ///   - isLoadingOrientation: A flag for whether to show the not requested view in an `HStack` or a `VStack`.
  ///   - loaded: The view to show when the state is ``LoadingState/loaded(_:)``
  ///
  public init(
    _ store: Store<LoadingState<State>, Action>,
    autoload: Autoload = .whenNotRequested,
    orientation isLoadingOrientation: IsLoadingOrientation = .horizontal(),
    @ViewBuilder loaded: @escaping (Store<State, Action>) -> Loaded
  )
  where
    IsLoading == IsLoadingView<State, Action, Action, NotRequested, Loaded>, Action == LoadedAction
  {
    let notRequested = { (_: Bool) in ProgressView() }
    self.init(
      store,
      autoload: autoload,
      orientation: isLoadingOrientation,
      loaded: loaded,
      notRequested: { notRequested($0) }
    )
  }
  // TODO: Better example for using a different domain for the loaded view
  /// Create a ``LoadableView`` that uses the default `ProgressView` for when an item is ``LoadingState/notRequested``.
  /// And uses an `HStack` or a `VStack` with the `ProgressView` along with the `LoadedView` for when an
  /// item is in the ``LoadingState/isLoading(previous:)`` state.
  ///
  /// ```swift
  ///  struct ContentView: View {
  ///    let store: StoreOf<App>
  ///    var body: some View {
  ///      VStack {
  ///        WithViewStore(store, observe: { $0 }) { viewStore in
  ///          LoadableView(store: store.scope(state: \.$int, action: Preview.Action.int)) {
  ///            WithViewStore($0, observe: { $0 }) { viewStore in
  ///              Text("Loaded: \(viewStore.state)")
  ///            }
  ///          }
  ///          Button(action: { viewStore.send(.int(.load)) }) {
  ///            Text("Reload")
  ///          }
  ///          .padding(.top)
  ///        }
  ///      }
  ///      .padding()
  ///    }
  ///  }
  /// ```
  /// - Parameters:
  ///   - store: The store of the ``LoadingState`` and ``LoadingAction``
  ///   - autoload: A flag for if we should call ``LoadingAction/load`` when the view appears.
  ///   - isLoadingOrientation: A flag for whether to show the not requested view in an `HStack` or a `VStack`.
  ///   - action: A transfromation action used for when the state is ``LoadingState/loaded(_:)``, allows the loaded view to work on a different domain.
  ///   - loaded: The view to show when the state is ``LoadingState/loaded(_:)``
  public init(
    _ store: Store<LoadingState<State>, Action>,
    autoload: Autoload = .whenNotRequested,
    orientation isLoadingOrientation: IsLoadingOrientation = .horizontal(),
    action fromLoadedAction: @escaping (LoadedAction) -> Action,
    @ViewBuilder loaded: @escaping (Store<State, LoadedAction>) -> Loaded
  )
  where IsLoading == IsLoadingView<State, Action, LoadedAction, NotRequested, Loaded> {
    let notRequested = { (_: Bool) in ProgressView() }
    self.init(
      store,
      autoload: autoload,
      orientation: isLoadingOrientation,
      action: fromLoadedAction,
      loaded: loaded,
      notRequested: { notRequested($0) }
    )
  }
}

/// Represents the orentation of an ``IsLoadingView``, and embeds a
/// previously loaded value in either an `HStack` or a `VStack` when the loading state
/// is ``LoadingState/isLoading(previous:)``.
///
public enum IsLoadingOrientation: Equatable {

  /// Embeds previously loaded values in an `HStack` when the state is ``LoadingState/isLoading(previous:)``
  case horizontal(Horizontal = .leading)

  /// Embeds previously loaded values in a `VStack` when the state is ``LoadingState/isLoading(previous:)``
  case vertical(Vertical = .above)

  /// Represents the orientation of the not requested view in relation to the loaded view, when shown in an `HStack`.
  public enum Horizontal: Equatable {
    case leading, trailing
  }

  /// Represents the orientation of the not requested view in relation to the loaded view, when shown in a `VStack`.
  public enum Vertical: Equatable {
    case above, below
  }

}

/// A view that will show the `NotRequested` and `Loaded` views in an `HStack` or a `VStack` based on if a
/// ``LoadingState`` when there has been a previous value loaded, otherwise it will show the `NotRequested` view.
///
/// This is generally not interacted with directly, but is used for the default for a ``LoadableView/init(store:autoload:isLoadingOrientation:loaded:)``
///
public struct IsLoadingView<State, Action, LoadedAction, NotRequested: View, Loaded: View>: View {

  private let orientation: IsLoadingOrientation
  private let store: Store<State?, Action>
  private let notRequested: (Bool) -> NotRequested
  private let loaded: (Store<State, LoadedAction>) -> Loaded
  private let fromLoadedAction: (LoadedAction) -> Action

  public init(
    _ store: Store<State?, Action>,
    orientation: IsLoadingOrientation,
    action fromLoadedAction: @escaping (LoadedAction) -> Action,
    @ViewBuilder notRequested: @escaping (Bool) -> NotRequested,
    @ViewBuilder loaded: @escaping (Store<State, LoadedAction>) -> Loaded
  ) {
    self.store = store
    self.notRequested = notRequested
    self.loaded = loaded
    self.orientation = orientation
    self.fromLoadedAction = fromLoadedAction
  }

  public var body: some View {
    IfLetStore(self.store) { store in
      self.buildView(store: store.scope(state: { $0 }, action: fromLoadedAction))
    } else: {
      notRequested(false)
    }
  }

  @ViewBuilder
  func buildView(
    store: Store<State, LoadedAction>
  ) -> some View {
    switch self.orientation {
    case let .horizontal(orientation):
      HStack(spacing: 20) {
        switch orientation {
        case .leading:
          notRequested(true)
          loaded(store)
        case .trailing:
          loaded(store)
          notRequested(true)
        }
      }
    case let .vertical(orientation):
      VStack(spacing: 10) {
        switch orientation {
        case .above:
          notRequested(true)
          loaded(store)
        case .below:
          loaded(store)
          notRequested(true)
        }
      }
    }
  }

}

extension IsLoadingView where Action == LoadedAction {
  public init(
    _ store: Store<State?, Action>,
    orientation: IsLoadingOrientation,
    @ViewBuilder notRequested: @escaping (Bool) -> NotRequested,
    @ViewBuilder loaded: @escaping (Store<State, LoadedAction>) -> Loaded
  ) {
    self.store = store
    self.notRequested = notRequested
    self.loaded = loaded
    self.orientation = orientation
    self.fromLoadedAction = { $0 }
  }
}
