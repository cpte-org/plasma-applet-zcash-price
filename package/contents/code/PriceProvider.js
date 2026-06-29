/*
 *   Copyright (C) 2024 Crypto Price Applet Contributors
 *   SPDX-License-Identifier: GPL-3.0
 *
 *   Multi-coin price provider system. Silent: callers receive (null, null) on
 *   any failure — no console output, no buffered error strings.
 */

// ====== Coin registry ==================================================
var COINS = {
    'ZEC':   { name: 'Zcash',             binance: 'ZECUSDT',   coingecko: 'zcash',                   bitfinex: 'tZECUSD',   kraken: 'ZECUSD',   coinbase: 'ZEC-USD',   color: '#F4B728' },
    'BTC':   { name: 'Bitcoin',           binance: 'BTCUSDT',   coingecko: 'bitcoin',                 bitfinex: 'tBTCUSD',   kraken: 'XBTUSD',   coinbase: 'BTC-USD',   color: '#F7931A' },
    'ETH':   { name: 'Ethereum',          binance: 'ETHUSDT',   coingecko: 'ethereum',                bitfinex: 'tETHUSD',   kraken: 'ETHUSD',   coinbase: 'ETH-USD',   color: '#627EEA' },
    'BNB':   { name: 'BNB',               binance: 'BNBUSDT',   coingecko: 'binancecoin',             bitfinex: null,        kraken: null,       coinbase: null,        color: '#F3BA2F' },
    'SOL':   { name: 'Solana',            binance: 'SOLUSDT',   coingecko: 'solana',                  bitfinex: 'tSOLUSD',   kraken: 'SOLUSD',   coinbase: 'SOL-USD',   color: '#14F195' },
    'XRP':   { name: 'XRP',               binance: 'XRPUSDT',   coingecko: 'ripple',                  bitfinex: 'tXRPUSD',   kraken: 'XRPUSD',   coinbase: 'XRP-USD',   color: '#0085C0' },
    'ADA':   { name: 'Cardano',           binance: 'ADAUSDT',   coingecko: 'cardano',                 bitfinex: 'tADAUSD',   kraken: 'ADAUSD',   coinbase: 'ADA-USD',   color: '#0033AD' },
    'AVAX':  { name: 'Avalanche',         binance: 'AVAXUSDT',  coingecko: 'avalanche-2',             bitfinex: 'tAVAX:USD', kraken: 'AVAXUSD',  coinbase: 'AVAX-USD',  color: '#E84142' },
    'DOT':   { name: 'Polkadot',          binance: 'DOTUSDT',   coingecko: 'polkadot',                bitfinex: 'tDOTUSD',   kraken: 'DOTUSD',   coinbase: 'DOT-USD',   color: '#E6007A' },
    'LINK':  { name: 'Chainlink',         binance: 'LINKUSDT',  coingecko: 'chainlink',               bitfinex: 'tLINK:USD', kraken: 'LINKUSD',  coinbase: 'LINK-USD',  color: '#2A5ADA' },
    'ATOM':  { name: 'Cosmos',            binance: 'ATOMUSDT',  coingecko: 'cosmos',                  bitfinex: 'tATOUSD',   kraken: 'ATOMUSD',  coinbase: 'ATOM-USD',  color: '#2E3148' },
    'NEAR':  { name: 'NEAR Protocol',     binance: 'NEARUSDT',  coingecko: 'near',                    bitfinex: 'tNEAR:USD', kraken: 'NEARUSD',  coinbase: 'NEAR-USD',  color: '#000000' },
    'APT':   { name: 'Aptos',             binance: 'APTUSDT',   coingecko: 'aptos',                   bitfinex: 'tAPTUSD',   kraken: 'APTUSD',   coinbase: 'APT-USD',   color: '#1E1E1E' },
    'SUI':   { name: 'Sui',               binance: 'SUIUSDT',   coingecko: 'sui',                     bitfinex: 'tSUIUSD',   kraken: 'SUIUSD',   coinbase: 'SUI-USD',   color: '#4DA2FF' },
    'TON':   { name: 'Toncoin',           binance: 'TONUSDT',   coingecko: 'the-open-network',        bitfinex: 'tTONUSD',   kraken: 'TONUSD',   coinbase: null,        color: '#0098EA' },
    'HBAR':  { name: 'Hedera',            binance: 'HBARUSDT',  coingecko: 'hedera-hashgraph',        bitfinex: null,        kraken: null,       coinbase: null,        color: '#222222' },
    'ICP':   { name: 'Internet Computer', binance: 'ICPUSDT',   coingecko: 'internet-computer',       bitfinex: 'tICPUSD',   kraken: 'ICPUSD',   coinbase: 'ICP-USD',   color: '#3B00B9' },
    'XLM':   { name: 'Stellar',           binance: 'XLMUSDT',   coingecko: 'stellar',                 bitfinex: 'tXLMUSD',   kraken: 'XLMUSD',   coinbase: 'XLM-USD',   color: '#000000' },
    'ALGO':  { name: 'Algorand',          binance: 'ALGOUSDT',  coingecko: 'algorand',                bitfinex: 'tALGUSD',   kraken: 'ALGOUSD',  coinbase: 'ALGO-USD',  color: '#000000' },
    'XTZ':   { name: 'Tezos',             binance: 'XTZUSDT',   coingecko: 'tezos',                   bitfinex: 'tXTZUSD',   kraken: 'XTZUSD',   coinbase: 'XTZ-USD',   color: '#2C7DF7' },
    'EGLD':  { name: 'MultiversX',        binance: 'EGLDUSDT',  coingecko: 'elrond-erd-2',            bitfinex: null,        kraken: 'EGLDUSD',  coinbase: 'EGLD-USD',  color: '#1B46C2' },
    'ARB':   { name: 'Arbitrum',          binance: 'ARBUSDT',   coingecko: 'arbitrum',                bitfinex: 'tARBUSD',   kraken: 'ARBUSD',   coinbase: 'ARB-USD',   color: '#28A0F0' },
    'OP':    { name: 'Optimism',          binance: 'OPUSDT',    coingecko: 'optimism',                bitfinex: 'tOPUSD',    kraken: 'OPUSD',    coinbase: 'OP-USD',    color: '#FF0420' },
    'POL':   { name: 'Polygon',           binance: 'POLUSDT',   coingecko: 'matic-network',           bitfinex: null,        kraken: 'POLUSD',   coinbase: 'POL-USD',   color: '#8247E5' },
    'MNT':   { name: 'Mantle',            binance: 'MNTUSDT',   coingecko: 'mantle',                  bitfinex: null,        kraken: 'MNTUSD',   coinbase: 'MNT-USD',   color: '#000000' },
    'TIA':   { name: 'Celestia',          binance: 'TIAUSDT',   coingecko: 'celestia',                bitfinex: 'tTIAUSD',   kraken: 'TIAUSD',   coinbase: 'TIA-USD',   color: '#7B2BF9' },
    'STX':   { name: 'Stacks',            binance: 'STXUSDT',   coingecko: 'blockstack',              bitfinex: null,        kraken: 'STXUSD',   coinbase: 'STX-USD',   color: '#5546FF' },
    'UNI':   { name: 'Uniswap',           binance: 'UNIUSDT',   coingecko: 'uniswap',                 bitfinex: 'tUNIUSD',   kraken: 'UNIUSD',   coinbase: 'UNI-USD',   color: '#FF007A' },
    'AAVE':  { name: 'Aave',              binance: 'AAVEUSDT',  coingecko: 'aave',                    bitfinex: 'tAAVE:USD', kraken: 'AAVEUSD',  coinbase: 'AAVE-USD',  color: '#B6509E' },
    'MKR':   { name: 'Maker',             binance: 'MKRUSDT',   coingecko: 'maker',                   bitfinex: 'tMKRUSD',   kraken: 'MKRUSD',   coinbase: 'MKR-USD',   color: '#1AAB9B' },
    'LDO':   { name: 'Lido DAO',          binance: 'LDOUSDT',   coingecko: 'lido-dao',                bitfinex: 'tLDOUSD',   kraken: 'LDOUSD',   coinbase: 'LDO-USD',   color: '#00A3FF' },
    'CRV':   { name: 'Curve',             binance: 'CRVUSDT',   coingecko: 'curve-dao-token',         bitfinex: null,        kraken: 'CRVUSD',   coinbase: 'CRV-USD',   color: '#A30000' },
    'RUNE':  { name: 'THORChain',         binance: 'RUNEUSDT',  coingecko: 'thorchain',               bitfinex: null,        kraken: 'RUNEUSD',  coinbase: 'RUNE-USD',  color: '#23DCC8' },
    'GMX':   { name: 'GMX',               binance: 'GMXUSDT',   coingecko: 'gmx',                     bitfinex: null,        kraken: 'GMXUSD',   coinbase: null,        color: '#3D51FF' },
    'DYDX':  { name: 'dYdX',              binance: 'DYDXUSDT',  coingecko: 'dydx-chain',              bitfinex: 'tDYDX:USD', kraken: 'DYDXUSD',  coinbase: 'DYDX-USD',  color: '#6966FF' },
    'COMP':  { name: 'Compound',          binance: 'COMPUSDT',  coingecko: 'compound-governance-token', bitfinex: 'tCOMP:USD', kraken: 'COMPUSD', coinbase: 'COMP-USD', color: '#00D395' },
    'FIL':   { name: 'Filecoin',          binance: 'FILUSDT',   coingecko: 'filecoin',                bitfinex: 'tFILUSD',   kraken: 'FILUSD',   coinbase: 'FIL-USD',   color: '#0090FF' },
    'GRT':   { name: 'The Graph',         binance: 'GRTUSDT',   coingecko: 'the-graph',               bitfinex: null,        kraken: 'GRTUSD',   coinbase: 'GRT-USD',   color: '#6747ED' },
    'RNDR':  { name: 'Render',            binance: 'RNDRUSDT',  coingecko: 'render-token',            bitfinex: null,        kraken: 'RNDRUSD',  coinbase: 'RNDR-USD',  color: '#CF1011' },
    'API3':  { name: 'API3',              binance: 'API3USDT',  coingecko: 'api3',                    bitfinex: null,        kraken: 'API3USD',  coinbase: 'API3-USD',  color: '#7CE3CB' },
    'VET':   { name: 'VeChain',           binance: 'VETUSDT',   coingecko: 'vechain',                 bitfinex: null,        kraken: null,       coinbase: 'VET-USD',   color: '#15BDFF' },
    'INJ':   { name: 'Injective',         binance: 'INJUSDT',   coingecko: 'injective-protocol',      bitfinex: 'tINJUSD',   kraken: 'INJUSD',   coinbase: 'INJ-USD',   color: '#00B4E1' },
    'MINA':  { name: 'Mina',              binance: 'MINAUSDT',  coingecko: 'mina-protocol',           bitfinex: 'tMNAUSD',   kraken: 'MINAUSD',  coinbase: 'MINA-USD',  color: '#000000' },
    'KAVA':  { name: 'Kava',              binance: 'KAVAUSDT',  coingecko: 'kava',                    bitfinex: null,        kraken: 'KAVAUSD',  coinbase: 'KAVA-USD',  color: '#FF433E' },
    'ROSE':  { name: 'Oasis Network',     binance: 'ROSEUSDT',  coingecko: 'oasis-network',           bitfinex: null,        kraken: 'ROSEUSD',  coinbase: 'ROSE-USD',  color: '#0092F6' },
    'SEI':   { name: 'Sei',               binance: 'SEIUSDT',   coingecko: 'sei-network',             bitfinex: 'tSEIUSD',   kraken: 'SEIUSD',   coinbase: 'SEI-USD',   color: '#9D1F19' },
    'FLOW':  { name: 'Flow',              binance: 'FLOWUSDT',  coingecko: 'flow',                    bitfinex: null,        kraken: 'FLOWUSD',  coinbase: 'FLOW-USD',  color: '#00EF8B' },
    'THETA': { name: 'Theta Network',     binance: 'THETAUSDT', coingecko: 'theta-token',             bitfinex: null,        kraken: null,       coinbase: 'THETA-USD', color: '#2AB8E6' },
    'ZIL':   { name: 'Zilliqa',           binance: 'ZILUSDT',   coingecko: 'zilliqa',                 bitfinex: 'tZILUSD',   kraken: null,       coinbase: 'ZIL-USD',   color: '#49C1BF' },
    'IOTA':  { name: 'IOTA',              binance: 'IOTAUSDT',  coingecko: 'iota',                    bitfinex: 'tIOTUSD',   kraken: null,       coinbase: null,        color: '#131F37' },
    'NEO':   { name: 'Neo',               binance: 'NEOUSDT',   coingecko: 'neo',                     bitfinex: 'tNEOUSD',   kraken: null,       coinbase: null,        color: '#58BF00' }
};

