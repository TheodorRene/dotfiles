#!/usr/bin/env python3
"""Smart Review: build a curated, GitHub-style HTML diff review from a git diff.

Subcommands:
  dump [--base BRANCH] [--committed | --untracked | --pr REF]
                              Detect the review scope, write the diff and a numbered
                              hunk listing to a session directory, print the paths.
                              --pr checks the PR out in <session>/worktree.
  render SESSION PLAN.json    Render review.html in the session directory per the plan
                              and open it in the default browser. --no-open skips the
                              browser; --out PATH writes the page elsewhere.
"""

from __future__ import annotations

import argparse
import difflib
import html
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import webbrowser
from dataclasses import dataclass, field
from pathlib import Path

# Not under a hidden directory: snap Firefox cannot read ~/.cache.
CACHE = Path.home() / "Documents" / "smart-review"
HUNK_RE = re.compile(rb"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@")
BASE_CANDIDATES = ["next", "main", "master"]
STORY_RE = re.compile(r"\bsc-(\d+)\b", re.IGNORECASE)
# Story links need the Shortcut workspace slug, which stays out of this public repo. Set it per
# repo with `git config shortcut.workspace <slug>` (worktrees share it), or in
# $SHORTCUT_WORKSPACE. Without it the page names the story but doesn't link it.
SHORTCUT_STORY_URL = "https://app.shortcut.com/{workspace}/story/{story_id}"
SKIPPED_FILE_LINE_CAP = 400  # lines of diff embedded per skipped file before truncating


def run(args, cwd=None, env=None, check=True, input=None) -> bytes:
    result = subprocess.run(args, cwd=cwd, env=env, input=input, capture_output=True)
    if check and result.returncode != 0:
        sys.exit(f"command failed: {' '.join(map(str, args))}\n{result.stderr.decode(errors='replace')}")
    return result.stdout


def git(root, *args, env=None, check=True) -> bytes:
    config = ["-c", "core.quotePath=false", "-c", "diff.mnemonicPrefix=false", "-c", "diff.noprefix=false"]
    return run(["git", *config, *args], cwd=root, env=env, check=check)


def shortcut_story_url(root: Path, story_id: int) -> str | None:
    workspace = os.environ.get("SHORTCUT_WORKSPACE") or git(
        root, "config", "--get", "shortcut.workspace", check=False).decode().strip()
    return SHORTCUT_STORY_URL.format(workspace=workspace, story_id=story_id) if workspace else None


# --------------------------------------------------------------------------- parsing


@dataclass
class Hunk:
    number: int
    old_start: int
    old_count: int
    new_start: int
    new_count: int
    lines: list[bytes] = field(default_factory=list)  # includes the @@ header line

    @property
    def header(self) -> str:
        return self.lines[0].decode(errors="replace")

    def content(self):
        """Yield (kind, text) for each content line; kind is ' ', '+' or '-'."""
        for line in self.lines[1:]:
            if line.startswith(b"\\"):
                continue
            kind = line[:1].decode() if line else " "
            yield kind, line[1:].decode(errors="replace")

    def first_changed_line(self, side: str = "new") -> int:
        old, new = self.old_start, self.new_start
        for kind, _ in self.content():
            if kind != " ":
                return new if side == "new" else old
            old += 1
            new += 1
        return self.new_start if side == "new" else self.old_start

    def counts(self) -> tuple[int, int]:
        added = sum(1 for kind, _ in self.content() if kind == "+")
        removed = sum(1 for kind, _ in self.content() if kind == "-")
        return added, removed


@dataclass
class FileDiff:
    header: list[bytes] = field(default_factory=list)
    old_path: str | None = None
    new_path: str | None = None
    binary: bool = False
    hunks: list[Hunk] = field(default_factory=list)

    @property
    def path(self) -> str:
        return self.new_path or self.old_path or "?"

    @property
    def status(self) -> str:
        if self.old_path is None:
            return "added"
        if self.new_path is None:
            return "deleted"
        if self.old_path != self.new_path:
            return "renamed"
        return "modified"

    def counts(self) -> tuple[int, int]:
        added = sum(h.counts()[0] for h in self.hunks)
        removed = sum(h.counts()[1] for h in self.hunks)
        return added, removed


def _path_from_marker(line: bytes) -> str | None:
    rest = line[4:]
    if rest.endswith(b"\t"):
        rest = rest.rstrip(b"\t")
    if rest == b"/dev/null":
        return None
    for prefix in (b"a/", b"b/"):
        if rest.startswith(prefix):
            return rest[2:].decode(errors="surrogateescape")
    return rest.decode(errors="surrogateescape")


def _paths_from_diff_line(line: bytes) -> tuple[str, str] | None:
    rest = line[len(b"diff --git ") :]
    start = 0
    while True:
        idx = rest.find(b" b/", start)
        if idx < 0:
            return None
        left, right = rest[:idx], rest[idx + 1 :]
        if left.startswith(b"a/") and left[2:] == right[2:]:
            return left[2:].decode(errors="surrogateescape"), right[2:].decode(errors="surrogateescape")
        start = idx + 1


def parse_patch(data: bytes) -> list[FileDiff]:
    files: list[FileDiff] = []
    current: FileDiff | None = None
    lines = data.split(b"\n")
    if lines and lines[-1] == b"":
        lines.pop()
    for line in lines:
        if line.startswith(b"diff --git "):
            current = FileDiff(header=[line])
            files.append(current)
            paths = _paths_from_diff_line(line)
            if paths:
                current.old_path, current.new_path = paths
            continue
        if current is None:
            continue
        if not current.hunks and not line.startswith(b"@@"):
            current.header.append(line)
            if line.startswith(b"--- "):
                current.old_path = _path_from_marker(line)
            elif line.startswith(b"+++ "):
                current.new_path = _path_from_marker(line)
            elif line.startswith(b"rename from "):
                current.old_path = line[len(b"rename from ") :].decode(errors="surrogateescape")
            elif line.startswith(b"rename to "):
                current.new_path = line[len(b"rename to ") :].decode(errors="surrogateescape")
            elif line.startswith(b"new file mode"):
                current.old_path = None
            elif line.startswith(b"deleted file mode"):
                current.new_path = None
            elif line.startswith(b"Binary files"):
                current.binary = True
            continue
        match = HUNK_RE.match(line)
        if match:
            old_start, old_count, new_start, new_count = (
                int(match.group(1)),
                int(match.group(2)) if match.group(2) is not None else 1,
                int(match.group(3)),
                int(match.group(4)) if match.group(4) is not None else 1,
            )
            current.hunks.append(Hunk(len(current.hunks) + 1, old_start, old_count, new_start, new_count, [line]))
        else:
            current.hunks[-1].lines.append(line)
    return files


