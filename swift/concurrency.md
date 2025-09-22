# Swift 6 Concurrency: Complete Guide to Data Race Safety and Strict Concurrency

## Table of Contents

1. [Introduction](#introduction)
2. [Core Concepts](#core-concepts)
3. [Swift Evolution Proposals](#swift-evolution-proposals)
4. [Data Race Safety](#data-race-safety)
5. [Actor System](#actor-system)
6. [Sendable Protocol](#sendable-protocol)
7. [Migration Guide](#migration-guide)
8. [Code Examples](#code-examples)
9. [Best Practices](#best-practices)
10. [Testing and Debugging](#testing-and-debugging)
11. [Common Compiler Errors](#common-compiler-errors)
12. [Performance Tuning](#performance-tuning)
13. [Swift 6.1+ Roadmap](#swift-61-roadmap)
14. [Resources](#resources)

## Introduction

Swift 6 represents a revolutionary leap in concurrent programming, introducing compile-time data race safety that eliminates an entire class of bugs. This comprehensive guide covers all Swift Evolution proposals, practical examples, and migration strategies for adopting Swift 6's strict concurrency model.

### Quick Start: Enable Strict Concurrency

**Xcode:**
```
Build Settings → Swift Compiler - Language → Strict Concurrency Checking → Complete
```

**Command Line:**
```bash
swiftc -strict-concurrency=complete -swift-version 6 MyFile.swift
```

**Package.swift:**
```swift
.target(
    name: "MyTarget",
    swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
        .swiftLanguageMode(.v6)  // or stay on .v5 with warnings
    ]
)
```

### What is Swift 6 Concurrency?

Swift 6's concurrency model builds upon Swift 5.5's async/await foundation with:
- **Complete data race safety** at compile time
- **Actor isolation** enforcement
- **Sendable protocol** requirements
- **Region-based isolation** for smarter type checking
- **Improved ergonomics** reducing false positives

### Key Benefits

1. **Compile-time Safety**: Catch data races before runtime
2. **Progressive Migration**: Adopt incrementally with warnings first
3. **Better Performance**: Compiler optimizations enabled by isolation guarantees
4. **Clearer Intent**: Explicit concurrency boundaries in code

## Core Concepts

### 1. Isolation Domains

Swift 6 defines clear isolation domains where data can be safely accessed:

```swift
// MainActor isolation domain - UI code
@MainActor
class ViewController: UIViewController {
    var label = UILabel() // Safe within MainActor
    
    func updateUI() {
        label.text = "Updated" // No await needed - same isolation
    }
}

// Custom actor isolation domain
actor DataManager {
    private var cache: [String: Data] = [:] // Protected by actor
    
    func store(key: String, data: Data) {
        cache[key] = data // Safe within actor
    }
}

// No isolation - must be Sendable
struct Point: Sendable {
    let x: Double
    let y: Double
}
```

### 2. Concurrency Boundaries

Data crossing concurrency boundaries must be Sendable:

```swift
// ❌ Swift 5: Potential data race
class Model {
    var items: [Item] = []
}

func process(model: Model) async {
    await Task.detached {
        model.items.append(Item()) // Data race!
    }.value
}

// ✅ Swift 6: Compile-time error prevents data race
@MainActor
final class Model: Sendable {
    private(set) var items: [Item] = []
    
    func addItem(_ item: Item) {
        items.append(item) // Safe - MainActor synchronized
    }
}
```

### 3. Region-Based Isolation

Swift 6 introduces "isolation regions" that track data flow:

```swift
// Region-based isolation allows safe transfer without Sendable
func processImage(_ image: UIImage) async -> ProcessedImage {
    // Swift 6 proves image won't be accessed after transfer
    let processed = await withTaskGroup(of: ProcessedTile.self) { group in
        for tile in image.tiles {
            group.addTask {
                // Safe transfer - compiler tracks regions
                await processTile(tile)
            }
        }
        // Collect results...
    }
    return processed
}
```

## Swift Evolution Proposals

### Foundation Proposals (Swift 5.5-5.10)

#### SE-0302: Sendable and @Sendable
Introduces the fundamental `Sendable` protocol:

```swift
// Types safe to share across concurrency domains
protocol Sendable {}

// Sendable closure
let operation: @Sendable () -> Void = {
    print("This closure captures only Sendable values")
}

// Conditional Sendable
struct Container<T>: Sendable where T: Sendable {
    let value: T
}
```

#### SE-0306: Actors
The actor model for protecting mutable state:

```swift
actor BankAccount {
    private var balance: Decimal = 0
    
    func deposit(amount: Decimal) {
        balance += amount
    }
    
    func withdraw(amount: Decimal) -> Bool {
        guard balance >= amount else { return false }
        balance -= amount
        return true
    }
    
    // Computed property accessible without await
    nonisolated var accountDescription: String {
        "Bank Account" // No state access
    }
}
```

#### SE-0316: Global Actors
System-wide isolation domains:

```swift
@globalActor
actor DataActor {
    static let shared = DataActor()
}

// Apply to entire type
@DataActor
class DataStore {
    var items: [Item] = []
    
    func add(_ item: Item) {
        items.append(item)
    }
}

// Apply to specific members
class MixedClass {
    @DataActor var data: [String] = []
    @MainActor var uiState = UIState()
    
    @DataActor
    func processData() async {
        // Runs on DataActor
    }
    
    @MainActor
    func updateUI() {
        // Runs on MainActor
    }
}
```

### Swift 6 Core Proposals

#### SE-0337: Incremental Migration to Concurrency Checking
Enables progressive adoption:

```swift
// Package.swift
.target(
    name: "MyTarget",
    swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
        .enableUpcomingFeature("CompleteAsync"),
        .enableExperimentalFeature("StrictConcurrency=minimal")
    ]
)

// Or via compiler flag
// swiftc -strict-concurrency=complete
```

#### SE-0401: Remove Actor Isolation Inference from Property Wrappers
Eliminates unexpected isolation:

```swift
// Before SE-0401
struct ContentView: View {
    @StateObject private var model = Model() // Made View MainActor-isolated!
    
    func doWork() { // Implicitly @MainActor
        // ...
    }
}

// After SE-0401
struct ContentView: View {
    @StateObject private var model = Model() // No isolation inference
    
    nonisolated func doWork() { // Explicitly non-isolated
        // ...
    }
}
```

#### SE-0412: Strict Concurrency for Global Variables
Global variable safety with `nonisolated(unsafe)`:

```swift
// ❌ Swift 6 error: global variable not concurrency-safe
var sharedCache: [String: Data] = [:]

// ✅ Option 1: Make it a let constant
let sharedConstants = Constants()

// ✅ Option 2: Use global actor
@MainActor
var sharedUICache: [String: UIImage] = [:]

// ✅ Option 3: Actor isolation
actor CacheActor {
    static let shared = CacheActor()
    private var cache: [String: Data] = [:]
}

// ✅ Option 4: Explicit unsafe opt-out
struct LegacyAPI {
    nonisolated(unsafe) static var shared: LegacyAPI?
}
```

#### SE-0414: Region-Based Isolation
Revolutionary improvement in isolation checking:

```swift
// Non-Sendable type can be safely transferred
class MutableData {
    var value: Int = 0
}

func process() async {
    let data = MutableData() // Non-Sendable
    
    // ✅ Safe: data not used after transfer
    await withTaskGroup(of: Void.self) { group in
        group.addTask {
            data.value = 42 // Region analysis proves safety
        }
    }
    
    // ❌ Error: data used after transfer
    // print(data.value)
}
```

#### SE-0420: Inheritance of Actor Isolation
Dynamic isolation inheritance:

```swift
// Function inherits caller's isolation
func log(
    _ message: String,
    isolation: isolated (any Actor)? = #isolation
) async {
    print("[\(isolation)] \(message)")
}

@MainActor
func updateUI() async {
    await log("Updating UI") // Inherits MainActor isolation
}

actor DataProcessor {
    func process() async {
        await log("Processing") // Inherits DataProcessor isolation
    }
}
```

#### SE-0430: Sending Parameter and Result Values
Safe transfer without full Sendable:

```swift
// 'sending' allows ownership transfer
func processData(_ data: sending MutableData) async -> sending ProcessedData {
    // data is consumed - original reference invalidated
    return ProcessedData(from: data)
}

// Updated Task API
extension Task where Failure == Never {
    init(
        priority: TaskPriority? = nil,
        operation: sending @escaping () async -> Success
    )
}
```

#### SE-0431: @isolated(any) Function Types
Isolation-agnostic function types:

```swift
// Function type that preserves any isolation
typealias IsolatedOperation = @isolated(any) () async -> Void

struct Executor {
    func run(_ operation: IsolatedOperation) async {
        await operation() // Maintains caller's isolation
    }
}
```

#### SE-0434: Usability of Global-Actor-Isolated Types
Improvements for global actor usage:

```swift
// Sendable properties can be nonisolated
@MainActor
final class ViewModel: Sendable {
    // ✅ Implicitly nonisolated (Sendable stored property)
    let id = UUID()
    
    // ❌ Must be isolated (non-Sendable)
    var items: [Item] = []
    
    // ✅ Can be explicitly nonisolated
    nonisolated let configuration: Configuration
}

// Improved inference for closures
@MainActor
class Controller {
    func setup() {
        // ✅ Closure inferred as @MainActor @Sendable
        Task {
            await updateData()
        }
    }
}
```

## Data Race Safety

### Complete Concurrency Checking

Swift 6 enforces complete checking by default:

```swift
// Enable in Swift 5 mode for migration
// swift -strict-concurrency=complete

// Levels of checking:
// 1. minimal - Only explicit Sendable conformances
// 2. targeted - Infer Sendable for some types
// 3. complete - Full data race checking
```

### Common Data Race Patterns and Fixes

#### Pattern 1: Shared Mutable State

```swift
// ❌ Data race
class Counter {
    var value = 0
    
    func increment() {
        value += 1 // Race condition!
    }
}

// ✅ Fix 1: Use an actor
actor Counter {
    private var value = 0
    
    func increment() {
        value += 1 // Actor-isolated
    }
    
    var currentValue: Int {
        value
    }
}

// ✅ Fix 2: Use atomic operations
import Atomics

final class Counter: Sendable {
    private let value = ManagedAtomic<Int>(0)
    
    func increment() {
        value.wrappingIncrement(ordering: .relaxed)
    }
    
    var currentValue: Int {
        value.load(ordering: .relaxed)
    }
}
```

#### Pattern 2: Callback Isolation

```swift
// ❌ Unclear isolation
class NetworkManager {
    func fetch(completion: @escaping (Data) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            completion(data!) // What thread?
        }
    }
}

// ✅ Clear isolation with async/await
class NetworkManager {
    func fetch() async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
}

// ✅ Or explicit MainActor isolation
class NetworkManager {
    func fetch(completion: @MainActor @escaping (Data) -> Void) {
        Task {
            let data = try await URLSession.shared.data(from: url).0
            await completion(data)
        }
    }
}
```

## Actor System

### Basic Actor Usage

```swift
actor DatabaseConnection {
    private var isConnected = false
    private var activeQueries = 0
    
    func connect() async throws {
        guard !isConnected else { return }
        // Connection logic...
        isConnected = true
    }
    
    func query(_ sql: String) async throws -> [Row] {
        activeQueries += 1
        defer { activeQueries -= 1 }
        
        // Query execution...
        return rows
    }
    
    // Synchronous access for immutable data
    nonisolated let connectionString: String
    
    // Computed property without state access
    nonisolated var description: String {
        "Database connection to \(connectionString)"
    }
}
```

### MainActor for UI Code

```swift
// Entire class on MainActor
@MainActor
final class LoginViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    func login(username: String, password: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // This switches to background for network call
            let user = try await AuthService.shared.login(
                username: username,
                password: password
            )
            // Automatically back on MainActor
            navigateToHome(user: user)
        } catch {
            self.error = error
        }
    }
    
    // Can run on any thread
    nonisolated func validateEmail(_ email: String) -> Bool {
        // Email validation logic...
    }
}
```

### Custom Global Actors

```swift
// Define a global actor for database operations
@globalActor
actor DatabaseActor {
    static let shared = DatabaseActor()
    
    // Custom executor for integration
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        DatabaseQueue.shared.unownedExecutor
    }
}

// Apply to types handling database operations
@DatabaseActor
class UserRepository {
    private var cache: [UUID: User] = [:]
    
    func findUser(id: UUID) async throws -> User {
        if let cached = cache[id] {
            return cached
        }
        
        let user = try await database.fetch(User.self, id: id)
        cache[id] = user
        return user
    }
    
    func saveUser(_ user: User) async throws {
        try await database.save(user)
        cache[user.id] = user
    }
}

// Mix different actors in one type
class DataCoordinator {
    @DatabaseActor
    private var userRepo = UserRepository()
    
    @MainActor
    private var viewModel = UserListViewModel()
    
    func refreshUsers() async {
        // Fetch on DatabaseActor
        let users = await userRepo.fetchAllUsers()
        
        // Update on MainActor
        await viewModel.update(users: users)
    }
}
```

## Sendable Protocol

### Understanding Sendable

```swift
// Sendable indicates thread-safe types
public protocol Sendable {}

// Automatic conformance for:
// 1. Actors (handle synchronization)
// 2. Immutable structs/enums
// 3. Final classes with immutable storage
// 4. @unchecked Sendable for manual safety

// Examples of automatic Sendable
struct Point: Sendable { // Implicit
    let x: Double
    let y: Double
}

enum Status: Sendable { // Implicit
    case pending
    case completed(at: Date)
}

actor DataManager {} // Implicitly Sendable

final class User: Sendable {
    let id: UUID
    let name: String
    // All stored properties are immutable
}
```

### Conditional Sendable

```swift
// Generic types can be conditionally Sendable
struct Container<T> {
    let value: T
}

// Automatic conditional conformance
extension Container: Sendable where T: Sendable {}

// Custom conditional conformance
struct Cache<Key: Hashable, Value> {
    private var storage: [Key: Value] = [:]
    private let lock = NSLock()
}

extension Cache: @unchecked Sendable where Key: Sendable, Value: Sendable {
    // We ensure thread safety with lock
}
```

### @unchecked Sendable

```swift
// For types that are thread-safe but can't be proven by compiler
final class ThreadSafeCache: @unchecked Sendable {
    private var cache: [String: Data] = [:]
    private let queue = DispatchQueue(label: "cache.queue")
    
    func get(_ key: String) -> Data? {
        queue.sync { cache[key] }
    }
    
    func set(_ key: String, value: Data) {
        queue.async { self.cache[key] = value }
    }
}

// Reference types with immutable data
final class ImageWrapper: @unchecked Sendable {
    let cgImage: CGImage
    
    init(cgImage: CGImage) {
        self.cgImage = cgImage
    }
}
```

### Sendable Functions and Closures

```swift
// Sendable function types
typealias AsyncOperation = @Sendable () async -> Void
typealias CompletionHandler = @Sendable (Result<Data, Error>) -> Void

// Using Sendable closures
func performAsync(operation: @Sendable @escaping () async -> Void) {
    Task {
        await operation()
    }
}

// Sendable captures
func createTimer(interval: TimeInterval) -> AsyncStream<Date> {
    AsyncStream { continuation in
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            continuation.yield(Date())
        }
        
        continuation.onTermination = { @Sendable _ in
            timer.invalidate() // Must be Sendable
        }
    }
}
```

## Migration Guide

### Step 1: Enable Warnings in Swift 5 Mode

```swift
// In Package.swift
.target(
    name: "MyApp",
    swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency"),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("ConciseMagicFile")
    ]
)

// Or in Xcode Build Settings
// Strict Concurrency Checking: Complete
// SWIFT_STRICT_CONCURRENCY = complete
```

### Step 2: Fix Global Variables

```swift
// Before
var sharedFormatter = DateFormatter()

// After - Option 1: Make immutable
let sharedFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    return formatter
}()

// After - Option 2: Add actor isolation
extension DateFormatter {
    @MainActor
    static let shared: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}

// After - Option 3: Use nonisolated(unsafe) for legacy code
nonisolated(unsafe) var legacyGlobal: LegacyType?
```

### Step 3: Add Sendable Conformances

```swift
// Make your model types Sendable
struct User: Codable, Sendable {
    let id: UUID
    let name: String
    let email: String
}

// For reference types, ensure immutability
final class Configuration: Sendable {
    let apiKey: String
    let baseURL: URL
    
    init(apiKey: String, baseURL: URL) {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }
}
```

### Step 4: Isolate UI Code

```swift
// Before
class ViewModel: ObservableObject {
    @Published var items: [Item] = []
    
    func loadItems() {
        Task {
            items = await fetchItems() // Potential race
        }
    }
}

// After
@MainActor
final class ViewModel: ObservableObject {
    @Published private(set) var items: [Item] = []
    
    func loadItems() async {
        items = await fetchItems() // Safe on MainActor
    }
}
```

### Step 5: Handle Callbacks and Delegates

```swift
// Before - Unclear isolation
protocol DataDelegate: AnyObject {
    func dataDidUpdate(_ data: Data)
}

// After - Explicit isolation
@MainActor
protocol DataDelegate: AnyObject {
    func dataDidUpdate(_ data: Data)
}

// Or use async alternatives
protocol DataProvider {
    func fetchData() async throws -> Data
}
```

### Progressive Migration Strategy

1. **Start with leaf modules**: Begin with modules that have few dependencies
2. **Fix simple issues first**: Immutable globals, missing Sendable conformances
3. **Isolate UI layer**: Add @MainActor to view controllers and view models
4. **Address shared state**: Convert to actors or use synchronization
5. **Enable Swift 6 mode**: Once warnings are resolved

## Code Examples

### Example 1: Image Processing Pipeline

```swift
// Image processor using actors and Sendable
actor ImageProcessor {
    private let cache = ImageCache()
    
    func process(_ image: UIImage, filters: [Filter]) async throws -> UIImage {
        // Check cache
        let cacheKey = CacheKey(image: image, filters: filters)
        if let cached = await cache.get(cacheKey) {
            return cached
        }
        
        // Process image
        var result = image
        for filter in filters {
            result = try await filter.apply(to: result)
        }
        
        // Cache result
        await cache.set(cacheKey, image: result)
        return result
    }
}

// Sendable filter protocol
protocol Filter: Sendable {
    func apply(to image: UIImage) async throws -> UIImage
}

// Concrete filter implementation
struct BlurFilter: Filter {
    let radius: Double
    
    func apply(to image: UIImage) async throws -> UIImage {
        // Implementation using Core Image
        let ciImage = CIImage(image: image)!
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = ciImage
        filter.radius = Float(radius)
        
        let context = CIContext()
        let output = filter.outputImage!
        let cgImage = context.createCGImage(output, from: output.extent)!
        
        return UIImage(cgImage: cgImage)
    }
}
```

### Example 2: Network Layer with Proper Isolation

```swift
// Network service with clear isolation boundaries
actor NetworkService {
    private let session: URLSession
    private let decoder = JSONDecoder()
    private var activeTasks: [UUID: URLSessionTask] = [:]
    
    init(configuration: URLSessionConfiguration = .default) {
        self.session = URLSession(configuration: configuration)
    }
    
    func fetch<T: Decodable & Sendable>(
        _ type: T.Type,
        from url: URL
    ) async throws -> T {
        let taskID = UUID()
        
        let task = session.dataTask(with: url)
        activeTasks[taskID] = task
        
        defer { activeTasks.removeValue(forKey: taskID) }
        
        let (data, response) = try await withTaskCancellationHandler {
            try await session.data(from: url)
        } onCancel: {
            task.cancel()
        }
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }
        
        return try decoder.decode(type, from: data)
    }
    
    func cancelAll() {
        activeTasks.values.forEach { $0.cancel() }
        activeTasks.removeAll()
    }
    
    nonisolated var activeTaskCount: Int {
        get async { await activeTasks.count }
    }
}

// Usage with proper error handling
@MainActor
class UserListViewModel: ObservableObject {
    @Published private(set) var users: [User] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    private let networkService = NetworkService()
    
    func loadUsers() async {
        isLoading = true
        error = nil
        
        do {
            let url = URL(string: "https://api.example.com/users")!
            users = try await networkService.fetch([User].self, from: url)
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
}
```

### Example 3: Concurrent Data Processing

```swift
// Parallel processing with proper isolation
struct DataProcessor {
    func processFiles(_ urls: [URL]) async throws -> [ProcessedData] {
        try await withThrowingTaskGroup(of: ProcessedData.self) { group in
            // Add tasks for each file
            for url in urls {
                group.addTask {
                    try await processFile(url)
                }
            }
            
            // Collect results
            var results: [ProcessedData] = []
            for try await result in group {
                results.append(result)
            }
            
            return results
        }
    }
    
    private func processFile(_ url: URL) async throws -> ProcessedData {
        let data = try await readFile(url)
        let processed = try await transform(data)
        return ProcessedData(
            originalURL: url,
            processedData: processed,
            timestamp: Date()
        )
    }
}

// Result type that's Sendable
struct ProcessedData: Sendable {
    let originalURL: URL
    let processedData: Data
    let timestamp: Date
}
```

## Best Practices

### 1. Design for Sendability

```swift
// ❌ Avoid mutable reference types
class Settings {
    var theme: Theme
    var notifications: Bool
}

// ✅ Prefer value types or immutable reference types
struct Settings: Sendable {
    let theme: Theme
    let notifications: Bool
}

// ✅ Or use actors for mutable state
actor SettingsManager {
    private var settings: Settings
    
    func update(theme: Theme) {
        settings = Settings(
            theme: theme,
            notifications: settings.notifications
        )
    }
}
```

### 2. Minimize Actor Hops

```swift
// ❌ Excessive actor hopping
@MainActor
class ViewModel {
    func processData() async {
        let data = await dataActor.getData()
        let processed = await processorActor.process(data)
        let formatted = await formatterActor.format(processed)
        updateUI(formatted)
    }
}

// ✅ Batch operations
@MainActor
class ViewModel {
    func processData() async {
        let result = await dataActor.getProcessedAndFormattedData()
        updateUI(result)
    }
}
```

### 3. Use nonisolated for Pure Functions

```swift
actor Calculator {
    private var history: [Calculation] = []
    
    // ✅ Pure functions don't need isolation
    nonisolated func add(_ a: Double, _ b: Double) -> Double {
        a + b
    }
    
    nonisolated func multiply(_ a: Double, _ b: Double) -> Double {
        a * b
    }
    
    // State-modifying functions need isolation
    func recordCalculation(_ calc: Calculation) {
        history.append(calc)
    }
}
```

### 4. Leverage Structured Concurrency

```swift
// ✅ Use task groups for parallel work
func downloadImages(urls: [URL]) async throws -> [UIImage] {
    try await withThrowingTaskGroup(of: (Int, UIImage).self) { group in
        for (index, url) in urls.enumerated() {
            group.addTask {
                let image = try await downloadImage(from: url)
                return (index, image)
            }
        }
        
        var images = Array<UIImage?>(repeating: nil, count: urls.count)
        for try await (index, image) in group {
            images[index] = image
        }
        
        return images.compactMap { $0 }
    }
}
```

### 5. Handle Cancellation Properly

```swift
func longRunningOperation() async throws -> Result {
    try await withTaskCancellationHandler {
        var progress = 0.0
        
        while progress < 1.0 {
            try Task.checkCancellation()
            
            // Do work...
            progress += 0.1
            
            try await Task.sleep(for: .seconds(1))
        }
        
        return result
    } onCancel: {
        // Cleanup resources
        cleanupOperation()
    }
}
```

## Testing and Debugging

### Thread Sanitizer (TSan)

Thread Sanitizer remains essential for catching runtime data races that escape compile-time checks:

```bash
# Enable in Xcode
Product → Scheme → Edit Scheme → Diagnostics → Thread Sanitizer

# Or via command line
swift test -Xswiftc -sanitize=thread
```

**When to use TSan:**
- Testing legacy code with @preconcurrency imports
- Verifying @unchecked Sendable implementations
- Catching races in C/Objective-C interop

### Swift Concurrency Debugger (Xcode 16+)

New debugging tools for concurrent code:

1. **Task Tree View**: Visualize parent-child task relationships
2. **Actor Memory Graph**: See actor isolation boundaries
3. **Hop Tracking**: Follow execution across isolation domains

```swift
// Debugging helpers
extension Task {
    static func currentPriority() -> TaskPriority {
        Task.currentPriority
    }
    
    static func printTaskTree() {
        // Available in debug builds
        #if DEBUG
        print("Task: \(Task<Never, Never>.currentPriority)")
        #endif
    }
}
```

### Unit Testing Concurrent Code

```swift
// Test helper for async code with timeout
func withTimeout<T>(
    _ duration: Duration = .seconds(5),
    operation: @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(for: duration)
            throw TimeoutError()
        }
        
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

// Testing actor isolation
final class ActorTests: XCTestCase {
    func testActorIsolation() async throws {
        let actor = TestActor()
        
        // Verify isolation with multiple concurrent operations
        try await withThrowingTaskGroup(of: Int.self) { group in
            for i in 0..<100 {
                group.addTask {
                    await actor.increment()
                    return await actor.value
                }
            }
            
            var results: Set<Int> = []
            for try await result in group {
                results.insert(result)
            }
            
            // All results should be unique if properly isolated
            XCTAssertEqual(results.count, 100)
        }
    }
}
```

### Debugging Common Issues

```swift
// 1. Debugging unexpected suspension points
actor DataManager {
    func debugSuspension() async {
        print("Before suspension: \(Thread.current)")
        await someAsyncOperation()
        print("After suspension: \(Thread.current)") // May be different thread
    }
}

// 2. Tracking isolation context
func debugIsolation(
    isolation: isolated (any Actor)? = #isolation
) async {
    if let isolation {
        print("Running on: \(type(of: isolation))")
    } else {
        print("Running on non-isolated context")
    }
}

// 3. Detecting priority inversions
Task(priority: .low) {
    await debugPriority() // May run at higher priority due to escalation
}

func debugPriority() async {
    print("Current priority: \(Task.currentPriority)")
}
```

## Common Compiler Errors

### Error Reference Table

| Diagnostic | Example | Fix |
|------------|---------|-----|
| **Non-Sendable type crossing actor boundary** | `Capture of 'nonSendable' with non-sendable type 'MyClass'` | 1. Make type Sendable<br>2. Use `sending` parameter<br>3. Copy/transform to Sendable type |
| **Actor-isolated property referenced from non-isolated** | `Actor-isolated property 'items' can not be referenced from a non-isolated context` | 1. Add `await`<br>2. Move code to actor<br>3. Make property `nonisolated` |
| **Call to main actor-isolated from non-isolated** | `Call to main actor-isolated instance method 'updateUI()' in a synchronous nonisolated context` | 1. Add `@MainActor` to caller<br>2. Use `await MainActor.run { }`<br>3. Make method `nonisolated` |
| **Mutation of captured var** | `Mutation of captured var 'counter' in concurrently-executing code` | 1. Use actor for state<br>2. Make immutable<br>3. Use `Mutex` (Swift 6.1+) |
| **Sendable closure captures non-Sendable** | `Capture of 'self' with non-sendable type 'ViewController?' in a `@Sendable` closure` | 1. Use `[weak self]`<br>2. Make type Sendable<br>3. Extract needed values before closure |

### Detailed Error Solutions

#### 1. Non-Sendable Type Errors

```swift
// ❌ Error: Non-Sendable type 'UIImage' crossing actor boundary
class ImageProcessor {
    func process(image: UIImage) async {
        Task.detached {
            // Error: capture of 'image' with non-sendable type
            manipulate(image)
        }
    }
}

// ✅ Solution 1: Use sending parameter
class ImageProcessor {
    func process(image: sending UIImage) async {
        Task.detached {
            manipulate(image) // Ownership transferred
        }
    }
}

// ✅ Solution 2: Convert to Sendable representation
class ImageProcessor {
    func process(image: UIImage) async {
        let imageData = image.pngData()! // Data is Sendable
        Task.detached {
            let recreated = UIImage(data: imageData)!
            manipulate(recreated)
        }
    }
}
```

#### 2. Actor Isolation Errors

```swift
// ❌ Error: Actor-isolated property accessed without await
actor DataStore {
    var items: [Item] = []
    
    nonisolated func getItemCount() -> Int {
        items.count // Error: actor-isolated property
    }
}

// ✅ Solution 1: Make method async
actor DataStore {
    var items: [Item] = []
    
    func getItemCount() async -> Int {
        items.count // OK: implicitly isolated to actor
    }
}

// ✅ Solution 2: Use computed property
actor DataStore {
    private var items: [Item] = []
    
    var itemCount: Int {
        items.count // OK: computed property is isolated
    }
}
```

#### 3. MainActor Isolation Errors

```swift
// ❌ Error: Call to MainActor-isolated from background
func backgroundWork() {
    updateUI() // Error: MainActor-isolated
}

@MainActor
func updateUI() { }

// ✅ Solution 1: Make caller MainActor
@MainActor
func backgroundWork() async {
    await fetchData()
    updateUI() // OK: both on MainActor
}

// ✅ Solution 2: Explicit MainActor.run
func backgroundWork() async {
    let data = await fetchData()
    await MainActor.run {
        updateUI()
    }
}
```

## Performance Tuning

### Task Creation Overhead

```swift
// ❌ Excessive task creation
for item in items {
    Task {
        await process(item) // Creates N unstructured tasks
    }
}

// ✅ Use TaskGroup for batch operations
await withTaskGroup(of: Void.self) { group in
    for item in items {
        group.addTask {
            await process(item) // Structured, limited concurrency
        }
    }
}

// ✅ Or use concurrent forEach
await items.concurrentForEach { item in
    await process(item)
}
```

### Clock APIs for Efficient Timing

```swift
// ❌ Old-style sleep
Task {
    Thread.sleep(forTimeInterval: 1.0) // Blocks thread
}

// ❌ Task.sleep with nanoseconds
Task {
    try await Task.sleep(nanoseconds: 1_000_000_000)
}

// ✅ Modern Clock-based approach
let clock = ContinuousClock()
try await clock.sleep(for: .seconds(1))

// ✅ Measure elapsed time
let elapsed = await clock.measure {
    await expensiveOperation()
}
print("Operation took: \(elapsed)")

// ✅ Custom clock for testing
struct TestClock: Clock {
    var now: Instant { .init() }
    func sleep(until deadline: Instant) async throws {
        // Instant return for tests
    }
}
```

### Structured vs Unstructured Tasks

```swift
// ❌ Unstructured tasks lose context
class Service {
    func startBackgroundWork() {
        Task {
            await longRunningWork() // No cancellation propagation
        }
    }
}

// ✅ Structured tasks with proper lifecycle
class Service {
    private var workTask: Task<Void, Never>?
    
    func startBackgroundWork() {
        workTask = Task {
            try await withTaskCancellationHandler {
                await longRunningWork()
            } onCancel: {
                cleanup()
            }
        }
    }
    
    func stopWork() {
        workTask?.cancel()
    }
}

// ✅ Detached tasks only for true daemons
Task.detached(priority: .background) {
    // Long-lived background monitoring
    while !Task.isCancelled {
        await checkSystemHealth()
        try await Task.sleep(for: .minutes(5))
    }
}
```

### Actor Contention Optimization

```swift
// ❌ High contention on single actor
actor Counter {
    private var value = 0
    
    func increment() {
        value += 1
    }
}

// ✅ Reduce contention with batching
actor Counter {
    private var value = 0
    
    func increment(by amount: Int = 1) {
        value += amount
    }
    
    func batchIncrement(_ operations: [Int]) {
        value += operations.reduce(0, +)
    }
}

// ✅ Or use sharding for high throughput
actor ShardedCounter {
    private var shards: [Int]
    
    init(shardCount: Int = ProcessInfo.processInfo.activeProcessorCount) {
        self.shards = Array(repeating: 0, count: shardCount)
    }
    
    func increment() {
        let shard = Int.random(in: 0..<shards.count)
        shards[shard] += 1
    }
    
    var total: Int {
        shards.reduce(0, +)
    }
}
```

## Swift 6.1+ Roadmap

### Swift 6.1 (Shipped)

#### SE-0431: @isolated(any) Function Types
```swift
// Function types that preserve isolation
typealias IsolatedHandler = @isolated(any) () async -> Void

func withIsolation(_ handler: IsolatedHandler) async {
    await handler() // Maintains caller's isolation
}

// Use with actors
actor MyActor {
    func doWork() async {
        await withIsolation {
            // Runs on MyActor
            print("Isolated to: \(self)")
        }
    }
}
```

#### SE-0433: Synchronous Mutual Exclusion Lock (Mutex)
```swift
import Synchronization

// For protecting critical sections without async
final class Statistics: Sendable {
    private let mutex = Mutex<Stats>(.init())
    
    func record(value: Double) {
        mutex.withLock { stats in
            stats.count += 1
            stats.sum += value
        }
    }
    
    var average: Double {
        mutex.withLock { stats in
            stats.count > 0 ? stats.sum / Double(stats.count) : 0
        }
    }
}

private struct Stats {
    var count = 0
    var sum = 0.0
}
```

### Swift 6.2 (In Development)

#### SE-0461: Isolated Default Arguments
```swift
// Default values can use isolation context
@MainActor
class ViewModel {
    // ✅ Default can access MainActor state
    func configure(
        title: String = defaultTitle // Coming in 6.2
    ) { }
    
    @MainActor
    static var defaultTitle: String { "Default" }
}
```

### Future Proposals Under Review

1. **SE-0449**: Allow nonisolated to prevent global actor inference
2. **SE-0450**: Limiting actor isolation inference
3. **SE-0451**: Isolated synchronous deinit
4. **Typed Throws in Concurrency**: Better error propagation
5. **Custom Executors v2**: More control over task execution

### Migration Timeline

| Version | Key Features | Migration Impact |
|---------|--------------|------------------|
| Swift 6.0 | Strict concurrency by default | Major - requires code updates |
| Swift 6.1 | Mutex, @isolated(any) | Minor - additive features |
| Swift 6.2 | Isolated defaults, deinit | Minor - quality of life |
| Swift 7.0 | Custom executors v2 | TBD - performance focused |

Stay updated: [Swift Evolution Dashboard](https://www.swift.org/swift-evolution/)

## Resources

### Official Documentation
- [Swift.org - Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [Migrating to Swift 6](https://www.swift.org/migration/documentation/migrationguide/)
- [Data Race Safety](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/dataracesafety/)

### Swift Evolution Proposals
- [SE-0401: Remove Actor Isolation Inference](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0401-remove-property-wrapper-isolation.md)
- [SE-0414: Region-based Isolation](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0414-region-based-isolation.md)
- [SE-0420: Inheritance of Actor Isolation](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0420-inheritance-of-actor-isolation.md)
- [SE-0430: Sending Parameter Values](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0430-transferring-parameters-and-results.md)

### WWDC Sessions
- **WWDC 2024**: "Migrate your app to Swift 6" - Practical migration guide
- **WWDC 2022**: "Eliminate data races using Swift Concurrency" - Foundational concepts
- **WWDC 2021**: "Meet async/await in Swift" - Introduction to Swift concurrency

### Community Resources
- [Swift Forums - Concurrency](https://forums.swift.org/c/swift-evolution/concurrency/23)
- [Concurrency Index Thread](https://developer.apple.com/forums/thread/768776)
- [Swift Package Index](https://swiftpackageindex.com) - Shows "Safe from data races" badge

## Conclusion

Swift 6's strict concurrency represents a paradigm shift in how we write concurrent code. By embracing:
- Complete data race safety at compile time
- Clear isolation boundaries with actors
- Explicit Sendable requirements
- Progressive migration strategies

We can write safer, more maintainable concurrent code. The compiler becomes our partner in preventing entire classes of bugs, leading to more reliable applications.

Remember: The goal isn't just to silence compiler warnings, but to design systems with clear concurrency boundaries that are easier to reason about and maintain over time.