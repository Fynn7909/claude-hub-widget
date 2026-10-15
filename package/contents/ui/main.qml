import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property color coral: "#D97757"
    readonly property string hub: "$HOME/.local/bin/claude-hub"

    // Ausgabe von `claude-hub --widget-json`
    property var stats: null
    property bool failed: false
    property real now: Date.now()

    readonly property var days: stats ? stats.days : []
    readonly property real peak: Math.max(1, ...days.map(d => d.tokens))
    readonly property var live: stats ? stats.live : []
    readonly property int working: live.filter(l => l.working).length
    readonly property var block: stats && stats.block && stats.block.reset > now ? stats.block : null
    // Echtes Limit aus Claude Code, sobald gemeldet; sonst gilt die Schätzung in `block`.
    readonly property var limit: stats && stats.limits && stats.limits.session && stats.limits.session.reset > now ? stats.limits.session : null
    readonly property real blockProgress: limit ? Math.min(1, limit.percent / 100) : block ? Math.max(0, Math.min(1, (now - block.start) / (block.reset - block.start))) : 0

    // Zahlen zählen hoch statt zu springen
    property real shownToday: stats ? stats.today : 0
    property real shownCost: stats ? stats.cost_today : 0
    Behavior on shownToday { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
    Behavior on shownCost { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }

    function compact(n) {
        const units = [[1e9, " Mrd."], [1e6, " Mio."], [1e3, " Tsd."]]
        for (const [size, unit] of units)
            if (n >= size) return (n / size).toFixed(1).replace(".", ",") + unit
        return Math.round(n).toString()
    }

    function dollars(cost) {
        return "≈ " + cost.toFixed(2).replace(".", ",") + " $"
    }

    function remaining() {
        const minutes = Math.max(0, Math.floor(((limit || block).reset - now) / 60000))
        return "noch " + Math.floor(minutes / 60) + " h " + String(minutes % 60).padStart(2, "0") + " min"
    }

    function statusText() {
        if (failed) return "Nicht installiert"
        if (live.length === 0) return "Keine Session"
        if (working > 0) return working === 1 ? "1 arbeitet" : working + " arbeiten"
        if (live.some(l => l.status === "waiting")) return "Braucht Antwort"
        return live.length === 1 ? "1 Session offen" : live.length + " Sessions offen"
    }

    P5Support.DataSource {
        id: shell
        engine: "executable"
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)
            if (!sourceName.endsWith("--widget-json")) return
            try {
                root.stats = JSON.parse(data["stdout"])
                root.failed = false
            } catch (e) {
                root.failed = root.stats === null
            }
        }
    }

    // Hintergrundbild der Arbeitsfläche und die Lage des Widgets darauf
    property Item wallpaper: null
    property point origin: Qt.point(0, 0)

    readonly property real corner: 26

    function locate(item) {
        for (let p = item.parent; p; p = p.parent) {
            if (p.wallpaper) {
                wallpaper = p.wallpaper
                origin = item.mapToItem(p.wallpaper, 0, 0)
                return
            }
        }
    }

    function refresh() {
        now = Date.now()
        shell.connectSource(hub + " --widget-json")
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    toolTipMainText: "Claude Hub"
    toolTipSubText: "Klicken zum Öffnen · Kosten sind API-Listenpreise, das 5-Stunden-Fenster ist geschätzt"

    // Schrift und Farbe für alle Texte im Widget
    component Txt: PC3.Label {
        color: "white"
        font.family: "Inter"
    }

    fullRepresentation: MouseArea {
        id: area
        Layout.minimumWidth: Kirigami.Units.gridUnit * 16
        Layout.minimumHeight: Kirigami.Units.gridUnit * 13
        Layout.preferredWidth: Kirigami.Units.gridUnit * 21
        Layout.preferredHeight: Kirigami.Units.gridUnit * 16

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        Component.onCompleted: root.locate(area)
        onWidthChanged: root.locate(area)
        onHeightChanged: root.locate(area)
        Timer {
            interval: 2000
            running: true
            repeat: true
            onTriggered: root.locate(area)
        }

        onClicked: {
            shell.connectSource("gtk-launch claude-hub")
            spin.restart()
        }

        Item {
            id: card
            anchors.fill: parent
            transformOrigin: Item.Center
            scale: area.pressed ? 0.97 : 1
            Behavior on scale { NumberAnimation { duration: area.pressed ? 100 : 350; easing.type: Easing.OutQuint } }

            // Einblenden beim Start
            opacity: 0
            transform: Translate { id: rise; y: 14 }
            ParallelAnimation {
                running: true
                NumberAnimation { target: card; property: "opacity"; to: 1; duration: 500; easing.type: Easing.OutCubic }
                NumberAnimation { target: rise; property: "y"; to: 0; duration: 600; easing.type: Easing.OutCubic }
            }

            // Weicher Schatten, damit das Glas über dem Hintergrund schwebt
            RectangularShadow {
                anchors.fill: glass
                radius: root.corner
                offset.y: 8
                blur: 28
                color: Qt.rgba(0, 0, 0, 0.26)
            }

            // Liquid Glass: Hintergrundbild hinter dem Widget, leicht weichgezeichnet, am Rand gebrochen
            Item {
                id: glass
                anchors.fill: parent

                ShaderEffectSource {
                    id: behind
                    anchors.fill: parent
                    visible: false
                    sourceItem: root.wallpaper
                    sourceRect: Qt.rect(root.origin.x + glass.x, root.origin.y + glass.y, glass.width, glass.height)
                }
                MultiEffect {
                    id: frost
                    anchors.fill: parent
                    visible: false
                    source: behind
                    autoPaddingEnabled: false
                    blurEnabled: true
                    blur: 0.6
                    blurMax: 48
                    saturation: 0.45
                }
                ShaderEffectSource {
                    id: frosted
                    anchors.fill: parent
                    visible: false
                    sourceItem: frost
                }
                ShaderEffect {
                    anchors.fill: parent
                    visible: root.wallpaper !== null
                    fragmentShader: Qt.resolvedUrl("glass.frag.qsb")

                    property var source: frosted
                    property vector2d size: Qt.vector2d(width, height)
                    property real radius: root.corner
                    property real bezel: 30
                    property real refraction: 26
                    property real tint: 0.24
                    // Licht folgt dem Zeiger und wird beim Drücken sofort heller
                    property vector2d light: Qt.vector2d(area.mouseX, area.mouseY)
                    property real glow: area.pressed ? 2.2 : area.containsMouse ? 1 : 0
                    Behavior on glow { NumberAnimation { duration: area.pressed ? 80 : 300; easing.type: Easing.OutCubic } }
                }
                // Ohne Hintergrundbild bleibt eine dunkle Glasfläche
                Rectangle {
                    anchors.fill: parent
                    visible: root.wallpaper === null
                    radius: root.corner
                    color: Qt.rgba(0.07, 0.07, 0.08, 0.7)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.16)
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: Kirigami.Units.smallSpacing * 2.5

                // Kopf: Marke und Status
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        id: mark
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 1.2
                        Layout.preferredHeight: Layout.preferredWidth
                        source: Qt.resolvedUrl("mark.svg")
                        isMask: true
                        color: root.coral

                        // Dreht sich, solange Claude arbeitet, und läuft dann bis zur vollen Umdrehung aus
                        RotationAnimation on rotation {
                            running: root.working > 0
                            from: 0; to: 360
                            duration: 6000
                            loops: Animation.Infinite
                            onRunningChanged: if (!running) settle.restart()
                        }
                        RotationAnimation {
                            id: settle
                            target: mark
                            to: 360
                            direction: RotationAnimation.Clockwise
                            duration: 700; easing.type: Easing.OutCubic
                        }
                        RotationAnimation {
                            id: spin
                            target: mark
                            from: mark.rotation; to: mark.rotation + 360
                            duration: 700; easing.type: Easing.OutCubic
                        }
                    }
                    Txt {
                        text: "Claude Hub"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    Item { Layout.fillWidth: true }

                    Item {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        Rectangle {
                            id: dot
                            anchors.fill: parent
                            radius: 4
                            color: root.working > 0 ? root.coral
                                 : root.live.length > 0 ? "#30D158"
                                 : Qt.rgba(1, 1, 1, 0.3)
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }
                        // Puls nur während Claude arbeitet
                        Rectangle {
                            id: pulse
                            anchors.centerIn: parent
                            width: 8; height: 8; radius: 4
                            color: root.coral
                            visible: root.working > 0
                            ParallelAnimation {
                                running: pulse.visible
                                loops: Animation.Infinite
                                NumberAnimation { target: pulse; property: "scale"; from: 1; to: 2.8; duration: 1400; easing.type: Easing.OutCubic }
                                NumberAnimation { target: pulse; property: "opacity"; from: 0.6; to: 0; duration: 1400; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                    Txt {
                        text: root.statusText()
                        opacity: 0.7
                        font.pixelSize: 11
                    }
                }

                // Heute
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    ColumnLayout {
                        spacing: 0
                        Txt {
                            text: root.compact(root.shownToday)
                            font.weight: Font.DemiBold
                            font.pixelSize: 32
                            font.letterSpacing: -0.8
                            font.features: { "tnum": 1 }
                        }
                        Txt {
                            text: "Tokens heute"
                            opacity: 0.7
                            font.pixelSize: 11
                        }
                    }
                    Item { Layout.fillWidth: true }
                    ColumnLayout {
                        spacing: 0
                        Txt {
                            Layout.alignment: Qt.AlignRight
                            text: root.dollars(root.shownCost)
                            color: root.coral
                            font.weight: Font.DemiBold
                            font.pixelSize: 15
                            font.features: { "tnum": 1 }
                        }
                        Txt {
                            Layout.alignment: Qt.AlignRight
                            text: root.stats ? "Serie: " + root.stats.streak + (root.stats.streak === 1 ? " Tag" : " Tage") : ""
                            opacity: 0.7
                            font.pixelSize: 11
                        }
                    }
                }

                // 5-Stunden-Fenster
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Txt {
                            text: root.limit ? "5-Stunden-Fenster · " + Math.round(root.limit.percent) + " %"
                                : root.block ? "5-Stunden-Fenster · " + root.compact(root.block.tokens) : "Kein aktives 5-Stunden-Fenster"
                            opacity: 0.7
                            font.pixelSize: 11
                        }
                        Item { Layout.fillWidth: true }
                        Txt {
                            visible: root.limit !== null || root.block !== null
                            text: visible ? root.remaining() : ""
                            font.pixelSize: 11
                            font.features: { "tnum": 1 }
                        }
                    }
                    Rectangle {
                        id: track
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        radius: 3
                        color: Qt.rgba(1, 1, 1, 0.12)
                        clip: true

                        Rectangle {
                            id: fill
                            width: track.width * root.blockProgress
                            height: parent.height
                            radius: 3
                            color: root.coral
                            Behavior on width { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }

                            // Lichtstreifen läuft durch, solange Claude arbeitet
                            Rectangle {
                                id: shine
                                width: 40
                                height: parent.height
                                visible: root.working > 0 && fill.width > width
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0) }
                                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.45) }
                                    GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
                                }
                                SequentialAnimation on x {
                                    running: shine.visible
                                    loops: Animation.Infinite
                                    NumberAnimation { from: -shine.width; to: track.width; duration: 1800; easing.type: Easing.InOutQuad }
                                    PauseAnimation { duration: 1200 }
                                }
                            }
                        }
                    }
                }

                // Letzte 7 Tage
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing

                    Repeater {
                        model: 7
                        delegate: ColumnLayout {
                            id: day
                            required property int index
                            readonly property var entry: root.days[index]
                            readonly property bool today: index === 6
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 2

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    // Tage ohne Verbrauch bleiben als flacher Strich sichtbar
                                    height: Math.max(3, day.entry ? parent.height * day.entry.tokens / root.peak : 0)
                                    radius: 3
                                    color: day.today ? root.coral : Qt.rgba(1, 1, 1, 0.22)
                                    Behavior on height {
                                        SequentialAnimation {
                                            PauseAnimation { duration: day.index * 50 }
                                            NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
                                        }
                                    }
                                }
                            }
                            Txt {
                                Layout.alignment: Qt.AlignHCenter
                                text: day.entry ? ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"][new Date(day.entry.date + "T12:00:00").getDay()] : ""
                                opacity: day.today ? 1 : 0.6
                                font.bold: day.today
                                font.pixelSize: 10
                            }
                        }
                    }
                }

                // Woche
                RowLayout {
                    Layout.fillWidth: true
                    Txt {
                        text: root.stats ? "7 Tage: " + root.compact(root.stats.week) : root.failed ? "claude-hub fehlt: install.sh ausführen" : "Lade …"
                        opacity: 0.7
                        font.pixelSize: 11
                    }
                    Item { Layout.fillWidth: true }
                    Txt {
                        text: root.stats ? root.dollars(root.stats.cost_week) : ""
                        opacity: 0.7
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
