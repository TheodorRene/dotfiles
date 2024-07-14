vim.cmd([[
    :command! Rocaf :!rocaf %
    :command! FindFiles :lua require"telescope.builtin".find_files()
    :command! StageHunk :Gitsigns stage_hunk
    :command! UndoStageHunk :Gitsigns undo_stage_hunk
    :command! ResetHunk :Gitsigns reset_hunk
    :command! PreviewHunk :Gitsigns preview_hunk
    :command! BlameLine :Gitsigns blame_line
    :command! AddFile :Git add %
    :command! OpenPr :!git prview
    :command! OpenJira :!git jira
    :command! Hover :lua vim.lsp.buf.hover()
    :command! ResetTS :write | edit | TSBufEnable highlight
    :command! -nargs=* ChangeDir :chdir 
    :command! ValApp :chdir ~/dev/blank/valstuff/app
    :command! Projects :Telescope workspaces
    :command! Reminder :e ~/dev/reminder_for_tomorrow.md
    :command! AstGrep :Telescope ast_grep
    :command! PeekDefinition :Lspsaga peek_definition
    :command! Finder :Lspsaga finder
    ]])
vim.api.nvim_create_user_command("Scrollbind", ":windo set scrollbind!", {})

