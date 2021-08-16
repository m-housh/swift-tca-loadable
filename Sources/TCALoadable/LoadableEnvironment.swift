//
//  LoadableEnvironment.swift
//  

import Foundation
import ComposableArchitecture

/// An environment that can load an item.
public protocol LoadableEnvironmentRepresentable {
  
  /// The type that the environment can load.
  associatedtype LoadedValue
  
  /// The request type
  associatedtype LoadRequest
  
  /// The method that loads the item.
  var load: (LoadRequest) -> Effect<LoadedValue, Error> { get }
  
  /// The main dispatch queue.
  var mainQueue: AnySchedulerOf<DispatchQueue> { get }
}

/// An empty load request type.
public struct EmptyLoadRequest: Equatable {
  public init() { }
}

/// A concrete `LoadableEnvironment` type.
public struct LoadableEnvironment<LoadedValue, LoadRequest>: LoadableEnvironmentRepresentable {
  
  public var load: (LoadRequest) -> Effect<LoadedValue, Error>
  public var mainQueue: AnySchedulerOf<DispatchQueue>
  
  public init(
    load: @escaping (LoadRequest) -> Effect<LoadedValue, Error>,
    mainQueue: AnySchedulerOf<DispatchQueue>
  ) {
    self.load = load
    self.mainQueue = mainQueue
  }
}

extension LoadableEnvironment where LoadRequest == EmptyLoadRequest {
  
  public init(
    load: @escaping () -> Effect<LoadedValue, Error>,
    mainQueue: AnySchedulerOf<DispatchQueue>
  ) {
    self.init(load: { _ in load() }, mainQueue: mainQueue)
  }
}
