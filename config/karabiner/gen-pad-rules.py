#!/usr/bin/env python3
"""Writes the ZXW macropad rules into the selected Karabiner profile.

The pad (USB 5566:0008) is stock firmware, so the Mac does the thinking:
  K1 refresh the desk panel   K2 capture to _inbox.md   K3 dictate Opt+/
  K4 cancel Opt+Esc           K5 Enter            knob = volume + play/pause (native)

Idempotent: rules whose description contains "ZXW pad" are dropped and re-added,
other rules are left alone. A backup of karabiner.json is taken before any write.

  gen-pad-rules.py          write the rules (backs up first, skips if unchanged)
  gen-pad-rules.py --print  print the rules only
  gen-pad-rules.py --lint   run karabiner_cli --lint-complex-modifications on them

Two traps this file exists to remember:
  * The pad enumerates as TWO Karabiner devices (keyboard-only: K1 K2 K5;
    keyboard+pointing: K3 K4 knob). Karabiner ignores keyboard+pointing devices by
    default, so the profile needs `devices` entries with ignore:false for both or
    K3/K4 leak as raw Previous/Next Track.
  * A from-event with no `optional` modifiers stops matching the moment any other
    modifier is down (Shift on the main keyboard, Caps Lock on) and the pad's raw
    Ctrl+C / Cmd+C / Previous Track goes through instead. So every from carries
    `optional`: `any` on K1 and K2, whose outputs ignore modifiers (a shell
    command), and only `caps_lock` on K3 and K4, whose outputs are key chords
    that a carried-over Shift or Cmd would corrupt. K5 is Enter, which a carried-
    over Shift or Cmd would also corrupt (Shift+Enter, Cmd+Enter), yet its raw
    Cmd+D is a live shortcut, so it gets two manipulators: Return with only
    `caps_lock` optional, then a catch-all on `any` that swallows the key
    (vk_none), so a modifier that Karabiner can see (from any other grabbed
    keyboard) makes K5 do nothing rather than the wrong thing. It cannot see the
    Magic Keyboard, which is ignored below, so Shift or left-Cmd held there still
    gives a plain Return (measured 2026-10-01, event flags empty). A LEFT Cmd from
    a grabbed keyboard would be indistinguishable from the pad's own.
    check_optional() enforces it for any later edit.
  * Karabiner grabs every keyboard, and a grabbed keyboard bypasses macOS's own
    per-device Modifier Keys, which is where Martin's Magic Keyboard caps lock ->
    Esc lives (`alt_handler_id-106` in `defaults -currentHost read -g`). The
    profile therefore carries an `ignore: true` entry for that keyboard, so
    Karabiner touches only the pad and macOS keeps doing the mapping itself.
  * Holding K1 flips a firmware layer (Ctrl becomes Cmd on K1 and K2) and fires one
    stray K1 tap. Every K1/K2 rule therefore covers both layers, and K1's action
    must be safe to fire twice.
"""
import json, os, shutil, subprocess, sys, tempfile, time

CFG = os.path.expanduser('~/.config/karabiner/karabiner.json')
CLI = '/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli'
PANEL_REFRESH = os.path.expanduser('~/.bin/chaos-panel-refresh.sh')
CAPTURE = os.path.expanduser('~/.bin/chaos-capture.sh')

PAD = [{"type": "device_if", "identifiers": [{"vendor_id": 21862, "product_id": 8}]}]
# repeat:false on every key output: a held pad key otherwise auto-repeats at about 30 a second
# (measured 2026-10-01: K5 ~85 Returns in 3 s, K3 109 Opt+/ in 3.9 s, which would flip dictation ~110 times)
OPT_SLASH = [{"key_code": "slash", "modifiers": ["left_option"], "repeat": False}]
OPT_ESC = [{"key_code": "escape", "modifiers": ["left_option"], "repeat": False}]
RETURN = [{"key_code": "return_or_enter", "repeat": False}]
NOTHING = [{"key_code": "vk_none"}]
REFRESH = [
    {"set_notification_message": {"id": "zxw-k1", "text": "panel: refreshing…", "duration_milliseconds": 1500}},
    {"shell_command": PANEL_REFRESH},
]
CAPTURE_TO = [{"shell_command": CAPTURE}]


