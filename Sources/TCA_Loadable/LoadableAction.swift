//
//  LoadableAction.swift
//  
//
//  Created by Michael on 10/10/20.
//

import Foundation

public enum LoadableAction<T: Equatable> {
    case load
    case loadingCompleted(Result<T, Error>)
}

extension LoadableAction: Equatable {
    public static func == (lhs: LoadableAction<T>, rhs: LoadableAction<T>) -> Bool {
        switch (lhs, rhs) {
        case (.load, .load):
            return true
        case let (.loadingCompleted(.success(lhsV)), .loadingCompleted(.success(rhsV))):
            return lhsV == rhsV
        case let (.loadingCompleted(.failure(lhsE)), .loadingCompleted(.failure(rhsE))):
            return lhsE.localizedDescription == rhsE.localizedDescription
        default:
            return false
        }
    }
}
