// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public protocol TranscriptResolvable {
	associatedtype ResolvedToolRun: Equatable
	associatedtype PartiallyResolvedToolRun: Equatable
	associatedtype Grounding: GroundingDecodable
	var allTools: [any ResolvableTool<Self>] { get }
	
	static func encodeGrounding(_ grounding: [Grounding]) throws -> Data
	static func decodeGrounding(from data: Data) throws -> [Grounding]
}

public struct DefaultTranscriptResolver: TranscriptResolvable {
	public var allTools: [any ResolvableTool<Self>]
	
	public static func encodeGrounding(_ grounding: [Grounding]) throws -> Data {
		Data()
	}
	
	public static func decodeGrounding(from data: Data) throws -> [Grounding] {
		[]
	}
	
	package init(allTools: [any ResolvableTool<Self>] = []) {
		self.allTools = allTools
	}
	
	public struct Grounding: GroundingDecodable {}
	public struct ResolvedToolRun: Equatable {}
	public struct PartiallyResolvedToolRun: Equatable {}
}
