//
//  LoadableView.swift
//  

import SwiftUI
import Combine
import ComposableArchitecture

public struct LoadableView2<
  LoadedValue: Equatable,
  Action: Equatable,
  NotRequestedView: View,
  LoadedView: View,
  ErrorView: View,
  IsLoadingView: View
>: View {
  
  /// The store to derive our state and actions from.
  public let store: Store<Loadable<LoadedValue>, Action>
  
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
    store: Store<Loadable<LoadedValue>, Action>,
    onLoad loadAction: Action,
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
    self.loadAction = loadAction
  }
  
  public var body: some View {
    WithViewStore(store) { viewStore in
      switch viewStore.state {
      case .notRequested:
        notRequestedView().onAppear {
          if autoLoad {
            viewStore.send(loadAction)
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

public struct LoadableView3<
  LoadedValue: Equatable,
  Action: Equatable,
  NotRequestedView: View,
  LoadedView: View,
  ErrorView: View,
  IsLoadingView: View
>: View {
  
  /// The store to derive our state and actions from.
  public let store: Store<Loadable<LoadedValue>, Action>
  
  /// A flag for if we automatically send a load action when the view appears and our state is `.notRequested`
  let autoLoad: Bool
  
  /// The view shown when our state is `.notRequested`
  let notRequestedView: (Store<Void, Action>) -> NotRequestedView
  
  /// The view shown when our state is `.loaded`
  let loadedView: (Store<LoadedValue, Action>) -> LoadedView
  
  /// The view shown when our state is `.isLoading`
  let isLoadingView: (Store<LoadedValue?, Action>) -> IsLoadingView
  
  /// The view shown when our state is `.failed`
  let errorView: (Store<Error, Action>) -> ErrorView
  
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
    store: Store<Loadable<LoadedValue>, Action>,
    onLoad loadAction: Action,
    autoLoad: Bool = false,
    @ViewBuilder loadedView: @escaping (Store<LoadedValue, Action>) -> LoadedView,
    @ViewBuilder notRequestedView: @escaping (Store<Void, Action>) -> NotRequestedView,
    @ViewBuilder isLoadingView: @escaping (Store<LoadedValue?, Action>) -> IsLoadingView,
    @ViewBuilder errorView: @escaping (Store<Error, Action>) -> ErrorView
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
      CaseLet<
        Loadable<LoadedValue>,
        Action,
        Void,
        Action,
        AnyView
      >(
        state: /Loadable<LoadedValue>.notRequested,
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
      CaseLet<
        Loadable<LoadedValue>,
        Action,
        LoadedValue,
        Action,
        LoadedView
      >(
        state: /Loadable<LoadedValue>.loaded,
        action: { $0 },
        then: loadedView
      )
      CaseLet<
        Loadable<LoadedValue>,
        Action,
        LoadedValue?,
        Action,
        IsLoadingView
      >(
        state: /Loadable<LoadedValue>.isLoading,
        action: { $0 },
        then: isLoadingView
      )
      CaseLet<
        Loadable<LoadedValue>,
        Action,
        Error,
        Action,
        ErrorView
      >(
        state: /Loadable<LoadedValue>.failed,
        action: { $0 },
        then: errorView
      )
    }
//    WithViewStore(store) { viewStore in
//      switch viewStore.state {
//      case .notRequested:
//        notRequestedView().onAppear {
//          if autoLoad {
//            viewStore.send(loadAction)
//          }
//        }
//      case let .isLoading(previous):
//        isLoadingView(previous)
//      case let .failed(error):
//        errorView(error)
//      case let .loaded(value):
//        loadedView(value)
//      }
//    }
  }
}

/// A view that can handle loadable items using the `ComposableArchitecture` pattern.  You will most likely want to make a more concrete
/// view that fits your needs, using this internally.
///
/// Example:
/// ``` swift
/// struct MyErrorView: View {
///   let error: Error
///
///   var body: some View {
///     Text(error.localizedDescription)
///       .font(.callout)
///   }
/// }
///
/// struct MyLoadedView: View {
///   let number: Int
///
///   var body: some View {
///     Text("The loaded number is: \(number)")
///   }
/// }
///
/// struct MyLoadableNumberView: View {
///   let store: Store<LoadableState<Int, EmptyLoadRequest>, LoadableAction<Int>>
///
///   var body: some View {
///     LoadableView(store: store, autoLoad: true) { loadedNumber in
///       MyLoadedView(number: loadedNumber)
///     }
///     notRequestedView: { ProgressView() }
///     isLoadingView: { ProgressView() }
///     errorView: { MyErrorView(error: $0) }
///   }
/// }
///
/// struct MyLoadableEnvironment: LoadableEnvironment {
///   typealias LoadedValue: Int
///   typealias LoadRequest: EmptyLoadRequest
///
///   let mainQueue: AnySchedulerOf<DispatchQueue>
///
///   let load: (EmptyLoadRequest) -> Effect<Int, Error> = { _ in
///     Just(1)
///       .delay(for: .seconds(1), scheduler: mainQueue)
///       .setFailureType(to: Error.self)
///       .eraseToEffect()
///   }
/// }
///
/// let view = MyLoadableNumberView(
///   store: Store(
///     initialState: .init(loadable: Loadable<Int>.notRequested),
///     reducer: Reducer.empty.loadable(
///       state: \.self,
///       action: /LoadableAction.self,
///       environment: { $0 }
///     ),
///     environment: MyLoadableEnvironment(
///       mainQueue: .main
///     )
///   )
/// )
///```
public struct LoadableView<
  LoadedValue: Equatable,
  NotRequestedView: View,
  LoadedView: View,
  ErrorView: View,
  IsLoadingView: View
>: View {
  
  /// The store to derive our state and actions from.
  public let store: Store<Loadable<LoadedValue>, LoadableAction<LoadedValue>>
  
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
    store: Store<Loadable<LoadedValue>, LoadableAction<LoadedValue>>,
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
      switch viewStore.state {
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

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension LoadableView where NotRequestedView == ProgressView<EmptyView, EmptyView> {
  public init(
    store: Store<Loadable<LoadedValue>, LoadableAction<LoadedValue>>,
    autoLoad: Bool = false,
    @ViewBuilder loadedView: @escaping (LoadedValue) -> LoadedView,
    @ViewBuilder isLoadingView: @escaping (LoadedValue?) -> IsLoadingView,
    @ViewBuilder errorView: @escaping (Error) -> ErrorView
  ) {
    self.init(
      store: store,
      loadedView: loadedView,
      notRequestedView: { ProgressView() },
      isLoadingView: isLoadingView,
      errorView: errorView
    )
  }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension LoadableView where
NotRequestedView == ProgressView<EmptyView, EmptyView>,
IsLoadingView == _ConditionalContent<
  ProgressView<EmptyView, EmptyView>,
  VStack<TupleView<(ProgressView<EmptyView, EmptyView>, LoadedView)>>
> {
  public init(
    store: Store<Loadable<LoadedValue>, LoadableAction<LoadedValue>>,
    autoLoad: Bool = false,
    @ViewBuilder loadedView: @escaping (LoadedValue) -> LoadedView,
    @ViewBuilder errorView: @escaping (Error) -> ErrorView
  ) {
    self.init(
      store: store,
      loadedView: loadedView,
      isLoadingView: { previous in
        switch previous {
        case .none:
          ProgressView()
        case let .some(item):
          VStack {
            ProgressView()
            loadedView(item)
          }
        }
      },
      errorView: errorView
    )
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
@available(*, deprecated, message: "Use overload on LoadableView instead.")
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct LoadableProgressView<
  LoadedValue: Equatable,
  LoadedView: View,
  ErrorView: View
>: View {
  
  /// The store to derive our state and actions.
  public let store: Store<Loadable<LoadedValue>, LoadableAction<LoadedValue>>
  
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
    store: Store<Loadable<LoadedValue>, LoadableAction<LoadedValue>>,
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
