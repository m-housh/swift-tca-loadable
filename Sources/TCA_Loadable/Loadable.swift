import Foundation

public enum Loadable<T> {
    case notRequested
    case isLoading(previous: T?)
    case loaded(T)
    case failed(Error)
}

extension Loadable: Equatable where T: Equatable {
    public static func == (lhs: Loadable<T>, rhs: Loadable<T>) -> Bool {
        switch (lhs, rhs) {
        case (.notRequested, .notRequested):
            return true
        case let (.isLoading(lhsV), .isLoading(rhsV)):
            return lhsV == rhsV
        case let (.loaded(lhsV), .loaded(rhsV)):
            return lhsV == rhsV
        case let (.failed(lhsE), .failed(rhsE)):
            return lhsE.localizedDescription == rhsE.localizedDescription
        default:
            return false
        }
    }
}
