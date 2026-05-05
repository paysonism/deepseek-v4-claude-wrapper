#!/usr/bin/env bash

# DeepSeek Claude Installation Script
# This script installs claude-code in an isolated environment configured for DeepSeek
# Can be run directly or via curl: curl -L https://raw.githubusercontent.com/iDrwish/deepseek-claude-wrapper/main/install-deepseek-claude.sh | bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="$HOME/.deepseek-claude"
BIN_DIR="/usr/local/bin"
WRAPPER_SCRIPT="deepseek-claude"

# Available DeepSeek models
MODELS=(
    "deepseek-v4-pro"
    "deepseek-v4-flash"
    "deepseek-chat"
    "deepseek-reasoner"
)
MODEL_DESCRIPTIONS=(
    "DeepSeek V4 Pro - Strongest model for complex reasoning, coding, and agent workflows"
    "DeepSeek V4 Flash - Fast and economical for cost-efficient production use"
    "DeepSeek Chat - Legacy model (maps to V4 Flash non-thinking mode)"
    "DeepSeek Reasoner - Legacy model (maps to V4 Flash thinking mode)"
)

# Available context limits
CONTEXT_LIMITS=(
    "64000"
    "128000"
    "256000"
    "512000"
    "1000000"
)
CONTEXT_DESCRIPTIONS=(
    "64K tokens"
    "128K tokens"
    "256K tokens"
    "512K tokens"
    "1M tokens (maximum)"
)

echo -e "${BLUE}🚀 Installing DeepSeek Claude in isolated environment...${NC}"

# Detect operating system (Linux or macOS)
OS="$(uname -s)"

# Check if Node.js and npm are installed
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Error: Node.js is not installed. Please install Node.js first.${NC}"
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo -e "${RED}❌ Error: npm is not installed. Please install npm first.${NC}"
    exit 1
fi

# Check for DeepSeek API key
if [ -z "$DEEPSEEK_API_KEY" ]; then
    echo -e "${YELLOW}⚠️  Warning: DEEPSEEK_API_KEY environment variable is not set.${NC}"
    echo -e "${YELLOW}   You can set it later by running: export DEEPSEEK_API_KEY=your_api_key${NC}"
    echo -e "${YELLOW}   Or add it to your shell profile (~/.bashrc, ~/.zshrc, etc.)${NC}"
    echo ""
fi

# Detect if running interactively (has a TTY)
IS_INTERACTIVE=false
if [ -t 0 ]; then
    IS_INTERACTIVE=true
fi

