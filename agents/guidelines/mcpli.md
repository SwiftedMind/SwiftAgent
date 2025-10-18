# MCPLI

**What it is**  
Turns any *stdio‑based* MCP server into a first‑class, script‑friendly CLI. Tools become shell commands you can chain/pipeline.

**Why it exists**  
Avoids loading huge MCP tool schemas into model context. Keeps MCP compatibility while letting you compose results with normal shell tools (e.g., `jq`, `grep`).

**Core idea**  
Run tools like: `mcpli <tool> [--params...] -- <mcp-server-command> [args...]`. Auto‑generated `--help` for both CLI and tools.
 with `--help`, then issue concise CLI calls.  
