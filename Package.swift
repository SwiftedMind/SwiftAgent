// swift-tools-version: 6.2

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "SwiftAgent",
  platforms: [
    .iOS(.v16),   // realistic minimums
    .macOS(.v13),
  ],
  products: [
    .library(name: "OpenAISession", targets: ["OpenAISession", "SimulatedSession", "SwiftAgent"]),
    .library(name: "AnthropicSession", targets: ["AnthropicSession", "SimulatedSession", "SwiftAgent"]),
    .library(name: "ExampleCode", targets: ["ExampleCode"]),
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0"..<"603.0.0"),
    // ✅ FIX: pin OpenAI to a tag or commit instead of branch
    .package(url: "https://github.com/MacPaw/OpenAI.git", from: "0.1.0"),
    .package(url: "https://github.com/jamesrochabrun/SwiftAnthropic.git", from: "2.2.0"),
    .package(url: "https://github.com/mattt/EventSource", from: "1.2.0"),
    .package(url: "https://github.com/pointfreeco/swift-macro-testing", from: "0.6.4"),
  ],
  targets: [
    .macro(
      name: "SwiftAgentMacros",
      dependencies: [
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        .product(name: "SwiftDiagnostics", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
      ]
    ),
    .target(
      name: "SwiftAgent",
      dependencies: [
        "SwiftAgentMacros",
        "EventSource",
      ]
    ),
    .target(
      name: "OpenAISession",
      dependencies: [
        "SwiftAgent",
        "OpenAI",
        "SwiftAgentMacros",
        "EventSource",
      ]
    ),
    .target(
      name: "AnthropicSession",
      dependencies: [
        "SwiftAgent",
        "SwiftAnthropic",
        "SwiftAgentMacros",
        "EventSource",
      ]
    ),
    .target(
      name: "SimulatedSession",
      dependencies: [
        "SwiftAgent",
        "OpenAI",
      ]
    ),
    .target(
      name: "ExampleCode",
      dependencies: [
        "SwiftAgent",
        "AnthropicSession",
        "OpenAISession",
        "SimulatedSession",
        .product(name: "SwiftAnthropic", package: "SwiftAnthropic"),
      ]
    ),
    .testTarget(
      name: "SwiftAgentTests",
      dependencies: [
        "AnthropicSession",
        "OpenAISession",
        "SwiftAgent",
        "SimulatedSession",
        .product(name: "SwiftAnthropic", package: "SwiftAnthropic"),
      ]
    ),
    .testTarget(
      name: "SwiftAgentMacroTests",
      dependencies: [
        "SwiftAgentMacros",
        .product(name: "MacroTesting", package: "swift-macro-testing"),
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
