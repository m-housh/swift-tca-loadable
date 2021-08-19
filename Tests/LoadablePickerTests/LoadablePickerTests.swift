import XCTest
import Combine
import ComposableArchitecture
import PreviewSupport
import SnapshotTesting
import SwiftUI
@testable import LoadableList
@testable import LoadablePicker


final class LoadablePickerTests: XCTestCase {
  
  var precision: Float!
  
  override func setUp() {
    super.setUp()
    self.precision = 0.99
//    isRecording = true
  }
  
  func test_loadable_picker_binding_action() {
    let store = TestStore(
      initialState: .init(),
      reducer: userPickerReducer,
      environment: .failing
    )
    store.send(.binding(.set(\.selection, User.blob.id))) {
      $0.selection = User.blob.id
    }
  }
  
  func test_loadable_picker_reducer_without_environment() {
    let reducer = Reducer<
      LoadablePickerState<User, LoadError>,
      LoadablePickerAction<User, LoadError>,
      Void
    >.empty
      .loadablePicker(state: \.self, action: /LoadablePickerAction.self)
    
    let store = TestStore(
      initialState: .init(),
      reducer: reducer,
      environment: ()
    )
    store.send(.load(.load)) {
      $0.loadable = .isLoading(previous: nil)
    }
    store.send(.load(.loadingCompleted(.success(.users)))) {
      $0.loadable = .loaded(.users)
    }
    store.send(.load(.loadingCompleted(.failure(.loadingFailed)))) {
      $0.loadable = .failed(.loadingFailed)
    }
    store.send(.binding(.set(\.selection, User.blob.id))) {
      $0.selection = User.blob.id
    }
  }
  
  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  func test_loadable_picker_root_view() {
    let view = TestPickerView(
      store: .init(
        initialState: .init(loadable: .loaded(.users), selection: nil), reducer: userPickerReducer,
        environment: .failing)
    )
    #if os(macOS)
    let vc = NSHostingController(rootView: view)
    assertSnapshot(
      matching: vc,
      as: .image(precision: precision, size: CGSize(width: 300, height: 300)),
      named: "macOS"
    )
    #elseif os(iOS)
    assertSnapshot(
      matching: view,
      as: .image(layout: .fixed(width: 300, height: 300), traits: .init(userInterfaceStyle: .light)),
      named: "ios"
    )
    #endif
  }
  
  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  func test_loadable_picker_root_view_with_nil_selection_disabled() {
    let view = TestPickerView(
      store: .init(
        initialState: .init(loadable: .loaded(.users), selection: nil), reducer: userPickerReducer,
        environment: .failing),
      allowNilSelection: false
    )
    #if os(macOS)
    let vc = NSHostingController(rootView: view)
    assertSnapshot(
      matching: vc,
      as: .image(precision: precision, size: CGSize(width: 300, height: 300)),
      named: "macOS"
    )
    #elseif os(iOS)
    assertSnapshot(
      matching: view,
      as: .image(layout: .fixed(width: 300, height: 300), traits: .init(userInterfaceStyle: .light)),
      named: "ios"
    )
    #endif
  }
  
  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  func test_loadable_picker_selection_view() {
    let view = TestPickerView(
      store: .init(
        initialState: .init(loadable: .loaded(.users), selection: User.blob.id), reducer: userPickerReducer,
        environment: .failing)
    )
    #if os(macOS)
    let vc = NSHostingController(rootView: view)
    assertSnapshot(
      matching: vc,
      as: .image(precision: precision, size: CGSize(width: 300, height: 300)),
      named: "macOS"
    )
    #elseif os(iOS)
    assertSnapshot(
      matching: view,
      as: .image(layout: .fixed(width: 300, height: 300), traits: .init(userInterfaceStyle: .light)),
      named: "ios"
    )
    #endif
  }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
struct TestPickerView: View {
  let store: Store<LoadablePickerState<User, LoadError>, LoadablePickerAction<User, LoadError>>
  var allowNilSelection: Bool = true
  var autoLoad: Bool = true
  
  var body: some View {
    NavigationView {
      Form {
        LoadablePicker(
          "User",
          store: store,
          allowNilSelection: allowNilSelection,
          autoLoad: autoLoad,
          nilSelectionTitle: nil // ensure it gets set appropriately.
        ) { user in
          Text(user.name)
        }
      }
    }
  }
}
