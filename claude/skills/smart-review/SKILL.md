---
name: smart-review
description: Smart Review — a curated code review as a GitHub-style HTML page in the browser. Use when the user says "/smart-review", "smart review", or wants to see only the interesting parts of the current change with explanations alongside. Reviews uncommitted changes to tracked files if there are any, otherwise all commits since the base branch, or a pull request given by number, URL or branch. Collapses mechanical hunks (imports, generated files, rename fallout, formatting), orders files for understanding with tests last, and places review notes next to the code they explain.
---

# Smart Review

Curate the current change into one self-contained HTML page that looks like a GitHub pull request
diff: files in reading order, mechanical hunks collapsed, review notes rendered as comment cards
directly under the lines they explain, generated files folded away at the bottom.

Helper script: `~/.claude/skills/smart-review/smart_review.py` (Python 3, no dependencies).

## Workflow

1. **Dump the scope.** Run:
   ```
   python3 ~/.claude/skills/smart-review/smart_review.py dump
   ```
   Scope is automatic: uncommitted changes to tracked files if there are any, otherwise the
   commits since the merge-base with the base branch: whichever of origin/HEAD, next, main, master
   and their `origin/` versions leaves the fewest commits, so a stale local `next` is not used.
   Untracked files are left out by default because the working tree usually holds scratch notes
   and local tooling.
   - `--committed`: review the branch's commits even when the tree is dirty. Use it when the user
     says "the branch", "the PR", "my commits" or similar.
   - `--untracked`: include untracked (non-ignored) files in an uncommitted review. Use it when
     the user asks for new files that are not yet `git add`ed.
   - `--pr <number|URL|branch>`: review a pull request. Fetches the PR head, checks it out in a
     detached worktree at `<session>/worktree`, diffs it against the merge-base with the PR's base
     branch and writes the PR's title, body and branch to `<session>/pr.json`. The current checkout
     is not touched. Read source files from the worktree, not from the current directory.
   - `--base <branch-or-rev>`: only if the user names a different base.

   The command prints the scope, a session directory and the path of `hunks.txt`. Check the scope
   line; if it is not what the user asked for, re-run with the right flag.

2. **For a PR, read the task.** Read `pr.json`. The dump prints the Shortcut story ID it found in
   the branch name or title (`story:`); load that story with the `view-story` skill. The page
   header links to the PR and the story. Use the story and the PR
   body to judge the diff: say in the plan `summary` whether the change does what the story asks,
   and add notes where the diff does something the story does not mention or misses something it
   asks for.

3. **Read `hunks.txt` in full.** It starts with an index (path, status, hunk count, +/- lines) and
   then lists every hunk with per-file 1-based numbers and new-side line ranges. For large diffs
   read it in chunks; never classify a file you have not read. Open surrounding source with Read
   when a hunk's meaning depends on context you cannot see.

4. **Classify every hunk** as shown or hidden, and every file as reviewed or skipped, using the
   rules below. Default to showing when unsure.

5. **Decide the reading order** (rules below) and write the plan JSON to the scratchpad.

6. **Render it:**
   ```
   python3 ~/.claude/skills/smart-review/smart_review.py render <session> <plan.json>
   ```
   This writes `<session>/review.html` and opens it in the default browser. Add `--no-open` to
   write without opening. The script refuses plans that reference unknown paths or hunk numbers.
   Files in the diff but missing from the plan are shown in full at the end under "Unclassified",
   so forgetting a file is visible, not silent.

7. **Reply briefly**: the scope, the reading order as a numbered list with one line per file, what
   was hidden or skipped and why in one or two lines, and anything that worried you while reading.
   The notes on the page already have the detail; do not repeat them hunk by hunk. If the user
   disagrees with a hiding decision, re-run `render` with an adjusted plan on the same session.
   For a PR, also give the worktree path, then stay available for follow-up questions about the
   PR. Never post comments or reviews to GitHub unless the user asks.

## What to hide

Hide a hunk when reading it would not change a reviewer's opinion of the change. Hidden hunks are
still on the page, collapsed behind a one-line toggle, so hiding is cheap to undo.

- `use`/`import`/`mod`/`pub use` changes, re-exports, module declarations.
- Formatting, whitespace, reordering, trailing commas, comment-only touch-ups.
- Rename fallout: once the definition rename is shown, hide the call sites that only swap the
  identifier. Say so in `hidden_reason`.
- Version bumps, lockfiles, dependency additions (mention them in the file `note` instead).
- Mechanical plumbing that mirrors a shown change one-to-one, such as adding a field to a constructor
  call after the struct change is shown, or a trait impl that only forwards.

