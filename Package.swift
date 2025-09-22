// swift-tools-version: 6.2

import PackageDescription

let package = Package(
	name: "SwiftAgent",
	platforms: [
		.iOS(.v26),
	],
	products: [
		.library(name: "OpenAISession", targets: ["OpenAISession", "SimulatedSession", "SwiftAgent"]),
	],
        dependencies: [],
        targets: [
                .target(
                        name: "Internal",
                ),
                .target(
			name: "SwiftAgent",
			dependencies: ["Internal"],
		),
		.target(
			name: "OpenAISession",
                        dependencies: [
                                "SwiftAgent",
                                "OpenAI",
                        ],
                        path: "Sources/OpenAI",
                ),
                .target(
                        name: "OpenAI",
                        path: "Sources/OpenAIModels",
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
			dependencies: ["SwiftAgent"],
		),
	],
)
