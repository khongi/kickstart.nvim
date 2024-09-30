-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

-- Helper function for getting telescope options
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
          ['tf'] = 'telescope_find',
          ['tg'] = 'telescope_grep',
          ['T'] = 'trash',
          ['t'] = 'none',
          ['B'] = 'show_buffers_right',
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
        telescope_find = function(state)
          local node = state.tree:get_node()
          local path = node:get_id()

          require('telescope.builtin').find_files(getTelescopeOpts(state, path))
        end,
        telescope_grep = function(state)
          local node = state.tree:get_node()
          local path = node:get_id()
          require('telescope.builtin').live_grep(getTelescopeOpts(state, path))
        end,
        trash = function(state)
          local inputs = require 'neo-tree.ui.inputs'
          local node = state.tree:get_node()
          if node.type == 'message' then
            return
          end
          local _, name = require('neo-tree.utils').split_path(node.path)
          local msg = string.format("Are you sure you want to trash '%s'?", name)
          inputs.confirm(msg, function(confirmed)
            if not confirmed then
              return
            end
            vim.api.nvim_command('silent !trash -F ' .. node.path)
            require('neo-tree.sources.manager').refresh(state)
          end)
        end,
        trash_visual = function(state, selected_nodes)
          local inputs = require 'neo-tree.ui.inputs'
          local paths_to_trash = {}
          for _, node in ipairs(selected_nodes) do
            if node.type ~= 'message' then
              table.insert(paths_to_trash, node.path)
            end
          end
          local msg = 'Are you sure you want to trash ' .. #paths_to_trash .. ' items?'
          inputs.confirm(msg, function(confirmed)
            if not confirmed then
              return
            end
            for _, path in ipairs(paths_to_trash) do
              vim.api.nvim_command('silent !trash -F ' .. path)
            end
            require('neo-tree.sources.manager').refresh(state)
          end)
        end,
        show_buffers_right = function()
          vim.api.nvim_exec2('Neotree focus buffers right', {})
        end,
      },
      hijack_netrw_behavior = 'open_default',
    },
  },
}
