#!/bin/bash
#
# Doctor — one-shot health check for a machine set up by this repo.
# Codifies the FIRST-RUN.md "Verify it worked" checks (BACKLOG #11) plus the
# failure classes from the June 2026 new-Mac bring-up (macOS-ahead-of-Homebrew,
# formula-vs-binary names, SSH-under-pipefail). Read-only: it changes no
# setting and runs no fix. One side effect: its request to the chaos
# dashboard's /frame route can refresh that route's own cache for its size.
#
# Run: sh ~/dotfiles/scripts/doctor.sh

set -uo pipefail

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=scripts/lib/detect.sh
. "$SCRIPT_DIR/scripts/lib/detect.sh"
# shellcheck source=scripts/lib/ui.sh
. "$SCRIPT_DIR/scripts/lib/ui.sh"

PASS=0
WARN=0
FAIL=0

pass() { ui_success "$1"; PASS=$((PASS + 1)); }
warn() { ui_info "⚠ $1"; WARN=$((WARN + 1)); }
fail() { ui_error "$1"; FAIL=$((FAIL + 1)); }

ui_header "Dotfiles Doctor"

# ── Homebrew ─────────────────────────────────────────────────────────────────
ui_section "Homebrew"
if is_homebrew_installed; then
    pass "brew present ($(brew --version | head -1))"
    if [ -n "${HOMEBREW_FAKE_MACOS:-}" ]; then
        pass "macOS-ahead fallback active (HOMEBREW_FAKE_MACOS=$HOMEBREW_FAKE_MACOS)"
    elif maybe_fake_unsupported_macos; then
        # Detection exported the var into THIS process only — doctor is
        # read-only; we just report what the shell is missing.
        warn "macOS $FAKE_MACOS_APPLIED is newer than Homebrew knows — bottle ops will fail with ':dunno'."
        ui_info "  Fix: add 'export HOMEBREW_FAKE_MACOS=$HOMEBREW_FAKE_MACOS' to ~/.zshrc.local"
    else
        pass "macOS version known to Homebrew"
    fi
else
    fail "brew not found — run sh setup"
fi

