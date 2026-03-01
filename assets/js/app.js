import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let Hooks = {}

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

let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

liveSocket.connect()

window.liveSocket = liveSocket
