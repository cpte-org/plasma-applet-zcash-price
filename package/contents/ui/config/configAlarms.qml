/*
 *   Copyright (C) 2024 Crypto Price Applet Contributors
 *   SPDX-License-Identifier: GPL-3.0
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid
import "../../code/PriceProvider.js" as PriceProvider

KCM.SimpleKCM {
    id: configAlarms

    property string cfg_coin
    property string cfg_displayMode
    property var cfg_coins
    property string cfg_priceAlarms
    property string cfg_currency
    property var priceAlarmRules: []

    readonly property var alarmAssetModel: {
        var refs = cfg_displayMode === "single" ? [cfg_coin] : (cfg_coins || []);
        var seen = {};
        var out = [];
        for (var i = 0; i < refs.length; i++) {
            var ref = normalizeAssetRef(refs[i]);
            if (!ref || seen[ref]) continue;
            var info = PriceProvider.getAssetInfo(ref);
            if (!info) continue;
            seen[ref] = true;
            out.push({
                key: ref,
                ticker: info.ticker || ref,
                name: info.name || ref,
                label: (info.ticker || ref) + "  -  " + (info.name || ref)
            });
        }
        return out;
    }

    function setConfig(key, value) {
        if (Plasmoid.configuration[key] === value) return;
        Plasmoid.configuration[key] = value;
        if (Plasmoid.configuration.writeConfig) {
            Plasmoid.configuration.writeConfig();
        }
    }

    function normalizeAssetRef(ref) {
        var s = ("" + ref).trim();
        return s.indexOf("dyn:") === 0 ? s : s.toUpperCase();
    }

    function parsePriceAlarms() {
        return PriceProvider.normalizePriceAlarms(cfg_priceAlarms, cfg_currency);
    }

    function savePriceAlarms(alarms) {
        priceAlarmRules = alarms || [];
        cfg_priceAlarms = JSON.stringify(priceAlarmRules);
        setConfig("priceAlarms", cfg_priceAlarms);
    }

    function refreshPriceAlarms() {
        var normalized = parsePriceAlarms();
        priceAlarmRules = normalized;
        if (JSON.stringify(normalized) !== (cfg_priceAlarms || "[]")) {
            savePriceAlarms(normalized);
        }
    }

    function alarmAssetLabel(ref) {
        var info = PriceProvider.getAssetInfo(ref);
        if (!info) return ref;
        return (info.ticker || ref) + " - " + (info.name || ref);
    }

    function alarmDirectionLabel(direction) {
        return direction === "below" ? i18n("Breaks below") : i18n("Breaks above");
    }

    function alarmSummary(alarm) {
        return i18n("%1 %2 %3 %4",
                    alarmAssetLabel(alarm.coin),
                    alarmDirectionLabel(alarm.direction).toLowerCase(),
                    alarm.target,
                    alarm.currency || cfg_currency);
    }

    function addPriceAlarm() {
        if (!alarmAssetModel.length) return;
        var target = parseFloat(alarmTargetField.text);
        if (!isFinite(target) || target <= 0) return;
        var picked = alarmAssetModel[alarmCoinCombo.currentIndex] || alarmAssetModel[0];
        var direction = alarmDirectionCombo.currentIndex === 1 ? "below" : "above";
        var alarms = priceAlarmRules.slice();
        alarms.push({
            id: "alarm-" + Date.now() + "-" + Math.floor(Math.random() * 100000),
            coin: picked.key,
            direction: direction,
            target: target,
            currency: cfg_currency || "USD",
            enabled: true
        });
        alarmTargetField.text = "";
        savePriceAlarms(alarms);
    }

    function removePriceAlarm(index) {
        var alarms = priceAlarmRules.slice();
        if (index < 0 || index >= alarms.length) return;
        alarms.splice(index, 1);
        savePriceAlarms(alarms);
    }

    function setPriceAlarmEnabled(index, enabled) {
        var alarms = priceAlarmRules.slice();
        if (index < 0 || index >= alarms.length) return;
        alarms[index].enabled = enabled;
        if (enabled && alarms[index].triggeredAt) delete alarms[index].triggeredAt;
        savePriceAlarms(alarms);
    }

    Component.onCompleted: refreshPriceAlarms()
    onCfg_priceAlarmsChanged: refreshPriceAlarms()

    Kirigami.FormLayout {
        Layout.fillWidth: true

        ComboBox {
            id: alarmCoinCombo
            Kirigami.FormData.label: i18n("Coin:")
            Layout.fillWidth: true
            model: alarmAssetModel
            textRole: "label"
            valueRole: "key"
            enabled: alarmAssetModel.length > 0
        }

        ComboBox {
            id: alarmDirectionCombo
            Kirigami.FormData.label: i18n("Condition:")
            model: [
                { key: "above", label: i18n("Breaks above") },
                { key: "below", label: i18n("Breaks below") }
            ]
            textRole: "label"
            valueRole: "key"
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Target:")
            Layout.fillWidth: true

            TextField {
                id: alarmTargetField
                Layout.fillWidth: true
                placeholderText: i18n("Price in %1", cfg_currency)
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                onAccepted: addPriceAlarm()
            }

            Button {
                icon.name: "list-add"
                text: i18n("Add")
                enabled: alarmAssetModel.length > 0 && parseFloat(alarmTargetField.text) > 0
                onClicked: addPriceAlarm()
            }
        }

        Label {
            visible: alarmAssetModel.length === 0
            text: i18n("Add coins to the watchlist before creating alarms.")
            color: Kirigami.Theme.neutralTextColor
            wrapMode: Text.WordWrap
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            visible: priceAlarmRules.length > 0
        }

        ColumnLayout {
            Kirigami.FormData.label: i18n("Alarms:")
            visible: priceAlarmRules.length > 0
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: priceAlarmRules
                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Label {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                        text: modelData.triggeredAt ? i18n("Triggered")
                            : modelData.enabled === false ? i18n("Disabled")
                            : i18n("Active")
                        color: modelData.triggeredAt ? Kirigami.Theme.neutralTextColor
                            : modelData.enabled === false ? Kirigami.Theme.disabledTextColor
                            : Kirigami.Theme.positiveTextColor
                    }

                    Label {
                        Layout.fillWidth: true
                        text: alarmSummary(modelData)
                        opacity: modelData.enabled === false ? 0.65 : 1.0
                        elide: Text.ElideRight
                    }

                    Button {
                        visible: !!modelData.triggeredAt || modelData.enabled === false
                        icon.name: "view-refresh"
                        text: i18n("Enable")
                        onClicked: setPriceAlarmEnabled(index, true)
                    }

                    Button {
                        visible: !modelData.triggeredAt && modelData.enabled !== false
                        icon.name: "media-playback-pause"
                        text: i18n("Disable")
                        onClicked: setPriceAlarmEnabled(index, false)
                    }

                    Button {
                        icon.name: "edit-delete"
                        text: i18n("Delete")
                        onClicked: removePriceAlarm(index)
                    }
                }
            }
        }
    }
}
