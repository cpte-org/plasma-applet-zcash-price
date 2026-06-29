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
import org.kde.plasma.plasma5support as P5Support
import "../../code/PriceProvider.js" as PriceProvider

KCM.SimpleKCM {
    id: configGeneral

    property string cfg_coin
    property string cfg_displayMode
    property var cfg_coins
    property string cfg_source
    property string cfg_marketCache
    property bool cfg_useWebSocket
    property string marketSearch: ""
    property var sourceMarkets: []
    property var filteredSourceMarkets: []
    property bool marketRefreshing: false
    property bool marketRefreshFailed: false
    property bool marketUsingCachedFallback: false
    property real marketUpdatedAt: 0
    property string pendingCurlMarketSource: ""
    property string pendingCurlMarketCommand: ""

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
    readonly property bool currentProviderSupportsWs: sourcesForCoin.indexOf(cfg_source) >= 0 &&
        (cfg_source === 'Binance' || cfg_source === 'Bitfinex')
    readonly property var selectedDynamicCoins: {
        var out = [];
        var arr = cfg_coins || [];
        for (var i = 0; i < arr.length; i++) {
            var ref = "" + arr[i];
            if (ref.indexOf("dyn:") !== 0) continue;
            var info = PriceProvider.getAssetInfo(ref);
            if (!info) continue;
            out.push({ key: ref, ticker: info.ticker || ref, name: info.name || ref });
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

    function setCoin(picked) {
        if (!picked || picked === cfg_coin) return;

        cfg_coin = normalizeAssetRef(picked);
        setConfig("coin", cfg_coin);

        // If current source no longer supports this coin, switch to the first available.
        var sources = PriceProvider.getSourcesForCoin(cfg_coin);
        if (sources.indexOf(cfg_source) === -1 && sources.length > 0) {
            cfg_source = sources[0];
            setConfig("source", cfg_source);
        }
    }

    function syncSavedConfig() {
        setConfig("coin", cfg_coin);
        setConfig("displayMode", cfg_displayMode);
        setConfig("coins", cfg_coins);
        setConfig("source", cfg_source);
        setConfig("marketCache", cfg_marketCache);
        setConfig("useWebSocket", cfg_useWebSocket);
    }

    function normalizeAssetRef(ref) {
        var s = ("" + ref).trim();
        return s.indexOf("dyn:") === 0 ? s : s.toUpperCase();
    }

    function isCoinChecked(ticker) {
        var wanted = normalizeAssetRef(ticker);
        if (!cfg_coins) return false;
        for (var i = 0; i < cfg_coins.length; i++) {
            if (normalizeAssetRef(cfg_coins[i]) === wanted) return true;
        }
        return false;
    }

    function toggleCoin(ticker, checked) {
        var wanted = normalizeAssetRef(ticker);
        var arr = [];
        if (cfg_coins) {
            for (var i = 0; i < cfg_coins.length; i++) {
                var t = normalizeAssetRef(cfg_coins[i]);
                if (t !== wanted) arr.push(t);
            }
        }
        if (checked) arr.push(wanted);
        cfg_coins = arr;
        setConfig("coins", arr);
    }

    function refreshMarketFilter() {
        var q = marketSearch.trim().toLowerCase();
        var out = [];
        for (var i = 0; i < sourceMarkets.length && out.length < 120; i++) {
            var a = sourceMarkets[i];
            var hay = (a.ticker + " " + a.name + " " + a.sourceId).toLowerCase();
            if (!q || hay.indexOf(q) >= 0) out.push(a);
        }
        filteredSourceMarkets = out;
    }

    function loadSourceMarkets() {
        loadSourceMarketsWithMode(false);
    }

    function loadSourceMarketsWithMode(forceRefresh) {
        var source = cfg_source || "Binance";
        marketRefreshing = true;
        marketRefreshFailed = false;
        marketUsingCachedFallback = false;
        if (sourceMarkets.length === 0) filteredSourceMarkets = [];
        PriceProvider.fetchSourceAssets(source, {
            forceRefresh: forceRefresh,
            allowStale: true,
            ttlMs: PriceProvider.MARKET_CACHE_TTL_MS
        }, function(items, meta) {
            if (source !== cfg_source) return;
            sourceMarkets = items || [];
            marketRefreshing = !!(meta && meta.refreshing);
            marketRefreshFailed = !!(meta && meta.failed && forceRefresh && sourceMarkets.length === 0);
            marketUsingCachedFallback = !!(meta && meta.failed && sourceMarkets.length > 0);
            marketUpdatedAt = meta && meta.at ? meta.at : 0;
            if (meta && !meta.fromCache && !meta.failed) {
                cfg_marketCache = PriceProvider.exportMarketCache();
                setConfig("marketCache", cfg_marketCache);
            }
            refreshMarketFilter();
            if (meta && meta.failed && sourceMarkets.length === 0) {
                fetchSourceMarketsWithCurl(source);
            }
        });
    }

    function shellQuote(value) {
        return "'" + ("" + value).replace(/'/g, "'\\''") + "'";
    }

    function fetchSourceMarketsWithCurl(source) {
        var url = PriceProvider.getMarketUrl(source);
        if (!url) {
            marketRefreshing = false;
            marketRefreshFailed = true;
            return;
        }
        cancelCurlMarketRefresh();
        pendingCurlMarketSource = source;
        marketRefreshing = true;
        marketRefreshFailed = false;
        var cmd = "curl -L -sS --max-time 25 -H " + shellQuote("Accept: application/json") + " " + shellQuote(url);
        pendingCurlMarketCommand = cmd;
        marketCurlSource.connectSource(cmd);
    }

    function cancelCurlMarketRefresh() {
        if (pendingCurlMarketCommand) {
            marketCurlSource.disconnectSource(pendingCurlMarketCommand);
        }
        pendingCurlMarketCommand = "";
        pendingCurlMarketSource = "";
    }

    P5Support.DataSource {
        id: marketCurlSource
        engine: "executable"
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            if (sourceName !== pendingCurlMarketCommand) return;
            var source = pendingCurlMarketSource || cfg_source || "Binance";
            pendingCurlMarketCommand = "";
            pendingCurlMarketSource = "";
            var stdout = data && data.stdout ? data.stdout : "";
            var items = PriceProvider.parseSourceAssets(source, stdout);
            if (items.length > 0) {
                PriceProvider.storeSourceAssets(source, items, Date.now());
                cfg_marketCache = PriceProvider.exportMarketCache();
                setConfig("marketCache", cfg_marketCache);
                if (source !== cfg_source) return;
                sourceMarkets = items;
                marketRefreshing = false;
                marketRefreshFailed = false;
                marketUsingCachedFallback = false;
                marketUpdatedAt = Date.now();
                refreshMarketFilter();
            } else if (source === cfg_source) {
                marketRefreshing = false;
                marketRefreshFailed = true;
                marketUsingCachedFallback = false;
                refreshMarketFilter();
            }
        }
    }

    function marketStatusText() {
        if (marketRefreshing) return i18n("Refreshing...");
        if (marketUpdatedAt > 0 && marketUsingCachedFallback) {
            return i18n("Using cached markets from %1", Qt.formatDateTime(new Date(marketUpdatedAt), Qt.locale().dateTimeFormat(Locale.ShortFormat)));
        }
        if (marketUpdatedAt > 0) {
            return i18n("Updated %1", Qt.formatDateTime(new Date(marketUpdatedAt), Qt.locale().dateTimeFormat(Locale.ShortFormat)));
        }
        if (marketRefreshFailed) return i18n("Market search unavailable");
        return i18n("Market search not loaded");
    }

    Component.onCompleted: {
        PriceProvider.restoreMarketCache(cfg_marketCache);
        syncSavedConfig();
        loadSourceMarkets();
    }

    onCfg_sourceChanged: {
        cancelCurlMarketRefresh();
        loadSourceMarkets();
    }

    Kirigami.FormLayout {
        id: form
        Layout.fillWidth: true

        // ====== Display mode ======
        Kirigami.Heading {
            Kirigami.FormData.label: i18n("Display mode")
            Kirigami.FormData.isSection: true
            level: 4
        }

        ButtonGroup { id: modeGroup }

        RadioButton {
            Kirigami.FormData.label: i18n("Mode:")
            checked: cfg_displayMode === "single"
            text: i18n("Single coin")
            ButtonGroup.group: modeGroup
            onCheckedChanged: if (checked) { cfg_displayMode = "single"; setConfig("displayMode", "single"); }
        }
        RadioButton {
            checked: cfg_displayMode === "rotation"
            text: i18n("Rotation (TV news style)")
            ButtonGroup.group: modeGroup
            onCheckedChanged: if (checked) { cfg_displayMode = "rotation"; setConfig("displayMode", "rotation"); }
        }
        RadioButton {
            checked: cfg_displayMode === "stacked"
            text: i18n("Stacked (auto-scrolls when full)")
            ButtonGroup.group: modeGroup
            onCheckedChanged: if (checked) { cfg_displayMode = "stacked"; setConfig("displayMode", "stacked"); }
        }

        // ====== Coin (single mode) ======
        Kirigami.Heading {
            Kirigami.FormData.label: i18n("Coin")
            Kirigami.FormData.isSection: true
            level: 4
            visible: cfg_displayMode === "single"
        }

        ComboBox {
            id: coinCombo
            visible: cfg_displayMode === "single"
            Kirigami.FormData.label: i18n("Track:")
            model: coinModel
            textRole: "label"
            valueRole: "ticker"
            editable: true
            currentIndex: {
                for (var i = 0; i < coinModel.length; i++)
                    if (coinModel[i].ticker === cfg_coin) return i;
                return 0;
            }
            onActivated: (idx) => {
                setCoin(coinModel[idx].ticker);
            }
        }

        TextField {
            visible: cfg_displayMode === "single"
            Kirigami.FormData.label: i18n("Source search:")
            text: marketSearch
            placeholderText: i18n("Search markets from selected source")
            onTextChanged: {
                marketSearch = text;
                refreshMarketFilter();
            }
        }

        RowLayout {
            visible: cfg_displayMode === "single"
            Layout.fillWidth: true
            ComboBox {
                id: singleMarketCombo
                Layout.fillWidth: true
                model: filteredSourceMarkets
                textRole: "label"
                valueRole: "key"
                enabled: filteredSourceMarkets.length > 0
            }
            Button {
                text: i18n("Track")
                enabled: filteredSourceMarkets.length > 0
                onClicked: {
                    var a = filteredSourceMarkets[singleMarketCombo.currentIndex];
                    if (a) setCoin(a.key);
                }
            }
        }

        RowLayout {
            visible: cfg_displayMode === "single"
            Layout.fillWidth: true
            Button {
                icon.name: "view-refresh"
                text: i18n("Refresh markets")
                enabled: !marketRefreshing
                onClicked: loadSourceMarketsWithMode(true)
            }
            Label {
                Layout.fillWidth: true
                text: marketStatusText()
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
                elide: Text.ElideRight
            }
        }

        // ====== Coins (multi-coin modes) ======
        Kirigami.Heading {
            Kirigami.FormData.label: i18n("Watchlist")
            Kirigami.FormData.isSection: true
            level: 4
            visible: cfg_displayMode !== "single"
        }

        Label {
            Kirigami.FormData.label: i18n("Coins:")
            visible: cfg_displayMode !== "single"
            text: i18n("Pick one or more — preferred source applies per coin, with fallback.")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.7
            wrapMode: Text.WordWrap
        }

        Flow {
            visible: cfg_displayMode !== "single"
            Layout.preferredWidth: 480
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: coinModel
                delegate: Button {
                    text: modelData.ticker
                    checkable: true
                    checked: isCoinChecked(modelData.ticker)
                    horizontalPadding: Kirigami.Units.largeSpacing
                    verticalPadding: Kirigami.Units.smallSpacing
                    onToggled: toggleCoin(modelData.ticker, checked)
                    ToolTip.visible: hovered
                    ToolTip.text: modelData.name

                    contentItem: Label {
                        text: parent.text
                        color: parent.checked ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                        font.bold: parent.checked
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: Kirigami.Units.smallSpacing
                        color: parent.checked ? Kirigami.Theme.highlightColor : "transparent"
                        border.width: 1
                        border.color: parent.checked ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
                    }
                }
            }
        }

        Flow {
            visible: cfg_displayMode !== "single" && selectedDynamicCoins.length > 0
            Layout.preferredWidth: 480
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: selectedDynamicCoins
                delegate: Button {
                    text: modelData.ticker
                    checkable: true
                    checked: true
                    horizontalPadding: Kirigami.Units.largeSpacing
                    verticalPadding: Kirigami.Units.smallSpacing
                    onToggled: if (!checked) toggleCoin(modelData.key, false)
                    ToolTip.visible: hovered
                    ToolTip.text: modelData.name

                    contentItem: Label {
                        text: parent.text
                        color: Kirigami.Theme.highlightedTextColor
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: Kirigami.Units.smallSpacing
                        color: Kirigami.Theme.highlightColor
                        border.width: 1
                        border.color: Kirigami.Theme.highlightColor
                    }
                }
            }
        }

        TextField {
            visible: cfg_displayMode !== "single"
            Kirigami.FormData.label: i18n("Source search:")
            text: marketSearch
            placeholderText: i18n("Search markets from selected source")
            onTextChanged: {
                marketSearch = text;
                refreshMarketFilter();
            }
        }

        RowLayout {
            visible: cfg_displayMode !== "single"
            Layout.fillWidth: true
            ComboBox {
                id: multiMarketCombo
                Layout.fillWidth: true
                model: filteredSourceMarkets
                textRole: "label"
                valueRole: "key"
                enabled: filteredSourceMarkets.length > 0
            }
            Button {
                text: i18n("Add")
                enabled: filteredSourceMarkets.length > 0
                onClicked: {
                    var a = filteredSourceMarkets[multiMarketCombo.currentIndex];
                    if (a) toggleCoin(a.key, true);
                }
            }
        }

        RowLayout {
            visible: cfg_displayMode !== "single"
            Layout.fillWidth: true
            Button {
                icon.name: "view-refresh"
                text: i18n("Refresh markets")
                enabled: !marketRefreshing
                onClicked: loadSourceMarketsWithMode(true)
            }
            Label {
                Layout.fillWidth: true
                text: marketStatusText()
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
                elide: Text.ElideRight
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
            model: PriceProvider.getSources()
            currentIndex: Math.max(0, model.indexOf(cfg_source))
            onActivated: {
                cfg_source = currentText;
                setConfig("source", cfg_source);
                loadSourceMarkets();
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

    }
}