var SOURCES = ['Binance', 'Coingecko', 'Bitfinex', 'Kraken', 'Coinbase'];

var currencySymbols = {
    'USD': '$', 'EUR': '€', 'GBP': '£', 'JPY': '¥', 'BTC': '₿', 'ETH': 'Ξ'
};

function getCoins() { return Object.keys(COINS); }
function getCoinInfo(t) { return COINS[t] || null; }
function getSources() { return SOURCES.slice(); }
function getCurrencies() { return Object.keys(currencySymbols); }

function _safeText(v) {
    return (v === undefined || v === null) ? "" : ("" + v);
}

function _sourceKey(source) {
    var s = _safeText(source).toLowerCase();
    if (s === "coingecko") return "coingecko";
    if (s === "bitfinex") return "bitfinex";
    if (s === "kraken") return "kraken";
    if (s === "coinbase") return "coinbase";
    return "binance";
}

function _sourceName(key) {
    switch (_sourceKey(key)) {
        case "coingecko": return "Coingecko";
        case "bitfinex": return "Bitfinex";
        case "kraken": return "Kraken";
        case "coinbase": return "Coinbase";
        default: return "Binance";
    }
}

function makeAssetKey(source, sourceId, ticker, name) {
    var src = _sourceName(source);
    var id = encodeURIComponent(_safeText(sourceId).trim());
    var t = encodeURIComponent(_safeText(ticker).trim().toUpperCase());
    var n = encodeURIComponent(_safeText(name).trim());
    if (!id || !t) return "";
    return "dyn:" + encodeURIComponent(src) + ":" + id + ":" + t + ":" + n;
}

