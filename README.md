# Hourly notify (dkoropenko.hourly-notify)

[Russian Documentation](https://github.com/dkoropenko/hourly_notify/blob/main/README_RU.md)

Omarchy shell plugin: emits an audio notify every hour on the hour (:00) and provides a visual interface for configuration.

- **id:** `dkoropenko.hourly-notify`
- **types:** `service`, `bar-widget`
- **location:** `~/.config/omarchy/plugins/dkoropenko.hourly-notify/`
- **version:** 1.0.0

## Files

| File | Purpose |
|------|---------|
| `manifest.json` | Plugin manifest: id, types, entry points, settings schema |
| `Service.qml` | Singleton service: timer for the exact hour and sound playback |
| `BarWidget.qml` | Bell icon in the bar; stores settings in `shell.json` |
| `Panel.qml` | Settings panel (opened by clicking the icon) |

## How It Works

The hourly logic is implemented in a `service` singleton, so the notify triggers exactly once, even if the bar is rendered on multiple monitors. The timer is set to the next exact hour (not “one hour after startup”) and recalculated after each trigger based on the system clock. If a notify is missed due to the computer being asleep, a false trigger upon waking is suppressed, and the timer is realigned to the next :00 mark.

The sound is played using the command:

```
pw-play --volume <level> <file>
```

The `--volume` option sets the volume for the notify’s audio stream only — this is independent of the system volume slider. The `LC_ALL=C` environment variable is explicitly set to ensure that the decimal point in `--volume` is interpreted correctly, regardless of locale (on this machine, `LC_NUMERIC` uses a comma by default).

Settings are stored in the bar widget entry in `~/.config/omarchy/shell.json`:

```json
{ "id": "dkoropenko.hourly-notify", "enabled": true, "sound": "/usr/share/sounds/freedesktop/stereo/complete.oga", "volume": 0.6 }
```

## Interface

Opened by clicking the bell icon on the right side of the bar. The icon changes to a crossed-out bell when the notification is disabled.

- Toggle switch for enabling/disabling the notify.
- Sound selection — a list of all files from `/usr/share/sounds`, `~/.local/share/sounds`, and `~/.config/omarchy/sounds` (extensions: `.oga`, `.ogg`, `.wav`, `.flac`, `.mp3`).
- Volume slider for the notify (0–100%), independent of the system volume.
- “Test notify” button.

Keyboard controls: `j`/`k` or arrow keys — navigate elements, `h`/`l` — adjust volume, `Enter`/`Space` — perform action, `t` — test notify, `Esc` — close. While the sound list is open, keyboard focus moves to it.

## Control via Scripts and Keybindings

IPC target for the plugin is `dkoropenko.hourly-notify`:

```bash
omarchy-shell dkoropenko.hourly-notify togglenotify          # toggle enable/disable
omarchy-shell dkoropenko.hourly-notify setEnabled true      # enable (true|1)
omarchy-shell dkoropenko.hourly-notify setEnabled false     # disable
omarchy-shell dkoropenko.hourly-notify setVolume 60         # set volume in percent (0–100)
omarchy-shell dkoropenko.hourly-notify setSound /path/to.oga
omarchy-shell dkoropenko.hourly-notify notify                # play notify once
omarchy-shell dkoropenko.hourly-notify open                 # open settings panel
omarchy-shell dkoropenko.hourly-notify close
omarchy-shell dkoropenko.hourly-notify toggle
```

To assign to keyboard shortcuts in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + C", "Hourly notify", "omarchy-shell dkoropenko.hourly-notify togglenotify")
```

## Installation and Activation

```bash
omarchy-shell shell rescanPlugins
omarchy plugin enable dkoropenko.hourly-notify --section right
```

To disable: `omarchy plugin disable dkoropenko.hourly-notify`.
Plugin file edits are picked up automatically; if needed, run `omarchy-shell shell rescanPlugins`. Changing IPC handler environments requires `omarchy restart shell`.

## Dependencies

- `pw-play` (PipeWire) — for audio playback;
- `find` (GNU findutils) — to locate available sound files.

## Note on Volume

The slider controls the notify’s own stream volume, separate from the system volume slider. However, the sound still goes through the system audio output, so the overall (master) volume and mute settings still affect it. The notify cannot be made completely “above” the system level — that would require a separate audio output (a dedicated sink).
