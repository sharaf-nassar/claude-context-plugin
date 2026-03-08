#!/usr/bin/env bash
set -euo pipefail

# Claude Context Plugin - Local Infrastructure Setup
# Installs and configures Ollama + Milvus for fully local semantic code search

MILVUS_IMAGE="milvusdb/milvus:v2.6.11"
MILVUS_CONTAINER="milvus-standalone"
OLLAMA_MODEL="nomic-embed-text"
DATA_DIR="${CLAUDE_CONTEXT_DATA_DIR:-$HOME/.claude-context}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[info]${NC} $*"; }
ok()    { echo -e "${GREEN}[ok]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $*"; }
err()   { echo -e "${RED}[error]${NC} $*"; }

check_docker() {
    if ! command -v docker &>/dev/null; then
        err "Docker is not installed."
        echo "  Install Docker: https://docs.docker.com/engine/install/"
        return 1
    fi
    if ! docker info &>/dev/null; then
        err "Docker daemon is not running or current user lacks permissions."
        echo "  Try: sudo systemctl start docker"
        echo "  Or add your user to the docker group: sudo usermod -aG docker \$USER"
        return 1
    fi
    ok "Docker is available"
}

install_ollama() {
    if command -v ollama &>/dev/null; then
        ok "Ollama is already installed ($(ollama --version 2>/dev/null || echo 'unknown version'))"
        return 0
    fi

    info "Installing Ollama..."
    if [[ "$(uname)" == "Linux" ]]; then
        curl -fsSL https://ollama.com/install.sh | sh
    elif [[ "$(uname)" == "Darwin" ]]; then
        if command -v brew &>/dev/null; then
            brew install ollama
        else
            err "On macOS, install Ollama from https://ollama.com/download or via Homebrew"
            return 1
        fi
    else
        err "Unsupported OS. Install Ollama manually from https://ollama.com/download"
        return 1
    fi

    if command -v ollama &>/dev/null; then
        ok "Ollama installed successfully"
    else
        err "Ollama installation failed"
        return 1
    fi
}

start_ollama() {
    if curl -sf http://127.0.0.1:11434/api/tags &>/dev/null; then
        ok "Ollama is running"
        return 0
    fi

    info "Starting Ollama..."
    if [[ "$(uname)" == "Linux" ]] && command -v systemctl &>/dev/null; then
        sudo systemctl start ollama 2>/dev/null || ollama serve &>/dev/null &
    else
        ollama serve &>/dev/null &
    fi

    # Wait for Ollama to be ready
    for i in $(seq 1 30); do
        if curl -sf http://127.0.0.1:11434/api/tags &>/dev/null; then
            ok "Ollama is running"
            return 0
        fi
        sleep 1
    done

    err "Ollama failed to start within 30 seconds"
    return 1
}

pull_embedding_model() {
    if ollama list 2>/dev/null | grep -q "$OLLAMA_MODEL"; then
        ok "Embedding model '$OLLAMA_MODEL' is already available"
        return 0
    fi

    info "Pulling embedding model '$OLLAMA_MODEL' (this may take a minute)..."
    ollama pull "$OLLAMA_MODEL"

    if ollama list 2>/dev/null | grep -q "$OLLAMA_MODEL"; then
        ok "Embedding model '$OLLAMA_MODEL' pulled successfully"
    else
        err "Failed to pull embedding model '$OLLAMA_MODEL'"
        return 1
    fi
}

