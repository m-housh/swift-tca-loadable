import Foundation

#if DEBUG
  public struct User: Equatable, Identifiable {
    public let id: UUID = UUID()
    public var name: String
    
    public init(name: String) {
      self.name = name
    }
    
    public static let blob = User.init(name: "blob")
    public static let blobJr = User.init(name: "blob-jr")
    public static let blobSr = User.init(name: "blob-sr")
  }

  extension Array where Element == User {
    public static let users: Self = [.blob, .blobJr, .blobSr]
  }
#endif
