import QtQuick 2.7
import QtQuick.Layouts 1.3
import QtGraphicalEffects 1.0
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3

// Modal-ish Popover with a circular HSV wheel (angle = hue, radius =
// saturation), a horizontal value slider, and a hex text field. The
// current colour is two-way bound to (hue, sat, val) and emitted via
// the `chosen(hex)` signal when the user confirms.
Popover {
    id: pop
    contentWidth: units.gu(30)
    contentHeight: contentCol.implicitHeight + units.gu(2.8)
    autoClose: false

    property var appTheme
    property var i18nApp
    property string initialHex: "#6366f1"

    signal chosen(string hex)

    // ---- working state (HSV in [0..1]) ----
    property real hue: 0
    property real sat: 1
    property real val: 1
    property string hexText: "#6366f1"

    readonly property color currentColor: {
        if (!appTheme) return Qt.rgba(0.4, 0.4, 0.95, 1);
        var rgb = appTheme.hsvToRgb(pop.hue, pop.sat, pop.val);
        return Qt.rgba(rgb[0], rgb[1], rgb[2], 1);
    }

    readonly property color valSliderMax: {
        if (!appTheme) return Qt.rgba(0.4, 0.4, 0.95, 1);
        var rgb = appTheme.hsvToRgb(pop.hue, pop.sat, 1);
        return Qt.rgba(rgb[0], rgb[1], rgb[2], 1);
    }

    function _syncFromHex(hex) {
        var c = Qt.color(hex);
        if (!c || !appTheme) return false;
        var hsv = appTheme.rgbToHsv(c.r, c.g, c.b);
        pop.hue = hsv[0];
        pop.sat = hsv[1];
        pop.val = hsv[2];
        pop.hexText = hex;
        return true;
    }

    function _rebuildHex() {
        var rgb = appTheme.hsvToRgb(pop.hue, pop.sat, pop.val);
        function p(c) {
            var s = Math.round(c * 255).toString(16);
            return s.length === 1 ? "0" + s : s;
        }
        pop.hexText = "#" + p(rgb[0]) + p(rgb[1]) + p(rgb[2]);
    }

    Component.onCompleted: _syncFromHex(initialHex)

    Column {
        id: contentCol
        anchors {
            left: parent.left; right: parent.right
            top: parent.top
            margins: units.gu(1.4)
        }
        spacing: units.gu(1)

        // Header: live preview + title
        RowLayout {
            width: parent.width
            spacing: units.gu(1)

            Rectangle {
                Layout.preferredWidth: units.gu(3.6)
                Layout.preferredHeight: units.gu(3.6)
                radius: width / 2
                color: pop.currentColor
                border.color: appTheme.border
                border.width: 1
            }
            Label {
                Layout.fillWidth: true
                text: i18nApp ? i18nApp.tr("Pick a colour") : "Pick a colour"
                color: appTheme.text
                textSize: Label.Medium
                font.bold: true
                elide: Text.ElideRight
            }
        }

        // ---- Circular hue / saturation wheel ----
        Item {
            id: wheel
            anchors.horizontalCenter: parent.horizontalCenter
            width: units.gu(22)
            height: width

            Rectangle {
                id: wheelDisc
                anchors.fill: parent
                radius: width / 2
                clip: true
                color: "black"
                border.color: appTheme.border
                border.width: 1

                // Hue ring (full saturation/value). The ConicalGradient's
                // default angle places red at 3 o'clock and rotates
                // clockwise, which matches our atan2-based hue mapping.
                ConicalGradient {
                    anchors.fill: parent
                    angle: 0
                    gradient: Gradient {
                        GradientStop { position: 0.000; color: "#ff0000" }
                        GradientStop { position: 0.167; color: "#ffff00" }
                        GradientStop { position: 0.333; color: "#00ff00" }
                        GradientStop { position: 0.500; color: "#00ffff" }
                        GradientStop { position: 0.667; color: "#0000ff" }
                        GradientStop { position: 0.833; color: "#ff00ff" }
                        GradientStop { position: 1.000; color: "#ff0000" }
                    }
                }

                // Saturation: white at the centre fading to fully
                // transparent at the rim. Lets the ConicalGradient bleed
                // through more strongly toward the edge.
                RadialGradient {
                    anchors.fill: parent
                    horizontalRadius: parent.width / 2
                    verticalRadius: parent.height / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 1) }
                        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
                    }
                }

                // Value: dim the whole disc with a black overlay tied to
                // `1 - val`. clip:true on wheelDisc keeps it round.
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 1 - pop.val)
                }
            }

            // Thumb positioned at the polar (hue, sat) coordinate.
            Rectangle {
                id: wheelThumb
                width: units.gu(1.6); height: width
                radius: width / 2
                color: "transparent"
                border.color: "white"; border.width: 2
                x: {
                    var cx = wheel.width / 2;
                    var r = pop.sat * (wheel.width / 2 - units.gu(0.4));
                    var ang = pop.hue * 2 * Math.PI;
                    return cx + Math.cos(ang) * r - width / 2;
                }
                y: {
                    var cy = wheel.height / 2;
                    var r = pop.sat * (wheel.height / 2 - units.gu(0.4));
                    var ang = pop.hue * 2 * Math.PI;
                    return cy + Math.sin(ang) * r - height / 2;
                }
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: width / 2
                    color: "transparent"
                    border.color: Qt.rgba(0, 0, 0, 0.6); border.width: 1
                }
            }

            MouseArea {
                anchors.fill: parent
                preventStealing: true
                onPressed: _set(mouse.x, mouse.y)
                onPositionChanged: if (pressed) _set(mouse.x, mouse.y)
                function _set(mx, my) {
                    var cx = wheel.width / 2;
                    var cy = wheel.height / 2;
                    var dx = mx - cx;
                    var dy = my - cy;
                    var r  = Math.sqrt(dx * dx + dy * dy);
                    var maxR = Math.min(cx, cy);
                    pop.sat = Math.min(1, r / maxR);
                    var ang = Math.atan2(dy, dx);
                    if (ang < 0) ang += 2 * Math.PI;
                    pop.hue = ang / (2 * Math.PI);
                    pop._rebuildHex();
                }
            }
        }

        // ---- Value slider (horizontal, black → currentColor at full val) ----
        Rectangle {
            id: valSlider
            width: parent.width
            height: units.gu(2.4)
            radius: height / 2
            clip: true
            color: "black"
            border.color: appTheme.border
            border.width: 1

            LinearGradient {
                anchors.fill: parent
                start: Qt.point(0, 0)
                end:   Qt.point(parent.width, 0)
                gradient: Gradient {
                    GradientStop { position: 0; color: "black" }
                    GradientStop { position: 1; color: pop.valSliderMax }
                }
            }

            Rectangle {
                width: units.gu(0.6); height: parent.height + units.gu(0.6)
                x: pop.val * (valSlider.width - width)
                y: -units.gu(0.3)
                radius: width / 2
                color: "white"
                border.color: Qt.rgba(0, 0, 0, 0.4); border.width: 1
            }

            MouseArea {
                anchors.fill: parent
                preventStealing: true
                onPressed: _set(mouse.x)
                onPositionChanged: if (pressed) _set(mouse.x)
                function _set(mx) {
                    pop.val = Math.max(0.02, Math.min(1, mx / valSlider.width));
                    pop._rebuildHex();
                }
            }
        }

        // ---- Hex input ----
        RowLayout {
            width: parent.width
            spacing: units.gu(0.6)

            Label {
                Layout.alignment: Qt.AlignVCenter
                text: "Hex"
                color: appTheme.textSecondary
                textSize: Label.Small
                font.bold: true
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: units.gu(4)
                radius: units.gu(0.6)
                color: appTheme.surfaceAlt
                border.color: hexInput.activeFocus ? appTheme.borderFocus : appTheme.border
                border.width: 1

                TextInput {
                    id: hexInput
                    anchors.fill: parent
                    anchors.leftMargin: units.gu(0.8)
                    anchors.rightMargin: units.gu(0.8)
                    verticalAlignment: TextInput.AlignVCenter
                    color: appTheme.text
                    selectionColor: appTheme.primary
                    selectedTextColor: "white"
                    text: pop.hexText
                    font.family: "Monospace"
                    font.pixelSize: FontUtils.sizeToPixels("small")
                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhPreferLowercase

                    onTextChanged: {
                        var t = text.trim();
                        var m = /^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.exec(t);
                        if (m) {
                            var hex = "#" + m[1];
                            if (hex.toLowerCase() !== pop.hexText.toLowerCase()) {
                                pop._syncFromHex(hex);
                            }
                        }
                    }
                }
            }
        }

        // ---- Footer: cancel + apply ----
        RowLayout {
            width: parent.width
            spacing: units.gu(0.8)
            Item { Layout.fillWidth: true }
            Button {
                text: i18nApp ? i18nApp.tr("Cancel") : "Cancel"
                onClicked: PopupUtils.close(pop)
            }
            Button {
                text: i18nApp ? i18nApp.tr("Apply") : "Apply"
                color: appTheme.primary
                onClicked: {
                    pop.chosen(pop.hexText);
                    PopupUtils.close(pop);
                }
            }
        }
    }
}
