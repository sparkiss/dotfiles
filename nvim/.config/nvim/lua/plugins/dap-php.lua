return {
  -- DAP UI (nice panels for scopes, breakpoints, etc.)
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
    config = function()
      local dap, dapui = require("dap"), require("dapui")
      dapui.setup()
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end
    end,
  },

  -- Mason helper to auto-install adapters
  {
    "jay-babu/mason-nvim-dap.nvim",
    dependencies = { "williamboman/mason.nvim", "mfussenegger/nvim-dap" },
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "php-debug-adapter",
        "codelldb", -- C/C++/Rust
        "delve", -- Go
        "node-debug2-adapter", -- Node.js
        "debugpy", -- Python
      })
    end,
  },

  -- PHP adapter & configuration
  {
    "mfussenegger/nvim-dap",
    keys = {
      {
        "<leader>db",
        function()
          require("dap").toggle_breakpoint()
        end,
        desc = "Toggle Breakpoint",
      },
      {
        "<leader>dB",
        function()
          require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
        end,
        desc = "Conditional Breakpoint",
      },
      {
        "<leader>dc",
        function()
          require("dap").continue()
        end,
        desc = "Continue/Start",
      },

      {
        "<leader>di",
        function()
          require("dap").step_into()
        end,
        desc = "Step Into",
      },
      {
        "<leader>dn",
        function()
          require("dap").step_over()
        end,
        desc = "Step Over",
      },
      {
        "<leader>do",
        function()
          require("dap").step_out()
        end,
        desc = "Step Out",
      },

      -- Toggle UI
      {
        "<leader>du",
        function()
          require("dapui").toggle()
        end,
        desc = "Toggle DAP UI",
      },
      -- Stop / Restart
      {
        "<leader>dq",
        function()
          require("dap").terminate()
        end,
        desc = "Stop Debugging",
      },

      {
        "<F4>",
        function()
          require("dap").run_to_cursor()
        end,
        desc = "Run to Cursor",
      },
      {
        "<F5>",
        function()
          require("dap").step_into()
        end,
        desc = "Step Into",
      },
      {
        "<F6>",
        function()
          require("dap").step_over()
        end,
        desc = "Step Over",
      },
      {
        "<F7>",
        function()
          require("dap").step_out()
        end,
        desc = "Step Out",
      },
      {
        "<F8>",
        function()
          require("dap").continue()
        end,
        desc = "Continue/Start",
      },
      {
        "<F9>",
        function()
          require("dap").toggle_breakpoint()
        end,
        desc = "Toggle Breakpoint",
      },
      -- Evaluate under cursor
      {
        "<leader>de",
        function()
          require("dap.ui.widgets").hover()
        end,
        desc = "Evaluate Expression (hover)",
      },
      {
        "<F2>",
        function()
          require("dap.ui.widgets").hover()
        end,
        desc = "Evaluate Expression (hover)",
      },
      -- Prompt for manual expression input
      {
        "<leader>dE",
        function()
          require("dapui").eval()
        end,
        desc = "Evaluate Custom Expression",
      },
      -- Open REPL for on-the-fly evals
      {
        "<leader>dr",
        function()
          require("dap").repl.open()
        end,
        desc = "Open Debug REPL",
      },
      {
        "<leader>dl",
        function()
          require("dap").focus_frame()
        end,
        desc = "Go to last stop (focus frame)",
      },
    },
    ft = { "php", "c", "cpp", "rust", "go", "javascript", "typescript", "python" },
    config = function()
      local dap = require("dap")
      local mason_path = vim.fn.stdpath("data") .. "/mason/packages"

      -- ==================== PHP ====================
      local php_debug = mason_path .. "/php-debug-adapter/extension/out/phpDebug.js"
      dap.adapters.php = {
        type = "executable",
        command = "node",
        args = { php_debug },
      }

      dap.configurations.php = {
        {
          type = "php",
          request = "launch",
          name = "Listen for Xdebug (9003)",
          port = 9003,
          log = false,
          xdebugSettings = { max_children = 256, max_data = 1024, max_depth = 5 },
        },
      }

      -- ==================== C/C++/Rust ====================
      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
          command = mason_path .. "/codelldb/extension/adapter/codelldb",
          args = { "--port", "${port}" },
        },
      }

      dap.configurations.c = {
        {
          name = "Launch file",
          type = "codelldb",
          request = "launch",
          program = function()
            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
        },
      }
      dap.configurations.cpp = dap.configurations.c
      dap.configurations.rust = {
        {
          name = "Launch file",
          type = "codelldb",
          request = "launch",
          program = function()
            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
        },
      }

      -- ==================== Go ====================
      dap.adapters.delve = {
        type = "server",
        port = "${port}",
        executable = {
          command = "dlv",
          args = { "dap", "-l", "127.0.0.1:${port}" },
        },
      }

      dap.configurations.go = {
        {
          type = "delve",
          name = "Debug",
          request = "launch",
          program = "${file}",
        },
        {
          type = "delve",
          name = "Debug test",
          request = "launch",
          mode = "test",
          program = "${file}",
        },
        {
          type = "delve",
          name = "Debug test (go.mod)",
          request = "launch",
          mode = "test",
          program = "./${relativeFileDirname}",
        },
      }

      -- ==================== Node.js ====================
      dap.adapters.node2 = {
        type = "executable",
        command = "node",
        args = { mason_path .. "/node-debug2-adapter/out/src/nodeDebug.js" },
      }

      dap.configurations.javascript = {
        {
          name = "Launch",
          type = "node2",
          request = "launch",
          program = "${file}",
          cwd = vim.fn.getcwd(),
          sourceMaps = true,
          protocol = "inspector",
          console = "integratedTerminal",
        },
        {
          name = "Attach to process",
          type = "node2",
          request = "attach",
          processId = require("dap.utils").pick_process,
        },
      }
      dap.configurations.typescript = dap.configurations.javascript

      -- ==================== Python ====================
      dap.adapters.python = {
        type = "executable",
        command = mason_path .. "/debugpy/venv/bin/python",
        args = { "-m", "debugpy.adapter" },
      }

      dap.configurations.python = {
        {
          type = "python",
          request = "launch",
          name = "Launch file",
          program = "${file}",
          pythonPath = function()
            local cwd = vim.fn.getcwd()
            if vim.fn.executable(cwd .. "/venv/bin/python") == 1 then
              return cwd .. "/venv/bin/python"
            elseif vim.fn.executable(cwd .. "/.venv/bin/python") == 1 then
              return cwd .. "/.venv/bin/python"
            else
              return "/usr/bin/python"
            end
          end,
        },
      }
    end,
  },
}
