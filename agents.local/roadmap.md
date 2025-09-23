# SwiftAgent Roadmap

Roadmap/Ideas. There aren't set in stone. They are more about brainstorming ideas.

## 1) Core Agent Loop

- Robust stop conditions: configurable `allowedSteps`, provider finish reasons, tool‑call limits.
- Cancellation: propagate Task cancellation to HTTP calls; expose `cancel()` on `Agent`.
- Retry & backoff: network and 5xx retries with exponential backoff; respect rate limits (429).
- Timeouts: per‑step and overall run timeouts; per‑tool timeout.
- Error model: unify errors with actionable contexts; preserve provider details.
- Content refusal handling: surface refusals with structured context and guidance.
- Proper support for custom backend relay

## 2) Tooling

- Tool sandboxing: per‑tool timeout, retries, and circuit‑breaker style failure tracking.
- Streaming tool outputs: yield partial output segments (text or structured) where applicable.

## 3) Adapters

- OpenAI: fix request option mismatches, add finish reasons, token usage, and cost surfaces.
- Anthropic: add adapter parity with tool calls and structured output.
- Google: add Gemini adapter with conservative surface focused on text + tools.
- Local: design adapter protocol for local models (e.g., MLX/llama.cpp) behind an async interface.

## 4) Prompting & Memory

- Context windows: automatic truncation policy with summaries to stay within token budget.

## 5) Transcript & Persistence

- Serialization: encode/decode `AgentTranscript` with metadata for persistence.

## 6) Structured Output

- Streaming structured output: incremental updates into a Generable builder type.
- Validation: schema validation errors with pinpointed locations and helpful diagnostics.

## 7) API Ergonomics

- Generation options: align README and code; expose `allowedSteps`; sensible defaults per adapter.
- Nice SwiftUI integration: `@Observable` agent already; add lightweight view helpers and samples.
- Concurrency correctness: mark boundaries `@MainActor`/`Sendable` appropriately; document rules.

## 8) Logging & Metrics

- Metrics: token usage, tool latency, retries, error rates; pluggable metrics sink.

## 9) Testing & Quality

- Unit tests: Agent loop (tool calls, refusals), ToolResolver, JSON post‑processing, HTTP error map.
- Adapter tests: mock `HTTPClient` to simulate provider responses and edge cases.
- Contract tests: ensure schema and transcript mapping remain stable across changes.

---

## Notable Gaps Discovered

- README mentions `allowedSteps`; code currently hardcodes steps (20) and lacks this option.
- Example App files are not present; README in Examples appears to be from another project.

## Sequenced Plan (MVP → Stable)

1. Schema compliance + tests (OpenAI tools) [blockers for reliable tools]
2. Generation options alignment (`allowedSteps`, fix `maxToolCalls`) + README sync
3. Agent loop reliability: cancellation, retries/backoff, timeouts
4. Observability hooks + basic metrics, token usage, finish reasons
5. Example App v1 with streaming UI and tool runs
6. Adapter #2 (Anthropic) to validate abstraction boundaries
7. Persistence of transcript and memory summarization

