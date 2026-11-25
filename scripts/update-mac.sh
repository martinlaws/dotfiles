#!/bin/bash
#
# update-mac.sh: update either Mac in one go. Repos, Homebrew, Claude Code,
# uv tools, the hey CLI (pinned) and App Store apps by default; Xcode, the
# Claude desktop app and macOS itself only when asked.
#
#   bash ~/dotfiles/scripts/update-mac.sh --dry-run   # reads only
#   bash ~/dotfiles/scripts/update-mac.sh             # the default run
#   bash ~/dotfiles/scripts/update-mac.sh --help
#
# Non-interactive, except for the sudo password (asked once, up front, then
# kept warm until the script ends) and typing "restart" before a macOS
# update. Run it in a terminal, not from a Claude chat: sudo needs a real
# prompt there, and --claude-app and --macos end every chat on the Mac.
#
# One failing step never stops the rest. The summary at the end has one line
# per step: ✓ done, ⚠ skipped or partly done, ✗ failed, • not run.
# Log: ~/.local/state/update-mac/YYYY-MM-DD-HHMM.log
#
# Why the guards:
# - The `claude` cask is held out of the brew step. Upgrading it quits the
#   Claude desktop app, which hosts the Remote Control chats (perhaps the one
#   that started this run). It goes last, and only with --claude-app.
# - hey is pinned to the release chaos's send gate was read against
#   (chaos technical/2026-11-12-hey-upgrade-plan.md): never a bare
#   `hey upgrade`. The checks after it are the plan's read-only ones.
# - Repos only fast-forward. Nothing here stashes, resets, rebases or
#   merges, or touches an autosave* branch.
# - xcode-select is never changed: the step prints the command instead.
# - doctor.sh is not run from here. It is read-only except for one side
#   effect it names itself: on the Studio its /frame probe can write the
#   dashboard's edition cache. The summary prints the command to run it.
#
# Plain bash 3.2 (macOS /bin/bash): no associative arrays, no mapfile, no
# process substitution. Output follows chaos's design tokens: ━ and ─
# dividers, the glyphs ✓ ✗ ⚠ → • ▸ …, nothing of ours over 60 columns,
# and colour only on a terminal with NO_COLOR unset, never on its own.
#
# The run itself is in functions, and the last line starts it and exits on
# the same line: the repos step can pull a new copy of this very file
# mid-run, and bash reads a script as it goes.

# The steps run through step()'s "$fn", which shellcheck can't follow.
# shellcheck disable=SC2329

# Re-run under bash proper if started as `sh update-mac.sh` or from zsh.
if [ -z "${BASH_VERSION:-}" ] || (shopt -oq posix) 2>/dev/null; then
    exec /bin/bash "$0" "$@"
fi

set -u

# ── Settings ────────────────────────────────────────────────────────────────

HEY_PIN="1.13.1"
HEY_BIN="$HOME/.local/bin/hey"
# The calendar the plan's `hey event list` check reads (plan step 6).
HEY_CAL="${UPDATE_MAC_HEY_CALENDAR:-241011}"
XCODE_ID="497799835"
XCODE_APP="/Applications/Xcode.app"
CHAOS_DIR="${CHAOS_DIR:-$HOME/code/chaos}"
DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BREWFILE="$DOTFILES_DIR/config/Brewfile"
LOG_DIR="$HOME/.local/state/update-mac"
STEPS="preflight repos brew claude-code uv hey appstore xcode final macos"

# A git environment variable outranks `git -C`, so a stray GIT_DIR would
# point every repo check at one repo.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

# Character counts (the summary's 60-column fit) need a UTF-8 locale.
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
    *UTF-8*|*utf-8*|*UTF8*|*utf8*) ;;
    *) export LC_CTYPE="en_US.UTF-8" ;;
esac

DRY_RUN=0
NO_SUDO=0
OPT_XCODE=0
OPT_MACOS=0
OPT_CLAUDE_APP=0
ONLY=""
SKIP=""

usage() {
    cat <<'EOF'
Usage: update-mac.sh [flags]

Updates this Mac in one go, either Mac. The default run is
preflight, repos, brew, claude-code, uv, hey and appstore,
then a hint for the Claude app. Opt-ins: --xcode,
--claude-app, --macos.

Steps, in order:
  preflight    which Mac, free disk, power, FileVault;
               asks for sudo once
  repos        fast-forward chaos, ~/.claude, ~/dotfiles
               (on main, nothing in the way; else skip)
  brew         update, trust taps, upgrade formulae and
               apps (not the claude cask), install missing
               config/Brewfile tools, cleanup
  claude-code  claude update (new chats get it)
  uv           uv tool upgrade --all
  hey          back up, hey upgrade 1.13.1 (pinned), then
               the upgrade plan's read-only checks
  appstore     mas upgrade, Xcode left out (needs sudo)
  xcode        opt-in: install or upgrade Xcode.app
  final        the claude cask: upgraded with --claude-app,
               else the command is printed
  macos        opt-in: macOS update, then a RESTART

Flags:
  --dry-run       reads only: prints what it would do
  --no-sudo       never sudo: skips appstore, xcode, macos
  --skip STEP     leave a step out (repeatable)
  --only STEP     run only the named steps (repeatable);
                  opt-in steps still need their flag
  --xcode         include the xcode step
  --claude-app    upgrade the claude cask at the end; it
                  quits the Claude app, ending every chat
  --macos         include the macos step (you type
                  restart before anything installs)
  -h, --help      this help

Log: ~/.local/state/update-mac/YYYY-MM-DD-HHMM.log
EOF
}

die_usage() {
    printf 'update-mac: %s\n' "$1" >&2
    printf 'Steps: %s\n' "$STEPS" | fold -s -w 60 | sed 's/ *$//' >&2
    exit 2
}

