# Biskit (Biscuit)

[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-brightgreen.svg?style=flat)](https://swift.org/package-manager)
[![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-blue.svg?style=flat)]()
[![License](https://img.shields.io/badge/License-MIT-black.svg?style=flat)]()

**Biskit** makes unidirectional data flow simple and predictable through a lightweight pipeline.

* **Inspired by TCA (The Composable Architecture):** Embraces modern concurrency guidelines and explicit, predictable data flow.
* **Driven like ReactorKit:** Inherits a straightforward, boilerplate-free pipeline design.

It serves as the perfect alternative if you find TCA's steep learning curve and massive boilerplate overwhelming, yet wish ReactorKit natively integrated with Swift Concurrency (`async/await`). Just like a biscuit, it's light, sweet, and incredibly easy to digest into your project!

---

## Core Components

Biskit structures your architecture into 4 simple, well-defined components:

* **Intent:** Represents any user action or system event originating from the View (e.g., button taps, screen appearances). 
* **Mutation:** Synchronous, pure data models that describe *how* the State should change. The `mutate` function processes Intents into a stream of Mutations.
* **Effect:** Dedicated channel for one-off side-effects that do not persistently alter the State—such as screen navigation, native alerts, toast overlays, or haptic feedback.
* **State:** A single source of truth representing what the View needs to render. It can only be modified via `reduce` and conforms to `Equatable` to prevent redundant redrawing.

---

## Quick Guide

Define your components to manage data flow predictably.

```swift
import SwiftUI
import Combine
import Biskit

// 1. Define UDF Components
enum ProfileIntent: Equatable {
    case fetchUser
    case refreshTapped
}

enum ProfileMutation {
    case setUserName(String)
    case setLoading(Bool)
}

enum ProfileEffect {
    case showErrorToast(String)
}

struct ProfileState: Equatable {
    var userName: String = "Guest"
    var isLoading: Bool = false
}

// 2. Create a Store
final class ProfileStore: BaseViewStore<ProfileIntent, ProfileEffect, ProfileMutation, ProfileState> {
    
    override func mutate(intent: ProfileIntent) -> AnyPublisher<ProfileMutation, Never> {
        switch intent {
        case .fetchUser, .refreshTapped:
            let startLoading = Just(ProfileMutation.setLoading(true)).eraseToAnyPublisher()
            let endLoading = Just(ProfileMutation.setLoading(false)).eraseToAnyPublisher()
            
            let fetchTask = performTask(
                taskID: "fetchUser", 
                fallbackValue: nil,
                catchHandler: { [weak self] error in
                    self?.effectSubject.send(.showErrorToast(error.localizedDescription))
                }
            ) {
                let user = try await Network.fetchUser() 
                return .setUserName(user.name)
            }
            
            return startLoading
                .append(fetchTask)
                .append(endLoading)
                .eraseToAnyPublisher()
        }
    }
    
    override func reduce(state: ProfileState, mutation: ProfileMutation) -> ProfileState {
        var newState = state
        switch mutation {
        case .setUserName(let name):
            newState.userName = name
        case .setLoading(let isLoading):
            newState.isLoading = isLoading
        }
        return newState
    }
}

// 3. Connect to View with WithViewStore & Handle Effects
struct ProfileView: View {
    @StateObject private var store = ProfileStore(initialState: ProfileState())
    @State private var isHovered = false // You can put it in the State, or you can also place it here.
    
    var body: some View {
        WithViewStore(store, observe: { $0.userName }) { userName in
            VStack {
                Text("Hello, \(userName)")
                    .foregroundColor(isHovered ? .blue : .black)
                
                Button("Refresh") {
                    store.send(.refreshTapped)
                }
            }
        }
        .onReceive(store.effectStream) { effect in
            switch effect {
            case .showErrorToast(let message):
                // do something
            }
        }
    }
}
```

---

## Advanced Usage

### The Power of `performTask`
Handling `async/await` within Combine pipelines can be tricky. Biskit provides `performTask` out-of-the-box to make asynchronous network calls and heavy background tasks incredibly safe and boilerplate-free:

- **Automatic Task Cancellation (`taskID`):** If a new intent triggers a task with an identical `taskID` while the previous one is still running, Biskit automatically cancels the old task. This perfectly prevents race conditions from rapid button taps without needing complex Combine operators.
- **Smart Retry Mechanism (`retryCount` & `retryDelay`):** Easily configure how many times a failing task should be retried before throwing an error. You can also inject a delay (in seconds) between retry attempts to gracefully handle unstable network conditions.
- **Isolated Error Handling (`catchHandler`):** Intercept errors immediately within the task. You can trigger an `Effect` (like presenting a native Alert or Toast) safely without polluting your pure state mutations.
- **Guaranteed Stream Safety (`fallbackValue`):** If a network request completely fails even after retries, the `fallbackValue` ensures your Combine pipeline never breaks, allowing the stream to continue gracefully.

```swift
let fetchTask = performTask(
    taskID: "fetch_user_task", // Auto-cancels previous ongoing tasks with this ID
    retryCount: 3,             // Automatically retries up to 3 times on failure
    retryDelay: 1.0,           // Waits 1 second between retry attempts
    fallbackValue: nil,        // Failsafe mutation if an error is thrown
    catchHandler: { [weak self] error in
        // Easily route errors to one-off Effects
        self?.effectSubject.send(.showErrorToast(error.localizedDescription))
    }
) {
    // Pure async/await logic here
    let user = try await Network.fetchUser() 
    return .setUserName(user.name)
}
```

### Transforming Streams (`transform`)
Just like ReactorKit, Biskit allows you to intercept and modify the reactive streams at two different stages: **Intent** and **Mutation**.

#### 1. `transform(intent:)`
Use this to manipulate the incoming stream of user intents before they trigger `mutate()`. It is the perfect place to apply operators like `throttle` or `debounce` to specific user actions (e.g., preventing double taps) while letting other intents pass through normally.

```swift
override func transform(intent: AnyPublisher<ProfileIntent, Never>) -> AnyPublisher<ProfileIntent, Never> {
    
    // Apply throttle to prevent double taps on refresh
    let throttledRefresh = intent
        .filter { $0 == .refreshTapped }
        .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: false)
    
    // Pass through all other intents normally
    let otherIntents = intent
        .filter { $0 != .refreshTapped }
    
    // Combine everything back into a single Intent stream
    return Publishers.Merge(otherIntents, throttledRefresh)
        .eraseToAnyPublisher()
}
```

#### 2. `transform(mutation:)`
Use this to intercept the stream of mutations *after* `mutate()` but *before* they reach `reduce()`. This is highly useful for merging **external events** (like `NotificationCenter` or Socket streams) directly into the state flow, or for global tasks like logging.

```swift
override func transform(mutation: AnyPublisher<ProfileMutation, Never>) -> AnyPublisher<ProfileMutation, Never> {
    
    // Merge external events directly into the Mutation stream
    let externalUpdate = NotificationCenter.default.publisher(for: .didUpdateProfile)
        .compactMap { $0.object as? String }
        .map { ProfileMutation.setUserName($0) }
    
    return Publishers.Merge(mutation, externalUpdate)
        .handleEvents(receiveOutput: { mutation in
            // Log every mutation globally
            print("Mutation triggered: \(mutation)")
        })
        .eraseToAnyPublisher()
}
```

### Handling One-off Events (Effects)
Unlike a `Mutation` which always mutates the state permanently through `reduce`, an `Effect` represents a transient event. 

Common use cases for `Effect` include:
* Presenting a native `Alert` or a HUD `Toast`
* Haptic feedback triggers (`UIImpactFeedbackGenerator`)
* Triggering a navigation push/present that shouldn't be bound to a persistent state

Inside `mutate(intent:)`, simply call `effectSubject.send(.yourEffect)` whenever a side-effect needs to occur. In your View, use `.onReceive(store.effectStream)` to listen and react to these events seamlessly.

### `@DiffIgnored`
If you have a state property that updates frequently but shouldn't trigger a view redraw (e.g., internal cache, scroll offset), simply wrap it with `@DiffIgnored`.

```swift
struct MyState: Equatable {
    var title: String
    
    @DiffIgnored
    var internalCache: [String: Any] = [:] 
    // Changes to internalCache will bypass Equatable check and prevent unnecessary rendering.
}
```

---

## Requirements

- iOS 14.0+ / macOS 11.0+
- Swift 5.5+ (Swift Concurrency support)

---

## Installation

### Swift Package Manager (SPM)

Biskit is available through Swift Package Manager. 
To install it, simply add the following line to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "[https://github.com/lyfeoncloudnine/Biskit.git](https://github.com/lyfeoncloudnine/Biskit.git)", .upToNextMajor(from: "1.0.0"))
]
```

---

## Author

lyfeoncloudnine, lyfeoncloudnine@gmail.com

---

## License

Biskit is available under the MIT license. See the LICENSE file for more info.