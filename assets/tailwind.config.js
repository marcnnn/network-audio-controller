const plugin = require("tailwindcss/plugin")

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/netaudio_web.ex",
    "../lib/netaudio_web/**/*.*ex"
  ],
  theme: {
    extend: {},
  },
  plugins: [
    require("daisyui"),
    plugin(({addVariant}) => addVariant("phx-no-feedback", [".phx-no-feedback&", ".phx-no-feedback &"])),
    plugin(({addVariant}) => addVariant("phx-click-loading", [".phx-click-loading&", ".phx-click-loading &"])),
    plugin(({addVariant}) => addVariant("phx-submit-loading", [".phx-submit-loading&", ".phx-submit-loading &"])),
    plugin(({addVariant}) => addVariant("phx-change-loading", [".phx-change-loading&", ".phx-change-loading &"]))
  ],
  daisyui: {
    themes: [
      {
        dark: {
          "primary": "#6366f1",
          "primary-content": "#ffffff",
          "secondary": "#22d3ee",
          "secondary-content": "#000000",
          "accent": "#34d399",
          "accent-content": "#000000",
          "neutral": "#1e293b",
          "neutral-content": "#cbd5e1",
          "base-100": "#0f172a",
          "base-200": "#1e293b",
          "base-300": "#334155",
          "base-content": "#e2e8f0",
          "info": "#38bdf8",
          "info-content": "#000000",
          "success": "#4ade80",
          "success-content": "#000000",
          "warning": "#fbbf24",
          "warning-content": "#000000",
          "error": "#f87171",
          "error-content": "#000000",
        },
      },
      {
        light: {
          "primary": "#4f46e5",
          "primary-content": "#ffffff",
          "secondary": "#0891b2",
          "secondary-content": "#ffffff",
          "accent": "#059669",
          "accent-content": "#ffffff",
          "neutral": "#f1f5f9",
          "neutral-content": "#334155",
          "base-100": "#ffffff",
          "base-200": "#f8fafc",
          "base-300": "#e2e8f0",
          "base-content": "#1e293b",
          "info": "#0284c7",
          "info-content": "#ffffff",
          "success": "#16a34a",
          "success-content": "#ffffff",
          "warning": "#d97706",
          "warning-content": "#ffffff",
          "error": "#dc2626",
          "error-content": "#ffffff",
        },
      },
    ],
    darkTheme: "dark",
  },
}
