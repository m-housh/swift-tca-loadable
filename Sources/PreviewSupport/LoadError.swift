import Foundation

#if DEBUG
  public enum LoadError: Error, Equatable {
    case loadingFailed
  }
#endif
