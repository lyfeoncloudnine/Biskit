//
//  File.swift
//  Biskit
//
//  Created by lyfeoncloudnine on 5/21/26.
//

import SwiftUI

/// `BaseViewStore`의 전체 상태(State) 중 뷰를 그리는 데 필요한 특정 부분(ViewState)만
/// 관찰하여 화면을 렌더링하는 컨테이너 뷰입니다.
///
/// 전체 상태가 변경되더라도, `observe` 클로저를 통해 추출된 `ViewState`를 기반으로 뷰를 구성합니다.
public struct WithViewStore<Intent, Mutation, Effect, State: Equatable, ViewState: Equatable, Content: View>: View {
    @ObservedObject private var store: BaseViewStore<Intent, Mutation, Effect, State>
    
    private let observe: (State) -> ViewState
    private let content: (ViewState) -> Content
    
    public init(
        _ store: BaseViewStore<Intent, Mutation, Effect, State>,
        observe: @escaping (State) -> ViewState,
        @ViewBuilder content: @escaping (ViewState) -> Content
    ) {
        self.store = store
        self.observe = observe
        self.content = content
    }
    
    public var body: some View {
        content(observe(store.currentState))
    }
}