function parseAssetKey(ref) {
    var s = _safeText(ref);
    if (s.indexOf("dyn:") !== 0) return null;
    var parts = s.split(":");
    if (parts.length < 4) return null;
    var source = _sourceName(decodeURIComponent(parts[1]));
    var sourceId = decodeURIComponent(parts[2]);
    var ticker = decodeURIComponent(parts[3]).toUpperCase();
    var name = parts.length >= 5 ? decodeURIComponent(parts.slice(4).join(":")) : ticker;
    if (!sourceId || !ticker) return null;
    return { key: s, source: source, sourceId: sourceId, ticker: ticker, name: name || ticker };
}

function _hashColor(text) {
    var h = 0;
    var s = _safeText(text);
    for (var i = 0; i < s.length; i++) h = ((h << 5) - h + s.charCodeAt(i)) | 0;
    var hue = Math.abs(h) % 360;
    return "hsl(" + hue + ", 58%, 45%)";
}

function _dynamicInfo(asset) {
    var info = {
        name: asset.name || asset.ticker,
        ticker: asset.ticker,
        assetKey: asset.key,
        preferredSource: asset.source,
        binance: null,
        coingecko: null,
        bitfinex: null,
        kraken: null,
        coinbase: null,
        color: _hashColor(asset.source + ":" + asset.sourceId)
    };
    info[_sourceKey(asset.source)] = asset.sourceId;
    return info;
}

