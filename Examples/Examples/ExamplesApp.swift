import SwiftUI

@main
struct ExamplesApp: SwiftUI.App {
  var body: some Scene {
    WindowGroup {
      ContentView(
        store: .init(initialState: App.State(), reducer: App())
      )
    }
  }
}
