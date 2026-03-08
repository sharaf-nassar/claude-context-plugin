---
description: Index a codebase for semantic code search
argument-hint: [path]
---

**Before doing anything else**, verify the local infrastructure is running by checking both:
1. Ollama: `curl -sf http://127.0.0.1:11434/api/tags > /dev/null`
2. Milvus: `curl -sf http://127.0.0.1:19530/v2/vectordb/collections/list -X POST -H 'Content-Type: application/json' -d '{}' > /dev/null`

If either check fails, stop and tell the user: "Local infrastructure is not running. Please run `/claude-context:setup` first to install and start Ollama and Milvus."

---

Index the codebase at the specified path for semantic search using the Claude Context MCP.

If the user provided a path: $ARGUMENTS
If no path was provided, use the current working directory.

Use the `mcp__claude-context__index_codebase` tool to index the resolved path. Use the AST splitter by default.

If indexing reports a conflict (already indexed), ask the user if they want to force re-index.

After starting, confirm the path being indexed and let the user know they can search while indexing completes.
