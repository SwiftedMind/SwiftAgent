// By Dennis Müller

import SwiftUI

struct ExampleListView: View {
	@State private var navigationPath = NavigationPath()

	var body: some View {
		NavigationStack(path: $navigationPath) {
			List {
				ForEach(ExampleSectionCatalog.allCases) { section in
					Section(section.title) {
						ForEach(section.examples) { example in
							NavigationLink(value: example) {
								ExampleRow(example: example)
							}
						}
					}
				}
			}
			.navigationTitle("SwiftAgent Examples")
			.navigationBarTitleDisplayMode(.inline)
			.listStyle(.insetGrouped)
			.navigationDestination(for: ExampleCatalog.self) { example in
				example.destinationView
					.navigationTitle(example.title)
					.navigationBarTitleDisplayMode(.inline)
			}
		}
	}
}

private struct ExampleRow: View {
	var example: ExampleCatalog

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(example.title)
				.font(.headline)
			Text(example.summary)
				.font(.subheadline)
				.foregroundStyle(.secondary)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}

enum ExampleSectionCatalog: Identifiable, CaseIterable, Hashable {
	case agentPlayground

	var id: Self { self }
	
	var title: LocalizedStringKey {
		switch self {
		case .agentPlayground:
			"Agent Playground"
		}
	}

	var examples: [ExampleCatalog] {
		switch self {
		case .agentPlayground:
			[.conversationalAgent]
		}
	}
}

enum ExampleCatalog: Identifiable, CaseIterable, Hashable {
	case conversationalAgent

	var id: Self { self }
	
	var title: LocalizedStringKey {
		switch self {
		case .conversationalAgent:
			"Conversational Agent"
		}
	}

	var summary: LocalizedStringKey {
		switch self {
		case .conversationalAgent:
			"Chat with SwiftAgent, issue tool requests, and inspect responses."
		}
	}

	@ViewBuilder
	var destinationView: some View {
		switch self {
		case .conversationalAgent:
			ConversationalAgentExampleView()
		}
	}
}

#Preview {
	ExampleListView()
		.preferredColorScheme(.dark)
}
