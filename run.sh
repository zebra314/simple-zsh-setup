#!/usr/bin/env bash
set -e

ZSHRC="$HOME/.zshrc"
FONT_DIR="$HOME/.local/share/fonts"
THEME_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
PLUGIN_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
TMUX_CONF="$HOME/.tmux.conf"

if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

# Detect OS
if [ -f /etc/arch-release ]; then
    OS="arch"
    PKG="$SUDO pacman -S --noconfirm"
elif [ -f /etc/debian_version ]; then
    OS="debian"
    PKG="$SUDO apt install -y"
elif [ -f /etc/fedora-release ]; then
    OS="fedora"
    PKG="$SUDO dnf install -y"
else
    echo "Unsupported Linux distribution."
    exit 1
fi

echo "Detected OS: $OS"

# Install dependencies
echo "Installing dependencies..."
$PKG git curl wget

# Install zsh
if ! command -v zsh >/dev/null 2>&1; then
    echo "Installing Zsh..."
    $PKG zsh
else
    echo "Zsh already installed."
fi

# Install fonts
echo "Installing Nerd Fonts (MesloLGS NF)..."
mkdir -p "$FONT_DIR"
cd "$FONT_DIR"
if [ ! -f "MesloLGS NF Regular.ttf" ]; then
    wget -q https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf
    wget -q https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf
    wget -q https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf
    wget -q https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf
    fc-cache -fv >/dev/null
fi
cd - >/dev/null

# Install oh-my-zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    export RUNZSH=no
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "Oh My Zsh already installed."
fi

# Install powerlevel10k theme
if [ ! -d "$THEME_DIR" ]; then
    echo "Installing Powerlevel10k theme..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$THEME_DIR"
else
    echo "Powerlevel10k already installed."
fi

# Configure p10k theme
if [ -f "$ZSHRC" ] && ! grep -q "source ~/.p10k.zsh" "$ZSHRC"; then
    echo "Adding p10k configuration to .zshrc..."
    echo '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh' >> "$ZSHRC"
fi

# Install zsh plugins
declare -A PLUGINS=(
    ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
    ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting"
    ["zsh-completions"]="https://github.com/zsh-users/zsh-completions"
)

echo "Installing Zsh plugins..."
mkdir -p "$PLUGIN_DIR"
for plugin in "${!PLUGINS[@]}"; do
    dir="$PLUGIN_DIR/$plugin"
    if [ ! -d "$dir" ]; then
        git clone --depth=1 "${PLUGINS[$plugin]}" "$dir"
    else
        echo "$plugin already installed."
    fi
done

# Install tmux
if ! command -v tmux >/dev/null 2>&1; then
    echo "Installing tmux..."
    $PKG tmux
else
    echo "tmux already installed."
fi

# Install tpm
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    echo "Installing tmux plugin manager (tpm)..."
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
else
    echo "tmux plugin manager already installed."
fi

# Install Catppuccin tmux theme
echo "Installing Catppuccin tmux theme..."
if [ ! -f "$TMUX_CONF" ]; then
    touch "$TMUX_CONF"
fi

# Ensure TPM load line exists
if ! grep -q "run '~/.tmux/plugins/tpm/tpm'" "$TMUX_CONF"; then
    echo "" >> "$TMUX_CONF"
    echo "# Initialize TPM plugin manager" >> "$TMUX_CONF"
    echo "run '~/.tmux/plugins/tpm/tpm'" >> "$TMUX_CONF"
fi

# Add Catppuccin plugin
if ! grep -q "catppuccin/tmux" "$TMUX_CONF"; then
    echo "" >> "$TMUX_CONF"
    echo "# Catppuccin tmux theme" >> "$TMUX_CONF"
    echo "set -g @plugin 'catppuccin/tmux#v2.1.3'" >> "$TMUX_CONF"
    echo "set-option -g status-position top" >> "$TMUX_CONF"
    echo "set -g @catppuccin_window_status_style "rounded"" >> "$TMUX_CONF"
fi

# Configure .zshrc
if [ -f "$ZSHRC" ]; then
    echo "Configuring .zshrc..."
    
    # Set theme to powerlevel10k
    if grep -q '^ZSH_THEME=' "$ZSHRC"; then
        sed -i 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' "$ZSHRC"
    fi
    
    # Update plugins
    if grep -q '^plugins=(' "$ZSHRC"; then
        sed -i 's|^plugins=([^)]*)|plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions tmux)|' "$ZSHRC"
    fi

    # Enable tmux auto-start
    if ! grep -q "ZSH_TMUX_AUTOSTART=true" "$ZSHRC"; then
        sed -i '/^ZSH_THEME=/a ZSH_TMUX_AUTOSTART=true' "$ZSHRC"
    fi
fi

# Set up zsh as default shell
if [ "$SHELL" != "$(which zsh)" ]; then
    echo "Changing default shell to zsh..."
    chsh -s "$(which zsh)"
fi
