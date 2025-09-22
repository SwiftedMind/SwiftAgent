# Foundation Models: Using Apple's On-Device LLM in Your Apps

## Overview

Foundation Models is an Apple framework that provides access to on-device large language models (LLMs) that power Apple Intelligence. This framework enables developers to enhance their apps with generative AI capabilities without requiring cloud connectivity or compromising user privacy.

Key capabilities include:
- Text generation and understanding
- Content summarization and extraction
- Structured data generation
- Custom tool integration

## Getting Started

### Check Model Availability

Always check if the model is available before attempting to use it. Model availability depends on device factors such as Apple Intelligence support, system settings, and device state.

```swift
struct GenerativeView: View {
    // Create a reference to the system language model
    private var model = SystemLanguageModel.default

    var body: some View {
        switch model.availability {
        case .available:
            // Show your intelligence UI
            Text("Model is available")
        case .unavailable(.deviceNotEligible):
            // Show an alternative UI
            Text("Device not eligible for Apple Intelligence")
        case .unavailable(.appleIntelligenceNotEnabled):
            // Ask the person to turn on Apple Intelligence
            Text("Please enable Apple Intelligence in Settings")
        case .unavailable(.modelNotReady):
            // The model isn't ready (downloading or other system reasons)
            Text("Model is downloading or not ready")
        case .unavailable(let other):
            // The model is unavailable for an unknown reason
            Text("Model unavailable: \(other)")
        }
    }
}
```

### Create a Session

After confirming model availability, create a `LanguageModelSession` to interact with the model:

```swift
// Create a basic session with the system model
let session = LanguageModelSession()

// Create a session with instructions
let instructions = """
    You are a helpful assistant that provides concise answers.
    Keep responses under 100 words and focus on clarity.
    """
let sessionWithInstructions = LanguageModelSession(instructions: instructions)
```

- For single-turn interactions, create a new session each time
- For multi-turn interactions, reuse the same session to maintain context

## Basic Usage

### Provide Instructions to the Model

Instructions help steer the model's behavior for your specific use case. The model prioritizes instructions over prompts.

Good instructions typically specify:
- The model's role (e.g., "You are a mentor")
- What the model should do (e.g., "Help extract calendar events")
- Style preferences (e.g., "Respond as briefly as possible")
- Safety measures (e.g., "Respond with 'I can't help with that' for dangerous requests")

```swift
let instructions = """
    You are a cooking assistant.
    Provide recipe suggestions based on ingredients.
    Keep suggestions brief and practical for home cooks.
    Include approximate cooking time.
    """

let session = LanguageModelSession(instructions: instructions)
```

### Provide a Prompt to the Model

A prompt is the input that the model responds to. Effective prompts are:
- Conversational (questions or commands)
- Focused on a single, specific task
- Clear about the desired output format and length

```swift
// Simple prompt
let prompt = "What's a good month to visit Paris?"

// Specific prompt with output constraints
let specificPrompt = "Write a profile for the dog breed Siberian Husky using three sentences."
```

### Generate a Response

Call the model asynchronously to get a response:

```swift
// Basic response generation
let response = try await session.respond(to: prompt)
print(response.content)

// With custom generation options
let options = GenerationOptions(temperature: 0.7)
let customResponse = try await session.respond(to: prompt, options: options)
```

Note: A session can only handle one request at a time. Check `isResponding` to verify the session is available before sending a new request.

## Advanced Features

### Guided Generation

Guided generation allows you to receive model responses as structured Swift data instead of raw strings. This provides stronger guarantees about the format of the response.

#### 1. Define a Generable Type

```swift
@Generable(description: "Basic profile information about a cat")
struct CatProfile {
    // A guide isn't necessary for basic fields
    var name: String

    @Guide(description: "The age of the cat", .range(0...20))
    var age: Int

    @Guide(description: "A one sentence profile about the cat's personality")
    var profile: String
}
```

#### 2. Request a Response in Your Custom Type

```swift
// Generate a response using the custom type
let catResponse = try await session.respond(
    to: "Generate a cute rescue cat",
    generating: CatProfile.self
)

// Use the structured data
print("Name: \(catResponse.content.name)")
print("Age: \(catResponse.content.age)")
print("Profile: \(catResponse.content.profile)")
```

#### 3. Printing a Response from your Custom Type

When printing values from a LanguageModelSession.Response always use the instance property content. Not output.

For example:

```swift
import FoundationModels
import Playgrounds

@Generable
struct CookbookSuggestions {
    @Guide(description: "Cookbook Suggestions", .count(3))
    var suggestions: [String]
}

#Playground {
    let session = LanguageModelSession()

    let prompt = "What's a good name for a cooking app?"

    let response = try await session.respond(
        to: prompt,
        generating: CookbookSuggestions.self
    )

    // Notice how print values come from content. Not output.
    print(response.content.suggestions)
}
```

### Tool Calling

Tool calling allows the model to use custom code you provide to perform specific tasks, access external data, or integrate with other frameworks.

#### 1. Create a Custom Tool

