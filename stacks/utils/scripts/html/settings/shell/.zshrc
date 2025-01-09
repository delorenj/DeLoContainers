# Path configuration
export PATH=$HOME/.local/bin:/usr/local/bin:$PATH

# Oh My Zsh configuration
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

# Oh My Zsh plugins
plugins=(
  git
  ruby
  docker
  docker-compose
  kubectl
  python
  pip
  virtualenv
  golang
  nvm
  npm
  node
  copypath                # Copy current directory path to clipboard
  copyfile                # Copy file contents to clipboard
  web-search              # Search Google from terminal
  jsontools               # Tools for working with JSON
  vscode                  # VS Code integration
  dirhistory             # Navigate directory history with Alt+Left/Right
  extract                # Extract any archive with 'x' command
  sudo                    # Press ESC twice to add sudo to current command
  command-not-found       # Suggests package to install if command not found
)

source $ZSH/oh-my-zsh.sh

# Basic environment setup
export LANG=en_US.UTF-8
export EDITOR='vim'
autoload -Uz compinit && compinit

# Basic aliases
alias zshconfig="vim ~/.zshrc"
alias ohmyzsh="vim ~/.oh-my-zsh"

# Source additional configuration files
[ -f ~/.zsh_secrets ] && source ~/.zsh_secrets  # API keys and secrets
[ -f ~/.zsh_local ] && source ~/.zsh_local     # Machine-specific configuration

# Tool initialization
eval "$(direnv hook zsh)"
eval "$(starship init zsh)"
