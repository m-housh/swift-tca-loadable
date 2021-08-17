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
  
  /// The failure type.
  associatedtype Failure: Error
  
  /// The method that loads the item.
  var load: (LoadRequest) -> Effect<LoadedValue, Failure> { get }
  
  /// The main dispatch queue.
  var mainQueue: AnySchedulerOf<DispatchQueue> { get }
}

/// An empty load request type.
public struct EmptyLoadRequest: Equatable {
  public init() { }
}

/// A concrete `LoadableEnvironmentRepresentable` type.
public struct LoadableEnvironment<LoadedValue, LoadRequest, Failure: Error>: LoadableEnvironmentRepresentable {
  
  public var load: (LoadRequest) -> Effect<LoadedValue, Failure>
  public var mainQueue: AnySchedulerOf<DispatchQueue>
  
  public init(
    load: @escaping (LoadRequest) -> Effect<LoadedValue, Failure>,
    mainQueue: AnySchedulerOf<DispatchQueue>
  ) {
    self.load = load
    self.mainQueue = mainQueue
  }
}

extension LoadableEnvironment where LoadRequest == EmptyLoadRequest {
  
  public init(
    load: @escaping () -> Effect<LoadedValue, Failure>,
    mainQueue: AnySchedulerOf<DispatchQueue>
  ) {
    self.init(load: { _ in load() }, mainQueue: mainQueue)
  }
}

#if DEBUG
  extension LoadableEnvironment {
    public static var failing: LoadableEnvironment {
      .init(
        load: { _ in .failing("\(Self.self).load is unimplemented") },
        mainQueue: .failing("\(Self.self).mainQueue is unimplemented")
      )
    }
  }
#endif

extension LoadableEnvironment {
  
  public static var noop: LoadableEnvironment {
    .init(load: { _ in .none }, mainQueue: .main)
  }
}