# ── Brewfile CLI tools ───────────────────────────────────────────────────────
ui_section "CLI Tools (config/Brewfile)"
MISSING_TOOLS=()
while IFS= read -r line; do
    if [[ $line =~ ^brew[[:space:]]+\"([^\"]+)\" ]]; then
        TOOL="${BASH_REMATCH[1]}"
        is_tool_installed "$TOOL" || MISSING_TOOLS+=("$TOOL")
    fi
done < "$SCRIPT_DIR/config/Brewfile"
if [ ${#MISSING_TOOLS[@]} -eq 0 ]; then
    pass "all Brewfile tools installed"
else
    fail "missing tools: ${MISSING_TOOLS[*]}"
    ui_info "  Fix: brew bundle install --file $SCRIPT_DIR/config/Brewfile"
fi

# ── Brewfile drift (reverse direction) ───────────────────────────────────────
# Things installed by hand never flow back into the Brewfiles, so the next
# machine silently misses them. Warn-only.
ui_section "Brewfile Drift"
if is_homebrew_installed; then
    # No process substitution — macOS `sh` (bash in POSIX mode) rejects it.
    # Formula/cask tokens never contain spaces, so word-splitting is safe.
    UNTRACKED_FORMULAE=()
    for leaf in $(brew leaves 2>/dev/null); do
        grep -qE "^brew[[:space:]]+\"([^\"]+/)?${leaf}\"" "$SCRIPT_DIR/config/Brewfile" || UNTRACKED_FORMULAE+=("$leaf")
    done
    if [ ${#UNTRACKED_FORMULAE[@]} -eq 0 ]; then
        pass "no untracked formulae"
    else
        warn "${#UNTRACKED_FORMULAE[@]} formula(e) installed but not in config/Brewfile: ${UNTRACKED_FORMULAE[*]}"
        ui_info "  Add the keepers to config/Brewfile so the next machine gets them."
    fi

    UNTRACKED_CASKS=()
    for cask in $(brew list --cask 2>/dev/null); do
        grep -qE "^cask[[:space:]]+\"${cask}\"" "$SCRIPT_DIR/config/Brewfile.apps" || UNTRACKED_CASKS+=("$cask")
    done
    if [ ${#UNTRACKED_CASKS[@]} -eq 0 ]; then
        pass "no untracked casks"
    else
        warn "${#UNTRACKED_CASKS[@]} cask(s) installed but not in config/Brewfile.apps: ${UNTRACKED_CASKS[*]}"
    fi
fi

# ── Node via fnm ─────────────────────────────────────────────────────────────
ui_section "Node (fnm)"
if command -v node >/dev/null 2>&1; then
    case "$(command -v node)" in
        *fnm*) pass "node $(node --version) served by fnm" ;;
        *)     warn "node $(node --version) NOT served by fnm ($(command -v node)) — shell init may be stale" ;;
    esac
else
    fail "node not on PATH — run 'fnm install --lts && fnm default lts-latest', then open a fresh shell"
fi

# ── GitHub SSH ───────────────────────────────────────────────────────────────
ui_section "GitHub SSH"
# Capture-then-grep: ssh -T git@github.com always exits non-zero (no shell),
# so a direct pipe under pipefail would report failure even on success.
ssh_result=$(ssh -o ConnectTimeout=8 -T git@github.com 2>&1 || true)
if echo "$ssh_result" | grep -q "successfully authenticated"; then
    pass "GitHub SSH authenticated (1Password agent)"
else
    fail "GitHub SSH not authenticating — is 1Password unlocked with the SSH agent on?"
    ui_info "  ($(echo "$ssh_result" | head -1))"
fi

# ── Dotfile symlinks ─────────────────────────────────────────────────────────
# ⚠ This used to check ~/.zshrc and nothing else, and reported green on the
# Mac Studio (2026-08-13) while FOUR packages were entirely unlinked — ghostty's
# font config, ~/.bin, aerospace, and the git templates. Pulling the repo does
# not re-stow it, so new files sit unlinked and invisible. Audit every package.
ui_section "Symlinks"
STOW_PACKAGES="${STOW_PACKAGES:-git shell terminal editors bin wm ssh}"
if command -v stow >/dev/null 2>&1 && [ -d "$SCRIPT_DIR/dotfiles" ]; then
    UNLINKED=()
    for pkg in $STOW_PACKAGES; do
        # A simulate run prints LINK for anything not yet linked, and WARNING!
        # for a target stow refuses to adopt (e.g. a hand-made absolute
        # symlink). "reverts previous action" is stow's own bookkeeping for
        # links it already owns — not a gap.
        pending=$(stow --simulate -v -R -d "$SCRIPT_DIR/dotfiles" -t "$HOME" "$pkg" 2>&1 \
            | grep -E '^(LINK|CONFLICT|WARNING!)|not owned by stow' \
            | grep -vc 'reverts previous action')
        [ "$pending" != "0" ] && UNLINKED+=("$pkg")
    done
    if [ ${#UNLINKED[@]} -eq 0 ]; then
        pass "all stow packages linked ($STOW_PACKAGES)"
    else
        fail "unlinked stow package(s): ${UNLINKED[*]}"
        ui_info "  Fix: cd ~/dotfiles && stow -R -d dotfiles -t \"\$HOME\" ${UNLINKED[*]}"
    fi
else
    warn "GNU stow not available — cannot audit symlinks"
fi
# Kept as a distinct check: the stow audit proves links exist, this proves the
# shell actually loads from the repo.
if [ -L "$HOME/.zshrc" ] && [[ "$(readlink "$HOME/.zshrc")" == *dotfiles* ]]; then
    pass "~/.zshrc symlinked into dotfiles"
else
    fail "~/.zshrc is not a dotfiles symlink — run scripts/symlink-dotfiles.sh"
fi

# ── Git config drift ─────────────────────────────────────────────────────────
# ⚠ ~/.gitconfig is GENERATED from the template, not symlinked, so the stow
# audit above cannot see it drift. Worse, setup-git.sh returns early with "Git
# already configured" whenever the file has a name and email — so template
# changes never reach a machine that already has one. The Studio ran a Feb-era
# config for six months, missing delta and commit signing entirely (2026-08-13).
ui_section "Git Config"
GITCONFIG_TEMPLATE="$SCRIPT_DIR/dotfiles/git/.gitconfig.template"
if [ -f "$HOME/.gitconfig" ] && [ -f "$GITCONFIG_TEMPLATE" ]; then
    MISSING_SECTIONS=""
    # Here-doc, not process substitution (macOS `sh` rejects it — see above), and
    # a read loop rather than `for`, because section names contain spaces:
    # [gpg "ssh"] would otherwise split into two bogus entries.
    #
    # ⚠ Ask git, don't grep the file. ~/.gitconfig ends with an [include] of
    # ~/.gitconfig.local, so a section can be fully configured while absent from
    # the file itself — grepping reported [gpg]/[commit]/[tag] missing on a
    # machine that was demonstrably signing commits.
    while IFS= read -r section; do
        [ -n "$section" ] || continue
        # [gpg "ssh"] -> gpg.ssh ; [commit] -> commit
        key=$(printf '%s' "$section" | tr -d '[]"' | tr ' ' '.')
        git config --get-regexp "^${key}\\." >/dev/null 2>&1 \
            || MISSING_SECTIONS="$MISSING_SECTIONS $section"
    done <<EOF
$(grep -oE '^\[[^]]+\]' "$GITCONFIG_TEMPLATE" | sort -u)
EOF
    if [ -z "$MISSING_SECTIONS" ]; then
        pass "~/.gitconfig carries every section the template defines"
    else
        warn "~/.gitconfig is missing template section(s):$MISSING_SECTIONS"
        ui_info "  setup-git.sh skips an existing config — reconcile by hand, or rerun it and choose Reconfigure."
    fi

    # Signing deserves its own check: it fails silently. Commits keep succeeding,
    # they just land unverified, and you find out on GitHub weeks later.
    if [ "$(git config --get commit.gpgsign 2>/dev/null)" = "true" ]; then
        pass "commit signing enabled ($(git config --get gpg.format 2>/dev/null || echo openpgp))"
    else
        warn "commit signing is OFF — commits will land unverified"
    fi
else
    warn "~/.gitconfig or the template is missing — run scripts/setup-git.sh"
fi

# ── Claude config (~/.claude) ────────────────────────────────────────────────
ui_section "Claude Code"
if [ -d "$HOME/.claude/.git" ]; then
    pass "~/.claude is version-controlled (claude-config)"
    dirty=$(git -C "$HOME/.claude" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$dirty" != "0" ]; then
        warn "~/.claude has $dirty uncommitted change(s) — memory drift won't reach other machines until pushed"
    fi
    unpushed=$(git -C "$HOME/.claude" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)
    if [ "$unpushed" != "0" ]; then
        warn "~/.claude has $unpushed unpushed commit(s)"
    fi
    if launchctl list "ca.mlaws.claude-autosave" >/dev/null 2>&1; then
        pass "claude-config autosave agent loaded (ca.mlaws.claude-autosave)"
    else
        fail "claude-config autosave agent NOT loaded — run ~/dotfiles/scripts/setup-autosave.sh"
    fi
else
    fail "~/.claude not version-controlled — run scripts/setup-claude.sh (needs GitHub SSH)"
fi

# ── chaos repo extras ────────────────────────────────────────────────────────
if [ -d "$HOME/code/chaos" ]; then
    ui_section "Chaos"
    if launchctl list "ca.mlaws.chaos-autosave" >/dev/null 2>&1; then
        pass "autosave agent loaded (ca.mlaws.chaos-autosave)"
    else
        fail "autosave agent NOT loaded — run ~/dotfiles/scripts/setup-autosave.sh"
    fi
    if command -v jq >/dev/null 2>&1 && [ -x "$HOME/code/chaos/.claude/skills/slurp/drain.sh" ]; then
        pass "/slurp deps present (jq + drain.sh)"
    else
        warn "/slurp deps incomplete (need jq + executable .claude/skills/slurp/drain.sh)"
    fi

    # Dashboard + calendar agents. Studio only on purpose — .cache/calendar.json
    # is git-tracked and a second machine on a timer would fight over it.
    # ⚠ `launchctl list` printing the label is NOT the check. The agent this
    # replaces stayed "loaded" while failing 1,279 consecutive times against a
    # wrapper script that had been deleted. Check that :2424 answers, and check
    # the calendar job's LAST EXIT STATUS, not its presence.
    if [ "$(/usr/sbin/scutil --get LocalHostName 2>/dev/null)" = "${CHAOS_DASHBOARD_HOST:-studio}" ]; then
        if ! launchctl list "ca.mlaws.chaos-dashboard" >/dev/null 2>&1; then
            fail "dashboard agent NOT loaded — run ~/dotfiles/scripts/setup-dashboard-agents.sh"
        elif curl -fsS --max-time 4 -o /dev/null "http://127.0.0.1:2424/"; then
            pass "dashboard agent serving on :2424 (ca.mlaws.chaos-dashboard)"
        else
            fail "dashboard agent loaded but :2424 is not answering — see ~/.local/state/chaos-dashboard.out.log"
        fi

        # ⚠ Freshness comes from lastRefresh INSIDE the json, never the file
        # mtime — git operations and hand-commits touch this tracked file, so
        # its mtime currently reads three days newer than its own contents.
        # Read before the agent check so the cloud check below can compare
        # against it even when the agent isn't loaded.
        cache="$HOME/code/chaos/dashboard/.cache/calendar.json"
        lr=$(sed -n 's/.*"lastRefresh": *"\([^.Z"]*\).*/\1/p' "$cache" 2>/dev/null | head -1)
        lr_epoch=$(date -j -u -f '%Y-%m-%dT%H:%M:%S' "$lr" +%s 2>/dev/null || echo 0)

        if ! cal_list=$(launchctl list "ca.mlaws.chaos-calendar" 2>/dev/null); then
            fail "calendar agent NOT loaded — run ~/dotfiles/scripts/setup-dashboard-agents.sh"
        else
            cal_status=$(printf '%s\n' "$cal_list" | awk -F'= ' '/LastExitStatus/ {gsub(/[; ]/,"",$2); print $2}')
            age_h=$(( ( $(date +%s) - lr_epoch ) / 3600 ))

            if [ "${cal_status:-0}" != "0" ]; then
                fail "calendar refresh last exited ${cal_status} — see ~/.local/state/chaos-calendar.out.log (try: hey auth status)"
            elif [ "$lr_epoch" = 0 ]; then
                fail "calendar agent loaded but .cache/calendar.json has no readable lastRefresh"
            elif [ "$age_h" -ge 2 ]; then
                warn "calendar agent reports success but lastRefresh is ${age_h}h old — it is not actually refreshing"
            else
                pass "calendar agent healthy, cache ${age_h}h old (ca.mlaws.chaos-calendar)"
            fi
        fi

        # ★ The copy the CLOUD briefing reads. The scheduled /morning runs in a
        # fresh clone with no hey, so it sees only what reached origin, and this
        # Mac force-pushes its tree to `autosave` (~/.bin/chaos-autosave.sh). A
        # green working copy above says nothing about that push. No fetch here
        # (read-only, and SSH can prompt 1Password): origin/autosave moves only
        # on a successful push or fetch, so this is AS OF THE LAST FETCH/PUSH.
        # ⚠ A push to `autosave` from another Mac after ours won't show here.
        # A stale cloud copy that is no older than the working copy means the
        # calendar refresh is the fault (flagged above), not autosave; only a
        # cloud copy BEHIND the working copy points at autosave.
        cloud_lr=$(git -C "$HOME/code/chaos" show origin/autosave:dashboard/.cache/calendar.json 2>/dev/null \
            | sed -n 's/.*"lastRefresh": *"\([^.Z"]*\).*/\1/p' | head -1)
        cloud_epoch=$(date -j -u -f '%Y-%m-%dT%H:%M:%S' "$cloud_lr" +%s 2>/dev/null || echo 0)
        cloud_age_m=$(( ( $(date +%s) - cloud_epoch ) / 60 ))
        if [ "$cloud_epoch" = 0 ]; then
            warn "this clone's origin/autosave has no readable calendar lastRefresh (as of the last fetch/push)"
        elif [ "$cloud_age_m" -ge 120 ]; then
            if [ "${lr_epoch:-0}" != 0 ] && [ "$cloud_epoch" -ge "${lr_epoch:-0}" ]; then
                warn "origin/autosave calendar is $((cloud_age_m / 60))h old (as of the last fetch/push), no older than the working copy — the calendar refresh above is the fault, not autosave"
            else
                warn "origin/autosave calendar is $((cloud_age_m / 60))h old (as of the last fetch/push) — autosave isn't reaching origin, or another Mac overwrote autosave (possible until the MacBook pulls the per-host fix); see ~/.local/state/chaos-autosave.log"
            fi
        else
            pass "cloud copy fresh: origin/autosave calendar ${cloud_age_m}m old (as of the last fetch/push)"
        fi

        # Same shape for weather. The frame's weather row returns null once the
        # cache passes ~3h, so a dead refresher takes the row off the panel
        # silently — which is how /morning's calendar died for 97 days.
        if ! wx_list=$(launchctl list "ca.mlaws.chaos-weather" 2>/dev/null); then
            fail "weather agent NOT loaded — run ~/dotfiles/scripts/setup-dashboard-agents.sh"
        else
            wx_status=$(printf '%s\n' "$wx_list" | awk -F'= ' '/LastExitStatus/ {gsub(/[; ]/,"",$2); print $2}')
            wx_cache="$HOME/code/chaos/dashboard/.cache/weather.json"
            wx_gen=$(sed -n 's/.*"generatedAt": *"\([^.Z"]*\).*/\1/p' "$wx_cache" 2>/dev/null | head -1)
            wx_epoch=$(date -j -u -f '%Y-%m-%dT%H:%M:%S' "$wx_gen" +%s 2>/dev/null || echo 0)
            wx_age_h=$(( ( $(date +%s) - wx_epoch ) / 3600 ))

            if [ "${wx_status:-0}" != "0" ]; then
                fail "weather refresh last exited ${wx_status} — see ~/.local/state/chaos-weather.out.log"
            elif [ "$wx_epoch" = 0 ]; then
                fail "weather agent loaded but .cache/weather.json has no readable generatedAt"
            elif [ "$wx_age_h" -ge 3 ]; then
                warn "weather cache is ${wx_age_h}h old — the frame drops the weather row past ~3h"
            else
                pass "weather agent healthy, cache ${wx_age_h}h old (ca.mlaws.chaos-weather)"
            fi
        fi

        ui_section "Desk panel"
        # ★ The frame route itself. Everything above can be green while the
        # route the panel is drawn from returns a 500. (The panel fetches
        # /frame.raw, which is this route turned into pixels.)
        # ⚠ Deliberately the default size, NOT the panel's 1404×1872: /frame
        # keeps one edition record per view and size (and writes it when the
        # content moved), so a request at the panel's size could mint the
        # panel's next edition itself. The panel never reads this size's record.
        if curl -fsS --max-time 8 -o /dev/null "http://127.0.0.1:2424/frame?view=morning"; then
            pass "/frame renders (the route the desk panel is drawn from)"
        else
            fail "/frame is NOT rendering — the desk panel will hold its last image forever"
        fi

        # ★ The tether: the Mac half of the panel. It holds the USB tunnel the
        # panel fetches through, and takes the tablet over after every boot.
        # ⚠ Installed BY HAND from the chaos checkout, never by `sh setup` or
        # setup-dashboard-agents.sh (decided 2026-09-28; recorded in chaos's
        # dashboard/kobo/README.md). Its binary is gitignored, so a rebuilt
        # Studio has neither until the two commands below run. ✗ Never automate
        # them: `install.sh --active` pins takeover.sh's sha256, and that pin
        # is a human approval step.
        # ⚠ Match `state = ` at exactly ONE tab: launchctl print also carries
        # nested "state = active" lines and a "job state" line.
        RM2="$HOME/code/chaos/dashboard/kobo/rm2"
        tether=$(launchctl print "gui/$(id -u)/ca.mlaws.rm2-tether" 2>/dev/null) || tether=""
        t_state=$(printf '%s\n' "$tether" | awk '/^\tstate = / {sub(/^\tstate = /, ""); print; exit}')
        if [ -x "$RM2/dist/rm2tether" ] && [ "$t_state" = running ]; then
            # Running is not feeding: observe mode probes and acts on nothing.
            case "$tether" in
                *-observe=false*)
                    # ⚠ Active is not "will take over" either. At each takeover
                    # the agent reads takeover.sh and refuses one whose sha256
                    # isn't the pin in its arguments, and a latched breaker
                    # refuses too. launchd still says running, and the glass
                    # stays fed until the tablet next boots, so neither shows
                    # anywhere else until the panel goes dark. Both are reads.
                    # Active mode won't start without a pin, so none = unreadable.
                    t_pin=$(printf '%s\n' "$tether" | sed -n 's/.*-script-sha256=\([0-9a-f]\{64\}\).*/\1/p' | head -1)
                    t_disk=$(shasum -a 256 < "$RM2/tether/device/takeover.sh" 2>/dev/null | cut -d' ' -f1)
                    t_json="$HOME/Library/Application Support/rm2panel/tether-state.json"
                    if [ -z "$t_pin" ]; then
                        warn "tether active, but its approved takeover.sh sha256 isn't readable from launchctl, so it wasn't compared"
                    elif [ "$t_pin" != "$t_disk" ]; then
                        warn "tether active, but takeover.sh no longer matches the sha256 it was approved at — the tablet's next boot will not be taken over"
                        ui_info "  Re-approve by hand once the change is reviewed: ~/code/chaos/dashboard/kobo/rm2/tether/launchd/install.sh --active"
                        ui_info "  ⚠ --active approves takeover.sh as it is on disk: check it has no local edits first."
                    elif grep -q '^  "trip":' "$t_json" 2>/dev/null; then
                        warn "tether active, but its breaker is latched — it will not take the tablet over"
                        ui_info "  Read why first (changes nothing): ~/code/chaos/dashboard/kobo/rm2/dist/rm2tether status"
                    else
                        pass "tether running in active mode (ca.mlaws.rm2-tether)"
                    fi ;;
                *) warn "tether running but NOT in active mode — it probes the tablet and takes nothing over"
                   ui_info "  Go live by hand: ~/code/chaos/dashboard/kobo/rm2/tether/launchd/install.sh --active"
                   ui_info "  ⚠ --active approves takeover.sh as it is on disk: check it has no local edits first." ;;
            esac
        else
            if [ ! -x "$RM2/dist/rm2tether" ]; then
                warn "tether binary not built: dashboard/kobo/rm2/dist/rm2tether (gitignored, so a fresh clone has none)"
            elif [ -z "$tether" ]; then
                warn "tether agent NOT installed (ca.mlaws.rm2-tether) — the desk panel has no feed"
            else
                warn "tether agent loaded but ${t_state:-not running} — see ~/.local/state/rm2-tether.out.log"
            fi
            ui_info "  Installed by hand, never by setup. Run, in order:"
            ui_info "    ~/code/chaos/dashboard/kobo/rm2/scripts/build.sh"
            ui_info "    ~/code/chaos/dashboard/kobo/rm2/tether/launchd/install.sh --active"
            ui_info "  ⚠ --active approves takeover.sh as it is on disk: check it has no local edits first."
        fi

        # ★ Is the glass still being fed? E-ink holds its last frame, so a dead
        # feed looks exactly like a live one. /frame.raw rewrites this file on
        # every poll whose User-Agent is rm2panel/, and nothing else writes it:
        # it is the panel's own signal. READ it, never fetch for it; a request
        # from here isn't the panel's and proves nothing. /daily reads the same
        # file (chaos .claude/skills/daily/frame-liveness.sh), and 30 min is its
        # STALE_MIN, rm2panel's own -stale-after: past it the glass shows the
        # device's stale face. Freshness comes from INSIDE the json, never the
        # mtime. Written by JSON.stringify(…, null, 2), so one key per line.
        beat="$HOME/code/chaos/dashboard/.cache/frame-heartbeat.json"
        hb() { sed -n "s/^ *\"$1\": *\"\{0,1\}\([^\",]*\).*/\1/p" "$beat" 2>/dev/null | head -1; }
        # "2026-09-23T14:05:07-04:00" (the route's local time + offset) → epoch, or 0.
        hb_epoch() {
            date -j -f '%Y-%m-%dT%H:%M:%S%z' \
                "$(printf '%s' "$1" | sed -E 's/Z$/+0000/; s/([+-][0-9]{2}):([0-9]{2})$/\1\2/')" +%s 2>/dev/null || echo 0
        }
        panel_live=0
        if [ ! -f "$beat" ]; then
            warn "no panel heartbeat — the desk panel has never fetched a frame from this Mac"
        else
            now=$(date +%s)
            at_ep=$(hb_epoch "$(hb at)")
            ok_ep=$(hb_epoch "$(hb lastOk)")
            hb_st=$(hb status)
            hb_fail=$(hb failures)
            hb_unp=$(hb unpainted)
            # A count that isn't a number means the file can't be trusted.
            case "${hb_fail:-0}${hb_unp:-0}" in *[!0-9]*) at_ep=0 ;; esac
            at_m=$(( (now - at_ep) / 60 ))
            ok_m=$(( (now - ok_ep) / 60 ))
            if [ "$at_ep" = 0 ]; then
                warn "panel heartbeat unreadable, so the panel's state is unknown ($beat)"
            elif [ "$ok_ep" = 0 ]; then
                warn "desk panel has polled (last ${at_m}m ago) but never had a good answer (last HTTP ${hb_st})"
            elif [ "$ok_m" -ge 30 ] && [ "$at_m" -ge 30 ]; then
                warn "desk panel NOT live: it stopped asking ${at_m}m ago, so the glass shows its stale face"
            elif [ "$ok_m" -ge 30 ]; then
                warn "desk panel NOT live: polling, but its last good answer was ${ok_m}m ago (last HTTP ${hb_st})"
            elif [ "${hb_fail:-0}" -gt 0 ]; then
                warn "desk panel's last ${hb_fail} poll(s) failed (HTTP ${hb_st}); last good answer ${ok_m}m ago"
            elif [ "${hb_unp:-0}" -gt 2 ]; then
                warn "desk panel fetching but not painting: it has held the same frame for ${hb_unp} polls while served newer ones"
            else
                pass "desk panel live: last poll ${at_m}m ago got HTTP ${hb_st} (frame-heartbeat.json)"
                panel_live=1
            fi
        fi
        # Every outcome but live gets the one command that tells the causes
        # apart (route down, no cable, tunnel down). Pointed at, never run: once
        # the heartbeat is 30 min stale it fetches /frame at the panel's size.
        [ "$panel_live" = 1 ] || ui_info "  Diagnose: bash ~/code/chaos/.claude/skills/daily/frame-liveness.sh"
    fi
fi

# ── Ollama (local models) ────────────────────────────────────────────────────
# ⚠ "A server is answering on :11434" is NOT the check. On the Studio
# (2026-08-13) ollama was answering fine — as an unsupervised child of Raycast,
# with no plist and no log, so it would have vanished with Raycast. Verify the
# SUPERVISOR, then the API, then that the model Zed names actually exists.
if command -v ollama >/dev/null 2>&1; then
    ui_section "Ollama"
    if launchctl list homebrew.mxcl.ollama >/dev/null 2>&1; then
        pass "ollama managed by brew services (comes back at login)"
    elif pgrep -f "ollama serve" >/dev/null 2>&1; then
        warn "ollama is running but NOT under brew services — nothing will restart it"
        ui_info "  Fix: pkill -f 'ollama serve' && brew services start ollama"
    else
        fail "ollama not running — run 'brew services start ollama'"
    fi

    if curl -fsS -m 5 http://localhost:11434/api/tags >/dev/null 2>&1; then
        pass "ollama API responding on :11434"
        # Zed's tab completion fails silently when this model is absent, so the
        # config naming it is not evidence the machine has it.
        ZED_SETTINGS="$HOME/.config/zed/settings.json"
        if [ -r "$ZED_SETTINGS" ]; then
            OLLAMA_MODELS=$(ollama list 2>/dev/null | awk 'NR>1 {print $1}')
            # Scope each lookup to its own block. A bare grep for "model" takes
            # whichever key appears first in the file — which is exactly how this
            # check first reported the agent model as the edit-prediction one.
            check_zed_model() {
                _label="$1"
                _want=$(awk -v a="$2" 'index($0, a) {f=1} f && /"model"[[:space:]]*:/ {print; exit}' \
                    "$ZED_SETTINGS" \
                    | sed -E 's/.*"model"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
                [ -n "$_want" ] || return 0
                if printf '%s\n' "$OLLAMA_MODELS" | grep -qx "$_want"; then
                    pass "$_label model present ($_want)"
                else
                    fail "$_label model MISSING: $_want"
                    ui_info "  Fix: ollama pull $_want"
                fi
            }
            # Agent panel errors visibly when its model is absent; tab
            # completion just goes quiet, so the second one matters more.
            check_zed_model "agent-panel" '"default_model"'
            check_zed_model "edit-prediction" '"edit_predictions"'
        fi
    else
        fail "ollama API not responding on :11434"
    fi
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
ui_section "Doctor: $PASS passed · $WARN warnings · $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
