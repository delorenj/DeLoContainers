#!/usr/bin/env bash
set -euo pipefail

# Install qBittorrent search plugins programmatically
# Usage: ./install-search-plugins.sh [plugin_names...]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS_FILE="$SCRIPT_DIR/../SEARCH_PLUGINS.md"
PLUGINS_DIR="$SCRIPT_DIR/../qbittorrent/nova3/engines"

if [ ! -f "$PLUGINS_FILE" ]; then
    echo "Error: SEARCH_PLUGINS.md not found at $PLUGINS_FILE"
    exit 1
fi

if [ ! -d "$PLUGINS_DIR" ]; then
    echo "Error: qBittorrent plugins directory not found at $PLUGINS_DIR"
    exit 1
fi

echo "🚀 Starting qBittorrent search plugin installation..."
echo "📁 Target directory: $PLUGINS_DIR"

# Function to extract download URLs from SEARCH_PLUGINS.md
extract_plugin_urls() {
    # Extract download URLs from the markdown file
    grep -o '\[.*Download.*\]\((https?://[^)]*)\)' "$PLUGINS_FILE" | \
    sed -E 's/.*\[(.*)\]\((.*)\).*/\2/' | \
    grep -v 'github.com.*raw.*assets' | \
    grep -v 'raw.*github.*Download'
}

# Function to download and install a plugin
install_plugin() {
    local url="$1"
    local plugin_name="$(basename "$url")"
    local target_path="$PLUGINS_DIR/$plugin_name"
    
    echo "📥 Downloading: $plugin_name"
    
    if curl -sSLf "$url" -o "$target_path"; then
        chmod +x "$target_path"
        echo "✅ Installed: $plugin_name"
    else
        echo "❌ Failed to download: $plugin_name"
        return 1
    fi
}

# Main installation process
main() {
    echo "🔍 Extracting plugin URLs from SEARCH_PLUGINS.md..."
    
    # Extract all plugin URLs
    local plugin_urls
    plugin_urls=$(extract_plugin_urls)
    
    if [ -z "$plugin_urls" ]; then
        echo "❌ No plugin URLs found in SEARCH_PLUGINS.md"
        exit 1
    fi
    
    echo "Found $(echo "$plugin_urls" | wc -l) plugins available"
    
    # If specific plugins are requested, filter the list
    if [ $# -gt 0 ]; then
        echo "Filtering for specific plugins: $*"
        local filtered_urls=""
        for plugin in "$@"; do
            local matched_url=$(echo "$plugin_urls" | grep -i "$plugin" | head -1)
            if [ -n "$matched_url" ]; then
                filtered_urls="$filtered_urls$matched_url\n"
            else
                echo "⚠️  Plugin '$plugin' not found in available plugins"
            fi
        done
        plugin_urls="$filtered_urls"
    fi
    
    # Install each plugin
    local installed_count=0
    local failed_count=0
    
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            local url=$(echo "$line" | awk '{print $NF}')
            install_plugin "$url" && ((installed_count++)) || ((failed_count++))
        fi
    done <<< "$plugin_urls"
    
    echo ""
    echo "📊 Installation Summary:"
    echo "✅ Successfully installed: $installed_count plugins"
    echo "❌ Failed to install: $failed_count plugins"
    echo ""
    echo "🎉 Plugins installed to: $PLUGINS_DIR"
}

# Run main function with all arguments
main "$@"