# Model selection function
select_models() {
    local selected_primary=""
    local selected_small=""
    local selected_context=""

    if [ "$IS_INTERACTIVE" = true ]; then
        echo ""
        echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${CYAN}║              🧠 DeepSeek Model Configuration                ║${NC}"
        echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        # Select primary model
        echo -e "${BOLD}Select your PRIMARY model (for complex tasks):${NC}"
        echo ""
        for i in "${!MODELS[@]}"; do
            echo -e "  ${GREEN}$((i+1)))${NC} ${MODEL_DESCRIPTIONS[$i]}"
        done
        echo ""
        while true; do
            read -r -p "Enter choice [1-${#MODELS[@]}] (default: 1 - deepseek-v4-pro): " choice
            choice="${choice:-1}"
            if [[ "$choice" =~ ^[1-4]$ ]]; then
                selected_primary="${MODELS[$((choice-1))]}"
                break
            fi
            echo -e "${RED}Invalid choice. Please enter 1-${#MODELS[@]}.${NC}"
        done
        echo -e "${GREEN}  ✓ Primary model: $selected_primary${NC}"
        echo ""

        # Select small/fast model
        echo -e "${BOLD}Select your SMALL/FAST model (for quick tasks):${NC}"
        echo ""
        for i in "${!MODELS[@]}"; do
            echo -e "  ${GREEN}$((i+1)))${NC} ${MODEL_DESCRIPTIONS[$i]}"
        done
        echo ""
        while true; do
            read -r -p "Enter choice [1-${#MODELS[@]}] (default: 2 - deepseek-v4-flash): " choice
            choice="${choice:-2}"
            if [[ "$choice" =~ ^[1-4]$ ]]; then
                selected_small="${MODELS[$((choice-1))]}"
                break
            fi
            echo -e "${RED}Invalid choice. Please enter 1-${#MODELS[@]}.${NC}"
        done
        echo -e "${GREEN}  ✓ Small/fast model: $selected_small${NC}"
        echo ""

        # Select context limit
        echo -e "${BOLD}Select context window limit:${NC}"
        echo ""
        for i in "${!CONTEXT_LIMITS[@]}"; do
            echo -e "  ${GREEN}$((i+1)))${NC} ${CONTEXT_DESCRIPTIONS[$i]}"
        done
        echo ""
        while true; do
            read -r -p "Enter choice [1-${#CONTEXT_LIMITS[@]}] (default: 5 - 1M tokens): " choice
            choice="${choice:-5}"
            if [[ "$choice" =~ ^[1-5]$ ]]; then
                selected_context="${CONTEXT_LIMITS[$((choice-1))]}"
                break
            fi
            echo -e "${RED}Invalid choice. Please enter 1-${#CONTEXT_LIMITS[@]}.${NC}"
        done
        echo -e "${GREEN}  ✓ Context limit: $selected_context tokens${NC}"
        echo ""
    else
        # Non-interactive defaults
        selected_primary="deepseek-v4-pro"
        selected_small="deepseek-v4-flash"
        selected_context="1000000"
        echo -e "${BLUE}📋 Using default model configuration (non-interactive mode):${NC}"
        echo -e "   Primary model: $selected_primary"
        echo -e "   Small/fast model: $selected_small"
        echo -e "   Context limit: $selected_context tokens"
        echo ""
    fi

    # Write config file
    cat > "$INSTALL_DIR/config.env" << CONFIGEOF
# DeepSeek Claude Configuration
# Edit this file or run 'deepseek-claude set-model' to change settings
DEEPSEEK_PRIMARY_MODEL="$selected_primary"
DEEPSEEK_SMALL_MODEL="$selected_small"
DEEPSEEK_CONTEXT_LIMIT="$selected_context"
CONFIGEOF

    echo -e "${GREEN}✅ Configuration saved to $INSTALL_DIR/config.env${NC}"
}

# Create installation directory
echo -e "${BLUE}📁 Creating installation directory: $INSTALL_DIR${NC}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Initialize npm project if package.json doesn't exist
if [ ! -f "package.json" ]; then
    echo -e "${BLUE}📦 Initializing npm project...${NC}"
    cat > package.json << 'PACKAGE_JSON'
{
  "name": "deepseek-claude-installation",
  "version": "1.0.0",
  "description": "DeepSeek Claude isolated installation",
  "private": true
}
PACKAGE_JSON
fi

# Install claude-code locally
echo -e "${BLUE}⬇️  Installing @anthropic-ai/claude-code...${NC}"
npm install @anthropic-ai/claude-code

# Run model selection
select_models

# Create the wrapper script
echo -e "${BLUE}📝 Creating wrapper script...${NC}"
cat > "$INSTALL_DIR/$WRAPPER_SCRIPT" << 'EOF'
#!/bin/bash

# DeepSeek Claude Wrapper Script
# This script sets up DeepSeek environment variables and launches claude-code

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"

# Available models and context limits (for set-model command)
MODELS=("deepseek-v4-pro" "deepseek-v4-flash" "deepseek-chat" "deepseek-reasoner")
MODEL_DESCRIPTIONS=(
    "DeepSeek V4 Pro - Strongest model for complex reasoning, coding, and agent workflows"
    "DeepSeek V4 Flash - Fast and economical for cost-efficient production use"
    "DeepSeek Chat - Legacy model (maps to V4 Flash non-thinking mode)"
    "DeepSeek Reasoner - Legacy model (maps to V4 Flash thinking mode)"
)
CONTEXT_LIMITS=("64000" "128000" "256000" "512000" "1000000")
CONTEXT_DESCRIPTIONS=("64K tokens" "128K tokens" "256K tokens" "512K tokens" "1M tokens (maximum)")

