//
// Loadable.swift
//

import Foundation

/// Represents the different states of a loadable item.
@dynamicMemberLookup
public enum Loadable<Value, Failure: Error> {

  /// Item has not yet been loaded.
  case notRequested

  /// Item is in the process of loading and any previously loaded state.
  case isLoading(previous: Value?)

  /// Item has successfully loaded.
  case loaded(Value)

  /// Item failed to load.
  case failed(Failure)

  /// The current value of the item, if it has been previously loaded.
  public var rawValue: Value? {
    get {
      switch self {
      case let .loaded(value):
        return value
      case let .isLoading(previous: previous):
        return previous
      default:
        return nil
      }
    }
    set {
      guard let newValue = newValue else { return }
      switch self {
      case .loaded:
        self = .loaded(newValue)
      case .isLoading:
        self = .isLoading(previous: newValue)
      default:
        break
      }
    }
  }

  public subscript<A>(dynamicMember keyPath: KeyPath<Value, A>) -> A? {
    self.rawValue?[keyPath: keyPath]
  }
}

extension Loadable: Equatable where Value: Equatable, Failure: Equatable {
  public static func == (lhs: Loadable<Value, Failure>, rhs: Loadable<Value, Failure>) -> Bool {
    switch (lhs, rhs) {
    case (.notRequested, .notRequested):
      return true
    case let (.isLoading(lhsV), .isLoading(rhsV)):
      return lhsV == rhsV
    case let (.loaded(lhsV), .loaded(rhsV)):
      return lhsV == rhsV
    case let (.failed(lhsE), .failed(rhsE)):
      return lhsE == rhsE
    default:
      return false
    }
  }
}
