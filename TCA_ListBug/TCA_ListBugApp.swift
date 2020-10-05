//
//  TCA_ListBugApp.swift
//  TCA_ListBug
//
//  Created by Michael on 10/2/20.
//

import SwiftUI
import ComposableArchitecture

@main
struct TCA_ListBugApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(
                store: Store(
                    initialState: AppState(),
                    reducer: Reducer.appReducer.debug(),
                    environment: ()
                )
            )
            .frame(minWidth: 300, minHeight: 300)
        }
    }
}
