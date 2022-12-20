    vim.cmd([[
    :command Rocaf :!rocaf % <CR>
    :command FindFiles :lua require"telescope.builtin".find_files()<cr>
    ]])
