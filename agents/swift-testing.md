# Swift Testing

## Basics

- **Add Swift Testing to an existing project:**
  Simply add a new Swift file, import the `Testing` framework, and start writing tests—no build or project configuration required.

  ```swift
  import Testing

  @Test func swiftTestingExample() {
    // do setup
    #expect(true, "This test will always pass")
    // do teardown
  }
  ```

- **Organize tests in suites:**
  Group related tests in a class or struct. Use `init()` for setup and `deinit` for teardown—each test runs on its own instance.

  ```swift
  class MyTestSuite {
    init() {
      // setup
    }

    deinit {
      // teardown
    }

    @Test func testWillPass() {
      #expect(true, "This test will always pass")
    }

    @Test func testWillFail() {
      #expect(1 == 2, "This test will always fail")
    }
  }
  ```

- **Async & throwing tests:**
  Mark test functions as `async throws` to await asynchronous code directly.

  ```swift
  class TestMyViewModel {
    var viewModel = ExercisesViewModel()

    @Test func testFetchExercises() async throws {
      let exercises = try await viewModel.fetchExercises()
      #expect(exercises.count > 0, "Exercises should be fetched")
    }
  }
  ```

- **Assertions with `#expect`:**
  Use `#expect(_:_:)` for boolean checks and the `throws:` variant for error assertions.

  ```swift
  // Boolean expectation
  #expect(true, "This test will always pass")

  // Thrown‑error expectation
  @Test("Validate missing exercises error") func throwErrorOnMissingExercises() async {
    await #expect(
      throws: FetchExercisesError.noExercisesFound,
      "An error should be thrown when no exercises are found",
      performing: { try await viewModel.fetchExercises() }
    )
  }
  ```

- **Custom display names:**
  Provide a human‑readable name via the `@Test("…")` argument.

  ```swift
  @Test("Test fetching exercises")
  func testFetchExercises() async throws {
    let exercises = try await viewModel.fetchExercises()
    #expect(exercises.count > 0, "Exercises should be fetched")
  }
  ```

- **Compatibility:**
  Works out of the box with Swift packages, executables, libraries, and any other Swift target.

- **Isolation & parallelism:**
  Every test runs on a fresh instance, and suites execute tests in parallel to speed up your feedback loop.

- **Implicit suites with `@Suite`:**
  Decorate a type as a test suite to treat all its methods as tests, eliminating the need for `@Test` on each method.

  ```swift
  @Suite
  struct MathTests {
    func addition() {
      #expect(1 + 1 == 2)
    }
  }
  ```

- **Tags & traits for customization:**
  Add metadata and control execution with traits like `.tags`, `.enabled`, `.timeLimit`, and `.disabled`.

  ```swift
  extension Tag {
    @Tag static var parsing: Self
  }

  @Suite(.tags(.parsing))
  struct WifiParserTests { ... }

  @Test(.enabled(when: Config.isCIRun))
  func testCIOnly() { ... }

  @Test(.timeLimit(.minutes(3)))
  func testWithTimeout() async throws { ... }

  @Test(.disabled("ignore for this loop"))
  func testSkipped() {}
  ```

- **Handling optional unwrapping with `#require`:**
  Unwrap optionals or stop execution if value is `nil`.

  ```swift
  @Test
  func testNetworkParsing() throws {
    let network = try sut.parse(wifi: wifiString)
    let security = try #require(network.security)
    #expect(security == "WPA")
  }
  ```

- **Parameterized tests:**
  Run a single test function with multiple inputs by passing arguments to `@Test`.

  ```swift
  @Test(arguments: [2, 3, 4, 5])
  func testIsEven(number: Int) {
    #expect(number % 2 == 0)
  }
  ```

- **Marking known failures with `withKnownIssue`:**
  Record expected failures and have them reported if they start passing.

  ```swift
  @Test
  func testKnownIssue() {
    withKnownIssue {
      #expect(false)
    }
  }
  ```
