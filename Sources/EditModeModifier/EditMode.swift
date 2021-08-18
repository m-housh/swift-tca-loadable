import ComposableArchitecture
@_exported import EditModeShim
import SwiftUI

public enum EditModeAction: Equatable {
  case binding(BindingAction<EditMode>)
}

extension Reducer {
  
  public func editMode(
    state: WritableKeyPath<State, EditMode>,
    action: CasePath<Action, EditModeAction>
  ) -> Reducer {
    .combine(
      Reducer<EditMode, EditModeAction, Void>.empty
        .binding(action: /EditModeAction.binding)
        .pullback(state: state, action: action, environment: { _ in }),
      self
    )
  }
}

private struct EditModeModifier: ViewModifier {
  let store: Store<EditMode, EditModeAction>
  
  func body(content: Content) -> some View {
    WithViewStore(store) { viewStore in
      content.environment(
        \.editMode,
         viewStore.binding(keyPath: \.self, send: EditModeAction.binding)
      )
    }
  }
}

public struct EditButton: View {
  public let store: Store<EditMode, EditModeAction>
  
  public init(store: Store<EditMode, EditModeAction>) {
    self.store = store
  }
  
  public var body: some View {
    WithViewStore(store) { viewStore in
      Button(viewStore.isEditing ? "Done" : "Edit") {
        viewStore.send(.binding(.set(\.self, viewStore.isEditing ? .inactive : .active)))
      }
    }
  }
}

extension View {
  
  public func editMode(
    _ store: Store<EditMode, EditModeAction>
  ) -> some View {
    self.modifier(EditModeModifier(store: store))
  }
}
