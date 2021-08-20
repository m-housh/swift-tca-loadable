//
//  LoadableView.swift
//

import Combine
import ComposableArchitecture
import SwiftUI

/// A view that can handle loadable items using the `ComposableArchitecture` pattern.  You will most likely want to make a more concrete
/// view that fits your needs, using this internally.
///
/// Although this looks pretty gnarly, it is not that bad from the call-site and allows customization of the views for each state of a `Loadable` item, and also
/// includes sensible default views (i.e. `ProgressView`'s) for when the item(s) are loading.
///
/// **Example**:
/// ``` swift
/// enum AppError: Error, Equatable {
///   case loadingError
/// }
///
/// struct AppState: Equatable {
///   var number: Loadable<Int, AppError> = .notRequested
/// }
///
/// enum AppReducer: Equatable {
///   case load(LoadAction<Int, AppError>)
///  }
///
/// let appReducer = Reducer<AppState, AppAction, LoadableEnvironment<Int, EmptyLoadRequest, AppError>>
///   .empty.loadable(
///     state: \.number,
///     action: /AppAction.load,
///     environment: { $0 }
///   )
///
/// extension LoadableEnvironment where LoadedValue == Int, LoadRequest == EmptyLoadRequest, Failure == AppError {
///   static let live = Self.init(
///     load: { _ in
///       Just(42)
///         .setFailureType(to: AppError.self)
///         .eraseToEffect()
///     },
///     mainQueue: .main
///   )
/// }
///
/// struct MyLoadableNumberView: View {
///   let store: Store<Loadable<Int, AppError>, LoadableAction<Int, AppError>>
///
///   var body: some View {
///     LoadableView(store: store, autoLoad: true) { store in
///       WithViewStore(store) { viewStore in
///         Text("\(viewStore.state)")
///       }
///     }
///   }
/// }
///
/// let myView = MyLoadableNumberView(
///   store: .init(
///     initialState: .init(),
///     reducer: appReducer,
///     environment: .live
///   )
/// )
///```
public struct LoadableView<
  LoadedValue: Equatable,
  Action: Equatable,
  Failure: Error,
  NotRequestedView: View,
  LoadedView: View,
  ErrorView: View,
  IsLoadingView: View
>: View {

  /// The store to derive our state and actions from.
  public let store: Store<Loadable<LoadedValue, Failure>, Action>

  /// A flag for if we automatically send a load action when the view appears and our state is `.notRequested`
  let autoLoad: Bool

  /// The view shown when our state is `.notRequested`
  let notRequestedView: (Store<Void, Action>) -> NotRequestedView

  /// The view shown when our state is `.loaded`
  let loadedView: (Store<LoadedValue, Action>) -> LoadedView

  /// The view shown when our state is `.isLoading`
  let isLoadingView: (Store<LoadedValue?, Action>) -> IsLoadingView

  /// The view shown when our state is `.failed`
  let errorView: (Store<Failure, Action>) -> ErrorView

  /// The action to call to load data.
  let loadAction: Action

  /// Create a loadable view.
  ///
  /// - parameters:
  ///     - store: The store to derive our state and actions from.
  ///     - autoLoad: A flag for if we automatically send a load action if our state is `.notRequested`
  ///     - loadedView: The view shown if our state is `.loaded`
  ///     - notRequestedView: The view shown if our state is `.notRequested`
  ///     - isLoadingView: The view shown if our state is `.isLoading`
  ///     - errorView: The view shown if our state is `.failed`
  public init(
    store: Store<Loadable<LoadedValue, Failure>, Action>,
    onLoad loadAction: Action,
    autoLoad: Bool = true,
    @ViewBuilder loadedView: @escaping (Store<LoadedValue, Action>) -> LoadedView,
    @ViewBuilder notRequestedView: @escaping (Store<Void, Action>) -> NotRequestedView,
    @ViewBuilder isLoadingView: @escaping (Store<LoadedValue?, Action>) -> IsLoadingView,
    @ViewBuilder errorView: @escaping (Store<Failure, Action>) -> ErrorView
  ) {
    self.store = store
    self.autoLoad = autoLoad
    self.notRequestedView = notRequestedView
    self.errorView = errorView
    self.isLoadingView = isLoadingView
    self.loadedView = loadedView
    self.loadAction = loadAction
  }

  public var body: some View {
    SwitchStore(self.store) {
      // Not Requested.
      CaseLet<
        Loadable<LoadedValue, Failure>,
        Action,
        Void,
        Action,
        AnyView
      >(
        state: /Loadable<LoadedValue, Failure>.notRequested,
        action: { $0 },
        then: { store in
          AnyView(
            WithViewStore(store) { viewStore in
              notRequestedView(store)
                .onAppear {
                  if autoLoad {
                    viewStore.send(loadAction)
                  }
                }
            }
          )
        }
      )
      // Loaded.
      CaseLet<
        Loadable<LoadedValue, Failure>,
        Action,
        LoadedValue,
        Action,
        LoadedView
      >(
        state: /Loadable<LoadedValue, Failure>.loaded,
        action: { $0 },
        then: loadedView
      )
      // Is loading.
      CaseLet<
        Loadable<LoadedValue, Failure>,
        Action,
        LoadedValue?,
        Action,
        IsLoadingView
      >(
        state: /Loadable<LoadedValue, Failure>.isLoading,
        action: { $0 },
        then: isLoadingView
      )
      // Failed
      CaseLet<
        Loadable<LoadedValue, Failure>,
        Action,
        Failure,
        Action,
        ErrorView
      >(
        state: /Loadable<LoadedValue, Failure>.failed,
        action: { $0 },
        then: errorView
      )
    }
  }
}

