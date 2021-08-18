import ComposableArchitecture
@_exported import EditModeShim
import SwiftUI

/// Represents the actions for changing the edit mode.
public enum EditModeAction: Equatable {
  case binding(BindingAction<EditMode>)
}

extension Reducer {
  
  /// Enhances a reducer with edit mode capabilities.
  ///
  /// - Parameters:
  ///   - state: The edit mode state.
  ///   - action: The edit mode action.
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

/// Sets the edit mode on the environment.
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

/// Represents a composable style edit button.
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
  
  /// Enhances a view with the edit mode environment.
  public func editMode(
    _ store: Store<EditMode, EditModeAction>
  ) -> some View {
    self.modifier(EditModeModifier(store: store))
  }
}
