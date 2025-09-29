// By Dennis Müller

import FoundationModels
import OpenAISession
import SwiftUI

struct StreamingToolArgumentsExampleView: View {
  @State private var streamedToolArgumentsText: String = "Tool arguments will stream here."
  @Bindable private var movieDatabase: MovieDatabase = .shared

  var body: some View {
		List {
			
		}
		.safeAreaBar(edge: .bottom) {
			// Text Field and send button
		}
  }
}

// MARK: - Data Structures

@Generable
private struct Movie {
  var title: String
  var summary: String
  var actors: [String]
  var year: Int
  var genres: [String]
}

@MainActor @Observable
private class MovieDatabase {
  static let shared = MovieDatabase()
  var movies: [Movie] = []

  func addMovie(_ movie: Movie) {
    movies.append(movie)
  }
}

// MARK: - Tools

#tools(accessLevel: .fileprivate) {
  AddMovieTool()
}

private struct AddMovieTool: SwiftAgentTool {
  let name = "add_movie"
  let description = "Add a movie"

  @Generable
	struct Arguments: Equatable {
    @Guide(description: "The title of the movie.")
    var title: String

    @Guide(description: "The summary of the movie.")
    var summary: String

    @Guide(description: "The list of actors starring in the movie.")
    var actors: [String]

    @Guide(description: "The year in which this movie was published.")
    var year: Int

    @Guide(description: "The list of genres of the movie.")
    var genres: [String]
  }

  @Generable
  struct Output: Equatable {
    var success: Bool
  }

  func call(arguments: Arguments) async throws -> Output {
    await MovieDatabase.shared.addMovie(Movie(
      title: arguments.title,
      summary: arguments.summary,
      actors: arguments.actors,
      year: arguments.year,
      genres: arguments.genres,
    ))
    return Output(success: true)
  }
}

#Preview {
  NavigationStack {
    StreamingToolArgumentsExampleView()
  }
  .preferredColorScheme(.dark)
}
