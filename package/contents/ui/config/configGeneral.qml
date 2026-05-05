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
    id: configGeneral

    property string cfg_coin
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

    readonly property var allCoins: PriceProvider.getCoins()
    readonly property var coinModel: {
        var arr = [];
        for (var i = 0; i < allCoins.length; i++) {
            var t = allCoins[i];
            var info = PriceProvider.getCoinInfo(t);
            arr.push({ ticker: t, name: info ? info.name : t, label: t + "  —  " + (info ? info.name : t) });
        }
        return arr;
    }

    readonly property var sourcesForCoin: PriceProvider.getSourcesForCoin(cfg_coin)
    readonly property bool currentProviderSupportsWs: cfg_source === 'Binance' || cfg_source === 'Bitfinex'

    function setConfig(key, value) {
        if (Plasmoid.configuration[key] === value) return;
        Plasmoid.configuration[key] = value;
        if (Plasmoid.configuration.writeConfig) {
            Plasmoid.configuration.writeConfig();
        }
    }

    function setCoin(picked) {
        if (!picked || picked === cfg_coin) return;

        cfg_coin = picked;
        setConfig("coin", picked);

        // If current source no longer supports this coin, switch to the first available.
        var sources = PriceProvider.getSourcesForCoin(picked);
        if (sources.indexOf(cfg_source) === -1 && sources.length > 0) {
            cfg_source = sources[0];
            setConfig("source", cfg_source);
        }
    }

    function syncSavedConfig() {
        setConfig("coin", cfg_coin);
        setConfig("source", cfg_source);
        setConfig("currency", cfg_currency);
        setConfig("refreshRate", cfg_refreshRate);
        setConfig("useWebSocket", cfg_useWebSocket);
        setConfig("showIcon", cfg_showIcon);
        setConfig("showText", cfg_showText);
        setConfig("showDecimals", cfg_showDecimals);
        setConfig("showBackground", cfg_showBackground);
        setConfig("onClickAction", cfg_onClickAction);
        setConfig("showPriceChange", cfg_showPriceChange);
    }

    Component.onCompleted: syncSavedConfig()

    Kirigami.FormLayout {
        id: form
        Layout.fillWidth: true

        // ====== Coin ======
        Kirigami.Heading {
            Kirigami.FormData.label: i18n("Coin")
            Kirigami.FormData.isSection: true
            level: 4
        }

        ComboBox {
            id: coinCombo
            Kirigami.FormData.label: i18n("Track:")
            model: coinModel
            textRole: "label"
            valueRole: "ticker"
            editable: true
            // simple substring filter on ticker or name
            currentIndex: {
                for (var i = 0; i < coinModel.length; i++)
                    if (coinModel[i].ticker === cfg_coin) return i;
                return 0;
            }
            onActivated: (idx) => {
                setCoin(coinModel[idx].ticker);
            }
        }

        // ====== Source ======
        Kirigami.Heading {
            Kirigami.FormData.label: i18n("Data Source")
            Kirigami.FormData.isSection: true
            level: 4
        }

        ComboBox {
            id: sourceCombo
            Kirigami.FormData.label: i18n("Source:")
            model: sourcesForCoin
            currentIndex: Math.max(0, model.indexOf(cfg_source))
            onActivated: {
                cfg_source = currentText;
                setConfig("source", cfg_source);
            }
        }

        Label {
            visible: sourcesForCoin.length === 0
            text: i18n("No sources available for this coin")
            color: Kirigami.Theme.negativeTextColor
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Connection:")
            visible: currentProviderSupportsWs
            spacing: Kirigami.Units.mediumSpacing

            Rectangle {
                width: 8; height: 8; radius: 4
                color: Kirigami.Theme.positiveTextColor
            }
            Label {
                text: i18n("WebSocket available for live updates")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
            }
        }

        CheckBox {
            visible: currentProviderSupportsWs
            checked: cfg_useWebSocket
            text: i18n("Use WebSocket for real-time updates")
            onCheckedChanged: {
                cfg_useWebSocket = checked;
                setConfig("useWebSocket", checked);
            }
        }

        Label {
            visible: !currentProviderSupportsWs
            text: i18n("This source uses polling (REST API)")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.6
            leftPadding: Kirigami.Units.mediumSpacing
        }

        // ====== Currency ======
        Kirigami.Heading {
            Kirigami.FormData.label: i18n("Display")
            Kirigami.FormData.isSection: true
            level: 4
        }

        ComboBox {
            id: currencyCombo
            Kirigami.FormData.label: i18n("Currency:")
            model: PriceProvider.getCurrencies()
            currentIndex: Math.max(0, model.indexOf(cfg_currency))
            onActivated: {
                cfg_currency = currentText;
                setConfig("currency", cfg_currency);
            }
        }

        CheckBox {
            checked: cfg_showDecimals
            text: i18n("Show decimal places")
            onCheckedChanged: {
                cfg_showDecimals = checked;
                setConfig("showDecimals", checked);
            }
        }

        CheckBox {
            checked: cfg_showPriceChange
            text: i18n("Show 24h change")
            onCheckedChanged: {
                cfg_showPriceChange = checked;
                setConfig("showPriceChange", checked);
            }
        }

        // ====== Refresh ======
        Kirigami.Heading {
            Kirigami.FormData.label: i18n("Refresh")
            Kirigami.FormData.isSection: true
            level: 4
            visible: !cfg_useWebSocket || !currentProviderSupportsWs
        }

        SpinBox {
            Kirigami.FormData.label: i18n("Interval:")
            visible: !cfg_useWebSocket || !currentProviderSupportsWs
            from: 1
            to: 60
            value: cfg_refreshRate
            textFromValue: (v) => v + i18n(" min")
            valueFromText: (t) => parseInt(t)
            onValueModified: {
                cfg_refreshRate = value;
                setConfig("refreshRate", value);
            }
        }

        // ====== Widget ======
        Kirigami.Heading {
            Kirigami.FormData.label: i18n("Widget")
            Kirigami.FormData.isSection: true
            level: 4
        }

        CheckBox {
            id: showIconCheck
            checked: cfg_showIcon
            text: i18n("Show coin badge")
            onCheckedChanged: {
                cfg_showIcon = checked;
                setConfig("showIcon", checked);
                if (!checked && !cfg_showText) {
                    cfg_showText = true;
                    showTextCheck.checked = true;
                    setConfig("showText", true);
                }
            }
        }

        CheckBox {
            id: showTextCheck
            checked: cfg_showText
            text: i18n("Show price text")
            onCheckedChanged: {
                cfg_showText = checked;
                setConfig("showText", checked);
                if (!checked && !cfg_showIcon) {
                    cfg_showIcon = true;
                    showIconCheck.checked = true;
                    setConfig("showIcon", true);
                }
            }
        }

        CheckBox {
            checked: cfg_showBackground
            text: i18n("Show background")
            onCheckedChanged: {
                cfg_showBackground = checked;
                setConfig("showBackground", checked);
            }
        }

        // ====== Click action ======
        Kirigami.Heading {
            Kirigami.FormData.label: i18n("Click action")
            Kirigami.FormData.isSection: true
            level: 4
        }

        ButtonGroup { id: clickActionGroup }

        RadioButton {
            checked: cfg_onClickAction === "refresh"
            text: i18n("Refresh price")
            ButtonGroup.group: clickActionGroup
            onCheckedChanged: if (checked) {
                cfg_onClickAction = "refresh";
                setConfig("onClickAction", cfg_onClickAction);
            }
        }

        RadioButton {
            checked: cfg_onClickAction === "website"
            text: i18n("Open market website")
            ButtonGroup.group: clickActionGroup
            onCheckedChanged: if (checked) {
                cfg_onClickAction = "website";
                setConfig("onClickAction", cfg_onClickAction);
            }
        }
    }
}
