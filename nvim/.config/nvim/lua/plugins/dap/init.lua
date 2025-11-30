-- Core DAP configuration: UI, keymaps, highlights, mason
-- Language-specific configs are loaded from separate files

return {
  -- DAP UI
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
    config = function()
      local dapui = require("dapui")
      dapui.setup({
        layouts = {
          {
            elements = {
              { id = "scopes", size = 0.25 },
              { id = "breakpoints", size = 0.25 },
              { id = "stacks", size = 0.25 },
              { id = "watches", size = 0.25 },
            },
            size = 40,
            position = "left",
          },
          {
            elements = {
              { id = "repl", size = 0.5 },
              { id = "console", size = 0.5 },
            },
            size = 10,
            position = "bottom",
          },
        },
      })

      -- Auto open/close UI
      local dap = require("dap")
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

  -- Virtual text (show variable values inline)
  {
    "theHamsta/nvim-dap-virtual-text",
    dependencies = { "mfussenegger/nvim-dap", "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("nvim-dap-virtual-text").setup({
        enabled = true,
        enabled_commands = true,
        highlight_changed_variables = true,
        highlight_new_as_changed = false,
        show_stop_reason = true,
        commented = false,
        virt_text_pos = "eol",
      })
    end,
  },

  -- Persistent breakpoints (saves across sessions)
  {
    "Weissle/persistent-breakpoints.nvim",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      require("persistent-breakpoints").setup({
        load_breakpoints_event = { "BufReadPost" },
      })
    end,
  },

  -- Mason auto-install adapters
  {
    "jay-babu/mason-nvim-dap.nvim",
    dependencies = { "mason-org/mason.nvim", "mfussenegger/nvim-dap" },
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "php-debug-adapter",
        "codelldb",
        "delve",
        "node-debug2-adapter",
        "debugpy",
      })
    end,
  },

  -- Core DAP with keymaps, highlights, and ALL language configs
  {
    "mfussenegger/nvim-dap",
    keys = {
      -- Breakpoints (using persistent-breakpoints for session persistence)
      { "<leader>db", function() require("persistent-breakpoints.api").toggle_breakpoint() end, desc = "Toggle Breakpoint" },
      { "<leader>dB", function() require("persistent-breakpoints.api").set_conditional_breakpoint() end, desc = "Conditional Breakpoint" },
      { "<leader>dX", function() require("persistent-breakpoints.api").clear_all_breakpoints() end, desc = "Clear All Breakpoints" },
      { "<F9>", function() require("persistent-breakpoints.api").toggle_breakpoint() end, desc = "Toggle Breakpoint" },

      -- Debug control
      { "<leader>dc", function() require("dap").continue() end, desc = "Continue/Start" },
      { "<leader>di", function() require("dap").step_into() end, desc = "Step Into" },
      { "<leader>dn", function() require("dap").step_over() end, desc = "Step Over" },
      { "<leader>do", function() require("dap").step_out() end, desc = "Step Out" },
      { "<F4>", function() require("dap").run_to_cursor() end, desc = "Run to Cursor" },
      { "<F5>", function() require("dap").step_into() end, desc = "Step Into" },
      { "<F6>", function() require("dap").step_over() end, desc = "Step Over" },
      { "<F7>", function() require("dap").step_out() end, desc = "Step Out" },
      { "<F8>", function() require("dap").continue() end, desc = "Continue/Start" },

      -- UI & REPL
      { "<leader>du", function() require("dapui").toggle() end, desc = "Toggle DAP UI" },
      { "<leader>dU", function() require("dapui").open({ reset = true }) end, desc = "Reset DAP UI" },
      { "<leader>dw", function() require("dapui").elements.watches.add(vim.fn.expand("<cword>")) end, desc = "Add Watch" },
      { "<leader>de", function() require("dap.ui.widgets").hover() end, desc = "Evaluate Expression (hover)" },
      { "<F2>", function() require("dap.ui.widgets").hover() end, desc = "Evaluate Expression (hover)" },
      { "<leader>dE", function() require("dapui").eval() end, desc = "Evaluate Custom Expression" },
      { "<leader>dr", function() require("dap").repl.open() end, desc = "Open Debug REPL" },
      { "<leader>dl", function() require("dap").focus_frame() end, desc = "Go to last stop (focus frame)" },
      { "<leader>dq", function() require("dap").terminate() end, desc = "Stop Debugging" },
    },
    config = function()
      local dap = require("dap")
      local mason_path = vim.fn.stdpath("data") .. "/mason/packages"

      -- Define highlight groups for DAP
      vim.api.nvim_set_hl(0, "DapBreakpoint", { fg = "#ffffff", bg = "#2e7d32" })
      vim.api.nvim_set_hl(0, "DapBreakpointCondition", { fg = "#ffffff", bg = "#2e7d32" })
      vim.api.nvim_set_hl(0, "DapBreakpointRejected", { fg = "#ff0000", bg = "#4b0000" })
      vim.api.nvim_set_hl(0, "DapStopped", { fg = "#facc15" })
      vim.api.nvim_set_hl(0, "DapStoppedLine", { bg = "#3d3d00" })
      vim.api.nvim_set_hl(0, "DapLogPoint", { fg = "#00ffff", bg = "#003f3f" })

      -- Define breakpoint signs with line highlighting
      vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DapBreakpoint", linehl = "DapBreakpoint", numhl = "" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "●", texthl = "DapBreakpointCondition", linehl = "DapBreakpointCondition", numhl = "" })
      vim.fn.sign_define("DapBreakpointRejected", { text = "○", texthl = "DapBreakpointRejected", linehl = "", numhl = "" })
      vim.fn.sign_define("DapStopped", { text = "→", texthl = "DapStopped", linehl = "DapStoppedLine", numhl = "" })
      vim.fn.sign_define("DapLogPoint", { text = "◆", texthl = "DapLogPoint", linehl = "", numhl = "" })

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

      -- ==================== C/C++/Rust (CodeLLDB) ====================
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

      -- ==================== Node.js/TypeScript ====================
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
