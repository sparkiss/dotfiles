-- in your plugins setup (e.g., with lazy.nvim)
return {
  "danymat/neogen",
  config = function()
    require("neogen").setup({
      enabled = true,
      snippet_engine = "luasnip", -- or whatever snippet engine you use
      languages = {
        php = {
          template = {
            annotation_convention = "phpdoc",
          },
        },
      },
    })
    -- optional: keymap
    vim.keymap.set("n", "<leader>dc", ":Neogen<CR>", { desc = "Generate doc comment" })
  end,
}