// MARK: - View Overrides.
extension LoadableView {

  /// Replaces / overrides the `error` view.
  ///
  /// - Parameters:
  ///   - view: The new error view.
  public func error<V: View>(
    view: @escaping (Store<Failure, Action>) -> V
  ) -> LoadableView<LoadedValue, Action, Failure, NotRequestedView, LoadedView, V, IsLoadingView> {
    .init(
      store: store,
      onLoad: loadAction,
      autoLoad: autoLoad,
      loadedView: loadedView,
      notRequestedView: notRequestedView,
      isLoadingView: isLoadingView,
      errorView: view
    )
  }

  /// Replaces / overrides the `isLoading`  view.
  ///
  /// - Parameters:
  ///   - view: The new is loading view.
  public func isLoading<V: View>(
    view: @escaping (Store<LoadedValue?, Action>) -> V
  ) -> LoadableView<LoadedValue, Action, Failure, NotRequestedView, LoadedView, ErrorView, V> {
    .init(
      store: store,
      onLoad: loadAction,
      autoLoad: autoLoad,
      loadedView: loadedView,
      notRequestedView: notRequestedView,
      isLoadingView: view,
      errorView: errorView
    )
  }

  /// Replaces / overrides the `loaded`  view.
  ///
  /// - Parameters:
  ///   - view: The new loaded view.
  public func loaded<V: View>(
    view: @escaping (Store<LoadedValue, Action>) -> V
  ) -> LoadableView<LoadedValue, Action, Failure, NotRequestedView, V, ErrorView, IsLoadingView> {
    .init(
      store: store,
      onLoad: loadAction,
      autoLoad: autoLoad,
      loadedView: view,
      notRequestedView: notRequestedView,
      isLoadingView: isLoadingView,
      errorView: errorView
    )
  }

