import Combine
import Testing
@testable import Biskit

enum TestIntent {
    case fetchUser(delay: Double, resultText: String)
}

enum TestMutation {
    case setLoading(Bool)
    case updateText(String)
}

struct TestState: Equatable {
    var text: String = ""
    var isLoading: Bool = false
}

@MainActor
final class TestStore: BaseViewStore<TestIntent, TestMutation, Void, TestState> {
    override func mutate(intent: TestIntent) -> AnyPublisher<TestMutation, Never> {
        switch intent {
        case let .fetchUser(delay, resultText):
            let startLoading = Just(TestMutation.setLoading(true)).eraseToAnyPublisher()
            
            let fetchTask = performTask(taskID: "fetch_user_task", fallbackValue: nil) {
                // iOS 14.0 호환을 위해 nanoseconds로 변경
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return .updateText(resultText)
            }
            
            let endLoading = Just(TestMutation.setLoading(false)).eraseToAnyPublisher()
            
            return startLoading
                .append(fetchTask)
                .append(endLoading)
                .eraseToAnyPublisher()
        }
    }
    
    override func reduce(state: TestState, mutation: TestMutation) -> TestState {
        var newState = state
        
        switch mutation {
        case .setLoading(let isLoading):
            newState.isLoading = isLoading
        case .updateText(let text):
            newState.text = text
        }
        
        return newState
    }
}

@Suite("Biskit 데이터 흐름 통합 테스트")
@MainActor
struct BiskitIntegrationTests {
    
    @Test("Intent가 전송되면 상류 스트림의 주입 순서에 따라 isLoading 상태를 거쳐 최종 상태로 올바르게 업데이트된다")
    func testIntentTriggersSequentialStateUpdates() async {
        let store = TestStore(initialState: TestState())
        
        #expect(store.currentState.text == "")
        #expect(store.currentState.isLoading == false)
        
        store.send(.fetchUser(delay: 0.1, resultText: "Lyfe"))
        await Task.yield()
        
        #expect(store.currentState.isLoading == true)
        
        // iOS 14.0 호환을 위해 nanoseconds로 변경
        try? await Task.sleep(nanoseconds: UInt64(0.2 * 1_000_000_000))
        
        #expect(store.currentState.isLoading == false)
        #expect(store.currentState.text == "Lyfe")
    }

    @Test("동일한 taskID를 가진 Intent가 진행 중에 다시 전송되면, 이전 작업은 취소되어 무시되고 마지막 Intent의 결과만 최종 반영된다")
    func testDuplicateIntentCancelsPreviousTaskAndEmitsLatestResultOnly() async {
        let store = TestStore(initialState: TestState())
        
        store.send(.fetchUser(delay: 0.3, resultText: "First Result"))
        await Task.yield()
        #expect(store.currentState.isLoading == true)
        
        // iOS 14.0 호환을 위해 nanoseconds로 변경
        try? await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
        
        store.send(.fetchUser(delay: 0.1, resultText: "Second Result"))
        
        // iOS 14.0 호환을 위해 nanoseconds로 변경
        try? await Task.sleep(nanoseconds: UInt64(0.4 * 1_000_000_000))
        
        #expect(store.currentState.isLoading == false)
        #expect(store.currentState.text == "Second Result")
    }
}
