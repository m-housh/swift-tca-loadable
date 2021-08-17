//
//  LoadableAction.swift
//  

import Foundation

/// The actions that a loadable view can use.
public enum LoadableAction<LoadedValue: Equatable> {
  
  /// Load or refresh the item.
  case load
  
  /// The load has completed.
  case loadingCompleted(Result<LoadedValue, Error>)
}

extension LoadableAction: Equatable {
  public static func == (
    lhs: LoadableAction<LoadedValue>,
    rhs: LoadableAction<LoadedValue>
  ) -> Bool {
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

public typealias LoadableActionsFor = LoadableAction
