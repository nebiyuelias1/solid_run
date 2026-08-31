# Solid Run

A lightweight, zero-config local CI webhook listener written in pure Ruby.

It automatically creates an ephemeral **Cloudflare Quick Tunnel**, registers a temporary webhook on your GitHub repository via the `gh` CLI, listens for incoming GitHub events (`push`, `pull_request`, `ping`, `workflow_dispatch`), and pretty-prints them in your terminal. When you stop the tool (`Ctrl+C`), it cleans up by deleting the webhook and terminating the tunnel.

---

## 🛠️ How It Works

```
GitHub Repo Event (push/PR)
          │
          ▼
Cloudflare Quick Tunnel (https://*.trycloudflare.com)
          │
          ▼
Local WEBrick HTTP Server (http://127.0.0.1:4567)
          │
          ▼
Local CI Event Printer (Terminal stdout)
```

1. **Git Detection**: Inspects `git remote get-url origin` to extract the `owner/repo`.
2. **Local HTTP Server**: Spawns an internal WEBrick server on port `4567` (or custom port).
3. **Cloudflare Quick Tunnel**: Starts `cloudflared tunnel --url http://127.0.0.1:4567` without requiring an account or login.
4. **Webhook Registration**: Uses `gh api` to register the temporary tunnel URL as a webhook on your GitHub repo.
5. **Event Dispatching**: Displays styled and structured logs for incoming events.
6. **Graceful Teardown**: Intercepts `SIGINT` (`Ctrl+C`) to automatically delete the webhook from GitHub and kill the tunnel.

---

## 📦 Prerequisites

Make sure the following tools are installed and in your `$PATH`:
- **Ruby** (3.0+)
- **GitHub CLI (`gh`)**: authenticated via `gh auth login`
- **Cloudflare CLI (`cloudflared`)**: installed (no login required)
- **Git**

---

## 🚀 Quickstart

1. Clone or navigate into any Git repository that has a GitHub remote `origin`:
   ```bash
   cd /path/to/your/github-repo
   ```

2. Run `local-ci`:
   ```bash
   /home/netale/projects/personal/local-ci/bin/local-ci
   ```

3. Trigger any event on GitHub (e.g. push a commit, open a PR, or ping the webhook). Watch the formatted event logs appear in real time!

4. Press `Ctrl+C` to stop. The webhook on GitHub will automatically be deleted.

---

## ⚙️ Options

```bash
Usage: local-ci [options]
    -p, --port PORT                  Port for local HTTP server (default: 4567)
    -r, --remote REMOTE              Git remote name to use (default: origin)
    -e, --events EVENTS              Comma-separated GitHub events to listen for (default: push,pull_request,workflow_dispatch,ping)
    -v, --version                    Show version
    -h, --help                       Show help message
```

---

## 🧪 Running Tests

```bash
bundle exec ruby -Ilib:test -e 'Dir["test/**/*_test.rb"].each { |f| require_relative f }'
```
