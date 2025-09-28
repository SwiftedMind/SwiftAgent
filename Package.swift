// swift-tools-version: 6.2

import CompilerPluginSupport
import PackageDescription

let package = Package(
	name: "SwiftAgent",
	platforms: [
		.iOS(.v26),
		.macOS(.v26),
	],
	products: [
		.library(name: "OpenAISession", targets: ["OpenAISession", "SimulatedSession", "SwiftAgent"]),
	],
	dependencies: [
		.package(url: "https://github.com/swiftlang/swift-syntax.git", from: "510.0.0"),
		.package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.10.0"),
		.package(url: "https://github.com/MacPaw/OpenAI.git", branch: "main"),
		.package(url: "https://github.com/mattt/EventSource", from: "1.2.0"),
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
			],
		),
		.target(
			name: "Internal",
		),
		.target(
			name: "SwiftAgent",
			dependencies: [
				"Internal",
				"SwiftAgentMacros",
				"EventSource",
			],
		),
		.target(
			name: "OpenAISession",
			dependencies: [
				"SwiftAgent",
				"OpenAI",
				"SwiftAgentMacros",
				"EventSource",
				.product(name: "Dependencies", package: "swift-dependencies"),
			],
			path: "Sources/OpenAI",
		),
		.target(
			name: "SimulatedSession",
			dependencies: [
				"SwiftAgent",
				"Internal",
				"OpenAI",
			],
			path: "Sources/Simulation",
		),
		.testTarget(
			name: "SwiftAgentTests",
			dependencies: [
				"OpenAISession",
				"SwiftAgent",
				.product(name: "Dependencies", package: "swift-dependencies"),
			],
		),
	],
)
