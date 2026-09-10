# Genet — deploy folder

**Status: nothing applied.** This is a design, not a build.

A directory on this machine (`~/deploy`) where dropping a file publishes it to a
secret URL, and where saving the file again republishes it. Prior art is
`~/dev/personal/DiagramMCP`, which does this for Mermaid diagrams only; the
lessons carried over and the ones deliberately dropped are noted throughout.

Daemon is `genetd`, CLI is `genet`.

---

## Decisions

| Question | Decision |
|---|---|
| Mechanism | Real directory + inotify daemon (`systemd --user`). **Not FUSE.** |
| Backend | Cloudflare **R2** + a **Pages Function**. |
| Storage | Raw bytes only. Rendering happens in the Function on request. |
| Trigger | Instant, on every *completed* write. |
| Size | Warn over ~100 MB, refuse over 4.995 GiB. |
| Feedback | mako notification + `wl-copy`, plus `genet <file>` to re-fetch a URL. |
| Retraction | 30-day TTL from last write + delete-on-remove. |
| URLs | Random per-file tokens. Non-enumerable, and not crawlable. |
| Host | `genet.theodorc.no`, CNAME'd from Route 53. **Zone stays on AWS.** |

### Why not FUSE

FUSE's genuine advantages here are publishing exactly at `release()` (so you
know a write finished) and synthetic files that never touch disk. Neither is
worth the cost: no FUSE binding is installed for any language on this machine
(no fusepy, no cargo), mounts break on daemon crashes, `allow_other` needs root
— which can't be run from Claude Code at all — and editors that write via
`rename()` are fiddly to handle correctly. `IN_CLOSE_WRITE` gives the same
write-completion signal, and a generated `.url` sidecar gives the same
synthetic-file affordance.

### Why R2 for content — and why Pages is still fine as the front door

`DiagramMCP/scripts/deploy.ts` documents a real flaw in its own header comment:
Cloudflare keeps **every past deployment live forever** at
`<hash>.<project>.pages.dev` with no authentication, so unsharing a diagram and
redeploying does not retract it. That script has to prune old deployments to
make unsharing real, and the prune is best-effort — it warns and continues on
failure. Every publish is also a full site rebuild.

Read what that actually breaks, though: it is fatal because **the content is
baked into the deployment** — each DiagramMCP build embeds the diagram source
into the bundle, so an old bundle is a frozen copy of old secrets.

Here the deployment contains **only code**. Every file lives in R2, so every
past deployment reads the *same live bucket*. Deleting an object retracts it
from all of them at once. An upload is one `PutObject`, a retraction is one
`DeleteObject`, and there is no rebuild.

**Residual caveat, stated plainly:** old deployments still run old *code*. Ship
v1 without the expiry check, add it in v2, and the v1 URL keeps serving expired
files. So pruning old deployments stays good practice — but it is now code
hygiene, not a content leak.

---

## Cost and rate limits

| | |
|---|---|
| `PutObject` (Class A) | $4.50/million — **1M/month free** |
| Storage | $0.015/GB-month — **10 GB free** |
| `DeleteObject` | **free** |
| Egress | **free, unlimited** |

Saving a file 1,000 times a day is ~30k writes/month, well inside the free
tier. Money is not a constraint on this design.

Two limits that **are** constraints:

- **R2 allows 1 write per second to the same object key** (HTTP 429 above
  that). Debouncing is mandatory, not a nicety.
- **A single PUT caps at 4.995 GiB.** Past that requires multipart uploads
  (max 10,000 parts). That is where the hard refusal goes — it is also where
  the code would get meaningfully more complex.

---

## Architecture

```
~/deploy/report.md                     you drop or save a file
        │
        │  inotify IN_CLOSE_WRITE / IN_MOVED_TO
        ▼
   genetd (systemd --user, Node)
        │  debounce ≥1.5s, hash, skip if unchanged
        │  check denylist + size
        │  WRITE PATH: PUT via S3 API — straight to R2,
        │              never through Pages
        ▼
   R2 bucket (private — no r2.dev, no bucket domain)
     key = <token>
     customMetadata = { filename, contentType, expiresAt, sha256 }
        ▲
        │  READ PATH: env.BUCKET.get(token)
        │
   Pages Function — functions/f/[token].ts
   https://genet.theodorc.no/f/<token>
        │  enforces expiry, sets headers, renders by type, streams
        ▼
   browser
```

