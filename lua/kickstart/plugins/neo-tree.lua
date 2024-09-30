-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

return {
  'nvim-neo-tree/neo-tree.nvim',
  lazy = false,
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
  },
  cmd = 'Neotree',
  keys = {
    { '\\', ':Neotree reveal<CR>', desc = 'NeoTree reveal', silent = true },
  },
  opts = {
    filesystem = {
      filtered_items = {
        hide_dotfiles = false,
      },
      window = {
        mappings = {
          ['\\'] = 'close_window',
          ['o'] = 'open_with_system',
          ['D'] = 'diff_two_files',
          ['tf'] = 'find_files',
          ['ts'] = 'search_in_files',
        },
      },
      commands = {
        open_with_system = function(state)
          local node = state.tree:get_node()
          local path = node:get_id()
          -- macOS: open file in default application in the background.
          vim.fn.jobstart({ 'open', '-g', path }, { detach = true })
        end,
        diff_two_files = function(state)
          local node = state.tree:get_node()
          local log = require 'neo-tree.log'
          state.clipboard = state.clipboard or {}
          if diff_Node and diff_Node ~= tostring(node.id) then
            local current_Diff = node.id
            require('neo-tree.utils').open_file(state, diff_Node, open)
            vim.cmd('vert diffs ' .. current_Diff)
            log.info('Diffing ' .. diff_Name .. ' against ' .. node.name)
            diff_Node = nil
            current_Diff = nil
            state.clipboard = {}
            require('neo-tree.ui.renderer').redraw(state)
          else
            local existing = state.clipboard[node.id]
            if existing and existing.action == 'diff' then
              state.clipboard[node.id] = nil
              diff_Node = nil
              require('neo-tree.ui.renderer').redraw(state)
            else
              state.clipboard[node.id] = { action = 'diff', node = node }
              diff_Name = state.clipboard[node.id].node.name
              diff_Node = tostring(state.clipboard[node.id].node.id)
              log.info('Diff source file ' .. diff_Name)
              require('neo-tree.ui.renderer').redraw(state)
            end
          end
        end,
        find_files = function(state)
          local node = state.tree:get_node()
          local path = node:get_id()

          local function getTelescopeOpts(state, path)
            return {
              cwd = path,
              search_dirs = { path },
              attach_mappings = function(prompt_bufnr, map)
                local actions = require 'telescope.actions'
                actions.select_default:replace(function()
                  actions.close(prompt_bufnr)
                  local action_state = require 'telescope.actions.state'
                  local selection = action_state.get_selected_entry()
                  local filename = selection.filename
                  if filename == nil then
                    filename = selection[1]
                  end
                  -- any way to open the file without triggering auto-close event of neo-tree?
                  ---@diagnostic disable-next-line: missing-parameter
                  require('neo-tree.sources.filesystem').navigate(state, state.path, filename)
                end)
                return true
              end,
            }
          end

          require('telescope.builtin').find_files(getTelescopeOpts(state, path))
        end,
        search_in_files = function(state)
          local node = state.tree:get_node()
          require('telescope.builtin').live_grep {
            search_dirs = { node.absolute_path },
            prompt_title = 'Live Grep in Selected Directory',
          }
        end,
      },
      hijack_netrw_behavior = 'open_default',
    },
  },
}
