# Secrets restore checklist

Secrets are **not** in this repo. **1Password is the source of truth**, and at
runtime secrets land in per-project `.env.local` files (gitignored). This file is
the checklist for putting them back on a new machine.

Sign into **1Password first** — everything below depends on it.

## Two buckets (they must not fight over the same file)

Some projects are **Vercel-managed**: their env vars live in the Vercel dashboard
and `.env.local` is a *generated artifact*. `vercel env pull` **replaces the whole
file** (it prompts unless you pass `--yes`). So 1Password must never write into a
Vercel-linked project's `.env.local` — let Vercel own those, and let 1Password own
everything else.

### Bucket A — Vercel owns it (do NOT store per-key in 1Password)

Restore by linking + pulling, per project:

```sh
vercel link          # connect the local dir to the Vercel project
vercel env pull      # writes .env.local from the cloud (use --yes to skip prompt)
```

Vercel-linked projects (have `.vercel/project.json`):

- `draftpad`
- `redacted-project-v2`
- `niche`
- `redacted-project`
- `redacted-project`

1Password's only job here is to hold your **Vercel account login** (+ optionally a
Vercel access token). Alternative to writing a file at all:
`vercel env run -- next dev` injects vars at runtime, nothing on disk.

### Bucket B — 1Password owns it (manual copy into `.env.local`)

Everything not Vercel-linked. No cloud manager exists for these — 1Password is the
source of truth and you copy each value into the project's `.env.local` by hand.
Non-Vercel projects include `chaos/dashboard`, `redacted-project-v2`, `mlaws.ca`,
`redacted-project-os`, and the rest under `~/code`.

> Check each project's `.env.local.example` (if present) or `git grep -i
> 'process.env\.'` for the authoritative list of keys that project needs.

## Keys to restore (1Password bucket)

| Key | Used by | Where to get it |
|---|---|---|
| `CALCOM_API_KEY` | /avails + /book (chaos dashboard) | Cal.com → Settings → Developer → API Keys. Lives in `chaos/dashboard/.env.local` |
| `ANTHROPIC_API_KEY` | Claude API scripts, tooling | console.anthropic.com → API Keys |
| `OPENAI_API_KEY` | misc AI scripts | platform.openai.com → API Keys |
| `PERPLEXITY_API_KEY` | deep-research / Perplexity runs | perplexity.ai → Settings → API |
| `GITHUB_TOKEN` | gh / CI scripts (if not using gh auth) | github.com → Settings → Developer settings → PAT |

> Not exhaustive — Vercel-linked projects' keys are **not** here on purpose (they
> come from `vercel env pull`).

## Other credentials (not env vars)

- **GitHub SSH key** — now lives in **1Password's SSH agent**. `scripts/setup-ssh.sh`
  detects the agent and wires it via `~/.ssh/config.local`, skipping per-machine key
  minting. Add the key in 1Password (Settings → Developer → SSH Agent) and put its
  public key on github.com/settings/keys. (If 1Password isn't present, the script
  falls back to generating `~/.ssh/id_ed25519`.)
- **Claude Code auth** — re-run Claude Code and sign in; it regenerates
  `~/.claude/.credentials.json`. Not restored from any repo.
- **1Password itself** — sign in first thing; everything else depends on it.
