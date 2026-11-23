import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Ui
import qs.Commons
import "WorldGeoJSON.js" as Geo

Panel {
  id: root
  moduleName: "nestor.lunar-tracker"
  ipcTarget: "nestor.lunar-tracker"

  readonly property color fb: root.bar ? root.bar.foreground : Color.foreground
  readonly property color dimFb: Util.alpha(fb, 0.55)
  readonly property color panelBg: Color.popups.background

  property var worldFeatures: []
  property var geoPolys: []
  property bool geometryReady: false

  property real timeOffsetDays: 0.0
  property double currentTimestamp: Date.now()
  property bool playing: false

  // Opening choreography progress values (0 -> 1)
  property real revealProgress: 1.0
  property real headerReveal: 1.0
  property real quad0Reveal: 1.0
  property real quad1Reveal: 1.0
  property real quad2Reveal: 1.0
  property real quad3Reveal: 1.0
  property real crosshairReveal: 1.0
  property real metricsReveal: 1.0
  property real footerReveal: 1.0

  // Smoothly animate discrete time steps / reset while keeping slider drag instant.
  NumberAnimation {
    id: offsetAnim
    target: root
    property: "timeOffsetDays"
    duration: Style.duration(260)
    easing.type: Easing.OutCubic
  }

  function setTimeOffsetDirect(value) {
    offsetAnim.stop()
    root.timeOffsetDays = Util.clamp(value, -30.0, 30.0)
  }

  function animateTimeOffsetTo(target) {
    var clamped = Util.clamp(target, -30.0, 30.0)
    if (Math.abs(clamped) < 0.01) clamped = 0.0
    if (Style.reduceMotion || Style.duration(260) === 0) {
      root.setTimeOffsetDirect(clamped)
      return
    }
    offsetAnim.stop()
    offsetAnim.from = root.timeOffsetDays
    offsetAnim.to = clamped
    offsetAnim.start()
  }

  function adjustTimeOffset(deltaDays) {
    root.playing = false
    var base = offsetAnim.running ? offsetAnim.to : root.timeOffsetDays
    root.animateTimeOffsetTo(base + deltaDays)
  }

  function resetToLive() {
    root.playing = false
    root.currentTimestamp = Date.now()
    root.animateTimeOffsetTo(0.0)
  }

  function togglePlayback() {
    offsetAnim.stop()
    root.playing = !root.playing
  }

  // Fast 1s clock only while the panel is open; slow 5-minute refresh while closed
  // so background monitors spend ~0% CPU.
  Timer {
    id: liveClockTimer
    interval: 1000
    running: root.opened && !root.playing
    repeat: true
    onTriggered: root.currentTimestamp = Date.now()
  }

  Timer {
    id: barRefreshTimer
    interval: 300000
    running: !root.opened
    repeat: true
    onTriggered: root.currentTimestamp = Date.now()
  }

  // Smooth orbital timelapse (~1.8 days/sec at ~30fps, active only while open).
  Timer {
    id: playbackTimer
    interval: 33
    running: root.opened && root.playing
    repeat: true
    onTriggered: {
      var next = root.timeOffsetDays + 0.06
      if (next > 30.0) next = -30.0
      root.timeOffsetDays = next
    }
  }

  // Staggered entrance + orbital sweep animation on panel open.
  ParallelAnimation {
    id: openChoreography

    NumberAnimation {
      target: root
      property: "headerReveal"
      from: 0.0
      to: 1.0
      duration: Style.duration(180)
      easing.type: Easing.Bezier
      easing.bezierCurve: Style.easeOut
    }

    SequentialAnimation {
      PauseAnimation { duration: Style.duration(30) }
      NumberAnimation {
        target: root
        property: "quad0Reveal"
        from: 0.0
        to: 1.0
        duration: Style.duration(210)
        easing.type: Easing.Bezier
        easing.bezierCurve: Style.easeOut
      }
    }

    SequentialAnimation {
      PauseAnimation { duration: Style.duration(65) }
      NumberAnimation {
        target: root
        property: "quad1Reveal"
        from: 0.0
        to: 1.0
        duration: Style.duration(210)
        easing.type: Easing.Bezier
        easing.bezierCurve: Style.easeOut
      }
    }

    SequentialAnimation {
      PauseAnimation { duration: Style.duration(100) }
      NumberAnimation {
        target: root
        property: "quad2Reveal"
        from: 0.0
        to: 1.0
        duration: Style.duration(210)
        easing.type: Easing.Bezier
        easing.bezierCurve: Style.easeOut
      }
    }

    SequentialAnimation {
      PauseAnimation { duration: Style.duration(135) }
      NumberAnimation {
        target: root
        property: "quad3Reveal"
        from: 0.0
        to: 1.0
        duration: Style.duration(210)
        easing.type: Easing.Bezier
        easing.bezierCurve: Style.easeOut
      }
    }

    SequentialAnimation {
      PauseAnimation { duration: Style.duration(40) }
      NumberAnimation {
        target: root
        property: "crosshairReveal"
        from: 0.0
        to: 1.0
        duration: Style.duration(260)
        easing.type: Easing.OutCubic
      }
    }

    SequentialAnimation {
      PauseAnimation { duration: Style.duration(25) }
      NumberAnimation {
        target: root
        property: "revealProgress"
        from: 0.0
        to: 1.0
        duration: Style.duration(460)
        easing.type: Easing.OutCubic
      }
    }

    SequentialAnimation {
      PauseAnimation { duration: Style.duration(120) }
      NumberAnimation {
        target: root
        property: "metricsReveal"
        from: 0.0
        to: 1.0
        duration: Style.duration(210)
        easing.type: Easing.Bezier
        easing.bezierCurve: Style.easeOut
      }
    }

    SequentialAnimation {
      PauseAnimation { duration: Style.duration(160) }
      NumberAnimation {
        target: root
        property: "footerReveal"
        from: 0.0
        to: 1.0
        duration: Style.duration(180)
        easing.type: Easing.OutCubic
      }
    }
  }

  function triggerOpenAnimation() {
    openChoreography.stop()
    if (Style.reduceMotion) {
      root.headerReveal = 1.0
      root.quad0Reveal = 1.0
      root.quad1Reveal = 1.0
      root.quad2Reveal = 1.0
      root.quad3Reveal = 1.0
      root.crosshairReveal = 1.0
      root.revealProgress = 1.0
      root.metricsReveal = 1.0
      root.footerReveal = 1.0
      return
    }
    root.headerReveal = 0.0
    root.quad0Reveal = 0.0
    root.quad1Reveal = 0.0
    root.quad2Reveal = 0.0
    root.quad3Reveal = 0.0
    root.crosshairReveal = 0.0
    root.revealProgress = 0.0
    root.metricsReveal = 0.0
    root.footerReveal = 0.0
    openChoreography.start()
  }

  onOpenedChanged: {
    if (root.opened) {
      root.ensureGeometry()
      root.currentTimestamp = Date.now()
      root.triggerOpenAnimation()
    } else {
      root.playing = false
      offsetAnim.stop()
      openChoreography.stop()
    }
  }

  readonly property bool isLive: Math.abs(root.timeOffsetDays) < 0.05 && !root.playing
  readonly property var simulatedDate: new Date(root.currentTimestamp + root.timeOffsetDays * 86400000)

  // Simulation calculations based on simulatedDate
  readonly property real simJd: simulatedDate.getTime() / 86400000.0 + 2440587.5
  readonly property real simDaysSince: simJd - 2451550.26
  readonly property real simSynodic: 29.53058770576
  readonly property real simPhaseAgeDays: ((simDaysSince / simSynodic) % 1 + 1) % 1 * simSynodic
  readonly property real simPhaseFraction: simPhaseAgeDays / simSynodic
  readonly property real simIllumination: (1 - Math.cos(2 * Math.PI * simPhaseFraction)) / 2 * 100
  readonly property real simMoonAngle: (simPhaseFraction * 360) % 360
  readonly property real simEarthRotation: ((simulatedDate.getUTCHours() * 60 + simulatedDate.getUTCMinutes() + simulatedDate.getUTCSeconds() / 60) / 1440.0) * 360
  readonly property real simDaysToFull: (0.5 - simPhaseFraction + 1) % 1 * simSynodic
  readonly property real simDaysToNew: (1.0 - simPhaseFraction) % 1 * simSynodic
  readonly property real simDayOfYear: {
    var now = root.simulatedDate
    var start = new Date(now.getFullYear(), 0, 0)
    return Math.floor((now - start) / 86400000)
  }
  readonly property real simSolarDeclination: -23.44 * Math.cos((simDayOfYear + 10) * 2 * Math.PI / 365)
  readonly property int simDistanceKm: {
    var Mm = 2 * Math.PI * (root.simJd - 2451534.5) / 27.55455
    return Math.round(384400 - 21100 * Math.cos(Mm))
  }
  readonly property string simNextEvent: {
    var now = root.simulatedDate
    var yr = now.getFullYear()
    var events = [
      { name: "MAR 20 (Eq)", date: new Date(Date.UTC(yr, 2, 20)) },
      { name: "JUN 21 (So)", date: new Date(Date.UTC(yr, 5, 21)) },
      { name: "SEP 22 (Eq)", date: new Date(Date.UTC(yr, 8, 22)) },
      { name: "DEC 21 (So)", date: new Date(Date.UTC(yr, 11, 21)) },
      { name: "MAR 20 (Eq)", date: new Date(Date.UTC(yr + 1, 2, 20)) }
    ]
    for (var i = 0; i < events.length; i++) {
      var diffDays = (events[i].date - now) / 86400000
      if (diffDays >= -0.5) {
        var rounded = Math.max(0, Math.ceil(diffDays))
        return rounded === 0 ? (events[i].name + " (today)") : (events[i].name + " (in " + rounded + "d)")
      }
    }
    return "MAR 20 (Eq)"
  }
  readonly property string simNorthSeason: {
    var d = root.simDayOfYear
    if (d >= 79 && d < 172) return "Spring 🌱"
    if (d >= 172 && d < 265) return "Summer ☀️"
    if (d >= 265 && d < 355) return "Autumn 🍂"
    return "Winter ❄️"
  }
  readonly property string simSouthSeason: {
    var d = root.simDayOfYear
    if (d >= 79 && d < 172) return "Autumn 🍂"
    if (d >= 172 && d < 265) return "Winter ❄️"
    if (d >= 265 && d < 355) return "Spring 🌱"
    return "Summer ☀️"
  }

  function getPhaseEmoji(f) {
    if (f < 0.0312 || f >= 0.9688) return "🌑"
    if (f < 0.2188) return "🌒"
    if (f < 0.2812) return "🌓"
    if (f < 0.4688) return "🌔"
    if (f < 0.5312) return "🌕"
    if (f < 0.7188) return "🌖"
    if (f < 0.7812) return "🌗"
    return "🌘"
  }

  function getPhaseName(f) {
    if (f < 0.0312 || f >= 0.9688) return "New Moon"
    if (f < 0.2188) return "Waxing Crescent"
    if (f < 0.2812) return "First Quarter"
    if (f < 0.4688) return "Waxing Gibbous"
    if (f < 0.5312) return "Full Moon"
    if (f < 0.7188) return "Waning Gibbous"
    if (f < 0.7812) return "Last Quarter"
    return "Waning Crescent"
  }

  readonly property string simPhaseName: getPhaseName(simPhaseFraction)
  readonly property string simPhaseEmoji: getPhaseEmoji(simPhaseFraction)
  readonly property int simLunation: Math.floor(simDaysSince / simSynodic) + 953

  readonly property string phaseName: simPhaseName
  readonly property string phaseEmoji: simPhaseEmoji
  readonly property real phaseFraction: simPhaseFraction
  readonly property real illumination: simIllumination
  readonly property real moonAngle: simMoonAngle
  readonly property real earthRotation: simEarthRotation
  readonly property real phaseAgeDays: simPhaseAgeDays
  readonly property real daysToFull: simDaysToFull
  readonly property real daysToNew: simDaysToNew
  readonly property real synodicMonth: simSynodic
  readonly property int lunation: simLunation

  // Lazy-parse GeoJSON only once when the dashboard is actually opened on this screen.
  function ensureGeometry() {
    if (root.geometryReady) return
    root.worldFeatures = Geo.data.features
    var polys = []
    for (var i = 0; i < root.worldFeatures.length; i++) {
      var feat = root.worldFeatures[i]
      if (!feat.geometry) continue
      if (feat.geometry.type === "Polygon") {
        root.collectRings(feat.geometry.coordinates, polys)
      } else if (feat.geometry.type === "MultiPolygon") {
        for (var p = 0; p < feat.geometry.coordinates.length; p++) {
          root.collectRings(feat.geometry.coordinates[p], polys)
        }
      }
    }
    root.geoPolys = polys
    root.geometryReady = true
  }

  function collectRings(rings, target) {
    for (var r = 0; r < rings.length; r++) {
      var coords = rings[r]
      var pts = []
      for (var c = 0; c < coords.length; c++) {
        pts.push(coords[c][0] * Math.PI / 180)
        pts.push(coords[c][1] * Math.PI / 180)
      }
      target.push(pts)
    }
  }

  // Reusable plain-text label enforcing Text.PlainText + Omarchy font family.
  component PlainLabel: Label {
    textFormat: Text.PlainText
    font.family: Style.font.family
  }

  // Reusable quick-step button with tactile press & hover animations.
  component StepButton: Rectangle {
    id: stepBtn
    required property string labelText
    required property real deltaDays
    property bool accentHover: false

    implicitWidth: stepBtnLabel.implicitWidth + Style.space(12)
    implicitHeight: Style.space(20)
    radius: Math.min(Style.cornerRadius > 0 ? Style.cornerRadius : Style.space(4), Style.space(4))
    color: stepBtnMouse.pressed
      ? Util.alpha(accentHover ? Color.accent : root.fb, 0.28)
      : (stepBtnMouse.containsMouse
        ? Util.alpha(accentHover ? Color.accent : root.fb, accentHover ? 0.22 : 0.14)
        : Util.alpha(root.fb, 0.05))
    border.width: 1
    border.color: stepBtnMouse.containsMouse
      ? Util.alpha(accentHover ? Color.accent : root.fb, 0.35)
      : Util.alpha(root.fb, 0.12)
    scale: stepBtnMouse.pressed ? 0.94 : 1.0

    Behavior on color { ColorAnimation { duration: Style.duration(120) } }
    Behavior on border.color { ColorAnimation { duration: Style.duration(120) } }
    Behavior on scale {
      NumberAnimation {
        duration: Style.duration(140)
        easing.type: Easing.Bezier
        easing.bezierCurve: Style.easeOut
      }
    }

    PlainLabel {
      id: stepBtnLabel
      anchors.centerIn: parent
      text: stepBtn.labelText
      font.pixelSize: Math.max(8, Style.font.caption - 1)
      font.weight: Font.DemiBold
      color: root.fb
    }

    MouseArea {
      id: stepBtnMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.adjustTimeOffset(stepBtn.deltaDays)
    }
  }

  // Reusable metric row with themed hover highlight & ToolTip.
  component MetricRow: Rectangle {
    id: metricRow
    required property string title
    required property string value
    property string suffix: ""
    property bool dimValue: false
    required property string tipText

    Layout.fillWidth: true
    implicitHeight: Style.space(21)
    radius: Math.min(Style.cornerRadius > 0 ? Style.cornerRadius : Style.space(4), Style.space(4))
    color: metricMa.containsMouse ? Util.alpha(root.fb, 0.08) : "transparent"

    Behavior on color { ColorAnimation { duration: Style.duration(120) } }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(4)

      PlainLabel {
        text: metricRow.title
        font.pixelSize: Style.font.caption
        font.letterSpacing: 1
        color: root.dimFb
      }
      Item { Layout.fillWidth: true }
      PlainLabel {
        text: metricRow.value
        font.pixelSize: Style.font.caption
        font.weight: metricRow.dimValue ? Font.Normal : Font.DemiBold
        color: metricRow.dimValue ? root.dimFb : root.fb
      }
      PlainLabel {
        visible: metricRow.suffix !== ""
        text: metricRow.suffix
        font.pixelSize: Style.font.caption
        color: root.dimFb
      }
    }

    ToolTip {
      visible: metricMa.containsMouse
      delay: 180
      timeout: 6000
      contentItem: Text {
        textFormat: Text.PlainText
        text: metricRow.tipText
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        color: Color.tooltip.text
        wrapMode: Text.WordWrap
      }
      background: Rectangle {
        color: Color.tooltip.background
        border.color: Color.tooltip.border
        border.width: 1
        radius: Math.min(Style.cornerRadius > 0 ? Style.cornerRadius : Style.space(6), Style.space(6))
      }
    }

    MouseArea {
      id: metricMa
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // ─── Bar icon ───
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    slotSize: Style.bar.iconSlot
    opticalSize: 12
    tooltipText: "Cosmic Dial — " + root.phaseName + " (" + Math.round(root.illumination) + "%)"

    iconComponent: Component {
      Canvas {
        id: moonIcon
        width: button.opticalSize
        height: button.opticalSize
        renderTarget: Canvas.Image

        property real phase: root.phaseFraction
        property color fgColor: root.fb

        onPhaseChanged: requestPaint()
        onFgColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()

        onPaint: {
          if (width <= 0 || height <= 0) return
          var ctx = getContext("2d")
          ctx.reset()
          ctx.clearRect(0, 0, width, height)
          var cx = width / 2
          var cy = height / 2
          var r = Math.min(width, height) / 2 - 1
          var pi = Math.PI
          var f = moonIcon.phase
          var fg = moonIcon.fgColor

          // Base outline (dark disk)
          ctx.fillStyle = Qt.rgba(fg.r, fg.g, fg.b, 0.15).toString()
          ctx.beginPath()
          ctx.arc(cx, cy, r, 0, 2 * pi)
          ctx.fill()

          // Fill illuminated part
          var illumFrac = (1 - Math.cos(2 * pi * f)) / 2
          if (illumFrac > 0.01) {
            ctx.fillStyle = fg.toString()
            ctx.beginPath()
            var steps = 18
            if (f <= 0.5) {
              ctx.arc(cx, cy, r, -pi / 2, pi / 2, false)
              var k = Math.cos(2 * pi * f)
              for (var i = 0; i <= steps; i++) {
                var theta = pi / 2 - (pi * i / steps)
                var tx = cx + k * r * Math.cos(theta)
                var ty = cy + r * Math.sin(theta)
                ctx.lineTo(tx, ty)
              }
            } else {
              ctx.arc(cx, cy, r, pi / 2, 3 * pi / 2, false)
              var k = -Math.cos(2 * pi * f)
              for (var i = 0; i <= steps; i++) {
                var theta = -pi / 2 + (pi * i / steps)
                var tx = cx + k * r * Math.cos(theta)
                var ty = cy + r * Math.sin(theta)
                ctx.lineTo(tx, ty)
              }
            }
            ctx.closePath()
            ctx.fill()
          }

          // Outline
          ctx.strokeStyle = fg.toString()
          ctx.lineWidth = 1.1
          ctx.beginPath()
          ctx.arc(cx, cy, r, 0, 2 * pi)
          ctx.stroke()
        }
      }
    }

    onPressed: function(b) {
      if (root.opened) root.close()
      else root.open()
    }
  }

  // ─── Panel popup (lazy-loaded on first open) ───
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(860))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      id: keyCatcher
      implicitHeight: rootColumn.implicitHeight

      onCloseRequested: root.close()
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.adjustTimeOffset(dx * 1.0)
        else if (dy !== 0) root.adjustTimeOffset(-dy * 7.0)
      }
      onActivateRequested: root.togglePlayback()
      onTextKey: function(t, modifiers) {
        if (t === "r" || t === "R" || t === "0") root.resetToLive()
      }

      ColumnLayout {
        id: rootColumn
        width: parent.width
        spacing: Style.space(8)

        // ─── Header: Title, Status Badge, Controls & Time Scrubber ───
        ColumnLayout {
          id: headerSection
          Layout.fillWidth: true
          Layout.leftMargin: Style.space(6)
          Layout.rightMargin: Style.space(6)
          Layout.topMargin: Style.space(2)
          spacing: Style.space(6)
          opacity: root.headerReveal
          transform: Translate { y: (1 - root.headerReveal) * Style.space(-6) }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            PlainLabel {
              text: "✦ COSMIC DIAL"
              font.pixelSize: Style.font.caption
              font.weight: Font.DemiBold
              font.letterSpacing: 2
              color: root.fb
            }

            PlainLabel {
              text: root.simPhaseEmoji + " " + root.simPhaseName.toUpperCase()
              font.pixelSize: Style.font.caption
              font.letterSpacing: 0.8
              color: root.dimFb
            }

            Item { Layout.fillWidth: true }

            // Play / Pause timelapse button
            Rectangle {
              implicitWidth: playBtnText.implicitWidth + Style.space(18)
              implicitHeight: Style.space(24)
              radius: Math.min(Style.cornerRadius > 0 ? Style.cornerRadius : Style.space(6), Style.space(6))
              color: root.playing
                ? Util.alpha(Color.accent, playBtnMouse.containsMouse ? 0.30 : 0.20)
                : (playBtnMouse.containsMouse ? Util.alpha(root.fb, 0.14) : Util.alpha(root.fb, 0.06))
              border.width: 1
              border.color: root.playing ? Util.alpha(Color.accent, 0.55) : Util.alpha(root.fb, 0.16)
              scale: playBtnMouse.pressed ? 0.94 : 1.0

              Behavior on color { ColorAnimation { duration: Style.duration(140) } }
              Behavior on border.color { ColorAnimation { duration: Style.duration(140) } }
              Behavior on scale {
                NumberAnimation { duration: Style.duration(140); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
              }

              PlainLabel {
                id: playBtnText
                anchors.centerIn: parent
                text: root.playing ? "⏸ PAUSE" : "▶ PLAY"
                font.pixelSize: Math.max(9, Style.font.caption - 1)
                font.weight: Font.Bold
                color: root.playing ? Color.accent : root.fb
              }

              MouseArea {
                id: playBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.togglePlayback()
              }
            }

            // Simulated Date & Status Badge
            Rectangle {
              implicitWidth: timeBadgeText.implicitWidth + Style.space(32)
              implicitHeight: Style.space(24)
              radius: implicitHeight / 2
              color: root.isLive ? Util.alpha(Color.accent, 0.15) : Util.alpha(Color.urgent, 0.15)
              border.width: 1
              border.color: root.isLive ? Util.alpha(Color.accent, 0.42) : Util.alpha(Color.urgent, 0.42)

              Behavior on color { ColorAnimation { duration: Style.duration(160) } }
              Behavior on border.color { ColorAnimation { duration: Style.duration(160) } }

              RowLayout {
                anchors.centerIn: parent
                spacing: Style.space(7)

                Rectangle {
                  id: liveDot
                  width: 6
                  height: 6
                  radius: 3
                  color: root.isLive ? Color.accent : Color.urgent

                  SequentialAnimation on opacity {
                    running: panel.visible && root.isLive && !Style.reduceMotion
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 1100; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 1100; easing.type: Easing.InOutSine }
                  }
                }

                PlainLabel {
                  id: timeBadgeText
                  text: {
                    var dStr = Qt.formatDateTime(root.simulatedDate, "dd MMM yyyy HH:mm")
                    if (root.isLive) return "LIVE (" + dStr + ")"
                    var sign = root.timeOffsetDays > 0 ? "+" : ""
                    return sign + root.timeOffsetDays.toFixed(1) + "d · " + dStr
                  }
                  font.pixelSize: Style.font.caption
                  font.weight: Font.Medium
                  color: root.fb
                }
              }
            }

            // Reset button when offset or playback active
            Rectangle {
              visible: !root.isLive
              implicitWidth: resetBtnText.implicitWidth + Style.space(18)
              implicitHeight: Style.space(24)
              radius: Math.min(Style.cornerRadius > 0 ? Style.cornerRadius : Style.space(6), Style.space(6))
              color: resetBtnMouse.containsMouse ? Util.alpha(Color.accent, 0.25) : Util.alpha(Color.accent, 0.12)
              border.width: 1
              border.color: Util.alpha(Color.accent, 0.40)
              scale: resetBtnMouse.pressed ? 0.94 : 1.0

              Behavior on color { ColorAnimation { duration: Style.duration(120) } }
              Behavior on scale {
                NumberAnimation { duration: Style.duration(140); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
              }

              PlainLabel {
                id: resetBtnText
                anchors.centerIn: parent
                text: "⟲ LIVE"
                font.pixelSize: Math.max(9, Style.font.caption - 1)
                font.weight: Font.Bold
                color: Color.accent
              }

              MouseArea {
                id: resetBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.resetToLive()
              }
            }
          }

          // Quick Step buttons row
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(5)

            PlainLabel {
              text: "STEP:"
              font.pixelSize: Math.max(8, Style.font.caption - 2)
              font.weight: Font.Bold
              color: root.dimFb
            }

            Repeater {
              model: [
                { label: "-1w", delta: -7.0 },
                { label: "-1d", delta: -1.0 },
                { label: "-12h", delta: -0.5 },
                { label: "-5h", delta: -5 / 24 },
                { label: "-1h", delta: -1 / 24 }
              ]
              delegate: StepButton {
                required property var modelData
                labelText: modelData.label
                deltaDays: modelData.delta
                accentHover: false
              }
            }

            Item { Layout.fillWidth: true }

            Repeater {
              model: [
                { label: "+1h", delta: 1 / 24 },
                { label: "+5h", delta: 5 / 24 },
                { label: "+12h", delta: 0.5 },
                { label: "+1d", delta: 1.0 },
                { label: "+1w", delta: 7.0 }
              ]
              delegate: StepButton {
                required property var modelData
                labelText: modelData.label
                deltaDays: modelData.delta
                accentHover: true
              }
            }
          }

          // Scrubber Slider bar
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(10)

            PlainLabel {
              text: "-30d"
              font.pixelSize: Math.max(9, Style.font.caption - 1)
              color: root.dimFb
            }

            Slider {
              id: timeScrubber
              Layout.fillWidth: true
              from: -30.0
              to: 30.0
              value: root.timeOffsetDays
              stepSize: 0.1

              onMoved: {
                root.playing = false
                if (Math.abs(value) < 0.3) root.setTimeOffsetDirect(0.0)
                else root.setTimeOffsetDirect(value)
              }

              background: Rectangle {
                x: timeScrubber.leftPadding
                y: timeScrubber.topPadding + timeScrubber.availableHeight / 2 - height / 2
                implicitWidth: 200
                implicitHeight: 4
                width: timeScrubber.availableWidth
                height: implicitHeight
                radius: 2
                color: Util.alpha(root.fb, 0.12)

                // Active offset fill from center (0d) to current handle
                Rectangle {
                  readonly property real centerX: parent.width / 2
                  readonly property real handleX: timeScrubber.visualPosition * parent.width
                  x: Math.min(centerX, handleX)
                  width: Math.abs(handleX - centerX)
                  height: parent.height
                  radius: 2
                  color: Util.alpha(root.isLive ? Color.accent : Color.urgent, 0.65)
                }

                // Center tick marker for LIVE (0d)
                Rectangle {
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.verticalCenter: parent.verticalCenter
                  width: 2
                  height: 10
                  radius: 1
                  color: Util.alpha(Color.accent, 0.7)
                }
              }

              handle: Rectangle {
                x: timeScrubber.leftPadding + timeScrubber.visualPosition * (timeScrubber.availableWidth - width)
                y: timeScrubber.topPadding + timeScrubber.availableHeight / 2 - height / 2
                implicitWidth: 16
                implicitHeight: 16
                radius: 8
                scale: timeScrubber.pressed ? 1.12 : 1.0
                color: timeScrubber.pressed ? root.fb : (root.isLive ? Color.accent : Color.urgent)
                border.color: Util.alpha(root.panelBg, 0.85)
                border.width: 2

                Behavior on scale {
                  NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic }
                }
                Behavior on color { ColorAnimation { duration: Style.duration(140) } }
              }
            }

            PlainLabel {
              text: "+30d"
              font.pixelSize: Math.max(9, Style.font.caption - 1)
              color: root.dimFb
            }
          }
        }

        // ─── 4-Quadrant Systems Dashboard ───
        Rectangle {
          id: dashboardFrame
          Layout.fillWidth: true
          Layout.leftMargin: Style.space(4)
          Layout.rightMargin: Style.space(4)
          Layout.preferredHeight: Math.min(
            Style.space(580),
            Math.max(Style.space(400), Math.round((panel.availableCardHeight > 0 ? panel.availableCardHeight : 960) * 0.56))
          )
          color: Util.alpha(root.fb, 0.02)
          radius: Math.min(Style.cornerRadius > 0 ? Style.cornerRadius : Style.space(8), Style.space(8))
          border.width: 1
          border.color: Util.alpha(root.fb, 0.12)

          GridLayout {
            anchors.fill: parent
            anchors.margins: Style.space(8)
            columns: 2
            rowSpacing: Style.space(8)
            columnSpacing: Style.space(8)

            // 1. Earth-Moon Orrery
            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.preferredWidth: 1
              Layout.preferredHeight: 1
              opacity: root.quad0Reveal
              scale: 0.965 + 0.035 * root.quad0Reveal

              Canvas {
                id: orreryCanvas
                anchors.fill: parent
                renderTarget: Canvas.Image

                property real phaseFrac: root.simPhaseFraction
                property real earthRot: root.simEarthRotation
                property real moonAng: root.simMoonAngle
                property real illum: root.simIllumination
                property real rev: root.revealProgress
                property color fgColor: root.fb
                property color bgColor: root.panelBg
                property bool geoReady: root.geometryReady

                onPhaseFracChanged: if (panel.visible) requestPaint()
                onEarthRotChanged: if (panel.visible) requestPaint()
                onMoonAngChanged: if (panel.visible) requestPaint()
                onIllumChanged: if (panel.visible) requestPaint()
                onRevChanged: if (panel.visible) requestPaint()
                onFgColorChanged: if (panel.visible) requestPaint()
                onBgColorChanged: if (panel.visible) requestPaint()
                onGeoReadyChanged: if (panel.visible) requestPaint()
                onWidthChanged: if (panel.visible) requestPaint()
                onHeightChanged: if (panel.visible) requestPaint()

                onPaint: {
                  if (!panel.visible || width <= 0 || height <= 0) return
                  var ctx = getContext("2d")
                  ctx.reset()
                  ctx.clearRect(0, 0, width, height)

                  var cx = width / 2
                  var cy = height / 2
                  var w = width
                  var h = height
                  var pi = Math.PI
                  var fg = orreryCanvas.fgColor
                  var bg = orreryCanvas.bgColor
                  var rev = orreryCanvas.rev

                  var orbitRX = Math.min(w * 0.31, h * 0.44)
                  var orbitRY = orbitRX * 0.36
                  var earthR = Math.max(18, Math.min(w, h) * 0.105)
                  var moonR = Math.max(8, earthR * 0.43)

                  // Smooth orbital sweep on panel open
                  var animatedAng = orreryCanvas.moonAng - 28 * (1 - rev)
                  var rad = animatedAng * pi / 180
                  var moonX = cx - orbitRX * Math.cos(rad)
                  var moonY = cy + orbitRY * Math.sin(rad)

                  // Sunlight direction arrows (slide in gently on open)
                  ctx.globalAlpha = 0.16 * rev
                  ctx.strokeStyle = Qt.rgba(1.0, 0.85, 0.38, 1.0).toString()
                  ctx.lineWidth = 1
                  var raySlide = (1 - rev) * 12
                  for (var i = -2; i <= 2; i++) {
                    var lineY = cy + i * Math.min(24, h * 0.085)
                    ctx.beginPath()
                    ctx.moveTo(10 - raySlide, lineY)
                    ctx.lineTo(28 - raySlide, lineY)
                    ctx.moveTo(23 - raySlide, lineY - 3)
                    ctx.lineTo(28 - raySlide, lineY)
                    ctx.lineTo(23 - raySlide, lineY + 3)
                    ctx.stroke()
                  }

                  // Orbit ellipse
                  ctx.globalAlpha = 0.25 * rev
                  ctx.strokeStyle = fg.toString()
                  ctx.lineWidth = 1
                  ctx.beginPath()
                  for (var j = 0; j <= 64; j++) {
                    var a = j * 2 * pi / 64
                    var x = cx + orbitRX * Math.cos(a)
                    var y = cy + orbitRY * Math.sin(a)
                    if (j === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                  }
                  ctx.stroke()

                  var drawEarth = function() {
                    ctx.save()
                    ctx.globalAlpha = 1
                    var oceanGrad = ctx.createRadialGradient(cx, cy, 0, cx, cy, earthR)
                    oceanGrad.addColorStop(0, Qt.rgba(fg.r, fg.g, fg.b, 0.10).toString())
                    oceanGrad.addColorStop(1, Qt.rgba(fg.r, fg.g, fg.b, 0.24).toString())
                    ctx.fillStyle = oceanGrad
                    ctx.beginPath()
                    ctx.arc(cx, cy, earthR, 0, 2 * pi)
                    ctx.fill()

                    if (root.geoPolys && root.geoPolys.length > 0) {
                      var lon0 = ((0.5 - (orreryCanvas.earthRot / 360)) * 360 + 90) * pi / 180
                      ctx.fillStyle = Qt.rgba(fg.r, fg.g, fg.b, 0.45).toString()
                      for (var p = 0; p < root.geoPolys.length; p++) {
                        var pts = root.geoPolys[p]
                        ctx.beginPath()
                        var started = false
                        for (var c = 0; c < pts.length; c += 2) {
                          var lon = pts[c] - lon0
                          var lat = pts[c + 1]
                          var z = Math.cos(lat) * Math.cos(lon)
                          var lx = Math.cos(lat) * Math.sin(lon)
                          var ly = -Math.sin(lat)
                          if (z > 0) {
                            var px = cx + lx * earthR
                            var py = cy + ly * earthR
                            if (!started) { ctx.moveTo(px, py); started = true }
                            else ctx.lineTo(px, py)
                          } else {
                            started = false
                          }
                        }
                        ctx.fill()
                      }
                    }

                    // Night hemisphere shadow
                    ctx.globalAlpha = 0.7
                    ctx.fillStyle = Qt.rgba(0, 0, 0, 0.6).toString()
                    ctx.beginPath()
                    ctx.arc(cx, cy, earthR, -pi / 2, pi / 2, false)
                    ctx.fill()

                    var shadowGrad = ctx.createLinearGradient(cx - earthR * 0.2, cy, cx + earthR * 0.5, cy)
                    shadowGrad.addColorStop(0, Qt.rgba(0, 0, 0, 0.0).toString())
                    shadowGrad.addColorStop(1, Qt.rgba(0, 0, 0, 0.5).toString())
                    ctx.fillStyle = shadowGrad
                    ctx.beginPath()
                    ctx.arc(cx, cy, earthR, 0, 2 * pi)
                    ctx.fill()

                    ctx.globalAlpha = 0.55
                    ctx.strokeStyle = fg.toString()
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.arc(cx, cy, earthR, 0, 2 * pi)
                    ctx.stroke()
                    ctx.restore()
                  }

                  var drawMoon = function() {
                    ctx.save()
                    var phaseFrac = orreryCanvas.phaseFrac
                    var illumFrac = orreryCanvas.illum / 100.0

                    // 1. Soft lunar glow
                    if (illumFrac > 0.05) {
                      var moonGlowGrad = ctx.createRadialGradient(moonX, moonY, moonR * 0.7, moonX, moonY, moonR + 7 * illumFrac)
                      moonGlowGrad.addColorStop(0, Qt.rgba(fg.r, fg.g, fg.b, 0.38 * illumFrac * rev).toString())
                      moonGlowGrad.addColorStop(1, Qt.rgba(fg.r, fg.g, fg.b, 0.0).toString())
                      ctx.globalAlpha = 1
                      ctx.fillStyle = moonGlowGrad
                      ctx.beginPath()
                      ctx.arc(moonX, moonY, moonR + 7 * illumFrac, 0, 2 * pi)
                      ctx.fill()
                    }

                    // 2. Opaque dark lunar disc (theme-aware)
                    var darkBase = Qt.darker(bg, 1.35)
                    var darkHi = Qt.lighter(bg, 1.15)
                    ctx.fillStyle = darkBase.toString()
                    ctx.beginPath()
                    ctx.arc(moonX, moonY, moonR, 0, 2 * pi)
                    ctx.fill()

                    var darkGrad = ctx.createRadialGradient(moonX - moonR * 0.2, moonY - moonR * 0.2, 0, moonX, moonY, moonR)
                    darkGrad.addColorStop(0, darkHi.toString())
                    darkGrad.addColorStop(1, darkBase.toString())
                    ctx.fillStyle = darkGrad
                    ctx.beginPath()
                    ctx.arc(moonX, moonY, moonR, 0, 2 * pi)
                    ctx.fill()

                    // 3. Illuminated phase crescent/gibbous
                    if (illumFrac > 0.01) {
                      ctx.save()
                      ctx.beginPath()
                      ctx.arc(moonX, moonY, moonR, 0, 2 * pi)
                      ctx.clip()

                      var litGrad = ctx.createRadialGradient(moonX - moonR * 0.3, moonY - moonR * 0.3, 0, moonX, moonY, moonR)
                      litGrad.addColorStop(0, Qt.rgba(fg.r, fg.g, fg.b, 0.98).toString())
                      litGrad.addColorStop(0.75, Qt.rgba(fg.r * 0.88, fg.g * 0.90, fg.b * 0.94, 0.98).toString())
                      litGrad.addColorStop(1, Qt.rgba(fg.r * 0.74, fg.g * 0.78, fg.b * 0.85, 0.98).toString())
                      ctx.fillStyle = litGrad

                      ctx.beginPath()
                      var steps = 32
                      if (phaseFrac <= 0.5) {
                        ctx.arc(moonX, moonY, moonR, -pi / 2, pi / 2, false)
                        var k = Math.cos(2 * pi * phaseFrac)
                        for (var s = 0; s <= steps; s++) {
                          var theta = pi / 2 - (pi * s / steps)
                          ctx.lineTo(moonX + k * moonR * Math.cos(theta), moonY + moonR * Math.sin(theta))
                        }
                      } else {
                        ctx.arc(moonX, moonY, moonR, pi / 2, 3 * pi / 2, false)
                        var k = -Math.cos(2 * pi * phaseFrac)
                        for (var s = 0; s <= steps; s++) {
                          var theta = -pi / 2 + (pi * s / steps)
                          ctx.lineTo(moonX + k * moonR * Math.cos(theta), moonY + moonR * Math.sin(theta))
                        }
                      }
                      ctx.closePath()
                      ctx.fill()
                      ctx.restore()
                    }

                    // 4. Crisp limb outline
                    ctx.globalAlpha = 0.5
                    ctx.strokeStyle = fg.toString()
                    ctx.lineWidth = 0.85
                    ctx.beginPath()
                    ctx.arc(moonX, moonY, moonR, 0, 2 * pi)
                    ctx.stroke()
                    ctx.restore()
                  }

                  if (moonY < cy) { drawMoon(); drawEarth() }
                  else { drawEarth(); drawMoon() }

                  ctx.globalAlpha = 0.42 * rev
                  ctx.fillStyle = fg.toString()
                  ctx.font = "8px monospace"
                  ctx.textAlign = "center"
                  ctx.fillText(orreryCanvas.moonAng.toFixed(0) + "°", moonX, moonY - moonR - 6)

                  ctx.globalAlpha = 0.35
                  ctx.textAlign = "left"
                  ctx.fillText("EARTH-MOON", 10, 18)
                  ctx.globalAlpha = 0.28 * rev
                  ctx.fillText(root.simPhaseName.toUpperCase() + " · " + orreryCanvas.illum.toFixed(0) + "%", 10, h - 10)
                }
              }
            }

            // 2. Earth Orbit around Sun
            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.preferredWidth: 1
              Layout.preferredHeight: 1
              opacity: root.quad1Reveal
              scale: 0.965 + 0.035 * root.quad1Reveal

              Canvas {
                id: sunEarthCanvas
                anchors.fill: parent
                renderTarget: Canvas.Image

                property var simDate: root.simulatedDate
                property real rev: root.revealProgress
                property color fgColor: root.fb
                property color accentColor: Color.accent

                onSimDateChanged: if (panel.visible) requestPaint()
                onRevChanged: if (panel.visible) requestPaint()
                onFgColorChanged: if (panel.visible) requestPaint()
                onAccentColorChanged: if (panel.visible) requestPaint()
                onWidthChanged: if (panel.visible) requestPaint()
                onHeightChanged: if (panel.visible) requestPaint()

                onPaint: {
                  if (!panel.visible || width <= 0 || height <= 0) return
                  var ctx = getContext("2d")
                  ctx.reset()
                  ctx.clearRect(0, 0, width, height)
                  var cx = width / 2
                  var cy = height / 2
                  var pi = Math.PI
                  var fg = sunEarthCanvas.fgColor
                  var rev = sunEarthCanvas.rev

                  var a = Math.min(width * 0.25, height * 0.36)
                  var e = 0.055
                  var longPeri = 102.94 * pi / 180
                  var b = a * Math.sqrt(1 - e * e)

                  var centerX = cx - a * e * Math.cos(longPeri)
                  var centerY = cy - a * e * Math.sin(longPeri)

                  // Orbit ellipse
                  ctx.globalAlpha = 0.26 * rev
                  ctx.strokeStyle = fg.toString()
                  ctx.lineWidth = 1.2
                  ctx.save()
                  ctx.translate(centerX, centerY)
                  ctx.rotate(longPeri)
                  ctx.beginPath()
                  for (var j = 0; j <= 64; j++) {
                    var a_ang = j * 2 * pi / 64
                    var ex0 = a * Math.cos(a_ang)
                    var ey0 = b * Math.sin(a_ang)
                    if (j === 0) ctx.moveTo(ex0, ey0)
                    else ctx.lineTo(ex0, ey0)
                  }
                  ctx.stroke()
                  ctx.restore()

                  // Equinox & Solstice markers
                  ctx.globalAlpha = 0.6 * rev
                  ctx.fillStyle = fg.toString()
                  ctx.font = "8px monospace"
                  var markerLongs = [0, 90, 180, 270]
                  var markerLabels = ["SEP 22 (Eq)", "DEC 21 (So)", "MAR 20 (Eq)", "JUN 21 (So)"]
                  for (var i = 0; i < 4; i++) {
                    var nuM = markerLongs[i] * pi / 180 - longPeri
                    var rM = a * (1 - e * e) / (1 + e * Math.cos(nuM))
                    var angM = longPeri + nuM
                    var ax = cx + rM * Math.cos(angM)
                    var ay = cy + rM * Math.sin(angM)

                    ctx.beginPath()
                    ctx.arc(ax, ay, 2.5, 0, 2 * pi)
                    ctx.fill()

                    if (markerLongs[i] === 0) {
                      ctx.textAlign = "left"
                      ctx.fillText(markerLabels[i], ax + 7, ay + 3)
                    } else if (markerLongs[i] === 180) {
                      ctx.textAlign = "right"
                      ctx.fillText(markerLabels[i], ax - 7, ay + 3)
                    } else if (markerLongs[i] === 270) {
                      ctx.textAlign = "center"
                      ctx.fillText(markerLabels[i], ax, ay - 7)
                    } else {
                      ctx.textAlign = "center"
                      ctx.fillText(markerLabels[i], ax, ay + 13)
                    }
                  }

                  // Earth Position (Keplerian with smooth opening sweep)
                  var now = sunEarthCanvas.simDate
                  var j2000 = new Date(Date.UTC(2000, 0, 1, 12, 0, 0))
                  var d = (now - j2000) / 86400000
                  var L = ((100.46 + (360 / 365.25) * d) % 360 + 360) % 360
                  var M = (L * pi / 180) - longPeri

                  var E = M
                  for (var k = 0; k < 5; k++) {
                    E = E - (E - e * Math.sin(E) - M) / (1 - e * Math.cos(E))
                  }
                  var nu = 2 * Math.atan2(Math.sqrt(1 + e) * Math.sin(E / 2), Math.sqrt(1 - e) * Math.cos(E / 2))
                  var animNu = nu - 0.48 * (1 - rev)
                  var r_dist = a * (1 - e * e) / (1 + e * Math.cos(animNu))
                  var ang = longPeri + animNu
                  var ex = cx + r_dist * Math.cos(ang)
                  var ey = cy + r_dist * Math.sin(ang)

                  // Subtle orbital trail behind Earth
                  ctx.globalAlpha = 0.45 * rev
                  ctx.strokeStyle = "#4a90e2"
                  ctx.lineWidth = 1.6
                  ctx.beginPath()
                  for (var t = 0; t <= 16; t++) {
                    var trailNu = animNu - (t / 16) * 0.42
                    var tr = a * (1 - e * e) / (1 + e * Math.cos(trailNu))
                    var ta = longPeri + trailNu
                    var tx = cx + tr * Math.cos(ta)
                    var ty = cy + tr * Math.sin(ta)
                    if (t === 0) ctx.moveTo(tx, ty)
                    else ctx.lineTo(tx, ty)
                  }
                  ctx.stroke()

                  // Subtle Sun-Earth radius vector
                  ctx.globalAlpha = 0.16 * rev
                  ctx.strokeStyle = fg.toString()
                  ctx.lineWidth = 0.8
                  ctx.beginPath()
                  ctx.moveTo(cx, cy)
                  ctx.lineTo(ex, ey)
                  ctx.stroke()

                  // Earth marker + subtle halo
                  ctx.globalAlpha = 0.28 * rev
                  ctx.fillStyle = "#4a90e2"
                  ctx.beginPath()
                  ctx.arc(ex, ey, 9.5, 0, 2 * pi)
                  ctx.fill()

                  ctx.globalAlpha = 1
                  ctx.fillStyle = "#4a90e2"
                  ctx.beginPath()
                  ctx.arc(ex, ey, 5.2, 0, 2 * pi)
                  ctx.fill()

                  ctx.fillStyle = fg.toString()
                  ctx.font = "8px monospace"
                  ctx.textAlign = "left"
                  ctx.fillText("EARTH", ex + 8, ey + 3)

                  // Sun (fixed 0..1 normalized RGBA golden corona!)
                  var coronaR = 14 + 10 * rev
                  var sunRad = ctx.createRadialGradient(cx, cy, 0, cx, cy, coronaR)
                  sunRad.addColorStop(0, Qt.rgba(1.0, 0.84, 0.35, 0.82 * rev).toString())
                  sunRad.addColorStop(0.5, Qt.rgba(1.0, 0.72, 0.22, 0.26 * rev).toString())
                  sunRad.addColorStop(1, Qt.rgba(1.0, 0.72, 0.22, 0.0).toString())
                  ctx.fillStyle = sunRad
                  ctx.beginPath()
                  ctx.arc(cx, cy, coronaR, 0, 2 * pi)
                  ctx.fill()

                  ctx.fillStyle = "#ffd154"
                  ctx.beginPath()
                  ctx.arc(cx, cy, 4.8, 0, 2 * pi)
                  ctx.fill()

                  ctx.globalAlpha = 0.35
                  ctx.fillStyle = fg.toString()
                  ctx.textAlign = "left"
                  ctx.fillText("EARTH ORBIT", 10, 18)
                }
              }
            }

            // 3. Natural Earth Day/Night Projection
            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.preferredWidth: 1
              Layout.preferredHeight: 1
              opacity: root.quad2Reveal
              scale: 0.965 + 0.035 * root.quad2Reveal

              Canvas {
                id: flatMapCanvas
                anchors.fill: parent
                renderTarget: Canvas.Image

                property real earthRot: root.simEarthRotation
                property real declDeg: root.simSolarDeclination
                property real rev: root.revealProgress
                property color fgColor: root.fb
                property bool geoReady: root.geometryReady

                onEarthRotChanged: if (panel.visible) requestPaint()
                onDeclDegChanged: if (panel.visible) requestPaint()
                onRevChanged: if (panel.visible) requestPaint()
                onFgColorChanged: if (panel.visible) requestPaint()
                onGeoReadyChanged: if (panel.visible) requestPaint()
                onWidthChanged: if (panel.visible) requestPaint()
                onHeightChanged: if (panel.visible) requestPaint()

                onPaint: {
                  if (!panel.visible || width <= 0 || height <= 0) return
                  var ctx = getContext("2d")
                  ctx.reset()
                  ctx.clearRect(0, 0, width, height)

                  var mapY = height / 2
                  var mapX = width / 2
                  var pi = Math.PI
                  var fg = flatMapCanvas.fgColor
                  var rev = flatMapCanvas.rev
                  var scale = Math.min(width / (2 * pi * 0.8707), height / (pi * 0.96)) * 0.88

                  if (!root.geoPolys || root.geoPolys.length === 0) return

                  var project = function(lon, lat) {
                    var r = lat * lat, e = r * r
                    var nx = lon * (0.8707 - 0.131979 * r + e * (e * (0.003971 * r - 0.001529 * e) - 0.013791))
                    var ny = lat * (1.007226 + r * (0.015085 + e * (0.028874 * r - 0.044475 - 0.005916 * e)))
                    return [mapX + nx * scale, mapY - ny * scale]
                  }

                  var addMapBoundary = function() {
                    var first = true
                    for (var latD = 90; latD >= -90; latD -= 3) {
                      var pt = project(pi, latD * pi / 180)
                      if (first) { ctx.moveTo(pt[0], pt[1]); first = false }
                      else ctx.lineTo(pt[0], pt[1])
                    }
                    for (var lonD = 180; lonD >= -180; lonD -= 6) {
                      var pt2 = project(lonD * pi / 180, -pi / 2)
                      ctx.lineTo(pt2[0], pt2[1])
                    }
                    for (var latD2 = -90; latD2 <= 90; latD2 += 3) {
                      var pt3 = project(-pi, latD2 * pi / 180)
                      ctx.lineTo(pt3[0], pt3[1])
                    }
                    for (var lonD2 = -180; lonD2 <= 180; lonD2 += 6) {
                      var pt4 = project(lonD2 * pi / 180, pi / 2)
                      ctx.lineTo(pt4[0], pt4[1])
                    }
                    ctx.closePath()
                  }

                  // Ocean background + outline
                  ctx.beginPath()
                  addMapBoundary()
                  ctx.fillStyle = Qt.rgba(fg.r, fg.g, fg.b, 0.07).toString()
                  ctx.fill()
                  ctx.strokeStyle = Qt.rgba(fg.r, fg.g, fg.b, 0.35).toString()
                  ctx.lineWidth = 1.1
                  ctx.stroke()

                  // Subtle Equator + Tropics graticule
                  ctx.save()
                  ctx.beginPath()
                  addMapBoundary()
                  ctx.clip()

                  var drawLatLine = function(latDeg, alpha) {
                    var lr = latDeg * pi / 180
                    ctx.beginPath()
                    for (var s = 0; s <= 40; s++) {
                      var l = -pi + (s / 40) * 2 * pi
                      var p = project(l, lr)
                      if (s === 0) ctx.moveTo(p[0], p[1])
                      else ctx.lineTo(p[0], p[1])
                    }
                    ctx.strokeStyle = Qt.rgba(fg.r, fg.g, fg.b, alpha * rev).toString()
                    ctx.lineWidth = 0.6
                    ctx.stroke()
                  }
                  drawLatLine(0, 0.22)
                  drawLatLine(23.44, 0.11)
                  drawLatLine(-23.44, 0.11)

                  // Continents
                  ctx.fillStyle = Qt.rgba(fg.r, fg.g, fg.b, 0.62).toString()
                  for (var i = 0; i < root.geoPolys.length; i++) {
                    var pts = root.geoPolys[i]
                    ctx.beginPath()
                    var started = false
                    for (var c = 0; c < pts.length; c += 2) {
                      var pt = project(pts[c], pts[c + 1])
                      if (!started) { ctx.moveTo(pt[0], pt[1]); started = true }
                      else ctx.lineTo(pt[0], pt[1])
                    }
                    ctx.fill()
                  }

                  // Day/night terminator
                  var declination = flatMapCanvas.declDeg * pi / 180
                  if (Math.abs(declination) < 0.0001) declination = 0.0001
                  var hourFrac = flatMapCanvas.earthRot / 360
                  var lonSun = (0.5 - hourFrac) * 2 * pi
                  if (lonSun > pi) lonSun -= 2 * pi
                  if (lonSun < -pi) lonSun += 2 * pi

                  var steps = 140
                  var startLat = 0, endLat = 0
                  var termPts = []
                  ctx.beginPath()
                  for (var t = 0; t <= steps; t++) {
                    var lon = -pi + (t / steps) * 2 * pi
                    var lat = Math.atan(-Math.cos(lon - lonSun) / Math.tan(declination))
                    if (t === 0) startLat = lat
                    if (t === steps) endLat = lat
                    var ptT = project(lon, lat)
                    termPts.push(ptT)
                    if (t === 0) ctx.moveTo(ptT[0], ptT[1])
                    else ctx.lineTo(ptT[0], ptT[1])
                  }

                  var latSteps = 24
                  if (declination > 0) {
                    for (var j = 0; j <= latSteps; j++) {
                      var ptA = project(pi, endLat + (j / latSteps) * (-pi / 2 - endLat))
                      ctx.lineTo(ptA[0], ptA[1])
                    }
                    for (var j2 = 0; j2 <= steps; j2++) {
                      var ptB = project(pi - (j2 / steps) * 2 * pi, -pi / 2)
                      ctx.lineTo(ptB[0], ptB[1])
                    }
                    for (var j3 = 0; j3 <= latSteps; j3++) {
                      var ptC = project(-pi, -pi / 2 + (j3 / latSteps) * (startLat - (-pi / 2)))
                      ctx.lineTo(ptC[0], ptC[1])
                    }
                  } else {
                    for (var j4 = 0; j4 <= latSteps; j4++) {
                      var ptD = project(pi, endLat + (j4 / latSteps) * (pi / 2 - endLat))
                      ctx.lineTo(ptD[0], ptD[1])
                    }
                    for (var j5 = 0; j5 <= steps; j5++) {
                      var ptE = project(pi - (j5 / steps) * 2 * pi, pi / 2)
                      ctx.lineTo(ptE[0], ptE[1])
                    }
                    for (var j6 = 0; j6 <= latSteps; j6++) {
                      var ptF = project(-pi, pi / 2 + (j6 / latSteps) * (startLat - pi / 2))
                      ctx.lineTo(ptF[0], ptF[1])
                    }
                  }
                  ctx.closePath()
                  ctx.fillStyle = Qt.rgba(0, 0, 0, 0.44 * rev).toString()
                  ctx.fill()

                  // Subtle twilight line along terminator
                  ctx.beginPath()
                  for (var tp = 0; tp < termPts.length; tp++) {
                    if (tp === 0) ctx.moveTo(termPts[tp][0], termPts[tp][1])
                    else ctx.lineTo(termPts[tp][0], termPts[tp][1])
                  }
                  ctx.strokeStyle = Qt.rgba(1.0, 0.80, 0.42, 0.32 * rev).toString()
                  ctx.lineWidth = 1.0
                  ctx.stroke()

                  // Subsolar point (where Sun is directly overhead)
                  var sunPt = project(lonSun, declination)
                  var subGlow = ctx.createRadialGradient(sunPt[0], sunPt[1], 0, sunPt[0], sunPt[1], 10 * rev)
                  subGlow.addColorStop(0, Qt.rgba(1.0, 0.85, 0.35, 0.75 * rev).toString())
                  subGlow.addColorStop(1, Qt.rgba(1.0, 0.85, 0.35, 0.0).toString())
                  ctx.fillStyle = subGlow
                  ctx.beginPath()
                  ctx.arc(sunPt[0], sunPt[1], 10 * rev, 0, 2 * pi)
                  ctx.fill()

                  ctx.fillStyle = "#ffd154"
                  ctx.globalAlpha = rev
                  ctx.beginPath()
                  ctx.arc(sunPt[0], sunPt[1], 2.5, 0, 2 * pi)
                  ctx.fill()

                  ctx.restore()

                  ctx.globalAlpha = 0.35
                  ctx.fillStyle = fg.toString()
                  ctx.font = "8px monospace"
                  ctx.textAlign = "left"
                  ctx.fillText("NATURAL EARTH", 10, 18)
                }
              }
            }

            // 4. Solar System Orrery
            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.preferredWidth: 1
              Layout.preferredHeight: 1
              opacity: root.quad3Reveal
              scale: 0.965 + 0.035 * root.quad3Reveal

              Canvas {
                id: solarSystemCanvas
                anchors.fill: parent
                renderTarget: Canvas.Image

                property var simDate: root.simulatedDate
                property real rev: root.revealProgress
                property color fgColor: root.fb

                onSimDateChanged: if (panel.visible) requestPaint()
                onRevChanged: if (panel.visible) requestPaint()
                onFgColorChanged: if (panel.visible) requestPaint()
                onWidthChanged: if (panel.visible) requestPaint()
                onHeightChanged: if (panel.visible) requestPaint()

                onPaint: {
                  if (!panel.visible || width <= 0 || height <= 0) return
                  var ctx = getContext("2d")
                  ctx.reset()
                  ctx.clearRect(0, 0, width, height)
                  var cx = width / 2
                  var cy = height / 2
                  var pi = Math.PI
                  var fg = solarSystemCanvas.fgColor
                  var rev = solarSystemCanvas.rev
                  var maxR = Math.min(width, height) * 0.43
                  var radiusScale = (maxR / 135) * (0.94 + 0.06 * rev)

                  var now = solarSystemCanvas.simDate
                  var j2000 = new Date(Date.UTC(2000, 0, 1, 12, 0, 0))
                  var d = (now - j2000) / 86400000

                  var planets = [
                    { name: "Me", period: 87.97,   L0: 252.25, a: 14,  e: 0.2056, w: 77.45,  c: "#a8a8a8", r: 2.3 },
                    { name: "V",  period: 224.70,  L0: 181.98, a: 23,  e: 0.0067, w: 131.53, c: "#e3bb76", r: 2.7 },
                    { name: "E",  period: 365.25,  L0: 100.46, a: 33,  e: 0.0167, w: 102.94, c: "#4a90e2", r: 3.0 },
                    { name: "Ma", period: 686.98,  L0: 355.45, a: 46,  e: 0.0934, w: 336.04, c: "#e26a4a", r: 2.6 },
                    { name: "J",  period: 4332.59, L0: 34.40,  a: 70,  e: 0.0484, w: 14.75,  c: "#d1a364", r: 4.2 },
                    { name: "S",  period: 10759.22,L0: 49.94,  a: 94,  e: 0.0555, w: 92.43,  c: "#ebd9a4", r: 3.6, ring: true },
                    { name: "U",  period: 30685.4, L0: 313.23, a: 114, e: 0.0463, w: 170.96, c: "#95dce3", r: 3.1 },
                    { name: "N",  period: 60189.0, L0: -55.12, a: 133, e: 0.0094, w: 44.97,  c: "#5b7cfa", r: 3.0 }
                  ]

                  // Orbits
                  ctx.globalAlpha = 0.16 * rev
                  ctx.lineWidth = 0.6
                  ctx.strokeStyle = fg.toString()

                  for (var i = 0; i < planets.length; i++) {
                    var p = planets[i]
                    var pa = p.a * radiusScale
                    var longPeri = p.w * pi / 180
                    var pb = pa * Math.sqrt(1 - p.e * p.e)
                    var centerX = cx - pa * p.e * Math.cos(longPeri)
                    var centerY = cy - pa * p.e * Math.sin(longPeri)

                    ctx.save()
                    ctx.translate(centerX, centerY)
                    ctx.rotate(longPeri)
                    ctx.beginPath()
                    for (var j = 0; j <= 64; j++) {
                      var a_ang = j * 2 * pi / 64
                      var ex = pa * Math.cos(a_ang)
                      var ey = pb * Math.sin(a_ang)
                      if (j === 0) ctx.moveTo(ex, ey)
                      else ctx.lineTo(ex, ey)
                    }
                    ctx.stroke()
                    ctx.restore()
                  }

                  // Planets + trails + Saturn ring
                  ctx.font = "7px monospace"
                  ctx.textAlign = "left"
                  for (var idx = 0; idx < planets.length; idx++) {
                    var pl = planets[idx]
                    var sa = pl.a * radiusScale
                    var lp = pl.w * pi / 180
                    var L = ((pl.L0 + (360 / pl.period) * d) % 360 + 360) % 360
                    var M = (L * pi / 180) - lp
                    // Normalize M to [-pi, pi] for clean Newton convergence
                    M = ((M + pi) % (2 * pi) + 2 * pi) % (2 * pi) - pi

                    var E = M
                    for (var k = 0; k < 6; k++) {
                      E = E - (E - pl.e * Math.sin(E) - M) / (1 - pl.e * Math.cos(E))
                    }
                    var nu = 2 * Math.atan2(Math.sqrt(1 + pl.e) * Math.sin(E / 2), Math.sqrt(1 - pl.e) * Math.cos(E / 2))
                    var animNu = nu - (0.35 + idx * 0.04) * (1 - rev)
                    var r_dist = sa * (1 - pl.e * pl.e) / (1 + pl.e * Math.cos(animNu))
                    var ang = lp + animNu
                    var px = cx + r_dist * Math.cos(ang)
                    var py = cy + r_dist * Math.sin(ang)

                    // Subtle orbital motion trail
                    ctx.globalAlpha = 0.30 * rev
                    ctx.strokeStyle = pl.c
                    ctx.lineWidth = 1.1
                    ctx.beginPath()
                    for (var t = 0; t <= 10; t++) {
                      var tNu = animNu - (t / 10) * 0.28
                      var tr = sa * (1 - pl.e * pl.e) / (1 + pl.e * Math.cos(tNu))
                      var ta = lp + tNu
                      var tx = cx + tr * Math.cos(ta)
                      var ty = cy + tr * Math.sin(ta)
                      if (t === 0) ctx.moveTo(tx, ty)
                      else ctx.lineTo(tx, ty)
                    }
                    ctx.stroke()

                    // Saturn ring
                    if (pl.ring) {
                      ctx.save()
                      ctx.globalAlpha = 0.72 * rev
                      ctx.translate(px, py)
                      ctx.rotate(-0.35)
                      ctx.strokeStyle = pl.c
                      ctx.lineWidth = 1.0
                      ctx.beginPath()
                      ctx.ellipse(-pl.r * 1.9, -pl.r * 0.65, pl.r * 3.8, pl.r * 1.3)
                      ctx.stroke()
                      ctx.restore()
                    }

                    ctx.globalAlpha = 1
                    ctx.fillStyle = pl.c
                    ctx.beginPath()
                    ctx.arc(px, py, pl.r, 0, 2 * pi)
                    ctx.fill()

                    ctx.globalAlpha = 0.65 * rev
                    ctx.fillStyle = fg.toString()
                    ctx.fillText(pl.name, px + pl.r + 3, py + 2.5)
                  }

                  // Sun (fixed 0..1 normalized RGBA golden corona!)
                  ctx.globalAlpha = 1
                  var sGlowR = 8 + 6 * rev
                  var sunRad = ctx.createRadialGradient(cx, cy, 0, cx, cy, sGlowR)
                  sunRad.addColorStop(0, Qt.rgba(1.0, 0.84, 0.35, 0.85 * rev).toString())
                  sunRad.addColorStop(1, Qt.rgba(1.0, 0.72, 0.22, 0.0).toString())
                  ctx.fillStyle = sunRad
                  ctx.beginPath()
                  ctx.arc(cx, cy, sGlowR, 0, 2 * pi)
                  ctx.fill()
                  ctx.fillStyle = "#ffd154"
                  ctx.beginPath()
                  ctx.arc(cx, cy, 3.2, 0, 2 * pi)
                  ctx.fill()

                  ctx.globalAlpha = 0.35
                  ctx.fillStyle = fg.toString()
                  ctx.font = "8px monospace"
                  ctx.textAlign = "left"
                  ctx.fillText("SOLAR SYSTEM", 10, 18)
                }
              }
            }
          }

          // Corner reticle decorations
          PlainLabel { anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 6; text: "┌"; font.pixelSize: 10; color: root.fb; opacity: 0.25 * root.crosshairReveal }
          PlainLabel { anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 6; text: "┐"; font.pixelSize: 10; color: root.fb; opacity: 0.25 * root.crosshairReveal }
          PlainLabel { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 6; text: "└"; font.pixelSize: 10; color: root.fb; opacity: 0.25 * root.crosshairReveal }
          PlainLabel { anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 6; text: "┘"; font.pixelSize: 10; color: root.fb; opacity: 0.25 * root.crosshairReveal }

          // Animated crosshair separator lines expanding outward from center
          Rectangle {
            anchors.centerIn: parent
            width: Math.max(0, (parent.width - 40) * root.crosshairReveal)
            height: 1
            color: Util.alpha(root.fb, 0.14 * root.crosshairReveal)
          }
          Rectangle {
            anchors.centerIn: parent
            width: 1
            height: Math.max(0, (parent.height - 40) * root.crosshairReveal)
            color: Util.alpha(root.fb, 0.14 * root.crosshairReveal)
          }

          // Dashboard title
          PlainLabel {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 6
            text: "SYSTEMS DASHBOARD"
            font.pixelSize: 7
            font.letterSpacing: 3
            color: root.fb
            opacity: 0.32 * root.crosshairReveal
          }
        }

        // ─── Data readouts (3 Sections with Hover Tooltips) ───
        RowLayout {
          id: metricsSection
          Layout.fillWidth: true
          Layout.leftMargin: Style.space(6)
          Layout.rightMargin: Style.space(6)
          spacing: Style.space(18)
          opacity: root.metricsReveal
          transform: Translate { y: (1 - root.metricsReveal) * Style.space(6) }

          // Column 1: Lunar Cycle
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(2)

            MetricRow {
              title: "AGE"
              value: root.simPhaseAgeDays.toFixed(1) + "d"
              suffix: "/ " + root.simSynodic.toFixed(1) + "d"
              tipText: "Lunar age: Days elapsed since the last New Moon within the ~29.53-day synodic cycle."
            }
            MetricRow {
              title: "→ FULL"
              value: root.simDaysToFull.toFixed(1) + " days"
              tipText: "Next Full Moon: Time remaining until full illumination (100% phase)."
            }
            MetricRow {
              title: "→ NEW"
              value: root.simDaysToNew.toFixed(1) + " days"
              tipText: "Next New Moon: Time remaining until the next New Moon and start of the next synodic cycle."
            }
            MetricRow {
              title: "LUNATION"
              value: "#" + root.simLunation
              dimValue: true
              tipText: "Brown Lunation Number: Official astronomical count of consecutive lunar cycles since January 1923."
            }
          }

          // Vertical separator
          Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Util.alpha(root.fb, 0.12)
          }

          // Column 2: Ephemeris & Dynamics
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(2)

            MetricRow {
              title: "ILLUMINATION"
              value: root.simIllumination.toFixed(1) + "%"
              tipText: "Illumination percentage: Fraction of the Moon's visible disc receiving direct sunlight as seen from Earth."
            }
            MetricRow {
              title: "DISTANCE"
              value: I18n.formatNumber(root.simDistanceKm, 0) + " km"
              tipText: "Earth-Moon distance: Geocentric orbital distance (~363,300 km at perigee to ~405,500 km at apogee)."
            }
            MetricRow {
              title: "SOLAR DECL."
              value: (root.simSolarDeclination >= 0 ? "+" : "") + root.simSolarDeclination.toFixed(1) + "°"
              tipText: "Solar declination: Angular position of the Sun north (+) or south (-) of the celestial equator (governs Earth's seasons)."
            }
            MetricRow {
              title: "NEXT EVENT"
              value: root.simNextEvent
              dimValue: true
              tipText: "Next astronomical milestone: Upcoming equinox or solstice marking the seasonal shift on Earth."
            }
          }

          // Vertical separator 2
          Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Util.alpha(root.fb, 0.12)
          }

          // Section 3: Earth Axial Tilt & Seasons
          Rectangle {
            Layout.preferredWidth: Style.space(256)
            Layout.fillHeight: true
            radius: Math.min(Style.cornerRadius > 0 ? Style.cornerRadius : Style.space(6), Style.space(6))
            color: tiltMa.containsMouse ? Util.alpha(root.fb, 0.08) : Util.alpha(root.fb, 0.03)
            border.width: 1
            border.color: Util.alpha(root.fb, 0.15)

            Behavior on color { ColorAnimation { duration: Style.duration(120) } }

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(6)
              spacing: Style.space(8)

              Canvas {
                id: tiltCanvas
                Layout.preferredWidth: Style.space(88)
                Layout.preferredHeight: Style.space(74)
                renderTarget: Canvas.Image

                property real decl: root.simSolarDeclination
                property real rev: root.revealProgress
                property color fgColor: root.fb

                onDeclChanged: if (panel.visible) requestPaint()
                onRevChanged: if (panel.visible) requestPaint()
                onFgColorChanged: if (panel.visible) requestPaint()
                onWidthChanged: if (panel.visible) requestPaint()
                onHeightChanged: if (panel.visible) requestPaint()

                onPaint: {
                  if (!panel.visible || width <= 0 || height <= 0) return
                  var ctx = getContext("2d")
                  ctx.reset()
                  ctx.clearRect(0, 0, width, height)

                  var cx = width / 2 + 6
                  var cy = height / 2
                  var R = Math.min(22, Math.min(width, height) * 0.30)
                  var pi = Math.PI
                  var fg = tiltCanvas.fgColor
                  var rev = tiltCanvas.rev

                  // Smoothly tilt from vertical into current solar declination on open
                  var tiltRad = (tiltCanvas.decl * rev * pi / 180)

                  // 1. Sunlight rays from left
                  ctx.strokeStyle = Qt.rgba(1.0, 0.80, 0.0, 0.72 * rev).toString()
                  ctx.lineWidth = 1
                  for (var i = -1; i <= 1; i++) {
                    var ly = cy + i * 11
                    ctx.beginPath()
                    ctx.moveTo(4, ly)
                    ctx.lineTo(cx - R - 6, ly)
                    ctx.lineTo(cx - R - 9, ly - 2)
                    ctx.moveTo(cx - R - 6, ly)
                    ctx.lineTo(cx - R - 9, ly + 2)
                    ctx.stroke()
                  }

                  // 2. Earth Globe
                  ctx.save()
                  ctx.beginPath()
                  ctx.arc(cx, cy, R, 0, 2 * pi)
                  ctx.clip()

                  ctx.fillStyle = Qt.rgba(fg.r, fg.g, fg.b, 0.12).toString()
                  ctx.fillRect(cx - R, cy - R, 2 * R, 2 * R)

                  var litGrad = ctx.createLinearGradient(cx - R, cy, cx + R * 0.2, cy)
                  litGrad.addColorStop(0, Qt.rgba(fg.r, fg.g, fg.b, 0.75).toString())
                  litGrad.addColorStop(1, Qt.rgba(fg.r, fg.g, fg.b, 0.25).toString())
                  ctx.fillStyle = litGrad
                  ctx.beginPath()
                  ctx.arc(cx, cy, R, pi / 2, 3 * pi / 2, false)
                  ctx.fill()

                  ctx.fillStyle = Qt.rgba(0, 0, 0, 0.62).toString()
                  ctx.beginPath()
                  ctx.arc(cx, cy, R, -pi / 2, pi / 2, false)
                  ctx.fill()
                  ctx.restore()

                  // 3. Equator
                  ctx.save()
                  ctx.translate(cx, cy)
                  ctx.rotate(-tiltRad)
                  ctx.strokeStyle = Qt.rgba(fg.r, fg.g, fg.b, 0.42).toString()
                  ctx.lineWidth = 0.8
                  ctx.beginPath()
                  ctx.ellipse(-R, -R * 0.18, 2 * R, 2 * R * 0.18)
                  ctx.stroke()
                  ctx.restore()

                  // 4. Tilted rotational axis
                  var axisLen = R + 9
                  var nx = cx - Math.sin(tiltRad) * axisLen
                  var ny = cy - Math.cos(tiltRad) * axisLen
                  var sx = cx + Math.sin(tiltRad) * axisLen
                  var sy = cy + Math.cos(tiltRad) * axisLen

                  ctx.strokeStyle = Qt.rgba(fg.r, fg.g, fg.b, 0.72).toString()
                  ctx.lineWidth = 1.2
                  ctx.beginPath()
                  ctx.moveTo(sx, sy)
                  ctx.lineTo(nx, ny)
                  ctx.stroke()

                  ctx.fillStyle = "#ff6b6b"
                  ctx.beginPath(); ctx.arc(nx, ny, 2.4, 0, 2 * pi); ctx.fill()
                  ctx.fillStyle = "#4dabf7"
                  ctx.beginPath(); ctx.arc(sx, sy, 2.4, 0, 2 * pi); ctx.fill()

                  ctx.fillStyle = fg.toString()
                  ctx.font = "8px monospace"
                  ctx.textAlign = "center"
                  ctx.fillText("N", nx + (tiltRad >= 0 ? -5 : 5), ny + 1)
                  ctx.fillText("S", sx + (tiltRad >= 0 ? 5 : -5), sy + 3)

                  ctx.strokeStyle = Qt.rgba(fg.r, fg.g, fg.b, 0.45).toString()
                  ctx.lineWidth = 0.8
                  ctx.beginPath()
                  ctx.arc(cx, cy, R, 0, 2 * pi)
                  ctx.stroke()
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.space(3)

                PlainLabel {
                  text: "AXIAL TILT 23.44°"
                  font.pixelSize: Math.max(8, Style.font.caption - 2)
                  font.letterSpacing: 1
                  font.weight: Font.Bold
                  color: Color.accent
                }

                RowLayout {
                  spacing: Style.space(4)
                  PlainLabel { text: "NORTH:"; font.pixelSize: Math.max(9, Style.font.caption - 1); color: root.dimFb }
                  PlainLabel { text: root.simNorthSeason; font.pixelSize: Math.max(9, Style.font.caption - 1); font.weight: Font.DemiBold; color: root.fb }
                }

                RowLayout {
                  spacing: Style.space(4)
                  PlainLabel { text: "SOUTH:"; font.pixelSize: Math.max(9, Style.font.caption - 1); color: root.dimFb }
                  PlainLabel { text: root.simSouthSeason; font.pixelSize: Math.max(9, Style.font.caption - 1); font.weight: Font.DemiBold; color: root.fb }
                }

                PlainLabel {
                  text: "Solar Decl: " + (root.simSolarDeclination >= 0 ? "+" : "") + root.simSolarDeclination.toFixed(1) + "°"
                  font.pixelSize: Math.max(8, Style.font.caption - 2)
                  color: root.dimFb
                }
              }
            }

            ToolTip {
              visible: tiltMa.containsMouse
              delay: 180
              timeout: 6000
              contentItem: Text {
                textFormat: Text.PlainText
                text: "Earth's 23.44° axial tilt relative to its orbital plane causes the seasons. The hemisphere tilted toward the Sun receives direct rays and longer days (Summer), while the opposite hemisphere experiences Winter."
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Color.tooltip.text
                wrapMode: Text.WordWrap
              }
              background: Rectangle {
                color: Color.tooltip.background
                border.color: Color.tooltip.border
                border.width: 1
                radius: Math.min(Style.cornerRadius > 0 ? Style.cornerRadius : Style.space(6), Style.space(6))
              }
            }

            MouseArea {
              id: tiltMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
            }
          }
        }

        // ─── Footer ───
        Rectangle {
          Layout.fillWidth: true
          Layout.leftMargin: Style.space(4)
          Layout.rightMargin: Style.space(4)
          height: 1
          color: Util.alpha(root.fb, 0.14)
          opacity: root.footerReveal
        }

        RowLayout {
          Layout.fillWidth: true
          Layout.leftMargin: Style.space(8)
          Layout.rightMargin: Style.space(8)
          Layout.bottomMargin: Style.space(2)
          opacity: root.footerReveal

          PlainLabel {
            text: root.playing ? "▶ TIMELAPSE" : (root.isLive ? "● LIVE" : "◐ SIMULATED")
            font.pixelSize: Style.font.caption
            font.weight: Font.DemiBold
            color: root.isLive || root.playing ? Color.accent : Color.urgent
          }

          Item { Layout.fillWidth: true }

          PlainLabel {
            text: "←/→ ±1d · ↑/↓ ±1w · Space play · R live · Esc close"
            font.pixelSize: Math.max(8, Style.font.caption - 1)
            color: root.dimFb
          }
        }
      }
    }
  }
}