check_step() {
    case " $STEPS " in
        *" $1 "*) ;;
        *) die_usage "unknown step '$1'" ;;
    esac
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run) DRY_RUN=1 ;;
            --no-sudo) NO_SUDO=1 ;;
            --xcode) OPT_XCODE=1 ;;
            --macos) OPT_MACOS=1 ;;
            --claude-app) OPT_CLAUDE_APP=1 ;;
            --skip|--only)
                [ $# -ge 2 ] || die_usage "$1 needs a step name"
                check_step "$2"
                if [ "$1" = --skip ]; then SKIP="$SKIP $2"; else ONLY="$ONLY $2"; fi
                shift ;;
            --skip=*) check_step "${1#--skip=}"; SKIP="$SKIP ${1#--skip=}" ;;
            --only=*) check_step "${1#--only=}"; ONLY="$ONLY ${1#--only=}" ;;
            -h|--help) usage; exit 0 ;;
            *) die_usage "unknown flag '$1' (try --help)" ;;
        esac
        shift
    done
}

# ── Output ──────────────────────────────────────────────────────────────────

ESC=$(printf '\033')
setup_colour() {
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != dumb ]; then
        USE_COLOUR=1
        C_OK="${ESC}[32m"; C_WARN="${ESC}[33m"; C_BAD="${ESC}[31m"
        C_HEAD="${ESC}[1m"; C_OFF="${ESC}[0m"
    else
        USE_COLOUR=0
        C_OK=""; C_WARN=""; C_BAD=""; C_HEAD=""; C_OFF=""
    fi
}

rep() {
    local out="" i=0
    while [ "$i" -lt "$2" ]; do out="$out$1"; i=$((i + 1)); done
    printf '%s' "$out"
}

HEAVY=$(rep '━' 60)

section() {
    local fill=$((55 - ${#1}))
    [ "$fill" -lt 3 ] && fill=3
    printf '\n%s─── %s %s%s\n' "$C_HEAD" "$1" "$(rep '─' "$fill")" "$C_OFF"
}

say_ok()   { printf '%s✓%s %s\n' "$C_OK" "$C_OFF" "$*"; }
say_warn() { printf '%s⚠%s %s\n' "$C_WARN" "$C_OFF" "$*"; }
say_bad()  { printf '%s✗%s %s\n' "$C_BAD" "$C_OFF" "$*"; }
say()      { printf '• %s\n' "$*"; }
note()     { printf '  ▸ %s\n' "$*"; }
would()    { printf '  → would run: %s\n' "$*"; }
cont()     { printf '    %s\n' "$*"; }   # a bullet's second line

# Print the command (home as ~, wrapped to 60 columns), then run it.
run() {
    local a shown=()
    for a in "$@"; do shown[${#shown[@]}]=$(tilde "$a"); done
    echo_cmd "→" "${shown[@]}"
    "$@"
}

tilde() {
    case "$1" in
        "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;;
        *) printf '%s' "$1" ;;
    esac
}

# Words, wrapped under a bullet so no line passes 60 columns.
wrap_words() {
    [ -n "$(printf '%s' "$1" | tr -d '[:space:]')" ] || return 0
    # shellcheck disable=SC2086  # word lists: package names have no spaces
    { printf '%s ' $1; printf '\n'; } | fold -s -w 54 | sed 's/ *$//; s/^/    /'
}

# A long command, echoed as lines of at most 60 columns with \ between
# them, so it still pastes as one command. $1 is the lead-in ("→" or
# "→ would run:"), the rest are the words.
echo_cmd() {
    local lead="$1" line w width=56
    shift
    line="  $lead"
    for w in "$@"; do
        if [ $(( ${#line} + 1 + ${#w} )) -gt "$width" ]; then
            printf '%s \\\n' "$line"
            line="      $w"
        else
            line="$line $w"
        fi
    done
    printf '%s\n' "$line"
}

# Keep a line to 60 columns, marking a cut with …
fit() {
    local s="$1" max="$2"
    if [ "${#s}" -gt "$max" ]; then
        s="${s:0:$((max - 1))}…"
    fi
    printf '%s' "$s"
}

# ── Word-list helpers ───────────────────────────────────────────────────────

# shellcheck disable=SC2086  # deliberate word splitting on package names
count_words() { set -f; set -- $1; set +f; printf '%s' "$#"; }

# Words of $1 that are not in $2.
words_minus() {
    local w b
    b=" $(printf '%s' "$2" | tr '\n' ' ') "
    set -f
    # shellcheck disable=SC2086
    for w in $1; do
        case "$b" in *" $w "*) ;; *) printf '%s\n' "$w" ;; esac
    done
    set +f
}

# Words of $1 that are also in $2.
words_both() {
    local w b
    b=" $(printf '%s' "$2" | tr '\n' ' ') "
    set -f
    # shellcheck disable=SC2086
    for w in $1; do
        case "$b" in *" $w "*) printf '%s\n' "$w" ;; esac
    done
    set +f
}

join_words() { printf '%s' "$1" | tr '\n' ' ' | sed 's/^ *//; s/ *$//; s/  */ /g'; }

# 1 if $1 > $2, as dotted versions (a suffix like -rc1 is ignored).
version_gt() {
    local a1 a2 a3 b1 b2 b3
    IFS=. read -r a1 a2 a3 <<EOF
$1
EOF
    IFS=. read -r b1 b2 b3 <<EOF
$2
EOF
    a1=${a1%%[!0-9]*}; a2=${a2%%[!0-9]*}; a3=${a3%%[!0-9]*}
    b1=${b1%%[!0-9]*}; b2=${b2%%[!0-9]*}; b3=${b3%%[!0-9]*}
    [ "${a1:-0}" -ne "${b1:-0}" ] && { [ "${a1:-0}" -gt "${b1:-0}" ]; return; }
    [ "${a2:-0}" -ne "${b2:-0}" ] && { [ "${a2:-0}" -gt "${b2:-0}" ]; return; }
    [ "${a3:-0}" -gt "${b3:-0}" ]
}

free_gb() {
    local vol="/System/Volumes/Data"
    [ -d "$vol" ] || vol="/"
    df -k "$vol" 2>/dev/null | awk 'NR == 2 { printf "%d", $4 / 1048576 }'
}

# ── Step plumbing ───────────────────────────────────────────────────────────

SUM_G=()
SUM_S=()
SUM_M=()
STEP_G=""
STEP_M=""
ANY_FAIL=0

result() { STEP_G="$1"; shift; STEP_M="$*"; }

record() {
    local n=${#SUM_S[@]}
    SUM_G[n]="$1"; SUM_S[n]="$2"; SUM_M[n]="$3"
    [ "$1" = fail ] && ANY_FAIL=1
    return 0
}

selected() {
    if [ -n "$ONLY" ]; then
        case " $ONLY " in *" $1 "*) ;; *) return 1 ;; esac
    fi
    case " $SKIP " in *" $1 "*) return 1 ;; esac
    return 0
}

opted_in() {
    case "$1" in
        xcode) [ "$OPT_XCODE" = 1 ] ;;
        macos) [ "$OPT_MACOS" = 1 ] ;;
        *) return 0 ;;
    esac
}