function getAssetInfo(ref) {
    var raw = _safeText(ref).trim();
    var dyn = parseAssetKey(raw);
    if (dyn) return _dynamicInfo(dyn);
    var ticker = raw.toUpperCase();
    var base = COINS[ticker];
    if (!base) return null;
    var out = {};
    for (var k in base) out[k] = base[k];
    out.ticker = ticker;
    out.assetKey = ticker;
    return out;
}

function getAssetTicker(ref) {
    var info = getAssetInfo(ref);
    return info ? (info.ticker || _safeText(ref).toUpperCase()) : _safeText(ref).toUpperCase();
}

// ====== FX rates (USD -> target) =======================================
// All providers return USD prices. We multiply by a cached USD->target
// rate to display in EUR/GBP/JPY/BTC/ETH. Rates fetched from Coingecko
// using USDT as the USD proxy; cached for 1 hour per session.
var _fxRates = { USD: 1.0 };
var _fxFetchedAt = 0;
var _fxFetching = false;
var _fxWaiters = [];
var _fxRequest = null;

function _fxFlushWaiters() {
    var ws = _fxWaiters; _fxWaiters = [];
    for (var i = 0; i < ws.length; i++) {
        try { ws[i](_fxRates); } catch (e) {}
    }
}

function ensureFxRates(callback) {
    if (typeof callback !== 'function') callback = function() {};
    var now = Date.now();
    var fresh = (now - _fxFetchedAt) < 60 * 60 * 1000;
    if (fresh && _fxFetchedAt > 0) { callback(_fxRates); return; }
    _fxWaiters.push(callback);
    if (_fxFetching) return;
    _fxFetching = true;

    var xhr = new XMLHttpRequest();
    _fxRequest = xhr;
    xhr.timeout = 15000;
    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        _fxFetching = false; _fxRequest = null;
        if (xhr.status === 200) {
            try {
                var d = JSON.parse(xhr.responseText);
                var t = d && d.tether;
                if (t) {
                    var r = { USD: 1.0 };
                    if (isFinite(t.eur)) r.EUR = t.eur;
                    if (isFinite(t.gbp)) r.GBP = t.gbp;
                    if (isFinite(t.jpy)) r.JPY = t.jpy;
                    if (isFinite(t.btc)) r.BTC = t.btc;
                    if (isFinite(t.eth)) r.ETH = t.eth;
                    _fxRates = r;
                    _fxFetchedAt = Date.now();
                }
            } catch (e) {}
        }
        _fxFlushWaiters();
    };
    xhr.ontimeout = function() { _fxFetching = false; _fxRequest = null; _fxFlushWaiters(); };
    xhr.onerror   = function() { _fxFetching = false; _fxRequest = null; _fxFlushWaiters(); };
    try {
        xhr.open("GET", "https://api.coingecko.com/api/v3/simple/price?ids=tether&vs_currencies=usd,eur,gbp,jpy,btc,eth", true);
        xhr.setRequestHeader("Accept", "application/json");
        xhr.send();
    } catch (e) {
        _fxFetching = false; _fxRequest = null;
        _fxFlushWaiters();
    }
}

function convertFromUsd(usd, currency) {
    if (!isFinite(usd)) return NaN;
    if (!currency || currency === 'USD') return usd;
    var r = _fxRates[currency];
    if (!isFinite(r) || r <= 0) return usd;
    return usd * r;
}

function fxReady() { return _fxFetchedAt > 0; }
function invalidateFxRates() { _fxFetchedAt = 0; }

// ====== Source market discovery =======================================
var _marketCache = {};
var _marketWaiters = {};
var MARKET_CACHE_TTL_MS = 24 * 60 * 60 * 1000;

function _marketUrl(source) {
    switch (_sourceName(source)) {
        case 'Binance': return "https://api.binance.com/api/v3/exchangeInfo";
        case 'Coingecko': return "https://api.coingecko.com/api/v3/coins/list";
        case 'Bitfinex': return "https://api-pub.bitfinex.com/v2/conf/pub:list:pair:exchange";
        case 'Kraken': return "https://api.kraken.com/0/public/AssetPairs";
        case 'Coinbase': return "https://api.exchange.coinbase.com/products";
        default: return "";
    }
}

function _assetLabel(ticker, name, sourceId) {
    var n = name && name !== ticker ? " — " + name : "";
    return ticker + n + "  (" + sourceId + ")";
}

