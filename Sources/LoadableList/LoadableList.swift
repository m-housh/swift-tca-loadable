import ComposableArchitecture
@_exported import EditModeModifier
@_exported import LoadableView
import SwiftUI

public struct LoadableListViewEnvironment<Element, LoadRequest, Failure: Error> {
  
  public var load: (LoadRequest) -> Effect<[Element], Failure>
  public var mainQueue: AnySchedulerOf<DispatchQueue>
  
  public init(
    load: @escaping (LoadRequest) -> Effect<[Element], Failure>,
    mainQueue: AnySchedulerOf<DispatchQueue>
  ) {
    self.load = load
    self.mainQueue = mainQueue
  }
}
extension LoadableListViewEnvironment: LoadableEnvironmentRepresentable { }
public typealias LoadableListViewEnvironmentFor = LoadableListViewEnvironment

// MARK: - State
public struct LoadableListViewState<Element, Failure: Error> {
  public var editMode: EditMode
  public var loadable: Loadable<[Element], Failure>
  
  public init(
    editMode: EditMode = .inactive,
    loadable: Loadable<[Element], Failure> = .notRequested
  ) {
    self.editMode = editMode
    self.loadable = loadable
  }
}
extension LoadableListViewState: Equatable where Element: Equatable, Failure: Equatable { }
public typealias LoadableListViewStateFor = LoadableListViewState

// MARK: - Action
public enum ListAction: Equatable {
  case delete(IndexSet)
  case move(IndexSet, Int)
}

public enum LoadableListViewAction<Element, Failure: Error> where Element: Equatable {
  case binding(BindingAction<LoadableListViewStateFor<Element, Failure>>)
  case editMode(EditModeAction)
  case list(ListAction)
  case load(LoadableAction<[Element], Failure>)
}
extension LoadableListViewAction: Equatable where Failure: Equatable { }
public typealias LoadableListViewActionFor = LoadableListViewAction

extension Reducer {
  
  public func loadableList<Element, Failure>(
    state: WritableKeyPath<State, LoadableListViewState<Element, Failure>>,
    action: CasePath<Action, LoadableListViewAction<Element, Failure>>
  ) -> Reducer {
    .combine(
      Reducer<LoadableListViewState<Element, Failure>, LoadableListViewAction<Element, Failure>, Void> { state, action, _ in
        switch action {
          
        case .binding:
          return .none
          
        case .editMode:
          return .none
          
        case let .list(.delete(indexSet)):
          state.loadable.rawValue?.remove(atOffsets: indexSet)
          return .none
          
        case let .list(.move(source, destination)):
          state.loadable.rawValue?.move(fromOffsets: source, toOffset: destination)
          return .none
          
        case .load:
          return .none
        }
      }
        .binding(action: /LoadableListViewAction.binding)
        .editMode(state: \.editMode, action: /LoadableListViewAction.editMode)
        .loadable(state: \.loadable, action: /LoadableListViewAction.load)
        .pullback(state: state, action: action, environment: { _ in }),
      self
    )
  }
  
  public func loadableList<Element, Failure>(
    state: WritableKeyPath<State, LoadableListViewStateFor<Element, Failure>>,
    action: CasePath<Action, LoadableListViewActionFor<Element, Failure>>,
    environment: @escaping (Environment) -> LoadableListViewEnvironmentFor<Element, EmptyLoadRequest, Failure>
  ) -> Reducer where Failure: Equatable, Failure: Error {
    .combine(
      Reducer<
        LoadableListViewState<Element, Failure>,
        LoadableListViewAction<Element, Failure>,
        LoadableListViewEnvironment<Element, EmptyLoadRequest, Failure>
      >.empty
        .loadableList(state: \.self, action: /LoadableListViewAction.self)
        .loadable(
          state: \.loadable,
          action: /LoadableListViewAction.load,
          environment: { $0 }
        )
        .pullback(state: state, action: action, environment: environment),
      self
    )
  }
  
  public func loadableList<Element, Failure: Error, Request>(
    state: WritableKeyPath<State, LoadableListViewStateFor<Element, Failure>>,
    action: CasePath<Action, LoadableListViewActionFor<Element, Failure>>,
    environment: @escaping (Environment) -> LoadableListViewEnvironmentFor<Element, Request, Failure>
  ) -> Reducer where Failure: Equatable {
    .combine(
      Reducer<
        LoadableListViewState<Element, Failure>,
        LoadableListViewAction<Element, Failure>,
        LoadableListViewEnvironment<Element, Request, Failure>
      >.empty
        .loadableList(state: \.self, action: /LoadableListViewAction.self)
        .loadable(
          state: \.loadable,
          action: /LoadableListViewAction.load,
          environment: { $0 }
        )
        .pullback(state: state, action: action, environment: environment),
      self
    )
  }
}

// MARK: - View
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct LoadableListView<
  Element: Equatable,
  Id: Hashable,
  Failure: Error,
  Row: View
>: View where Failure: Equatable {
  
  public let store: Store<LoadableListViewStateFor<Element, Failure>, LoadableListViewActionFor<Element, Failure>>
  
  let autoLoad: Bool
  let id: KeyPath<Element, Id>
  let row: (Element) -> Row
  
  public init(
    store: Store<LoadableListViewStateFor<Element, Failure>, LoadableListViewActionFor<Element, Failure>>,
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
    WithViewStore(store) { viewStore in
      LoadableView(
        store: store.scope(state: \.loadable),
        autoLoad: autoLoad,
        onLoad: .load(.load)
      ) { store in
        WithViewStore(store) { loadedViewStore in
          List {
            ForEach(loadedViewStore.state, id: id) {
              row($0)
            }
            .onDelete { loadedViewStore.send(.list(.delete($0))) }
            .onMove { loadedViewStore.send(.list(.move($0, $1))) }
          }
        }
      }
      .editMode(
        store.scope(state: \.editMode, action: LoadableListViewAction.editMode)
      )
    }
  }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension LoadableListView where Element: Identifiable, Id == Element.ID {
  public init(
    store: Store<LoadableListViewStateFor<Element, Failure>, LoadableListViewActionFor<Element, Failure>>,
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

// MARK: - Preview
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

  extension LoadableListViewEnvironment where Element == User, LoadRequest == EmptyLoadRequest, Failure == LoadError {
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
    LoadableListViewStateFor<User, LoadError>,
    LoadableListViewActionFor<User, LoadError>,
    LoadableListViewEnvironmentFor<User, EmptyLoadRequest, LoadError>
  >.empty
    .loadableList(
      state: \.self,
      action: /LoadableListViewAction<User, LoadError>.self,
      environment: { $0 }
    )

  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  struct LoadableListViewPreviewWithEditModeButton: View {
    let store: Store<LoadableListViewStateFor<User, LoadError>, LoadableListViewActionFor<User, LoadError>>

    var body: some View {
      NavigationView {
        LoadableListView(store: store, autoLoad: true) { user in
          Text(user.name)
        }
        .toolbar {
          ToolbarItemGroup(placement: .confirmationAction) {
            EditButton(
              store: store.scope(state: \.editMode, action: LoadableListViewAction.editMode)
            )
          }
        }
      }
    }
  }

  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  struct LoadableListView_Previews: PreviewProvider {
    static var previews: some View {
      LoadableListViewPreviewWithEditModeButton(
        store: .init(
          initialState: .init(),
          reducer: usersReducer,
          environment: .users
        )
      )
    }
  }
#endif
