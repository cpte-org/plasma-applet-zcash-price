/*
 *   Copyright (C) 2024 Zcash Price Applet Contributors
 *   SPDX-License-Identifier: GPL-3.0
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.config as KConfig  // KF6 Config module
import ".."
import "../../code/PriceProvider.js" as PriceProvider

KCM.SimpleKCM {
    id: configGeneral

    // Configuration properties
    property string cfg_source
    property string cfg_currency
    property int cfg_refreshRate
    property bool cfg_useWebSocket
    property bool cfg_showIcon
    property bool cfg_showText
    property bool cfg_showDecimals
    property bool cfg_showBackground
    property string cfg_onClickAction
    property bool cfg_showPriceChange

    Kirigami.FormLayout {
        id: form
        Layout.fillWidth: true

        // ========== Data Source Section ==========
        Kirigami.Heading {
            Kirigami.FormData.label: i18n("Data Source")
            Kirigami.FormData.isSection: true
            level: 4
        }

        ComboBox {
            id: sourceCombo
            Kirigami.FormData.label: i18n("Price source:")
            model: PriceProvider.getSources()
            currentIndex: model.indexOf(cfg_source) >= 0 ? model.indexOf(cfg_source) : 0
            onActivated: cfg_source = currentText
        }

        // WebSocket support indicator and toggle
        RowLayout {
            Kirigami.FormData.label: i18n("Connection:")
            visible: currentProviderSupportsWs
            spacing: Kirigami.Units.mediumSpacing

            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: "#4CAF50"
            }

            Label {
                text: i18n("WebSocket available for live updates")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
            }
        }

        CheckBox {
            id: useWebSocketCheck
            visible: currentProviderSupportsWs
            checked: cfg_useWebSocket
            text: i18n("Use WebSocket for real-time price updates")
            onCheckedChanged: cfg_useWebSocket = checked
        }

        Label {
            visible: !currentProviderSupportsWs
            text: i18n("This source uses polling (REST API)")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.6
            leftPadding: Kirigami.Units.mediumSpacing
        }

        // ========== Currency Section ==========
        Kirigami.Heading {
            Kirigami.FormData.label: i18n("Currency")
            Kirigami.FormData.isSection: true
            level: 4
        }

        ComboBox {
            id: currencyCombo
            Kirigami.FormData.label: i18n("Display currency:")
            model: PriceProvider.getCurrencies()
            currentIndex: model.indexOf(cfg_currency) >= 0 ? model.indexOf(cfg_currency) : 0
            onActivated: cfg_currency = currentText
        }

        CheckBox {
            id: showDecimalsCheck
            checked: cfg_showDecimals
            text: i18n("Show decimal places")
            onCheckedChanged: cfg_showDecimals = checked
        }

        CheckBox {
            id: showPriceChangeCheck
            checked: cfg_showPriceChange
            text: i18n("Show 24h price change percentage")
            onCheckedChanged: cfg_showPriceChange = checked
        }

        // ========== Refresh Section ==========
        Kirigami.Heading {
            Kirigami.FormData.label: i18n("Refresh")
            Kirigami.FormData.isSection: true
            level: 4
            visible: !cfg_useWebSocket || !currentProviderSupportsWs
        }

        SpinBox {
            id: refreshRateSpin
            Kirigami.FormData.label: i18n("Refresh interval:")
            visible: !cfg_useWebSocket || !currentProviderSupportsWs
            from: 1
            to: 60
            value: cfg_refreshRate
            textFromValue: function(value, locale) {
                return value + i18n(" minutes");
            }
            valueFromText: function(text, locale) {
                return parseInt(text);
            }
            onValueModified: cfg_refreshRate = value
        }

        // ========== Display Section ==========
        Kirigami.Heading {
            Kirigami.FormData.label: i18n("Display")
            Kirigami.FormData.isSection: true
            level: 4
        }

        CheckBox {
            id: showIconCheck
            checked: cfg_showIcon
            text: i18n("Show Zcash icon")
            onCheckedChanged: {
                cfg_showIcon = checked;
                // Ensure at least one display option is enabled
                if (!checked && !cfg_showText) {
                    cfg_showText = true;
                    showTextCheck.checked = true;
                }
            }
        }

        CheckBox {
            id: showTextCheck
            checked: cfg_showText
            text: i18n("Show price text")
            onCheckedChanged: {
                cfg_showText = checked;
                // Ensure at least one display option is enabled
                if (!checked && !cfg_showIcon) {
                    cfg_showIcon = true;
                    showIconCheck.checked = true;
                }
            }
        }

        CheckBox {
            id: showBackgroundCheck
            checked: cfg_showBackground
            text: i18n("Show background")
            onCheckedChanged: cfg_showBackground = checked
        }

        // ========== Interaction Section ==========
        Kirigami.Heading {
            Kirigami.FormData.label: i18n("Interaction")
            Kirigami.FormData.isSection: true
            level: 4
        }

        Label {
            Kirigami.FormData.label: i18n("On click:")
            text: i18n("Action when clicking the widget:")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.7
        }

        ButtonGroup {
            id: clickActionGroup
        }

        RadioButton {
            checked: cfg_onClickAction === "refresh"
            text: i18n("Refresh price")
            ButtonGroup.group: clickActionGroup
            onCheckedChanged: if (checked) cfg_onClickAction = "refresh"
        }

        RadioButton {
            checked: cfg_onClickAction === "website"
            text: i18n("Open market website")
            ButtonGroup.group: clickActionGroup
            onCheckedChanged: if (checked) cfg_onClickAction = "website"
        }
    }

    // Helper property to check if current provider supports WebSocket
    property bool currentProviderSupportsWs: {
        var provider = PriceProvider.createProvider(cfg_source, {});
        var supports = provider ? provider.supportsWebSocket : false;
        if (provider && provider.destroy) provider.destroy();
        return supports;
    }

    // Sync UI with config on load
    Component.onCompleted: {
        sourceCombo.currentIndex = Math.max(0, sourceCombo.model.indexOf(cfg_source));
        currencyCombo.currentIndex = Math.max(0, currencyCombo.model.indexOf(cfg_currency));
    }
}
