//
//  Reducer + loadable.swift
//

import ComposableArchitecture
import Foundation

extension Reducer {

  /// Enhances a reducer with loadable actions.
  ///
  /// When using this overload the caller still needs to implement / override the `load`, however it handles
  /// setting the state appropriately on the loadable.
  ///
  /// - Parameters:
  ///     - state: The key path to a loadable item.
  ///     - action: The case path to the loadable actions.
  public func loadable<Value, Failure>(
    state: WritableKeyPath<State, Loadable<Value, Failure>>,
    action: CasePath<Action, LoadableAction<Value, Failure>>
  ) -> Reducer {
    .combine(
      Reducer<Loadable<Value, Failure>, LoadableAction<Value, Failure>, Void> { state, action, _ in
        switch action {

        // Load the item and set the state appropriately.
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

  /// Enhances a reducer with all the loadable actions when the environment's `LoadRequest` type is equal to `EmptyLoadRequest`.
  ///
  /// - Parameters:
  ///    - state: The key path to a loadable item.
  ///    - action: The case path to the loadable actions.
  ///    - environment: The loadable environment.
  public func loadable<E>(
    state: WritableKeyPath<State, Loadable<E.LoadedValue, E.Failure>>,
    action: CasePath<Action, LoadableAction<E.LoadedValue, E.Failure>>,
    environment: @escaping (Environment) -> E
  ) -> Reducer
  where
    E: LoadableEnvironmentRepresentable,
    E.LoadRequest == EmptyLoadRequest
  {
    .combine(
      Reducer<Loadable<E.LoadedValue, E.Failure>, LoadableAction<E.LoadedValue, E.Failure>, E> {
        state, action, environment in
        switch action {

        // Load the item and set the state appropriately.
        case .load:
          state = .isLoading(previous: state.rawValue)
          return environment.load(.init())
            .receive(on: environment.mainQueue)
            .catchToEffect()
            .map(LoadableAction<E.LoadedValue, E.Failure>.loadingCompleted)

        case .loadingCompleted:
          return .none
        }
      }
      .loadable(state: \.self, action: /LoadableAction.self)
      .pullback(state: state, action: action, environment: environment),
      self
    )
  }

}