needs_sudo() {
    case "$1" in appstore|xcode|macos) return 0 ;; *) return 1 ;; esac
}

print_result() {
    case "$1" in
        ok) say_ok "$2" ;;
        warn) say_warn "$2" ;;
        fail) say_bad "$2" ;;
        flow) printf '→ %s\n' "$2" ;;
        *) say "$2" ;;
    esac
}

# step NAME FUNCTION: run one step unless deselected, and record its line.
step() {
    local name="$1" fn="$2"
    if ! selected "$name"; then
        if [ -n "$ONLY" ]; then record info "$name" "not run (--only)"
        else record info "$name" "skipped (--skip)"; fi
        return 0
    fi
    if ! opted_in "$name"; then
        record info "$name" "not run (opt-in: --$name)"
        return 0
    fi
    if needs_sudo "$name"; then
        if [ "$NO_SUDO" = 1 ]; then
            record info "$name" "not run (--no-sudo)"
            return 0
        fi
        if [ "$DRY_RUN" = 0 ] && [ "$SUDO_OK" != 1 ]; then
            record warn "$name" "skipped: no sudo (password not given)"
            return 0
        fi
    fi
    section "$name"
    STEP_G="fail"
    STEP_M="ended without a result"
    "$fn"
    record "$STEP_G" "$name" "$STEP_M"
    print_result "$STEP_G" "$name — $STEP_M"
}

# ── sudo ────────────────────────────────────────────────────────────────────

SUDO_OK=0
KEEPALIVE_PID=""

sudo_wanted() {
    local s
    for s in brew appstore xcode macos; do
        selected "$s" && opted_in "$s" && return 0
    done
    return 1
}

acquire_sudo() {
    if [ "$DRY_RUN" = 1 ]; then
        say "Dry run: no sudo asked."
        return 0
    fi
    if [ "$NO_SUDO" = 1 ]; then
        say "--no-sudo: nothing in this run uses sudo."
        return 0
    fi
    [ "$SUDO_OK" = 1 ] && return 0
    if ! sudo_wanted; then
        say "No chosen step needs sudo."
        return 0
    fi
    say "sudo, once, for the App Store and any cask that needs it:"
    if sudo -v; then
        SUDO_OK=1
        # Refresh the timestamp until the script ends. It stops by itself
        # when this script's process is gone, and the EXIT trap kills it.
        (
            while kill -0 "$TOP_PID" 2>/dev/null; do
                sudo -n -v 2>/dev/null || exit 0
                sleep 50
            done
        ) >/dev/null 2>&1 &
        KEEPALIVE_PID=$!
        say_ok "sudo is kept warm until the script ends"
    else
        say_warn "No sudo: appstore, xcode and macos will be skipped"
    fi
}

cleanup() {
    if [ -n "$KEEPALIVE_PID" ]; then
        kill "$KEEPALIVE_PID" 2>/dev/null
    fi
}

# ── 1 preflight ─────────────────────────────────────────────────────────────

COMPUTER=""
FILEVAULT="unknown"

step_preflight() {
    local os build arch free batt power pct
    os=$(sw_vers -productVersion 2>/dev/null)
    build=$(sw_vers -buildVersion 2>/dev/null)
    arch=$(uname -m)
    free=$(free_gb)
    say "Mac: $COMPUTER"
    say "macOS $os ($build), $arch"
    say "Free on /System/Volumes/Data: ${free:-?} GB"

    batt=$(pmset -g batt 2>/dev/null)
    case "$batt" in
        *"AC Power"*)
            power="on AC"
            say "Power: AC" ;;
        *"Battery Power"*)
            pct=$(printf '%s\n' "$batt" | grep -oE '[0-9]+%' | head -1)
            power="on battery ${pct:-}"
            say_warn "On battery (${pct:-?}): plug in before a long run" ;;
        *)
            power="power unknown"
            say "Power: unknown" ;;
    esac

    case "$(fdesetup status 2>/dev/null)" in
        *"FileVault is On"*) FILEVAULT="on" ;;
        *"FileVault is Off"*) FILEVAULT="off" ;;
    esac
    say "FileVault: $FILEVAULT"

    if [ -n "${CLAUDECODE:-}" ]; then
        say_warn "Running inside a Claude chat: sudo can't ask here."
        note "Run it in a terminal, or pass --no-sudo."
    fi

    acquire_sudo

    local msg="${free:-?} GB free, $power, FileVault $FILEVAULT"
    if [ "${free:-0}" -lt 20 ] 2>/dev/null; then
        result warn "$msg (low disk)"
    elif [ "$DRY_RUN" = 0 ] && [ "$NO_SUDO" = 0 ] && [ "$SUDO_OK" != 1 ] && sudo_wanted; then
        result warn "$msg; no sudo"
    else
        result ok "$msg"
    fi
}

# ── 2 repos ─────────────────────────────────────────────────────────────────

REPO_PULLED=""
REPO_CURRENT=""
REPO_UNPUSHED=""
REPO_WARNS=""

repo_warn() {
    say_warn "$1"
    REPO_WARNS="$REPO_WARNS; $1"
}

