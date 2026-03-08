# Claude Context Plugin

A Claude Code plugin for fully local semantic code search, built on top of [Claude Context](https://github.com/zilliztech/claude-context) by [Zilliz](https://zilliz.com/). Uses Ollama for embeddings and Milvus as the vector database — no API keys, no cloud dependencies, zero cost.

## Installation

### From GitHub (recommended)

Add this repo as a plugin marketplace, then install the plugin:

**CLI (outside Claude Code):**

```bash
claude plugin marketplace add sharaf-nassar/claude-context-plugin
claude plugin install claude-context@claude-context-plugin
```

**REPL (inside a Claude Code session):**

```
/plugin marketplace add sharaf-nassar/claude-context-plugin
/plugin install claude-context@claude-context-plugin
```

You can also use the interactive plugin manager inside Claude Code:

```
/plugin
```

Navigate to the **Discover** tab to find and install the plugin.

### From a local clone

If you've cloned the repo locally, add it as a marketplace by path:

```bash
claude plugin marketplace add /path/to/claude-context-plugin
claude plugin install claude-context@claude-context-plugin
```

### Development mode

Load the plugin for a single session without installing:

```bash
claude --plugin-dir /path/to/claude-context-plugin
```

### Requirements

- **Claude Code v1.0.33+** — plugin support requires this version or later

## Setup

After installing, run the setup command to install and configure the local infrastructure:

```
/claude-context:setup
```

This will:
- Install [Ollama](https://ollama.com/) if not present
- Pull the `nomic-embed-text` embedding model
- Start a [Milvus](https://milvus.io/) standalone instance via Docker
- Verify everything is connected

### Prerequisites

- **Docker** — required for running Milvus
- **Node.js 18+** — required for npx to run the MCP server

## Usage

### Index a codebase

```
/claude-context:index [path]
```

Indexes the codebase at the given path (defaults to current directory) for semantic search using AST-aware code splitting.

### Search

```
/claude-context:search <query> [path]
```

Search the indexed codebase using natural language queries. Returns relevant code snippets ranked by semantic similarity.

### Check status

```
/claude-context:status [path]
```

Check whether indexing is in progress, complete, or not started.

### Clear index

```
/claude-context:clear [path]
```

Remove the search index for a codebase.

## Architecture

```
User (Claude Code)
  └─ Slash Commands (/claude-context:*)
       └─ MCP Server (@zilliz/claude-context-mcp)
            ├─ Ollama (http://127.0.0.1:11434)
            │    └─ nomic-embed-text model
            └─ Milvus (127.0.0.1:19530)
                 └─ Vector storage (~/.claude-context/volumes/)
```

All processing stays on your machine. Embeddings are generated locally via Ollama, stored and searched locally via Milvus.

## Configuration

Data is stored at `~/.claude-context/` by default. Override with:

```bash
export CLAUDE_CONTEXT_DATA_DIR=/custom/path
```

The MCP server environment can be customized in `.claude-plugin/plugin.json`:

| Variable | Default | Description |
|----------|---------|-------------|
| `EMBEDDING_PROVIDER` | `Ollama` | Embedding provider |
| `OLLAMA_HOST` | `http://127.0.0.1:11434` | Ollama server address |
| `OLLAMA_MODEL` | `nomic-embed-text` | Embedding model name |
| `MILVUS_ADDRESS` | `127.0.0.1:19530` | Milvus server address |

## Credits

This plugin wraps [Claude Context](https://github.com/zilliztech/claude-context) by [Zilliz](https://zilliz.com/), which provides the MCP server powering the semantic search functionality. This plugin adds a Claude Code plugin layer on top — with slash commands, automated local infrastructure setup, and opinionated defaults for a fully local workflow.

## License

MIT
