import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let Hooks = {}

// Theme management — persist selection in localStorage
function getTheme() {
  return localStorage.getItem("theme") || "dark"
}

function setTheme(theme) {
  localStorage.setItem("theme", theme)
  document.documentElement.setAttribute("data-theme", theme)
}

// Apply saved theme on page load
setTheme(getTheme())

Hooks.ThemeToggle = {
  mounted() {
    this.el.checked = getTheme() === "dark"
    this.el.addEventListener("change", (e) => {
      setTheme(e.target.checked ? "dark" : "light")
    })
  }
}

// Auto-refresh hook for device discovery
Hooks.AutoRefresh = {
  mounted() {
    this.interval = setInterval(() => {
      this.pushEvent("refresh", {})
    }, 5000)
  },
  destroyed() {
    clearInterval(this.interval)
  }
}

// Crosspoint hover — highlight corresponding row/column headers
Hooks.Crosspoint = {
  mounted() {
    this.el.addEventListener("mouseenter", () => {
      const tx = this.el.dataset.txChannel
      const rx = this.el.dataset.rxChannel

      document.querySelectorAll(`[data-tx-header="${tx}"]`).forEach(el =>
        el.classList.add("text-primary", "font-bold")
      )
      document.querySelectorAll(`[data-rx-header="${rx}"]`).forEach(el =>
        el.classList.add("text-primary", "font-bold")
      )
    })

    this.el.addEventListener("mouseleave", () => {
      document.querySelectorAll("[data-tx-header]").forEach(el =>
        el.classList.remove("text-primary", "font-bold")
      )
      document.querySelectorAll("[data-rx-header]").forEach(el =>
        el.classList.remove("text-primary", "font-bold")
      )
    })
  }
}

// Collapsible device groups in routing matrix
Hooks.Collapsible = {
  mounted() {
    this.el.addEventListener("click", () => {
      const target = this.el.dataset.target
      const els = document.querySelectorAll(`[data-group="${target}"]`)
      const isHidden = els[0]?.classList.contains("hidden")

      els.forEach(el => el.classList.toggle("hidden"))
      this.el.querySelector(".collapse-icon").textContent = isHidden ? "−" : "+"
    })
  }
}

let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

liveSocket.connect()

window.liveSocket = liveSocket
