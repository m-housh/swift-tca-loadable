//
//  Reducer + loadable.swift
//  

import Foundation
import ComposableArchitecture

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
    ) -> Reducer where E: LoadableEnvironment {
        .combine(
            Reducer<Loadable<E.LoadedValue>, LoadableAction<E.LoadedValue>, E> { state, action, environment in
                switch action {
                
                // Load the item and set the state appropriately.
                case .load:
                    state = .isLoading(previous: state.value)
                    return environment
                        .load()
                        .catchToEffect()
                        .map { LoadableAction<E.LoadedValue>.loadingCompleted($0) }
                    
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
}
