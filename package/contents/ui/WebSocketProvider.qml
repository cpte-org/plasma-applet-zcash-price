/*
 *   Copyright (C) 2024 Zcash Price Applet Contributors
 *   SPDX-License-Identifier: GPL-3.0
 *
 *   WebSocket Provider Component for Qt6
 *   Must be instantiated in QML, not created with 'new' in JS
 */

import QtQuick
import QtWebSockets

Item {
    id: root

    // Configuration properties
    property string providerName: ""
    property string wsUrl: ""
    property bool active: false
    property int reconnectDelay: 5000
    property int maxRetries: 3

    // Status properties
    property bool connected: webSocket.status === WebSocket.Open
    property int status: webSocket.status
    property string errorString: webSocket.errorString
    property int retryCount: 0

    // Signals
    signal priceUpdate(real price, real change24h)
    signal connectionStatus(bool connected)
    signal error(string message)

    // Internal WebSocket - created declaratively
    WebSocket {
        id: webSocket
        url: root.wsUrl
        active: root.active && root.wsUrl !== ""

        onStatusChanged: (status) => {
            console.log("ZcashPrice [" + root.providerName + "]: WebSocket status:", status);
            
            if (status === WebSocket.Open) {
                root.retryCount = 0;
                root.connectionStatus(true);
            } else if (status === WebSocket.Closed || status === WebSocket.Error) {
                root.connectionStatus(false);
                
                if (root.active && root.retryCount < root.maxRetries) {
                    root.retryCount++;
                    console.log("ZcashPrice [" + root.providerName + "]: Reconnecting in", 
                                root.reconnectDelay * root.retryCount, "ms (attempt", root.retryCount, ")");
                    reconnectTimer.start();
                } else if (root.retryCount >= root.maxRetries) {
                    root.error(i18n("WebSocket failed after %1 attempts", root.maxRetries));
                }
            }
        }

        onErrorStringChanged: (errorString) => {
            if (errorString !== "") {
                console.error("ZcashPrice [" + root.providerName + "]: WebSocket error:", errorString);
                root.error(errorString);
            }
        }

        onTextMessageReceived: (message) => {
            root.handleMessage(message);
        }
    }

    // Reconnection timer
    Timer {
        id: reconnectTimer
        interval: root.reconnectDelay * root.retryCount
        repeat: false
        onTriggered: {
            if (root.active) {
                webSocket.active = false;
                webSocket.active = true;
            }
        }
    }

    // Subscribe timer for Bitfinex
    Timer {
        id: subscribeTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (root.providerName === "Bitfinex" && webSocket.status === WebSocket.Open) {
                var subscribeMsg = JSON.stringify({
                    event: "subscribe",
                    channel: "ticker",
                    symbol: "tZECUSD"
                });
                console.log("ZcashPrice [Bitfinex]: Sending subscription");
                webSocket.sendTextMessage(subscribeMsg);
            }
        }
    }

    // Handle incoming messages
    function handleMessage(message) {
        if (!message || message === "") return;

        var data;
        try {
            data = JSON.parse(message);
        } catch (e) {
            console.error("ZcashPrice [" + root.providerName + "]: JSON parse error:", e.message);
            return;
        }

        if (root.providerName === "Binance") {
            handleBinanceMessage(data);
        } else if (root.providerName === "Bitfinex") {
            handleBitfinexMessage(data);
        }
    }

    function handleBinanceMessage(data) {
        // Binance: { "c": "234.67", "P": "6.051", ... }
        if (data && typeof data.c === 'string' && typeof data.P === 'string') {
            var price = parseFloat(data.c);
            var change24h = parseFloat(data.P);
            
            if (!isNaN(price) && price > 0 && price < 100000) {
                root.priceUpdate(price, isNaN(change24h) ? 0 : change24h);
            }
        }
    }

    function handleBitfinexMessage(data) {
        // Handle subscription confirmation
        if (data.event === "subscribed") {
            console.log("ZcashPrice [Bitfinex]: Subscribed to channel", data.chanId);
            return;
        }
        
        // Handle info/heartbeat
        if (data.event === "info" || data.event === "pong") {
            return;
        }
        
        // Handle heartbeat [CHAN_ID, "hb"]
        if (Array.isArray(data) && data.length === 2 && data[1] === "hb") {
            return;
        }
        
        // Handle ticker data [CHAN_ID, [BID, BID_SIZE, ASK, ASK_SIZE, DAILY_CHANGE, DAILY_CHANGE_RELATIVE, LAST_PRICE, ...]]
        if (Array.isArray(data) && data.length >= 2 && Array.isArray(data[1])) {
            var ticker = data[1];
            if (ticker.length >= 7) {
                var price = parseFloat(ticker[6]); // LAST_PRICE
                var change24h = parseFloat(ticker[5]) * 100; // DAILY_CHANGE_RELATIVE as percentage
                
                if (!isNaN(price) && price > 0 && price < 100000) {
                    root.priceUpdate(price, isNaN(change24h) ? 0 : change24h);
                }
            }
        }
    }

    // Public methods
    function connect() {
        console.log("ZcashPrice [" + root.providerName + "]: Connecting to", root.wsUrl);
        retryCount = 0;
        webSocket.active = true;
        
        // For Bitfinex, need to subscribe after connection
        if (root.providerName === "Bitfinex") {
            subscribeTimer.start();
        }
    }

    function disconnect() {
        console.log("ZcashPrice [" + root.providerName + "]: Disconnecting");
        reconnectTimer.stop();
        subscribeTimer.stop();
        
        // For Bitfinex, unsubscribe if we have a channel
        if (root.providerName === "Bitfinex" && webSocket.status === WebSocket.Open) {
            var unsubscribeMsg = JSON.stringify({
                event: "unsubscribe",
                channel: "ticker",
                symbol: "tZECUSD"
            });
            webSocket.sendTextMessage(unsubscribeMsg);
        }
        
        webSocket.active = false;
    }

    function send(message) {
        if (webSocket.status === WebSocket.Open) {
            webSocket.sendTextMessage(message);
        }
    }

    // Cleanup on destruction
    Component.onDestruction: {
        disconnect();
    }
}
