# SwiftAgent

**Native Swift SDK for building autonomous AI agents with Apple's FoundationModels design philosophy**

SwiftAgent simplifies AI agent development by providing a clean, intuitive API that handles all the complexity of agent loops, tool execution, and adapter communication. Inspired by Apple's FoundationModels framework, it brings the same elegant, declarative approach to cross-platform AI agent development.

## General Instructions

- Whenever you make changes to the code, build the project to ensure everything still compiles
- Whenever you make changes to unit tests, run the testsuite to verify the changes.
- Always follow the best practices of naming things in Swift
- Always use clear names for types and variables, don't just use single letters or abbreviations. Clarity is key!
- In SwiftUI views, always place private properties on top of the non-private ones, and the non-private ones directly above the initializer
- Do not collapse declarations into single-line statements. Expand types, properties, closures, and functions across multiple lines for readability. For example, prefer:

  ```swift
  @Generable
  struct Schema {
    let title: String
  }

  let buildGreeting: (String) -> String = { name in
    "Hello, \(name)"
  }
  ```

### **IMPORTANT**: Before you start

- Check if you should read a resource or guideline related to your task
- When asked to commit changes to the repository, always read and understand the commit guidelines before doing anything!
- When asked to update the changelog, always read and understand the changelog guidelines before doing anything!
- When asked to write documentation or docstrings, always read and understand the docc guidelines before doing anything!

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
- agents/swift/docc.md - Guidelines on writing docstrings in Swift

## Documentation Shortcuts

### FoundationModels

These types are defined in Apple’s FoundationModels framework, so you will not find their definitions inside this repository. If you need a refresher on how they behave, call `tool.sosumi__fetchAppleDocumentation` with the relevant path:

- `{"path":"/documentation/foundationmodels/generable"}` for the `Generable` macro protocol.
- `{"path":"/documentation/foundationmodels/generatedcontent"}` for the `GeneratedContent` structure.
- `{"path":"/documentation/foundationmodels/convertiblefromgeneratedcontent"}` for `ConvertibleFromGeneratedContent`.
- `{"path":"/documentation/foundationmodels/convertibletogeneratedcontent"}` for `ConvertibleToGeneratedContent`.
- `{"path":"/documentation/foundationmodels/generationschema"}` for `GenerationSchema`.
- `{"path":"/documentation/foundationmodels/tool"}` for the `Tool` protocol.

## Available MCPs

- `hatch-mcp run-allowed-command` for running `xcodebuild` outside the sandbox (do not use it for anything else)
- `sosumi` mcp - Access to Apple's documentation for all Swift and SwiftUI APIs, guidelines and best practices. Use this to complement or fix/enhance your potentially outdated knowledge of these APIs.
- `context7` - Access to documentation for a large amount of libraries and SDKs, including:
  - MacPaw: "OpenAI Swift" - Swift implementation of the OpenAI API (Responses API)
  - Swift Syntax: When working with Swift Macros, you can refer to this since its APIs constantly change which might cause problems for you
- You can use GitHub's `gh` cli to interact with the GitHub repository, but you need to call it with elevated permissions

## Development Commands

### Building and Testing (use `hatch-mcp` for `xcodebuild`)

- Only run `xcodebuild` through `hatch-mcp run-allowed-command`; it is approved solely for `xcodebuild` so do not execute any other tool with it. Pass the command below directly to `--command`.
- Always include the `-quiet` flag to keep logs readable. Remove it only when debugging a failing build.
- Replace {working_directory} with the current project directory
- There is no need to `cd` into the project first

#### Build SDK

```
xcodebuild -quiet -workspace {working_directory}/SwiftAgent.xcworkspace -scheme ExampleApp -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=latest" build
```

#### Build Utility App

```
xcodebuild -quiet -workspace {working_directory}/SwiftAgent.xcworkspace -scheme UtilityApp -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=latest" build
```

#### Build Tests

```
xcodebuild -quiet -workspace {working_directory}/SwiftAgent.xcworkspace -scheme SwiftAgentTests build
```

#### Run Tests

```
xcodebuild -quiet -workspace {working_directory}/SwiftAgent.xcworkspace -scheme SwiftAgentTests -testPlan SwiftAgentTests test
```
