import ComposableArchitecture
import SwiftUI
import TCALoadable

//public struct TCAViewEnvironment {
//  public init() { }
//}

//public struct TCAViewState: Equatable {
//
//}

public enum LoadableListAction: Equatable {
  
  case list(ListAction)
  
  public enum ListAction: Equatable {
    case delete(IndexSet)
    case move(IndexSet, Int)
  }
}

//public let reducer = Reducer<
//  TCAViewState,
//  TCAViewAction,
//  TCAViewEnvironment
//> { state, action, environment in
//  switch action {
//
//  }
//}

//public struct TCAView: View {
//  let store: Store<TCAViewState, TCAViewAction>
//
//  public init(store: Store<TCAViewState, TCAViewAction>) {
//    self.store = store
//  }
//
//  public var body: some View {
//    WithViewStore(store) { viewStore in
//      Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
//    }
//  }
//}

#if DEBUG
//  struct TCAView_Previews: PreviewProvider {
//    static var previews: some View {
//      TCAView(
//        store: .init(
//          initialState: .init(),
//          reducer: reducer,
//          environment: .init()
//        )
//      )
//    }
//  }
#endif
