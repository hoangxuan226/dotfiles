return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      {
        "j-hui/fidget.nvim",
        opts = {
          notification = {
            window = {
              winblend = 0,
            },
          },
        },
      },
      "ravitemer/codecompanion-history.nvim",
      { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
      { "nvim-lua/plenary.nvim", branch = "master" },
    },
    keys = {
      { "<leader>a", "<Nop>", desc = "AI" },
      { "<leader>aa", "<cmd>CodeCompanionActions<cr>", desc = "Actions", mode = { "n", "v" } },
      { "<leader>ac", "<cmd>CodeCompanionChat Toggle<cr>", desc = "Toggle Chat", mode = { "n", "v" } },
      { "<leader>ai", "<cmd>CodeCompanion<cr>", desc = "Inline Chat", mode = { "n", "v" } },
      { "<leader>av", "<cmd>CodeCompanionChat Add<cr>", desc = "Add code to a chat buffer", mode = { "v" } },
      {
        "<leader>aq",
        function()
          require("config.codecompanion.quick-model").open({
            "copilot:gpt-5-mini",
            "copilot:gemini-3.1-pro-preview",
          })
        end,
        desc = "Quick chat presets",
        mode = { "n" },
      },
    },
    init = function()
      require("config.components.fidget.codecompanion-spinner"):init()
    end,
    config = function()
      -- Apply monkey-patch
      require("config.codecompanion.history.patch-history-model-restore")() -- patch model not being restored correctly from chat history
      require("config.codecompanion.patch-gpt5-mini")() -- patch using gpt-5 mini and clearing stale param values

      require("codecompanion").setup({
        interactions = {
          chat = {
            adapter = {
              name = "copilot",
              model = "gemini-3.1-pro-preview",
            },
            tools = {
              opts = {
                default_tools = { "agent", "fetch_webpage" },
              },
              -- Disable approval for read-only tools
              ["read_file"] = {
                opts = { require_approval_before = false },
              },
              ["file_search"] = {
                opts = { require_approval_before = false },
              },
              ["grep_search"] = {
                opts = { require_approval_before = false },
              },
              ["list_code_usages"] = {
                opts = { require_approval_before = false },
              },
              ["get_changed_files"] = {
                opts = { require_approval_before = false },
              },
              ["run_command"] = {
                opts = {
                  allowed_in_yolo_mode = true,
                  require_approval_before = function(tool, _)
                    local cmd = tool.args.cmd or ""
                    local safe_prefixes = {
                      "cat ",
                      "grep ",
                      "ls ",
                      "sed -n ", -- Pattern matching print only
                      "find ",
                      "pwd",
                    }

                    -- If the command matches a safe prefix, auto-approve it (return false)
                    for _, prefix in ipairs(safe_prefixes) do
                      if cmd:sub(1, #prefix) == prefix then
                        return false
                      end
                    end

                    -- Otherwise, require explicit manual approval (return true)
                    return true
                  end,
                },
              },
            },
            -- keymaps = {
            --   my_custom_action = {
            --     description = "My custom action (example)",
            --     modes = { n = "gm" }, -- Normal mode: gm
            --     callback = function(chat)
            --       -- chat là đối tượng CodeCompanion.Chat
            --       -- require("codecompanion.interactions.chat").last_chat():change_model({ model = "gpt-5-mini" })
            --       vim.notify("Custom action triggered for chat: " .. tostring(chat.id))
            --       -- hoặc gọi module riêng: require("my_module").do_something(chat)
            --     end,
            --   },
            -- },
          },
          inline = {
            adapter = {
              name = "copilot",
              model = "gemini-3.1-pro-preview",
            },
          },
          cmd = {
            adapter = {
              name = "copilot",
              model = "gemini-3.1-pro-preview",
            },
          },
        },
        rules = {
          default = {
            files = { ".codecompanionrules/*" },
          },
        },
        opts = {
          per_project_config = {
            -- Files in the cwd that contain project configuration
            -- Example of per_project_config '.codecompanion.lua' file:
            -- return {
            --   interactions = {
            --     chat = {
            --       adapter = {
            --         name = "copilot",
            --         model = "claude-opus-4.6",
            --       },
            --     },
            --   },
            --   rules = {
            --     default = {
            --       files = { "test.md", ".rules/*" },
            --     },
            --   },
            -- }
            files = { ".codecompanion.lua" },
            -- paths = {}, -- Per-path config: { ["~/Code/myproject"] = { ... } }
          },
        },
        extensions = {
          history = {
            enabled = true,
            opts = {
              -- Keymap to open history from chat buffer (default: gh)
              keymap = "gh",
              -- Keymap to save the current chat manually (when auto_save is disabled)
              save_chat_keymap = "sc",
              -- Save all chats by default (disable to save only manually using 'sc')
              auto_save = true,
              -- Number of days after which chats are automatically deleted (0 to disable)
              expiration_days = 0,
              -- Picker interface (auto resolved to a valid picker)
              picker = "snacks", --- ("telescope", "snacks", "fzf-lua", or "default")
              ---Optional filter function to control which chats are shown when browsing
              chat_filter = nil, -- function(chat_data) return boolean end
              -- Customize picker keymaps (optional)
              picker_keymaps = {
                rename = { n = "r", i = "<M-r>" },
                delete = { n = "d", i = "<M-d>" },
                duplicate = { n = "<C-y>", i = "<C-y>" },
              },
              ---Automatically generate titles for new chats
              auto_generate_title = true,
              title_generation_opts = {
                ---Adapter for generating titles (defaults to current chat adapter)
                adapter = "copilot", -- "copilot"
                ---Model for generating titles (defaults to current chat model)
                model = "gpt-5-mini", -- "gpt-4o"
                ---Number of user prompts after which to refresh the title (0 to disable)
                refresh_every_n_prompts = 0, -- e.g., 3 to refresh after every 3rd user prompt
                ---Maximum number of times to refresh the title (default: 3)
                max_refreshes = 3,
                format_title = function(original_title)
                  -- this can be a custom function that applies some custom
                  -- formatting to the title.
                  return original_title
                end,
              },
              ---On exiting and entering neovim, loads the last chat on opening chat
              continue_last_chat = false,
              ---When chat is cleared with `gx` delete the chat from history
              delete_on_clearing_chat = true,
              ---Directory path to save the chats
              dir_to_save = vim.fn.stdpath("data") .. "/codecompanion-history",
              ---Enable detailed logging for history extension
              enable_logging = false,

              -- Summary system
              summary = {
                -- Keymap to generate summary for current chat (default: "gcs")
                create_summary_keymap = "gcs",
                -- Keymap to browse summaries (default: "gbs")
                browse_summaries_keymap = "gbs",

                generation_opts = {
                  adapter = nil, -- defaults to current chat adapter
                  model = nil, -- defaults to current chat model
                  context_size = 90000, -- max tokens that the model supports
                  include_references = true, -- include slash command content
                  include_tool_outputs = true, -- include tool execution results
                  system_prompt = nil, -- custom system prompt (string or function)
                  format_summary = nil, -- custom function to format generated summary e.g to remove <think/> tags from summary
                },
              },

              -- Memory system (requires VectorCode CLI)
              memory = {
                -- Automatically index summaries when they are generated
                auto_create_memories_on_summary_generation = true,
                -- Path to the VectorCode executable
                vectorcode_exe = "vectorcode",
                -- Tool configuration
                tool_opts = {
                  -- Default number of memories to retrieve
                  default_num = 10,
                },
                -- Enable notifications for indexing progress
                notify = true,
                -- Index all existing memories on startup
                -- (requires VectorCode 0.6.12+ for efficient incremental indexing)
                index_on_startup = false,
              },
            },
          },
        },
      })
    end,
  },
}
