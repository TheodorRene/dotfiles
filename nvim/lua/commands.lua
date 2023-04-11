vim.cmd([[
    :command! Rocaf :!rocaf %
    :command! FindFiles :lua require"telescope.builtin".find_files()
    :command! StageHunk :Gitsigns stage_hunk
    :command! UndoStageHunk :Gitsigns undo_stage_hunk
    :command! ResetHunk :Gitsigns reset_hunk
    :command! PreviewHunk :Gitsigns preview_hunk
    :command! BlameLine :Gitsigns blame_line
    :command! AddFile :Git add %
    :command! Hover :lua vim.lsp.buf.hover()
    :command! ResetTS :write | edit | TSBufEnable highlight
    :command! -nargs=* ChangeDir :chdir 
    ]])
vim.api.nvim_create_user_command("Scrollbind", ":windo set scrollbind!", {})