function _makeDiscoveredAsset(source, sourceId, ticker, name) {
    var key = makeAssetKey(source, sourceId, ticker, name || ticker);
    return {
        key: key,
        source: _sourceName(source),
        sourceId: sourceId,
        ticker: _safeText(ticker).toUpperCase(),
        name: name || _safeText(ticker).toUpperCase(),
        label: _assetLabel(_safeText(ticker).toUpperCase(), name || _safeText(ticker).toUpperCase(), sourceId)
    };
}

function _parseBinanceMarkets(d) {
    var out = [];
    var symbols = d && d.symbols;
    if (!Array.isArray(symbols)) return out;
    for (var i = 0; i < symbols.length; i++) {
        var s = symbols[i];
        if (!s || s.status !== "TRADING" || s.quoteAsset !== "USDT") continue;
        out.push(_makeDiscoveredAsset("Binance", s.symbol, s.baseAsset, s.baseAsset));
    }
    return out;
}

function _parseCoingeckoMarkets(d) {
    var out = [];
    if (!Array.isArray(d)) return out;
    for (var i = 0; i < d.length; i++) {
        var c = d[i];
        if (!c || !c.id || !c.symbol) continue;
        out.push(_makeDiscoveredAsset("Coingecko", c.id, c.symbol, c.name || c.symbol));
    }
    return out;
}

function _parseCoinbaseMarkets(d) {
    var out = [];
    if (!Array.isArray(d)) return out;
    for (var i = 0; i < d.length; i++) {
        var p = d[i];
        if (!p || p.quote_currency !== "USD" || p.status !== "online") continue;
        out.push(_makeDiscoveredAsset("Coinbase", p.id, p.base_currency, p.display_name || p.base_currency));
    }
    return out;
}

function _parseKrakenMarkets(d) {
    var out = [];
    var result = d && d.result;
    if (!result) return out;
    for (var key in result) {
        var p = result[key];
        if (!p) continue;
        if (p.status && p.status !== "online") continue;
        var quote = p.quote || "";
        var ws = p.wsname || "";
        if (quote !== "ZUSD" && quote !== "USD" && ws.indexOf("/USD") < 0) continue;
        var base = p.base || "";
        var ticker = ws.indexOf("/") > 0 ? ws.split("/")[0] : base.replace(/^X/, "").replace(/^Z/, "");
        if (!ticker) continue;
        out.push(_makeDiscoveredAsset("Kraken", key, ticker, ticker));
    }
    return out;
}

function _parseBitfinexMarkets(d) {
    var out = [];
    var pairs = Array.isArray(d) && Array.isArray(d[0]) ? d[0] : d;
    if (!Array.isArray(pairs)) return out;
    for (var i = 0; i < pairs.length; i++) {
        var pair = _safeText(pairs[i]).toUpperCase();
        if (pair.length < 6 || pair.slice(-3) !== "USD") continue;
        var base = pair.indexOf(":") > 0 ? pair.split(":")[0] : pair.slice(0, pair.length - 3);
        var symbol = "t" + pair;
        out.push(_makeDiscoveredAsset("Bitfinex", symbol, base, base));
    }
    return out;
}

function _parseMarkets(source, data) {
    switch (_sourceName(source)) {
        case 'Binance': return _parseBinanceMarkets(data);
        case 'Coingecko': return _parseCoingeckoMarkets(data);
        case 'Bitfinex': return _parseBitfinexMarkets(data);
        case 'Kraken': return _parseKrakenMarkets(data);
        case 'Coinbase': return _parseCoinbaseMarkets(data);
        default: return [];
    }
}

function getMarketUrl(source) {
    return _marketUrl(source);
}

function parseSourceAssets(source, responseText) {
    if (!responseText || responseText.charAt(0) === '<') return [];
    try {
        return _parseMarkets(source, JSON.parse(responseText));
    } catch (e) {
        return [];
    }
}

function storeSourceAssets(source, items, at) {
    var src = _sourceName(source);
    if (!Array.isArray(items) || items.length === 0) return false;
    _marketCache[src] = { at: isFinite(at) ? at : Date.now(), items: items };
    return true;
}

function _compactMarketItems(items) {
    var out = [];
    if (!Array.isArray(items)) return out;
    for (var i = 0; i < items.length; i++) {
        var item = items[i];
        if (!item || !item.sourceId || !item.ticker) continue;
        out.push([item.sourceId, item.ticker, item.name || item.ticker]);
    }
    return out;
}

function _hydrateMarketItems(source, items) {
    var out = [];
    if (!Array.isArray(items)) return out;
    for (var i = 0; i < items.length; i++) {
        var item = items[i];
        if (Array.isArray(item) && item.length >= 2) {
            out.push(_makeDiscoveredAsset(source, item[0], item[1], item.length >= 3 ? item[2] : item[1]));
        } else if (item && item.sourceId && item.ticker) {
            out.push(_makeDiscoveredAsset(source, item.sourceId, item.ticker, item.name || item.ticker));
        }
    }
    return out;
}