# --------------------------------------------------------------------------- scope


def repo_root() -> Path:
    return Path(run(["git", "rev-parse", "--show-toplevel"]).decode().strip())


def rev_exists(root, rev) -> bool:
    return subprocess.run(["git", "rev-parse", "--verify", "-q", rev], cwd=root, capture_output=True).returncode == 0


def detect_base(root, override: str | None) -> str:
    if override:
        if not rev_exists(root, override):
            sys.exit(f"base {override!r} does not exist")
        return override
    candidates = []
    origin_head = subprocess.run(
        ["git", "symbolic-ref", "-q", "--short", "refs/remotes/origin/HEAD"], cwd=root, capture_output=True
    )
    if origin_head.returncode == 0:
        name = origin_head.stdout.decode().strip()
        candidates += [name.removeprefix("origin/"), name]
    candidates += BASE_CANDIDATES + [f"origin/{c}" for c in BASE_CANDIDATES]
    existing = [c for c in candidates if rev_exists(root, c)]
    if not existing:
        sys.exit("could not detect a base branch; pass --base")

    # A stale local `next` would pull already-merged commits into the review.
    def commits_ahead(candidate: str) -> int:
        return int(git(root, "rev-list", "--count", f"{candidate}..HEAD").decode().strip())

    return min(existing, key=commits_ahead)


def uncommitted_patch(root, include_untracked: bool) -> bytes:
    """Working tree vs HEAD. Untracked (non-ignored) files are added via a throwaway index."""
    if not include_untracked:
        return git(root, "diff", "--no-color", "--no-ext-diff", "-M", "HEAD")
    real_index = Path(git(root, "rev-parse", "--git-path", "index").decode().strip())
    if not real_index.is_absolute():
        real_index = root / real_index
    with tempfile.TemporaryDirectory() as tmp:
        index = Path(tmp) / "index"
        shutil.copy(real_index, index)
        env = dict(os.environ, GIT_INDEX_FILE=str(index))
        untracked = git(root, "ls-files", "--others", "--exclude-standard", "-z", env=env)
        if untracked.strip(b"\0"):
            run(["git", "add", "--intent-to-add", "--pathspec-from-file=-", "--pathspec-file-nul"], cwd=root, env=env, input=untracked)
        return git(root, "diff", "--no-color", "--no-ext-diff", "-M", "HEAD", env=env)


def commit_list(root, rev_range: str) -> list[list[str]]:
    """[full sha, subject] per commit, oldest first."""
    log = git(root, "log", "--reverse", "--format=%H%x09%s", rev_range).decode(errors="replace")
    return [line.split("\t", 1) for line in log.splitlines() if line]


def new_session() -> Path:
    cleanup_old_sessions()
    session = CACHE / time.strftime("%Y%m%d-%H%M%S")
    session.mkdir(parents=True)
    return session


def write_session(session: Path, patch: bytes, files: list[FileDiff], state: dict):
    (session / "diff.patch").write_bytes(patch)
    (session / "state.json").write_text(json.dumps({**state, "session": str(session)}, indent=2))
    listing = session / "hunks.txt"
    listing.write_text(render_listing(files, state["scope"]), errors="surrogateescape")
    total_hunks = sum(len(f.hunks) for f in files)
    print(f"session: {session}")
    print(f"scope: {state['scope']}")
    print(f"files: {len(files)}, hunks: {total_hunks}")
    print(f"hunk listing: {listing}")


def cmd_dump_pr(args):
    """Check the PR head out in a detached worktree inside the session and diff it against its base."""
    root = repo_root()
    fields = "number,title,url,body,author,baseRefName,headRefName,headRefOid,isDraft"
    pr = json.loads(run(["gh", "pr", "view", args.pr, "--json", fields], cwd=root))
    number, base_branch = pr["number"], pr["baseRefName"]
    pr_ref = f"refs/remotes/origin/pr/{number}"
    git(root, "fetch", "-q", "origin", f"+refs/pull/{number}/head:{pr_ref}",
        f"+refs/heads/{base_branch}:refs/remotes/origin/{base_branch}")
    base = args.base or f"origin/{base_branch}"
    if not rev_exists(root, base):
        sys.exit(f"base {base!r} does not exist")

    merge_base = git(root, "merge-base", pr_ref, base).decode().strip()
    count = git(root, "rev-list", "--count", f"{merge_base}..{pr_ref}").decode().strip()
    patch = git(root, "diff", "--no-color", "--no-ext-diff", "-M", f"{merge_base}..{pr_ref}")
    files = parse_patch(patch)
    if not files:
        sys.exit(f"nothing to review: PR #{number} has no changes against {base}")

    story = STORY_RE.search(pr["headRefName"]) or STORY_RE.search(pr["title"])
    story_id = int(story.group(1)) if story else None

    session = new_session()
    worktree = session / "worktree"
    git(root, "worktree", "add", "-q", "--detach", str(worktree), pr_ref)
    (session / "pr.json").write_text(json.dumps(pr, indent=2))
    scope = f"PR #{number}: {count} commit(s) on {pr['headRefName']} since merge-base with {base} ({merge_base[:10]})"
    write_session(session, patch, files,
                  {"root": str(worktree), "mode": "committed", "base_rev": merge_base, "scope": scope,
                   "pr_url": pr["url"], "pr_number": number, "story_id": story_id,
                   "commits": commit_list(root, f"{merge_base}..{pr_ref}")})
    print(f"pr: #{number} {pr['title']} ({pr['url']}) by {pr['author']['login']}")
    print(f"branch: {pr['headRefName']}")
    print(f"story: {f'sc-{story_id}' if story_id else 'none found in branch or title'}")
    print(f"worktree: {worktree}")
    print(f"pr details: {session / 'pr.json'}")


