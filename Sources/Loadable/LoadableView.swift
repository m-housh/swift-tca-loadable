@_spi(Reflection) import CasePaths
import ComposableArchitecture
import SwiftUI

/// A view that can handle loadable items using the `ComposableArchitecture` pattern.
///
/// Although this looks pretty gnarly, it is not that bad from the call-site and allows customization of the views for each state of a ``LoadableState``
/// item, and also includes default views (i.e. `ProgressView`'s) for when the item(s) are loading.
///
/// **Example**:
/// ``` swift
///  @Reducer
///  struct App {
///     @ObservableState
///     struct State: Equatable {
///       var int: LoadableState<Int> = .notRequested
///     }
///
///     enum Action: Equatable {
///       case int(LoadableAction<Int>)
///     }
///
///     @Dependency(\.continuousClock) var clock;
///     var body: some ReducerOf<Self> {
///       Reduce { state, action in
///         switch action {
///         case .int(.load):
///           return .run { send in
///             await send(.int(.receiveLoaded(
///               TaskResult {
///                 /// sleep to act like data is loading from a remote.
///                 try await clock.sleep(for: .seconds(2))
///                 return 42
///               }
///             )))
///           }
///         case .int:
///           return .none
///         }
///       }
///       .loadable(state: \.int, action: \.int)
///     }
///  }
///
///  struct ContentView: View {
///    let store: StoreOf<App>
///    var body: some View {
///      VStack {
///        LoadableView(store: store.scope(state: \.int, action: \.int)) { int in
///          Text("Loaded: \(int)")
///        } notRequested: {
///            ProgressView()
///        } isLoading: { optionalInt in
///         if let int = optionalInt {
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
///          Button(action: { store.send(.int(.load)) }) {
///            Text("Reload")
///          }
///          .padding(.top)
///        }
///      .padding()
///    }
///  }
///```
///
///
public struct LoadableView<
  State: Equatable,
  NotRequested: View,
  Loaded: View,
  IsLoading: View
>: View {

  private let autoload: Autoload

  private let isLoading: (State?) -> IsLoading

  private let loaded: (State) -> Loaded

  private let notRequested: () -> NotRequested

  @Perception.Bindable private var store: Store<LoadableState<State>, LoadableAction<State>>

  /// Create a ``LoadableView`` without any default view implementations for the ``LoadingState``.
  ///
  /// - Parameters:
  ///   - store: The store of the ``LoadingState`` and ``LoadingAction``
  ///   - autoload: A flag for if we should call ``LoadingAction/load`` when the view appears.
  ///   - loaded: The view to show when the state is ``LoadingState/loaded(_:)``
  ///   - notRequested: The view to show when the state is ``LoadingState/notRequested``
  ///   - isLoading: The view to show when the state is ``LoadingState/isLoading(previous:)``
  public init(
    store: Store<LoadableState<State>, LoadableAction<State>>,
    autoload: Autoload = .whenNotRequested,
    @ViewBuilder loaded: @escaping (State) -> Loaded,
    @ViewBuilder notRequested: @escaping () -> NotRequested,
    @ViewBuilder isLoading: @escaping (State?) -> IsLoading
  ) {
    self.autoload = autoload
    self.store = store
    self.notRequested = notRequested
    self.isLoading = isLoading
    self.loaded = loaded
  }

  public var body: some View {
    Group {
      switch store.state {
      case let .loaded(state):
        self.loaded(state)
      case let .isLoading(previous: previous):
        self.isLoading(previous)
      case .notRequested:
        self.notRequested()
      }
    }
    .onAppear {
      if self.autoload.shouldLoad(store.state) {
        store.send(.load)
      }
    }
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

  func shouldLoad<V: Equatable>(_ state: LoadableState<V>) -> Bool {
    switch self {
    case .always:
      return true
    case .never:
      return false
    case .whenNotRequested:
      return state == .notRequested
    }
  }
}

@available(iOS 14.0, macOS 11, tvOS 14, watchOS 7, *)
extension LoadableView where NotRequested == ProgressView<EmptyView, EmptyView> {

  /// Create a ``LoadableView`` that uses a `ProgressView` for the ``LoadingState/notRequested`` state,
  /// allowing customization of the other view's for ``LoadingState``.
  ///
  public init(
    store: Store<LoadableState<State>, LoadableAction<State>>,
    autoload: Autoload = .whenNotRequested,
    @ViewBuilder isLoading: @escaping (State?) -> IsLoading,
    @ViewBuilder loaded: @escaping (State) -> Loaded
  ) {
    self.autoload = autoload
    self.store = store
    self.notRequested = { ProgressView() }
    self.isLoading = isLoading
    self.loaded = loaded
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
    store: Store<LoadableState<State>, LoadableAction<State>>,
    autoload: Autoload = .whenNotRequested,
    orientation isLoadingOrientation: IsLoadingOrientation = .horizontal(),
    @ViewBuilder loaded: @escaping (State) -> Loaded,
    @ViewBuilder notRequested: @escaping (Bool) -> NotRequested
  )
  where IsLoading == IsLoadingView<State, NotRequested, Loaded> {
    self.autoload = autoload
    self.store = store
    self.notRequested = { notRequested(false) }
    self.isLoading = {
      IsLoadingView(
        state: $0,
        orientation: isLoadingOrientation,
        notRequested: notRequested,
        loaded: loaded
      )
    }
    self.loaded = loaded
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
    store: Store<LoadableState<State>, LoadableAction<State>>,
    autoload: Autoload = .whenNotRequested,
    orientation isLoadingOrientation: IsLoadingOrientation = .horizontal(),
    @ViewBuilder loaded: @escaping (State) -> Loaded
  )
  where IsLoading == IsLoadingView<State, NotRequested, Loaded> {
    let notRequested = { (_: Bool) in ProgressView() }
    self.autoload = autoload
    self.store = store
    self.notRequested = { notRequested(false) }
    self.isLoading = {
      IsLoadingView(
        state: $0,
        orientation: isLoadingOrientation,
        notRequested: notRequested,
        loaded: loaded
      )
    }
    self.loaded = loaded
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
public struct IsLoadingView<State, NotRequested: View, Loaded: View>: View {

  private let orientation: IsLoadingOrientation
  private let state: State?
  private let notRequested: (Bool) -> NotRequested
  private let loaded: (State) -> Loaded

  public init(
    state: State?,
    orientation: IsLoadingOrientation,
    @ViewBuilder notRequested: @escaping (Bool) -> NotRequested,
    @ViewBuilder loaded: @escaping (State) -> Loaded
  ) {
    self.state = state
    self.notRequested = notRequested
    self.loaded = loaded
    self.orientation = orientation
  }

  public var body: some View {
    if let state {
      self.buildView(state)
    } else {
      self.notRequested(false)
    }
  }

  @ViewBuilder
  func buildView(
    _ state: State
  ) -> some View {
    switch self.orientation {
    case let .horizontal(orientation):
      HStack(spacing: 20) {
        switch orientation {
        case .leading:
          notRequested(true)
          loaded(state)
        case .trailing:
          loaded(state)
          notRequested(true)
        }
      }
    case let .vertical(orientation):
      VStack(spacing: 10) {
        switch orientation {
        case .above:
          notRequested(true)
          loaded(state)
        case .below:
          loaded(state)
          notRequested(true)
        }
      }
    }
  }

}
