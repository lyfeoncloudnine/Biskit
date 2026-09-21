//
//  ScopedViewStore.swift
//  Biskit
//
//  Created by lyfeoncloudnine on 9/22/26.
//

import SwiftUI

public struct ScopedContent<ViewState: Equatable, Content: View>: View, @MainActor Equatable {
    fileprivate let viewState: ViewState
    fileprivate let content: (ViewState) -> Content
    
    public var body: some View {
        content(viewState)
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.viewState == rhs.viewState
    }
}

@MainActor
public func withScopedViewStore<Intent, Mutation, Effect, StoreState: Equatable, ViewState: Equatable, Content: View>(
    _ store: BaseViewStore<Intent, Mutation, Effect, StoreState>,
    observe: @escaping (StoreState) -> ViewState,
    @ViewBuilder content: @escaping (ViewState) -> Content
) -> EquatableView<ScopedContent<ViewState, Content>> {
    ScopedContent(viewState: observe(store.currentState), content: content).equatable()
}

@MainActor
public func withScopedViewStore<Intent, Mutation, Effect, StoreState: Equatable, A: Equatable, B: Equatable, Content: View>(
    _ store: BaseViewStore<Intent, Mutation, Effect, StoreState>,
    observe keyPaths: (KeyPath<StoreState, A>, KeyPath<StoreState, B>),
    @ViewBuilder content: @escaping (A, B) -> Content
) -> EquatableView<ScopedContent<ScopedPair<A, B>, Content>> {
    withScopedViewStore(
        store,
        observe: { state in ScopedPair(first: state[keyPath: keyPaths.0], second: state[keyPath: keyPaths.1]) },
        content: { pair in content(pair.first, pair.second) }
    )
}

@MainActor
public func withScopedViewStore<Intent, Mutation, Effect, StoreState: Equatable, A: Equatable, B: Equatable, C: Equatable, Content: View>(
    _ store: BaseViewStore<Intent, Mutation, Effect, StoreState>,
    observe keyPaths: (KeyPath<StoreState, A>, KeyPath<StoreState, B>, KeyPath<StoreState, C>),
    @ViewBuilder content: @escaping (A, B, C) -> Content
) -> EquatableView<ScopedContent<ScopedTriple<A, B, C>, Content>> {
    withScopedViewStore(
        store,
        observe: { state in
            ScopedTriple(
                first: state[keyPath: keyPaths.0],
                second: state[keyPath: keyPaths.1],
                third: state[keyPath: keyPaths.2]
            )
        },
        content: { triple in content(triple.first, triple.second, triple.third) }
    )
}

@MainActor
public func withScopedViewStore<
    Intent, Mutation, Effect, StoreState: Equatable, A: Equatable, B: Equatable, C: Equatable, D: Equatable, Content: View>(
    _ store: BaseViewStore<Intent, Mutation, Effect, StoreState>,
    observe keyPaths: (
        KeyPath<StoreState, A>, KeyPath<StoreState, B>, KeyPath<StoreState, C>, KeyPath<StoreState, D>
    ),
    @ViewBuilder content: @escaping (A, B, C, D) -> Content
) -> EquatableView<ScopedContent<ScopedQuad<A, B, C, D>, Content>> {
    withScopedViewStore(
        store,
        observe: { state in
            ScopedQuad(
                first: state[keyPath: keyPaths.0],
                second: state[keyPath: keyPaths.1],
                third: state[keyPath: keyPaths.2],
                fourth: state[keyPath: keyPaths.3]
            )
        },
        content: { quad in content(quad.first, quad.second, quad.third, quad.fourth) }
    )
}

@MainActor
public func withScopedViewStore<
    Intent, Mutation, Effect, StoreState: Equatable,
    A: Equatable, B: Equatable, C: Equatable, D: Equatable, E: Equatable, Content: View>(
    _ store: BaseViewStore<Intent, Mutation, Effect, StoreState>,
    observe keyPaths: (
        KeyPath<StoreState, A>,
        KeyPath<StoreState, B>,
        KeyPath<StoreState, C>,
        KeyPath<StoreState, D>,
        KeyPath<StoreState, E>
    ),
    @ViewBuilder content: @escaping (A, B, C, D, E) -> Content
) -> EquatableView<ScopedContent<ScopedQuint<A, B, C, D, E>, Content>> {
    withScopedViewStore(
        store,
        observe: { state in
            ScopedQuint(
                first: state[keyPath: keyPaths.0],
                second: state[keyPath: keyPaths.1],
                third: state[keyPath: keyPaths.2],
                fourth: state[keyPath: keyPaths.3],
                fifth: state[keyPath: keyPaths.4]
            )
        },
        content: { quint in content(quint.first, quint.second, quint.third, quint.fourth, quint.fifth) }
    )
}

public struct ScopedPair<A: Equatable, B: Equatable>: Equatable {
    public let first: A
    public let second: B
}

public struct ScopedTriple<A: Equatable, B: Equatable, C: Equatable>: Equatable {
    public let first: A
    public let second: B
    public let third: C
}

public struct ScopedQuad<A: Equatable, B: Equatable, C: Equatable, D: Equatable>: Equatable {
    public let first: A
    public let second: B
    public let third: C
    public let fourth: D
}

public struct ScopedQuint<A: Equatable, B: Equatable, C: Equatable, D: Equatable, E: Equatable>: Equatable {
    public let first: A
    public let second: B
    public let third: C
    public let fourth: D
    public let fifth: E
}
