---
description: Install and configure local infrastructure (Ollama + Milvus) for semantic code search
argument-hint:
---

Set up the local infrastructure required for Claude Context semantic code search.

This will:
1. Install Ollama (if not already installed)
2. Start Ollama and pull the nomic-embed-text embedding model
3. Install and start Milvus vector database via Docker
4. Verify the MCP package is available via npx

Run the setup script:

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh
```

Use the Bash tool to execute the above command. After the script completes, report the results to the user.

If any step fails, explain what went wrong and how to fix it manually.

After successful setup, suggest the user try `/claude-context:index` to index their first codebase.