function restoreMarketCache(json) {
    if (!json) return;
    var parsed;
    try { parsed = JSON.parse(json); } catch (e) { return; }
    if (!parsed || typeof parsed !== "object") return;
    for (var source in parsed) {
        var entry = parsed[source];
        if (!entry || !Array.isArray(entry.items) || !isFinite(entry.at)) continue;
        var src = _sourceName(source);
        var at = parseInt(entry.at);
        var items = _hydrateMarketItems(src, entry.items);
        if (!items.length) continue;
        if (_marketCache[src] && _marketCache[src].at >= at) continue;
        _marketCache[src] = { at: at, items: items };
    }
}

function exportMarketCache() {
    var out = {};
    for (var source in _marketCache) {
        var entry = _marketCache[source];
        if (!entry || !Array.isArray(entry.items) || !isFinite(entry.at)) continue;
        out[_sourceName(source)] = { at: entry.at, items: _compactMarketItems(entry.items) };
    }
    try { return JSON.stringify(out); } catch (e) { return ""; }
}

function getMarketCacheMeta(source) {
    var src = _sourceName(source);
    var entry = _marketCache[src];
    if (!entry || !isFinite(entry.at)) return { source: src, at: 0, ageMs: -1, fresh: false, count: 0 };
    var age = Date.now() - entry.at;
    return {
        source: src,
        at: entry.at,
        ageMs: age,
        fresh: age >= 0 && age < MARKET_CACHE_TTL_MS,
        count: Array.isArray(entry.items) ? entry.items.length : 0
    };
}

function fetchSourceAssets(source, options, callback) {
    if (typeof options === 'function') {
        callback = options;
        options = {};
    }
    options = options || {};
    if (typeof callback !== 'function') callback = function() {};
    var src = _sourceName(source);
    var cached = _marketCache[src];
    var now = Date.now();
    var ttl = isFinite(options.ttlMs) ? options.ttlMs : MARKET_CACHE_TTL_MS;
    var hasCache = cached && Array.isArray(cached.items);
    var fresh = hasCache && (now - cached.at) >= 0 && (now - cached.at) < ttl;
    var force = !!options.forceRefresh;
    if (hasCache && !force && (fresh || options.allowStale)) {
        callback(cached.items, {
            source: src,
            fromCache: true,
            stale: !fresh,
            refreshing: !fresh,
            at: cached.at
        });
        if (fresh) return;
    }
    if (_marketWaiters[src]) {
        _marketWaiters[src].push(callback);
        return;
    }
    _marketWaiters[src] = [callback];
    var xhr = new XMLHttpRequest();
    xhr.timeout = 20000;
    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        var items = [];
        if (xhr.status === 200 && xhr.responseText && xhr.responseText.charAt(0) !== '<') {
            try { items = _parseMarkets(src, JSON.parse(xhr.responseText)); } catch (e) { items = []; }
        }
        var ok = xhr.status === 200 && items.length > 0;
        if (ok) _marketCache[src] = { at: Date.now(), items: items };
        else if (hasCache) items = cached.items;
        var waiters = _marketWaiters[src] || [];
        delete _marketWaiters[src];
        for (var i = 0; i < waiters.length; i++) {
            try {
                waiters[i](items, {
                    source: src,
                    fromCache: !ok && hasCache,
                    stale: !ok,
                    refreshing: false,
                    failed: !ok,
                    at: ok ? _marketCache[src].at : (hasCache ? cached.at : 0)
                });
            } catch (e) {}
        }
    };
    xhr.ontimeout = xhr.onerror = function() {
        var waiters = _marketWaiters[src] || [];
        delete _marketWaiters[src];
        var fallback = hasCache ? cached.items : [];
        for (var i = 0; i < waiters.length; i++) {
            try {
                waiters[i](fallback, {
                    source: src,
                    fromCache: hasCache,
                    stale: true,
                    refreshing: false,
                    failed: true,
                    at: hasCache ? cached.at : 0
                });
            } catch (e) {}
        }
    };
    try {
        xhr.open("GET", _marketUrl(src), true);
        xhr.setRequestHeader("Accept", "application/json");
        xhr.send();
    } catch (e) {
        xhr.onerror();
    }
}

function getSourcesForCoin(t) {
    var i = getAssetInfo(t); if (!i) return [];
    var out = [];
    if (i.binance)   out.push('Binance');
    if (i.coingecko) out.push('Coingecko');
    if (i.bitfinex)  out.push('Bitfinex');
    if (i.kraken)    out.push('Kraken');
    if (i.coinbase)  out.push('Coinbase');
    return out;
}

function createProvider(source, coin) {
    var i = getAssetInfo(coin); if (!i) return null;
    switch (source) {
        case 'Binance':   return i.binance   ? new BinanceProvider(coin, i)   : null;
        case 'Coingecko': return i.coingecko ? new CoingeckoProvider(coin, i) : null;
        case 'Bitfinex':  return i.bitfinex  ? new BitfinexProvider(coin, i)  : null;
        case 'Kraken':    return i.kraken    ? new KrakenProvider(coin, i)    : null;
        case 'Coinbase':  return i.coinbase  ? new CoinbaseProvider(coin, i)  : null;
        default: return null;
    }
}