def cmd_dump(args):
    if args.pr:
        return cmd_dump_pr(args)
    root = repo_root()
    patch = b"" if args.committed else uncommitted_patch(root, args.untracked)
    commits = []
    if patch.strip():
        untracked = " (including untracked files)" if args.untracked else ""
        mode, base_rev, scope = "uncommitted", "HEAD", f"uncommitted changes vs HEAD{untracked}"
    else:
        base = detect_base(root, args.base)
        merge_base = git(root, "merge-base", "HEAD", base).decode().strip()
        head = git(root, "rev-parse", "HEAD").decode().strip()
        if merge_base == head:
            sys.exit(f"nothing to review: no uncommitted changes and HEAD is not ahead of {base}")
        count = git(root, "rev-list", "--count", f"{merge_base}..HEAD").decode().strip()
        branch = git(root, "rev-parse", "--abbrev-ref", "HEAD").decode().strip()
        patch = git(root, "diff", "--no-color", "--no-ext-diff", "-M", f"{merge_base}..HEAD")
        mode, base_rev = "committed", merge_base
        commits = commit_list(root, f"{merge_base}..HEAD")
        scope = f"{count} commit(s) on {branch} since merge-base with {base} ({merge_base[:10]})"

    files = parse_patch(patch)
    if not files:
        sys.exit("nothing to review: the diff is empty")

    write_session(new_session(), patch, files,
                  {"root": str(root), "mode": mode, "base_rev": base_rev, "scope": scope, "commits": commits})


def render_listing(files: list[FileDiff], scope: str) -> str:
    out = [
        "# Smart Review hunk listing",
        f"# scope: {scope}",
        "# Refer to hunks as <path> hunk <n>. Hunk numbers are per file, 1-based.",
        "",
        "## Index",
    ]
    for f in files:
        added, removed = f.counts()
        extra = " binary" if f.binary else ""
        rename = f" (from {f.old_path})" if f.status == "renamed" else ""
        out.append(f"- {f.path}{rename}: {f.status}{extra}, {len(f.hunks)} hunk(s), +{added}/-{removed}")
    out.append("")
    for f in files:
        rename = f", renamed from {f.old_path}" if f.status == "renamed" else ""
        out.append(f"===== {f.path} ({f.status}{rename}, {len(f.hunks)} hunk(s)) =====")
        if f.binary:
            out.append("(binary)")
        for h in f.hunks:
            added, removed = h.counts()
            end = h.new_start + max(h.new_count, 1) - 1
            out.append(f"--- hunk {h.number} (new lines {h.new_start}-{end}, +{added}/-{removed}) ---")
            out.extend(line.decode(errors="replace") for line in h.lines)
        out.append("")
    return "\n".join(out) + "\n"


def cleanup_old_sessions(max_age_days=7):
    if not CACHE.exists():
        return
    cutoff = time.time() - max_age_days * 86400
    for entry in CACHE.iterdir():
        if entry.is_dir() and entry.stat().st_mtime < cutoff:
            worktree = entry / "worktree"
            if worktree.exists():
                subprocess.run(["git", "worktree", "remove", "--force", str(worktree)], cwd=worktree, capture_output=True)
            shutil.rmtree(entry, ignore_errors=True)


# --------------------------------------------------------------------------- plan


@dataclass
class Card:
    index: int
    file: FileDiff
    shown: list[Hunk]
    hidden: list[Hunk]
    note: str
    hunk_notes: dict[str, str]
    line_notes: dict[str, str]
    hidden_reason: str
    section: str = ""


@dataclass
class Review:
    plan: dict
    state: dict
    files: dict[str, FileDiff]
    items: list  # section headings (dict) and Cards, in reading order
    skipped: list[dict]
    unclassified: list[str]

    @property
    def cards(self) -> list[Card]:
        return [item for item in self.items if isinstance(item, Card)]


def build_review(plan: dict, state: dict, files: dict[str, FileDiff]) -> Review:
    planned: set[str] = set()
    items: list = []

    def make_card(entry: dict) -> Card | None:
        path = entry["path"]
        file = files.get(path)
        if file is None:
            sys.exit(f"plan references {path!r}, which is not in the diff")
        planned.add(path)
        show = entry.get("show", "all")
        if show == "all":
            shown = list(file.hunks)
        else:
            unknown = [n for n in show if not 1 <= n <= len(file.hunks)]
            if unknown:
                sys.exit(f"{path}: hunk(s) {unknown} do not exist (file has {len(file.hunks)})")
            shown = [h for h in file.hunks if h.number in show]
        hidden = [h for h in file.hunks if h not in shown]
        if not shown and not file.binary:
            return None
        for key in entry.get("hunk_notes", {}):
            if not str(key).isdigit() or not 1 <= int(key) <= len(file.hunks):
                sys.exit(f"{path}: hunk note for hunk {key}, which does not exist")
        return Card(
            0, file, shown, hidden, entry.get("note", ""),
            {str(k): v for k, v in entry.get("hunk_notes", {}).items()},
            {str(k): v for k, v in entry.get("line_notes", {}).items()},
            entry.get("hidden_reason", ""),
        )

    for entry in plan.get("order", []):
        if "section" in entry:
            items.append(entry)
            continue
        card = make_card(entry)
        if card is not None:
            items.append(card)

    skipped = plan.get("skip", [])
    for entry in skipped:
        if entry["path"] not in files:
            sys.exit(f"plan skips {entry['path']!r}, which is not in the diff")
        planned.add(entry["path"])

    unclassified = [path for path in files if path not in planned]
    if unclassified:
        items.append({"section": "Unclassified (not in the plan, shown in full)"})
        for path in unclassified:
            card = make_card({"path": path})
            if card is not None:
                items.append(card)

    section = ""
    index = 0
    for item in items:
        if isinstance(item, dict):
            section = item["section"]
        else:
            index += 1
            item.index = index
            item.section = section
    return Review(plan, state, files, items, skipped, unclassified)


# --------------------------------------------------------------------------- intra-line diff

TOKEN_RE = re.compile(r"\w+|\s+|[^\w\s]")


def _tokens(text: str) -> list[tuple[int, int]]:
    return [(m.start(), m.end()) for m in TOKEN_RE.finditer(text)]


