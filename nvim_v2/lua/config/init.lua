-- Load modules in order. Options and pack go first so plugins are available
-- before keymaps and LSP try to reference them.
require('config.options')
require('config.pack')
require('config.diagnostics')
require('config.lsp')
require('config.keymaps')
require('config.autocmds')
require('config.commands')

-- ── Experimental ui2 ──────────────────────────────────────────────────────────
-- Redesigned messages + cmdline UI: no "Press ENTER" interruptions, cmdline
-- highlighted as you type, messages shown in a floating window.
-- See :help ui2. No-ops in headless mode (guarded inside enable()).
require('vim._core.ui2').enable()
