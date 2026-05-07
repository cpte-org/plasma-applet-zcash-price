/*
 *   Copyright (C) 2024 Crypto Price Applet Contributors
 *   SPDX-License-Identifier: GPL-3.0
 *
 *   Multi-symbol WebSocket client. Silent: never logs.
 *
 *   The `multiSocket` property is an object produced by
 *   PriceProvider.createMultiSocket(source, coins): { wsUrl, coins,
 *   subscribeMessages, parseMessage(data) -> [{coin, price, change24h}, ...] }.
 */

import QtQuick
import QtWebSockets

Item {
    id: root

    property var multiSocket: null
    property bool connected: webSocket.status === WebSocket.Open
    property int retryCount: 0

    readonly property int baseDelayMs: 1000
    readonly property int maxDelayMs: 60000

    signal priceUpdate(string coin, real price, real change24h)
    signal connectionStatus(bool connected)

    WebSocket {
        id: webSocket
        url: root.multiSocket ? root.multiSocket.wsUrl : ""
        active: false

        onStatusChanged: (status) => {
            if (status === WebSocket.Open) {
                root.retryCount = 0;
                root.connectionStatus(true);
                if (root.multiSocket && root.multiSocket.subscribeMessages) {
                    var msgs = root.multiSocket.subscribeMessages;
                    for (var i = 0; i < msgs.length; i++) webSocket.sendTextMessage(msgs[i]);
                }
            } else if (status === WebSocket.Closed || status === WebSocket.Error) {
                root.connectionStatus(false);
                root._scheduleReconnect();
            }
        }

        onTextMessageReceived: (message) => {
            if (!root.multiSocket || !message) return;
            var data;
            try { data = JSON.parse(message); } catch (e) { return; }
            var updates;
            try { updates = root.multiSocket.parseMessage(data); } catch (e) { return; }
            if (!Array.isArray(updates)) return;
            for (var i = 0; i < updates.length; i++) {
                var u = updates[i];
                if (u && u.coin && isFinite(u.price) && u.price > 0) {
                    root.priceUpdate(u.coin, u.price, isFinite(u.change24h) ? u.change24h : 0);
                }
            }
        }
    }

    Timer {
        id: reconnectTimer
        repeat: false
        onTriggered: {
            if (!root.multiSocket) return;
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
        if (!multiSocket || !multiSocket.wsUrl) return;
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
