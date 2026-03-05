/*
 *   Copyright (C) 2024 Zcash Price Applet Contributors
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
import "../code/PriceProvider.js" as PriceProvider

PlasmoidItem {
    id: root

    // ========== Properties ==========
    property string currentPrice: "..."
    property string priceChange24h: ""
    property bool isPriceUp: false
    property bool isLoading: false
    property string errorMessage: ""
    property bool isWebSocketConnected: false
    property var currentProvider: null
    
    // Stability tracking
    property int consecutiveErrors: 0
    property int maxConsecutiveErrors: 5
    property int backoffMultiplier: 1
    property date lastSuccessfulUpdate

    // Configuration shortcuts
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

    // ========== Plasmoid Configuration ==========
    preferredRepresentation: compactRepresentation
    toolTipMainText: i18n("Zcash Price")
    toolTipSubText: formatTooltip()
    Plasmoid.backgroundHints: cfgShowBackground ? PlasmaCore.Types.StandardBackground : PlasmaCore.Types.NoBackground

    // ========== Compact Representation (Panel Widget) ==========
    compactRepresentation: Item {
        Layout.fillWidth: false
        Layout.fillHeight: true
        Layout.minimumWidth: contentRow.implicitWidth + Kirigami.Units.smallSpacing * 2

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            // Connection status indicator (only when WebSocket is enabled)
            Rectangle {
                visible: cfgUseWebSocket && root.currentProvider?.supportsWebSocket
                width: 6
                height: 6
                radius: 3
                color: root.isWebSocketConnected ? "#4CAF50" : "#F44336"
                Layout.alignment: Qt.AlignVCenter
            }

            // Zcash Icon
            Image {
                id: zcashIcon
                visible: cfgShowIcon
                source: "../images/zcash.png"
                Layout.preferredWidth: Math.min(parent.height * 0.8, Kirigami.Units.iconSizes.smallMedium)
                Layout.preferredHeight: Layout.preferredWidth
                fillMode: Image.PreserveAspectFit
                opacity: root.isLoading ? 0.4 : 1.0
                // Ensure smooth rendering
                mipmap: true
                smooth: true
            }

            // Price Label
            PlasmaComponents.Label {
                id: priceLabel
                visible: cfgShowText
                text: root.currentPrice
                font.bold: true
                font.pointSize: root.cfgShowIcon ? Kirigami.Theme.defaultFont.pointSize : Kirigami.Theme.defaultFont.pointSize + 1
                opacity: root.isLoading ? 0.4 : 1.0
                Layout.alignment: Qt.AlignVCenter
            }

            // 24h Change Indicator
            PlasmaComponents.Label {
                id: changeLabel
                visible: cfgShowPriceChange && root.priceChange24h !== ""
                text: root.priceChange24h
                color: root.isPriceUp ? "#4CAF50" : "#F44336"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // Loading indicator overlay
        BusyIndicator {
            anchors.centerIn: parent
            running: root.isLoading
            visible: running
            width: Math.min(parent.height * 0.6, 16)
            height: width
        }

        // Error indicator
        Rectangle {
            visible: root.errorMessage !== "" && !root.isLoading
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: 4
            height: 4
            radius: 2
            color: "#F44336"
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if (cfgOnClickAction === "website") {
                    openProviderWebsite();
                } else {
                    refreshPrice();
                }
            }
        }
    }

    // ========== Full Representation (Popup/Expanded View) ==========
    fullRepresentation: Item {
        Layout.minimumWidth: 280
        Layout.minimumHeight: 180
        Layout.preferredWidth: 320
        Layout.preferredHeight: 220

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.mediumSpacing

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.mediumSpacing

                Image {
                    source: "../images/zcash.png"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.large
                    Layout.preferredHeight: Layout.preferredWidth
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    smooth: true
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    PlasmaExtras.Heading {
                        level: 2
                        text: i18n("Zcash")
                    }

                    PlasmaComponents.Label {
                        text: i18n("Source: %1", root.cfgSource)
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.7
                    }
                }

                // Connection status
                ColumnLayout {
                    spacing: 2
                    visible: root.currentProvider?.supportsWebSocket

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: root.isWebSocketConnected ? "#4CAF50" : "#F44336"
                    }

                    PlasmaComponents.Label {
                        text: root.isWebSocketConnected ? i18n("Live") : i18n("Polling")
                        font.pointSize: Kirigami.Theme.smallFont.pointSize - 1
                        opacity: 0.6
                    }
                }
            }

            Kirigami.Separator {
                Layout.fillWidth: true
            }

            // Price Display
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
                        text: i18n("24h Change:")
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.7
                    }

                    PlasmaComponents.Label {
                        text: root.priceChange24h
                        font.bold: true
                        color: root.isPriceUp ? "#4CAF50" : "#F44336"
                        font.pointSize: Kirigami.Theme.smallFont.pointSize + 1
                    }
                }

                // Error display
                PlasmaComponents.Label {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    visible: root.errorMessage !== ""
                    text: root.errorMessage
                    color: "#F44336"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Item {
                Layout.fillHeight: true
            }

            // Action Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.mediumSpacing

                Button {
                    Layout.fillWidth: true
                    text: i18n("Refresh")
                    icon.name: "view-refresh"
                    enabled: !root.isLoading && !root.isWebSocketConnected
                    onClicked: refreshPrice()
                }

                Button {
                    Layout.fillWidth: true
                    text: i18n("Open Website")
                    icon.name: "internet-services"
                    onClicked: openProviderWebsite()
                }
            }

            // Last update time
            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignHCenter
                text: root.isWebSocketConnected 
                    ? i18n("Live WebSocket updates") 
                    : i18n("Updates every %1 minutes", root.cfgRefreshRate)
                font.pointSize: Kirigami.Theme.smallFont.pointSize - 1
                opacity: 0.5
            }
        }
    }

    // ========== Timer for Polling Mode ==========
    Timer {
        id: pollTimer
        interval: root.cfgRefreshRate * 60 * 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: fetchPrice()
    }
    
    // Health check timer - detects stale data
    Timer {
        id: healthCheckTimer
        interval: 60000 // 1 minute
        repeat: true
        onTriggered: {
            if (!root.isWebSocketConnected && !root.isLoading && root.consecutiveErrors === 0) {
                var now = new Date();
                var staleThreshold = 2 * root.cfgRefreshRate * 60 * 1000; // 2x refresh interval
                if (root.lastSuccessfulUpdate && (now - root.lastSuccessfulUpdate) > staleThreshold) {
                    console.log("ZcashPrice: Data may be stale, triggering refresh");
                    refreshPrice();
                }
            }
        }
    }

    // ========== Context Menu Actions (Plasma 6) ==========
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Refresh Price")
            icon.name: "view-refresh"
            onTriggered: action_refresh()
        },
        PlasmaCore.Action {
            text: i18n("Open Market Website")
            icon.name: "internet-services"
            onTriggered: action_website()
        }
    ]

    // ========== WebSocket Provider (Declarative) ==========
    Loader {
        id: webSocketLoader
        active: false
        sourceComponent: webSocketComponent
        
        onLoaded: {
            // Explicitly connect signals in Qt6 style
            item.priceUpdate.connect((price, change24h) => handlePriceUpdate(price, change24h));
            item.connectionStatus.connect((connected) => handleConnectionStatus(connected));
            item.error.connect((message) => handleError(message));
            item.connect();
        }
    }
    
    Component {
        id: webSocketComponent
        WebSocketProvider {
            providerName: currentProvider ? currentProvider.name : ""
            wsUrl: currentProvider ? currentProvider.wsUrl : ""
            // Signal connections handled in onLoaded
        }
    }

    // ========== Initialization ==========
    Component.onCompleted: {
        setupProvider();
        healthCheckTimer.start();
    }

    // ========== Configuration Change Handlers ==========
    Connections {
        target: plasmoid.configuration
        function onSourceChanged() { setupProvider(); }
        function onCurrencyChanged() { setupProvider(); }
        function onRefreshRateChanged() { restartPolling(); }
        function onUseWebSocketChanged() { setupProvider(); }
    }

    // ========== Functions ==========

    function setupProvider() {
        // Cleanup previous provider
        if (currentProvider) {
            currentProvider.disconnect();
            currentProvider.destroy();
        }
        
        // Disconnect WebSocket
        if (webSocketLoader.item) {
            webSocketLoader.item.disconnect();
        }
        webSocketLoader.active = false;

        errorMessage = "";
        isWebSocketConnected = false;

        // Create new provider
        currentProvider = PriceProvider.createProvider(cfgSource, {
            onPriceUpdate: handlePriceUpdate,
            onError: handleError,
            onConnectionStatus: handleConnectionStatus,
            currency: cfgCurrency,
            useWebSocket: cfgUseWebSocket,
            parent: root
        });

        if (!currentProvider) {
            handleError(i18n("Unknown price source: %1", cfgSource));
            return;
        }

        // Decide between WebSocket and polling
        if (cfgUseWebSocket && currentProvider.supportsWebSocket) {
            pollTimer.stop();
            // Activate WebSocket provider
            isLoading = true;  // Show loading state while connecting
            webSocketLoader.active = true;
            
            // Fallback: if WebSocket doesn't connect within 10 seconds, fetch via REST
            Qt.callLater(function() {
                if (isLoading && !isWebSocketConnected) {
                    console.log("ZcashPrice: WebSocket taking too long, fetching via REST");
                    fetchPrice();
                }
            }, 10000);
        } else {
            webSocketLoader.active = false;
            restartPolling();
        }
    }

    function restartPolling() {
        if (!cfgUseWebSocket || !currentProvider?.supportsWebSocket) {
            // Ensure timer is running and trigger immediately
            pollTimer.stop();
            pollTimer.start();
        }
    }

    function fetchPrice() {
        if (!currentProvider || isLoading) return;

        isLoading = true;
        errorMessage = "";

        currentProvider.fetchPrice(function(price, change24h) {
            isLoading = false;
            if (price !== null) {
                updateDisplay(price, change24h);
            }
        });
    }

    function handlePriceUpdate(price, change24h) {
        // Only update if we have valid data
        if (price === null || price === undefined) return;
        
        isLoading = false;
        consecutiveErrors = 0;
        backoffMultiplier = 1;
        pollTimer.interval = root.cfgRefreshRate * 60 * 1000;
        lastSuccessfulUpdate = new Date();
        updateDisplay(price, change24h);
    }

    function handleError(message) {
        isLoading = false;
        consecutiveErrors++;
        
        // If WebSocket failed, fall back to REST polling
        if (cfgUseWebSocket && isWebSocketConnected === false && webSocketLoader.active) {
            console.log("ZcashPrice: WebSocket error, falling back to REST polling");
            webSocketLoader.active = false;
            restartPolling();
            fetchPrice(); // Immediate fetch via REST
            errorMessage = i18n("WebSocket unavailable, using REST");
            return;
        }
        
        if (consecutiveErrors >= maxConsecutiveErrors) {
            // Exponential backoff
            backoffMultiplier = Math.min(backoffMultiplier * 2, 12); // Max 12x
            var newInterval = root.cfgRefreshRate * 60 * 1000 * backoffMultiplier;
            pollTimer.interval = newInterval;
            errorMessage = i18n("Connection issues - reduced update frequency (%1x)", backoffMultiplier);
            console.error("ZcashPrice: Too many errors, backing off to", newInterval, "ms");
        } else {
            errorMessage = message;
        }
        
        console.error("ZcashPrice: Error (", consecutiveErrors, "/", maxConsecutiveErrors, "):", message);
    }

    function handleConnectionStatus(connected) {
        isWebSocketConnected = connected;
        if (connected) {
            errorMessage = "";
        }
    }

    function updateDisplay(price, change24h) {
        errorMessage = "";

        // Format price
        let numPrice = parseFloat(price);
        if (isNaN(numPrice)) {
            currentPrice = "N/A";
            return;
        }

        if (cfgShowDecimals) {
            currentPrice = formatCurrency(numPrice);
        } else {
            currentPrice = formatCurrency(Math.floor(numPrice));
        }

        // Format 24h change
        if (change24h !== undefined && change24h !== null) {
            let numChange = parseFloat(change24h);
            if (!isNaN(numChange)) {
                isPriceUp = numChange >= 0;
                let sign = isPriceUp ? "+" : "";
                priceChange24h = sign + numChange.toFixed(2) + "%";
            } else {
                priceChange24h = "";
            }
        } else {
            priceChange24h = "";
        }
    }

    function formatCurrency(value) {
        // Use Number.toLocaleString for currency formatting
        let symbol = PriceProvider.currencySymbols[cfgCurrency] || cfgCurrency;
        try {
            return Number(value).toLocaleString(Qt.locale(), 'f', cfgShowDecimals ? 2 : 0) + " " + symbol;
        } catch (e) {
            return value.toFixed(cfgShowDecimals ? 2 : 0) + " " + symbol;
        }
    }

    function formatTooltip() {
        let text = "<b>" + currentPrice + "</b>";
        if (priceChange24h !== "") {
            let color = isPriceUp ? "#4CAF50" : "#F44336";
            text += " <span style='color:" + color + "'>" + priceChange24h + "</span>";
        }
        text += "<br/>";
        text += i18n("Source: %1", cfgSource);
        if (errorMessage !== "") {
            text += "<br/><span style='color:#F44336'>" + i18n("Error: %1", errorMessage) + "</span>";
        }
        return text;
    }

    function refreshPrice() {
        if (isWebSocketConnected && webSocketLoader.item) {
            // Force reconnect WebSocket
            webSocketLoader.item.disconnect();
            webSocketLoader.item.connect();
        } else {
            pollTimer.restart();
            fetchPrice();
        }
    }

    function openProviderWebsite() {
        if (currentProvider?.homepage) {
            Qt.openUrlExternally(currentProvider.homepage);
        }
    }

    function action_refresh() {
        refreshPrice();
    }

    function action_website() {
        openProviderWebsite();
    }
}
