#!/usr/bin/env node
const fs = require("fs");
const { loadPriceProvider } = require("./helpers/load_price_provider");

let responses = {};

function MockXMLHttpRequest() {
    this.readyState = 0;
    this.status = 0;
    this.responseText = "";
    this.timeout = 0;
    this.onreadystatechange = null;
    this.onerror = null;
    this.ontimeout = null;
    this._url = "";
}

MockXMLHttpRequest.DONE = 4;
MockXMLHttpRequest.prototype.open = function(_method, url) {
    this._url = url;
};
MockXMLHttpRequest.prototype.setRequestHeader = function() {};
MockXMLHttpRequest.prototype.send = function() {
    const response = responses[this._url] || { error: true };
    setTimeout(() => {
        if (response.error) {
            this.status = response.status || 0;
            this.readyState = MockXMLHttpRequest.DONE;
            if (this.onerror) this.onerror();
            return;
        }
        this.status = response.status;
        this.responseText = response.body;
        this.readyState = MockXMLHttpRequest.DONE;
        if (this.onreadystatechange) this.onreadystatechange();
    }, 0);
};

const context = loadPriceProvider(MockXMLHttpRequest);

function assert(condition, message) {
    if (!condition) throw new Error(message);
}

function fetchAssets(source, options) {
    return new Promise((resolve) => {
        context.fetchSourceAssets(source, options || {}, (items, meta) => {
            resolve({ items, meta });
        });
    });
}

