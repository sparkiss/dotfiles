-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.g.mapleader = ","
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.tabstop = 4 -- number of visual spaces per TAB
vim.opt.softtabstop = 4 -- number of spaces inserted when you hit TAB
vim.opt.shiftwidth = 4 -- number of spaces used for indentation
vim.opt.expandtab = true -- use spaces instead of tabs

-- Helper function for transparency formatting
local alpha = function()
  return string.format("%x", math.floor((255 * vim.g.transparency) or 0.8))
end
-- g:neovide_transparency should be 0 if you want to unify transparency of content and title bar.
vim.g.neovide_transparency = 0.0
vim.g.transparency = 0.85
vim.g.neovide_background_color = "#17110f" .. alpha()
vim.o.guifont = "UbuntuMono Nerd Font Mono:h14" -- text below applies for VimScript

vim.o.clipboard = "unnamedplus"

local function paste()
  return {
    vim.fn.split(vim.fn.getreg(""), "\n"),
    vim.fn.getregtype(""),
  }
end

vim.g.clipboard = {
  name = "OSC 52",
  copy = {
    ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
    ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
  },
  paste = {
    ["+"] = paste,
    ["*"] = paste,
  },
}
