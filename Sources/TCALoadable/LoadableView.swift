//
//  LoadableView.swift
//  

import SwiftUI
import Combine
import ComposableArchitecture

/// A view that can handle loadable items using the `ComposableArchitecture` pattern.  You will most likely want to make a more concrete
/// view that fits your needs, using this internally.
///
/// Example:
/// ``` swift
/// struct MyErrorView: View {
///     let error: Error
///
///     var body: some View {
///         Text(error.localizedDescription)
///             .font(.callout)
///     }
/// }
///
/// struct MyLoadedView: View {
///     let number: Int
///
///     var body: some View {
///         Text("The loaded number is: \(number)")
///     }
/// }
///
/// struct MyLoadableNumberView: View {
///     let store: Store<Loadable<Int>, LoadableAction<Int>>
///
///     var body: some View {
///         LoadableView(store: store, autoLoad: true) { loadedNumber in
///             MyLoadedView(number: loadedNumber)
///         }
///         notRequestedView: { ProgressView() }
///         isLoadingView: { ProgressView() }
///         errorView: { MyErrorView(error: $0) }
///     }
/// }
///
/// struct MyLoadableEnvironment: LoadableEnvironment {
///     typealias LoadedValue: Int
///
///     let mainQueue: AnySchedulerOf<DispatchQueue>
///
///     func load() -> Effect<Int, Error> {
///         Just(1)
///             .delay(for: .seconds(1), scheduler: mainQueue)
///             .setFailureType(to: Error.self)
///             .eraseToEffect()
///     }
/// }
///
/// let view = MyLoadableNumberView(
///     store: Store(
///         initialState: .init(loadable: Loadable<Int>.notRequested),
///         reducer: Reducer.empty.loadable(
///             state: \.self,
///             action: /LoadableAction.self,
///             environment: { $0 }
///         ),
///         environment: MyLoadableEnvironment(
///             mainQueue: DispatchQueue.main.eraseToAnyScheduler()
///         )
///     )
/// )
///```
public struct LoadableView<
  LoadedValue: Equatable,
  LoadRequest,
  NotRequestedView: View,
  LoadedView: View,
  ErrorView: View,
  IsLoadingView: View
>: View {
  
  /// The store to derive our state and actions from.
  public let store: Store<LoadableState<LoadedValue, LoadRequest>, LoadableAction<LoadedValue>>
  
  /// A flag for if we automatically send a load action when the view appears and our state is `.notRequested`
  let autoLoad: Bool
  
  /// The view shown when our state is `.notRequested`
  let notRequestedView: () -> NotRequestedView
  
  /// The view shown when our state is `.loaded`
  let loadedView: (LoadedValue) -> LoadedView
  
  /// The view shown when our state is `.isLoading`
  let isLoadingView: (LoadedValue?) -> IsLoadingView
  
  /// The view shown when our state is `.failed`
  let errorView: (Error) -> ErrorView
  
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
    store: Store<LoadableState<LoadedValue, LoadRequest>, LoadableAction<LoadedValue>>,
    autoLoad: Bool = false,
    @ViewBuilder loadedView: @escaping (LoadedValue) -> LoadedView,
    @ViewBuilder notRequestedView: @escaping () -> NotRequestedView,
    @ViewBuilder isLoadingView: @escaping (LoadedValue?) -> IsLoadingView,
    @ViewBuilder errorView: @escaping (Error) -> ErrorView
  ) {
    self.store = store
    self.autoLoad = autoLoad
    self.notRequestedView = notRequestedView
    self.errorView = errorView
    self.isLoadingView = isLoadingView
    self.loadedView = loadedView
  }
  
  public var body: some View {
    WithViewStore(store) { viewStore in
      switch viewStore.state.loadable {
      case .notRequested:
        notRequestedView().onAppear {
          if autoLoad {
            viewStore.send(.load)
          }
        }
      case let .isLoading(previous):
        isLoadingView(previous)
      case let .failed(error):
        errorView(error)
      case let .loaded(value):
        loadedView(value)
      }
    }
  }
}

/// A basic loadable view that uses a `ProgressView` when it's state is `.notRequested` or `.isLoading`.
///
/// Example:
/// ```
/// struct MyErrorView: View {
///     let error: Error
///
///     var body: some View {
///         Text(error.localizedDescription)
///             .font(.callout)
///     }
/// }
///
/// struct MyLoadedView: View {
///     let number: Int
///
///     var body: some View {
///         Text("The loaded number is: \(number)")
///     }
/// }
///
/// struct MyLoadableEnvironment: LoadableEnvironment {
///     typealias LoadedValue: Int
///
///     let mainQueue: AnySchedulerOf<DispatchQueue>
///
///     func load() -> Effect<Int, Error> {
///         Just(1)
///             .delay(for: .seconds(1), scheduler: mainQueue)
///             .setFailureType(to: Error.self)
///             .eraseToEffect()
///     }
/// }
///
/// let store = Store(
///     initialState: Loadable<Int>.notRequested,
///     reducer: Reducer.empty.loadable(
///         state: \.self,
///         action: /LoadableAction<Int>.self,
///         environment: { $0 }
///     ),
///     environment: MyLoadableEnvironment(
///         mainQueue: DispatchQueue.main.eraseToAnyScheduler()
///     )
/// )
///
/// let view = LoadableProgressView(store: store) { loadedNumber in
///     MyLoadedView(number: loadedNumber)
/// }
/// errorView: { MyErrorView(error: $0) }
///
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct LoadableProgressView<LoadedValue: Equatable, LoadRequest, LoadedView: View, ErrorView: View>: View {
  
  /// The store to derive our state and actions.
  public let store: Store<LoadableState<LoadedValue, LoadRequest>, LoadableAction<LoadedValue>>
  
  /// A flag for if we automatically send a load action if our state is `.notRequested`
  let autoLoad: Bool
  
  /// The view shown for when our state is `.loaded`
  let loadedView: (LoadedValue) -> LoadedView
  
  /// The view shown for when our state is `.failed`
  let errorView: (Error) -> ErrorView
  
  /// Create a new view.
  ///
  /// - parameters:
  ///     - store: The store to derive our state and actions from.
  ///     - autoLoad: A flag for if we automatically send a load action if our state is `.notRequested`
  ///     - loadedView: The view shown if our state is `.loaded`
  ///     - errorView: The view shown if our state is `.failed`
  ///
  public init(
    store: Store<LoadableState<LoadedValue, LoadRequest>, LoadableAction<LoadedValue>>,
    autoLoad: Bool = true,
    @ViewBuilder loadedView: @escaping (LoadedValue) -> LoadedView,
    @ViewBuilder errorView: @escaping (Error) -> ErrorView
  ) {
    self.store = store
    self.autoLoad = autoLoad
    self.loadedView = loadedView
    self.errorView = errorView
  }
  
  public var body: some View {
    WithViewStore(store) { viewStore in
      LoadableView(store: store, autoLoad: autoLoad) { loaded in
        loadedView(loaded)
      }
    notRequestedView: {
      ProgressView()
    }
    isLoadingView: { previous in
      switch previous {
      case .none:
        ProgressView("Loading")
      case let .some(item):
        VStack {
          ProgressView()
          loadedView(item)
        }
      }
    }
    errorView: { errorView($0) }
    }
  }
}
