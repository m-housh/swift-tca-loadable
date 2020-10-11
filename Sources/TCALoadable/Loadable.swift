//
// Loadable.swift
//

import Foundation

/// Represents the different states of a loadable item.
public enum Loadable<T> {
    
    /// Item has not yet been loaded.
    case notRequested
    
    /// Item is in the process of loading and any previously loaded state.
    case isLoading(previous: T?)
    
    /// Item has successfully loaded.
    case loaded(T)
    
    /// Item failed to load.
    case failed(Error)
    
    /// The current value of the item, if it has been previously loaded.
    public var value: T? {
        switch self {
        case let .loaded(value):
            return value
        case let .isLoading(previous: previous):
            return previous
        default:
            return nil
        }
    }
}

extension Loadable: Equatable where T: Equatable {
    public static func == (lhs: Loadable<T>, rhs: Loadable<T>) -> Bool {
        switch (lhs, rhs) {
        case (.notRequested, .notRequested):
            return true
        case let (.isLoading(lhsV), .isLoading(rhsV)):
            return lhsV == rhsV
        case let (.loaded(lhsV), .loaded(rhsV)):
            return lhsV == rhsV
        case let (.failed(lhsE), .failed(rhsE)):
            return lhsE.localizedDescription == rhsE.localizedDescription
        default:
            return false
        }
    }
}
