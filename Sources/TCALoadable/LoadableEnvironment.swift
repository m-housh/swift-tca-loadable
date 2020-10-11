//
//  LoadableEnvironment.swift
//  

import Foundation
import ComposableArchitecture

/// An environment that can load an item.
public protocol LoadableEnvironment {
    
    /// The type that the environment can load.
    associatedtype LoadedValue
    
    /// The method that loads the item.
    func load() -> Effect<LoadedValue, Error>
}

/// A concrete `LoadableEnvironment` wrapper.
public struct AnyLoadableEnvironment<Environment>: LoadableEnvironment where Environment: LoadableEnvironment {
    
    public typealias LoadedValue = Environment.LoadedValue
    
    private let other: Environment
    
    public init(_ other: Environment) {
        self.other = other
    }
    
    public func load() -> Effect<Environment.LoadedValue, Error> {
        other.load()
    }
}

extension LoadableEnvironment {
    public func eraseToAnyLoadableEnvironment() -> AnyLoadableEnvironment<Self> {
        AnyLoadableEnvironment(self)
    }
}
