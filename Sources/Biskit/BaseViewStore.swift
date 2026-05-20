//
//  BaseViewStore.swift
//  Biskit
//
//  Created by lyfeoncloudnine on 5/20/26.
//

import Combine
import Foundation

@MainActor
open class BaseViewStore<Intent, Mutation, Effect, State: Equatable>: ObservableObject {
    private var state: State {
        willSet {
            guard state != newValue else { return }
            objectWillChange.send()
        }
    }
    public var currentState: State {
        state
    }
    
    private let intentSubject = PassthroughSubject<Intent, Never>()
    
    public let effectSubject = PassthroughSubject<Effect, Never>()
    public var effectStream: AnyPublisher<Effect, Never> {
        effectSubject.eraseToAnyPublisher()
    }
    
    public private(set) var cancelBag = Set<AnyCancellable>()
    public private(set) var tasks = [String: AnyCancellable]()
    
    public init(initialState: State) {
        self.state = initialState
        self.setupTransform()
    }
    
    public func send(_ intent: Intent) {
        intentSubject.send(intent)
    }
    
    private func setupTransform() {
        let mutationFromIntent = transform(intent: intentSubject.eraseToAnyPublisher())
            .flatMap { [weak self] intent -> AnyPublisher<Mutation, Never> in
                guard let self else { return Empty().eraseToAnyPublisher() }
                return mutate(intent: intent)
            }
            .eraseToAnyPublisher()
        transform(mutation: mutationFromIntent)
            .receive(on: DispatchQueue.main)
            .scan(state) { [weak self] prevState, mutation in
                guard let self else { return prevState }
                return reduce(state: prevState, mutation: mutation)
            }
            .sink { [weak self] newState in
                self?.state = newState
            }
            .store(in: &cancelBag)
    }
    
    open func transform(intent: AnyPublisher<Intent, Never>) -> AnyPublisher<Intent, Never> {
        intent
    }
    
    open func transform(mutation: AnyPublisher<Mutation, Never>) -> AnyPublisher<Mutation, Never> {
        mutation
    }
    
    open func mutate(intent: Intent) -> AnyPublisher<Mutation, Never> {
        fatalError("mutate(intent:) must be implemented by subclass")
    }
    
    open func reduce(state: State, mutation: Mutation) -> State {
        fatalError("reduce(state:mutation:) must be implemented by subclass")
    }
}

extension BaseViewStore {
    /// 비동기 작업(async/await)을 수행하고 결과를 Combine 파이프라인(Mutation)으로 연결하는 헬퍼 메서드입니다.
    ///
    /// 동일한 `taskID`로 새로운 작업이 요청되면 이전에 실행 중이던 작업은 자동으로 취소(Cancel)됩니다.
    /// 이를 통해 중복 네트워크 요청을 방지하거나 디바운스(Debounce) 효과를 자연스럽게 구현할 수 있습니다.
    ///
    /// - parameters:
    ///   - taskID: 작업의 고유 식별자. 기본값은 호출된 함수명(`#function`)입니다. 동일한 ID로 호출 시 이전 작업은 즉시 취소됩니다.
    ///   - fallbackValue: 작업 실패 혹은 취소 시 방출할 `Mutation`. `nil`을 전달할 경우 아무 상태도 방출하지 않고 스트림에서 완전히 무시됩니다.
    ///   - retryCount: 에러 발생 시 작업을 재시도할 최대 횟수. (기본값: 0)
    ///   - retryDelay: 재시도 간 대기할 시간(초 단위). (기본값: 0)
    ///   - catchHandler: 최종 실패 시 에러를 로깅하거나 외부 부수 효과(Side-effect)를 처리하기 위한 클로저.
    ///   - operation: 실제 수행할 비동기(`async throws`) 작업 클로저. 성공 시 상태를 변경할 `Mutation`을 반환해야 합니다.
    ///
    /// - returns: 비동기 작업의 성공 결과 또는 `fallbackValue`를 방출하며, 에러를 내뿜지 않는(`Never`) `AnyPublisher<Mutation, Never>` 타입의 스트림
    public final func performTask(
        taskID: String = #function,
        fallbackValue: Mutation? = nil,
        retryCount: Int = 0,
        retryDelay: TimeInterval = 0,
        catchHandler: ((Error) -> Void)? = nil,
        operation: @escaping () async throws -> Mutation
    ) -> AnyPublisher<Mutation, Never> {
        var currentAttemptCount = 0
        return Deferred {
            Future<Mutation?, Error> { [weak self] promise in
                guard let self else {
                    promise(.success(fallbackValue))
                    return
                }
                
                currentAttemptCount += 1
                let task = Task {
                    do {
                        let result = try await operation()
                        try Task.checkCancellation()
                        promise(.success(result))
                    } catch {
                        guard !(error is CancellationError) && !Task.isCancelled else {
                            promise(.success(fallbackValue))
                            return
                        }
                        
                        if currentAttemptCount <= retryCount, retryDelay > 0 {
                            try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                            guard !Task.isCancelled else {
                                promise(.success(fallbackValue))
                                return
                            }
                        }
                        promise(.failure(error))
                    }
                }
                self.tasks[taskID] = AnyCancellable { task.cancel() }
            }
        }
        .retry(retryCount)
        .catch { error in
            catchHandler?(error)
            return Just(fallbackValue)
        }
        .compactMap { $0 }
        .eraseToAnyPublisher()
    }
}