# repo_one NAME DIR: fetch, report ahead/behind, fast-forward if it can.
repo_one() {
    local name="$1" dir="$2" branch up counts ahead behind err
    local dirty incoming f hit="" nhit=0
    if ! git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
        repo_warn "$name skipped: no repo at $(tilde "$dir")"
        return 0
    fi
    branch=$(git -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null)
    if [ "$branch" != main ]; then
        repo_warn "$name skipped: not on main (on ${branch:-a detached HEAD})"
        return 0
    fi
    if git -C "$dir" rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
        repo_warn "$name skipped: a merge is in progress"
        return 0
    fi
    if ! up=$(git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null); then
        repo_warn "$name skipped: main has no upstream"
        return 0
    fi
    printf '  → git -C %s fetch\n' "$(tilde "$dir")"
    if ! err=$(git -C "$dir" fetch --quiet 2>&1); then
        repo_warn "$name skipped: fetch failed ($(printf '%s' "$err" | head -1))"
        return 0
    fi
    counts=$(git -C "$dir" rev-list --left-right --count "HEAD...$up" 2>/dev/null)
    ahead=$(printf '%s' "$counts" | awk '{print $1}')
    behind=$(printf '%s' "$counts" | awk '{print $2}')
    say "$name: main is $ahead ahead, $behind behind $up"

    if [ "${behind:-0}" -eq 0 ]; then
        if [ "${ahead:-0}" -gt 0 ]; then
            say_ok "$name: nothing to pull ($ahead unpushed)"
            REPO_UNPUSHED="$REPO_UNPUSHED, $name $ahead unpushed"
        else
            say_ok "$name: up to date"
            REPO_CURRENT="$REPO_CURRENT, $name"
        fi
        return 0
    fi
    if [ "${ahead:-0}" -gt 0 ]; then
        repo_warn "$name skipped: diverged ($ahead ahead, $behind behind)"
        return 0
    fi

    # A dirty tree is fine unless the pull would touch a changed file.
    dirty=$(git -C "$dir" status --porcelain --untracked-files=all 2>/dev/null \
        | cut -c4- | sed 's/^.* -> //; s/^"//; s/"$//')
    incoming=$(git -C "$dir" diff --name-only HEAD "$up" 2>/dev/null)
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        if printf '%s\n' "$incoming" | grep -Fxq -- "$f"; then
            nhit=$((nhit + 1))
            [ -n "$hit" ] || hit="$f"
        fi
    done <<EOF
$dirty
EOF
    if [ "$nhit" -gt 0 ]; then
        if [ "$nhit" -gt 1 ]; then hit="$hit and $((nhit - 1)) more"; fi
        repo_warn "$name skipped: your change to $hit is in the way"
        return 0
    fi

    if [ "$DRY_RUN" = 1 ]; then
        would "git -C $(tilde "$dir") pull --ff-only --no-rebase"
        say_ok "$name: would fast-forward $behind commit(s)"
        REPO_PULLED="$REPO_PULLED, $name would pull $behind"
        return 0
    fi
    printf '  → git -C %s pull --ff-only --no-rebase\n' "$(tilde "$dir")"
    if err=$(git -C "$dir" pull --ff-only --no-rebase --quiet 2>&1); then
        say_ok "$name: fast-forwarded $behind commit(s)"
        REPO_PULLED="$REPO_PULLED, $name +$behind"
    else
        repo_warn "$name skipped: pull refused ($(printf '%s' "$err" | grep -v '^hint' | head -1))"
    fi
}

step_repos() {
    local msg=""
    REPO_PULLED=""
    REPO_CURRENT=""
    REPO_UNPUSHED=""
    REPO_WARNS=""
    repo_one chaos "$CHAOS_DIR"
    repo_one .claude "$HOME/.claude"
    repo_one dotfiles "$DOTFILES_DIR"
    if [ -n "$REPO_WARNS" ]; then
        result warn "${REPO_WARNS#; }"
        return 0
    fi
    # e.g. "chaos +3; .claude current; dotfiles 2 unpushed"
    [ -n "$REPO_PULLED" ] && msg="$msg; ${REPO_PULLED#, }"
    [ -n "$REPO_CURRENT" ] && msg="$msg; ${REPO_CURRENT#, } current"
    [ -n "$REPO_UNPUSHED" ] && msg="$msg; ${REPO_UNPUSHED#, }"
    result ok "${msg#; }"
}

# ── 3 brew ──────────────────────────────────────────────────────────────────

brewfile_taps() {
    grep -E '^tap "' "$BREWFILE" 2>/dev/null | sed 's/^tap "//; s/".*//'
}

# Formulae config/Brewfile names that aren't installed at all (one brew
# call; a tap prefix is dropped, as brew list prints short names).
brewfile_missing() {
    local have f
    have=" $(brew list --formula -1 2>/dev/null | tr '\n' ' ') "
    grep -E '^brew "' "$BREWFILE" 2>/dev/null | sed 's/^brew "//; s/".*//' \
        | while IFS= read -r f; do
            [ -n "$f" ] || continue
            case "$have" in *" ${f##*/} "*) ;; *) printf '%s\n' "$f" ;; esac
        done
}

