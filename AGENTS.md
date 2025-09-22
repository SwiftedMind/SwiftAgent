# SwiftAgent

**Native Swift SDK for building autonomous AI agents with Apple's FoundationModels design philosophy**

SwiftAgent simplifies AI agent development by providing a clean, intuitive API that handles all the complexity of agent loops, tool execution, and adapter communication. Inspired by Apple's FoundationModels framework, it brings the same elegant, declarative approach to cross-platform AI agent development.

## General Instructions

- **IMPORTANT**: Before starting to work on tasks, ALWAYS check if you should read a resource or guideline
- **IMPORTANT**: When making changes to the code, ALWAYS build the project to check for compilation errors
- **IMPORTANT**: When committing changes to the repository, always follow the commit guidelines
- **IMPORTANT**: When writing to the CHANGELOG.md, always follow the changelog guidelines
- **IMPORTANT**: Whenever you are done with editing .swift files, ALWAYS run `swiftformat --config ".swiftformat" {file1} {file2} ...` at the end to format all the files you have written to!

- Always follow the best practices of naming things in Swift
- ALWAYS use clear names for types and variables, don't just use single letters or abbreviations. Clarity is key!
- Use 2 spaces for indentation and tabs
- In SwiftUI views, always place private properties on top of the non-private ones, and the non-private ones directly above the initializer

## Resources

- ALWAYS look through the available resources below, read the files that are relevant to your task and follow their instructions and guidelines.

### Internal Resources

- agents/commit-guidelines.md - Guidelines for committing changes to the repository
- agents/changelog-guidelines.md - Guidelines for maintaining the changelog
- agents/modern-swift.md - Guidelines on modern SwiftUI and how to build things with it
- agents/swift-testing.md - An overview of the Swift Testing framework
- agents/tests.md - Guidelines on writing unit tests for the SDK

### External Tools

- `sosumi` tool - Access to Apple's documentation for all Swift and SwiftUI APIs, guidelines and best practices. Use this to complement or fix/enhance your potentially outdated knowledge of these APIs.

## Development Commands

### Building and Testing

- Build and test the SDK in `SwiftAgent.xcworkspace` using the `XcodeBuildMCP` mcp
- DO NOT build or test using `swift build` or `swift test` as it will not work (due to iOS dependencies)

#### Build SDK

- Replace {working_directory} with the current working directory

```
XcodeBuildMCP.build_sim({
  workspacePath: "{working_directory}/SwiftAgent.xcworkspace",
  scheme: "SwiftAgent",
  simulatorName: "iPhone 16 Pro"
})
```

#### Build Example App

- Replace {working_directory} with the current working directory

```
XcodeBuildMCP.build_sim({
  workspacePath: "{working_directory}/SwiftAgent.xcworkspace",
  scheme: "ExampleApp",
  simulatorName: "iPhone 16 Pro"
})
```

#### Run Tests

- Replace {working_directory} with the current working directory

```
XcodeBuildMCP.test_sim({
  workspacePath: "{working_directory}/SwiftAgent.xcworkspace",
  scheme: "SwiftAgentTests",
  simulatorName: "iPhone 16 Pro",
  useLatestOS: true,
  extraArgs: ["-testPlan", "SwiftAgentTests"]
})
```
