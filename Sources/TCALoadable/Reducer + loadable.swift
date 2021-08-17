//
//  Reducer + loadable.swift
//  

import Foundation
import ComposableArchitecture

public struct LoadableCancellationId: Hashable {
  public init() { }
}

extension Reducer {
  
  /// Enhances a reducer with loadable actions.
  ///
  /// - Parameters:
  ///     - state: The key path to a loadable item.
  ///     - action: The case path to the loadable actions.
  ///     - environment: The loadable environment.
  public func loadable<E>(
    state: WritableKeyPath<State, Loadable<E.LoadedValue>>,
    action: CasePath<Action, LoadableAction<E.LoadedValue>>,
    environment: @escaping (Environment) -> E
  ) -> Reducer where E: LoadableEnvironmentRepresentable {
    .combine(
      Reducer<Loadable<E.LoadedValue>, LoadableAction<E.LoadedValue>, E> { state, action, environment in
        switch action {
          
        // Load the item and set the state appropriately.
        case .load:
          state = .isLoading(previous: state.rawValue)
          return .none
//          return environment
//            .load(state.loadRequest(state))
//            .receive(on: environment.mainQueue)
//            .catchToEffect()
//            .map(LoadableAction<E.LoadedValue, E.LoadRequest>.loadingCompleted)
//            .cancellable(id: LoadableCancellationId())
          
        // Loading completed successfully.
        case let .loadingCompleted(.success(item)):
          state = .loaded(item)
          return .none
          
        // Loading failed.
        case let .loadingCompleted(.failure(error)):
          state = .failed(error)
          return .none
        }
      }
        .pullback(state: state, action: action, environment: environment),
      self
    )
  }
  
  // caller is responsible for hooking into the load in this scenario and should call loadingComplete.
  public func loadable2<T>(
    state: WritableKeyPath<State, Loadable<T>>,
    action: CasePath<Action, LoadableAction<T>>
  ) -> Reducer {
    .combine(
      Reducer<Loadable<T>, LoadableAction<T>, Void> { state, action, _ in
        switch action {
          
        // Set the state appropriately.
        case .load:
          state = .isLoading(previous: state.rawValue)
          return .none
          
        // Loading completed successfully.
        case let .loadingCompleted(.success(item)):
          state = .loaded(item)
          return .none
          
        // Loading failed.
        case let .loadingCompleted(.failure(error)):
          state = .failed(error)
          return .none
        }
      }
        .pullback(state: state, action: action, environment: { _ in }),
      self
    )
  }
}