step_brew() {
    local f_before c_all c_list f_after c_after nf nc up_f up_c left missing
    local warns="" bundle_ok=1
    if ! command -v brew >/dev/null 2>&1; then
        result fail "brew not found"
        return 0
    fi
    # Without sudo, a cask that needs it fails instead of stopping the run
    # at a password prompt.
    if [ "$DRY_RUN" = 1 ] || [ "$SUDO_OK" != 1 ]; then
        export HOMEBREW_NO_SUDO=1
    fi
    export HOMEBREW_NO_ENV_HINTS=1

    if [ "$DRY_RUN" = 1 ]; then
        export HOMEBREW_NO_AUTO_UPDATE=1
        would "brew update"
        say "Lists below are as of the last brew update."
        # shellcheck disable=SC2046  # one argument per tap
        echo_cmd "→ would run:" brew trust $(brewfile_taps)
    else
        if ! run brew update; then
            say_warn "brew update failed: upgrading from the index already here"
            warns="$warns; brew update failed"
        fi
        export HOMEBREW_NO_AUTO_UPDATE=1
        # Trust the taps config/Brewfile declares: Homebrew 6+ aborts a
        # whole bundle on one untrusted tap (same loop as update-apps.sh).
        # shellcheck disable=SC2046  # one argument per tap
        echo_cmd "→" brew trust $(brewfile_taps)
        grep -E '^tap "' "$BREWFILE" 2>/dev/null \
          | sed 's/^tap "//; s/".*//' \
          | while IFS= read -r t; do
              [ -n "$t" ] && brew trust "$t" >/dev/null 2>&1 || true
          done
    fi

    f_before=$(brew outdated --formula --quiet 2>/dev/null)
    c_all=$(brew outdated --cask --quiet 2>/dev/null)
    c_list=$(words_minus "$c_all" "claude")
    nf=$(count_words "$f_before")
    nc=$(count_words "$c_list")
    say "$nf formulae outdated"
    wrap_words "$f_before"
    if [ -n "$(words_both "$c_all" claude)" ]; then
        say "$nc apps outdated, not counting claude (held)"
    else
        say "$nc apps outdated"
    fi
    wrap_words "$c_list"

    # Missing, not outdated: `brew bundle check` fails on either, and the
    # upgrade above covers outdated ones.
    missing=$(brewfile_missing)
    if [ -z "$missing" ]; then
        say_ok "Every config/Brewfile tool is installed"
    else
        bundle_ok=0
        say "Missing from config/Brewfile: $(count_words "$missing")"
        wrap_words "$missing"
    fi

    if [ "$DRY_RUN" = 1 ]; then
        [ "$nf" -gt 0 ] && would "brew upgrade --formula"
        # shellcheck disable=SC2086  # one argument per cask
        [ "$nc" -gt 0 ] && echo_cmd "→ would run:" brew upgrade --cask $c_list
        [ "$bundle_ok" = 0 ] && echo_cmd "→ would run:" brew bundle install \
            --file "$(tilde "$BREWFILE")"
        would "brew cleanup"
        if [ "$bundle_ok" = 0 ]; then
            result ok "would upgrade $nf formulae, $nc apps, add $(count_words "$missing")"
        else
            result ok "would upgrade $nf formulae, $nc apps (claude held)"
        fi
        return 0
    fi

    if [ "$nf" -gt 0 ]; then
        run brew upgrade --formula || warns="$warns; brew upgrade --formula failed"
    fi
    if [ "$nc" -gt 0 ]; then
        note "Homebrew quits and reopens a running app it upgrades."
        # shellcheck disable=SC2086  # one argument per cask
        echo_cmd "→" brew upgrade --cask $c_list
        # shellcheck disable=SC2086
        brew upgrade --cask $c_list || warns="$warns; some apps failed"
    fi
    if [ "$bundle_ok" = 0 ]; then
        run brew bundle install --file "$BREWFILE" \
            || warns="$warns; brew bundle install failed"
        missing=$(brewfile_missing)
        [ -z "$missing" ] || warns="$warns; still missing: $(join_words "$missing")"
    fi
    run brew cleanup || warns="$warns; brew cleanup failed"

    f_after=$(brew outdated --formula --quiet 2>/dev/null)
    c_after=$(brew outdated --cask --quiet 2>/dev/null)
    up_f=$(count_words "$(words_minus "$f_before" "$f_after")")
    up_c=$(count_words "$(words_minus "$c_list" "$c_after")")
    left=$(join_words "$(words_both "$f_before $c_list" "$f_after $c_after")")
    if [ -n "$left" ]; then
        say_warn "Still outdated: $left"
        warns="$warns; still outdated: $left"
    fi
    if [ -n "$warns" ]; then
        result warn "$up_f formulae, $up_c apps upgraded${warns}"
    else
        result ok "$up_f formulae, $up_c apps upgraded (claude held)"
    fi
}

# ── 4 claude-code ───────────────────────────────────────────────────────────

claude_bin() {
    if [ -x "$HOME/.local/bin/claude" ]; then
        printf '%s' "$HOME/.local/bin/claude"
    else
        command -v claude 2>/dev/null
    fi
}

step_claude_code() {
    local bin cur new
    bin=$(claude_bin)
    if [ -z "$bin" ]; then
        result warn "claude not found; skipped"
        return 0
    fi
    cur=$("$bin" --version 2>/dev/null | head -1 | awk '{print $1}')
    say "Installed: ${cur:-unknown} ($(tilde "$bin"))"
    note "Running chats keep theirs; new chats get the new one."
    if [ "$DRY_RUN" = 1 ]; then
        would "claude update"
        result ok "would run claude update (now ${cur:-unknown})"
        return 0
    fi
    if ! run "$bin" update </dev/null; then
        result fail "claude update failed (still ${cur:-unknown})"
        return 0
    fi
    new=$("$bin" --version 2>/dev/null | head -1 | awk '{print $1}')
    if [ -n "$new" ] && [ "$new" != "$cur" ]; then
        printf '→ In a new chat, check the hey gate still denies:\n'
        note "chaos technical/hey-cli-reference.md, §Install"
        cont "and upgrade, \"After a Claude Code upgrade\""
        result ok "$cur → $new (new chats only)"
    else
        result ok "already the latest (${cur:-unknown})"
    fi
}

# ── 5 uv ────────────────────────────────────────────────────────────────────

uv_tools() {
    uv tool list 2>/dev/null | grep -v '^-' | grep -v '^$'
}

step_uv() {
    local before after n changed=0 line nl
    if ! command -v uv >/dev/null 2>&1; then
        result info "uv not installed"
        return 0
    fi
    before=$(uv_tools)
    n=$(printf '%s\n' "$before" | grep -c .)
    if [ "$n" -eq 0 ]; then
        result ok "no uv tools installed"
        return 0
    fi
    say "$n tool(s):"
    printf '%s\n' "$before" | sed 's/^/    /'
    if [ "$DRY_RUN" = 1 ]; then
        would "uv tool upgrade --all"
        result ok "would upgrade $n tool(s)"
        return 0
    fi
    if ! run uv tool upgrade --all; then
        result fail "uv tool upgrade --all failed"
        return 0
    fi
    after=$(uv_tools)
    nl='
'
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        case "$nl$before$nl" in *"$nl$line$nl"*) ;; *) changed=$((changed + 1)) ;; esac
    done <<EOF
$after
EOF
    result ok "$changed of $n tool(s) upgraded"
}

# ── 6 hey ───────────────────────────────────────────────────────────────────
#
# The steps and checks are chaos technical/2026-11-12-hey-upgrade-plan.md
# (§The steps, per Mac) and technical/hey-cli-reference.md (§Install and
# upgrade). Only the reads are here. The plan's other after-steps send,
# write or need a Claude chat, and are printed as the next step instead.

HEY_FAILED=""
HEY_OUT=""

# hey_read ARGS...: run a read, show only its line count. The output (mail
# boxes, drafts, events) stays out of the log.
hey_read() {
    local rc
    HEY_OUT=$("$HEY_BIN" "$@" 2>&1)
    rc=$?
    if [ "$rc" -ne 0 ]; then
        say_bad "hey $* exited $rc"
        printf '%s\n' "$HEY_OUT" | tail -3 | sed 's/^/    /'
        HEY_FAILED="hey $* exited $rc"
        return 1
    fi
    say_ok "hey $* ($(printf '%s\n' "$HEY_OUT" | grep -c .) lines)"
}

