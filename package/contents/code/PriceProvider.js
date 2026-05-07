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

function getSourcesForCoin(t) {
    var i = COINS[t]; if (!i) return [];
    var out = [];
    if (i.binance)   out.push('Binance');
    if (i.coingecko) out.push('Coingecko');
    if (i.bitfinex)  out.push('Bitfinex');
    if (i.kraken)    out.push('Kraken');
    if (i.coinbase)  out.push('Coinbase');
    return out;
}

function createProvider(source, coin) {
    var i = COINS[coin]; if (!i) return null;
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
        var info = COINS[coins[i]];
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
        var info = COINS[coins[i]];
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
    this.homepage = "https://www.binance.com/en/trade/" + coin + "_USDT";
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
    this.homepage = "https://trading.bitfinex.com/t/" + coin + ":USD";
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
    this.homepage = "https://www.kraken.com/prices/" + (coin === 'BTC' ? 'bitcoin' : coin.toLowerCase());
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