def word_ranges(old: str, new: str) -> tuple[list[tuple[int, int]], list[tuple[int, int]]]:
    """Character ranges that differ between two lines, at word granularity. Empty when the
    lines are too different for highlighting to help."""
    old_tokens, new_tokens = _tokens(old), _tokens(new)
    matcher = difflib.SequenceMatcher(None, [old[a:b] for a, b in old_tokens], [new[a:b] for a, b in new_tokens], autojunk=False)
    if matcher.ratio() < 0.5:
        return [], []
    old_ranges, new_ranges = [], []
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == "equal":
            continue
        if i2 > i1:
            old_ranges.append((old_tokens[i1][0], old_tokens[i2 - 1][1]))
        if j2 > j1:
            new_ranges.append((new_tokens[j1][0], new_tokens[j2 - 1][1]))
    return old_ranges, new_ranges


def hunk_rows(hunk: Hunk) -> list[dict]:
    """Flatten a hunk into rows with line numbers and word-diff ranges."""
    rows = []
    old, new = hunk.old_start, hunk.new_start
    for kind, text in hunk.content():
        row = {"kind": kind, "text": text, "old": None, "new": None, "ranges": []}
        if kind in " -":
            row["old"] = old
            old += 1
        if kind in " +":
            row["new"] = new
            new += 1
        rows.append(row)
    # Pair runs of removed lines with the run of added lines that follows them.
    i = 0
    while i < len(rows):
        if rows[i]["kind"] != "-":
            i += 1
            continue
        j = i
        while j < len(rows) and rows[j]["kind"] == "-":
            j += 1
        k = j
        while k < len(rows) and rows[k]["kind"] == "+":
            k += 1
        for removed, added in zip(rows[i:j], rows[j:k]):
            removed["ranges"], added["ranges"] = word_ranges(removed["text"], added["text"])
        i = k
    return rows


# --------------------------------------------------------------------------- html

LANGUAGES = {
    "rs": "rust", "ts": "typescript", "tsx": "typescript", "js": "javascript", "jsx": "javascript", "mjs": "javascript",
    "py": "python", "sql": "sql", "toml": "ini", "yaml": "yaml", "yml": "yaml", "json": "json", "md": "markdown",
    "html": "xml", "xml": "xml", "css": "css", "scss": "scss", "less": "less", "sh": "bash", "bash": "bash",
    "fish": "bash", "cs": "csharp", "fs": "fsharp", "go": "go", "java": "java", "kt": "kotlin", "swift": "swift",
    "c": "c", "h": "c", "cpp": "cpp", "hpp": "cpp", "rb": "ruby", "php": "php", "lua": "lua", "diff": "diff",
    "dockerfile": "dockerfile", "justfile": "makefile", "makefile": "makefile", "cshtml": "xml", "razor": "xml",
    "ini": "ini", "cfg": "ini", "env": "bash", "svg": "xml", "vue": "xml", "graphql": "graphql", "proto": "protobuf",
}


def language(path: str) -> str:
    name = Path(path).name.lower()
    if name in LANGUAGES:
        return LANGUAGES[name]
    return LANGUAGES.get(Path(path).suffix.lstrip(".").lower(), "plaintext")


def esc(text: str) -> str:
    return html.escape(text, quote=True)


def note_html(text: str) -> str:
    """Escaped note text with `code` spans and line breaks."""
    parts = re.split(r"(`[^`]+`)", text)
    out = []
    for part in parts:
        if part.startswith("`") and part.endswith("`") and len(part) > 1:
            out.append(f"<code>{esc(part[1:-1])}</code>")
        else:
            out.append(esc(part).replace("\n", "<br>"))
    return "".join(out)


def vscode_link(root: Path, path: str, line: int | None = None) -> str:
    target = f"vscode://file{root / path}"
    return f"{target}:{line}" if line else target


def render_hunk(card_id: str, hunk: Hunk, file: FileDiff, root: Path, hidden: bool, hidden_reason: str,
                hunk_note: str | None, line_notes: dict[str, str], used_line_notes: set[str]) -> str:
    lang = language(file.path)
    side = "old" if file.status == "deleted" else "new"
    note_line = hunk.first_changed_line(side) if hunk_note else None
    rows = []
    hunk_id = f"{card_id}-h{hunk.number}"
    added, removed = hunk.counts()
    if hidden:
        reason = f": {note_html(hidden_reason)}" if hidden_reason else ""
        rows.append(
            f'<tbody class="hunk-head hidden-head"><tr><td colspan="3">'
            f'<button type="button" class="toggle" aria-expanded="false" aria-controls="{hunk_id}">'
            f'<span class="chev">▸</span> Hidden hunk {hunk.number}{reason} '
            f'<span class="muted">(+{added} −{removed}, {esc(hunk.header)})</span></button></td></tr></tbody>'
        )
        rows.append(f'<tbody id="{hunk_id}" class="hunk collapsed" hidden>')
    else:
        rows.append(f'<tbody class="hunk-head"><tr><td colspan="3"><span class="hdr">{esc(hunk.header)}</span></td></tr></tbody>')
        rows.append(f'<tbody id="{hunk_id}" class="hunk">')
    for row in hunk_rows(hunk):
        cls = {"+": "add", "-": "del", " ": "ctx"}[row["kind"]]
        old_cell = f'<td class="n">{row["old"]}</td>' if row["old"] else '<td class="n"></td>'
        if row["new"]:
            new_cell = f'<td class="n"><a href="{vscode_link(root, file.path, row["new"])}" title="Open in VS Code">{row["new"]}</a></td>'
        else:
            new_cell = '<td class="n"></td>'
        ranges = ",".join(f"{a}-{b}" for a, b in row["ranges"])
        data = f' data-chg="{ranges}"' if ranges else ""
        rows.append(
            f'<tr class="l {cls}">{old_cell}{new_cell}<td class="c"><code class="language-{lang}"{data}>{esc(row["text"])}</code></td></tr>'
        )
        anchor = row[side]
        if hunk_note and anchor == note_line:
            rows.append(note_row(f"hunk {hunk.number}", hunk_note))
        if row["new"] is not None and str(row["new"]) in line_notes:
            key = str(row["new"])
            used_line_notes.add(key)
            rows.append(note_row(f"line {key}", line_notes[key]))
    rows.append("</tbody>")
    return "\n".join(rows)


COLGROUP = '<colgroup><col class="col-n"><col class="col-n"><col></colgroup>'


def note_row(tag: str, text: str) -> str:
    return f'<tr class="note"><td colspan="3"><div class="note-card"><span class="note-tag">{esc(tag)}</span>{note_html(text)}</div></td></tr>'