hey_after_checks() {
    local out rc suite_log
    # Plan step 4.
    out=$("$HEY_BIN" --version 2>/dev/null | head -1)
    if [ "$out" != "hey version $HEY_PIN" ]; then
        HEY_FAILED="hey --version said: $out"
        say_bad "$HEY_FAILED"
        return 1
    fi
    say_ok "hey --version: $out"

    # Plan step 5: the flag check (runs `hey help …` and `hey version` only).
    printf '  → python3 tools/hey/flag-check.py\n'
    python3 "$CHAOS_DIR/tools/hey/flag-check.py"
    rc=$?
    if [ "$rc" -ne 0 ]; then
        HEY_FAILED="flag-check.py exited $rc"
        say_bad "$HEY_FAILED"
        note "A ⚠ line: save no draft and edit no event until"
        cont "it is settled (plan step 5)."
        return 1
    fi
    say_ok "flag-check.py: nothing the gate would misread"

    # Plan step 6: reads.
    hey_read box list || return 1
    hey_read draft list || return 1
    hey_read calendar list --json || return 1
    hey_read event list --calendar "$HEY_CAL" --json || return 1
    hey_read auth status || return 1
    note "auth status on hey mcp (expect: not signed in):"
    printf '%s\n' "$HEY_OUT" | grep -i 'mcp' | sed 's/^/    /'

    # The reference's after-check: the gate's own suite. It runs the gate
    # on test strings against a stub hey, never the real one.
    suite_log="${LOG%.log}-hey-gate-suite.log"
    printf '  → bash tools/hey/hey-gate.test.sh (2 to 3 min)\n'
    bash "$CHAOS_DIR/tools/hey/hey-gate.test.sh" >"$suite_log" 2>&1
    rc=$?
    grep -E '(✓|✗) [0-9]+ passed' "$suite_log" | tail -1 | sed 's/^/    /'
    note "Full output: $(tilde "$suite_log")"
    if [ "$rc" -ne 0 ]; then
        HEY_FAILED="the gate suite failed"
        say_bad "$HEY_FAILED"
        return 1
    fi
    say_ok "The gate suite passed"
}

step_hey() {
    local cur backup gate h1 h2
    if [ ! -x "$HEY_BIN" ]; then
        result warn "skipped: no hey at ~/.local/bin/hey"
        return 0
    fi
    cur=$("$HEY_BIN" --version 2>/dev/null | head -1 | awk '{print $NF}')
    say "Installed: ${cur:-unknown}; pinned target: $HEY_PIN"
    if [ "$cur" = "$HEY_PIN" ]; then
        result ok "already $HEY_PIN"
        return 0
    fi
    if [ -z "$cur" ]; then
        result fail "hey --version gave nothing; not upgrading"
        return 0
    fi
    if version_gt "$cur" "$HEY_PIN"; then
        result warn "$cur is past the pin $HEY_PIN; left alone"
        return 0
    fi

    # Plan step 1, the gate first: the old gate with the new binary would
    # leave `hey auth login --mcp` open to Claude.
    gate="$CHAOS_DIR/tools/hey/hey-gate.py"
    if ! grep -qE '^HARD_DENIED_VERBS = .*"mcp"' "$gate" 2>/dev/null \
        || [ ! -f "$CHAOS_DIR/tools/hey/flag-check.py" ]; then
        result warn "skipped: chaos's gate isn't readied for $HEY_PIN (PR #189)"
        return 0
    fi
    say_ok "chaos's send gate is readied for $HEY_PIN"
    note "No /triage-emails round should be open on either Mac."

    backup="$HOME/.local/bin/hey.backup-v$cur"
    if [ "$DRY_RUN" = 1 ]; then
        if [ -e "$backup" ]; then
            say "A backup is already there: $(tilde "$backup")"
        else
            echo_cmd "→ would run:" cp -p "$(tilde "$HEY_BIN")" "$(tilde "$backup")"
        fi
        would "hey upgrade $HEY_PIN"
        say "Then, stopping at the first failure:"
        note "plan step 4: hey --version says $HEY_PIN"
        note "plan step 5: python3 tools/hey/flag-check.py"
        note "plan step 6: hey box list, hey draft list,"
        cont "hey calendar list --json, hey event list"
        cont "--calendar $HEY_CAL --json, hey auth status"
        note "reference: bash tools/hey/hey-gate.test.sh"
        result ok "would back up, then upgrade $cur → $HEY_PIN"
        return 0
    fi

    # Plan step 2: back up, and check the copy hashes the same.
    if [ -e "$backup" ]; then
        h1=$(shasum -a 256 "$HEY_BIN" | awk '{print $1}')
        h2=$(shasum -a 256 "$backup" | awk '{print $1}')
        if [ "$h1" != "$h2" ]; then
            result warn "skipped: $(tilde "$backup") exists and differs"
            return 0
        fi
        say_ok "Backup already there: $(tilde "$backup")"
    else
        run cp -p "$HEY_BIN" "$backup" || {
            result fail "backup failed; hey not upgraded"
            return 0
        }
        h1=$(shasum -a 256 "$HEY_BIN" | awk '{print $1}')
        h2=$(shasum -a 256 "$backup" | awk '{print $1}')
        if [ -z "$h1" ] || [ "$h1" != "$h2" ]; then
            result fail "backup doesn't match the binary; hey not upgraded"
            return 0
        fi
        say_ok "Backed up to $(tilde "$backup") (same sha256)"
    fi

    # Plan step 3.
    if ! run "$HEY_BIN" upgrade "$HEY_PIN" </dev/null; then
        say_bad "hey upgrade failed"
        note "Roll back:"
        cont "cp -p $(tilde "$backup") ~/.local/bin/hey"
        result fail "upgrade failed, backup at $(tilde "$backup")"
        return 0
    fi

    # Plan steps 4 to 6, then the reference's gate suite.
    HEY_FAILED=""
    if ! hey_after_checks; then
        say_bad "Stopped at: $HEY_FAILED"
        note "Roll back (plan, UNDO), then hey --version says $cur:"
        cont "cp -p $(tilde "$backup") ~/.local/bin/hey"
        result fail "$HEY_FAILED; backup at $(tilde "$backup")"
        return 0
    fi
    printf '→ Next, in a Claude chat: plan steps 7 to 11\n'
    note "chaos technical/2026-11-12-hey-upgrade-plan.md"
    result ok "$cur → $HEY_PIN, checks passed; backup kept"
}

