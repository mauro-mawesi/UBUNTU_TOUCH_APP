import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3

// Slim banner anchored above the chat. Replaces the previous "3 yellow
// system bubbles per failure" pattern: same `key` collapses into one row
// with a ×N counter, and raw technical detail is hidden behind "Details"
// instead of being shown as the headline message.
Item {
    id: root
    property var appTheme
    property var i18nApp
    property string severity: "danger"   // "danger" | "warning"
    // Live model. Each entry: { key, message, detail, count }
    property var errors: []
    property bool expanded: false

    signal dismissed()

    // Add an error. If `key` already exists, bumps its count and replaces
    // the (typically identical) detail string. Otherwise appends a new row.
    function pushError(key, message, detail) {
        var arr = errors.slice();
        for (var i = 0; i < arr.length; i++) {
            if (arr[i].key === key) {
                arr[i].count = (arr[i].count || 1) + 1;
                arr[i].detail = detail || arr[i].detail || "";
                errors = arr;
                return;
            }
        }
        arr.push({
            key: key,
            message: message || "",
            detail: detail || "",
            count: 1
        });
        errors = arr;
    }

    function clear() {
        errors = [];
        expanded = false;
    }

    readonly property bool _isDanger: severity === "danger"
    readonly property color _accent: _isDanger ? appTheme.danger : appTheme.warning
    readonly property color _bg:     appTheme.withAlpha(_accent, appTheme.isDark ? 0.16 : 0.10)
    readonly property color _border: appTheme.withAlpha(_accent, appTheme.isDark ? 0.50 : 0.40)

    visible: errors.length > 0
    height: visible ? card.implicitHeight + units.gu(1.0) : 0
    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    Rectangle {
        id: card
        anchors {
            left: parent.left; right: parent.right
            top: parent.top
            leftMargin: units.gu(1.5)
            rightMargin: units.gu(1.5)
            topMargin: units.gu(0.5)
        }
        implicitHeight: contentCol.implicitHeight + units.gu(1.4)
        radius: units.gu(1.0)
        color: root._bg
        border.color: root._border
        border.width: 1

        Column {
            id: contentCol
            anchors {
                left: parent.left; right: parent.right
                top: parent.top
                leftMargin: units.gu(1.2)
                rightMargin: units.gu(0.6)
                topMargin: units.gu(0.7)
            }
            spacing: units.gu(0.4)

            RowLayout {
                width: parent.width
                spacing: units.gu(0.8)

                Item {
                    Layout.preferredWidth: units.gu(2)
                    Layout.preferredHeight: units.gu(2)
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: root._accent
                        Icon {
                            anchors.centerIn: parent
                            width: parent.width * 0.7; height: width
                            name: "dialog-warning-symbolic"
                            color: "white"
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0

                    // Headline: humanized first message; if more than one
                    // distinct error, show a digest count.
                    Label {
                        Layout.fillWidth: true
                        text: {
                            if (root.errors.length === 0) return "";
                            var head = root.errors[0].message;
                            if (root.errors.length > 1) {
                                var extra = root.errors.length - 1;
                                head = head + " · +" + extra;
                            }
                            return head;
                        }
                        color: appTheme.text
                        textSize: Label.Small
                        font.bold: true
                        wrapMode: Text.Wrap
                    }

                    // Total occurrences across all entries — collapses
                    // repeated failures into a single visible counter so the
                    // banner doesn't quietly hide the magnitude of the issue.
                    Label {
                        Layout.fillWidth: true
                        text: {
                            var total = 0;
                            for (var i = 0; i < root.errors.length; i++) {
                                total += (root.errors[i].count || 1);
                            }
                            if (total <= 1) return "";
                            return (i18nApp ? i18nApp.tr("%1 occurrences").replace("%1", total)
                                            : (total + " occurrences"));
                        }
                        color: appTheme.textSecondary
                        textSize: Label.XSmall
                        visible: text.length > 0
                    }
                }

                // "Details" toggle
                Rectangle {
                    Layout.preferredWidth: detailsLabel.implicitWidth + units.gu(1.4)
                    Layout.preferredHeight: units.gu(3)
                    Layout.alignment: Qt.AlignVCenter
                    radius: units.gu(0.6)
                    color: detailsMouse.containsMouse ? appTheme.withAlpha(root._accent, 0.15) : "transparent"
                    border.color: root._border
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Label {
                        id: detailsLabel
                        anchors.centerIn: parent
                        text: root.expanded
                              ? (i18nApp ? i18nApp.tr("Hide details") : "Hide details")
                              : (i18nApp ? i18nApp.tr("Details") : "Details")
                        textSize: Label.XSmall
                        color: appTheme.text
                        font.bold: true
                    }
                    MouseArea {
                        id: detailsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.expanded = !root.expanded
                    }
                }

                // Dismiss
                Rectangle {
                    Layout.preferredWidth: units.gu(3)
                    Layout.preferredHeight: units.gu(3)
                    Layout.alignment: Qt.AlignVCenter
                    radius: width / 2
                    color: closeMouse.containsMouse ? appTheme.withAlpha(root._accent, 0.18) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(1.6); height: width
                        name: "close"
                        color: appTheme.textSecondary
                    }
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.clear();
                            root.dismissed();
                        }
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: i18nApp ? i18nApp.tr("Dismiss") : "Dismiss"
                }
            }

            // Expanded body — list of all unique errors with raw detail.
            // Capped to keep tall failure cascades from pushing the chat
            // off-screen; we still keep the counts visible above.
            Item {
                width: parent.width
                height: root.expanded ? detailsCol.implicitHeight + units.gu(0.4) : 0
                clip: true
                opacity: root.expanded ? 1 : 0
                visible: height > 0
                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Column {
                    id: detailsCol
                    width: parent.width
                    spacing: units.gu(0.4)

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: appTheme.withAlpha(root._accent, 0.25)
                    }

                    Repeater {
                        model: root.errors
                        Item {
                            width: detailsCol.width
                            height: rowCol.implicitHeight + units.gu(0.6)

                            Column {
                                id: rowCol
                                anchors {
                                    left: parent.left; right: parent.right
                                    top: parent.top
                                    topMargin: units.gu(0.3)
                                }
                                spacing: units.gu(0.1)

                                RowLayout {
                                    width: parent.width
                                    spacing: units.gu(0.6)

                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData.message
                                        color: appTheme.text
                                        textSize: Label.XSmall
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                    Label {
                                        visible: (modelData.count || 1) > 1
                                        text: "×" + (modelData.count || 1)
                                        color: appTheme.textSecondary
                                        textSize: Label.XSmall
                                    }
                                }

                                Label {
                                    width: parent.width
                                    text: modelData.detail
                                    color: appTheme.textMuted
                                    textSize: Label.XSmall
                                    wrapMode: Text.Wrap
                                    font.family: "Monospace"
                                    visible: text.length > 0
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
