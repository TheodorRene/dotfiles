---
name: review-pr
description: Start a review of someone's pull request in its own herdr tab. Opens a new tab, starts a Claude session there and has it run /smart-review on the PR, then returns straight away. Use when the user says "review this PR", "review #4560", "review <GitHub PR link>", "review sc-12345" or similar. Do not use for reviewing the user's own uncommitted changes or current branch; that is /smart-review in this session.
---

# Review PR

This session only launches the review. The new session in the new tab does the review and answers
follow-up questions about it.

## Steps

1. **Check herdr.** `test "${HERDR_ENV:-}" = 1`. If it fails, say this session is not running in
   herdr and stop.

2. **Resolve the PR** from whatever the user gave (link, `#123`, `123`, branch name):
   ```bash
   gh pr view <ref> --json number,title,url,author,isDraft
   ```
   For a Shortcut reference (`sc-12345`), find the PR with
   `gh pr list --state open --search "sc-12345" --json number,title,url,author`. If that finds
   none or several, ask which one.

3. **Check for an existing review.** `herdr agent list`. If an agent named `pr-<number>` is live,
   focus it (`herdr agent focus pr-<number>`), tell the user and stop.

4. **Open a tab and start Claude in it.** Keep the user's focus where it is.
   ```bash
   herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$PWD" --label "#<number> <author login>" --no-focus
   herdr agent start pr-<number> --kind claude --pane <.result.root_pane.pane_id> --timeout 60000
   ```
   Do not split the current pane.

5. **Send the review prompt** and wait only until the agent starts working, not until it finishes:
   ```bash
   herdr agent prompt pr-<number> "/smart-review --pr <url>" --wait --until working --until blocked --timeout 15000
   ```
   If it reports `blocked`, the new session is waiting on a permission prompt; tell the user to
   answer it in the tab.

6. **Reply in one or two lines**: the PR (number, title, author) and the tab label. Do not poll the
   agent or wait for the review; the new session opens the page in the browser when it is done.