def status_badge(file: FileDiff) -> str:
    label = file.status
    if file.status == "renamed":
        label = f"renamed from {file.old_path}"
    return f'<span class="badge {file.status}">{esc(label)}</span>'


def render_card(card: Card, root: Path) -> str:
    file = card.file
    card_id = f"f{card.index}"
    added, removed = file.counts()
    note = f'<div class="file-note">{note_html(card.note)}</div>' if card.note else ""
    hidden_info = ""
    if card.hidden:
        numbers = ", ".join(str(h.number) for h in card.hidden)
        reason = f" ({note_html(card.hidden_reason)})" if card.hidden_reason else ""
        hidden_info = f'<span class="muted">hidden: {numbers}{reason}</span>'
    link = "" if file.status == "deleted" else f' href="{vscode_link(root, file.path)}" title="Open in VS Code"'
    head = (
        f'<div class="file-head"><span class="idx">{card.index}</span>{status_badge(file)}'
        f'<a class="path"{link}>{esc(file.path)}</a>'
        f'<span class="counts"><span class="plus">+{added}</span> <span class="minus">−{removed}</span></span>{hidden_info}'
        f'<label class="viewed-box"><input type="checkbox" class="viewed-check"> Viewed</label></div>'
    )
    if file.binary:
        body = '<div class="empty">Binary file.</div>'
    else:
        used: set[str] = set()
        parts = []
        for hunk in file.hunks:
            parts.append(render_hunk(
                card_id, hunk, file, root, hunk in card.hidden, card.hidden_reason,
                card.hunk_notes.get(str(hunk.number)), card.line_notes, used,
            ))
        stray = {k: v for k, v in card.line_notes.items() if k not in used}
        for key in stray:
            print(f"warning: {file.path}: line note for line {key} is not inside any hunk; shown at the top", file=sys.stderr)
        stray_rows = "".join(note_row(f"line {k}", v) for k, v in stray.items())
        body = f'<table class="diff">{COLGROUP}{stray_rows}{"".join(parts)}</table>'
    return f'<section class="file" id="{card_id}">{head}{note}{body}</section>'


def render_skipped(entry: dict, file: FileDiff, root: Path, index: int) -> str:
    added, removed = file.counts()
    reason = note_html(entry.get("reason", ""))
    card_id = f"s{index}"
    if file.binary:
        body = '<div class="empty">Binary file.</div>'
    else:
        used: set[str] = set()
        parts, lines = [], 0
        for hunk in file.hunks:
            if lines >= SKIPPED_FILE_LINE_CAP:
                remaining = sum(len(h.lines) - 1 for h in file.hunks[hunk.number - 1 :])
                parts.append(f'<tbody><tr class="note"><td colspan="3"><div class="muted">… {remaining} more lines not embedded; see diff.patch in the session.</div></td></tr></tbody>')
                break
            parts.append(render_hunk(card_id, hunk, file, root, False, "", None, {}, used))
            lines += len(hunk.lines) - 1
        body = f'<table class="diff">{COLGROUP}{"".join(parts)}</table>'
    return (
        f'<details class="file skipped" id="{card_id}"><summary class="file-head">{status_badge(file)}'
        f'<span class="path">{esc(file.path)}</span>'
        f'<span class="counts"><span class="plus">+{added}</span> <span class="minus">−{removed}</span></span>'
        f'<span class="muted">{reason}</span></summary>{body}</details>'
    )


def render_toc(review: Review) -> str:
    out = ['<nav class="toc"><div class="toc-title">Reading order <span id="viewed-count"></span></div><ol>']
    for item in review.items:
        if isinstance(item, dict):
            out.append(f'<li class="section">{esc(item["section"])}</li>')
            continue
        name = Path(item.file.path).name
        parent = str(Path(item.file.path).parent)
        note = f'<span class="toc-note">{note_html(item.note)}</span>' if item.note else ""
        out.append(
            f'<li><a href="#f{item.index}"><span class="toc-idx">{item.index}</span>'
            f'<span class="toc-name">{esc(name)}</span><span class="toc-dir">{esc(parent)}</span>{note}</a></li>'
        )
    out.append("</ol>")
    if review.skipped:
        out.append('<div class="toc-title">Skipped</div><ul>')
        for i, entry in enumerate(review.skipped, 1):
            out.append(f'<li><a href="#s{i}"><span class="toc-idx"></span><span class="toc-name">{esc(Path(entry["path"]).name)}</span><span class="toc-dir">{esc(entry.get("reason", ""))}</span></a></li>')
        out.append("</ul>")
    out.append(
        '<div class="toc-title">Keyboard</div><table class="keys">'
        '<tr><td><kbd>j</kbd> <kbd>k</kbd></td><td>select next / previous file</td></tr>'
        '<tr><td><kbd>v</kbd></td><td>mark selected file viewed (collapses it)</td></tr>'
        '<tr><td><kbd>h</kbd></td><td>show / hide all hidden hunks</td></tr>'
        '<tr><td><kbd>n</kbd></td><td>show / hide all notes</td></tr>'
        '</table><div class="keys-hint">Click a file or a sidebar entry to select it.</div></nav>'
    )
    return "".join(out)


def render_page(review: Review) -> str:
    plan, state = review.plan, review.state
    root = Path(state["root"])
    cards = review.cards
    shown = sum(len(c.shown) for c in cards)
    total = sum(len(f.hunks) for f in review.files.values())
    title = plan.get("title", "Smart Review")
    summary = f'<p class="summary">{note_html(plan["summary"])}</p>' if plan.get("summary") else ""
    links = []
    if state.get("pr_url"):
        links.append(f'<a href="{esc(state["pr_url"])}">Pull request #{state["pr_number"]} on GitHub</a>')
    if state.get("story_id"):
        story_url = shortcut_story_url(root, state["story_id"])
        story = f'Story sc-{state["story_id"]} on Shortcut'
        links.append(f'<a href="{esc(story_url)}">{story}</a>' if story_url else story)
    pr_link = f'<p class="meta">{" · ".join(links)}</p>' if links else ""
    commits = ""
    if state.get("commits"):
        items = []
        for sha, subject in state["commits"]:
            short = f"<code>{sha[:10]}</code>"
            if state.get("pr_url"):
                short = f'<a href="{esc(state["pr_url"])}/commits/{sha}">{short}</a>'
            items.append(f"<li>{short} {esc(subject)}</li>")
        commits = f'<ol class="commits">{"".join(items)}</ol>'
    unclassified = ""
    if review.unclassified:
        listing = "".join(f"<li>{esc(path)}</li>" for path in review.unclassified)
        unclassified = (
            f'<details class="warn"><summary>{len(review.unclassified)} file(s) were not in the plan and are shown in full '
            f'at the end under "Unclassified".</summary><ul>{listing}</ul></details>'
        )

    body = []
    for item in review.items:
        if isinstance(item, dict):
            body.append(f'<h2 class="section-title">{esc(item["section"])}</h2>')
        else:
            body.append(render_card(item, root))
    if review.skipped:
        body.append('<h2 class="section-title">Skipped files</h2><p class="muted">Mechanical or generated; expand to see the raw diff.</p>')
        for i, entry in enumerate(review.skipped, 1):
            body.append(render_skipped(entry, review.files[entry["path"]], root, i))

    return PAGE_TEMPLATE.format(
        title=esc(title),
        summary=summary,
        pr_link=pr_link,
        commits=commits,
        scope=esc(state["scope"]),
        stats=f"Showing {shown} of {total} hunks across {len(cards)} of {len(review.files)} files",
        root=esc(str(root)),
        unclassified=unclassified,
        toc=render_toc(review),
        body="\n".join(body),
        css=CSS,
        js=JS,
    )


