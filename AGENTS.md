# SwiftAgent

**Native Swift SDK for building autonomous AI agents with Apple's FoundationModels design philosophy**

SwiftAgent simplifies AI agent development by providing a clean, intuitive API that handles all the complexity of agent loops, tool execution, and adapter communication. Inspired by Apple's FoundationModels framework, it brings the same elegant, declarative approach to cross-platform AI agent development.

## General Instructions

- Always follow the best practices of naming things in Swift
- ALWAYS use clear names for types and variables, don't just use single letters or abbreviations. Clarity is key!
- In SwiftUI views, always place private properties on top of the non-private ones, and the non-private ones directly above the initializer

### **IMPORTANT**: Before you start

- Check if you should read a resource or guideline related to your task
- When asked to commit changes to the repository, always read and understand the commit guidelines before doing anything!
- When asked to update the changelog, always read and understand the changelog guidelines before doing anything!

### When you are done

- Build the project to check for compilation errors
- When you have added or modified Swift files, run `swiftformat --config ".swiftformat" {files}`.
  - For large refactors, run `swiftformat` on the touched subdirectories only.

### Simplicity

- Do the smallest thing that works. Prefer plain, direct code over new layers, patterns, or abstractions.
- Minimize change. Choose the approach that touches the fewest files and concepts while meeting requirements.
- Optimize for readability & maintenance. Clear names, small functions, single responsibility, brief doc comments.
- Defer complexity. Add abstractions only after real repetition/need is proven (rule of three), not “just in case.”

## Internal Resources

- agents/guidelines/commit.md - Guidelines for committing changes to the repository
- agents/guidelines/changelog.md - Guidelines for maintaining the changelog
- agents/swift/swiftui.md - Guidelines on modern SwiftUI and how to build things with it
- agents/swift/swift-testing.md - An overview of the Swift Testing framework
- agents.local/tests.md - Guidelines on writing unit tests for the SDK

## Available MCPs

- `XcodeBuildMCP` to build and test the project
- `sosumi` mcp - Access to Apple's documentation for all Swift and SwiftUI APIs, guidelines and best practices. Use this to complement or fix/enhance your potentially outdated knowledge of these APIs.
- `context7` - Access to documentation for a large amount of libraries and SDKs, including:
  - MacPaw: "OpenAI Swift" - Swift implementation of the OpenAI API (Responses API)
  - Swift Syntax: When working with Swift Macros, you can refer to this since its APIs constantly change which might cause problems for you
- You can use GitHub's `gh` cli to interact with the GitHub repository, but you need to call it with elevated permissions

## Development Commands

### Building and Testing (use XcodeBuildMCP only)

- NEVER use `swift build` or the cli version of `xcodebuild` to build or test the project! You MUST use XcodeBuildMCP
- Replace {working_directory} with the current working directory

#### Build SDK

```
XcodeBuildMCP.build_sim({
  workspacePath: "{working_directory}/SwiftAgent.xcworkspace",
  scheme: "ExampleApp",
  simulatorName: "iPhone 17 Pro",
  useLatestOS: true
})
```

#### Build Utility App

```
XcodeBuildMCP.build_sim({
  workspacePath: "{working_directory}/SwiftAgent.xcworkspace",
  scheme: "UtilityApp",
  simulatorName: "iPhone 17 Pro"
})
```

#### Build Tests

```
XcodeBuildMCP.build_macos({
  workspacePath: "{working_directory}/SwiftAgent.xcworkspace",
  scheme: "SwiftAgentTests"
})
```

#### Run Tests

- Replace {working_directory} with the current working directory

```
XcodeBuildMCP.test_macos({
  workspacePath: "{working_directory}/SwiftAgent.xcworkspace",
  scheme: "SwiftAgentTests",
  extraArgs: ["-testPlan", "SwiftAgentTests"]
})
```