# ── 7 appstore ──────────────────────────────────────────────────────────────

step_appstore() {
    local list out ids names n
    if ! command -v mas >/dev/null 2>&1; then
        result warn "skipped: mas not installed (it is in config/Brewfile)"
        return 0
    fi
    export MAS_NO_AUTO_INDEX=1
    # mas finds installed apps through Spotlight. With none found, outdated
    # prints nothing at all, so ask list first.
    list=$(mas list 2>&1)
    if printf '%s' "$list" | grep -q 'No installed apps found'; then
        say_warn "mas sees no App Store apps: Spotlight lists none"
        note "Try by hand: mdimport /Applications"
        note "Or update from the App Store app."
        result warn "mas sees no App Store apps; nothing to do"
        return 0
    fi
    out=$(mas outdated 2>&1)
    # Xcode belongs to the xcode step, which is opt-in.
    ids=$(printf '%s\n' "$out" | awk -v x="$XCODE_ID" '$1 ~ /^[0-9]+$/ && $1 != x {print $1}')
    names=$(printf '%s\n' "$out" | awk -v x="$XCODE_ID" '$1 ~ /^[0-9]+$/ && $1 != x {$1=""; sub(/^ +/, ""); print}')
    n=$(count_words "$ids")
    if printf '%s\n' "$out" | awk '{print $1}' | grep -qx "$XCODE_ID"; then
        note "Xcode is outdated too: left to --xcode"
    fi
    if [ "$n" -eq 0 ]; then
        result ok "nothing outdated"
        return 0
    fi
    say "$n app(s) outdated:"
    printf '%s\n' "$names" | sed 's/^/    /'
    if [ "$DRY_RUN" = 1 ]; then
        would "mas upgrade $(join_words "$ids")"
        result ok "would upgrade $n app(s)"
        return 0
    fi
    # shellcheck disable=SC2086  # one argument per app id
    if run mas upgrade $ids; then
        result ok "$n app(s) upgraded"
    else
        result warn "mas upgrade failed (signed in to the App Store?)"
    fi
}

# ── 8 xcode (opt-in) ────────────────────────────────────────────────────────

step_xcode() {
    local before after xb="$XCODE_APP/Contents/Developer/usr/bin/xcodebuild"
    local xb_short="$XCODE_APP/…/xcodebuild"
    if ! command -v mas >/dev/null 2>&1; then
        result fail "mas not installed"
        return 0
    fi
    export MAS_NO_AUTO_INDEX=1
    before=$(free_gb)
    say "Free before: ${before:-?} GB"
    if [ "${before:-0}" -lt 40 ] 2>/dev/null; then
        say_warn "Only ${before} GB free: Xcode can need tens of GB"
    fi
    if [ ! -d "$XCODE_APP" ]; then
        say "Xcode.app is not installed"
        # The full path: xcodebuild on PATH follows xcode-select, which
        # points elsewhere, and would accept that one's licence instead.
        # The echo elides the middle of the path to stay in 60 columns.
        note "xcodebuild below is Xcode.app's own (its full path)"
        if [ "$DRY_RUN" = 1 ]; then
            would "mas install $XCODE_ID"
            echo_cmd "→ would run:" sudo "$xb_short" -license accept
            echo_cmd "→ would run:" sudo "$xb_short" -runFirstLaunch
            result ok "would install Xcode ($before GB free)"
        else
            if ! run mas install "$XCODE_ID"; then
                result fail "mas install failed (signed in to the App Store?)"
                return 0
            fi
            echo_cmd "→" sudo "$xb_short" -license accept
            sudo "$xb" -license accept || say_warn "license accept failed"
            echo_cmd "→" sudo "$xb_short" -runFirstLaunch
            sudo "$xb" -runFirstLaunch || say_warn "-runFirstLaunch failed"
            after=$(free_gb)
            say "Free after: ${after:-?} GB"
            result ok "Xcode installed; ${before} → ${after} GB free"
        fi
    else
        say "Xcode.app is installed"
        if [ "$DRY_RUN" = 1 ]; then
            would "mas upgrade $XCODE_ID"
            result ok "would upgrade Xcode if outdated ($before GB free)"
        else
            if run mas upgrade "$XCODE_ID"; then
                after=$(free_gb)
                say "Free after: ${after:-?} GB"
                result ok "Xcode upgraded or current; ${before} → ${after} GB free"
            else
                result fail "mas upgrade $XCODE_ID failed"
            fi
        fi
    fi
    say "xcode-select stays: $(xcode-select -p 2>/dev/null)"
    note "To switch: sudo xcode-select -s $XCODE_APP"
}

# ── 10 final: the claude cask ───────────────────────────────────────────────

step_final() {
    local ver
    if ! command -v brew >/dev/null 2>&1; then
        result info "brew not found; nothing to do"
        return 0
    fi
    if ! brew list --cask claude >/dev/null 2>&1; then
        result info "claude cask not installed"
        return 0
    fi
    if ! HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --cask --quiet claude 2>/dev/null | grep -qx claude; then
        result ok "Claude app up to date"
        return 0
    fi
    # "claude (1.2.3,hash) != 1.2.4,hash" → "1.2.3 → 1.2.4"
    ver=$(HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --cask --verbose claude 2>/dev/null \
        | head -1 | sed -E 's/^[^(]*\(([^,)]*)[^)]*\) != ([^,]*).*/\1 → \2/')
    say "Claude app update waiting: $ver"
    if [ "$OPT_CLAUDE_APP" != 1 ]; then
        say "When no chat needs this Mac, run:"
        note "brew upgrade --cask claude"
        result info "Claude app waiting: brew upgrade --cask claude"
        return 0
    fi
    say_warn "This quits the Claude desktop app."
    note "Every chat on this Mac ends, Remote Control too."
    if [ "$DRY_RUN" = 1 ]; then
        would "brew upgrade --cask claude"
        result ok "would upgrade the Claude app (ends chats)"
        return 0
    fi
    if run brew upgrade --cask claude; then
        result ok "Claude app upgraded; reopen it"
    else
        result fail "brew upgrade --cask claude failed"
    fi
}

