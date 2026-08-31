# ⚡ Solid Run

> A self-hosted, local GitHub Actions CI platform powered by **Rails 8**, **Solid Queue**, **Hotwire**, and **`act`**.

Automatically creates a zero-login Cloudflare Quick Tunnel, registers temporary webhooks on your GitHub repositories, queues builds in SQLite-backed Solid Queue, runs your workflows locally in Docker via `act`, and streams live logs to a real-time dashboard.

---

## 🏗️ Architecture

```
GitHub Push / PR
       │
       ▼ (Webhook POST with HMAC-SHA256)
Cloudflare Quick Tunnel (https://*.trycloudflare.com)
       │
       ▼
Rails 8 Webhooks Controller
       │
       ├─► 1. Evaluates matching workflows (.github/workflows/*.yml)
       ├─► 2. Creates WorkflowRun in SQLite (status: :queued)
       ├─► 3. Updates GitHub commit status ➔ "Queued ⏳" (with direct dashboard link)
       └─► 4. Enqueues ExecuteWorkflowJob in Solid Queue
       │
       ▼
Solid Queue Worker Supervisor
       │
       ├─► 5. Picks up job from queue (concurrency-controlled per repo)
       ├─► 6. Updates GitHub commit status ➔ "In Progress ⚙️"
       ├─► 7. Executes `act -W .github/workflows/ci.yml` in Docker container
       ├─► 8. Streams live terminal logs to DB & broadcasts to Web UI via Turbo Streams
       └─► 9. Updates final GitHub commit status ➔ "Success ✅" or "Failure ❌"
```

---

## 📦 Prerequisites

Make sure the following are installed:

- **Ruby (3.1+)**
- **Git**
- **GitHub CLI (`gh`)**: Authenticated via `gh auth login`
- **Docker**: Running daemon
- **act**: `https://github.com/nektos/act`
- **cloudflared**: `https://github.com/cloudflare/cloudflared`

---

## 🚀 Installation

### Option 1: Install as a Ruby Gem

```bash
gem install solid_run
```

### Option 2: 1-Line Installer Script

```bash
curl -fsSL https://raw.githubusercontent.com/nebiyuelias1/solid_run/main/install.sh | bash
```

---

## 🎮 How to Use

Navigate to any Git repository connected to GitHub:

```bash
cd /path/to/your-project
solid_run
```

### What Happens:

1. Detects your GitHub remote origin (`owner/repo`).
2. Starts the Rails 8 server & Solid Queue worker.
3. Automatically opens a Cloudflare Quick Tunnel.
4. Registers the webhook on GitHub with an auto-generated HMAC-SHA256 secret.
5. Displays your live dashboard: **`http://localhost:3000`**
6. On `Ctrl+C`, automatically removes the webhook from GitHub and shuts down the tunnel.

---

## 📊 Real-Time Web Dashboard

Open `http://localhost:3000` to:

- View all active and past workflow runs.
- Watch terminal build logs stream live in real-time.
- Trigger 1-click workflow re-runs.
- Click commit status links directly from GitHub pull requests or direct commits to `main`.

---

## 🧪 Running Tests

```bash
bin/rails test
```
