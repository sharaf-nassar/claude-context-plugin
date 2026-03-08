---
description: Search indexed codebase using natural language
argument-hint: <query> [path]
---

**Before doing anything else**, verify the local infrastructure is running by checking both:
1. Ollama: `curl -sf http://127.0.0.1:11434/api/tags > /dev/null`
2. Milvus: `curl -sf http://127.0.0.1:19530/v2/vectordb/collections/list -X POST -H 'Content-Type: application/json' -d '{}' > /dev/null`

If either check fails, stop and tell the user: "Local infrastructure is not running. Please run `/claude-context:setup` first to install and start Ollama and Milvus."

---

Search the indexed codebase using natural language via the Claude Context MCP.

The user's query: $ARGUMENTS

Parse the arguments:
- The query is required (everything before an optional absolute path at the end)
- If a path is provided as the last argument (starts with /), use it
- If no path is provided, use the current working directory

Use the `mcp__claude-context__search_code` tool with the query and path.

Present the results clearly, showing file paths and relevant code snippets. If the codebase is not indexed, suggest running `/claude-context:index` first.
