// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public protocol TranscriptDecodable: Equatable {
	associatedtype ResolvedToolRun: Equatable
	associatedtype PartiallyResolvedToolRun: Equatable
	var allTools: [any ToolDecodable<Self>] { get }
}
