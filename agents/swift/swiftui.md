# SwiftUI Guidelines

Write idiomatic SwiftUI code following Apple's latest architectural recommendations and best practices.

## Core Philosophy

- SwiftUI is the default UI paradigm for Apple platforms - embrace its declarative nature
- Avoid legacy UIKit patterns and unnecessary abstractions
- Focus on simplicity, clarity, and native data flow
- Let SwiftUI handle the complexity - don't fight the framework

## General Guidelines

- Avoid initializing custom Bindings using Binding(get:set:). Always prefer bindings derived by SwiftUI from State directly
- Always pass router instances into feature views; do not access `RootRouter.shared` from inside feature views. Route through the owning router instead.

## Architecture Guidelines

### 1. Embrace Native State Management

Use SwiftUI's built-in property wrappers appropriately:
- `@State` - Local, ephemeral view state
- `@Binding` - Two-way data flow between views
- `@Observable` - Shared state
- `@Environment` - Dependency injection for app-wide concerns

### 2. State Ownership Principles

- Views own their local state unless sharing is required
- State flows down, actions flow up
- Keep state as close to where it's used as possible
- Extract shared state only when multiple views need it

### 3. Modern Async Patterns

- Use `async/await` as the default for asynchronous operations
- Leverage `.task` modifier for lifecycle-aware async work
- Avoid Combine unless absolutely necessary
- Handle errors gracefully with try/catch

### 4. View Composition

- Build UI with small, focused views
- Split the view body into view builder properties to keep the code structured and readable
- Use view modifiers to encapsulate common styling
- Prefer composition over inheritance

### 5. Code Organization

- Organize by feature, not by type (avoid Views/, ViewModels/ folders)
- Follow Swift naming conventions consistently

## Implementation Patterns

### Simple State Example
```swift
struct CounterView: View {
  @State private var count = 0
  
  var body: some View {
	  VStack {
		  Text("Count: \(count)")
		  Button("Increment") { 
			  count += 1 
		  }
	  }
  }
}
```

## Best Practices

### DO:
- Write self-contained views when possible
- Use property wrappers as intended by Apple
- Test logic in isolation, preview UI visually
- Handle loading and error states explicitly using 
- Use Swift's type system for safety

### DON'T:
- Create ViewModels for every view
- Move state out of views unnecessarily
- Add abstraction layers without clear benefit
- Use Combine for simple async operations
- Fight SwiftUI's update mechanism
- Overcomplicate simple features

## Modern Swift Features

- Use Swift Concurrency (async/await, actors)
- Leverage Swift 6 data race safety when available
- Utilize property wrappers effectively

## Summary

Write SwiftUI code that looks and feels like SwiftUI. The framework has matured significantly - trust its patterns and tools. Focus on solving user problems rather than implementing architectural patterns from other platforms.
