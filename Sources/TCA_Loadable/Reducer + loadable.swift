//
//  Reducer + loadable.swift
//  
//
//  Created by Michael on 10/10/20.
//

import Foundation
import ComposableArchitecture

extension Reducer {
    
    public func loadable<E>(
        state: WritableKeyPath<State, Loadable<E.Item>>,
        action: CasePath<Action, LoadableAction<E.Item>>,
        environment: @escaping (Environment) -> E
    ) -> Reducer where E: LoadableEnvironment {
        .combine(
            Reducer<Loadable<E.Item>, LoadableAction<E.Item>, E> { state, action, environment in
                switch action {
                case .load:
                    return environment
                        .load()
                        .catchToEffect()
                        .map { LoadableAction<E.Item>.loadingCompleted($0) }
                    
                case let .loadingCompleted(.success(item)):
                    state = .loaded(item)
                    return .none
                    
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
