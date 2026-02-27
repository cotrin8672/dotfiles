return {
  {
    'kawre/neotab.nvim',
    event = 'InsertEnter',
    opts = {
      tabkey = '',
      act_as_tab = false,
      completion = {
        enabled = true,
      },
      ignore = {
        comments = true,
      },
    },
  },
  {
    'saghen/blink.cmp',
    optional = true,
    opts = function(_, opts)
      opts.keymap = opts.keymap or {}

      local tab_chain = opts.keymap['<Tab>']
      if type(tab_chain) ~= 'table' then
        tab_chain = { 'snippet_forward', 'fallback' }
      end
      local has_neotab = false
      for _, item in ipairs(tab_chain) do
        if type(item) == 'function' then
          has_neotab = true
          break
        end
      end
      if not has_neotab then
        local fallback_index
        for i, item in ipairs(tab_chain) do
          if item == 'fallback' then
            fallback_index = i
            break
          end
        end
        local tabout = function(_)
          return require('neotab').tabout()
        end
        if fallback_index then
          table.insert(tab_chain, fallback_index, tabout)
        else
          table.insert(tab_chain, tabout)
          table.insert(tab_chain, 'fallback')
        end
      end
      opts.keymap['<Tab>'] = tab_chain

      local stab_chain = opts.keymap['<S-Tab>']
      if type(stab_chain) ~= 'table' then
        stab_chain = { 'snippet_backward', 'fallback' }
      end
      local has_rev = false
      for _, item in ipairs(stab_chain) do
        if type(item) == 'function' then
          has_rev = true
          break
        end
      end
      if not has_rev then
        local fallback_index
        for i, item in ipairs(stab_chain) do
          if item == 'fallback' then
            fallback_index = i
            break
          end
        end
        local reverse_tabout = function(_)
          return require('neotab').taboutReverse()
        end
        if fallback_index then
          table.insert(stab_chain, fallback_index, reverse_tabout)
        else
          table.insert(stab_chain, reverse_tabout)
          table.insert(stab_chain, 'fallback')
        end
      end
      opts.keymap['<S-Tab>'] = stab_chain
    end,
  },
}
