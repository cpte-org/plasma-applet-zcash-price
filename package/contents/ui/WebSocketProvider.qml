/*
 *   Copyright (C) 2024 Crypto Price Applet Contributors
 *   SPDX-License-Identifier: GPL-3.0
 *
 *   Provider-agnostic WebSocket client. Silent: never logs.
 */

import QtQuick
import QtWebSockets

Item {
    id: root

    property var provider: null
    property bool connected: webSocket.status === WebSocket.Open
    property int retryCount: 0

    readonly property int baseDelayMs: 1000
    readonly property int maxDelayMs: 60000

    signal priceUpdate(real price, real change24h)
    signal connectionStatus(bool connected)

    WebSocket {
        id: webSocket
        url: root.provider ? root.provider.wsUrl : ""
        active: false

        onStatusChanged: (status) => {
            if (status === WebSocket.Open) {
                root.retryCount = 0;
                root.connectionStatus(true);
                var msg = root.provider ? root.provider.wsSubscribeMessage() : null;
                if (msg) webSocket.sendTextMessage(msg);
            } else if (status === WebSocket.Closed || status === WebSocket.Error) {
                if (root.connected) root.connectionStatus(false);
                else root.connectionStatus(false);
                root._scheduleReconnect();
            }
        }

        onTextMessageReceived: (message) => {
            if (!root.provider || !message) return;
            var data;
            try { data = JSON.parse(message); } catch (e) { return; }
            var parsed = root.provider.wsParseMessage(data);
            if (parsed && isFinite(parsed.price) && parsed.price > 0) {
                root.priceUpdate(parsed.price, isFinite(parsed.change24h) ? parsed.change24h : 0);
            }
        }
    }

    Timer {
        id: reconnectTimer
        repeat: false
        onTriggered: {
            if (!root.provider) return;
            webSocket.active = false;
            webSocket.active = true;
        }
    }

    function _scheduleReconnect() {
        retryCount++;
        var delay = Math.min(maxDelayMs, baseDelayMs * Math.pow(2, Math.min(retryCount - 1, 6)));
        delay += Math.floor(Math.random() * 1000);
        reconnectTimer.interval = delay;
        reconnectTimer.start();
    }

    function connect() {
        if (!provider || !provider.wsUrl) return;
        retryCount = 0;
        reconnectTimer.stop();
        webSocket.active = true;
    }

    function disconnect() {
        reconnectTimer.stop();
        webSocket.active = false;
    }

    function forceReconnect() {
        reconnectTimer.stop();
        retryCount = 0;
        webSocket.active = false;
        webSocket.active = true;
    }

    Component.onDestruction: disconnect()
}
