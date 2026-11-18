import QtQuick
import Quickshell
import Quickshell.Io

// Headless singleton for the hourly chime. One instance lives for the whole
// shell session regardless of how many bars/monitors render the widget.
//
// The bar widget mirrors its shell.json entry into `enabled`, `soundPath` and
// `volume`; this object owns the timer and the actual playback so the chime
// fires exactly once no matter how many monitor bars exist.
Item {
  id: root

  // Injected by the shell host.
  property QtObject shell: null

  // Runtime state, mirrored from the widget's shell.json entry.
  property bool enabled: false
  property string soundPath: ""
  property real volume: 0.6

  readonly property string defaultSound: "/usr/share/sounds/freedesktop/stereo/complete.oga"
  readonly property string effectiveSound: soundPath !== "" ? soundPath : defaultSound

  // Every playable file discovered under the standard sound directories.
  // [{ value: absolutePath, label: friendlyName, description: path }]
  property var soundOptions: []

  function play(path) {
    if (!path || path === "") return
    var level = Math.max(0, Math.min(1, volume))
    player.command = ["pw-play", "--volume", level.toFixed(3), path]
    if (player.running) player.running = false
    player.running = true
  }

  function chime() {
    play(effectiveSound)
  }

  // Milliseconds until the top of the next wall-clock hour, so the chime
  // lands on :00 rather than an hour after the shell happened to start.
  function msToNextHour() {
    var now = new Date()
    var next = new Date(now.getFullYear(), now.getMonth(), now.getDate(), now.getHours() + 1, 0, 0, 0)
    return Math.max(1000, next.getTime() - now.getTime())
  }

  // True only when the wall clock is actually at the top of the hour. A timer
  // that fires late because the machine was suspended must not chime at the
  // wake-up minute (e.g. :26); it should just realign to the next :00.
  function atTopOfHour() {
    return new Date().getMinutes() === 0
  }

  function reschedule() {
    hourTimer.stop()
    if (!enabled) return
    hourTimer.interval = msToNextHour()
    hourTimer.start()
  }

  function labelFor(path) {
    var base = String(path || "").split("/").pop() || ""
    var name = base.replace(/\.[^.]+$/, "").replace(/[-_]+/g, " ").trim()
    if (name === "") return String(path)
    return name.charAt(0).toUpperCase() + name.slice(1)
  }

  function parseSounds(text) {
    var lines = String(text || "").split("\n")
    var seen = ({})
    var out = []
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (line === "" || seen[line]) continue
      seen[line] = true
      out.push({ value: line, label: labelFor(line), description: line })
    }
    out.sort(function(a, b) { return a.label.localeCompare(b.label) })
    return out
  }

  onEnabledChanged: reschedule()

  Component.onCompleted: {
    reschedule()
    if (!finder.running) finder.running = true
  }

  // LC_ALL=C keeps pw-play's --volume decimal parsing locale-independent
  // (this system's LC_NUMERIC uses a comma).
  Process {
    id: player
    environment: ({ LC_ALL: "C" })
  }

  Process {
    id: finder
    command: [
      "find",
      "/usr/share/sounds",
      Quickshell.env("HOME") + "/.local/share/sounds",
      Quickshell.env("HOME") + "/.config/omarchy/sounds",
      "-type", "f",
      "(", "-iname", "*.oga", "-o", "-iname", "*.ogg", "-o", "-iname", "*.wav",
      "-o", "-iname", "*.flac", "-o", "-iname", "*.mp3", ")",
      "-print"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.soundOptions = root.parseSounds(text)
    }
    onExited: function(code) {
      if (root.soundOptions.length === 0)
        root.soundOptions = [{ value: root.defaultSound, label: "Complete", description: root.defaultSound }]
    }
  }

  Timer {
    id: hourTimer
    repeat: false
    onTriggered: {
      if (root.atTopOfHour()) root.chime()
      // Recompute against the wall clock every time so a suspend/resume (or a
      // late fire) never leaves the chime pinned to the wake-up minute.
      root.reschedule()
    }
  }
}
