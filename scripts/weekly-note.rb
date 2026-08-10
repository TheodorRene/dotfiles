#!/usr/bin/env ruby
# frozen_string_literal: true

# Resolve (and, if missing, create) this week's Impero note.
#
# Prints the absolute path of the note on stdout so a shell wrapper can open it
# (see the `week` function in zsh/functions.zsh). All diagnostics go to stderr.
#
# Naming: notes are `<ISO-year>-<ISO-week>.md` (e.g. 2026-30.md), matching the
# ids Obsidian's weekly-note plugin writes into the frontmatter.
#
# When this week's note doesn't exist yet, the most recent earlier week's note
# is copied verbatim and its `id:` frontmatter line is rewritten to this week.
# The rest is left untouched for you to prune by hand.

require "date"

NOTES_DIR = File.expand_path("~/Documents/inner-sanctum/Impero")
WEEK_RE = /\A(\d{4})-(\d{2})\.md\z/

def week_id(date = Date.today)
  date.strftime("%G-%V")
end

# All existing week notes as [[year, week], filename], newest last.
def existing_weeks
  Dir.children(NOTES_DIR)
     .filter_map { |f| (m = WEEK_RE.match(f)) && [[m[1].to_i, m[2].to_i], f] }
     .sort_by(&:first)
end

def newest_before(target_key)
  existing_weeks.select { |key, _| (key <=> target_key) < 0 }.last
end

def frontmatter_stub(id)
  <<~MD
    ---
    id: "#{id}"
    aliases: []
    tags: []
    ---

  MD
end

# Rewrite the first `id:` line of a note's frontmatter to the new week id.
def with_id(content, id)
  if content.match?(/^id:\s*.*$/)
    content.sub(/^id:\s*.*$/, %(id: "#{id}"))
  else
    # No frontmatter to fix up — prepend a stub so the file is still valid.
    frontmatter_stub(id) + content
  end
end

id = week_id
target = File.join(NOTES_DIR, "#{id}.md")

unless File.exist?(target)
  prev = newest_before([id[0, 4].to_i, id[5, 2].to_i])
  if prev
    _, prev_file = prev
    warn "week: creating #{id}.md from #{prev_file}"
    File.write(target, with_id(File.read(File.join(NOTES_DIR, prev_file)), id))
  else
    warn "week: no earlier note found; creating empty #{id}.md"
    File.write(target, frontmatter_stub(id))
  end
end

puts target
