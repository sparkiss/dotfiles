-- Overseer: Universal task runner for all languages
-- Run/Build/Test with <leader>rr (shows menu)
-- Works with: Go, PHP, Python, Rust, C/C++, Node.js, TypeScript, Make, Docker
return {
  "stevearc/overseer.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  cmd = {
    "OverseerRun",
    "OverseerToggle",
    "OverseerOpen",
    "OverseerRunCmd",
    "OverseerBuild",
  },
  keys = {
    { "<leader>rr", "<cmd>OverseerRun<CR>", desc = "Run Task (menu)" },
    { "<leader>rl", "<cmd>OverseerRestartLast<CR>", desc = "Run Last Task" },
    { "<leader>rt", "<cmd>OverseerToggle<CR>", desc = "Toggle Task List" },
    { "<leader>ro", "<cmd>OverseerOpen<CR>", desc = "Open Task List" },
    { "<leader>rc", "<cmd>OverseerRunCmd<CR>", desc = "Run Shell Command" },
    { "<leader>rq", "<cmd>OverseerQuickAction<CR>", desc = "Quick Action" },
  },
  opts = {
    -- Task output window
    task_list = {
      direction = "bottom",
      min_height = 10,
      max_height = 20,
      default_detail = 1,
      bindings = {
        ["q"] = "Close",
        ["<CR>"] = "RunAction",
        ["o"] = "Open",
        ["<C-v>"] = "OpenVsplit",
        ["<C-s>"] = "OpenSplit",
        ["r"] = "Restart",
        ["x"] = "Stop",
      },
    },
    -- Templates for different project types
    templates = { "builtin" },
    -- Strategy for running tasks
    strategy = {
      "toggleterm",
      direction = "horizontal",
      open_on_start = true,
      close_on_exit = false,
    },
  },
  config = function(_, opts)
    local overseer = require("overseer")
    overseer.setup(opts)

    -- ==================== Custom Templates ====================

    -- Go tasks
    overseer.register_template({
      name = "go run",
      builder = function()
        return {
          cmd = { "go", "run", "." },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        filetype = { "go" },
      },
    })

    overseer.register_template({
      name = "go run (current file)",
      builder = function()
        return {
          cmd = { "go", "run", vim.fn.expand("%") },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        filetype = { "go" },
      },
    })

    overseer.register_template({
      name = "go build",
      builder = function()
        return {
          cmd = { "go", "build", "-v", "." },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        filetype = { "go" },
      },
    })

    overseer.register_template({
      name = "go test",
      builder = function()
        return {
          cmd = { "go", "test", "-v", "./..." },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        filetype = { "go" },
      },
    })

    overseer.register_template({
      name = "go test (current package)",
      builder = function()
        local dir = vim.fn.expand("%:p:h")
        return {
          cmd = { "go", "test", "-v", "./" .. vim.fn.fnamemodify(dir, ":t") },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        filetype = { "go" },
      },
    })

    overseer.register_template({
      name = "go mod tidy",
      builder = function()
        return {
          cmd = { "go", "mod", "tidy" },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        filetype = { "go", "gomod" },
      },
    })

    -- PHP tasks
    overseer.register_template({
      name = "php run",
      builder = function()
        return {
          cmd = { "php", vim.fn.expand("%") },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        filetype = { "php" },
      },
    })

    overseer.register_template({
      name = "php artisan serve",
      builder = function()
        return {
          cmd = { "php", "artisan", "serve" },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        callback = function()
          return vim.fn.filereadable("artisan") == 1
        end,
      },
    })

    overseer.register_template({
      name = "phpunit",
      builder = function()
        return {
          cmd = { "./vendor/bin/phpunit" },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        callback = function()
          return vim.fn.filereadable("phpunit.xml") == 1
            or vim.fn.filereadable("phpunit.xml.dist") == 1
        end,
      },
    })

    overseer.register_template({
      name = "composer install",
      builder = function()
        return {
          cmd = { "composer", "install" },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        callback = function()
          return vim.fn.filereadable("composer.json") == 1
        end,
      },
    })

    -- Python tasks
    overseer.register_template({
      name = "python run",
      builder = function()
        -- Try to use venv if available
        local python = "python3"
        local cwd = vim.fn.getcwd()
        if vim.fn.executable(cwd .. "/venv/bin/python") == 1 then
          python = cwd .. "/venv/bin/python"
        elseif vim.fn.executable(cwd .. "/.venv/bin/python") == 1 then
          python = cwd .. "/.venv/bin/python"
        end
        return {
          cmd = { python, vim.fn.expand("%") },
          cwd = cwd,
        }
      end,
      condition = {
        filetype = { "python" },
      },
    })

    overseer.register_template({
      name = "pytest",
      builder = function()
        return {
          cmd = { "pytest", "-v" },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        callback = function()
          return vim.fn.filereadable("pytest.ini") == 1
            or vim.fn.filereadable("pyproject.toml") == 1
            or vim.fn.isdirectory("tests") == 1
        end,
      },
    })

    overseer.register_template({
      name = "pip install -r requirements.txt",
      builder = function()
        return {
          cmd = { "pip", "install", "-r", "requirements.txt" },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        callback = function()
          return vim.fn.filereadable("requirements.txt") == 1
        end,
      },
    })

    -- Rust tasks
    overseer.register_template({
      name = "cargo run",
      builder = function()
        return {
          cmd = { "cargo", "run" },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        filetype = { "rust" },
      },
    })

    overseer.register_template({
      name = "cargo build",
      builder = function()
        return {
          cmd = { "cargo", "build" },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        filetype = { "rust" },
      },
    })

    overseer.register_template({
      name = "cargo build (release)",
      builder = function()
        return {
          cmd = { "cargo", "build", "--release" },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        filetype = { "rust" },
      },
    })

    overseer.register_template({
      name = "cargo test",
      builder = function()
        return {
          cmd = { "cargo", "test" },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        filetype = { "rust" },
      },
    })

    overseer.register_template({
      name = "cargo check",
      builder = function()
        return {
          cmd = { "cargo", "check" },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        filetype = { "rust" },
      },
    })

    -- Node.js / TypeScript tasks
    overseer.register_template({
      name = "node run",
      builder = function()
        return {
          cmd = { "node", vim.fn.expand("%") },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        filetype = { "javascript" },
      },
    })

    overseer.register_template({
      name = "npx ts-node",
      builder = function()
        return {
          cmd = { "npx", "ts-node", vim.fn.expand("%") },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        filetype = { "typescript" },
      },
    })

    overseer.register_template({
      name = "npm run dev",
      builder = function()
        return {
          cmd = { "npm", "run", "dev" },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        callback = function()
          return vim.fn.filereadable("package.json") == 1
        end,
      },
    })

    overseer.register_template({
      name = "npm run build",
      builder = function()
        return {
          cmd = { "npm", "run", "build" },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        callback = function()
          return vim.fn.filereadable("package.json") == 1
        end,
      },
    })

    overseer.register_template({
      name = "npm test",
      builder = function()
        return {
          cmd = { "npm", "test" },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        callback = function()
          return vim.fn.filereadable("package.json") == 1
        end,
      },
    })

    overseer.register_template({
      name = "npm install",
      builder = function()
        return {
          cmd = { "npm", "install" },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        callback = function()
          return vim.fn.filereadable("package.json") == 1
        end,
      },
    })

    -- C/C++ tasks
    overseer.register_template({
      name = "gcc compile",
      builder = function()
        local file = vim.fn.expand("%")
        local output = vim.fn.expand("%:r")
        return {
          cmd = { "gcc", "-g", "-o", output, file },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        filetype = { "c" },
      },
    })

    overseer.register_template({
      name = "g++ compile",
      builder = function()
        local file = vim.fn.expand("%")
        local output = vim.fn.expand("%:r")
        return {
          cmd = { "g++", "-g", "-o", output, file },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        filetype = { "cpp" },
      },
    })

    overseer.register_template({
      name = "make",
      builder = function()
        return {
          cmd = { "make" },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        callback = function()
          return vim.fn.filereadable("Makefile") == 1 or vim.fn.filereadable("makefile") == 1
        end,
      },
    })

    overseer.register_template({
      name = "cmake build",
      builder = function()
        return {
          cmd = { "cmake", "--build", "build" },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        callback = function()
          return vim.fn.filereadable("CMakeLists.txt") == 1
        end,
      },
    })

    -- Docker tasks
    overseer.register_template({
      name = "docker compose up",
      builder = function()
        return {
          cmd = { "docker", "compose", "up", "-d" },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        callback = function()
          return vim.fn.filereadable("docker-compose.yml") == 1
            or vim.fn.filereadable("docker-compose.yaml") == 1
            or vim.fn.filereadable("compose.yml") == 1
        end,
      },
    })

    overseer.register_template({
      name = "docker compose down",
      builder = function()
        return {
          cmd = { "docker", "compose", "down" },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        callback = function()
          return vim.fn.filereadable("docker-compose.yml") == 1
            or vim.fn.filereadable("docker-compose.yaml") == 1
            or vim.fn.filereadable("compose.yml") == 1
        end,
      },
    })

    overseer.register_template({
      name = "docker compose logs",
      builder = function()
        return {
          cmd = { "docker", "compose", "logs", "-f" },
          cwd = vim.fn.getcwd(),
        }
      end,
      condition = {
        callback = function()
          return vim.fn.filereadable("docker-compose.yml") == 1
            or vim.fn.filereadable("docker-compose.yaml") == 1
            or vim.fn.filereadable("compose.yml") == 1
        end,
      },
    })
  end,
}
