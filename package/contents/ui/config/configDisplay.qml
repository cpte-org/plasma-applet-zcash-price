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
    id: configDisplay

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

    readonly property var sourcesForCoin: PriceProvider.getSourcesForCoin(cfg_coin)
    readonly property bool currentProviderSupportsWs: sourcesForCoin.indexOf(cfg_source) >= 0 &&
        (cfg_source === "Binance" || cfg_source === "Bitfinex")

    function setConfig(key, value) {
        if (Plasmoid.configuration[key] === value) return;
        Plasmoid.configuration[key] = value;
        if (Plasmoid.configuration.writeConfig) {
            Plasmoid.configuration.writeConfig();
        }
    }

    Kirigami.FormLayout {
        Layout.fillWidth: true

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

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
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

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
        }

        SpinBox {
            Kirigami.FormData.label: i18n("Refresh interval:")
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

        Label {
            visible: cfg_useWebSocket && currentProviderSupportsWs
            text: i18n("Refresh interval is hidden while WebSocket live updates are active.")
            color: Kirigami.Theme.neutralTextColor
            wrapMode: Text.WordWrap
        }

        ButtonGroup { id: clickActionGroup }

        RadioButton {
            Kirigami.FormData.label: i18n("Click:")
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
