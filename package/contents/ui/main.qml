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
    property string currentPrice: "..."
    property string priceChange24h: ""
    property bool isPriceUp: false
    property bool isLoading: false
    property bool isWebSocketConnected: false
    property var currentProvider: null
    property date lastSuccessfulUpdate
    property real lastTickEpoch: 0

    // ---- Config
    readonly property string cfgCoin: plasmoid.configuration.coin
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

    readonly property var coinInfo: PriceProvider.getCoinInfo(cfgCoin)
    readonly property color coinColor: coinInfo ? coinInfo.color : Kirigami.Theme.highlightColor
    readonly property string coinName: coinInfo ? coinInfo.name : cfgCoin
    readonly property int pollIntervalMs: cfgRefreshRate * 60 * 1000
    readonly property color upColor: Kirigami.Theme.positiveTextColor
    readonly property color downColor: Kirigami.Theme.negativeTextColor

    // ---- No tooltip
    preferredRepresentation: compactRepresentation
    toolTipMainText: ""
    toolTipSubText: ""
    Plasmoid.backgroundHints: cfgShowBackground ? PlasmaCore.Types.StandardBackground : PlasmaCore.Types.NoBackground

    // ========== Coin badge ==========
    Component {
        id: coinBadgeComponent
        Rectangle {
            property real diameter: 16
            property string ticker: ""
            property color badgeColor: Kirigami.Theme.highlightColor
            implicitWidth: diameter
            implicitHeight: diameter
            radius: diameter / 2
            color: badgeColor
            border.color: Qt.rgba(0, 0, 0, 0.15)
            border.width: 1
            Label {
                anchors.centerIn: parent
                text: parent.ticker
                color: "white"
                font.bold: true
                font.pointSize: Math.max(6, parent.diameter * 0.32)
                font.letterSpacing: -0.3
                renderType: Text.NativeRendering
            }
        }
    }

    // ========== Compact ==========
    compactRepresentation: Item {
        Layout.fillWidth: false
        Layout.fillHeight: true
        Layout.minimumWidth: contentRow.implicitWidth + Kirigami.Units.smallSpacing * 2

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                visible: cfgUseWebSocket && root.currentProvider?.supportsWebSocket
                width: 6
                height: 6
                radius: 3
                color: root.isWebSocketConnected ? root.upColor : root.downColor
                Layout.alignment: Qt.AlignVCenter
            }

            Loader {
                id: compactBadge
                visible: cfgShowIcon
                Layout.alignment: Qt.AlignVCenter
                sourceComponent: coinBadgeComponent
                onLoaded: applyBadge()
                function applyBadge() {
                    if (!item) return;
                    item.diameter = Math.min(parent.height * 0.85, Kirigami.Units.iconSizes.smallMedium);
                    item.ticker = root.cfgCoin;
                    item.badgeColor = root.coinColor;
                }
                Connections {
                    target: root
                    function onCfgCoinChanged() { compactBadge.applyBadge(); }
                }
                opacity: root.isLoading ? 0.4 : 1.0
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            PlasmaComponents.Label {
                visible: cfgShowText
                text: root.currentPrice
                font.bold: true
                font.pointSize: cfgShowIcon ? Kirigami.Theme.defaultFont.pointSize : Kirigami.Theme.defaultFont.pointSize + 1
                opacity: root.isLoading ? 0.4 : 1.0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Layout.alignment: Qt.AlignVCenter
            }

            PlasmaComponents.Label {
                visible: cfgShowPriceChange && root.priceChange24h !== ""
                text: root.priceChange24h
                color: root.isPriceUp ? root.upColor : root.downColor
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                Layout.alignment: Qt.AlignVCenter
            }
        }

        BusyIndicator {
            anchors.centerIn: parent
            running: root.isLoading
            visible: running
            width: Math.min(parent.height * 0.6, 16)
            height: width
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: false
            onClicked: cfgOnClickAction === "website" ? openProviderWebsite() : refreshPrice()
        }
    }

    // ========== Full popup ==========
    fullRepresentation: Item {
        Layout.minimumWidth: 300
        Layout.minimumHeight: 200
        Layout.preferredWidth: 340
        Layout.preferredHeight: 240

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.mediumSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.mediumSpacing

                Loader {
                    id: popupBadge
                    sourceComponent: coinBadgeComponent
                    onLoaded: applyBadge()
                    function applyBadge() {
                        if (!item) return;
                        item.diameter = Kirigami.Units.iconSizes.large;
                        item.ticker = root.cfgCoin;
                        item.badgeColor = root.coinColor;
                    }
                    Connections {
                        target: root
                        function onCfgCoinChanged() { popupBadge.applyBadge(); }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PlasmaExtras.Heading { level: 2; text: root.coinName }
                    PlasmaComponents.Label {
                        text: i18n("Source: %1", root.cfgSource)
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.7
                    }
                }

                ColumnLayout {
                    spacing: 2
                    visible: root.currentProvider?.supportsWebSocket
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 8; height: 8; radius: 4
                        color: root.isWebSocketConnected ? root.upColor : root.downColor
                    }
                    PlasmaComponents.Label {
                        text: root.isWebSocketConnected ? i18n("Live") : i18n("Polling")
                        font.pointSize: Kirigami.Theme.smallFont.pointSize - 1
                        opacity: 0.6
                    }
                }
            }

            Kirigami.Separator { Layout.fillWidth: true }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.currentPrice
                    font.bold: true
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize + 8
                    opacity: root.isLoading ? 0.5 : 1.0
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Kirigami.Units.mediumSpacing
                    visible: root.priceChange24h !== ""
                    PlasmaComponents.Label {
                        text: i18n("24h:")
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.7
                    }
                    PlasmaComponents.Label {
                        text: root.priceChange24h
                        font.bold: true
                        color: root.isPriceUp ? root.upColor : root.downColor
                        font.pointSize: Kirigami.Theme.smallFont.pointSize + 1
                    }
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.mediumSpacing
                Button {
                    Layout.fillWidth: true
                    text: i18n("Refresh")
                    icon.name: "view-refresh"
                    enabled: !root.isLoading
                    onClicked: refreshPrice()
                }
                Button {
                    Layout.fillWidth: true
                    text: i18n("Open website")
                    icon.name: "internet-services"
                    onClicked: openProviderWebsite()
                }
            }

            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignHCenter
                text: root.isWebSocketConnected
                    ? i18n("Live updates")
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
        onTriggered: fetchPrice()
    }

    // Wall-clock drift watchdog: detects sleep/resume even without DBus.
    Timer {
        id: watchdog
        interval: 30000
        repeat: true
        running: true
        onTriggered: {
            var nowMs = Date.now();
            var drift = root.lastTickEpoch ? (nowMs - root.lastTickEpoch) : 0;
            root.lastTickEpoch = nowMs;
            if (drift > 2 * watchdog.interval) {
                root.handleWakeup();
            }
        }
    }

    // ========== Event-driven recovery via DBus ==========
    // Listens for login1 PrepareForSleep AND NetworkManager StateChanged.
    // dbus-monitor + grep -m1 emits one matched line per event then exits;
    // we restart on each event so memory stays bounded.
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
                // No stdout = grep didn't match (likely dbus-monitor unavailable
                // or terminated early). Cap retries to avoid a spin loop.
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
            text: i18n("Refresh price")
            icon.name: "view-refresh"
            onTriggered: refreshPrice()
        },
        PlasmaCore.Action {
            text: i18n("Open market website")
            icon.name: "internet-services"
            onTriggered: openProviderWebsite()
        }
    ]

    // ========== WebSocket loader ==========
    Loader {
        id: webSocketLoader
        active: false
        sourceComponent: webSocketComponent
        onLoaded: {
            item.priceUpdate.connect(handlePriceUpdate);
            item.connectionStatus.connect(handleConnectionStatus);
            item.provider = currentProvider;
            item.connect();
        }
    }

    Component {
        id: webSocketComponent
        WebSocketProvider {}
    }

    // ========== Init ==========
    Component.onCompleted: {
        lastTickEpoch = Date.now();
        setupProvider();
    }

    Connections {
        target: plasmoid.configuration
        function onCoinChanged()         { setupProvider(); }
        function onSourceChanged()       { setupProvider(); }
        function onCurrencyChanged()     { setupProvider(); }
        function onUseWebSocketChanged() { setupProvider(); }
        function onRefreshRateChanged()  { pollTimer.interval = pollIntervalMs; }
    }

    // ========== Core logic ==========
    function setupProvider() {
        if (currentProvider) {
            try { currentProvider.disconnect(); } catch (e) {}
            currentProvider = null;
        }
        if (webSocketLoader.item) webSocketLoader.item.disconnect();
        webSocketLoader.active = false;
        isWebSocketConnected = false;

        currentProvider = PriceProvider.createProvider(cfgSource, cfgCoin);
        if (!currentProvider) return;

        // Always start REST polling — it's stopped automatically when WS connects.
        pollTimer.interval = pollIntervalMs;
        pollTimer.restart();

        if (cfgUseWebSocket && currentProvider.supportsWebSocket) {
            webSocketLoader.active = true;
        }
    }

    function fetchPrice() {
        if (!currentProvider || isLoading) return;
        isLoading = true;
        currentProvider.fetchPrice(function(price, change24h) {
            isLoading = false;
            if (price !== null) updateDisplay(price, change24h);
        });
    }

    function handlePriceUpdate(price, change24h) {
        if (price === null || price === undefined) return;
        isLoading = false;
        lastSuccessfulUpdate = new Date();
        updateDisplay(price, change24h);
    }

    function handleConnectionStatus(connected) {
        isWebSocketConnected = connected;
        if (connected) {
            // Live updates take over — stop hitting REST.
            pollTimer.stop();
        } else if (cfgUseWebSocket && currentProvider?.supportsWebSocket) {
            // WS dropped — keep REST polling so price stays fresh while WS retries.
            if (!pollTimer.running) {
                pollTimer.interval = pollIntervalMs;
                pollTimer.restart();
            }
        }
    }

    // Triggered by DBus events (PrepareForSleep, NM StateChanged) or wall-clock drift.
    function handleWakeup() {
        if (cfgUseWebSocket && currentProvider?.supportsWebSocket) {
            if (webSocketLoader.item) webSocketLoader.item.forceReconnect();
            else webSocketLoader.active = true;
        }
        fetchPrice();
    }

    function updateDisplay(price, change24h) {
        var n = parseFloat(price);
        if (isNaN(n)) { currentPrice = "—"; return; }
        currentPrice = formatCurrency(cfgShowDecimals ? n : Math.floor(n));

        if (change24h !== undefined && change24h !== null) {
            var c = parseFloat(change24h);
            if (!isNaN(c)) {
                isPriceUp = c >= 0;
                priceChange24h = (isPriceUp ? "+" : "") + c.toFixed(2) + "%";
                return;
            }
        }
        priceChange24h = "";
    }

    function formatCurrency(value) {
        var symbol = PriceProvider.currencySymbols[cfgCurrency] || cfgCurrency;
        // Auto-precision for sub-dollar coins (e.g. ZIL at $0.0034).
        var decimals = cfgShowDecimals
            ? (value > 0 && value < 1 ? Math.min(6, Math.max(2, 2 - Math.floor(Math.log10(value)))) : 2)
            : 0;
        try {
            return Number(value).toLocaleString(Qt.locale(), 'f', decimals) + " " + symbol;
        } catch (e) {
            return value.toFixed(decimals) + " " + symbol;
        }
    }

    function refreshPrice() {
        if (cfgUseWebSocket && currentProvider?.supportsWebSocket && webSocketLoader.item) {
            webSocketLoader.item.forceReconnect();
        }
        fetchPrice();
    }

    function openProviderWebsite() {
        if (currentProvider?.homepage) Qt.openUrlExternally(currentProvider.homepage);
    }
}
