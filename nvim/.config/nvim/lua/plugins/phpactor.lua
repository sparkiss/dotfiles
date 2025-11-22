return {
  {
    "phpactor/phpactor",
    ft = "php",
    build = "composer install --no-dev -o",
    keys = {
      { "<leader>pt", ":PhpactorClassNew test<CR>", desc = "Generate test for current class" },
      { "<leader>pT", ":PhpactorGoto test<CR>", desc = "Jump to test" },
      { "<leader>pc", ":PhpactorGoto source<CR>", desc = "Jump to source" },
      { "<leader>pp", ":PhpactorContextMenu<CR>", desc = "Phpactor: context menu" },
    },
    config = function()
      vim.g.phpactor_enable_completion = false
    end,
  },
}
