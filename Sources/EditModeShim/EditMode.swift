import SwiftUI

#if canImport(AppKit)

  @available(macOS 10.15, *)
  public enum EditMode: Equatable, Hashable {
    case active
    case inactive
    case transient
    
    public var isEditing: Bool {
      switch self {
      case .active, .transient:
        return true
      case .inactive:
        return false
      }
    }
  }

  private struct EditModeKey: EnvironmentKey {
    static var defaultValue: Binding<EditMode>? { nil }
  }

  @available(macOS 10.15, *)
  extension EnvironmentValues {

    public var editMode: Binding<EditMode>? {
      get { self[EditModeKey.self] }
      set { self[EditModeKey.self] = newValue }
    }
  }

#endif