setup_milvus() {
    # Check if container already exists and is healthy
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${MILVUS_CONTAINER}$"; then
        local health
        health=$(docker inspect --format='{{.State.Health.Status}}' "$MILVUS_CONTAINER" 2>/dev/null || echo "unknown")
        if [[ "$health" == "healthy" ]]; then
            ok "Milvus is already running and healthy"
            return 0
        fi
        warn "Milvus container exists but status is: $health. Restarting..."
        docker restart "$MILVUS_CONTAINER"
        wait_for_milvus
        return $?
    fi

    # Check if container exists but is stopped
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${MILVUS_CONTAINER}$"; then
        info "Starting existing Milvus container..."
        docker start "$MILVUS_CONTAINER"
        wait_for_milvus
        return $?
    fi

    # Fresh install
    info "Setting up Milvus at $DATA_DIR..."
    mkdir -p "$DATA_DIR/volumes/milvus"

    # Write embedded etcd config
    cat > "$DATA_DIR/embedEtcd.yaml" <<'ETCD'
listen-client-urls: http://0.0.0.0:2379
advertise-client-urls: http://0.0.0.0:2379
quota-backend-bytes: 4294967296
auto-compaction-mode: revision
auto-compaction-retention: '1000'
ETCD

    # Write user config
    cat > "$DATA_DIR/user.yaml" <<'USER'
# Extra config to override default milvus.yaml
USER

    # Write docker-compose.yml
    cat > "$DATA_DIR/docker-compose.yml" <<COMPOSE
services:
  milvus:
    image: ${MILVUS_IMAGE}
    container_name: ${MILVUS_CONTAINER}
    command: milvus run standalone
    restart: unless-stopped
    security_opt:
      - seccomp:unconfined
    environment:
      ETCD_USE_EMBED: "true"
      ETCD_DATA_DIR: /var/lib/milvus/etcd
      ETCD_CONFIG_PATH: /milvus/configs/embedEtcd.yaml
      COMMON_STORAGETYPE: local
      DEPLOY_MODE: STANDALONE
    volumes:
      - ./volumes/milvus:/var/lib/milvus
      - ./embedEtcd.yaml:/milvus/configs/embedEtcd.yaml
      - ./user.yaml:/milvus/configs/user.yaml
    ports:
      - "19530:19530"
      - "9091:9091"
      - "2379:2379"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9091/healthz"]
      interval: 30s
      start_period: 90s
      timeout: 20s
      retries: 3
COMPOSE

    info "Starting Milvus container..."
    docker compose -f "$DATA_DIR/docker-compose.yml" up -d

    wait_for_milvus
}

wait_for_milvus() {
    info "Waiting for Milvus to become healthy (this can take up to 90 seconds on first start)..."
    for i in $(seq 1 90); do
        local health
        health=$(docker inspect --format='{{.State.Health.Status}}' "$MILVUS_CONTAINER" 2>/dev/null || echo "unknown")
        if [[ "$health" == "healthy" ]]; then
            ok "Milvus is healthy"
            return 0
        fi
        sleep 1
    done

    err "Milvus did not become healthy within 90 seconds"
    echo "  Check logs: docker logs $MILVUS_CONTAINER"
    return 1
}

install_mcp_server() {
    if ! command -v npx &>/dev/null; then
        err "npx is not available. Install Node.js (18+): https://nodejs.org/"
        return 1
    fi
    ok "npx is available"

    # Check if already installed globally
    if npm list -g @zilliz/claude-context-mcp &>/dev/null; then
        local installed_version
        installed_version=$(npm list -g @zilliz/claude-context-mcp --json 2>/dev/null | grep -o '"version": *"[^"]*"' | head -1 | grep -o '"[^"]*"$' | tr -d '"')
        ok "Claude Context MCP server is already installed (v${installed_version:-unknown})"
        return 0
    fi

    info "Installing Claude Context MCP server (@zilliz/claude-context-mcp)..."
    npm install -g @zilliz/claude-context-mcp@latest

    if npm list -g @zilliz/claude-context-mcp &>/dev/null; then
        ok "Claude Context MCP server installed successfully"
    else
        err "Failed to install Claude Context MCP server"
        return 1
    fi
}

print_summary() {
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  Claude Context Plugin - Setup Complete!${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo "  Infrastructure:"
    echo "    Ollama:  http://127.0.0.1:11434"
    echo "    Milvus:  127.0.0.1:19530"
    echo "    Model:   $OLLAMA_MODEL"
    echo "    Data:    $DATA_DIR"
    echo ""
    echo "  Slash commands:"
    echo "    /claude-context:index [path]        Index a codebase"
    echo "    /claude-context:search <query>      Semantic search"
    echo "    /claude-context:status [path]       Check indexing progress"
    echo "    /claude-context:clear [path]        Clear an index"
    echo ""
    echo "  To get started, index your project:"
    echo "    /claude-context:index"
    echo ""
}

main() {
    echo ""
    echo -e "${BLUE}Claude Context Plugin - Local Infrastructure Setup${NC}"
    echo ""

    check_docker
    install_ollama
    start_ollama
    pull_embedding_model
    setup_milvus
    install_mcp_server
    print_summary
}

main "$@"
