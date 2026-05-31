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

For any project with a `.vercel/project.json`, restore by linking + pulling:

```sh
vercel link          # connect the local dir to the Vercel project
vercel env pull      # writes .env.local from the cloud (use --yes to skip prompt)
```

1Password's only job here is to hold your **Vercel account login** (+ optionally a
Vercel access token). Alternative to writing a file at all:
`vercel env run -- next dev` injects vars at runtime, nothing on disk.

### Bucket B — 1Password owns it (manual copy into `.env.local`)

Every other project — anything **without** a `.vercel/project.json`. No cloud
manager exists for these, so 1Password is the source of truth and you copy each
value into the project's `.env.local` by hand.

> To find a project's bucket: `ls .vercel/project.json` → Bucket A if present,
> Bucket B if not.
>
> For the keys a project needs: check its `.env.local.example` (if present) or
> `git grep -i 'process.env\.'`.

## Keys to restore (Bucket B / 1Password)

| Key | Used by | Where to get it |
|---|---|---|
| `CALCOM_API_KEY` | scheduling tooling | Cal.com → Settings → Developer → API Keys |
| `ANTHROPIC_API_KEY` | Claude API scripts, tooling | console.anthropic.com → API Keys |
| `OPENAI_API_KEY` | misc AI scripts | platform.openai.com → API Keys |
| `PERPLEXITY_API_KEY` | deep-research runs | perplexity.ai → Settings → API |
| `GITHUB_TOKEN` | gh / CI scripts (if not using `gh auth`) | github.com → Settings → Developer settings → PAT |

> Not exhaustive — Bucket A projects' keys are **not** listed here on purpose
> (they come from `vercel env pull`).

## Other credentials (not env vars)

- **GitHub SSH key** — lives in the **1Password SSH agent**; the committed
  `~/.ssh/config` points at it via `IdentityAgent`. Add the key in 1Password
  (Settings → Developer → SSH Agent) and its public half to
  github.com/settings/keys. If 1Password is absent, `scripts/setup-ssh.sh` falls
  back to minting `~/.ssh/id_ed25519`.
- **Claude Code auth** — re-run Claude Code and sign in; it regenerates
  `~/.claude/.credentials.json`. Not restored from any repo.
- **GitHub CLI (`gh`)** — run `gh auth login`; the keyring token doesn't migrate.
  SSH covers `git` operations, but `gh` commands/scripts need their own auth.
- **1Password itself** — sign in first thing; everything else depends on it.
