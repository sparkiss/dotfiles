return {
  {
    "L3MON4D3/LuaSnip",
    version = "v2.*", -- or omit this for latest
    build = "make install_jsregexp", -- optional but recommended
    dependencies = { "rafamadriz/friendly-snippets" },
    config = function()
      require("luasnip.loaders.from_vscode").lazy_load() -- load snippets
    end,
  },
}
