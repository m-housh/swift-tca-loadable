import ComposableArchitecture
import SwiftUI
import TCALoadable

public enum LoadableListAction<LoadedValue: Collection, Failure: Error> where LoadedValue: Equatable {
  
  case list(ListAction)
  case load(LoadableAction<LoadedValue, Failure>)
  
  public enum ListAction: Equatable {
    case delete(IndexSet)
    case move(IndexSet, Int)
  }
}
extension LoadableListAction: Equatable where Failure: Equatable { }

extension Reducer {
  
  public func loadableList<T, F>(
    state: WritableKeyPath<State, Loadable<T, F>>,
    action: CasePath<Action, LoadableListAction<T, F>>
  ) -> Reducer where T: RangeReplaceableCollection, T: MutableCollection {
    .combine(
      Reducer<Loadable<T, F>, LoadableListAction<T, F>, Void> { state, action, _ in
        switch action {
        case let .list(.delete(indexSet)):
          state.rawValue?.remove(atOffsets: indexSet)
          return .none
        case let .list(.move(source, destination)):
          state.rawValue?.move(fromOffsets: source, toOffset: destination)
          return .none
        case .load:
          return .none
        }
      }
        .loadable(state: \.self, action: /LoadableListAction<T, F>.load)
        .pullback(state: state, action: action, environment: { _ in }),
      self
    )
  }
  
  public func loadableList<E>(
    state: WritableKeyPath<State, Loadable<E.LoadedValue, E.Failure>>,
    action: CasePath<Action, LoadableListAction<E.LoadedValue, E.Failure>>,
    environment: @escaping (Environment) -> E
  ) -> Reducer where E: LoadableEnvironmentRepresentable, E.LoadedValue: RangeReplaceableCollection, E.LoadedValue: MutableCollection, E.LoadRequest == EmptyLoadRequest, E.Failure: Equatable {
    .combine(
      Reducer<Loadable<E.LoadedValue, E.Failure>, LoadableListAction<E.LoadedValue, E.Failure>, E>.empty
        .loadableList(state: \.self, action: /LoadableListAction.self)
        .loadable(
          state: \.self,
          action: /LoadableListAction<E.LoadedValue, E.Failure>.load,
          environment: { $0 }
        )
        .pullback(state: state, action: action, environment: environment),
      self
    )
  }
  
  public func loadableList<E>(
    state: WritableKeyPath<State, Loadable<E.LoadedValue, E.Failure>>,
    action: CasePath<Action, LoadableListAction<E.LoadedValue, E.Failure>>,
    environment: @escaping (Environment) -> E
  ) -> Reducer where E: LoadableEnvironmentRepresentable, E.LoadedValue: RangeReplaceableCollection, E.LoadedValue: MutableCollection, E.Failure: Equatable {
    .combine(
      Reducer<Loadable<E.LoadedValue, E.Failure>, LoadableListAction<E.LoadedValue, E.Failure>, E>.empty
        .loadableList(state: \.self, action: /LoadableListAction.self)
        .loadable(
          state: \.self,
          action: /LoadableListAction<E.LoadedValue, E.Failure>.load,
          environment: { $0 }
        )
        .pullback(state: state, action: action, environment: environment),
      self
    )
  }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct LoadableListView<
  Element: Equatable,
  Id: Hashable,
  Failure: Error,
  Row: View
>: View where Failure: Equatable {
  
  public let store: Store<Loadable<[Element], Failure>, LoadableListAction<[Element], Failure>>
  
  let autoLoad: Bool
  let id: KeyPath<Element, Id>
  let row: (Element) -> Row
  
  public init(
    store: Store<Loadable<[Element], Failure>, LoadableListAction<[Element], Failure>>,
    autoLoad: Bool = false,
    id: KeyPath<Element, Id>,
    @ViewBuilder row: @escaping (Element) -> Row
  ) {
    self.autoLoad = autoLoad
    self.store = store
    self.row = row
    self.id = id
  }
  
  public var body: some View {
    LoadableView(
      store: store,
      autoLoad: autoLoad,
      onLoad: .load(.load)
    ) { store in
      WithViewStore(store) { viewStore in
        List {
          ForEach(viewStore.state, id: id) {
            row($0)
          }
          .onDelete { viewStore.send(.list(.delete($0))) }
          .onMove { viewStore.send(.list(.move($0, $1))) }
        }
      }
    }
  }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension LoadableListView where Element: Identifiable, Id == Element.ID {
  public init(
    store: Store<Loadable<[Element], Failure>, LoadableListAction<[Element], Failure>>,
    autoLoad: Bool = false,
    @ViewBuilder row: @escaping (Element) -> Row
  ) {
    self.init(
      store: store,
      autoLoad: autoLoad,
      id: \.id,
      row: row
    )
  }
}

#if DEBUG
  import Combine

  struct User: Equatable, Identifiable {
    let id: UUID = UUID()
    var name: String
    
    static let blob = User.init(name: "blob")
    static let blobJr = User.init(name: "blob-jr")
    static let blobSr = User.init(name: "blob-sr")
  }

  enum LoadError: Error, Equatable {
    case loadingFailed
  }

  extension LoadableEnvironment where LoadedValue == [User], LoadRequest == EmptyLoadRequest, Failure == LoadError {
    static let users = Self.init(
      load: { _ in
        Just([User.blob, .blobJr, .blobSr])
          .delay(for: .seconds(1), scheduler: DispatchQueue.main)
          .setFailureType(to: LoadError.self)
          .eraseToEffect()
      },
      mainQueue: .main
    )
  }

  let usersReducer = Reducer<
    Loadable<[User], LoadError>,
    LoadableListAction<[User], LoadError>,
    LoadableEnvironment<[User], EmptyLoadRequest, LoadError>
  >.empty
    .loadableList(
      state: \.self,
      action: /LoadableListAction<[User], LoadError>.self,
      environment: { $0 }
    )

  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  struct TCAView_Previews: PreviewProvider {
    static var previews: some View {
      LoadableListView(
        store: .init(
          initialState: .notRequested,
          reducer: usersReducer,
          environment: .users
        ),
        autoLoad: true
      ) { user in
        Text(user.name)
      }
    }
  }
#endif
