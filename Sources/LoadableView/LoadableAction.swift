//
//  LoadableAction.swift
//  

import Foundation

/// The actions that a loadable view can use.
public enum LoadableAction<LoadedValue, Failure: Error> {
  
  /// Load or refresh the item.
  case load
  
  /// The load has completed.
  case loadingCompleted(Result<LoadedValue, Failure>)
}

extension LoadableAction: Equatable where LoadedValue: Equatable, Failure: Equatable { }

public typealias LoadableActionsFor = LoadableAction
