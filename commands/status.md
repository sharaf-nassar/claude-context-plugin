---
description: Check indexing progress for a codebase
argument-hint: [path]
---

**Before doing anything else**, verify the local infrastructure is running by checking both:
1. Ollama: `curl -sf http://127.0.0.1:11434/api/tags > /dev/null`
2. Milvus: `curl -sf http://127.0.0.1:19530/v2/vectordb/collections/list -X POST -H 'Content-Type: application/json' -d '{}' > /dev/null`

If either check fails, stop and tell the user: "Local infrastructure is not running. Please run `/claude-context:setup` first to install and start Ollama and Milvus."

---

Check the indexing status of a codebase using the Claude Context MCP.

If the user provided a path: $ARGUMENTS
If no path was provided, use the current working directory.

Use the `mcp__claude-context__get_indexing_status` tool with the resolved path.

Report the status clearly - whether indexing is in progress (with percentage), complete, or not started.
