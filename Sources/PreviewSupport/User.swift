import ComposableArchitecture
import Foundation

#if DEBUG
  public struct User: Equatable, Identifiable {
    public let id: UUID = UUID()
    public var name: String
    public var isFavorite: Bool

    public init(name: String, isFavorite: Bool = false) {
      self.name = name
      self.isFavorite = isFavorite
    }

    public static let blob = User.init(name: "blob")
    public static let blobJr = User.init(name: "blob-jr")
    public static let blobSr = User.init(name: "blob-sr")
  }

  extension Array where Element == User {
    public static let users: Self = [.blob, .blobJr, .blobSr]
  }

  public enum UserAction: Equatable {
    case binding(BindingAction<User>)
  }

  public let userReducer = Reducer<User, UserAction, Void>.empty
    .binding(action: /UserAction.binding)
#endif