PAGE_TEMPLATE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css" media="(prefers-color-scheme: light)">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css" media="(prefers-color-scheme: dark)">
<script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
<style>{css}</style>
</head>
<body>
<div class="layout">
{toc}
<main>
<header>
<h1>{title}</h1>
{pr_link}
{commits}
{summary}
<p class="meta">{scope}. {stats}. Repository <code>{root}</code>.</p>
{unclassified}
</header>
{body}
</main>
</div>
<script>{js}</script>
</body>
</html>
"""

CSS = """
:root {
  --bg: #ffffff; --fg: #1f2328; --muted: #656d76; --border: #d0d7de; --head: #f6f8fa;
  --add-bg: #e6ffec; --add-num: #ccffd8; --add-mark: #abf2bc;
  --del-bg: #ffebe9; --del-num: #ffd7d5; --del-mark: #ff9b96;
  --hunk-bg: #ddf4ff; --hunk-fg: #0969da; --note-bg: #fff8c5; --note-border: #d4a72c;
  --link: #0969da; --badge-add: #1a7f37; --badge-del: #cf222e; --badge-mod: #9a6700; --badge-ren: #8250df;
  --warn-bg: #fff1e5; --warn-fg: #953800;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #0d1117; --fg: #e6edf3; --muted: #8b949e; --border: #30363d; --head: #161b22;
    --add-bg: #12261e; --add-num: #1b3a2a; --add-mark: #2e5a3c;
    --del-bg: #2d1518; --del-num: #45232a; --del-mark: #7a2e35;
    --hunk-bg: #121d2f; --hunk-fg: #79c0ff; --note-bg: #2a2410; --note-border: #9e6a03;
    --link: #58a6ff; --badge-add: #3fb950; --badge-del: #f85149; --badge-mod: #d29922; --badge-ren: #a371f7;
    --warn-bg: #2b1d12; --warn-fg: #f0883e;
  }
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--fg); font: 14px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif; }
a { color: var(--link); text-decoration: none; }
a:hover { text-decoration: underline; }
code { font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, "Liberation Mono", monospace; }
.layout { display: grid; grid-template-columns: 300px minmax(0, 1fr); gap: 0; min-height: 100vh; }
@media (max-width: 1000px) { .layout { grid-template-columns: 1fr; } .toc { position: static !important; height: auto !important; border-right: 0; border-bottom: 1px solid var(--border); } }
.toc { position: sticky; top: 0; height: 100vh; overflow-y: auto; padding: 16px; border-right: 1px solid var(--border); background: var(--head); font-size: 13px; }
.toc-title { font-weight: 600; margin: 8px 0 6px; color: var(--muted); text-transform: uppercase; font-size: 11px; letter-spacing: .04em; }
.toc ol, .toc ul { list-style: none; margin: 0; padding: 0; }
.toc li { margin: 2px 0; }
.toc li.section { margin: 12px 0 4px; font-weight: 600; }
.toc li a { display: grid; grid-template-columns: 22px 1fr; column-gap: 4px; padding: 3px 6px; border-radius: 6px; color: var(--fg); }
.toc li a:hover { background: var(--border); text-decoration: none; }
.toc li a.active { background: var(--link); color: var(--bg); text-decoration: none; }
.toc li a.active .toc-idx, .toc li a.active .toc-dir, .toc li a.active .toc-note { color: inherit; opacity: .85; }
.toc-idx { color: var(--muted); font-variant-numeric: tabular-nums; }
.toc-name { font-family: ui-monospace, monospace; font-size: 12px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.toc-dir { grid-column: 2; color: var(--muted); font-size: 11px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.toc-note { grid-column: 2; color: var(--muted); font-size: 12px; margin-top: 2px; }
body.notes-hidden tr.note, body.notes-hidden .file-note { display: none; }
.keys { margin-top: 4px; border-collapse: collapse; font-size: 13px; }
.keys td { padding: 4px 6px 4px 0; vertical-align: top; }
.keys td:first-child { white-space: nowrap; padding-right: 10px; }
kbd { display: inline-block; min-width: 22px; padding: 1px 6px; text-align: center; font: 600 12px/18px ui-monospace, monospace; color: var(--fg); background: var(--bg); border: 1px solid var(--border); border-bottom-width: 2px; border-radius: 5px; }
.keys-hint { margin: 8px 0 0; color: var(--muted); font-size: 12px; }
main { padding: 16px 24px 80px; min-width: 0; }
header { margin-bottom: 20px; }
h1 { font-size: 22px; margin: 0 0 8px; }
.summary { font-size: 15px; max-width: 80ch; margin: 0 0 8px; }
.meta { color: var(--muted); margin: 0; font-size: 13px; }
.meta code { font-size: 12px; }
.commits { margin: 8px 0 12px; padding-left: 22px; font-size: 13px; }
.commits li { margin: 2px 0; }
.commits code { font-size: 12px; color: var(--muted); margin-right: 6px; }
.warn { background: var(--warn-bg); color: var(--warn-fg); padding: 8px 12px; border-radius: 6px; margin-top: 8px; }
.warn summary { cursor: pointer; }
.warn ul { margin: 6px 0 0; padding-left: 20px; font-size: 12px; }
.section-title { font-size: 16px; margin: 28px 0 10px; padding-bottom: 4px; border-bottom: 1px solid var(--border); }
.file { border: 1px solid var(--border); border-radius: 6px; margin: 0 0 16px; overflow: hidden; scroll-margin-top: 8px; }
section.file.selected { border-color: var(--link); box-shadow: 0 0 0 2px var(--link); }
section.file.selected .file-head { border-bottom-color: var(--link); }
section.file.selected .file-head .idx { background: var(--link); color: var(--bg); border-radius: 10px; text-align: center; min-width: 1.6em; }
.viewed-box { margin-left: auto; font-size: 12px; color: var(--muted); cursor: pointer; user-select: none; display: inline-flex; align-items: center; gap: 4px; white-space: nowrap; }
section.file.viewed > :not(.file-head) { display: none; }
section.file.viewed .file-head { border-bottom: 0; opacity: .7; }
section.file.viewed .file-head .path { text-decoration: line-through; font-weight: 500; }
.toc li a.viewed .toc-name { text-decoration: line-through; }
.toc li a.viewed:not(.active) { opacity: .55; }
.toc li a.viewed .toc-idx::after { content: " ✓"; }
#viewed-count { font-weight: normal; text-transform: none; letter-spacing: 0; }
.file-head { display: flex; align-items: center; gap: 10px; padding: 8px 12px; background: var(--head); border-bottom: 1px solid var(--border); position: sticky; top: 0; z-index: 2; flex-wrap: wrap; }
.file-head .idx { color: var(--muted); font-variant-numeric: tabular-nums; min-width: 1.5em; }
.file-head .path { font-family: ui-monospace, monospace; font-size: 13px; font-weight: 600; color: var(--fg); }
.file-head .counts { font-family: ui-monospace, monospace; font-size: 12px; }
.plus { color: var(--badge-add); } .minus { color: var(--badge-del); }
.muted { color: var(--muted); font-weight: normal; }
.badge { font-size: 11px; padding: 1px 7px; border-radius: 10px; border: 1px solid currentColor; text-transform: lowercase; }
.badge.added { color: var(--badge-add); } .badge.deleted { color: var(--badge-del); }
.badge.modified { color: var(--badge-mod); } .badge.renamed { color: var(--badge-ren); }
.file-note { padding: 8px 12px; border-bottom: 1px solid var(--border); background: var(--note-bg); border-left: 4px solid var(--note-border); }
.empty { padding: 12px; color: var(--muted); }
table.diff { width: 100%; border-collapse: collapse; font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, "Liberation Mono", monospace; font-size: 12px; line-height: 20px; table-layout: fixed; }
table.diff td { padding: 0; vertical-align: top; }
col.col-n { width: 56px; }
td.n { text-align: right; padding: 0 8px 0 4px !important; color: var(--muted); user-select: none; white-space: nowrap; }
td.n a { color: inherit; }
td.c { white-space: pre-wrap; word-break: break-all; padding-left: 20px !important; position: relative; }
td.c::before { position: absolute; left: 6px; color: var(--muted); }
tr.add td.c::before { content: "+"; } tr.del td.c::before { content: "−"; }
tr.add { background: var(--add-bg); } tr.add td.n { background: var(--add-num); }
tr.del { background: var(--del-bg); } tr.del td.n { background: var(--del-num); }
tr.add mark { background: var(--add-mark); color: inherit; border-radius: 2px; }
tr.del mark { background: var(--del-mark); color: inherit; border-radius: 2px; }
td.c code { background: transparent !important; padding: 0 !important; font-size: inherit; }
td.c code.hljs { display: inline; white-space: pre-wrap; color: inherit; }
tbody.hunk-head td { background: var(--hunk-bg); color: var(--hunk-fg); padding: 2px 12px; font-size: 12px; }
tbody.hidden-head td { background: var(--head); color: var(--muted); }
button.toggle { all: unset; cursor: pointer; display: block; width: 100%; padding: 2px 0; font: inherit; }
button.toggle:hover { color: var(--fg); }
button.toggle .chev { display: inline-block; width: 1em; transition: transform .1s; }
button.toggle[aria-expanded="true"] .chev { transform: rotate(90deg); }
tbody.collapsed tr.l { opacity: .75; }
tr.note td { padding: 6px 12px 8px 60px; background: var(--bg); }
.note-card { background: var(--note-bg); border: 1px solid var(--note-border); border-left-width: 4px; border-radius: 6px; padding: 6px 10px; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif; font-size: 13px; line-height: 1.45; max-width: 90ch; white-space: normal; }
.note-tag { display: inline-block; font-size: 11px; color: var(--muted); margin-right: 8px; text-transform: uppercase; letter-spacing: .03em; }
.note-card code { background: var(--head); padding: 0 4px; border-radius: 3px; font-size: 12px; }
details.skipped summary { cursor: pointer; list-style: none; }
details.skipped summary::-webkit-details-marker { display: none; }
details.skipped summary::before { content: "▸"; color: var(--muted); }
details.skipped[open] summary::before { content: "▾"; }
details.skipped .path { font-weight: 500; }
"""

JS = """
(function () {
  function markRanges(code, ranges) {
    var walker = document.createTreeWalker(code, NodeFilter.SHOW_TEXT), nodes = [], node, pos = 0;
    while ((node = walker.nextNode())) nodes.push([node, pos]), pos += node.data.length;
    nodes.forEach(function (entry) {
      var t = entry[0], s = entry[1], e = s + t.data.length, parts = [], cur = 0;
      ranges.forEach(function (r) {
        var lo = Math.max(r[0], s) - s, hi = Math.min(r[1], e) - s;
        if (lo >= hi) return;
        if (lo > cur) parts.push(document.createTextNode(t.data.slice(cur, lo)));
        var m = document.createElement('mark'); m.textContent = t.data.slice(lo, hi); parts.push(m); cur = hi;
      });
      if (!parts.length) return;
      if (cur < t.data.length) parts.push(document.createTextNode(t.data.slice(cur)));
      t.replaceWith.apply(t, parts);
    });
  }
  function decorate(tbody) {
    if (tbody.dataset.done) return;
    tbody.dataset.done = '1';
    tbody.querySelectorAll('code').forEach(function (code) {
      if (window.hljs && code.textContent.trim()) { try { hljs.highlightElement(code); } catch (e) {} }
      var chg = code.dataset.chg;
      if (chg) markRanges(code, chg.split(',').map(function (p) { return p.split('-').map(Number); }));
    });
  }
  document.querySelectorAll('tbody.hunk:not([hidden])').forEach(decorate);
  document.querySelectorAll('details.skipped').forEach(function (d) {
    d.addEventListener('toggle', function () { if (d.open) d.querySelectorAll('tbody.hunk').forEach(decorate); });
  });
  function setOpen(btn, open) {
    var body = document.getElementById(btn.getAttribute('aria-controls'));
    btn.setAttribute('aria-expanded', open ? 'true' : 'false');
    body.hidden = !open;
    if (open) decorate(body);
  }
  document.querySelectorAll('button.toggle').forEach(function (btn) {
    btn.addEventListener('click', function () { setOpen(btn, btn.getAttribute('aria-expanded') !== 'true'); });
  });
  var files = Array.prototype.slice.call(document.querySelectorAll('section.file'));
  var links = Array.prototype.slice.call(document.querySelectorAll('.toc a[href^="#f"]'));
  var selected = -1;
  var storageKey = 'smart-review:viewed:' + location.pathname;
  function loadViewed() { try { return JSON.parse(localStorage.getItem(storageKey) || '[]'); } catch (e) { return []; } }
  function saveViewed() {
    var ids = files.filter(function (f) { return f.classList.contains('viewed'); }).map(function (f) { return f.id; });
    try { localStorage.setItem(storageKey, JSON.stringify(ids)); } catch (e) {}
    var count = document.getElementById('viewed-count');
    if (count) count.textContent = ids.length ? ids.length + ' / ' + files.length + ' viewed' : '';
  }
  function setViewed(i, on, focus) {
    var f = files[i];
    if (!f) return;
    f.classList.toggle('viewed', on);
    f.querySelector('.viewed-check').checked = on;
    if (links[i]) links[i].classList.toggle('viewed', on);
    saveViewed();
    if (focus) select(i, true);
  }
  files.forEach(function (f, i) {
    var box = f.querySelector('.viewed-check');
    box.addEventListener('change', function () { setViewed(i, box.checked, true); });
  });
  var notesKey = 'smart-review:notes-hidden:' + location.pathname;
  function setNotesHidden(hidden) {
    document.body.classList.toggle('notes-hidden', hidden);
    try { localStorage.setItem(notesKey, hidden ? '1' : '0'); } catch (e) {}
  }
  try { if (localStorage.getItem(notesKey) === '1') setNotesHidden(true); } catch (e) {}
  var remembered = loadViewed();
  files.forEach(function (f, i) { if (remembered.indexOf(f.id) >= 0) setViewed(i, true); });
  saveViewed();
  function select(i, scroll) {
    if (!files[i]) return;
    if (selected >= 0) files[selected].classList.remove('selected');
    selected = i;
    files[i].classList.add('selected');
    links.forEach(function (a) {
      var active = a.getAttribute('href') === '#' + files[i].id;
      a.classList.toggle('active', active);
      if (active) a.scrollIntoView({ block: 'nearest' });
    });
    if (scroll) files[i].scrollIntoView({ block: 'start' });
  }
  files.forEach(function (f, i) {
    f.addEventListener('click', function () { if (selected !== i) select(i, false); });
  });
  links.forEach(function (a, i) {
    a.addEventListener('click', function () { select(i, false); });
  });
  document.addEventListener('keydown', function (ev) {
    if (ev.target.tagName === 'INPUT' || ev.metaKey || ev.ctrlKey || ev.altKey) return;
    if (ev.key === 'j') select(Math.min(selected + 1, files.length - 1), true);
    else if (ev.key === 'k') select(Math.max(selected - 1, 0), true);
    else if (ev.key === 'n') setNotesHidden(!document.body.classList.contains('notes-hidden'));
    else if (ev.key === 'v' && selected >= 0) setViewed(selected, !files[selected].classList.contains('viewed'), true);
    else if (ev.key === 'h') {
      var all = document.querySelectorAll('button.toggle');
      var anyClosed = Array.prototype.some.call(all, function (b) { return b.getAttribute('aria-expanded') !== 'true'; });
      all.forEach(function (b) { setOpen(b, anyClosed); });
    }
  });
  select(Math.max(files.findIndex(function (f) { return '#' + f.id === location.hash; }), 0), false);
})();
"""


def cmd_render(args):
    session = Path(args.session)
    state = json.loads((session / "state.json").read_text())
    plan = json.loads(Path(args.plan).read_text())
    files = {f.path: f for f in parse_patch((session / "diff.patch").read_bytes())}
    review = build_review(plan, state, files)

    out = Path(args.out) if args.out else session / "review.html"
    out.write_text(render_page(review), errors="surrogateescape")
    (session / "plan.json").write_text(json.dumps(plan, indent=2))

    shown = sum(len(c.shown) for c in review.cards)
    total = sum(len(f.hunks) for f in files.values())
    print(f"review: {out}")
    print(f"showing {shown} of {total} hunks across {len(review.cards)} of {len(files)} files; {len(review.skipped)} skipped")
    if review.unclassified:
        print(f"unclassified (shown in full at the end): {', '.join(review.unclassified)}")
    if not args.no_open:
        webbrowser.open(out.as_uri())


# --------------------------------------------------------------------------- main


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    dump = sub.add_parser("dump", help="detect scope and write the hunk listing")
    dump.add_argument("--base", help="base branch or rev (default: origin/HEAD, next, main or master)")
    scope = dump.add_mutually_exclusive_group()
    scope.add_argument("--committed", action="store_true", help="review the commits since the base even if the tree is dirty")
    scope.add_argument("--untracked", action="store_true", help="include untracked (non-ignored) files in an uncommitted review")
    scope.add_argument("--pr", help="review a pull request (number, URL or branch) in a worktree inside the session")
    dump.set_defaults(func=cmd_dump)
    render = sub.add_parser("render", help="render review.html from a plan and open it")
    render.add_argument("session")
    render.add_argument("plan")
    render.add_argument("--no-open", action="store_true", help="write the page but do not open a browser")
    render.add_argument("--out", help="write the page to this path instead of <session>/review.html")
    render.set_defaults(func=cmd_render)
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