# Load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    else
        DEEPSEEK_PRIMARY_MODEL="deepseek-v4-pro"
        DEEPSEEK_SMALL_MODEL="deepseek-v4-flash"
        DEEPSEEK_CONTEXT_LIMIT="1000000"
    fi
}

# Handle 'set-model' command - interactive model reconfiguration
handle_set_model() {
    echo ""
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║              🧠 DeepSeek Model Configuration                ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    load_config
    echo -e "${BLUE}Current configuration:${NC}"
    echo -e "  Primary model:  $DEEPSEEK_PRIMARY_MODEL"
    echo -e "  Small/fast model: $DEEPSEEK_SMALL_MODEL"
    echo -e "  Context limit:  $DEEPSEEK_CONTEXT_LIMIT tokens"
    echo ""

    # Select primary model
    echo -e "${BOLD}Select your PRIMARY model (for complex tasks):${NC}"
    echo ""
    for i in "${!MODELS[@]}"; do
        local marker=""
        if [ "${MODELS[$i]}" = "$DEEPSEEK_PRIMARY_MODEL" ]; then
            marker=" ${CYAN}(current)${NC}"
        fi
        echo -e "  ${GREEN}$((i+1)))${NC} ${MODEL_DESCRIPTIONS[$i]}$marker"
    done
    echo ""
    while true; do
        read -r -p "Enter choice [1-${#MODELS[@]}] (default: keep current): " choice
        if [ -z "$choice" ]; then
            break
        fi
        if [[ "$choice" =~ ^[1-4]$ ]]; then
            DEEPSEEK_PRIMARY_MODEL="${MODELS[$((choice-1))]}"
            break
        fi
        echo -e "${RED}Invalid choice. Please enter 1-${#MODELS[@]} or press Enter to keep current.${NC}"
    done
    echo -e "${GREEN}  ✓ Primary model: $DEEPSEEK_PRIMARY_MODEL${NC}"
    echo ""

    # Select small/fast model
    echo -e "${BOLD}Select your SMALL/FAST model (for quick tasks):${NC}"
    echo ""
    for i in "${!MODELS[@]}"; do
        local marker=""
        if [ "${MODELS[$i]}" = "$DEEPSEEK_SMALL_MODEL" ]; then
            marker=" ${CYAN}(current)${NC}"
        fi
        echo -e "  ${GREEN}$((i+1)))${NC} ${MODEL_DESCRIPTIONS[$i]}$marker"
    done
    echo ""
    while true; do
        read -r -p "Enter choice [1-${#MODELS[@]}] (default: keep current): " choice
        if [ -z "$choice" ]; then
            break
        fi
        if [[ "$choice" =~ ^[1-4]$ ]]; then
            DEEPSEEK_SMALL_MODEL="${MODELS[$((choice-1))]}"
            break
        fi
        echo -e "${RED}Invalid choice. Please enter 1-${#MODELS[@]} or press Enter to keep current.${NC}"
    done
    echo -e "${GREEN}  ✓ Small/fast model: $DEEPSEEK_SMALL_MODEL${NC}"
    echo ""

    # Select context limit
    echo -e "${BOLD}Select context window limit:${NC}"
    echo ""
    for i in "${!CONTEXT_LIMITS[@]}"; do
        local marker=""
        if [ "${CONTEXT_LIMITS[$i]}" = "$DEEPSEEK_CONTEXT_LIMIT" ]; then
            marker=" ${CYAN}(current)${NC}"
        fi
        echo -e "  ${GREEN}$((i+1)))${NC} ${CONTEXT_DESCRIPTIONS[$i]}$marker"
    done
    echo ""
    while true; do
        read -r -p "Enter choice [1-${#CONTEXT_LIMITS[@]}] (default: keep current): " choice
        if [ -z "$choice" ]; then
            break
        fi
        if [[ "$choice" =~ ^[1-5]$ ]]; then
            DEEPSEEK_CONTEXT_LIMIT="${CONTEXT_LIMITS[$((choice-1))]}"
            break
        fi
        echo -e "${RED}Invalid choice. Please enter 1-${#CONTEXT_LIMITS[@]} or press Enter to keep current.${NC}"
    done
    echo -e "${GREEN}  ✓ Context limit: $DEEPSEEK_CONTEXT_LIMIT tokens${NC}"
    echo ""

    # Save config
    cat > "$CONFIG_FILE" << CONFIGEOF
# DeepSeek Claude Configuration
# Edit this file or run 'deepseek-claude set-model' to change settings
DEEPSEEK_PRIMARY_MODEL="$DEEPSEEK_PRIMARY_MODEL"
DEEPSEEK_SMALL_MODEL="$DEEPSEEK_SMALL_MODEL"
DEEPSEEK_CONTEXT_LIMIT="$DEEPSEEK_CONTEXT_LIMIT"
CONFIGEOF

    echo -e "${GREEN}✅ Configuration saved!${NC}"
    echo ""
    echo -e "${BLUE}New configuration:${NC}"
    echo -e "  Primary model:    $DEEPSEEK_PRIMARY_MODEL"
    echo -e "  Small/fast model: $DEEPSEEK_SMALL_MODEL"
    echo -e "  Context limit:    $DEEPSEEK_CONTEXT_LIMIT tokens"
    echo ""
    exit 0
}