Skip a whole file (put it in `skip` with a reason) when all of it is mechanical. Skipped files are
listed in a folded "Skipped files" section at the bottom with their raw diff available on expand:

- Generated output: `openapi/*.json`, Orval-generated clients and models, `schema.rs`, `.snap`
  snapshots, lockfiles, locize/translation JSON, `*.generated.*`.
- Pure renames or moves with no content change.
- Large fixtures and test data with nothing to judge.

Never hide: logic and control flow, SQL and Diesel queries, migrations, permission and auth checks,
error handling, concurrency, API shape or serialisation changes, new public types, config and
feature flags, and tests that assert behaviour. Snapshot changes are skipped as files, but the
*reason* they changed should be visible in a shown hunk; if it is not, show the snapshot.

## Reading order

Order for understanding, not for git's alphabetical listing:

1. Start with the *why*: the migration, the schema or type change, the new enum variant, the
   config flag. The reader should know what the change is about after the first file.
2. Then the core logic that uses it, following the data flow outward: domain crate, then service,
   then endpoint or handler, then frontend consumer.
3. Risky or surprising things early, not buried: anything touching auth, deletion, money, tenancy,
   or concurrency.
4. Tests always last, in their own "Tests" section. The one exception: a test that is the clearest
   statement of the intended behaviour may go first, with a note saying why.
5. Group with `section` headings when there are more than four or five files. Section titles are
   short and say what the group does ("Schema", "Backend logic", "Endpoint", "Frontend", "Tests").

## Notes

Three kinds of note, all optional, all plain text with `backticks` for code:

- `summary` (plan level): two or three sentences on what the change does and the one thing to
  scrutinise. Shown under the title.
- `note` (file level): what the file contributes, one line. Shown in the file header and the
  sidebar.
- `hunk_notes` and `line_notes`: things a reader might miss — a changed default, a swallowed error,
  a subtle ordering dependency, a question you have. Not a paraphrase of the diff. A hunk note is
  rendered as a comment card under the hunk's first changed line; a line note under the given
  new-side line number. Prefer `line_notes` when the point is about one specific line. One or two
  sentences each.

Write every note as a plain statement: the fact, then stop. No build-up, no "interestingly" or
"worth noting", no restating the diff in prose.

## Plan format

```json
{
  "title": "Short title of the change",
  "summary": "Two or three sentences on what the change does and the one thing to scrutinise.",
  "order": [
    {"section": "1. Schema"},
    {
      "path": "backend/src/model.rs",
      "show": [2, 3],
      "note": "Why this file matters, one line.",
      "hunk_notes": {"2": "Default changed from 7 to 0 days"},
      "line_notes": {"148": "Question: is `None` reachable here?"},
      "hidden_reason": "imports, derive list"
    },
    {"path": "frontend/src/features/x/Thing.tsx", "show": "all"},
    {"section": "3. Tests"},
    {"path": "backend/tests/model.rs"}
  ],
  "skip": [
    {"path": "openapi/schema.json", "reason": "generated"}
  ]
}
```

- `show` is a list of per-file hunk numbers or `"all"`. Omitting it means `"all"`. An empty list
  hides the file entirely (same as `skip`, but keep `skip` for the reason).
- `note`, `hunk_notes`, `line_notes`, `hidden_reason` are optional.
- Hunk numbers come from `hunks.txt` for this session and are per file. Line numbers in
  `line_notes` are new-side line numbers and must fall inside a hunk of that file: line numbers in
  the changed file (count from the hunk's `new lines` start), not line numbers in `hunks.txt`.

## The page

The header lists the commits under review, oldest first, and for a PR links to the PR, each
commit on GitHub and the Shortcut story. Sidebar with the reading order and skipped files. One file is always selected (blue ring, highlighted
in the sidebar); `j`/`k` move the selection and scroll to it, clicking a file or sidebar entry selects
it. Scrolling by itself never changes the selection. `v` marks the selected file as viewed, which collapses it to its header
(like GitHub; also a checkbox in the header, remembered per page in the browser). `h` toggles all
hidden hunks, `n` hides or shows all notes. File paths and new-side line numbers link to VS Code via `vscode://file`. Syntax
highlighting comes from highlight.js on cdnjs and degrades to plain text offline. Light and dark
follow the browser's colour scheme.

## Session files

Everything lives in `~/Documents/smart-review/<timestamp>/`: `diff.patch`, `hunks.txt`, `state.json`,
`plan.json` (the last plan rendered) and `review.html`, plus `pr.json` and `worktree/` for a PR.
Sessions older than seven days are deleted on the next dump, worktree included. The folder is not
under `~/.cache` because snap Firefox cannot read hidden directories.
