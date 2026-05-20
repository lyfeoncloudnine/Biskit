//
//  File.swift
//  Biskit
//
//  Created by lyfeoncloudnine on 5/21/26.
//

import SwiftUI

@MainActor
public struct WithViewStore<Intent, Mutation, Effect, State: Equatable, Content: View>: View {
    @ObservedObject private var store: BaseViewStore<Intent, Mutation, Effect, State>
    
    private let content: (State) -> Content
    
    public init(_ store: BaseViewStore<Intent, Mutation, Effect, State>, @ViewBuilder content: @escaping (State) -> Content) {
        self.store = store
        self.content = content
    }
    
    public var body: some View {
        content(store.currentState)
    }
}