# Handle 'show-config' command
handle_show_config() {
    load_config
    echo ""
    echo -e "${BOLD}${CYAN}DeepSeek Claude Configuration${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  Primary model:    ${GREEN}$DEEPSEEK_PRIMARY_MODEL${NC}"
    echo -e "  Small/fast model: ${GREEN}$DEEPSEEK_SMALL_MODEL${NC}"
    echo -e "  Context limit:    ${GREEN}$DEEPSEEK_CONTEXT_LIMIT tokens${NC}"
    echo -e "  Config file:      $CONFIG_FILE"
    echo ""
    echo -e "${BLUE}To change: ${NC}deepseek-claude set-model"
    echo ""
    exit 0
}

# Check if DEEPSEEK_API_KEY is set (skip for config commands)
if [ "$1" != "set-model" ] && [ "$1" != "show-config" ]; then
    if [ -z "$DEEPSEEK_API_KEY" ]; then
        echo "❌ Error: DEEPSEEK_API_KEY environment variable is not set."
        echo "Please set it by running: export DEEPSEEK_API_KEY=your_api_key"
        echo "Or add it to your shell profile (~/.bashrc, ~/.zshrc, etc.)"
        exit 1
    fi
fi

# Handle custom commands
case "$1" in
    set-model)
        handle_set_model
        ;;
    show-config)
        handle_show_config
        ;;
esac

# Handle the 'update' command specifically
if [ "$1" = "update" ]; then
    echo -e "${BLUE}🔄 Updating DeepSeek Claude...${NC}"
    
    # Check current version
    CURRENT_VERSION=$(npm list @anthropic-ai/claude-code --depth=0 --prefix="$SCRIPT_DIR" 2>/dev/null | grep @anthropic-ai/claude-code | cut -d@ -f3)
    echo -e "${BLUE}📋 Current version: v$CURRENT_VERSION${NC}"
    
    # Check latest version
    echo -e "${BLUE}🔍 Checking for updates...${NC}"
    LATEST_VERSION=$(npm view @anthropic-ai/claude-code version 2>/dev/null)
    echo -e "${BLUE}   Latest: v$LATEST_VERSION${NC}"
    
    if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
        echo -e "${GREEN}✅ Already up to date!${NC}"
        exit 0
    fi
    
    # Update the package
    echo -e "${BLUE}⬇️  Updating @anthropic-ai/claude-code...${NC}"
    cd "$SCRIPT_DIR"
    npm update @anthropic-ai/claude-code
    
    # Verify update
    NEW_VERSION=$(npm list @anthropic-ai/claude-code --depth=0 2>/dev/null | grep @anthropic-ai/claude-code | cut -d@ -f3)
    
    if [ "$NEW_VERSION" = "$LATEST_VERSION" ]; then
        echo -e "${GREEN}🎉 Update successful!${NC}"
        echo -e "${GREEN}   Updated from v$CURRENT_VERSION to v$NEW_VERSION${NC}"
    else
        echo -e "${RED}❌ Update may have failed. Current version: v$NEW_VERSION${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${BLUE}🚀 DeepSeek Claude is now ready with the latest version!${NC}"
    exit 0
