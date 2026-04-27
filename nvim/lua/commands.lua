vim.cmd([[
    :command! Rocaf :!rocaf %
    :command! FindFiles :lua require("lazy").load({plugins = {"telescope.nvim"}}); require"telescope.builtin".find_files()
    :command! StageHunk :lua require("lazy").load({plugins = {"gitsigns.nvim"}}); vim.cmd("Gitsigns stage_hunk")
    :command! UndoStageHunk :lua require("lazy").load({plugins = {"gitsigns.nvim"}}); vim.cmd("Gitsigns undo_stage_hunk")
    :command! ResetHunk :lua require("lazy").load({plugins = {"gitsigns.nvim"}}); vim.cmd("Gitsigns reset_hunk")
    :command! PreviewHunk :lua require("lazy").load({plugins = {"gitsigns.nvim"}}); vim.cmd("Gitsigns preview_hunk")
    :command! BlameLine :lua require("lazy").load({plugins = {"gitsigns.nvim"}}); vim.cmd("Gitsigns blame_line")
    :command! AddFile :Git add %
    :command! OpenPr :!git prview
    :command! OpenJira :!git jira
    :command! Hover :lua vim.lsp.buf.hover()
    :command! ResetTS :write | edit | TSBufEnable highlight
    :command! -nargs=* ChangeDir :chdir
    :command! ValApp :chdir ~/dev/blank/valstuff/app
    :command! Projects :lua require("lazy").load({plugins = {"telescope.nvim"}}); vim.cmd("Telescope workspaces")
    :command! Reminder :e ~/dev/reminder_for_tomorrow.md
    :command! AstGrep :lua require("lazy").load({plugins = {"telescope.nvim"}}); vim.cmd("Telescope ast_grep")
    :command! PeekDefinition :lua require("lazy").load({plugins = {"lspsaga.nvim"}}); vim.cmd("Lspsaga peek_definition")
    :command! Finder :lua require("lazy").load({plugins = {"lspsaga.nvim"}}); vim.cmd("Lspsaga finder")
    :command! Rename :lua require("lazy").load({plugins = {"lspsaga.nvim"}}); vim.cmd("Lspsaga rename")
    :command! DiffLastCommit :lua require("lazy").load({plugins = {"neogit"}}); vim.cmd("Neogit commit diff HEAD^")
    :command! CopyFilename :let @+ = expand('%:p')
    :command! Fold execute "normal zA"
    :command! GitResetCurrentLine :exec '.!git checkout -- '.shellescape(expand('%')).':'.line('.')
    :command! ResetCurrentLine :lua require("lazy").load({plugins = {"gitsigns.nvim"}}); require('gitsigns').reset_hunk({vim.fn.line('.'), vim.fn.line('.')})
    :command! Dotfiles :lua require("lazy").load({plugins = {"telescope.nvim"}}); require('telescope.builtin').find_files({cwd = '~/dotfiles'})
    ]])
vim.api.nvim_create_user_command("Scrollbind", ":windo set scrollbind!", {})

