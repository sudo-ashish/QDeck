local theme_path = vim.fn.expand("~/.config/themes/current/neovim.lua")
local ok, spec = pcall(dofile, theme_path)

if not ok then
  return {}
end

if type(spec) ~= "table" then
  return {}
end

return spec
