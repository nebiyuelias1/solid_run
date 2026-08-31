import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["stepsContainer", "rawContainer", "viewToggleBtn"]

  connect() {
    this.currentStepCard = null
    this.currentJob = null

    // Observe changes in raw logs container to update steps view in real time
    if (this.hasRawContainerTarget) {
      this.observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
          mutation.addedNodes.forEach((node) => {
            if (node.nodeType === Node.TEXT_NODE || node.nodeType === Node.ELEMENT_NODE) {
              const text = node.textContent || ""
              this.processIncomingChunk(text)
            }
          })
        })
      })
      this.observer.observe(this.rawContainerTarget, { childList: true, characterData: true, subtree: true })
    }
  }

  disconnect() {
    this.observer?.disconnect()
  }

  processIncomingChunk(chunk) {
    const lines = chunk.split("\n")
    lines.forEach((line) => {
      if (!line.trim()) return
      this.processLine(line)
    })
  }

  processLine(line) {
    const cleanLine = line.trim()

    // 1. Check Step Start: e.g. "[CI/test] ⭐ Run Run Tests"
    const stepStart = cleanLine.match(/(?:\[(.*?)\]\s*)?⭐\s*Run\s+(.*)/)
    if (stepStart) {
      const jobName = stepStart[1] || "Default"
      const stepName = stepStart[2].trim()
      this.createStepCard(jobName, stepName)
      return
    }

    // 2. Check Step Success: e.g. "[CI/test]   ✅  Success - Run Tests"
    const stepSuccess = cleanLine.match(/(?:\[(.*?)\]\s*)?✅\s*Success\s*-\s*(.*)/)
    if (stepSuccess) {
      this.markCurrentStep("success")
      return
    }

    // 3. Check Step Failure: e.g. "[CI/test]   ❌  Failure - Run Tests"
    const stepFailure = cleanLine.match(/(?:\[(.*?)\]\s*)?❌\s*Failure\s*-\s*(.*)/)
    if (stepFailure) {
      this.markCurrentStep("failure")
      return
    }

    // 4. Regular line: append to current step
    if (this.currentStepCard) {
      const body = this.currentStepCard.querySelector(".step-body")
      if (body) {
        const lineElem = document.createElement("div")
        lineElem.className = "step-line"
        lineElem.textContent = line.replace(/^\[.*?\]\s*/, "").replace(/^\|\s*/, "")
        body.appendChild(lineElem)
        body.scrollTop = body.scrollHeight
      }
    }
  }

  createStepCard(jobName, stepName) {
    if (!this.hasStepsContainerTarget) return

    // Close previous step if active
    if (this.currentStepCard) {
      this.markCurrentStep("success")
    }

    const card = document.createElement("details")
    card.className = "step-card in-progress"
    card.open = true

    const summary = document.createElement("summary")
    summary.className = "step-header"
    summary.innerHTML = `
      <div class="step-title">
        <span class="step-icon">⚙️</span>
        <span class="step-name">${stepName}</span>
        <span class="step-job-badge">${jobName}</span>
      </div>
      <span class="step-status-text">Running...</span>
    `

    const body = document.createElement("div")
    body.className = "step-body"

    card.appendChild(summary)
    card.appendChild(body)
    this.stepsContainerTarget.appendChild(card)

    this.currentStepCard = card
    card.scrollIntoView({ behavior: "smooth", block: "nearest" })
  }

  markCurrentStep(status) {
    if (!this.currentStepCard) return

    this.currentStepCard.className = `step-card ${status}`
    const icon = this.currentStepCard.querySelector(".step-icon")
    const statusText = this.currentStepCard.querySelector(".step-status-text")

    if (status === "success") {
      if (icon) icon.textContent = "✅"
      if (statusText) statusText.textContent = "Completed"
    } else if (status === "failure") {
      if (icon) icon.textContent = "❌"
      if (statusText) statusText.textContent = "Failed"
      this.currentStepCard.open = true
    }
  }

  toggleView(event) {
    event.preventDefault()
    const isShowingRaw = this.rawContainerTarget.style.display !== "none"

    if (isShowingRaw) {
      this.rawContainerTarget.style.display = "none"
      this.stepsContainerTarget.style.display = "block"
      this.viewToggleBtnTarget.textContent = "💻 View Raw Terminal Logs"
    } else {
      this.rawContainerTarget.style.display = "block"
      this.stepsContainerTarget.style.display = "none"
      this.viewToggleBtnTarget.textContent = "📑 View GitHub Step Cards"
    }
  }

  expandAll() {
    this.stepsContainerTarget.querySelectorAll("details").forEach((d) => (d.open = true))
  }

  collapseAll() {
    this.stepsContainerTarget.querySelectorAll("details").forEach((d) => (d.open = false))
  }
}