def key_chord(key, mod, to, optional=("any",)):
    return {"type": "basic", "conditions": PAD, "to": to,
            "from": {"key_code": key, "modifiers": {"mandatory": [mod], "optional": list(optional)}}}


def consumer(code, to, optional=("caps_lock",)):
    return {"type": "basic", "conditions": PAD, "to": to,
            "from": {"consumer_key_code": code, "modifiers": {"optional": list(optional)}}}


def both_layers(key, to):
    return [key_chord(key, "left_control", to), key_chord(key, "left_command", to)]


RULES = [
    {"description": "ZXW pad K1: refresh the desk panel (both layers)",
     "manipulators": both_layers("c", REFRESH)},
    {"description": "ZXW pad K2: capture one line to _inbox.md (both layers)",
     "manipulators": both_layers("v", CAPTURE_TO)},
    {"description": "ZXW pad K3: dictate = Opt+/",
     "manipulators": [consumer("scan_previous_track", OPT_SLASH)]},
    {"description": "ZXW pad K4: cancel = Opt+Esc",
     "manipulators": [consumer("scan_next_track", OPT_ESC)]},
    {"description": "ZXW pad K5: enter = Return",
     "manipulators": [key_chord("d", "left_command", RETURN, ("caps_lock",)),
                      key_chord("d", "left_command", NOTHING)]},
]
MARK = "ZXW pad"
MAGIC_KEYBOARD = {"is_keyboard": True, "product_id": 801, "vendor_id": 76}


def pad_devices():
    kb = {"is_keyboard": True, "product_id": 8, "vendor_id": 21862}
    kb_ptr = {"is_keyboard": True, "is_pointing_device": True, "product_id": 8, "vendor_id": 21862}
    return [{"identifiers": kb, "ignore": False}, {"identifiers": kb_ptr, "ignore": False}]


def device_entries():
    return pad_devices() + [{"identifiers": MAGIC_KEYBOARD, "ignore": True}]


def apply(cfg):
    prof = next((p for p in cfg["profiles"] if p.get("selected")), cfg["profiles"][0])
    rules = prof.setdefault("complex_modifications", {}).setdefault("rules", [])
    rules[:] = [r for r in rules if MARK not in r.get("description", "")] + RULES
    devs = prof.setdefault("devices", [])
    wanted = device_entries()
    devs[:] = [d for d in devs if d.get("identifiers") not in [w["identifiers"] for w in wanted]] + wanted
    return prof


def check_optional():
    bad = [r["description"] for r in RULES for m in r["manipulators"]
           if not m["from"].get("modifiers", {}).get("optional")]
    if bad:
        sys.exit(f"pad rules without `optional` modifiers (raw keys leak under Shift/Caps Lock): {sorted(set(bad))}")


def lint():
    check_optional()
    if not os.path.exists(CLI):
        sys.exit(f"no {CLI}: Karabiner-Elements is not installed here")
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump({"title": "ZXW pad", "rules": RULES}, f)
        path = f.name
    try:
        r = subprocess.run([CLI, "--lint-complex-modifications", path], capture_output=True, text=True)
        print((r.stdout + r.stderr).strip())
        return r.returncode
    finally:
        os.unlink(path)


def main():
    if not os.path.exists(CFG):
        sys.exit(f"no {CFG}: launch Karabiner-Elements once first")
    check_optional()
    with open(CFG) as f:
        cfg = json.load(f)
    before = json.dumps(cfg, sort_keys=True)
    prof = apply(cfg)
    if json.dumps(cfg, sort_keys=True) == before:
        print(f"unchanged: profile '{prof['name']}' already has the {len(RULES)} pad rules")
        return
    backup = f"{CFG}.bak-{int(time.time())}"
    shutil.copy2(CFG, backup)
    mode = os.stat(CFG).st_mode & 0o777
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(CFG), prefix=".karabiner.json.")
    with os.fdopen(fd, "w") as f:
        json.dump(cfg, f, indent=2)
    os.chmod(tmp, mode)
    os.replace(tmp, CFG)
    print(f"wrote {len(RULES)} rules to profile '{prof['name']}' (backup {backup})")


if __name__ == "__main__":
    if "--print" in sys.argv:
        print(json.dumps(RULES, indent=1))
    elif "--lint" in sys.argv:
        sys.exit(lint())
    else:
        main()
