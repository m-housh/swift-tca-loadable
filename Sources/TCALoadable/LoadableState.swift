import Foundation

@dynamicMemberLookup
public struct LoadableState<LoadedValue, LoadRequest> {
  
  public var loadable: Loadable<LoadedValue>
  public var loadRequest: () -> LoadRequest
  
  public init(
    loadable: Loadable<LoadedValue> = .notRequested,
    loadRequest: @escaping () -> LoadRequest
  ) {
    self.loadable = loadable
    self.loadRequest = loadRequest
  }
  
  public subscript<A>(dynamicMember keyPath: KeyPath<LoadedValue, A?>) -> A? {
    loadable.value?[keyPath: keyPath]
  }
}

extension LoadableState: Equatable where LoadedValue: Equatable {
  public static func == (lhs: LoadableState<LoadedValue, LoadRequest>, rhs: LoadableState<LoadedValue, LoadRequest>) -> Bool {
    lhs.loadable == rhs.loadable
  }
}

extension LoadableState where LoadRequest == EmptyLoadRequest {
  public init(loadable: Loadable<LoadedValue> = .notRequested) {
    self.init(loadable: loadable, loadRequest: { EmptyLoadRequest() })
  }
}
