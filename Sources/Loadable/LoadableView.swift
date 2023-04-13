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
///     enum Action: Equatable {
///       case int(LoadingAction<Int>)
///     }
///
///     @Dependency(\.continuousClock) var clock;
///     var body: some ReducerOf<Self> {
///       Reduce { state, action in
///         switch action {
///         case .int(.load):
///           return .task {
///             await .int(.receiveLoaded(
///               TaskResult {
///                 /// sleep to act like data is loading from a remote.
///                 try await clock.sleep(for: .seconds(2))
///                 return 42
///               }
///             ))
///           }
///         case .int:
///           return .none
///         }
///       }
///       .loadable(state: \.$int, action: /Action.int)
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
  NotRequested: View,
  Loaded: View,
  IsLoading: View
>: View {

  private let autoload: Autoload

  private let isLoading: (Store<State?, LoadingAction<State>>) -> IsLoading

  private let loaded: (Store<State, LoadingAction<State>>) -> Loaded

  private let notRequested: () -> NotRequested

  private let store: Store<LoadingState<State>, LoadingAction<State>>

  /// Create a ``LoadableView`` without any default view implementations for the ``LoadingState``.
  ///
  /// - Parameters:
  ///   - store: The store of the ``LoadingState`` and ``LoadingAction``
  ///   - autoload: A flag for if we should call ``LoadingAction/load`` when the view appears.
  ///   - loaded: The view to show when the state is ``LoadingState/loaded(_:)``
  ///   - notRequested: The view to show when the state is ``LoadingState/notRequested``
  ///   - isLoading: The view to show when the state is ``LoadingState/isLoading(previous:)``
  public init(
    store: Store<LoadingState<State>, LoadingAction<State>>,
    autoload: Autoload = .whenNotRequested,
    @ViewBuilder loaded: @escaping (Store<State, LoadingAction<State>>) -> Loaded,
    @ViewBuilder notRequested: @escaping () -> NotRequested,
    @ViewBuilder isLoading: @escaping (Store<State?, LoadingAction<State>>) -> IsLoading
  ) {
    self.autoload = autoload
    self.store = store
    self.notRequested = notRequested
    self.isLoading = isLoading
    self.loaded = loaded
  }

  public var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      SwitchStore(self.store) {
        CaseLet<
          LoadingState<State>,
          LoadingAction<State>,
          Void,
          LoadingAction<State>,
          NotRequested
        >(
          state: /LoadingState<State>.notRequested
        ) { _ in
          notRequested()
        }
        CaseLet<
          LoadingState<State>,
          LoadingAction<State>,
          State?,
          LoadingAction<State>,
          IsLoading
        >(
          state: /LoadingState<State>.isLoading(previous:)
        ) {
          isLoading($0)
        }
        CaseLet<
          LoadingState<State>,
          LoadingAction<State>,
          State,
          LoadingAction<State>,
          Loaded
        >(
          state: /LoadingState<State>.loaded
        ) {
          loaded($0)
        }
      }
      .onAppear {
        if self.autoload.shouldLoad(viewStore.state) {
          viewStore.send(.load)
        }
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

  func shouldLoad<V: Equatable>(_ state: LoadingState<V>) -> Bool {
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

@available(iOS 14.0, macOS 11, *)
extension LoadableView where NotRequested == ProgressView<EmptyView, EmptyView> {

  /// Create a ``LoadableView`` that uses a `ProgressView` for the ``LoadingState/notRequested`` state,
  /// allowing customization of the other view's for ``LoadingState``.
  ///
  public init(
    store: Store<LoadingState<State>, LoadingAction<State>>,
    autoload: Autoload = .whenNotRequested,
    @ViewBuilder isLoading: @escaping (Store<State?, LoadingAction<State>>) -> IsLoading,
    @ViewBuilder loaded: @escaping (Store<State, LoadingAction<State>>) -> Loaded
  ) {
    self.autoload = autoload
    self.store = store
    self.notRequested = { ProgressView() }
    self.isLoading = isLoading
    self.loaded = loaded
  }
}

/// A view that will show the `NotRequested` and `Loaded` views in an `HStack` based on if a
/// ``LoadingState`` when there has been a previous value loaded, otherwise it will show the `NotRequested` view.
///
/// This is generally not interacted with directly, but is used for the default for a ``LoadableView/init(store:autoload:loaded:)``
///
public struct HorizontalIsLoadingView<State, Action, NotRequested: View, Loaded: View>: View {

  private let store: Store<State?, Action>
  private let notRequested: () -> NotRequested
  private let loaded: (Store<State, Action>) -> Loaded

  public init(
    store: Store<State?, Action>,
    @ViewBuilder notRequested: @escaping () -> NotRequested,
    @ViewBuilder loaded: @escaping (Store<State, Action>) -> Loaded
  ) {
    self.store = store
    self.notRequested = notRequested
    self.loaded = loaded
  }

  public var body: some View {
    IfLetStore(self.store) { store in
      HStack {
        notRequested()
          .padding(.trailing)
        loaded(store)
      }
    } else: {
      notRequested()
    }
  }
}

@available(iOS 14.0, macOS 11, *)
extension LoadableView
where
  NotRequested == ProgressView<EmptyView, EmptyView>
{

  /// Create a ``LoadableView`` that uses the default `ProgressView` for when an item is ``LoadingState/notRequested``.
  /// And uses an `HStack` of a `ProgressView` and the `LoadedView` for when an item is ``LoadingState/isLoading(previous:)``
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
  public init(
    store: Store<LoadingState<State>, LoadingAction<State>>,
    autoload: Autoload = .whenNotRequested,
    @ViewBuilder loaded: @escaping (Store<State, LoadingAction<State>>) -> Loaded
  )
  where IsLoading == HorizontalIsLoadingView<State, LoadingAction<State>, NotRequested, Loaded> {
    let notRequested = { ProgressView() }
    self.autoload = autoload
    self.store = store
    self.notRequested = notRequested
    self.isLoading = {
      HorizontalIsLoadingView(
        store: $0,
        notRequested: notRequested,
        loaded: loaded
      )
    }
    self.loaded = loaded
  }
}

#if DEBUG
  @available(iOS 16, macOS 13, *)
  struct Preview: Reducer {
    struct State: Equatable {
      @LoadableState var int: Int?
    }

    enum Action: Equatable {
      case int(LoadingAction<Int>)
    }

    @Dependency(\.continuousClock) var clock

    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .int(.load):
          return .task {
            await .int(
              .receiveLoaded(
                TaskResult {
                  try await clock.sleep(for: .milliseconds(100))
                  return 42
                }
              ))
          }
        case .int:
          return .none
        }
      }
      .loadable(state: \.$int, action: /Action.int)
    }
  }

  struct LoadableView_Previews: PreviewProvider {
    static var previews: some View {
      Text("Hello, world!")
    }
  }
#endif
