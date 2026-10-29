---
name: spin-off
description: Start a separate Claude session in its own herdr tab for a task that shouldn't block this one, and return straight away. Use when the user says "spin off a session for …", "start a new session in ~/dotfiles to look at …", "open a tab and investigate …", "have another agent check …", or reports a side problem (a crash, a broken tool) they want looked at elsewhere. Not for PR reviews; that is review-pr.
---

# Spin off

This session only launches the new one. The new session does the work and answers follow-up
questions in its own tab.

## Steps

1. **Check herdr.** `test "${HERDR_ENV:-}" = 1`. If it fails, say this session is not running in
   herdr and stop.

2. **Work out three things** from the user's message, and ask only if one is missing:
   - **Folder** for the new session (e.g. `~/dotfiles`). Default to `$PWD` when the task is about
     this repo.
   - **Name**: two or three words for the tab label ("waybar crash"). The agent name is the same in
     kebab case (`waybar-crash`).
   - **Task**: what the new session should find out or do.

3. **Check for an existing session.** `herdr agent list`. If an agent with that name is live, focus
   it (`herdr agent focus <name>`), tell the user and stop.

4. **Open a tab and start Claude in it.** Keep the user's focus where it is; do not split the
   current pane.
   ```bash
   herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd <folder> --label "<Name>" --no-focus
   herdr agent start <name> --kind claude --pane <.result.root_pane.pane_id> --timeout 60000
   ```

5. **Write the brief.** The new session knows nothing about this conversation, so the prompt has to
   stand on its own:
   - The task, with what is already known: times, error messages, what was tried, file paths.
   - What to report back, e.g. the cause and a proposed fix.
   - Ground rules that fit the task: explain before changing anything, ask before restarting
     services or running anything destructive, don't commit or push unless asked. In
     `~/dotfiles`, add that the repo is public.

   Keep it to a few sentences. Don't pass on conclusions as facts; say what is a guess.

6. **Send it** and wait only until the agent starts working, not until it finishes:
   ```bash
   herdr agent prompt <name> "<brief>" --wait --until working --until blocked --timeout 15000
   ```
   If it reports `blocked`, the new session is waiting on a permission prompt; tell the user to
   answer it in the tab.

7. **Reply in one or two lines**: the tab label and what the session is doing. Do not poll the agent
   or wait for its result.
