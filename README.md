# package_aware

My personal approach to staying safe from package supply-chain attacks (npm, PyPI,
VS Code extensions, Claude Code plugins), written down so I can share it and reuse it.

This repo is **not** a tool you install. It's two things:

1. **A document that describes the security posture** I run on my machine.
2. **A script that can reproduce that posture** on another machine.

If you only read one file, read
[`PACKAGE_AWARE_PLATFORM_SETTINGS.md`](PACKAGE_AWARE_PLATFORM_SETTINGS.md).

---

## Why this exists

During the active npm/PyPI supply-chain incidents, "just `npx` it" or "let the editor
auto-update extensions" became real risks. So I tightened a handful of settings across
Claude Code and VS Code: no ad-hoc package execution, no silent updates, exact version
pins, audited installs. This repo captures those decisions in a form I can share with a
team and re-apply later instead of re-explaining from memory.

---

## What's in here

```
package_aware/
├─ README.md                          ← you are here
├─ PACKAGE_AWARE_PLATFORM_SETTINGS.md ← THE shareable summary (read this)
└─ package-aware-hardening/           ← a Claude Code skill that automates it
   ├─ SKILL.md                        ← how Claude runs this workflow
   ├─ scripts/
   │  ├─ apply_package_aware_hardening.ps1  ← applies the posture to a machine
   │  └─ export_shareable_settings.ps1      ← regenerates the summary doc
   └─ references/
      ├─ settings-map.md              ← every setting + the reason for it
      └─ shareable-template.md        ← the source the summary doc is built from
```

### The two layers, plainly

| Layer | File(s) | What it's for |
|---|---|---|
| **Human-readable summary** | `PACKAGE_AWARE_PLATFORM_SETTINGS.md` | What to read or hand to a teammate. Describes the posture and gives copy-paste baseline snippets. It is **generated** from `references/shareable-template.md`. |
| **Automation (a Claude Code skill)** | `package-aware-hardening/` | Lets Claude Code (or you) *apply* the posture to a machine and *regenerate* the summary. Optional — the doc stands on its own. |

---

## How to use it

### Just want to read or copy the settings?
Open [`PACKAGE_AWARE_PLATFORM_SETTINGS.md`](PACKAGE_AWARE_PLATFORM_SETTINGS.md). It's
organized by layer (Claude Code, VS Code, package ecosystems, GitHub, Supabase) with a
copyable snippet under each.

### Want to apply this posture to a machine?
The apply script edits user-level config (`~/.claude/settings.json`, `~/.claude/CLAUDE.md`,
and VS Code `settings.json`). It **backs up every file first** to
`~/.claude/backups/package-aware-hardening/<timestamp>/`.

```powershell
# See what it would change — writes nothing:
powershell -ExecutionPolicy Bypass -File .\package-aware-hardening\scripts\apply_package_aware_hardening.ps1 -DryRun

# Actually apply it:
powershell -ExecutionPolicy Bypass -File .\package-aware-hardening\scripts\apply_package_aware_hardening.ps1
```

It sets: `DISABLE_AUTOUPDATER=1`, `autoUpdatesChannel=stable`, `allowedHttpHookUrls=[]`,
`disableBypassPermissionsMode=disable`, disables the Supabase plugin, adds the
package-manager + extension-install deny rules, sets VS Code updates to manual, and writes
a managed hardening block into `CLAUDE.md`.

> **`CLAUDE.md` is never clobbered.** The script writes its managed block only when there's
> no existing hardening section, or when a previous run left its
> `<!-- PACKAGE-AWARE-HARDENING:START -->` / `<!-- PACKAGE-AWARE-HARDENING:END -->`
> marker pair (which it then refreshes in place). If it finds a hand-written
> "Global hardening overrides" section *without* those markers, it leaves the file untouched
> and tells you so (`ClaudeMdAction: skipped-existing-unmarked-section`). So on the machine
> that authored the posture, apply safely no-ops on `CLAUDE.md`.

### Want to regenerate the shareable summary?
Edit the source (`references/shareable-template.md`), then:

```powershell
powershell -ExecutionPolicy Bypass -File .\package-aware-hardening\scripts\export_shareable_settings.ps1
```

This rewrites `PACKAGE_AWARE_PLATFORM_SETTINGS.md` and **fails loudly if it detects a
username, home path, or `C:\Users\...`** — the public doc must stay sanitized.

---

## What is deliberately NOT in here

- Machine-specific rollback notes and backup locations (kept private).
- Usernames, home directories, absolute paths, local CLI install paths.
- Any secret. Nothing here is sensitive; it's all policy.

---

## The short version of the philosophy

- Prefer exact version pins and committed lockfiles over `latest` and loose ranges.
- No ad-hoc fetch-and-run (`npx`, `pipx run`, `pnpm dlx`, `bunx`, `yarn dlx`).
- No silent editor/extension/CLI updates — keep a review window.
- Prefer standalone, auditable CLIs over marketplace/plugin paths.
- Treat the editor and CI as part of the supply chain, not separate from it.