async function run() {
    const binanceMarkets = context._parseMarkets("Binance", {
        symbols: [
            { symbol: "ZECUSDT", status: "TRADING", quoteAsset: "USDT", baseAsset: "ZEC" },
            { symbol: "ZECBUSD", status: "TRADING", quoteAsset: "BUSD", baseAsset: "ZEC" },
            { symbol: "OLDUSDT", status: "BREAK", quoteAsset: "USDT", baseAsset: "OLD" }
        ]
    });
    assert(binanceMarkets.length === 1, "Binance parser should keep only active USDT markets");
    assert(binanceMarkets[0].key.indexOf("dyn:Binance:ZECUSDT:ZEC") === 0, "Binance dynamic key should preserve source id");

    const bitfinexMarkets = context._parseMarkets("Bitfinex", [["ZECUSD", "PEPE:USD", "BTCEUR"]]);
    assert(bitfinexMarkets.length === 2, "Bitfinex parser should keep USD pairs");
    assert(bitfinexMarkets.some((m) => m.sourceId === "tPEPE:USD"), "Bitfinex parser should preserve colon pair source id");

    const coinbaseMarkets = context._parseMarkets("Coinbase", [
        { id: "ZEC-USD", base_currency: "ZEC", quote_currency: "USD", status: "online", display_name: "ZEC-USD" },
        { id: "ZEC-EUR", base_currency: "ZEC", quote_currency: "EUR", status: "online", display_name: "ZEC-EUR" },
        { id: "OLD-USD", base_currency: "OLD", quote_currency: "USD", status: "delisted", display_name: "OLD-USD" }
    ]);
    assert(coinbaseMarkets.length === 1, "Coinbase parser should keep only online USD markets");

    const krakenMarkets = context._parseMarkets("Kraken", {
        result: {
            ZECUSD: { wsname: "ZEC/USD", quote: "ZUSD", status: "online", base: "XZEC" },
            ZECEUR: { wsname: "ZEC/EUR", quote: "ZEUR", status: "online", base: "XZEC" },
            OLDUSD: { wsname: "OLD/USD", quote: "ZUSD", status: "cancel_only", base: "OLD" }
        }
    });
    assert(krakenMarkets.length === 1, "Kraken parser should keep only online USD markets");

    const coingeckoMarkets = context._parseMarkets("Coingecko", [
        { id: "zcash", symbol: "zec", name: "Zcash" },
        { id: "bad" }
    ]);
    assert(coingeckoMarkets.length === 1, "Coingecko parser should keep entries with id and symbol");
    assert(context.getMarketUrl("Binance").indexOf("ticker/24hr") > 0, "getMarketUrl should expose smaller Binance ticker market URL");
    assert(context.parseSourceAssets("Binance", JSON.stringify({
        symbols: [{ symbol: "ZECUSDT", status: "TRADING", quoteAsset: "USDT", baseAsset: "ZEC" }]
    })).length === 1, "parseSourceAssets should parse response text");
    assert(context.parseSourceAssets("Binance", "<html></html>").length === 0, "parseSourceAssets should reject HTML responses");

    context._marketCache = {};
    responses = {
        "https://api.binance.com/api/v3/ticker/24hr": {
            status: 200,
            body: JSON.stringify([
                { symbol: "ZECUSDT", lastPrice: "25" },
                { symbol: "BTCUSDT", lastPrice: "100000" }
            ])
        }
    };
    const fresh = await fetchAssets("Binance", { forceRefresh: true });
    assert(fresh.items.length === 2, "fetchSourceAssets should parse successful Binance response");
    assert(fresh.meta.failed === false, "successful fetch should not be marked failed");
    assert(fresh.meta.fromCache === false, "successful fetch should not be from cache");

    const exported = context.exportMarketCache();
    assert(exported.indexOf("ZECUSDT") >= 0, "exportMarketCache should include compact source ids");

    context._marketCache = {};
    assert(context.storeSourceAssets("Binance", fresh.items, 12345), "storeSourceAssets should accept parsed market lists");
    assert(context.getMarketCacheMeta("Binance").count === 2, "storeSourceAssets should update market cache");

    context._marketCache = {};
    context.restoreMarketCache(exported);
    const cached = await fetchAssets("Binance", { allowStale: true });
    assert(cached.items.length === 2, "restoreMarketCache should hydrate cached markets");
    assert(cached.meta.fromCache === true, "cached fetch should identify cache source");

    responses = {
        "https://api.binance.com/api/v3/ticker/24hr": { error: true }
    };
    const fallback = await fetchAssets("Binance", { forceRefresh: true, allowStale: true });
    assert(fallback.items.length === 2, "failed refresh should fall back to cached markets");
    assert(fallback.meta.failed === true, "failed refresh should mark failure metadata");
    assert(fallback.meta.fromCache === true, "failed refresh with cache should report cache fallback");

    context._marketCache = {};
    const failed = await fetchAssets("Binance", { forceRefresh: true });
    assert(failed.items.length === 0, "failed refresh without cache should return no markets");
    assert(failed.meta.failed === true, "failed refresh without cache should mark failure");

    assert(context.getCoins().indexOf("ZEC") >= 0, "coin registry should include ZEC");
    assert(context.getSources().length === 5, "source registry should expose all configured sources");
    assert(context.getCurrencies().indexOf("USD") >= 0, "currency registry should include USD");

    const normalizedAlarms = context.normalizePriceAlarms([
        { id: "a", coin: "ZEC", direction: "above", target: "30", currency: "USD", enabled: true },
        { id: "b", coin: "ZEC", direction: "below", target: "20", currency: "NOPE", triggeredAt: 123 },
        { id: "bad-coin", coin: "NOPE", direction: "above", target: "1", currency: "USD" },
        { id: "bad-dir", coin: "ZEC", direction: "sideways", target: "1", currency: "USD" },
        { id: "bad-target", coin: "ZEC", direction: "above", target: "-1", currency: "USD" }
    ], "EUR");
    assert(normalizedAlarms.length === 2, "normalizePriceAlarms should drop malformed rules");
    assert(normalizedAlarms[1].currency === "USD", "normalizePriceAlarms should default unsupported currency to USD");
    assert(normalizedAlarms[1].enabled === false && normalizedAlarms[1].triggeredAt === 123, "triggered alarms should normalize as disabled");

    const binanceSocket = context.createMultiSocket("Binance", ["ZEC", "BTC"]);
    assert(binanceSocket && binanceSocket.coins.length === 2, "Binance multi-socket should include supported coins");
    assert(binanceSocket.parseMessage({ data: { s: "ZECUSDT", c: "25.5", P: "1.2" } })[0].coin === "ZEC", "Binance WS parser should route combined stream messages");
    assert(binanceSocket.parseMessage({ data: { s: "UNKNOWN", c: "1", P: "0" } }).length === 0, "Binance WS parser should ignore unknown symbols");
    assert(binanceSocket.parseMessage({ data: { s: "ZECUSDT", c: "0", P: "0" } }).length === 0, "Binance WS parser should reject invalid prices");

    const dynBitfinex = context.makeAssetKey("Bitfinex", "tPEPE:USD", "PEPE", "Pepe");
    const bitfinexSocket = context.createMultiSocket("Bitfinex", ["ZEC", dynBitfinex]);
    assert(bitfinexSocket && bitfinexSocket.subscribeMessages.length === 2, "Bitfinex multi-socket should include dynamic supported coins");
    assert(bitfinexSocket.parseMessage({ event: "subscribed", symbol: "tZECUSD", chanId: 10 }).length === 0, "Bitfinex subscription messages should not emit prices");
    var bitfinexUpdate = bitfinexSocket.parseMessage([10, [0, 0, 0, 0, 0, 0.02, 30.5]]);
    assert(bitfinexUpdate.length === 1 && bitfinexUpdate[0].coin === "ZEC", "Bitfinex WS parser should map channel to coin");
    assert(bitfinexSocket.parseMessage([999, [0, 0, 0, 0, 0, 0.02, 30.5]]).length === 0, "Bitfinex WS parser should ignore unknown channels");

    console.log("price_provider.test.js: ok");
}

run().catch((error) => {
    console.error(error && error.stack ? error.stack : error);
    process.exit(1);
});