**The two paths are separate on purpose.** Uploads go directly to R2 over the
S3 API because a Pages Function's *request body* caps at 100 MB, which would
put a ceiling far below the 5 GiB target. Downloads go through the Function,
which streams R2 responses with no size limit. Sign uploads with `aws4fetch`
(tiny, works with Node 24's built-in fetch) rather than pulling in the full AWS
SDK.

R2 is never publicly reachable on its own. The Function is the only public
door, which is what makes expiry enforcement and the security headers
unavoidable rather than advisory.

---

## Non-enumerable URLs

This was called out explicitly, so it gets its own section — it is not just
"use a long token".

1. **Token**: 128 bits from `crypto.randomBytes`, base32-encoded, ~26 chars.
   Brute-forcing is infeasible.
2. **The R2 key *is* the token.** No mapping table in the Function, and the
   Function never needs list access.
3. **The bucket must stay private.** No `r2.dev` public access, and no R2
   custom domain **bound to the bucket** — both make every object reachable by
   key directly, bypassing the Function and its expiry check. This is the single
   most important configuration step. Note this is specifically about a domain
   attached to the *bucket*; a custom domain on the **Pages project** is an
   unrelated feature and is exactly what we want (see Hostname below).
4. **The Function exposes no listing endpoint.** No index, no gallery. This is a
   deliberate departure from DiagramMCP, whose gallery page makes the full set
   of shares enumerable to anyone holding the index link.
5. **`X-Robots-Tag: noindex, nofollow`** on every response, plus a
   `/robots.txt` disallow. An unguessable URL is worthless if a link lands in
   something that crawls it.
6. **`Referrer-Policy: no-referrer`** so a click-through from a rendered page
   doesn't hand the token to a third-party site.

Not reusing DiagramMCP's `HMAC(urlSalt, slug)` scheme (`src/diagrams.ts:69`).
That is correct *there*, because diagram slugs are unique and meaningful and
re-sharing should restore the old link. Here you will drop `screenshot.png`
fifty times, and HMAC-of-filename would silently give all fifty the same URL —
a new screenshot would overwrite an old share that someone still holds a link
to. Random tokens, recorded in a local manifest.

**Caveat worth stating plainly:** this is obscurity, not access control.
Whoever holds a link can read it and pass it on. Same posture DiagramMCP
already documents, and the reason TTL matters below.

---

## Hostname — `genet.theodorc.no`, no DNS migration

`theodorc.no` stays on Route 53, untouched:

```
NS    ns-{310,575,1277,1607}.awsdns-*      Route 53   (unchanged)
@     104.198.14.52                        Ghost      (unchanged)
www   blog.theodorc.no → *.netlify.app     Netlify    (unchanged)
genet CNAME → genet.pages.dev              ← the only new record
```

This is the reason the front door is a **Pages Function rather than a Worker**.

- A **Workers custom domain requires an active Cloudflare zone.** There is no
  IP to point an A record at: Cloudflare's edge routes by `Host` on shared
  anycast addresses and issues the certificate for hostnames it controls. No
  amount of Route 53 configuration reaches a Worker.
- Adding only `genet.theodorc.no` to Cloudflare as its own zone would sidestep
  that, but **subdomain zone setup is Enterprise-only**.
- **Pages custom domains work with external DNS.** Add the domain in the Pages
  project, then CNAME it at Route 53. Subdomains only — an apex would still
  require the zone on Cloudflare, but the apex is already Ghost's.
- A **Pages Function is a Worker in all but name**, including R2 bindings via
  `context.env.BUCKET`.

So the domain constraint picks the deployment target, and costs nothing in
capability.

**Order matters:** add the custom domain in the Pages dashboard *first*, then
create the CNAME. A CNAME pointing at `pages.dev` without the domain registered
on the project resolves to a **522**.

Two things to get right:

- Keep Genet on its own subdomain and **never set cookies on it**. Anything
  scoped to `theodorc.no` itself would otherwise be sent to a host serving
  arbitrary shared files.
- `genet.pages.dev/f/<token>` will also serve, alongside the custom domain.
  Harmless — the token is what gates access, not the hostname — but worth
  knowing the shorter URL exists.

---

## Rendering (Pages Function, on request)

Storing raw bytes and rendering on request means restyling is a Function
redeploy with zero re-uploads — every already-published link picks up the new
look.

| Type | Response |
|---|---|
| `.md`, `.markdown` | Rendered HTML page, mermaid fences included |
| `.txt`, `.log`, `.json`, `.csv` | `text/plain; charset=utf-8`, inline |
| Source code | `<pre><code>` shell, highlighted client-side |
| Images, PDF, video, audio | Correct content-type, `inline` |
| `.mmd` | Mermaid render — reuse DiagramMCP's page |
| Anything else | `attachment; filename="<original>"` |
| `?raw` | Original bytes, always |

Two implementation notes:

- **Markdown**: render server-side in the Function with `markdown-it` or
  `micromark`. Sanitize the output — the source may be untrusted-ish and it is
  being served on your own origin.
- **mermaid and highlight.js are too big to bundle** into a Function comfortably.
  Store them as fixed R2 keys and have the Function serve them from
  `/_assets/mermaid.js` and `/_assets/highlight.js` on the same origin. Keeps
  the bundle small and avoids a third-party CDN in the CSP.

**Open decision — `.html` files.** Serving user HTML on the Function’s origin
means one share could `fetch()` another share's URL. Tokens make that hard to
exploit, but the clean fix is a `Content-Security-Policy: sandbox` header on
HTML responses, or serving `.html` as `text/plain` by default with an opt-in.
Worth deciding before the first HTML file goes up.

---

## Publish trigger

`chokidar` with `awaitWriteFinish: { stabilityThreshold: 1500, pollInterval: 200 }`.
That satisfies R2's 1-write-per-second-per-key limit and handles the fact that
"every write" is not a real event — editors write in chunks, or write a temp
file and `rename()` over the target, so firing on raw write events would
publish half-written files.

Then, before uploading:

- **Hash check.** Skip if the SHA-256 matches what is already published;
  editors touch files without changing them constantly.
- **Ignore editor droppings**: `*~`, `.*.swp`, `.#*`, `4913`, `*.tmp`,
  `*.part`, `*.crdownload`, `.goutputstream-*`.
- **Skip hidden files** by default.

---

## Guardrails

**Extension denylist** — refused regardless of content, no exceptions,
no override flag:

```
.env  .env.*  .pem  .key  .p12  .pfx  .jks  .kdbx  .ovpn
id_rsa*  id_ed25519*  .netrc  .npmrc  .git-credentials  .aws/credentials
```

Cheap, and it has no false positives on ordinary files. Note that
DiagramMCP's substring deny-scan (`scripts/deny-patterns.json`) was
**not** carried over — it was declined, and it fits poorly with instant
publishing anyway, since blocking on content inspection turns every save into a
maybe. The denylist covers the catastrophic cases; TTL covers the rest.

**Size**: notify and show progress above 100 MB; refuse above 4.995 GiB with a
clear reason rather than starting an upload that will fail at the ceiling.

**TTL: 30 days from last write. No automatic renewal.**

An earlier draft made presence in the folder an auto-renewing lease — a daily
timer bumping expiry for anything still in `~/deploy`. That is dropped,
because it contradicts wanting to see time remaining: under auto-renewal
nothing present ever expires and every countdown reads "30 days" forever. It
also means a file quietly stays public for years.

So expiry is a real deadline:

- Publishing sets `expiresAt = now + 30d` in R2 custom metadata. Saving the
  file again republishes it and resets the clock — active files stay alive by
  being used, not by merely existing.
- The Function checks `expiresAt` on every GET and returns **410 Gone** past it.
  Instant effect, no cleanup job in the request path.
- Deleting the file from `~/deploy` triggers an immediate `DeleteObject`
  (free) — retraction now, not at expiry.
- **Expired but still present is a normal state**, and the one the CLI is
  built to surface. The file sits in `~/deploy`, its link is dead, `genet list`
  shows it as expired, and `genet renew` brings it back at the same token.
- A daily `systemd --user` timer **notifies** rather than renews: one mako
  notification when something is within 3 days of expiry.
- An R2 **object lifecycle rule** at 30 days + a grace period is the backstop
  for when the daemon is dead or the machine is gone. This is what makes the
  whole thing safe to forget about.

Renewal keeps the same token, so a renewed link is the link you already gave
out. Tokens are only minted for paths the manifest has never seen.

---

## Feedback

**On publish**: mako notification with the URL, and `wl-copy` puts it on the
clipboard immediately so it's already pasteable. Errors — too big, denylisted,
offline, 429 — arrive as `--urgency=critical`.

**`genet`** — expiry is surfaced everywhere, not hidden behind a flag:

```
$ genet report.md
  https://genet.theodorc.no/f/k3n8p2q7wxr4m9
  12 KB · published 2 days ago · expires in 28 days

$ genet list
  FILE               SIZE     EXPIRES
  screenshot.png     1.4 MB   in 2 days      ⚠
  demo.mp4           84 MB    in 11 days
  report.md          12 KB    in 28 days
  old-notes.md       8 KB     EXPIRED 4 days ago
  scratch.txt        2 KB     never published (denylisted)
```

Sorted by time remaining ascending, so whatever needs attention is at the top.
Under 3 days is flagged; expired entries stay listed as long as the file is
still in the folder, since that is exactly the state you would otherwise not
notice.

```
genet <file>              URL, size, age, time remaining
genet list                as above
genet list --expired      only the dead ones
genet list --json         for scripting or a future waybar module
genet renew <file>        reset to 30 days, same token
genet renew --all         everything expiring within a week
genet rm <file>           unpublish now (keeps the local file)
genet status              daemon health, queue depth, last error
```

`genet <file>` also copies the URL to the clipboard, same as the publish
notification — that is the whole point of it.

History via `journalctl --user -u genetd`.

**Manifest** at `~/.local/state/genet/manifest.json`: path → `{ token, sha256,
size, publishedAt, expiresAt }`. This is what makes `genet <file>` work and what
stops a daemon restart from re-tokenizing everything. **Entries survive
expiry** — that record is what lets `genet list` report "expired 4 days ago"
and what lets `genet renew` restore the original token rather than mint a new
one. Because the original path is also written into R2 custom metadata, a lost
manifest can be rebuilt by listing the bucket from the daemon's authenticated
side.

Waybar module deliberately left out of v1 — easy to add later against the
existing docker-module pattern in this repo.

---

## Secrets

R2 API token (access key + secret) in `~/.config/genet/env`, mode 0600,
loaded by the unit via `EnvironmentFile=`.

**This file must never be symlinked into the dotfiles repo.** If
`~/.config/genet/` ever gets added to the `.config` loop in
`symlinkifier.pl`, the credentials go with it. Keep the directory out of that
loop and symlink only the unit file.

---

## Build order

1. **Cloudflare setup** — create the R2 bucket and **confirm public access is
   off**, mint a scoped R2 API token, create the Pages project `genet` and bind
   the bucket as `BUCKET`. *Requires your hands on the dashboard.*
2. **Pages Function** — `functions/f/[token].ts`: token → object, content-type
   map, expiry check, security headers, `?raw`. Ship it serving raw bytes
   correctly on `genet.pages.dev` before touching DNS or rendering.
3. **Domain** — add `genet.theodorc.no` to the Pages project **first**, then
   the CNAME in Route 53. Reverse that order and you get a 522.
4. **Rendering** — markdown first (the actual complaint), then code
   highlighting, then the `_assets` plumbing for mermaid.
5. **Daemon** — watch, debounce, hash, denylist, size check, upload, manifest,
   notify.
6. **`genet` CLI** — starting with `genet <file>`, then `list` with expiry.
7. **systemd unit** + a `symlink_path(...)` line in `symlinkifier.pl`. No root
   needed; a user unit is enough.
8. **TTL** — expiry-warning timer plus the R2 lifecycle backstop.

Steps 1 and 3 are yours — dashboard and registrar. Everything else is code.

Stack: TypeScript on Node 24 for the daemon, TypeScript + wrangler for the
Pages Function. Matches DiagramMCP, and `wrangler` is already a devDependency
there.

---

## Still open

- **`.html` handling** — sandbox CSP, or serve as `text/plain` by default.
  The only real decision left before building.
- **Later**: a waybar module, fed by `genet list --json`.
- **Later**: DiagramMCP's `share_diagram` could delegate here instead of
  carrying its own Pages deploy and prune logic — and would inherit real
  retraction in the process, since its content would move to R2.

## Settled

- Name: **Genet** — repo at `~/dev/personal/Genet`, daemon `genetd`, CLI `genet`.
- TTL: **30 days from last write**, no auto-renewal.
- Host: **`genet.theodorc.no`**, CNAME → `genet.pages.dev`. Route 53 keeps the
  zone; the only change is one new record.
- Front door is a **Pages Function**, not a Worker — because Pages custom
  domains work with external DNS and Workers custom domains do not.
- Content lives in **R2**, never in the deployment. Uploads go straight to R2;
  reads go through the Function.
