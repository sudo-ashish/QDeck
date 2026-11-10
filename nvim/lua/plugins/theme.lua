local function reload_current_theme()
  local theme_path = vim.fn.expand("~/.config/themes/current/neovim.lua")
  local ok, spec = pcall(dofile, theme_path)
  if not ok or type(spec) ~= "table" then return end
  for _, item in ipairs(spec) do
    if item.opts and item.opts.colorscheme then
      if item.opts.background then
        vim.o.background = item.opts.background
      end
      pcall(vim.cmd.colorscheme, item.opts.colorscheme)
    end
  end
end

_G.reload_qdeck_theme = reload_current_theme

-- User command to reload theme manually anytime
pcall(vim.api.nvim_create_user_command, "ReloadTheme", function()
  reload_current_theme()
  vim.notify("QDeck theme reloaded", vim.log.levels.INFO)
end, { desc = "Reload QDeck active theme in LazyVim" })

-- Auto-reload when Neovim terminal window regains focus
pcall(vim.api.nvim_create_autocmd, "FocusGained", {
  callback = reload_current_theme,
  desc = "Reload QDeck theme on focus gained",
})

-- Handle SIGUSR1 for instantaneous live reload from theme-switch
if vim.uv and vim.uv.new_signal then
  local sig = vim.uv.new_signal()
  sig:start("sigusr1", function()
    vim.schedule(reload_current_theme)
  end)
end

local theme_path = vim.fn.expand("~/.config/themes/current/neovim.lua")
local ok, spec = pcall(dofile, theme_path)

if not ok then
  return {}
end

if type(spec) ~= "table" then
  return {}
end

return spec
