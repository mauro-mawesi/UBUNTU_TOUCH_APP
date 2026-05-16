import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3

Rectangle {
    id: card
    property string sectionTitle: ""
    property string icon: ""           // optional Lomiri icon name shown left of title
    property bool collapsible: false   // header tap toggles `collapsed`
    property bool collapsed: false
    property var appTheme
    default property alias content: inner.data

    signal toggled()

    radius: appTheme ? appTheme.radiusLg : units.gu(1.5)
    color: appTheme ? appTheme.surface : "#1a1f29"
    border.color: appTheme ? appTheme.border : "#2a3140"
    border.width: 1

    clip: card.collapsible
    implicitHeight: card.collapsed
                    ? (headerWrap.implicitHeight + units.gu(3))
                    : (outerCol.implicitHeight + units.gu(3))
    Behavior on implicitHeight {
        enabled: card.collapsible
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    ColumnLayout {
        id: outerCol
        anchors {
            left: parent.left; right: parent.right; top: parent.top
            leftMargin: units.gu(1.5)
            rightMargin: units.gu(1.5)
            topMargin: units.gu(1.5)
        }
        spacing: units.gu(0.8)

        Item {
            id: headerWrap
            Layout.fillWidth: true
            implicitHeight: headerRow.implicitHeight + units.gu(0.3)
            visible: (card.sectionTitle.length > 0) || card.collapsible || (card.icon.length > 0)

            RowLayout {
                id: headerRow
                anchors.fill: parent
                spacing: units.gu(0.8)

                Icon {
                    visible: card.icon.length > 0
                    Layout.preferredWidth: units.gu(2.2)
                    Layout.preferredHeight: units.gu(2.2)
                    Layout.alignment: Qt.AlignVCenter
                    name: card.icon
                    color: appTheme ? appTheme.text : "#e6edf3"
                }

                Label {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: card.sectionTitle
                    textSize: Label.Medium
                    color: appTheme ? appTheme.text : "#e6edf3"
                    font.bold: true
                    visible: text.length > 0
                }

                Icon {
                    visible: card.collapsible
                    Layout.preferredWidth: units.gu(1.8)
                    Layout.preferredHeight: units.gu(1.8)
                    Layout.alignment: Qt.AlignVCenter
                    name: card.collapsed ? "down" : "up"
                    color: appTheme ? appTheme.textSecondary : "#8b949e"

                    Behavior on rotation { NumberAnimation { duration: 180 } }
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: card.collapsible
                cursorShape: card.collapsible ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (!card.collapsible) return;
                    card.collapsed = !card.collapsed;
                    card.toggled();
                }
            }
        }

        ColumnLayout {
            id: inner
            Layout.fillWidth: true
            spacing: units.gu(0.6)
            visible: !card.collapsed
            opacity: card.collapsed ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
    }
}
