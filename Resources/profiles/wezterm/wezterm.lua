-- Persona 3 Reload — Isolated WezTerm Profile
local wezterm = require 'wezterm'
local config = wezterm.config_builder and wezterm.config_builder() or {}

config.window_background_opacity = 0.92
config.macos_window_background_blur = 20
config.window_padding = { left = 14, right = 14, top = 14, bottom = 14 }
config.font = wezterm.font_with_fallback({ 'Rajdhani', 'Menlo' })
config.font_size = 13.0

config.colors = {
  background = '#0a192f',
  foreground = '#e8f6ff',
  cursor_bg = '#00d8ff',
  cursor_fg = '#0a192f',
  cursor_border = '#00d8ff',
  selection_bg = '#1f6bff',
  selection_fg = '#e8f6ff',
  ansi = {
    '#0a192f', '#ff3b5c', '#5dffcf', '#ffd24a',
    '#1f6bff', '#b48cff', '#00d8ff', '#e8f6ff',
  },
  brights = {
    '#3a5a7a', '#ff6b85', '#8cffdf', '#ffe07d',
    '#4d8bff', '#ccaeff', '#5ce5ff', '#ffffff',
  },
}

return config

