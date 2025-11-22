return {
  -- Extend LazyVim's Mason configuration
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        -- LSP servers
        "clangd", -- C/C++
        "rust-analyzer", -- Rust
        "gopls", -- Go
        "intelephense", -- PHP
        "phpactor", -- PHP alternative
        "typescript-language-server", -- Node/TypeScript/JavaScript
        "html-lsp", -- HTML
        "css-lsp", -- CSS
        "cssmodules-language-server", -- CSS modules
        "tailwindcss-language-server", -- Tailwind CSS
        "pyright", -- Python
        "ruff-lsp", -- Python linting

        -- Formatters
        "clang-format", -- C/C++
        "rustfmt", -- Rust
        "gofumpt", -- Go
        "goimports", -- Go imports
        "prettier", -- JS/TS/HTML/CSS
        "black", -- Python
        "isort", -- Python imports

        -- Linters
        "eslint_d", -- JS/TS
        "golangci-lint", -- Go
        "phpstan", -- PHP
        "ruff", -- Python
      })
    end,
  },
}
