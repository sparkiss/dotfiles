-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
-- map <D-v> "+p<CR>
-- map! <D-v> <C-R>+
-- tmap <D-v> <C-R>+
-- vmap <D-c> "+y<CR>

-- vim.keymap.set("n,i", "<D-v>", '<Esc>"+p')
-- vim.keymap.set("v", "<D-c>", '"+y<CR>')

-- Yank to clipboard (works via OSC52 over SSH/tmux)
vim.keymap.set("n", "<leader>y", '"+y', { noremap = true, silent = true, desc = "Yank motion to clipboard" })
vim.keymap.set({ "v", "x" }, "<leader>y", '"+y', { noremap = true, silent = true, desc = "Yank selection to clipboard" })
vim.keymap.set({ "v", "x" }, "<D-c>", '"+y', { noremap = true, silent = true, desc = "Yank selection to clipboard" })

-- Yank line to clipboard
vim.keymap.set("n", "<leader>yy", '"+yy', { noremap = true, silent = true, desc = "Yank line to clipboard (OSC52)" })
vim.keymap.set("n", "<leader>Y", '"+yy', { noremap = true, silent = true, desc = "Yank line to clipboard (OSC52)" })

-- Visual mode: yy doesn't make sense, so map to just y (yank selection)
vim.keymap.set({ "v", "x" }, "<leader>yy", '"+y', { noremap = true, silent = true, desc = "Yank selection to clipboard (OSC52)" })
vim.keymap.set({ "v", "x" }, "<leader>Y", '"+y', { noremap = true, silent = true, desc = "Yank selection to clipboard (OSC52)" })

-- Disable <C-a> and <C-x> in normal and visual modes
vim.keymap.set({ "n", "v" }, "<C-a>", "<Nop>", { desc = "disable Ctrl-A increment" })
vim.keymap.set({ "n", "v" }, "<C-x>", "<Nop>", { desc = "disable Ctrl-X decrement" })
--vim.keymap.set({ "n", "v", "x" }, "<leader>p", '"+p', { noremap = true, silent = true, desc = "Paste from clipboard" })
vim.keymap.set(
  "i",
  "<C-p>",
  "<C-r>+",
  { noremap = true, silent = true, desc = "Paste from clipboard from within insert mode" }
)
-- Paste over selection without replacing clipboard (using leader)
vim.keymap.set(
  "x",
  "<leader>P",
  '"_dP',
  { noremap = true, silent = true, desc = "Paste over selection without erasing unnamed register" }
)

-- Make regular 'p' in visual/visual-block mode not replace clipboard
-- This deletes to black hole register (_) before pasting
vim.keymap.set({ "v", "x" }, "p", '"_dP', { noremap = true, silent = true, desc = "Paste without replacing clipboard" })

-- FZF: Find all files including gitignored
vim.keymap.set("n", "<leader>fA", function()
  require("fzf-lua").files({ no_ignore = true, hidden = true })
end, { desc = "Find all files (including ignored)" })
