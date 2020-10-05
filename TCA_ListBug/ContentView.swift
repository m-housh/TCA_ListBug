//
//  ContentView.swift
//  TCA_ListBug
//
//  Created by Michael on 10/2/20.
//

import SwiftUI
import ComposableArchitecture
import Combine

struct Model: Identifiable, Equatable {
    var id: UUID
    var name: String
}

extension Array where Element == Model {
    static let mocks: Self = [
        Model(id: UUID(), name: "Foo"),
        Model(id: UUID(), name: "Bar"),
        Model(id: UUID(), name: "Baz"),
        Model(id: UUID(), name: "Bing"),
        Model(id: UUID(), name: "Bang")
    ]
}

enum Loadable<T> {
    case notRequested
    case isLoading(last: T?)
    case loaded(T)
    case failed(Error)
    
    var value: T? {
        switch self {
        case let .isLoading(last: last): return last
        case let .loaded(value): return value
        default: return nil
        }
    }
    
    var error: Error? {
        switch self {
        case let .failed(error): return error
        default: return nil
        }
    }
}

extension Loadable: Equatable where T: Equatable {
    static func == (lhs: Loadable<T>, rhs: Loadable<T>) -> Bool {
        switch (lhs, rhs) {
        case (.notRequested, .notRequested): return true
        case let (.isLoading(lhsV), .isLoading(rhsV)): return lhsV == rhsV
        case let (.loaded(lhsV), .loaded(rhsV)): return lhsV == rhsV
        case let (.failed(lhsE), .failed(rhsE)): return lhsE.localizedDescription == rhsE.localizedDescription
        default: return false
        }
    }
}

struct AppState: Equatable {
    var models: Loadable<[Model]> = .notRequested
}

enum AppAction: Equatable {
    
    case row(RowAction)
    case repository(RepositoryAction)
    
    enum RowAction: Equatable {
        case move(source: IndexSet, to: Int)
        case delete(source: IndexSet)
    }
    
    enum RepositoryAction {
        case load
        case loadingComplete(Result<[Model], Error>)
    }
}

extension AppAction.RepositoryAction: Equatable {
    static func == (lhs: AppAction.RepositoryAction, rhs: AppAction.RepositoryAction) -> Bool {
        switch (lhs, rhs) {
        case (.load, .load): return true
        case let (.loadingComplete(.success(lhsV)), .loadingComplete(.success(rhsV))):
            return lhsV == rhsV
        case let (.loadingComplete(.failure(lhsE)), .loadingComplete(.failure(rhsE))):
            return lhsE.localizedDescription == rhsE.localizedDescription
        default: return false
        }
    }
}

extension Reducer where State == AppState, Action == AppAction, Environment == Void {
    
    static let appReducer = Self { state, action, _ in
        switch action {
        case let .row(.move(source: fromOffsets, to: destination)):
            guard var current = state.models.value else { return .none }
            current.move(fromOffsets: fromOffsets, toOffset: destination)
            state.models = .loaded(current)
            return .none
            
        case let .row(.delete(source: indexes)):
            guard var current = state.models.value else { return .none }
            for index in indexes {
                current.remove(at: index)
            }
            state.models = .loaded(current)
            return .none
            
        case .repository(.load):
            return Just([Model].mocks)
                .setFailureType(to: Error.self)
                .delay(for: .seconds(2), scheduler: DispatchQueue.main)
                .catchToEffect()
                .map { AppAction.repository(.loadingComplete($0)) }
            
        case let .repository(.loadingComplete(.success(models))):
            state.models = .loaded(models)
            return .none
            
        case let .repository(.loadingComplete(.failure(error))):
            state.models = .failed(error)
            return .none
        }
    }
}

struct ContentView: View {
    
    let store: Store<AppState, AppAction>
    
    var body: some View {
        WithViewStore(store) { viewStore in
            switch viewStore.models {
            case .notRequested:
                notRequestedView
            case let .isLoading(previous):
                isLoadingView(previouslyLoaded: previous)
            case let .failed(error):
                errorView(error: error)
            case let .loaded(models):
                loadedView(models)
            }
        }
    }
    
    var notRequestedView: some View {
        WithViewStore(store) { viewStore in
            ProgressView()
                .onAppear { viewStore.send(.repository(.load)) }
        }
    }
    
    func errorView(error: Error) -> some View {
        Text(error.localizedDescription)
    }
    
    func loadedView(_ models: [Model], showProgressView: Bool = false) -> some View {
        VStack {
            if showProgressView {
                ProgressView()
            }
            List {
                WithViewStore(store) { viewStore in
                    ForEach(models) { model in
                        Text(model.name)
                    }
                    .onMove { viewStore.send(.row(.move(source: $0, to: $1))) }
                    .onDelete { viewStore.send(.row(.delete(source: $0))) }

                }
            }
        }
    }
    
    @ViewBuilder func isLoadingView(previouslyLoaded: [Model]?) -> some View {
        switch previouslyLoaded {
        case .none:
            notRequestedView
        case let .some(previous):
            loadedView(previous, showProgressView: true)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(
            store: Store(
                initialState: AppState(models: .loaded(.mocks)),
                reducer: .appReducer,
                environment: ()
            )
        )
    }
}