  /// Replaces / overrides the `notRequested`  view.
  ///
  /// - Parameters:
  ///   - view: The new not requested view.
  public func notRequested<V: View>(
    view: @escaping (Store<Void, Action>) -> V
  ) -> LoadableView<LoadedValue, Action, Failure, V, LoadedView, ErrorView, IsLoadingView> {
    .init(
      store: store,
      onLoad: loadAction,
      autoLoad: autoLoad,
      loadedView: loadedView,
      notRequestedView: view,
      isLoadingView: isLoadingView,
      errorView: errorView
    )
  }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension LoadableView
where
  Failure: Equatable,
  NotRequestedView == ProgressView<EmptyView, EmptyView>,
  IsLoadingView == SwitchStore<
    LoadedValue?, Action,
    WithViewStore<
      LoadedValue?, Action,
      _ConditionalContent<
        _ConditionalContent<
          CaseLet<LoadedValue?, Action, Void, Action, ProgressView<EmptyView, EmptyView>>,
          CaseLet<
            LoadedValue?, Action, LoadedValue, Action,
            VStack<
              TupleView<
                (
                  ProgressView<EmptyView, EmptyView>,
                  LoadedView
                )
              >
            >
          >
        >, Default<_ExhaustivityCheckView<LoadedValue?, Action>>
      >
    >
  >,
  ErrorView == WithViewStore<Failure, Action, VStack<TupleView<(Text, Button<Text>)>>>
{
  /// Create a loadable view with defaults for all the states, except for `loaded`.
  ///
  /// - parameters:
  ///    - store: The store to derive our state and actions from.
  ///    - autoLoad: A flag for if we automatically send a load action if our state is `.notRequested`
  ///    - loadAction: The action that loads our value.
  ///    - loadedView: The view shown if our state is `.loaded`
  public init(
    store: Store<Loadable<LoadedValue, Failure>, Action>,
    autoLoad: Bool = true,
    onLoad loadAction: Action,
    failure: Failure.Type = Failure.self,
    @ViewBuilder loadedView: @escaping (Store<LoadedValue, Action>) -> LoadedView
  ) {
    self.init(
      store: store,
      onLoad: loadAction,
      autoLoad: autoLoad,
      loadedView: loadedView,
      notRequestedView: { _ in ProgressView() },
      isLoadingView: { store in
        SwitchStore(store) {
          CaseLet<
            LoadedValue?,
            Action,
            Void,
            Action,
            ProgressView
          >(
            state: /Optional<LoadedValue>.none,
            action: { $0 },
            then: { _ in ProgressView() }
          )
          CaseLet<
            LoadedValue?,
            Action,
            LoadedValue,
            Action,
            VStack<TupleView<(ProgressView<EmptyView, EmptyView>, LoadedView)>>
          >(
            state: /Optional<LoadedValue>.some,
            action: { $0 },
            then: { store in
              VStack {
                ProgressView()
                loadedView(store)
              }
            }
          )
        }
      },
      errorView: { store in
        WithViewStore(store) { viewStore in
          VStack {
            Text(viewStore.localizedDescription)
              .font(.callout)
            Button("Retry", action: { viewStore.send(loadAction) })
          }
        }
      }
    )
  }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension LoadableView
where
  Action == LoadableAction<LoadedValue, Failure>,
  Failure: Equatable,
  NotRequestedView == ProgressView<EmptyView, EmptyView>,
  IsLoadingView == SwitchStore<
    LoadedValue?, Action,
    WithViewStore<
      LoadedValue?, Action,
      _ConditionalContent<
        _ConditionalContent<
          CaseLet<LoadedValue?, Action, Void, Action, ProgressView<EmptyView, EmptyView>>,
          CaseLet<
            LoadedValue?, Action, LoadedValue, Action,
            VStack<
              TupleView<
                (
                  ProgressView<EmptyView, EmptyView>,
                  LoadedView
                )
              >
            >
          >
        >, Default<_ExhaustivityCheckView<LoadedValue?, Action>>
      >
    >
  >,
  ErrorView == WithViewStore<Failure, Action, VStack<TupleView<(Text, Button<Text>)>>>
{

  /// Create a loadable view with defaults for all the states, except for `loaded`.
  ///
  /// - parameters:
  ///     - store: The store to derive our state and actions from.
  ///     - autoLoad: A flag for if we automatically send a load action if our state is `.notRequested`
  ///     - loadedView: The view shown if our state is `.loaded`
  public init(
    store: Store<Loadable<LoadedValue, Failure>, Action>,
    autoLoad: Bool = true,
    failure: Failure.Type = Failure.self,
    @ViewBuilder loadedView: @escaping (Store<LoadedValue, Action>) -> LoadedView
  ) {
    self.init(
      store: store,
      autoLoad: autoLoad,
      onLoad: .load,
      failure: failure,
      loadedView: loadedView
    )
  }
}
