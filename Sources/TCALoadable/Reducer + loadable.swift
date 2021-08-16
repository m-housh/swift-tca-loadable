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
    state: WritableKeyPath<State, LoadableState<E.LoadedValue, E.LoadRequest>>,
    action: CasePath<Action, LoadableAction<E.LoadedValue>>,
    environment: @escaping (Environment) -> E
  ) -> Reducer where E: LoadableEnvironmentRepresentable {
    .combine(
      Reducer<LoadableState<E.LoadedValue, E.LoadRequest>, LoadableAction<E.LoadedValue>, E> { state, action, environment in
        switch action {
          
          // Load the item and set the state appropriately.
        case .load:
          state.loadable = .isLoading(previous: state.loadable.value)
          return environment
            .load(state.loadRequest())
            .receive(on: environment.mainQueue)
            .catchToEffect()
            .map(LoadableAction<E.LoadedValue>.loadingCompleted)
            .cancellable(id: LoadableCancellationId())
          
          // Loading completed successfully.
        case let .loadingCompleted(.success(item)):
          state.loadable = .loaded(item)
          return .none
          
          // Loading failed.
        case let .loadingCompleted(.failure(error)):
          state.loadable = .failed(error)
          return .none
        }
      }
        .pullback(state: state, action: action, environment: environment),
      self
    )
  }
}