# ── 11 macos (opt-in) ───────────────────────────────────────────────────────

MACOS_GO=0

step_macos() {
    local list items label size action gb answer first=""
    printf '  → softwareupdate -l\n'
    list=$(softwareupdate -l 2>&1)
    items=$(printf '%s\n' "$list" | awk '
        /^\* Label: / { lab = substr($0, 10); next }
        lab != "" && /Title:/ {
            size = ""; act = ""
            n = split($0, f, ", ")
            for (i = 1; i <= n; i++) {
                if (f[i] ~ /^Size: /) size = substr(f[i], 7)
                if (f[i] ~ /^Action: /) act = substr(f[i], 9)
            }
            print lab "|" size "|" act
            lab = ""
        }')
    if [ -z "$items" ]; then
        result ok "no macOS update offered"
        return 0
    fi
    while IFS='|' read -r label size action; do
        [ -n "$label" ] || continue
        [ -n "$first" ] || first="$label"
        gb=$(printf '%s' "$size" | sed 's/KiB$//' | awk '{ if ($1 + 0 > 0) printf "%.1f GB", $1 / 1048576; else print "size unknown" }')
        say "$label"
        note "$gb ($size), action: ${action:-none}"
    done <<EOF
$items
EOF
    if [ "$DRY_RUN" = 1 ]; then
        say "Would ask you to type restart, then:"
        would "sudo softwareupdate --install --all --restart"
        result ok "would offer $first"
        return 0
    fi

    say_warn "This installs the update above and RESTARTS the Mac."
    if [ "$FILEVAULT" != off ]; then
        note "FileVault is on: someone must be at the Mac to"
        cont "unlock it after the restart, unless macOS unlocks"
        cont "it by itself."
    fi
    note "Every Claude chat running on this Mac loses its"
    cont "process."
    note "Apple silicon may ask for your password again."
    printf 'Type restart to go ahead (anything else skips): '
    answer=""
    if ! read -r answer </dev/tty 2>/dev/null; then
        answer=""
        printf '\n'
    fi
    if [ "$answer" = restart ]; then
        MACOS_GO=1
        result flow "installing $first, then a restart"
    else
        result warn "skipped: restart was not typed"
    fi
}

macos_install() {
    printf '\n'
    say "Installing. The Mac restarts by itself when it's done."
    printf '  → sudo softwareupdate --install --all --restart\n'
    sudo softwareupdate --install --all --restart
    local rc=$?
    if [ "$rc" -ne 0 ]; then
        say_bad "macos — softwareupdate exited $rc; no restart"
        ANY_FAIL=1
    else
        say_warn "macos — softwareupdate returned without a restart"
    fi
}

# ── Summary ─────────────────────────────────────────────────────────────────

print_summary() {
    local i=0 g c line
    printf '\n%s\n' "$HEAVY"
    if [ "$DRY_RUN" = 1 ]; then
        printf '%sSUMMARY%s (dry run: nothing changed)\n' "$C_HEAD" "$C_OFF"
    else
        printf '%sSUMMARY%s\n' "$C_HEAD" "$C_OFF"
    fi
    while [ "$i" -lt "${#SUM_S[@]}" ]; do
        case "${SUM_G[$i]}" in
            ok) g="✓"; c="$C_OK" ;;
            warn) g="⚠"; c="$C_WARN" ;;
            fail) g="✗"; c="$C_BAD" ;;
            flow) g="→"; c="" ;;
            *) g="•"; c="" ;;
        esac
        line=$(fit "${SUM_S[$i]} — ${SUM_M[$i]}" 58)
        printf '%s%s%s %s\n' "$c" "$g" "$C_OFF" "$line"
        i=$((i + 1))
    done
    printf '%s\n' "$HEAVY"
    printf '→ Health check, by hand: sh ~/dotfiles/scripts/doctor.sh\n'
    printf 'Log: %s\n' "$(tilde "$LOG")"
}

# ── Main ────────────────────────────────────────────────────────────────────

main() {
    trap cleanup EXIT
    trap 'exit 130' INT TERM

    printf '%s\n' "$HEAVY"
    printf '%supdate-mac%s — %s\n' "$C_HEAD" "$C_OFF" "$COMPUTER"
    printf '%s\n' "$(date '+%a %Y-%m-%d %H:%M')"
    if [ "$DRY_RUN" = 1 ]; then
        printf 'DRY RUN: reads only, nothing changes\n'
    fi
    printf '%s\n' "$HEAVY"

    step preflight step_preflight
    if ! selected preflight; then
        acquire_sudo
    fi
    step repos step_repos
    step brew step_brew
    step claude-code step_claude_code
    step uv step_uv
    step hey step_hey
    step appstore step_appstore
    step xcode step_xcode
    step final step_final
    step macos step_macos

    # The summary prints before a macOS install: the restart ends the run.
    print_summary
    if [ "$MACOS_GO" = 1 ]; then
        macos_install
    fi
    [ "$ANY_FAIL" = 0 ]
}

# main runs in a ( ) subshell: bash 3.2 runs a pipeline function's EXIT
# trap (which stops the sudo keepalive) only in an explicit subshell.
start() {
    local rc
    parse_args "$@"
    setup_colour
    TOP_PID=$$
    COMPUTER=$(scutil --get ComputerName 2>/dev/null || hostname -s)
    mkdir -p "$LOG_DIR" || exit 1
    LOG="$LOG_DIR/$(date +%Y-%m-%d-%H%M).log"
    if [ "$USE_COLOUR" = 1 ]; then
        # The terminal gets colour; the log gets the same lines without it.
        # sed -l: line-buffered, so the log is whole even if a macOS
        # install restarts the Mac.
        (main) 2>&1 | tee /dev/tty | sed -l "s/${ESC}\\[[0-9;]*m//g" >>"$LOG"
        rc=${PIPESTATUS[0]}
    else
        (main) 2>&1 | tee -a "$LOG"
        rc=${PIPESTATUS[0]}
    fi
    return "$rc"
}

start "$@"; exit $?
