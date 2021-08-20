import ComposableArchitecture

/// Represents common actions that can be taken on lists.
public enum ListAction: Equatable {

  /// Delete rows from the list.
  case delete(IndexSet)

  /// Move rows in the list.
  case move(IndexSet, Int)
}

extension Reducer {

  /// Enhances a reducer with list actions.
  ///
  /// - Parameters:
  ///   - state: The list state.
  ///   - action: The list actions.
  public func list<A>(
    state: WritableKeyPath<State, A>,
    action: CasePath<Action, ListAction>
  ) -> Reducer where A: MutableCollection, A: RangeReplaceableCollection {
    .combine(
      Reducer<A, ListAction, Void> { state, action, _ in
        switch action {
        case let .delete(indexSet):
          state.remove(atOffsets: indexSet)
          return .none

        case let .move(source, destination):
          state.move(fromOffsets: source, toOffset: destination)
          return .none
        }
      }
      .pullback(state: state, action: action, environment: { _ in }),
      self
    )
  }

  /// Enhances a reducer with list actions for an optional list.
  ///
  /// - Parameters:
  ///   - state: The list state.
  ///   - action: The list actions.
  public func list<A>(
    state: WritableKeyPath<State, A?>,
    action: CasePath<Action, ListAction>
  ) -> Reducer where A: MutableCollection, A: RangeReplaceableCollection {
    .combine(
      Reducer<A, ListAction, Void>.empty
        .list(state: \.self, action: /ListAction.self)
        .optional()
        .pullback(state: state, action: action, environment: { _ in }),
      self
    )
  }

  /// Enhances an `IdentifiedArray` reducer with list actions.
  ///
  /// - Parameters:
  ///   - state: The list state.
  ///   - action: The list actions.
  public func list<Element, Id: Hashable>(
    state: WritableKeyPath<State, IdentifiedArray<Id, Element>>,
    action: CasePath<Action, ListAction>
  ) -> Reducer {
    .combine(
      Reducer<IdentifiedArray<Id, Element>, ListAction, Void> { state, action, _ in
        switch action {
        case let .delete(indexSet):
          state.remove(atOffsets: indexSet)
          return .none

        case let .move(source, destination):
          state.move(fromOffsets: source, toOffset: destination)
          return .none
        }
      }
      .pullback(state: state, action: action, environment: { _ in }),
      self
    )
  }

  /// Enhances an optional `IdentifiedArray` reducer with list actions.
  ///
  /// - Parameters:
  ///   - state: The list state.
  ///   - action: The list actions.
  public func list<Element, Id: Hashable>(
    state: WritableKeyPath<State, IdentifiedArray<Id, Element>?>,
    action: CasePath<Action, ListAction>
  ) -> Reducer {
    .combine(
      Reducer<IdentifiedArray<Id, Element>, ListAction, Void>
        .empty
        .list(state: \.self, action: /ListAction.self)
        .optional()
        .pullback(state: state, action: action, environment: { _ in }),
      self
    )
  }
}
