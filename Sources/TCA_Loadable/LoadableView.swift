//
//  LoadableView.swift
//  
//
//  Created by Michael on 10/10/20.
//

import SwiftUI
import Combine
import ComposableArchitecture

public struct LoadableView<LoadedValue: Equatable, NotLoadedView: View, LoadedView: View, ErrorView: View, IsLoadingView: View>: View {
    
    public let store: Store<Loadable<LoadedValue>, LoadableAction<LoadedValue>>
    let notLoadedView: () -> NotLoadedView
    let loadedView: (LoadedValue) -> LoadedView
    let isLoadingView: (LoadedValue?) -> IsLoadingView
    let errorView: (Error) -> ErrorView
    
    public init(
        store: Store<Loadable<LoadedValue>, LoadableAction<LoadedValue>>,
        @ViewBuilder loadedView: @escaping (LoadedValue) -> LoadedView,
        @ViewBuilder notLoadedView: @escaping () -> NotLoadedView,
        @ViewBuilder isLoadingView: @escaping (LoadedValue?) -> IsLoadingView,
        @ViewBuilder errorView: @escaping (Error) -> ErrorView
    ) {
        self.store = store
        self.notLoadedView = notLoadedView
        self.errorView = errorView
        self.isLoadingView = isLoadingView
        self.loadedView = loadedView
    }
    
    public var body: some View {
        WithViewStore(store) { viewStore  in
            switch viewStore.state {
            case .notRequested:
                notLoadedView()
            case let .isLoading(previous):
                isLoadingView(previous)
            case let .failed(error):
                errorView(error)
            case let .loaded(value):
                loadedView(value)
            }
        }
    }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct LoadableProgressView<LoadedValue: Equatable, LoadedView: View, ErrorView: View>: View {
    
    public let store: Store<Loadable<LoadedValue>, LoadableAction<LoadedValue>>
    let loadedView: (LoadedValue) -> LoadedView
    let errorView: (Error) -> ErrorView
    
    public init(
        store: Store<Loadable<LoadedValue>, LoadableAction<LoadedValue>>,
        @ViewBuilder loadedView: @escaping (LoadedValue) -> LoadedView,
        @ViewBuilder errorView: @escaping (Error) -> ErrorView
    ) {
        self.store = store
        self.loadedView = loadedView
        self.errorView = errorView
    }
    
    public var body: some View {
        WithViewStore(store) { viewStore in
            LoadableView(store: store) { loaded in
                loadedView(loaded)
            }
            notLoadedView: {
                ProgressView()
                    .onAppear { viewStore.send(.load) }
            }
            isLoadingView: { previous in
                switch previous {
                case .none:
                    ProgressView("Loading")
                case let .some(item):
                    VStack {
                        ProgressView()
                        loadedView(item)
                    }
                }
            }
            errorView: { errorView($0) }
        }
    }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
struct LoadableView_Previews: PreviewProvider {
    
    struct PreviewEnvironment: LoadableEnvironment {
        typealias Item = Int
        
        func load() -> Effect<Int, Error> {
            Just(1)
                .delay(for: .seconds(1), scheduler: DispatchQueue.main)
                .setFailureType(to: Error.self)
                .eraseToEffect()
                
        }
    }
    
    static let previewReducer = Reducer<Loadable<Int>, LoadableAction<Int>, PreviewEnvironment>.empty
        .loadable(
            state: \.self,
            action: /LoadableAction.self,
            environment: { $0 }
        )
    
    static var previews: some View {
        Group {
            LoadableProgressView(
                store: Store(
                    initialState: Loadable<Int>.notRequested,
                    reducer: previewReducer,
                    environment: PreviewEnvironment()
                )
            ) {
                Text("\($0)")
            } errorView: {
                Text($0.localizedDescription)
            }
        }
    }
}
