import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "WorldGeoJSON.js" as Geo


Panel {
  id: root
  moduleName: "nestor.lunar-tracker"
  ipcTarget: "nestor.lunar-tracker"

  readonly property string home: Quickshell.env("HOME")

  readonly property color fb: root.bar ? root.bar.foreground : Color.foreground
  readonly property color dimFb: Qt.rgba(fb.r, fb.g, fb.b, 0.5)

  property var worldFeatures: []
  property var geoPolys: []

  property real timeOffsetDays: 0.0
  property double currentTimestamp: Date.now()

  Timer {
    id: clockTicker
    interval: 1000
    running: true
    repeat: true
    onTriggered: {
      root.currentTimestamp = Date.now()
    }
  }

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
    var now = root.simulatedDate;
    var start = new Date(now.getFullYear(), 0, 0);
    var diff = now - start;
    return Math.floor(diff / 86400000);
  }
  readonly property real simSolarDeclination: -23.44 * Math.cos((simDayOfYear + 10) * 2 * Math.PI / 365)
  readonly property string simNorthSeason: {
    var d = root.simDayOfYear;
    if (d >= 79 && d < 172) return "Spring 🌱";
    if (d >= 172 && d < 265) return "Summer ☀️";
    if (d >= 265 && d < 355) return "Autumn 🍂";
    return "Winter ❄️";
  }
  readonly property string simSouthSeason: {
    var d = root.simDayOfYear;
    if (d >= 79 && d < 172) return "Autumn 🍂";
    if (d >= 172 && d < 265) return "Winter ❄️";
    if (d >= 265 && d < 355) return "Spring 🌱";
    return "Summer ☀️";
  }

  function getPhaseEmoji(f) {
    if (f < 0.0312 || f >= 0.9688) return "🌑";
    if (f < 0.2188) return "🌒";
    if (f < 0.2812) return "🌓";
    if (f < 0.4688) return "🌔";
    if (f < 0.5312) return "🌕";
    if (f < 0.7188) return "🌖";
    if (f < 0.7812) return "🌗";
    return "🌘";
  }

  function getPhaseName(f) {
    if (f < 0.0312 || f >= 0.9688) return "New Moon";
    if (f < 0.2188) return "Waxing Crescent";
    if (f < 0.2812) return "First Quarter";
    if (f < 0.4688) return "Waxing Gibbous";
    if (f < 0.5312) return "Full Moon";
    if (f < 0.7188) return "Waning Gibbous";
    if (f < 0.7812) return "Last Quarter";
    return "Waning Crescent";
  }

  function adjustTimeOffset(deltaDays) {
    var next = root.timeOffsetDays + deltaDays;
    if (next < -30.0) next = -30.0;
    if (next > 30.0) next = 30.0;
    if (Math.abs(next) < 0.01) next = 0.0;
    root.timeOffsetDays = next;
  }

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

  Component.onCompleted: {
    root.worldFeatures = Geo.data.features
    root.precomputeGeometry()
  }

  function precomputeGeometry() {
    root.geoPolys = []
    for (var i = 0; i < root.worldFeatures.length; i++) {
      var feat = root.worldFeatures[i]
      if (!feat.geometry) continue
      if (feat.geometry.type === "Polygon") {
        root.flattenRings(feat.geometry.coordinates)
      } else if (feat.geometry.type === "MultiPolygon") {
        for (var p = 0; p < feat.geometry.coordinates.length; p++) {
          root.flattenRings(feat.geometry.coordinates[p])
        }
      }
    }
  }

  function flattenRings(rings) {
    for (var r = 0; r < rings.length; r++) {
      var coords = rings[r]
      var pts = []
      for (var c = 0; c < coords.length; c++) {
        pts.push(coords[c][0] * Math.PI / 180)
        pts.push(coords[c][1] * Math.PI / 180)
      }
      root.geoPolys.push(pts)
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
    opticalSize: 10

    iconComponent: Component {
      Item {
        anchors.fill: parent

        Canvas {
          id: moonIcon
          anchors.fill: parent
          renderTarget: Canvas.Image

          property real phase: root.phaseFraction

          onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            var cx = width / 2
            var cy = height / 2
            var r = Math.min(width, height) / 2 - 1
            var pi = Math.PI
            var f = moonIcon.phase

            // Base outline (dark disk)
            ctx.fillStyle = Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.15).toString()
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, 2 * pi)
            ctx.fill()

            // Fill illuminated part
            var illumFrac = (1 - Math.cos(2 * pi * f)) / 2
            if (illumFrac > 0.01) {
              ctx.fillStyle = root.fb.toString()
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
            ctx.strokeStyle = root.fb.toString()
            ctx.lineWidth = 1.1
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, 2 * pi)
            ctx.stroke()
          }

          onPhaseChanged: requestPaint()
        }
      }
    }

    onPressed: function(b) {
      if (root.opened) root.close()
      else {
        root.currentTimestamp = Date.now()
        root.open()
      }
    }
  }

  // ─── Panel popup ───
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: 880
    contentHeight: panel.fittedContentHeight(rootColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      onCloseRequested: root.close()
    }

    ColumnLayout {
      id: rootColumn
      width: parent.width
      spacing: Style.space(6)

      // ─── Header: Scrubber Slider ───
      ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Style.space(16)
        Layout.rightMargin: Style.space(16)
        Layout.topMargin: Style.space(10)
        Layout.bottomMargin: 0
        spacing: Style.space(5)

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(10)

          Label {
            text: "✦ COSMIC DIAL"
            font.family: "monospace"
            font.pixelSize: Style.font.caption
            font.weight: Font.DemiBold
            font.letterSpacing: 2
            color: root.fb
          }

          Rectangle {
            implicitWidth: badgeRow.implicitWidth + 20
            implicitHeight: 22
            radius: 11
            color: Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.08)
            border.width: 1
            border.color: Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.2)

            RowLayout {
              id: badgeRow
              anchors.centerIn: parent
              spacing: 6

              Canvas {
                id: headerMoonCanvas
                Layout.preferredWidth: 13
                Layout.preferredHeight: 13
                renderTarget: Canvas.Image

                property real phaseFrac: root.simPhaseFraction
                property real illum: root.simIllumination

                onPhaseFracChanged: requestPaint()
                onIllumChanged: requestPaint()

                onPaint: {
                  var ctx = getContext("2d")
                  ctx.reset()
                  ctx.clearRect(0, 0, width, height)

                  var cx = width / 2
                  var cy = height / 2
                  var R = width / 2 - 1.2
                  var pi = Math.PI

                  // Base dark
                  ctx.fillStyle = "#14171f"
                  ctx.beginPath()
                  ctx.arc(cx, cy, R, 0, 2 * pi)
                  ctx.fill()

                  var darkGrad = ctx.createRadialGradient(cx - R * 0.3, cy - R * 0.3, 0, cx, cy, R)
                  darkGrad.addColorStop(0, "#252b3b")
                  darkGrad.addColorStop(1, "#101217")
                  ctx.fillStyle = darkGrad
                  ctx.beginPath()
                  ctx.arc(cx, cy, R, 0, 2 * pi)
                  ctx.fill()

                  var phaseFrac = root.simPhaseFraction
                  var illumFrac = root.simIllumination / 100.0

                  if (illumFrac > 0.01) {
                    ctx.save()
                    ctx.beginPath()
                    ctx.arc(cx, cy, R, 0, 2 * pi)
                    ctx.clip()

                    var litGrad = ctx.createRadialGradient(cx - R * 0.3, cy - R * 0.3, 0, cx, cy, R)
                    litGrad.addColorStop(0, Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.98).toString())
                    litGrad.addColorStop(0.75, Qt.rgba(root.fb.r * 0.88, root.fb.g * 0.90, root.fb.b * 0.94, 0.98).toString())
                    litGrad.addColorStop(1, Qt.rgba(root.fb.r * 0.74, root.fb.g * 0.78, root.fb.b * 0.85, 0.98).toString())
                    ctx.fillStyle = litGrad

                    ctx.beginPath()
                    var steps = 20
                    if (phaseFrac <= 0.5) {
                      ctx.arc(cx, cy, R, -pi / 2, pi / 2, false)
                      var k = Math.cos(2 * pi * phaseFrac)
                      for (var i = 0; i <= steps; i++) {
                        var theta = pi / 2 - (pi * i / steps)
                        var tx = cx + k * R * Math.cos(theta)
                        var ty = cy + R * Math.sin(theta)
                        ctx.lineTo(tx, ty)
                      }
                    } else {
                      ctx.arc(cx, cy, R, pi / 2, 3 * pi / 2, false)
                      var k = -Math.cos(2 * pi * phaseFrac)
                      for (var i = 0; i <= steps; i++) {
                        var theta = -pi / 2 + (pi * i / steps)
                        var tx = cx + k * R * Math.cos(theta)
                        var ty = cy + R * Math.sin(theta)
                        ctx.lineTo(tx, ty)
                      }
                    }
                    ctx.closePath()
                    ctx.fill()
                    ctx.restore()
                  }

                  ctx.strokeStyle = Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.45).toString()
                  ctx.lineWidth = 0.8
                  ctx.beginPath()
                  ctx.arc(cx, cy, R, 0, 2 * pi)
                  ctx.stroke()
                }
              }

              Label {
                id: phaseBadgeText
                text: root.simPhaseName.toUpperCase() + " (" + root.simIllumination.toFixed(0) + "%)"
                font.family: "monospace"
                font.pixelSize: 8
                font.weight: Font.Medium
                color: root.fb
              }
            }
          }

          Item { Layout.fillWidth: true }

          // Simulated Date & Status Badge
          Rectangle {
            implicitWidth: timeBadgeText.implicitWidth + 32
            implicitHeight: 26
            radius: 13
            color: Math.abs(root.timeOffsetDays) < 0.05 ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15) : Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.15)
            border.width: 1
            border.color: Math.abs(root.timeOffsetDays) < 0.05 ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.4) : Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.4)

            RowLayout {
              anchors.centerIn: parent
              spacing: 8

              Rectangle {
                width: 6; height: 6; radius: 3
                color: Math.abs(root.timeOffsetDays) < 0.05 ? Color.accent : Color.urgent
              }

              Label {
                id: timeBadgeText
                text: {
                  var dStr = Qt.formatDateTime(root.simulatedDate, "dd MMM yyyy HH:mm")
                  if (Math.abs(root.timeOffsetDays) < 0.05) {
                    return "LIVE (" + dStr + ")"
                  } else {
                    var sign = root.timeOffsetDays > 0 ? "+" : ""
                    return sign + root.timeOffsetDays.toFixed(1) + "d · " + dStr
                  }
                }
                font.family: "monospace"
                font.pixelSize: 10
                font.weight: Font.Medium
                color: root.fb
              }
            }
          }

          // Reset button when offset active
          Rectangle {
            visible: Math.abs(root.timeOffsetDays) >= 0.05
            implicitWidth: resetBtnText.implicitWidth + 18
            implicitHeight: 24
            radius: 6
            color: resetBtnMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
            border.width: 1
            border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35)

            Label {
              id: resetBtnText
              anchors.centerIn: parent
              text: "⟲ LIVE"
              font.family: "monospace"
              font.pixelSize: 9
              font.weight: Font.Bold
              color: Color.accent
            }

            MouseArea {
              id: resetBtnMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.timeOffsetDays = 0
            }
          }
        }

        // Quick Step buttons row
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(6)

          Label {
            text: "STEP:"
            font.family: "monospace"
            font.pixelSize: 8
            font.weight: Font.Bold
            color: root.dimFb
          }

          // Backward steps
          Repeater {
            model: [
              { label: "-1w", delta: -7.0 },
              { label: "-1d", delta: -1.0 },
              { label: "-12h", delta: -0.5 },
              { label: "-5h", delta: -5/24 },
              { label: "-1h", delta: -1/24 }
            ]
            delegate: Rectangle {
              implicitWidth: stepBackLabel.implicitWidth + 12
              implicitHeight: 18
              radius: 4
              color: stepBackMouse.containsMouse ? Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.15) : Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.05)
              border.width: 1
              border.color: Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.12)

              Label {
                id: stepBackLabel
                anchors.centerIn: parent
                text: modelData.label
                font.family: "monospace"
                font.pixelSize: 8
                font.weight: Font.DemiBold
                color: root.fb
              }

              MouseArea {
                id: stepBackMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.adjustTimeOffset(modelData.delta)
              }
            }
          }

          Item { Layout.fillWidth: true }

          // Forward steps
          Repeater {
            model: [
              { label: "+1h", delta: 1/24 },
              { label: "+5h", delta: 5/24 },
              { label: "+12h", delta: 0.5 },
              { label: "+1d", delta: 1.0 },
              { label: "+1w", delta: 7.0 }
            ]
            delegate: Rectangle {
              implicitWidth: stepFwdLabel.implicitWidth + 12
              implicitHeight: 18
              radius: 4
              color: stepFwdMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.05)
              border.width: 1
              border.color: Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.12)

              Label {
                id: stepFwdLabel
                anchors.centerIn: parent
                text: modelData.label
                font.family: "monospace"
                font.pixelSize: 8
                font.weight: Font.DemiBold
                color: root.fb
              }

              MouseArea {
                id: stepFwdMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.adjustTimeOffset(modelData.delta)
              }
            }
          }
        }

        // Scrubber Slider bar
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(10)

          Label {
            text: "-30d"
            font.family: "monospace"
            font.pixelSize: 9
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
              if (Math.abs(value) < 0.3) root.timeOffsetDays = 0;
              else root.timeOffsetDays = value;
            }

            background: Rectangle {
              x: timeScrubber.leftPadding
              y: timeScrubber.topPadding + timeScrubber.availableHeight / 2 - height / 2
              implicitWidth: 200
              implicitHeight: 4
              width: timeScrubber.availableWidth
              height: implicitHeight
              radius: 2
              color: Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.12)

              // Center tick marker for LIVE (0d)
              Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: 10
                color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.6)
              }
            }

            handle: Rectangle {
              x: timeScrubber.leftPadding + timeScrubber.visualPosition * (timeScrubber.availableWidth - width)
              y: timeScrubber.topPadding + timeScrubber.availableHeight / 2 - height / 2
              implicitWidth: 16
              implicitHeight: 16
              radius: 8
              color: timeScrubber.pressed ? root.fb : (Math.abs(root.timeOffsetDays) < 0.05 ? Color.accent : Color.urgent)
              border.color: Qt.rgba(0, 0, 0, 0.5)
              border.width: 2
            }
          }

          Label {
            text: "+30d"
            font.family: "monospace"
            font.pixelSize: 9
            color: root.dimFb
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: Style.space(14)
        Layout.rightMargin: Style.space(14)
        Layout.preferredHeight: 680
        color: "transparent"
        radius: 8
        border.width: 1
        border.color: Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.1)
        
      GridLayout {
        anchors.fill: parent
        anchors.margins: 10
        columns: 2
        rowSpacing: 10
        columnSpacing: 10

        // 1. Earth-Moon Orrery
        Canvas {
          id: orreryCanvas
          Layout.preferredWidth: 400
          Layout.preferredHeight: 320
          renderTarget: Canvas.Image
          
          property real phaseFrac: root.simPhaseFraction
          property real earthRot: root.simEarthRotation
          property real moonAng: root.simMoonAngle
          property real illum: root.simIllumination

          onPhaseFracChanged: requestPaint()
          onEarthRotChanged: requestPaint()
          onMoonAngChanged: requestPaint()
          onIllumChanged: requestPaint()
          
          onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            
            var cx = width / 2
            var cy = height / 2
            var r = 120
            var w = width
            var pi = Math.PI

            // Orbit ellipse
            var orbitRX = w * 0.30
            var orbitRY = orbitRX * 0.35
            
            // Astronomical orbital angle:
            // 0 deg (New Moon) -> LEFT between Sun and Earth (cx - orbitRX, cy)
            // 90 deg (First Quarter) -> BOTTOM (cx, cy + orbitRY)
            // 180 deg (Full Moon) -> RIGHT behind Earth (cx + orbitRX, cy)
            // 270 deg (Last Quarter) -> TOP (cx, cy - orbitRY)
            var rad = orreryCanvas.moonAng * pi / 180
            var moonX = cx - orbitRX * Math.cos(rad)
            var moonY = cy + orbitRY * Math.sin(rad)
            var moonR = 12
            
            var earthR = 28

            // Sunlight direction arrows
            ctx.globalAlpha = 0.12
            ctx.strokeStyle = root.fb.toString()
            ctx.lineWidth = 1
            for (var i = -2; i <= 2; i++) {
                var lineY = cy + i * 25
                ctx.beginPath()
                ctx.moveTo(10, lineY)
                ctx.lineTo(30, lineY)
                ctx.moveTo(25, lineY - 3)
                ctx.lineTo(30, lineY)
                ctx.lineTo(25, lineY + 3)
                ctx.stroke()
            }
            
            ctx.globalAlpha = 0.25
            ctx.strokeStyle = root.fb.toString()
            ctx.lineWidth = 1
            ctx.beginPath()
            for (var j = 0; j <= 64; j++) {
                var a = j * 2 * pi / 64;
                var x = cx + orbitRX * Math.cos(a);
                var y = cy + orbitRY * Math.sin(a);
                if (j === 0) ctx.moveTo(x, y);
                else ctx.lineTo(x, y);
            }
            ctx.stroke()

            var drawEarth = function() {
                var oceanGrad = ctx.createRadialGradient(cx, cy, 0, cx, cy, earthR)
                oceanGrad.addColorStop(0, Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.1).toString())
                oceanGrad.addColorStop(1, Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.25).toString())
                ctx.fillStyle = oceanGrad
                ctx.beginPath()
                ctx.arc(cx, cy, earthR, 0, 2 * pi)
                ctx.fill()
                
                if (root.geoPolys && root.geoPolys.length > 0) {
                    var lon0 = ((0.5 - (orreryCanvas.earthRot / 360)) * 360 + 90) * pi / 180
                    ctx.fillStyle = Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.45).toString()
                    for (var i = 0; i < root.geoPolys.length; i++) {
                        var pts = root.geoPolys[i]
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
                                else { ctx.lineTo(px, py) }
                            } else {
                                started = false
                            }
                        }
                        ctx.fill()
                    }
                }
                ctx.globalAlpha = 0.7
                ctx.fillStyle = Qt.rgba(0, 0, 0, 0.6).toString()
                ctx.beginPath()
                ctx.arc(cx, cy, earthR, -pi/2, pi/2, false)
                ctx.fill()
                
                var shadowGrad = ctx.createLinearGradient(cx - earthR*0.2, cy, cx + earthR*0.5, cy)
                shadowGrad.addColorStop(0, Qt.rgba(0, 0, 0, 0.0).toString())
                shadowGrad.addColorStop(1, Qt.rgba(0, 0, 0, 0.5).toString())
                ctx.fillStyle = shadowGrad
                ctx.beginPath()
                ctx.arc(cx, cy, earthR, 0, 2 * pi)
                ctx.fill()
                
                ctx.globalAlpha = 0.5
                ctx.strokeStyle = root.fb.toString()
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.arc(cx, cy, earthR, 0, 2 * pi)
                ctx.stroke()
            }
            
            var drawMoon = function() {
                ctx.save();
                
                var phaseFrac = root.simPhaseFraction;
                var illumFrac = orreryCanvas.illum / 100.0;
                
                // 1. Soft lunar glow around illuminated body (scales with illumination)
                if (illumFrac > 0.05) {
                    var moonGlowGrad = ctx.createRadialGradient(moonX, moonY, moonR * 0.7, moonX, moonY, moonR + 6 * illumFrac);
                    moonGlowGrad.addColorStop(0, Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.35 * illumFrac).toString());
                    moonGlowGrad.addColorStop(1, Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.0).toString());
                    ctx.globalAlpha = 1;
                    ctx.fillStyle = moonGlowGrad;
                    ctx.beginPath();
                    ctx.arc(moonX, moonY, moonR + 6 * illumFrac, 0, 2 * pi);
                    ctx.fill();
                }

                // 2. Solid Opaque Dark Lunar Base (Occludes background orbit line completely)
                ctx.fillStyle = "#14171f";
                ctx.beginPath();
                ctx.arc(moonX, moonY, moonR, 0, 2 * pi);
                ctx.fill();

                // Dark side 3D sphere gradient (earthshine)
                var darkGrad = ctx.createRadialGradient(moonX - moonR * 0.2, moonY - moonR * 0.2, 0, moonX, moonY, moonR);
                darkGrad.addColorStop(0, "#252b3b");
                darkGrad.addColorStop(1, "#101217");
                ctx.fillStyle = darkGrad;
                ctx.beginPath();
                ctx.arc(moonX, moonY, moonR, 0, 2 * pi);
                ctx.fill();

                // 3. Dynamic Illuminated Phase Shape
                if (illumFrac > 0.01) {
                    ctx.save();
                    ctx.beginPath();
                    ctx.arc(moonX, moonY, moonR, 0, 2 * pi);
                    ctx.clip();

                    var litGrad = ctx.createRadialGradient(moonX - moonR * 0.3, moonY - moonR * 0.3, 0, moonX, moonY, moonR);
                    litGrad.addColorStop(0, Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.98).toString());
                    litGrad.addColorStop(0.75, Qt.rgba(root.fb.r * 0.88, root.fb.g * 0.90, root.fb.b * 0.94, 0.98).toString());
                    litGrad.addColorStop(1, Qt.rgba(root.fb.r * 0.74, root.fb.g * 0.78, root.fb.b * 0.85, 0.98).toString());
                    ctx.fillStyle = litGrad;

                    ctx.beginPath();
                    var steps = 32;
                    if (phaseFrac <= 0.5) {
                        // Waxing: lit limb on the right (from top -pi/2 to bottom pi/2)
                        ctx.arc(moonX, moonY, moonR, -pi / 2, pi / 2, false);
                        // Terminator: from bottom (+pi/2) back to top (-pi/2)
                        var k = Math.cos(2 * pi * phaseFrac);
                        for (var i = 0; i <= steps; i++) {
                            var theta = pi / 2 - (pi * i / steps);
                            var tx = moonX + k * moonR * Math.cos(theta);
                            var ty = moonY + moonR * Math.sin(theta);
                            ctx.lineTo(tx, ty);
                        }
                    } else {
                        // Waning: lit limb on the left (from bottom +pi/2 up to top 3pi/2 / -pi/2)
                        ctx.arc(moonX, moonY, moonR, pi / 2, 3 * pi / 2, false);
                        // Terminator: from top (-pi/2) back down to bottom (+pi/2)
                        var k = -Math.cos(2 * pi * phaseFrac);
                        for (var i = 0; i <= steps; i++) {
                            var theta = -pi / 2 + (pi * i / steps);
                            var tx = moonX + k * moonR * Math.cos(theta);
                            var ty = moonY + moonR * Math.sin(theta);
                            ctx.lineTo(tx, ty);
                        }
                    }
                    ctx.closePath();
                    ctx.fill();
                    ctx.restore();
                }

                // 4. Crisp limb outline
                ctx.globalAlpha = 0.45;
                ctx.strokeStyle = root.fb.toString();
                ctx.lineWidth = 0.8;
                ctx.beginPath();
                ctx.arc(moonX, moonY, moonR, 0, 2 * pi);
                ctx.stroke();

                ctx.restore();
            }
            
            if (moonY < cy) { drawMoon(); drawEarth(); }
            else { drawEarth(); drawMoon(); }
            
            ctx.globalAlpha = 0.3
            ctx.fillStyle = root.fb.toString()
            ctx.font = "8px monospace"
            ctx.textAlign = "center"
            ctx.fillText(orreryCanvas.moonAng.toFixed(0) + "°", moonX, moonY - moonR - 6)
            
            ctx.textAlign = "left"
            ctx.fillText("EARTH-MOON", 10, 20)
          }
        }

        // 2. Earth Orbit around Sun
        Canvas {
          id: sunEarthCanvas
          Layout.preferredWidth: 400
          Layout.preferredHeight: 320
          renderTarget: Canvas.Image
          
          property var simDate: root.simulatedDate
          
          onSimDateChanged: requestPaint()
          
          onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            var cx = width / 2
            var cy = height / 2
            var pi = Math.PI
            
            var a = 100;
            var e = 0.055; // Slightly enhanced eccentricity so Keplerian shape and focus offset are distinctly visible
            var longPeri = 102.94 * pi / 180;
            var b = a * Math.sqrt(1 - e*e);
            
            var centerX = cx - a*e * Math.cos(longPeri);
            var centerY = cy - a*e * Math.sin(longPeri);
            
            ctx.globalAlpha = 0.25;
            ctx.strokeStyle = root.fb.toString();
            ctx.lineWidth = 1.2;
            ctx.save();
            ctx.translate(centerX, centerY);
            ctx.rotate(longPeri);
            ctx.beginPath();
            for (var j = 0; j <= 64; j++) {
                var a_ang = j * 2 * pi / 64;
                var ex = a * Math.cos(a_ang);
                var ey = b * Math.sin(a_ang);
                if (j === 0) ctx.moveTo(ex, ey);
                else ctx.lineTo(ex, ey);
            }
            ctx.stroke();
            ctx.restore();
            
            // Markers (Heliocentric Earth positions: lambda = 0 [Sep 22], 90 [Dec 21], 180 [Mar 20], 270 [Jun 21])
            ctx.globalAlpha = 0.6;
            ctx.fillStyle = root.fb.toString();
            ctx.font = "8px monospace";
            var markerLongs = [0, 90, 180, 270];
            var markerLabels = ["SEP 22 (Eq)", "DEC 21 (So)", "MAR 20 (Eq)", "JUN 21 (So)"];
            for (var i = 0; i < 4; i++) {
                var nu = markerLongs[i] * pi / 180 - longPeri;
                var r_dist = a * (1 - e*e) / (1 + e*Math.cos(nu));
                var ang = longPeri + nu;
                var ax = cx + r_dist * Math.cos(ang);
                var ay = cy + r_dist * Math.sin(ang);
                
                ctx.beginPath();
                ctx.arc(ax, ay, 2.5, 0, 2*pi);
                ctx.fill();

                if (markerLongs[i] === 0) {
                    ctx.textAlign = "left";
                    ctx.fillText(markerLabels[i], ax + 8, ay + 3);
                } else if (markerLongs[i] === 180) {
                    ctx.textAlign = "right";
                    ctx.fillText(markerLabels[i], ax - 8, ay + 3);
                } else if (markerLongs[i] === 270) {
                    ctx.textAlign = "center";
                    ctx.fillText(markerLabels[i], ax, ay - 8);
                } else {
                    ctx.textAlign = "center";
                    ctx.fillText(markerLabels[i], ax, ay + 14);
                }
            }
            
            // Earth Position (Keplerian)
            var now = root.simulatedDate;
            var j2000 = new Date(Date.UTC(2000, 0, 1, 12, 0, 0));
            var d = (now - j2000) / 86400000;
            var L = (100.46 + (360 / 365.25) * d) % 360;
            var M = (L * pi / 180) - longPeri;
            
            var E = M;
            for (var k = 0; k < 5; k++) {
                E = E - (E - e*Math.sin(E) - M) / (1 - e*Math.cos(E));
            }
            var nu = 2 * Math.atan2(Math.sqrt(1+e)*Math.sin(E/2), Math.sqrt(1-e)*Math.cos(E/2));
            var r_dist = a * (1 - e*e) / (1 + e*Math.cos(nu));
            var ang = longPeri + nu;
            var ex = cx + r_dist * Math.cos(ang);
            var ey = cy + r_dist * Math.sin(ang);
            
            ctx.globalAlpha = 1;
            ctx.fillStyle = "#4a90e2";
            ctx.beginPath();
            ctx.arc(ex, ey, 5.5, 0, 2*pi);
            ctx.fill();

            ctx.fillStyle = root.fb.toString();
            ctx.font = "8px monospace";
            ctx.textAlign = "left";
            ctx.fillText("EARTH", ex + 8, ey + 3);
            
            // Sun
            var sunRad = ctx.createRadialGradient(cx, cy, 0, cx, cy, 22);
            sunRad.addColorStop(0, Qt.rgba(255, 210, 80, 0.8).toString());
            sunRad.addColorStop(1, Qt.rgba(255, 210, 80, 0.0).toString());
            ctx.fillStyle = sunRad;
            ctx.beginPath();
            ctx.arc(cx, cy, 22, 0, 2*pi);
            ctx.fill();
            ctx.fillStyle = "#ffcc00";
            ctx.beginPath();
            ctx.arc(cx, cy, 4.5, 0, 2*pi);
            ctx.fill();
            
            ctx.globalAlpha = 0.3;
            ctx.fillStyle = root.fb.toString();
            ctx.textAlign = "left";
            ctx.fillText("EARTH ORBIT", 10, 20);
          }
        }

        // 3. Flat Map
        Canvas {
          id: flatMapCanvas
          Layout.preferredWidth: 400
          Layout.preferredHeight: 320
          renderTarget: Canvas.Image
          
          property real earthRot: root.simEarthRotation
          property var simDate: root.simulatedDate
          
          onEarthRotChanged: requestPaint()
          onSimDateChanged: requestPaint()
          
          onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            
            var mapY = height / 2; 
            var mapX = width / 2; 
            var pi = Math.PI;
            var scale = width / (2 * pi * 0.8707); 
            scale *= 0.90; 
            
            if (!root.geoPolys || root.geoPolys.length === 0) return;
            
            var project = function(lon, lat) {
                var r = lat * lat, e = r * r;
                var nx = lon * (0.8707 - 0.131979 * r + e * (e * (0.003971 * r - 0.001529 * e) - 0.013791));
                var ny = lat * (1.007226 + r * (0.015085 + e * (0.028874 * r - 0.044475 - 0.005916 * e)));
                return [mapX + nx * scale, mapY - ny * scale];
            };

            var addMapBoundary = function() {
                var first = true;
                for (var latD = 90; latD >= -90; latD -= 2) {
                    var pt = project(pi, latD * pi / 180);
                    if (first) { ctx.moveTo(pt[0], pt[1]); first = false; }
                    else { ctx.lineTo(pt[0], pt[1]); }
                }
                for (var lonD = 180; lonD >= -180; lonD -= 5) {
                    var pt = project(lonD * pi / 180, -pi / 2);
                    ctx.lineTo(pt[0], pt[1]);
                }
                for (var latD = -90; latD <= 90; latD += 2) {
                    var pt = project(-pi, latD * pi / 180);
                    ctx.lineTo(pt[0], pt[1]);
                }
                for (var lonD = -180; lonD <= 180; lonD += 5) {
                    var pt = project(lonD * pi / 180, pi / 2);
                    ctx.lineTo(pt[0], pt[1]);
                }
                ctx.closePath();
            };
            
            ctx.beginPath();
            addMapBoundary();
            ctx.fillStyle = Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.08).toString();
            ctx.fill();
            ctx.strokeStyle = Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.35).toString();
            ctx.lineWidth = 1.2;
            ctx.stroke();
            
            ctx.fillStyle = Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.65).toString();
            for (var i = 0; i < root.geoPolys.length; i++) {
                var pts = root.geoPolys[i];
                ctx.beginPath();
                var started = false;
                for (var c = 0; c < pts.length; c += 2) {
                    var lon = pts[c];
                    var lat = pts[c + 1];
                    var pt = project(lon, lat);
                    if (!started) { ctx.moveTo(pt[0], pt[1]); started = true; }
                    else { ctx.lineTo(pt[0], pt[1]); }
                }
                ctx.fill();
            }
            
            var now = root.simulatedDate;
            var start = new Date(now.getFullYear(), 0, 0);
            var diff = now - start;
            var dayOfYear = Math.floor(diff / 86400000);
            var declination = -23.44 * Math.cos((dayOfYear + 10) * 2 * pi / 365) * pi / 180;
            if (Math.abs(declination) < 0.0001) declination = 0.0001;
            
            var hourFrac = flatMapCanvas.earthRot / 360;
            var lonSun = (0.5 - hourFrac) * 2 * pi;
            
            var steps = 180;
            var startLat = 0, endLat = 0;
            
            ctx.save();
            ctx.beginPath();
            addMapBoundary();
            ctx.clip();
            
            ctx.beginPath();
            for (var i = 0; i <= steps; i++) {
                var lon = -pi + (i / steps) * 2 * pi;
                var lat = Math.atan(-Math.cos(lon - lonSun) / Math.tan(declination));
                if (i === 0) startLat = lat;
                if (i === steps) endLat = lat;
                var pt = project(lon, lat);
                if (i === 0) ctx.moveTo(pt[0], pt[1]);
                else ctx.lineTo(pt[0], pt[1]);
            }
            
            var latSteps = 30;
            if (declination > 0) {
                for (var j = 0; j <= latSteps; j++) {
                    var lat = endLat + (j / latSteps) * (-pi / 2 - endLat);
                    var pt = project(pi, lat);
                    ctx.lineTo(pt[0], pt[1]);
                }
                for (var j = 0; j <= steps; j++) {
                    var lon = pi - (j / steps) * 2 * pi;
                    var pt = project(lon, -pi / 2);
                    ctx.lineTo(pt[0], pt[1]);
                }
                for (var j = 0; j <= latSteps; j++) {
                    var lat = -pi / 2 + (j / latSteps) * (startLat - (-pi / 2));
                    var pt = project(-pi, lat);
                    ctx.lineTo(pt[0], pt[1]);
                }
            } else {
                for (var j = 0; j <= latSteps; j++) {
                    var lat = endLat + (j / latSteps) * (pi / 2 - endLat);
                    var pt = project(pi, lat);
                    ctx.lineTo(pt[0], pt[1]);
                }
                for (var j = 0; j <= steps; j++) {
                    var lon = pi - (j / steps) * 2 * pi;
                    var pt = project(lon, pi / 2);
                    ctx.lineTo(pt[0], pt[1]);
                }
                for (var j = 0; j <= latSteps; j++) {
                    var lat = pi / 2 + (j / latSteps) * (startLat - pi / 2);
                    var pt = project(-pi, lat);
                    ctx.lineTo(pt[0], pt[1]);
                }
            }
            ctx.closePath();
            ctx.fillStyle = Qt.rgba(0, 0, 0, 0.42).toString();
            ctx.fill();
            ctx.restore();
            
            ctx.globalAlpha = 0.3
            ctx.fillStyle = root.fb.toString()
            ctx.font = "8px monospace"
            ctx.textAlign = "left"
            ctx.fillText("NATURAL EARTH", 10, 20)
          }
        }

        // 4. Solar System Orrery
        Canvas {
          id: solarSystemCanvas
          Layout.preferredWidth: 400
          Layout.preferredHeight: 320
          renderTarget: Canvas.Image
          
          property var simDate: root.simulatedDate
          onSimDateChanged: requestPaint()
          
          onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            var cx = width / 2
            var cy = height / 2
            var pi = Math.PI
            
            // J2000 epoch days
            var now = root.simulatedDate;
            var j2000 = new Date(Date.UTC(2000, 0, 1, 12, 0, 0))
            var d = (now - j2000) / 86400000
            
            var planets = [
                {name: "Me", period: 87.97, L0: 252.25, a: 12, e: 0.2056, w: 77.45, c: "#a8a8a8"},
                {name: "V", period: 224.70, L0: 181.98, a: 21, e: 0.0067, w: 131.53, c: "#e3bb76"},
                {name: "E", period: 365.25, L0: 100.46, a: 30, e: 0.0167, w: 102.94, c: "#4a90e2"},
                {name: "Ma", period: 686.98, L0: 355.45, a: 44, e: 0.0934, w: 336.04, c: "#e26a4a"},
                {name: "J", period: 4332.59, L0: 34.40, a: 70, e: 0.0484, w: 14.75, c: "#d1a364"},
                {name: "S", period: 10759.22, L0: 49.94, a: 95, e: 0.0555, w: 92.43, c: "#ebd9a4"},
                {name: "U", period: 30685.4, L0: 313.23, a: 115, e: 0.0463, w: 170.96, c: "#95dce3"},
                {name: "N", period: 60189.0, L0: -55.12, a: 135, e: 0.0094, w: 44.97, c: "#4a68e2"}
            ];
            
            ctx.globalAlpha = 0.15;
            ctx.lineWidth = 0.5;
            ctx.strokeStyle = root.fb.toString();
            
            for (var i=0; i<planets.length; i++) {
                var p = planets[i];
                var longPeri = p.w * pi / 180;
                var b = p.a * Math.sqrt(1 - p.e*p.e);
                var centerX = cx - p.a * p.e * Math.cos(longPeri);
                var centerY = cy - p.a * p.e * Math.sin(longPeri);
                
                ctx.save();
                ctx.translate(centerX, centerY);
                ctx.rotate(longPeri);
                ctx.beginPath();
                for (var j = 0; j <= 64; j++) {
                    var a_ang = j * 2 * pi / 64;
                    var ex = p.a * Math.cos(a_ang);
                    var ey = b * Math.sin(a_ang);
                    if (j === 0) ctx.moveTo(ex, ey);
                    else ctx.lineTo(ex, ey);
                }
                ctx.stroke();
                ctx.restore();
            }
            
            ctx.globalAlpha = 1;
            ctx.font = "7px monospace";
            for (var i=0; i<planets.length; i++) {
                var p = planets[i];
                var longPeri = p.w * pi / 180;
                var L = (p.L0 + (360 / p.period) * d) % 360;
                var M = (L * pi / 180) - longPeri;
                
                var E = M;
                for (var k=0; k<5; k++) {
                    E = E - (E - p.e*Math.sin(E) - M) / (1 - p.e*Math.cos(E));
                }
                var nu = 2 * Math.atan2(Math.sqrt(1+p.e)*Math.sin(E/2), Math.sqrt(1-p.e)*Math.cos(E/2));
                var r_dist = p.a * (1 - p.e*p.e) / (1 + p.e*Math.cos(nu));
                var ang = longPeri + nu;
                var px = cx + r_dist * Math.cos(ang);
                var py = cy + r_dist * Math.sin(ang);
                
                ctx.fillStyle = p.c
                ctx.beginPath()
                ctx.arc(px, py, 3, 0, 2*pi)
                ctx.fill()
                
                ctx.globalAlpha = 0.6
                ctx.fillStyle = root.fb.toString()
                ctx.fillText(p.name, px + 5, py + 3)
                ctx.globalAlpha = 1
            }
            
            // Sun
            var sunRad = ctx.createRadialGradient(cx, cy, 0, cx, cy, 12)
            sunRad.addColorStop(0, Qt.rgba(255, 210, 80, 0.8).toString())
            sunRad.addColorStop(1, Qt.rgba(255, 210, 80, 0.0).toString())
            ctx.fillStyle = sunRad
            ctx.beginPath()
            ctx.arc(cx, cy, 12, 0, 2*pi)
            ctx.fill()
            ctx.fillStyle = "#ffcc00"
            ctx.beginPath()
            ctx.arc(cx, cy, 3, 0, 2*pi)
            ctx.fill()
            
            ctx.globalAlpha = 0.3
            ctx.fillStyle = root.fb.toString()
            ctx.font = "8px monospace"
            ctx.textAlign = "left"
            ctx.fillText("SOLAR SYSTEM", 10, 20)
          }
        }
      }


        // Corner decorations
        Label { anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 6; text: "┌"; font.family: "monospace"; font.pixelSize: 10; color: root.fb; opacity: 0.25 }
        Label { anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 6; text: "┐"; font.family: "monospace"; font.pixelSize: 10; color: root.fb; opacity: 0.25 }
        Label { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 6; text: "└"; font.family: "monospace"; font.pixelSize: 10; color: root.fb; opacity: 0.25 }
        Label { anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 6; text: "┘"; font.family: "monospace"; font.pixelSize: 10; color: root.fb; opacity: 0.25 }


        // Separator lines
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 40
            height: 1
            color: Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.15)
        }
        Rectangle {
            anchors.centerIn: parent
            width: 1
            height: parent.height - 40
            color: Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.15)
        }
        
        // DASHBOARD label
        Label {
          anchors.top: parent.top
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.topMargin: 6
          text: "SYSTEMS DASHBOARD"
          font.family: "monospace"
          font.pixelSize: 7
          font.letterSpacing: 3
          color: root.fb
          opacity: 0.3
        }
      }
      // ─── Data readouts (2 Columns with Hover Tooltips) ───
      RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Style.space(16)
        Layout.rightMargin: Style.space(16)
        spacing: Style.space(24)

        // Column 1: Lunar Cycle
        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.space(2)

          // Age
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: 20
            radius: 4
            color: ageMa.containsMouse ? Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.08) : "transparent"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 6
              anchors.rightMargin: 6
              spacing: 4
              Label { text: "AGE"; font.family: "monospace"; font.pixelSize: Style.font.caption; font.letterSpacing: 1; color: root.dimFb }
              Item { Layout.fillWidth: true }
              Label { text: root.simPhaseAgeDays.toFixed(1) + "d"; font.family: "monospace"; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold; color: root.fb }
              Label { text: " / " + root.simSynodic.toFixed(1) + "d"; font.family: "monospace"; font.pixelSize: Style.font.caption; color: root.dimFb }
            }

            ToolTip {
              visible: ageMa.containsMouse
              delay: 150
              timeout: 6000
              contentItem: Text {
                text: "Lunar age: Days elapsed since the last New Moon within the ~29.53-day synodic cycle."
                font.family: "monospace"
                font.pixelSize: 10
                color: root.fb
                wrapMode: Text.WordWrap
              }
              background: Rectangle {
                color: Qt.rgba(20/255, 24/255, 32/255, 0.96)
                border.color: Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.3)
                radius: 6
              }
            }

            MouseArea {
              id: ageMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
            }
          }

          // Next full
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: 20
            radius: 4
            color: fullMa.containsMouse ? Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.08) : "transparent"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 6
              anchors.rightMargin: 6
              spacing: 4
              Label { text: "→ FULL"; font.family: "monospace"; font.pixelSize: Style.font.caption; font.letterSpacing: 1; color: root.dimFb }
              Item { Layout.fillWidth: true }
              Label { text: root.simDaysToFull.toFixed(1) + " days"; font.family: "monospace"; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold; color: root.fb }
            }

            ToolTip {
              visible: fullMa.containsMouse
              delay: 150
              timeout: 6000
              contentItem: Text {
                text: "Next Full Moon: Exact time remaining until full illumination (plenilune / 100% phase)."
                font.family: "monospace"
                font.pixelSize: 10
                color: root.fb
                wrapMode: Text.WordWrap
              }
              background: Rectangle {
                color: Qt.rgba(20/255, 24/255, 32/255, 0.96)
                border.color: Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.3)
                radius: 6
              }
            }

            MouseArea {
              id: fullMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
            }
          }

          // Next new
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: 20
            radius: 4
            color: newMa.containsMouse ? Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.08) : "transparent"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 6
              anchors.rightMargin: 6
              spacing: 4
              Label { text: "→ NEW"; font.family: "monospace"; font.pixelSize: Style.font.caption; font.letterSpacing: 1; color: root.dimFb }
              Item { Layout.fillWidth: true }
              Label { text: root.simDaysToNew.toFixed(1) + " days"; font.family: "monospace"; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold; color: root.fb }
            }

            ToolTip {
              visible: newMa.containsMouse
              delay: 150
              timeout: 6000
              contentItem: Text {
                text: "Next New Moon: Exact time remaining until the next new moon and start of the next synodic cycle."
                font.family: "monospace"
                font.pixelSize: 10
                color: root.fb
                wrapMode: Text.WordWrap
              }
              background: Rectangle {
                color: Qt.rgba(20/255, 24/255, 32/255, 0.96)
                border.color: Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.3)
                radius: 6
              }
            }

            MouseArea {
              id: newMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
            }
          }

          // Lunation
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: 20
            radius: 4
            color: lunMa.containsMouse ? Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.08) : "transparent"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 6
              anchors.rightMargin: 6
              spacing: 4
              Label { text: "LUNATION"; font.family: "monospace"; font.pixelSize: Style.font.caption; font.letterSpacing: 1; color: root.dimFb }
              Item { Layout.fillWidth: true }
              Label { text: "#" + root.simLunation; font.family: "monospace"; font.pixelSize: Style.font.caption; color: root.dimFb }
            }

            ToolTip {
              visible: lunMa.containsMouse
              delay: 150
              timeout: 6000
              contentItem: Text {
                text: "Brown Lunation Number: Official astronomical count of consecutive lunar cycles since January 1923."
                font.family: "monospace"
                font.pixelSize: 10
                color: root.fb
                wrapMode: Text.WordWrap
              }
              background: Rectangle {
                color: Qt.rgba(20/255, 24/255, 32/255, 0.96)
                border.color: Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.3)
                radius: 6
              }
            }

            MouseArea {
              id: lunMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
            }
          }
        }

        // Vertical separator line
        Rectangle {
          Layout.preferredWidth: 1
          Layout.fillHeight: true
          color: Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.12)
        }

        // Column 2: Ephemeris & Dynamics
        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.space(2)

          // Illumination
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: 20
            radius: 4
            color: illumMa.containsMouse ? Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.08) : "transparent"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 6
              anchors.rightMargin: 6
              spacing: 4
              Label { text: "ILLUMINATION"; font.family: "monospace"; font.pixelSize: Style.font.caption; font.letterSpacing: 1; color: root.dimFb }
              Item { Layout.fillWidth: true }
              Label { text: root.simIllumination.toFixed(1) + "%"; font.family: "monospace"; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold; color: root.fb }
            }

            ToolTip {
              visible: illumMa.containsMouse
              delay: 150
              timeout: 6000
              contentItem: Text {
                text: "Illumination percentage: Fraction of the Moon's visible disc receiving direct sunlight as seen from Earth."
                font.family: "monospace"
                font.pixelSize: 10
                color: root.fb
                wrapMode: Text.WordWrap
              }
              background: Rectangle {
                color: Qt.rgba(20/255, 24/255, 32/255, 0.96)
                border.color: Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.3)
                radius: 6
              }
            }

            MouseArea {
              id: illumMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
            }
          }

          // Distance
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: 20
            radius: 4
            color: distMa.containsMouse ? Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.08) : "transparent"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 6
              anchors.rightMargin: 6
              spacing: 4
              Label { text: "DISTANCE"; font.family: "monospace"; font.pixelSize: Style.font.caption; font.letterSpacing: 1; color: root.dimFb }
              Item { Layout.fillWidth: true }
              Label {
                text: {
                  var Mm = 2 * Math.PI * (root.simJd - 2451534.5) / 27.55455;
                  var dist = Math.round(384400 - 21100 * Math.cos(Mm));
                  return dist.toLocaleString() + " km";
                }
                font.family: "monospace"
                font.pixelSize: Style.font.caption
                font.weight: Font.DemiBold
                color: root.fb
              }
            }

            ToolTip {
              visible: distMa.containsMouse
              delay: 150
              timeout: 6000
              contentItem: Text {
                text: "Real-time Earth-Moon distance: Geocentric orbital distance (~363,300 km at perigee to ~405,500 km at apogee)."
                font.family: "monospace"
                font.pixelSize: 10
                color: root.fb
                wrapMode: Text.WordWrap
              }
              background: Rectangle {
                color: Qt.rgba(20/255, 24/255, 32/255, 0.96)
                border.color: Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.3)
                radius: 6
              }
            }

            MouseArea {
              id: distMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
            }
          }

          // Solar Declination
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: 20
            radius: 4
            color: declMa.containsMouse ? Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.08) : "transparent"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 6
              anchors.rightMargin: 6
              spacing: 4
              Label { text: "SOLAR DECL."; font.family: "monospace"; font.pixelSize: Style.font.caption; font.letterSpacing: 1; color: root.dimFb }
              Item { Layout.fillWidth: true }
              Label {
                text: {
                  var now = root.simulatedDate;
                  var start = new Date(now.getFullYear(), 0, 0);
                  var diff = now - start;
                  var dayOfYear = Math.floor(diff / 86400000);
                  var decl = -23.44 * Math.cos((dayOfYear + 10) * 2 * Math.PI / 365);
                  var sign = decl >= 0 ? "+" : "";
                  return sign + decl.toFixed(1) + "°";
                }
                font.family: "monospace"
                font.pixelSize: Style.font.caption
                font.weight: Font.DemiBold
                color: root.fb
              }
            }

            ToolTip {
              visible: declMa.containsMouse
              delay: 150
              timeout: 6000
              contentItem: Text {
                text: "Solar declination: Angular position of the Sun north (+) or south (-) of the celestial equator (governs Earth's seasons)."
                font.family: "monospace"
                font.pixelSize: 10
                color: root.fb
                wrapMode: Text.WordWrap
              }
              background: Rectangle {
                color: Qt.rgba(20/255, 24/255, 32/255, 0.96)
                border.color: Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.3)
                radius: 6
              }
            }

            MouseArea {
              id: declMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
            }
          }

          // Next Event
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: 20
            radius: 4
            color: evtMa.containsMouse ? Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.08) : "transparent"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 6
              anchors.rightMargin: 6
              spacing: 4
              Label { text: "NEXT EVENT"; font.family: "monospace"; font.pixelSize: Style.font.caption; font.letterSpacing: 1; color: root.dimFb }
              Item { Layout.fillWidth: true }
              Label {
                text: {
                  var now = root.simulatedDate;
                  var yr = now.getFullYear();
                  var events = [
                    { name: "MAR 20 (Eq)", date: new Date(Date.UTC(yr, 2, 20)) },
                    { name: "JUN 21 (So)", date: new Date(Date.UTC(yr, 5, 21)) },
                    { name: "SEP 22 (Eq)", date: new Date(Date.UTC(yr, 8, 22)) },
                    { name: "DEC 21 (So)", date: new Date(Date.UTC(yr, 11, 21)) },
                    { name: "MAR 20 (Eq)", date: new Date(Date.UTC(yr + 1, 2, 20)) }
                  ];
                  for (var i = 0; i < events.length; i++) {
                    var diffDays = (events[i].date - now) / 86400000;
                    if (diffDays >= 0) {
                      return events[i].name + " (in " + Math.ceil(diffDays) + "d)";
                    }
                  }
                  return "SEP 22 (Eq)";
                }
                font.family: "monospace"
                font.pixelSize: Style.font.caption
                color: root.dimFb
              }
            }

            ToolTip {
              visible: evtMa.containsMouse
              delay: 150
              timeout: 6000
              contentItem: Text {
                text: "Next astronomical milestone: Upcoming equinox or solstice marking the seasonal shift on Earth."
                font.family: "monospace"
                font.pixelSize: 10
                color: root.fb
                wrapMode: Text.WordWrap
              }
              background: Rectangle {
                color: Qt.rgba(20/255, 24/255, 32/255, 0.96)
                border.color: Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.3)
                radius: 6
              }
            }

            MouseArea {
              id: evtMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
            }
          }
        }

        // Vertical separator line 2
        Rectangle {
          Layout.preferredWidth: 1
          Layout.fillHeight: true
          color: Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.12)
        }

        // Section 3: Earth Axial Tilt & Seasons
        Rectangle {
          Layout.preferredWidth: 260
          Layout.fillHeight: true
          radius: 6
          color: tiltMa.containsMouse ? Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.08) : Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.03)
          border.width: 1
          border.color: Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.15)

          RowLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 8

            // Mini Axial Tilt Canvas
            Canvas {
              id: tiltCanvas
              Layout.preferredWidth: 90
              Layout.preferredHeight: 74
              renderTarget: Canvas.Image

              property real decl: root.simSolarDeclination
              onDeclChanged: requestPaint()

              onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.clearRect(0, 0, width, height)

                var cx = width / 2 + 6
                var cy = height / 2
                var R = 22
                var pi = Math.PI

                // Projected tilt angle based on current solar declination
                var tiltRad = (tiltCanvas.decl * pi / 180)

                // 1. Sunlight rays coming from left
                ctx.strokeStyle = Qt.rgba(255/255, 204/255, 0/255, 0.7)
                ctx.lineWidth = 1
                for (var i = -1; i <= 1; i++) {
                  var ly = cy + i * 12
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

                // Ocean base
                ctx.fillStyle = Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.12).toString()
                ctx.fillRect(cx - R, cy - R, 2 * R, 2 * R)

                // Left illuminated hemisphere (sunlight from left)
                var litGrad = ctx.createLinearGradient(cx - R, cy, cx + R * 0.2, cy)
                litGrad.addColorStop(0, Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.75).toString())
                litGrad.addColorStop(1, Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.25).toString())
                ctx.fillStyle = litGrad
                ctx.beginPath()
                ctx.arc(cx, cy, R, pi / 2, 3 * pi / 2, false)
                ctx.fill()

                // Night shadow on right
                ctx.fillStyle = Qt.rgba(0, 0, 0, 0.65).toString()
                ctx.beginPath()
                ctx.arc(cx, cy, R, -pi / 2, pi / 2, false)
                ctx.fill()
                ctx.restore()

                // 3. Equator (tilted perpendicular to axis)
                ctx.save()
                ctx.translate(cx, cy)
                ctx.rotate(-tiltRad)
                ctx.strokeStyle = Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.4).toString()
                ctx.lineWidth = 0.8
                ctx.beginPath()
                ctx.ellipse(-R, -R * 0.18, 2 * R, 2 * R * 0.18)
                ctx.stroke()
                ctx.restore()

                // 4. Tilted rotational axis (23.44°)
                var axisLen = R + 10
                // When decl > 0 (Summer), North pole tilts to left (-X) towards sun
                var nx = cx - Math.sin(tiltRad) * axisLen
                var ny = cy - Math.cos(tiltRad) * axisLen
                var sx = cx + Math.sin(tiltRad) * axisLen
                var sy = cy + Math.cos(tiltRad) * axisLen

                ctx.strokeStyle = Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.7).toString()
                ctx.lineWidth = 1.2
                ctx.beginPath()
                ctx.moveTo(sx, sy)
                ctx.lineTo(nx, ny)
                ctx.stroke()

                // Pole tips: N (red/warm) and S (blue/cyan)
                ctx.fillStyle = "#ff6b6b"
                ctx.beginPath(); ctx.arc(nx, ny, 2.5, 0, 2 * pi); ctx.fill()
                ctx.fillStyle = "#4dabf7"
                ctx.beginPath(); ctx.arc(sx, sy, 2.5, 0, 2 * pi); ctx.fill()

                // Labels
                ctx.fillStyle = root.fb.toString()
                ctx.font = "8px monospace"
                ctx.textAlign = "center"
                ctx.fillText("N", nx + (tiltRad > 0 ? -5 : 5), ny + 1)
                ctx.fillText("S", sx + (tiltRad > 0 ? 5 : -5), sy + 3)

                // Globe outline
                ctx.strokeStyle = Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.45).toString()
                ctx.lineWidth = 0.8
                ctx.beginPath()
                ctx.arc(cx, cy, R, 0, 2 * pi)
                ctx.stroke()
              }
            }

            // Seasonal Badges and Details
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 3

              Label {
                text: "AXIAL TILT 23.44°"
                font.family: "monospace"
                font.pixelSize: 8
                font.letterSpacing: 1
                font.weight: Font.Bold
                color: Color.accent
              }

              RowLayout {
                spacing: 4
                Label { text: "NORTH:"; font.family: "monospace"; font.pixelSize: 9; color: root.dimFb }
                Label { text: root.simNorthSeason; font.family: "monospace"; font.pixelSize: 9; font.weight: Font.DemiBold; color: root.fb }
              }

              RowLayout {
                spacing: 4
                Label { text: "SOUTH:"; font.family: "monospace"; font.pixelSize: 9; color: root.dimFb }
                Label { text: root.simSouthSeason; font.family: "monospace"; font.pixelSize: 9; font.weight: Font.DemiBold; color: root.fb }
              }

              Label {
                text: "Solar Decl: " + (root.simSolarDeclination >= 0 ? "+" : "") + root.simSolarDeclination.toFixed(1) + "°"
                font.family: "monospace"
                font.pixelSize: 8
                color: root.dimFb
              }
            }
          }

          ToolTip {
            visible: tiltMa.containsMouse
            delay: 150
            timeout: 6000
            contentItem: Text {
              text: "Earth's 23.44° axial tilt relative to its orbital plane causes the seasons. The hemisphere tilted toward the Sun receives direct rays and longer days (Summer), while the opposite hemisphere experiences Winter."
              font.family: "monospace"
              font.pixelSize: 10
              color: root.fb
              wrapMode: Text.WordWrap
            }
            background: Rectangle {
              color: Qt.rgba(20/255, 24/255, 32/255, 0.96)
              border.color: Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.3)
              radius: 6
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
        Layout.leftMargin: Style.space(14)
        Layout.rightMargin: Style.space(14)
        height: 1
        color: Qt.rgba(root.fb.r, root.fb.g, root.fb.b, 0.15)
      }

      Label {
        text: "● LIVE"
        font.family: "monospace"
        font.pixelSize: Style.font.caption
        font.weight: Font.DemiBold
        color: Color.accent
        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: Style.space(10)
      }
    }
  }
}