```swift
// Define a tool for searching recipes
struct RecipeSearchTool: Tool {
    struct Arguments: Codable {
        var searchTerm: String
        var numberOfResults: Int
    }
    
    func call(arguments: Arguments) async throws -> ToolOutput {
        // Search your recipe database
        let recipes = await searchRecipes(term: arguments.searchTerm, 
                                         limit: arguments.numberOfResults)
        
        // Return results as a string the model can use
        return .string(recipes.map { "- \($0.name): \($0.description)" }.joined(separator: "\n"))
    }
    
    private func searchRecipes(term: String, limit: Int) async -> [Recipe] {
        // Implementation to search your database
        // ...
    }
}
```

#### 2. Provide the Tool to a Session

```swift
// Create the tool
let recipeSearchTool = RecipeSearchTool()

// Create a session with the tool
let session = LanguageModelSession(tools: [recipeSearchTool])

// The model will automatically use the tool when appropriate
let response = try await session.respond(to: "Find me some pasta recipes")
```

#### 3. Handle Tool Errors

```swift
do {
    let answer = try await session.respond("Find a recipe for tomato soup.")
} catch let error as LanguageModelSession.ToolCallError {
    // Access the name of the tool
    print(error.tool.name) 
    
    // Access the underlying error
    if case .databaseIsEmpty = error.underlyingError as? RecipeSearchToolError {
        // Handle specific error
    }
} catch {
    print("Other error: \(error)")
}
```

## Snapshot streaming

- LLM generate text as short groups of characters called tokens.
- Typically, when streaming tokens, tokens are delivered in what's called a delta. But Foundation Models does this different.
- As deltas are produced, the responsibility for accumulating them usually falls on the developer
- You append each delta as they come in. And the response grows as you do. But it gets tricky when the result has structure.
- If you want to show the greeting string after each delta, you have to parse it out of the accumulation, and that's not trival, especially for complicated structures.
- Structured output is at the core of the Foundation Model framework. Which is why we stream snapshots.

## Snapshot streaming

- LLM generate text as short groups of characters called tokens.
- Typically, when streaming tokens, tokens are delivered in what's called a delta. But Foundation Models does this different.
- As deltas are produced, the responsibility for accumulating them usually falls on the developer
- You append each delta as they come in. And the response grows as you do. But it gets tricky when the result has structure.
- If you want to show the greeting string after each delta, you have to parse it out of the accumulation, and that's not trival, especially for complicated structures.
- Structured output is at the core of the Foundation Model framework. Which is why we stream snapshots.

### What are snapshots

- Snapshots represent partically generated response. Their properties are all optinoal. And they get filled in as the model produces more of the response.
- Snapshots are a robust and convenient representation for streaming structure output.
- You are already familar with the `@Generable` macro, and as it turns out, it's also where the definitions for partially generated types come from.
- If you expand the macro, you'll discover it produces a types named `PartiallyGenerated`. It is effectively a mirror of the outer structure except every property is optional.
- The partically generated type comes into play when you call the 'streamResponse` method on your session.

```swift
import FoundationModels
import Playgrounds

@Generable
struct TripIdeas {
    @Guide(description: "Ideas for upcoming trips")
    var ideas: [String]
}

#Playground {
    let session = LanguageModelSession()

    let prompt = "What are some exciting trip ideas for the upcoming year?"

    let stream = session.streamResponse(
        to: prompt,
        generating: TripIdeas.self
    )

    for try await partial in stream {
        print(partial)
    }
}
```

- Stream response returns an async sequence. And the elements of that sequence are instances of a partially generated type.
- Each element in the sequence will contain an updated snapshot.
- These snapshots work great with declarative frameworks like SwiftUI.
- First, create state holding a partially generated type.
- Then, just iterate over a response stream, stores its elements, and watch as your UI comes to life.

## Best Practices and Limitations

### Context Size Limits

- The system model supports up to 4,096 tokens per session
- A token is roughly 3-4 characters in languages like English
- All instructions, prompts, and outputs count toward this limit
- If you exceed the limit, you'll get a `LanguageModelSession.GenerationError.exceededContextWindowSize` error
- For large data processing, break it into smaller chunks across multiple sessions

### Optimizing Performance

- Use `GenerationOptions` to tune model behavior:
  ```swift
  let options = GenerationOptions(temperature: 2.0) // Higher temperature = more creative
  ```
- Use Xcode Instruments to monitor request performance
- Access `Transcript` entries to see model actions during a session:
  ```swift
  let transcript = session.transcript
  ```

### Prompt Engineering Tips

- Be specific about what you want
- Specify output constraints (e.g., "in three sentences")
- Break complex tasks into multiple simple prompts
- Use examples in instructions to guide the model's output format

## References

- [Generating content and performing tasks with Foundation Models](https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models)
- [Generating Swift data structures with guided generation](https://developer.apple.com/documentation/FoundationModels/generating-swift-data-structures-with-guided-generation)
- [Expanding generation with tool calling](https://developer.apple.com/documentation/FoundationModels/expanding-generation-with-tool-calling)
- [Human Interface Guidelines: Generative AI](https://developer.apple.com/design/human-interface-guidelines/technologies/generative-ai)