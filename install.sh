#!/usr/bin/env bash
set -e

echo "⚡ Installing Solid Run..."

# Check prerequisites
command -v ruby >/dev/null 2>&1 || { echo "❌ Ruby is required but not installed."; exit 1; }
command -v git >/dev/null 2>&1 || { echo "❌ Git is required but not installed."; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "❌ GitHub CLI (gh) is required but not installed."; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "❌ Docker is required but not installed."; exit 1; }
command -v act >/dev/null 2>&1 || { echo "❌ act is required but not installed (https://github.com/nektos/act)."; exit 1; }
command -v cloudflared >/dev/null 2>&1 || { echo "❌ cloudflared is required but not installed."; exit 1; }

INSTALL_DIR="$HOME/.solid_run_app"

if [ -d "$INSTALL_DIR" ]; then
  echo "Updating existing installation in $INSTALL_DIR..."
  cd "$INSTALL_DIR" && git pull
else
  echo "Cloning Solid Run into $INSTALL_DIR..."
  git clone https://github.com/nebiyuelias1/solid_run.git "$INSTALL_DIR"
  cd "$INSTALL_DIR"
fi

echo "Installing dependencies & preparing database..."
bundle install --quiet
bin/rails db:prepare >/dev/null 2>&1

# Link binary into ~/.local/bin
mkdir -p "$HOME/.local/bin"
ln -sf "$INSTALL_DIR/bin/solid_run" "$HOME/.local/bin/solid_run"

echo ""
echo "🎉 Solid Run successfully installed!"
echo "Run 'solid_run' inside any repository to start your local CI runner."
