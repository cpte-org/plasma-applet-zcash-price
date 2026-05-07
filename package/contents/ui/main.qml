/*
 *   Copyright (C) 2024 Crypto Price Applet Contributors
 *   SPDX-License-Identifier: GPL-3.0
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import "../code/PriceProvider.js" as PriceProvider

PlasmoidItem {
    id: root

    // ---- State
    property var providersByCoin: ({})
    property int providerGeneration: 0
    property string modelKey: ""
    property date lastSuccessfulUpdate
    property real lastTickEpoch: 0
    property bool anyWsConnected: false
    property bool compactHovered: false

    // Multi-coin model. One row per effective coin.
    ListModel { id: coinModel }

    // ---- Config
    readonly property string cfgCoin: plasmoid.configuration.coin
    readonly property string cfgDisplayMode: plasmoid.configuration.displayMode
    readonly property var cfgCoinsList: plasmoid.configuration.coins
    readonly property string cfgSource: plasmoid.configuration.source
    readonly property string cfgCurrency: plasmoid.configuration.currency
    readonly property int cfgRefreshRate: plasmoid.configuration.refreshRate
    readonly property bool cfgUseWebSocket: plasmoid.configuration.useWebSocket
    readonly property bool cfgShowIcon: plasmoid.configuration.showIcon
    readonly property bool cfgShowText: plasmoid.configuration.showText
    readonly property bool cfgShowDecimals: plasmoid.configuration.showDecimals
    readonly property bool cfgShowBackground: plasmoid.configuration.showBackground
    readonly property string cfgOnClickAction: plasmoid.configuration.onClickAction
    readonly property bool cfgShowPriceChange: plasmoid.configuration.showPriceChange

    readonly property var effectiveCoins: {
        if (cfgDisplayMode === "single") return [cfgCoin];
        var arr = cfgCoinsList || [];
        var seen = {}, out = [];
        for (var i = 0; i < arr.length; i++) {
            var c = ("" + arr[i]).trim().toUpperCase();
            if (!c || seen[c]) continue;
            if (!PriceProvider.getCoinInfo(c)) continue;
            seen[c] = true; out.push(c);
        }
        return out.length ? out : [cfgCoin];
    }

    readonly property int pollIntervalMs: cfgRefreshRate * 60 * 1000
    readonly property color upColor: Kirigami.Theme.positiveTextColor
    readonly property color downColor: Kirigami.Theme.negativeTextColor

    // Rotation/marquee timing — fixed sensible defaults.
    readonly property int rotationIntervalMs: 5000
    readonly property int rotationFadeMs: 250
    readonly property real marqueePxPerSec: 30

    // ---- No hover tooltip/popup
    preferredRepresentation: compactRepresentation
    activationTogglesExpanded: false
    toolTipMainText: ""
    toolTipSubText: ""
    toolTipItem: Item { width: 0; height: 0; visible: false }
    Plasmoid.backgroundHints: cfgShowBackground ? PlasmaCore.Types.StandardBackground : PlasmaCore.Types.NoBackground

    // ========== Coin badge ==========
    Component {
        id: coinBadgeComponent
        Item {
            property real diameter: 16
            property string ticker: ""
            property color badgeColor: Kirigami.Theme.highlightColor
            implicitWidth: tickerLabel.implicitWidth
            implicitHeight: diameter
            PlasmaComponents.Label {
                id: tickerLabel
                anchors.centerIn: parent
                text: parent.ticker
                color: Kirigami.Theme.textColor
                font.bold: true
                font.weight: Font.Bold
                font.pointSize: Math.max(Kirigami.Theme.defaultFont.pointSize, parent.diameter * 0.55)
                font.letterSpacing: 0
                renderType: Text.NativeRendering
            }
        }
    }

    // ========== Reusable coin row (badge + price + 24h%) ==========
    Component {
        id: coinChipComponent
        RowLayout {
            id: chip
            property string ticker: ""
            property string priceText: "..."
            property string changeText: ""
            property bool priceUp: false
            property color tickerColor: Kirigami.Theme.highlightColor
            property bool busy: false
            spacing: Kirigami.Units.smallSpacing

            Loader {
                visible: cfgShowIcon
                Layout.alignment: Qt.AlignVCenter
                sourceComponent: coinBadgeComponent
                onLoaded: applyBadge()
                function applyBadge() {
                    if (!item) return;
                    item.diameter = Math.min((parent && parent.height ? parent.height : 22) * 0.85,
                                             Kirigami.Units.iconSizes.smallMedium);
                    item.ticker = chip.ticker;
                    item.badgeColor = chip.tickerColor;
                }
                Connections {
                    target: chip
                    function onTickerChanged() { applyBadge(); }
                }
                opacity: chip.busy ? 0.4 : 1.0
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            PlasmaComponents.Label {
                visible: cfgShowText
                text: chip.priceText
                font.bold: true
                font.pointSize: cfgShowIcon ? Kirigami.Theme.defaultFont.pointSize : Kirigami.Theme.defaultFont.pointSize + 1
                opacity: chip.busy ? 0.4 : 1.0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Layout.alignment: Qt.AlignVCenter
            }

            PlasmaComponents.Label {
                visible: cfgShowPriceChange && chip.changeText !== ""
                text: chip.changeText
                color: chip.priceUp ? root.upColor : root.downColor
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    // ========== Compact representation ==========
    compactRepresentation: Item {
        id: compactRoot

        readonly property bool isMulti: cfgDisplayMode !== "single"
        readonly property real preferredW: contentLoader.item ? contentLoader.item.implicitContentWidth + Kirigami.Units.smallSpacing * 2 : 80
        readonly property real cappedW: Math.min(preferredW, 600)

        Layout.fillWidth: cfgDisplayMode === "stacked"
        Layout.fillHeight: true
        Layout.minimumWidth: cfgDisplayMode === "stacked"
            ? Math.min(120, preferredW)
            : preferredW
        Layout.preferredWidth: cappedW
        Layout.maximumWidth: cfgDisplayMode === "stacked" ? cappedW : preferredW

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: cfgDisplayMode !== "single"
            acceptedButtons: Qt.NoButton
            onContainsMouseChanged: root.compactHovered = containsMouse
        }

        Loader {
            id: contentLoader
            anchors.fill: parent
            sourceComponent: cfgDisplayMode === "rotation" ? rotationViewC
                           : cfgDisplayMode === "stacked"  ? stackedViewC
                                                           : singleViewC
        }

        BusyIndicator {
            anchors.centerIn: parent
            running: coinModel.count === 0
            visible: running
            width: Math.min(parent.height * 0.6, 16)
            height: width
        }
    }

    // ---------- Reactive coin chip delegate (binds to a model row) ----------
    Component {
        id: reactiveChipC
        Loader {
            id: rl
            property var rowModel: null
            sourceComponent: coinChipComponent
            onLoaded: bindRow()
            function bindRow() {
                if (!item || !rowModel) return;
                item.ticker      = Qt.binding(function() { return rowModel.coin; });
                item.priceText   = Qt.binding(function() { return rowModel.displayPrice; });
                item.changeText  = Qt.binding(function() { return rowModel.displayChange; });
                item.priceUp     = Qt.binding(function() { return rowModel.isUp; });
                item.tickerColor = Qt.binding(function() { return rowModel.coinColor; });
                item.busy        = Qt.binding(function() { return rowModel.displayPrice === "..."; });
            }
            onRowModelChanged: bindRow()
        }
    }

    // ---------- Single view (uses coinModel row 0) ----------
    Component {
        id: singleViewC
        Item {
            id: singleRoot
            anchors.fill: parent
            property real implicitContentWidth: chipL.item ? chipL.item.implicitWidth + Kirigami.Units.smallSpacing * 2 : 80

            Loader {
                id: chipL
                anchors.centerIn: parent
                sourceComponent: reactiveChipC
                Component.onCompleted: bindRow()
                function bindRow() {
                    if (item && coinModel.count > 0) item.rowModel = coinModel.get(0);
                }
                Connections {
                    target: coinModel
                    function onCountChanged() { chipL.bindRow(); }
                }
            }

            // WS status dot at left edge.
            Rectangle {
                visible: {
                    if (!cfgUseWebSocket || coinModel.count === 0) return false;
                    return coinModel.get(0).supportsWs;
                }
                width: 6; height: 6; radius: 3
                color: (coinModel.count > 0 && coinModel.get(0).isWsConnected) ? root.upColor : root.downColor
                anchors.left: parent.left
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (cfgOnClickAction === "website")
                        openCoinWebsite(coinModel.count > 0 ? coinModel.get(0).coin : cfgCoin);
                    else
                        refreshAll();
                }
            }
        }
    }

    // ---------- Rotation view ----------
    Component {
        id: rotationViewC
        Item {
            id: rotation
            anchors.fill: parent
            property int index: 0
            property real implicitContentWidth: rotChip.item ? rotChip.item.implicitWidth + Kirigami.Units.smallSpacing * 2 : 80
            property real visibleOpacity: 1.0

            function advance() {
                if (coinModel.count === 0) return;
                index = (index + 1) % coinModel.count;
                rotChip.bindRow();
            }

            Loader {
                id: rotChip
                anchors.centerIn: parent
                opacity: rotation.visibleOpacity
                sourceComponent: reactiveChipC
                Component.onCompleted: bindRow()
                function bindRow() {
                    if (!item || coinModel.count === 0) return;
                    var i = Math.min(rotation.index, coinModel.count - 1);
                    item.rowModel = coinModel.get(i);
                }
                Connections {
                    target: coinModel
                    function onCountChanged() {
                        if (rotation.index >= coinModel.count) rotation.index = 0;
                        rotChip.bindRow();
                    }
                }
            }

            SequentialAnimation {
                id: rotateAnim
                loops: Animation.Infinite
                running: coinModel.count > 1 && !root.compactHovered
                PauseAnimation { duration: Math.max(0, root.rotationIntervalMs - root.rotationFadeMs * 2) }
                NumberAnimation { target: rotation; property: "visibleOpacity"; to: 0; duration: root.rotationFadeMs }
                ScriptAction { script: rotation.advance() }
                NumberAnimation { target: rotation; property: "visibleOpacity"; to: 1; duration: root.rotationFadeMs }
            }

            Connections {
                target: rotateAnim
                function onRunningChanged() { if (!rotateAnim.running) rotation.visibleOpacity = 1; }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: false
                onClicked: {
                    if (coinModel.count === 0) return;
                    var i = Math.min(rotation.index, coinModel.count - 1);
                    openCoinWebsite(coinModel.get(i).coin);
                }
            }
        }
    }

    // ---------- Stacked view (marquee on overflow) ----------
    Component {
        id: stackedViewC
        Item {
            id: stack
            anchors.fill: parent
            clip: true

            property real chipSpacing: Kirigami.Units.largeSpacing * 2
            property real loopWidth: chipsA.width + chipSpacing
            property bool needsScroll: chipsA.width > stack.width
            property real implicitContentWidth: chipsA.width + Kirigami.Units.smallSpacing * 2

            Row {
                id: marquee
                anchors.verticalCenter: parent.verticalCenter
                spacing: stack.chipSpacing
                x: 0

                Row {
                    id: chipsA
                    spacing: stack.chipSpacing
                    Repeater {
                        model: coinModel
                        delegate: Item {
                            implicitWidth: chipL.item ? chipL.item.implicitWidth : 0
                            implicitHeight: chipL.item ? chipL.item.implicitHeight : 0
                            width: implicitWidth
                            height: stack.height
                            Loader {
                                id: chipL
                                anchors.centerIn: parent
                                sourceComponent: reactiveChipC
                                onLoaded: { if (item) item.rowModel = model; }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: openCoinWebsite(model.coin)
                            }
                        }
                    }
                }

                Row {
                    id: chipsB
                    spacing: stack.chipSpacing
                    visible: stack.needsScroll
                    Repeater {
                        model: coinModel
                        delegate: Item {
                            implicitWidth: chipL2.item ? chipL2.item.implicitWidth : 0
                            implicitHeight: chipL2.item ? chipL2.item.implicitHeight : 0
                            width: implicitWidth
                            height: stack.height
                            Loader {
                                id: chipL2
                                anchors.centerIn: parent
                                sourceComponent: reactiveChipC
                                onLoaded: { if (item) item.rowModel = model; }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: openCoinWebsite(model.coin)
                            }
                        }
                    }
                }
            }

            NumberAnimation {
                id: marqueeAnim
                target: marquee
                property: "x"
                from: 0
                to: -stack.loopWidth
                duration: Math.max(2000, (stack.loopWidth / root.marqueePxPerSec) * 1000)
                loops: Animation.Infinite
                running: stack.needsScroll && !root.compactHovered && stack.loopWidth > 0
            }

            onNeedsScrollChanged: if (!needsScroll) marquee.x = 0
            onLoopWidthChanged: if (!needsScroll) marquee.x = 0
        }
    }

    // ========== Full popup ==========
    fullRepresentation: Item {
        Layout.minimumWidth: 320
        Layout.minimumHeight: 240
        Layout.preferredWidth: 360
        Layout.preferredHeight: Math.max(240, 80 + coinModel.count * 36)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.mediumSpacing

            PlasmaExtras.Heading {
                level: 3
                text: cfgDisplayMode === "single" ? i18n("Price") : i18n("Watchlist")
            }

            Kirigami.Separator { Layout.fillWidth: true }

            ListView {
                id: popupList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Kirigami.Units.smallSpacing
                model: coinModel
                delegate: RowLayout {
                    width: popupList.width
                    spacing: Kirigami.Units.mediumSpacing

                    Loader {
                        sourceComponent: coinBadgeComponent
                        onLoaded: {
                            if (!item) return;
                            item.diameter = Kirigami.Units.iconSizes.medium;
                            item.ticker = model.coin;
                            item.badgeColor = model.coinColor;
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        PlasmaComponents.Label {
                            text: model.coinName + (model.isWsConnected ? "  •  " + i18n("Live") : "")
                            font.bold: true
                        }
                        PlasmaComponents.Label {
                            text: i18n("Source: %1", model.source)
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.6
                        }
                    }

                    PlasmaComponents.Label {
                        text: model.displayPrice
                        font.bold: true
                    }

                    PlasmaComponents.Label {
                        visible: cfgShowPriceChange && model.displayChange !== ""
                        text: model.displayChange
                        color: model.isUp ? root.upColor : root.downColor
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: openCoinWebsite(model.coin)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Button {
                    Layout.fillWidth: true
                    text: i18n("Refresh all")
                    icon.name: "view-refresh"
                    onClicked: refreshAll()
                }
            }

            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignHCenter
                text: anyWsConnected ? i18n("Live updates")
                    : (root.lastSuccessfulUpdate && !isNaN(root.lastSuccessfulUpdate.getTime())
                        ? i18n("Updated %1", Qt.formatTime(root.lastSuccessfulUpdate, Qt.locale().timeFormat(Locale.ShortFormat)))
                        : i18n("Updates every %1 min", root.cfgRefreshRate))
                font.pointSize: Kirigami.Theme.smallFont.pointSize - 1
                opacity: 0.55
            }
        }
    }

    // ========== Timers ==========
    Timer {
        id: pollTimer
        interval: root.pollIntervalMs
        repeat: true
        triggeredOnStart: true
        onTriggered: fetchAllPrices()
    }

    Timer {
        id: watchdog
        interval: 30000
        repeat: true
        running: true
        onTriggered: {
            var nowMs = Date.now();
            var drift = root.lastTickEpoch ? (nowMs - root.lastTickEpoch) : 0;
            root.lastTickEpoch = nowMs;
            if (drift > 2 * watchdog.interval) root.handleWakeup();
        }
    }

    // ========== Event-driven recovery via DBus ==========
    P5Support.DataSource {
        id: dbusEvents
        engine: "executable"
        readonly property string cmd: `dbus-monitor --system "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'" "type='signal',interface='org.freedesktop.NetworkManager',member='StateChanged'" 2>/dev/null | grep -m 1 -E 'PrepareForSleep|StateChanged'`
        property int failureCount: 0

        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            var stdout = data && data.stdout ? data.stdout : "";
            if (stdout.length > 0) {
                failureCount = 0;
                root.handleWakeup();
                Qt.callLater(() => connectSource(sourceName));
            } else {
                failureCount++;
                if (failureCount < 3) Qt.callLater(() => connectSource(sourceName));
            }
        }

        Component.onCompleted: connectSource(cmd)
        Component.onDestruction: disconnectSource(cmd)
    }

    // ========== Context menu ==========
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Refresh prices")
            icon.name: "view-refresh"
            onTriggered: refreshAll()
        }
    ]

    // ========== WebSocket Repeater (one socket per source group) ==========
    property var wsGroups: []  // [{source, multiSocket}]

    Item {
        id: wsHost
        visible: false
        Repeater {
            id: wsRepeater
            model: root.wsGroups
            delegate: WebSocketProvider {
                multiSocket: modelData.multiSocket
                Component.onCompleted: connect()
                onPriceUpdate: (coin, price, change24h) => root.handlePriceUpdate(coin, price, change24h)
                onConnectionStatus: (connected) => root.handleConnectionStatus(modelData.source, modelData.multiSocket.coins, connected)
            }
        }
    }

    // ========== Init ==========
    Component.onCompleted: {
        lastTickEpoch = Date.now();
        PriceProvider.ensureFxRates(function() { reformatAllPrices(); });
        rebuildModel();
    }

    onCfgCoinChanged: rebuildModel()
    onCfgDisplayModeChanged: rebuildModel()
    onCfgCoinsListChanged: rebuildModel()
    onCfgSourceChanged: rebuildModel()
    onCfgCurrencyChanged: {
        PriceProvider.ensureFxRates(function() { reformatAllPrices(); });
    }
    onCfgUseWebSocketChanged: rebuildModel()
    onCfgShowDecimalsChanged: reformatAllPrices()
    onCfgRefreshRateChanged: {
        pollTimer.interval = pollIntervalMs;
        if (pollTimer.running) pollTimer.restart();
    }

    Connections {
        target: plasmoid.configuration
        function onValueChanged(key, _value) {
            if (key === "coin" || key === "coins" || key === "displayMode" ||
                key === "source" || key === "useWebSocket") {
                Qt.callLater(rebuildModel);
            } else if (key === "currency") {
                Qt.callLater(function() {
                    PriceProvider.ensureFxRates(function() { reformatAllPrices(); });
                });
            } else if (key === "showDecimals") {
                Qt.callLater(reformatAllPrices);
            } else if (key === "refreshRate") {
                Qt.callLater(function() {
                    pollTimer.interval = pollIntervalMs;
                    if (pollTimer.running) pollTimer.restart();
                });
            }
        }
    }

    // ========== Core logic ==========
    function rebuildModel() {
        var nextCoins = effectiveCoins;
        var nextKey = cfgDisplayMode + "|" + cfgSource + "|" +
                      (cfgUseWebSocket ? "1" : "0") + "|" + nextCoins.join(",");
        if (nextKey === modelKey && coinModel.count === nextCoins.length) return;
        modelKey = nextKey;

        providerGeneration++;

        // Tear down WS first.
        wsGroups = [];

        // Tear down REST providers.
        for (var k in providersByCoin) {
            try { providersByCoin[k].disconnect(); } catch (e) {}
        }
        providersByCoin = {};

        coinModel.clear();
        anyWsConnected = false;

        for (var i = 0; i < nextCoins.length; i++) {
            var c = nextCoins[i];
            var info = PriceProvider.getCoinInfo(c);
            if (!info) continue;
            var sources = PriceProvider.getSourcesForCoin(c);
            var src = (sources.indexOf(cfgSource) >= 0) ? cfgSource : (sources[0] || cfgSource);
            var p = PriceProvider.createProvider(src, c);
            if (!p) continue;
            providersByCoin[c] = p;
            coinModel.append({
                coin: c,
                coinName: info.name,
                coinColor: info.color,
                source: src,
                homepage: p.homepage || "",
                supportsWs: !!p.supportsWebSocket,
                isWsConnected: false,
                priceUsd: 0,
                change24h: 0,
                isUp: false,
                displayPrice: "...",
                displayChange: ""
            });
        }

        // Group WS-capable coins by source for multiplexed sockets.
        if (cfgUseWebSocket) {
            var bySource = {};
            for (var j = 0; j < coinModel.count; j++) {
                var row = coinModel.get(j);
                if (!row.supportsWs) continue;
                if (!bySource[row.source]) bySource[row.source] = [];
                bySource[row.source].push(row.coin);
            }
            var groups = [];
            for (var s in bySource) {
                var ms = PriceProvider.createMultiSocket(s, bySource[s]);
                if (ms) groups.push({ source: s, multiSocket: ms });
            }
            wsGroups = groups;
        }

        pollTimer.interval = pollIntervalMs;
        pollTimer.restart();
    }

    function fetchAllPrices() {
        var generation = providerGeneration;
        for (var i = 0; i < coinModel.count; i++) {
            var coin = coinModel.get(i).coin;
            (function(c, idx) {
                var p = providersByCoin[c]; if (!p) return;
                p.fetchPrice(function(price, change24h) {
                    if (generation !== providerGeneration) return;
                    if (price === null) return;
                    applyUpdate(c, price, change24h);
                });
            })(coin, i);
        }
    }

    function findRowIndex(coin) {
        for (var i = 0; i < coinModel.count; i++) {
            if (coinModel.get(i).coin === coin) return i;
        }
        return -1;
    }

    function applyUpdate(coin, price, change24h) {
        var idx = findRowIndex(coin); if (idx < 0) return;
        var n = parseFloat(price);
        if (!isFinite(n)) return;
        var c = parseFloat(change24h);
        var hasChange = isFinite(c);
        var isUp = hasChange ? c >= 0 : false;
        coinModel.setProperty(idx, "priceUsd", n);
        var converted = PriceProvider.convertFromUsd(n, cfgCurrency);
        coinModel.setProperty(idx, "displayPrice", formatCurrency(cfgShowDecimals ? converted : Math.floor(converted)));
        if (hasChange) {
            coinModel.setProperty(idx, "change24h", c);
            coinModel.setProperty(idx, "isUp", isUp);
            coinModel.setProperty(idx, "displayChange", (isUp ? "+" : "") + c.toFixed(2) + "%");
        } else {
            coinModel.setProperty(idx, "displayChange", "");
        }
        lastSuccessfulUpdate = new Date();
    }

    function reformatAllPrices() {
        for (var i = 0; i < coinModel.count; i++) {
            var row = coinModel.get(i);
            if (row.priceUsd > 0) {
                var v = PriceProvider.convertFromUsd(row.priceUsd, cfgCurrency);
                coinModel.setProperty(i, "displayPrice", formatCurrency(cfgShowDecimals ? v : Math.floor(v)));
            }
        }
    }

    function handlePriceUpdate(coin, price, change24h) {
        applyUpdate(coin, price, change24h);
    }

    function handleConnectionStatus(source, coins, connected) {
        for (var i = 0; i < coins.length; i++) {
            var idx = findRowIndex(coins[i]);
            if (idx >= 0) coinModel.setProperty(idx, "isWsConnected", connected);
        }
        // Update aggregate flag.
        var any = false;
        for (var j = 0; j < coinModel.count; j++) {
            if (coinModel.get(j).isWsConnected) { any = true; break; }
        }
        anyWsConnected = any;
    }

    function handleWakeup() {
        for (var i = 0; i < wsRepeater.count; i++) {
            var w = wsRepeater.itemAt(i);
            if (w) w.forceReconnect();
        }
        PriceProvider.invalidateFxRates();
        PriceProvider.ensureFxRates(function() { reformatAllPrices(); });
        fetchAllPrices();
    }

    function refreshAll() {
        for (var i = 0; i < wsRepeater.count; i++) {
            var w = wsRepeater.itemAt(i);
            if (w) w.forceReconnect();
        }
        fetchAllPrices();
    }

    function formatCurrency(value) {
        var symbol = PriceProvider.currencySymbols[cfgCurrency] || cfgCurrency;
        var decimals = cfgShowDecimals
            ? (value > 0 && value < 1 ? Math.min(6, Math.max(2, 2 - Math.floor(Math.log10(value)))) : 2)
            : 0;
        try {
            return Number(value).toLocaleString(Qt.locale(), 'f', decimals) + " " + symbol;
        } catch (e) {
            return value.toFixed(decimals) + " " + symbol;
        }
    }

    function openCoinWebsite(coin) {
        var p = providersByCoin[coin];
        if (p && p.homepage) Qt.openUrlExternally(p.homepage);
    }
}
