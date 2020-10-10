//
//  LoadableEnvironment.swift
//  
//
//  Created by Michael on 10/10/20.
//

import Foundation
import ComposableArchitecture

public protocol LoadableEnvironment {
    associatedtype Item
    func load() -> Effect<Item, Error>
}

public struct AnyLoadableEnvironment<Environment>: LoadableEnvironment where Environment: LoadableEnvironment {
    
    public typealias Item = Environment.Item
    
    private let other: Environment
    
    public init(_ other: Environment) {
        self.other = other
    }
    
    public func load() -> Effect<Environment.Item, Error> {
        other.load()
    }
}

extension LoadableEnvironment {
    public func eraseToAnyLoadableEnvironment() -> AnyLoadableEnvironment<Self> {
        AnyLoadableEnvironment(self)
    }
}