// ====== Multi-symbol WebSocket factory =================================
// Returns an object describing a single WS that streams updates for many
// coins from one source, or null if the source doesn't support WS or no
// passed-in coin is tradable on it.
//
// Shape: { wsUrl, coins: [tickers], subscribeMessages: [strings to send on open],
//          parseMessage(data) -> [{coin, price, change24h}, ...] }
function createMultiSocket(source, coins) {
    if (!Array.isArray(coins) || coins.length === 0) return null;
    if (source === 'Binance')  return _binanceMultiSocket(coins);
    if (source === 'Bitfinex') return _bitfinexMultiSocket(coins);
    return null;
}

function _binanceMultiSocket(coins) {
    var symToCoin = {};
    var streams = [];
    var valid = [];
    for (var i = 0; i < coins.length; i++) {
        var info = getAssetInfo(coins[i]);
        if (!info || !info.binance) continue;
        valid.push(coins[i]);
        symToCoin[info.binance] = coins[i];
        streams.push(info.binance.toLowerCase() + "@ticker");
    }
    if (!valid.length) return null;
    return {
        wsUrl: "wss://stream.binance.com:9443/stream?streams=" + streams.join("/"),
        coins: valid,
        subscribeMessages: [],
        parseMessage: function(data) {
            // Combined-stream wrapper: {stream: "...", data: {...}}
            var d = data && data.data ? data.data : data;
            if (!d || typeof d.s !== 'string') return [];
            var coin = symToCoin[d.s]; if (!coin) return [];
            var price = parseFloat(d.c);
            var change = parseFloat(d.P);
            if (!isFinite(price) || price <= 0) return [];
            return [{ coin: coin, price: price, change24h: isFinite(change) ? change : 0 }];
        }
    };
}

function _bitfinexMultiSocket(coins) {
    var symToCoin = {};
    var msgs = [];
    var valid = [];
    for (var i = 0; i < coins.length; i++) {
        var info = getAssetInfo(coins[i]);
        if (!info || !info.bitfinex) continue;
        valid.push(coins[i]);
        symToCoin[info.bitfinex] = coins[i];
        msgs.push(JSON.stringify({ event: "subscribe", channel: "ticker", symbol: info.bitfinex }));
    }
    if (!valid.length) return null;
    var chanToCoin = {};
    return {
        wsUrl: "wss://api-pub.bitfinex.com/ws/2",
        coins: valid,
        subscribeMessages: msgs,
        parseMessage: function(data) {
            if (data && data.event === 'subscribed' && typeof data.symbol === 'string' && data.chanId !== undefined) {
                var c = symToCoin[data.symbol];
                if (c) chanToCoin[data.chanId] = c;
                return [];
            }
            if (Array.isArray(data) && data.length >= 2 && Array.isArray(data[1]) && data[1].length >= 7) {
                var coin = chanToCoin[data[0]];
                if (!coin) return [];
                var price = parseFloat(data[1][6]);
                var change = parseFloat(data[1][5]) * 100;
                if (!isFinite(price) || price <= 0) return [];
                return [{ coin: coin, price: price, change24h: change }];
            }
            return [];
        }
    };
}

// ====== Base ===========================================================
function BaseProvider(coin, info) {
    this.coin = coin;
    this.info = info;
    this.name = "";
    this.homepage = "";
    this.supportsWebSocket = false;
    this.wsUrl = "";
    this.restUrl = "";
    this.httpRequest = null;
}

BaseProvider.prototype.disconnect = function() {
    if (this.httpRequest) {
        try { this.httpRequest.abort(); } catch (e) {}
        this.httpRequest = null;
    }
};

BaseProvider.prototype.wsSubscribeMessage = function() { return null; };
BaseProvider.prototype.wsParseMessage = function(_d) { return null; };

BaseProvider.prototype._get = function(callback, parseFn) {
    var self = this;
    this.httpRequest = new XMLHttpRequest();
    this.httpRequest.timeout = 15000;
    this.httpRequest.onreadystatechange = function() {
        if (self.httpRequest.readyState !== XMLHttpRequest.DONE) return;
        var status = self.httpRequest.status;
        var body = self.httpRequest.responseText;
        self.httpRequest = null;
        if (status !== 200) { callback(null, null); return; }
        if (!body || body.charAt(0) === '<') { callback(null, null); return; }
        var data;
        try { data = JSON.parse(body); } catch (e) { callback(null, null); return; }
        var parsed;
        try { parsed = parseFn(data); } catch (e) { callback(null, null); return; }
        if (!parsed || !isFinite(parsed.price) || parsed.price <= 0) { callback(null, null); return; }
        callback(parsed.price, isFinite(parsed.change24h) ? parsed.change24h : null);
    };
    this.httpRequest.ontimeout = function() { self.httpRequest = null; callback(null, null); };
    this.httpRequest.onerror   = function() { self.httpRequest = null; callback(null, null); };
    try {
        this.httpRequest.open("GET", this.restUrl, true);
        this.httpRequest.setRequestHeader("Accept", "application/json");
        this.httpRequest.send();
    } catch (e) {
        callback(null, null);
    }
};

