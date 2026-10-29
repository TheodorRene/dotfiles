---
name: close-session
description: Archive this Claude session as a note in the Obsidian vault and close its own herdr tab. Use when the user says "close this session", "archive and close", "we're done here, close it", "wrap up and close", or similar. Only for ending the current session; to start one, use spin-off.
---

# Close session

Writes a short note about this session to the vault, then closes the herdr tab it runs in. Closing
the tab ends this Claude process, so it is the very last step: nothing printed after it is seen.

## Steps

1. **Check for unfinished work** in the session's folder and anything the session created:
   uncommitted changes (`git status --short`), a worktree it added, a server or background command
   it started. If there is any, list it and ask whether to close anyway. Don't clean anything up
   without asking.

2. **Find the session id.** In herdr:
   ```bash
   herdr agent list | jq -r --arg p "$HERDR_PANE_ID" '.result.agents[] | select(.pane_id == $p) | .agent_session.value'
   ```
   Also note the tab label (`herdr tab get "$HERDR_TAB_ID"`) and the folder (`$PWD`).

3. **Write the note** to `~/Documents/inner-sanctum/claude-sessions/<YYYY-MM-DD>-<short-name>.md`
   (create the folder if needed; add `-2` and so on if the name exists). Match the vault style:
   ```markdown
   ---
   id: <YYYY-MM-DD>-<short-name>
   aliases: []
   tags: [claude-session]
   ---

   # <Tab label or topic>

   - Date: <YYYY-MM-DD>, folder: `<folder>`
   - Resume: `cd <folder> && claude --resume <session-id>` (transcripts are deleted after 30 days
     unless `cleanupPeriodDays` is raised)

   ## Outcome
   <two to four plain sentences: what was asked, what was found or done, decisions made>

   ## Follow-ups
   - [ ] <open items, if any>
   ```
   Write it for the user reading it weeks later: facts and results, no tool names or agent jargon.
   Leave out secrets and tokens.

4. **Say goodbye in one line**, with the note's path, before closing; the user can't see anything
   after the next step.

5. **Close the tab:**
   ```bash
   herdr tab close "$HERDR_TAB_ID"
   ```
   If `HERDR_ENV` is not `1`, the session isn't running in herdr: skip this step and tell the user
   to close the terminal themselves.
