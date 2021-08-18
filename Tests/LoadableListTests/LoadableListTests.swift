import XCTest
import Combine
import ComposableArchitecture
import PreviewSupport
import SnapshotTesting
import SwiftUI

@testable import LoadableList

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
final class LoadableListTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
//    isRecording = true
  }
  
  func test_loadable_list_while_not_editing() {
    
    let view = LoadableListView(
      store: .init(
        initialState: .init(),
        reducer: usersReducer,
        environment: .test
      )
    ) { user in
      Text(user.name)
    }
    
    #if os(macOS)
    let vc = NSHostingController(rootView: view)
    assertSnapshot(matching: vc, as: .image(precision: 1, size: CGSize(width: 300, height: 300)))
    #endif
    #if os(iOS)
    assertSnapshot(matching: view, as: .image(layout: .fixed(width: 300, height: 300), traits: .init(userInterfaceStyle: .light)), named: "ios-not-editing")
    #endif
  }
  
  func test_loadable_list_while_editing() {
    
    let view = LoadableListView(
      store: .init(
        initialState: .init(editMode: .active),
        reducer: usersReducer,
        environment: .test
      )
    ) { user in
      Text(user.name)
    }
    
    #if os(macOS)
    let vc = NSHostingController(rootView: view)
    assertSnapshot(matching: vc, as: .image(precision: 1, size: CGSize(width: 300, height: 300)))
    #endif
    #if os(iOS)
    assertSnapshot(matching: view, as: .image(layout: .fixed(width: 300, height: 300), traits: .init(userInterfaceStyle: .light)), named: "ios-editing")
    #endif
  }
}

extension LoadableListViewEnvironment where Element == User, LoadRequest == EmptyLoadRequest, Failure == LoadError {
  public static let test = Self.init(
    load: { _ in
      Just([User.blob, .blobJr, .blobSr])
        .setFailureType(to: LoadError.self)
        .eraseToEffect()
    },
    mainQueue: .immediate
  )
}