// ====== Binance ========================================================
function BinanceProvider(coin, info) {
    BaseProvider.call(this, coin, info);
    this.name = "Binance";
    var ticker = info.ticker || coin;
    this.homepage = "https://www.binance.com/en/trade/" + ticker + "_USDT";
    this.supportsWebSocket = true;
    this.restUrl = "https://api.binance.com/api/v3/ticker/24hr?symbol=" + info.binance;
    this.wsUrl = "wss://stream.binance.com:9443/ws/" + info.binance.toLowerCase() + "@ticker";
}
BinanceProvider.prototype = Object.create(BaseProvider.prototype);
BinanceProvider.prototype.constructor = BinanceProvider;
BinanceProvider.prototype.fetchPrice = function(cb) {
    this._get(cb, function(d) {
        return { price: parseFloat(d.lastPrice), change24h: parseFloat(d.priceChangePercent) };
    });
};
BinanceProvider.prototype.wsParseMessage = function(d) {
    if (!d || typeof d.c !== 'string') return null;
    return { price: parseFloat(d.c), change24h: parseFloat(d.P) };
};

// ====== Coingecko ======================================================
function CoingeckoProvider(coin, info) {
    BaseProvider.call(this, coin, info);
    this.name = "Coingecko";
    this.homepage = "https://www.coingecko.com/en/coins/" + info.coingecko;
    this.restUrl = "https://api.coingecko.com/api/v3/simple/price?ids=" + info.coingecko +
                   "&vs_currencies=usd&include_24hr_change=true";
}
CoingeckoProvider.prototype = Object.create(BaseProvider.prototype);
CoingeckoProvider.prototype.constructor = CoingeckoProvider;
CoingeckoProvider.prototype.fetchPrice = function(cb) {
    var slug = this.info.coingecko;
    this._get(cb, function(d) {
        var c = d[slug]; if (!c || c.usd === undefined) return null;
        return { price: parseFloat(c.usd), change24h: parseFloat(c.usd_24h_change) };
    });
};

// ====== Bitfinex =======================================================
function BitfinexProvider(coin, info) {
    BaseProvider.call(this, coin, info);
    this.name = "Bitfinex";
    this.homepage = "https://trading.bitfinex.com/t/" + (info.ticker || coin) + ":USD";
    this.supportsWebSocket = true;
    this.restUrl = "https://api-pub.bitfinex.com/v2/ticker/" + info.bitfinex;
    this.wsUrl = "wss://api-pub.bitfinex.com/ws/2";
}
BitfinexProvider.prototype = Object.create(BaseProvider.prototype);
BitfinexProvider.prototype.constructor = BitfinexProvider;
BitfinexProvider.prototype.fetchPrice = function(cb) {
    this._get(cb, function(d) {
        if (!Array.isArray(d) || d.length < 7) return null;
        return { price: parseFloat(d[6]), change24h: parseFloat(d[5]) * 100 };
    });
};
BitfinexProvider.prototype.wsSubscribeMessage = function() {
    return JSON.stringify({ event: "subscribe", channel: "ticker", symbol: this.info.bitfinex });
};
BitfinexProvider.prototype.wsParseMessage = function(d) {
    if (Array.isArray(d) && d.length >= 2 && Array.isArray(d[1]) && d[1].length >= 7) {
        return { price: parseFloat(d[1][6]), change24h: parseFloat(d[1][5]) * 100 };
    }
    return null;
};

// ====== Kraken (REST) ==================================================
function KrakenProvider(coin, info) {
    BaseProvider.call(this, coin, info);
    this.name = "Kraken";
    var ticker = info.ticker || coin;
    this.homepage = "https://www.kraken.com/prices/" + (ticker === 'BTC' ? 'bitcoin' : ticker.toLowerCase());
    this.restUrl = "https://api.kraken.com/0/public/Ticker?pair=" + info.kraken;
}
KrakenProvider.prototype = Object.create(BaseProvider.prototype);
KrakenProvider.prototype.constructor = KrakenProvider;
KrakenProvider.prototype.fetchPrice = function(cb) {
    this._get(cb, function(d) {
        if (!d || !d.result) return null;
        var k = Object.keys(d.result); if (!k.length) return null;
        var t = d.result[k[0]];
        var last = parseFloat(t.c[0]);
        var open = parseFloat(t.o);
        var change = (isFinite(open) && open > 0) ? ((last - open) / open) * 100 : NaN;
        return { price: last, change24h: change };
    });
};

// ====== Coinbase Exchange (REST) =======================================
function CoinbaseProvider(coin, info) {
    BaseProvider.call(this, coin, info);
    this.name = "Coinbase";
    this.homepage = "https://www.coinbase.com/price/" + (info.name || coin).toLowerCase().replace(/\s+/g, '-');
    this.restUrl = "https://api.exchange.coinbase.com/products/" + info.coinbase + "/stats";
}
CoinbaseProvider.prototype = Object.create(BaseProvider.prototype);
CoinbaseProvider.prototype.constructor = CoinbaseProvider;
CoinbaseProvider.prototype.fetchPrice = function(cb) {
    this._get(cb, function(d) {
        if (!d || d.last === undefined || d.open === undefined) return null;
        var last = parseFloat(d.last);
        var open = parseFloat(d.open);
        var change = (isFinite(open) && open > 0) ? ((last - open) / open) * 100 : NaN;
        return { price: last, change24h: change };
    });
};