fi

# Load configuration for runtime
load_config

# Set DeepSeek environment variables from config
export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
export ANTHROPIC_AUTH_TOKEN="$DEEPSEEK_API_KEY"
export ANTHROPIC_MODEL="$DEEPSEEK_PRIMARY_MODEL"
export ANTHROPIC_SMALL_FAST_MODEL="$DEEPSEEK_SMALL_MODEL"
export CLAUDE_CODE_MAX_CONTEXT_TOKENS="$DEEPSEEK_CONTEXT_LIMIT"

# Run claude-code from the isolated installation with all arguments
exec "$SCRIPT_DIR/node_modules/.bin/claude" "$@"
EOF

# Make the wrapper script executable
chmod +x "$INSTALL_DIR/$WRAPPER_SCRIPT"

# Add to PATH instead of using symlink (avoids sudo requirement)
echo -e "${BLUE}🔗 Adding to PATH...${NC}"
SHELL_PROFILE=""
if [ "$SHELL" = "/bin/zsh" ] || [ "$SHELL" = "/usr/bin/zsh" ]; then
    # zsh uses the same profile file on macOS and Linux
    SHELL_PROFILE="$HOME/.zshrc"
elif [ "$SHELL" = "/bin/bash" ] || [ "$SHELL" = "/usr/bin/bash" ]; then
    if [ "$OS" = "Darwin" ]; then
        SHELL_PROFILE="$HOME/.bash_profile"
    else
        SHELL_PROFILE="$HOME/.bashrc"
    fi
fi

if [ -n "$SHELL_PROFILE" ]; then
    if ! grep -q "/.deepseek-claude:" "$SHELL_PROFILE" 2>/dev/null; then
        echo "export PATH=\"\$HOME/.deepseek-claude:\$PATH\"" >> "$SHELL_PROFILE"
        echo -e "${GREEN}✅ Added to PATH in $SHELL_PROFILE${NC}"
        echo -e "${YELLOW}⚠️  Run 'source $SHELL_PROFILE' or restart your terminal to activate${NC}"
    else
        echo -e "${GREEN}✅ Already in PATH${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Could not detect shell profile. Manually add to your PATH:${NC}"
    echo -e "${YELLOW}   export PATH=\"$INSTALL_DIR:\$PATH\"${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Installation completed successfully!${NC}"
echo ""
echo -e "${BLUE}📋 Usage Instructions:${NC}"
echo -e "1. Set your DeepSeek API key:"
echo -e "   ${YELLOW}export DEEPSEEK_API_KEY=your_api_key_here${NC}"
echo ""
echo -e "2. Navigate to your project directory and run:"
echo -e "   ${YELLOW}deepseek-claude${NC}"
echo ""
echo -e "${BLUE}📚 Additional Information:${NC}"
echo -e "• Your original claude installation remains untouched"
echo -e "• DeepSeek Claude is installed in: $INSTALL_DIR"
echo -e "• The command 'deepseek-claude' is now available system-wide"
echo -e "• To change models: ${YELLOW}deepseek-claude set-model${NC}"
echo -e "• To view config:   ${YELLOW}deepseek-claude show-config${NC}"
echo -e "• To uninstall, simply run: rm -rf $INSTALL_DIR"
echo ""
echo -e "${BLUE}🔧 Configuration:${NC}"
# shellcheck source=/dev/null
source "$INSTALL_DIR/config.env"
echo -e "• Primary model:    $DEEPSEEK_PRIMARY_MODEL"
echo -e "• Small/fast model: $DEEPSEEK_SMALL_MODEL"
echo -e "• Context limit:    $DEEPSEEK_CONTEXT_LIMIT tokens"
echo -e "• Base URL:         https://api.deepseek.com/anthropic"
echo ""
