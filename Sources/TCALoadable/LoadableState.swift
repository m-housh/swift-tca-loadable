import Foundation

//@dynamicMemberLookup
//public struct LoadableState<LoadedValue, Action> {
//
//  public var rawValue: Loadable<LoadedValue>
//  public var action: Action
//
//  public init(
//    rawValue: Loadable<LoadedValue> = .notRequested,
//    action: Action
//  ) {
//    self.rawValue = rawValue
//    self.action = action
//  }
//
//  public subscript<A>(dynamicMember keyPath: KeyPath<LoadedValue, A?>) -> A? {
//    rawValue.rawValue?[keyPath: keyPath]
//  }
//}

//extension LoadableState: Equatable where LoadedValue: Equatable, LoadRequest: Equatable {
//  public static func == (
//    lhs: LoadableState<LoadedValue, LoadRequest>,
//    rhs: LoadableState<LoadedValue, LoadRequest>
//  ) -> Bool {
//    lhs.rawValue == rhs.rawValue
//      && lhs.loadRequest(lhs) == rhs.loadRequest(rhs)
//  }
//}
//
//extension LoadableState where LoadRequest == EmptyLoadRequest {
//  public init(rawValue: Loadable<LoadedValue> = .notRequested) {
//    self.init(rawValue: rawValue, loadRequest: { _ in EmptyLoadRequest() })
//  }
//}
