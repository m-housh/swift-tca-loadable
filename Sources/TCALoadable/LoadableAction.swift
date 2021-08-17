//
//  LoadableAction.swift
//  

import Foundation

/// The actions that a loadable view can use.
public enum LoadableAction<LoadedValue: Equatable, Failure: Error> {
  
  /// Load or refresh the item.
  case load
  
  /// The load has completed.
  case loadingCompleted(Result<LoadedValue, Failure>)
}

extension LoadableAction: Equatable where Failure: Equatable { }

public typealias LoadableActionsFor = LoadableAction
