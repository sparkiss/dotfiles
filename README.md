# dotfiles

remote-first development environment


## Philosophy

<!-- Write about your approach to SSH + Tmux + Neovim remote development workflow
     - Why this particular setup?
     - What problems does it solve?
     - Your development philosophy
-->

## Features

     - Remote-first design (OSC52 clipboard integration across SSH/nested tmux)
     - Multi-language development environment (PHP-focused with Rust/Go/Python/TypeScript)
     - Comprehensive debugging setup (DAP for 6+ languages with unified F-key workflow)
     - Session persistence (tmux-resurrect/continuum auto-restore)
     - Modern toolchain integration (zoxide, fzf, bun, nvm, cargo, etc.)
     - Vim-centric consistency across all tools

## Prerequisites

     - GNU Stow
     - Zsh
     - Tmux (version 3.5a+)
     - Neovim (version 0.11+)
     - Git
     - Oh-My-Zsh
     - Node.js (via nvm) / Rust / Go / etc.

## Installation

### Quick Start

```bash
git clone https://github.com/<username>/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```


### Manual Installation

cd ~/.dotfiles
stow nvim
stow tmux
stow zsh

## Configuration Highlights

### Neovim / LazyVim

     - Leader key: comma (,)
     - Clipboard integration strategy (OSC52 for remote/SSH)
     - Key bindings:
       - <leader>y / <leader>yy / <leader>Y - yank to clipboard
       - <leader>aa - select all
       - <leader>P - paste without erasing register
       - <leader>dc - generate PHPDoc
       - <leader>ce - toggle code outline
       - F4-F9 - debugging workflow

     - PHP development setup:
       - LSP servers (Intelephense, Phpactor)
       - Debugging (Xdebug port 9003)
       - Testing navigation
       - Code formatting (PHP CS Fixer PSR12)

     - Multi-language support:
       - Rust (rust-analyzer, rustfmt)
       - Go (gopls, gofumpt, golangci-lint)
       - Python (pyright, ruff, black)
       - TypeScript (ts-server, prettier, eslint)

     - Theme: Catppuccin Mocha with transparent background
     - Neovide support with 85% transparency

### Tmux

     - Prefix: C-a
     - Vim-style navigation: C-a h/j/k/l
     - Vim-style resize: C-a H/J/K/L
     - OSC52 clipboard support for remote sessions
     - Session persistence with auto-restore
     - Respawn commands: R (window), ` (pane)
     - Plugins: tmux-sensible, tmux-yank, tmux-resurrect, tmux-continuum

### Zsh / Powerlevel10k

     - Vi mode enabled
     - Powerlevel10k theme
     - Plugins: git, npm, zsh-autosuggestions, zsh-syntax-highlighting
     - Modern CLI tools:
       - fzf - fuzzy finder
       - zoxide - smart cd
       - nvm - Node version management
       - cargo/rustup - Rust toolchain
     - Custom aliases:
       - tma - attach to tmux session 0
       - supervisorctl shortcuts (svc, sstart, sstatus, sstop, srestart)

## Key Bindings Reference

     organized by tool (Neovim, Tmux, Shell)

## Remote Development Workflow

     - My typical usage is SSH + TMUX + SSH + TMUX + Neovim


## License

  MIT License - feel free to use this however you'd like.



