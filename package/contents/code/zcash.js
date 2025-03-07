var sources = [
    {
        name: 'Coingecko',
        url: 'https://api.coingecko.com/api/v3/simple/price?ids=zcash&vs_currencies=usd',
        homepage: 'https://coingecko.com/',
        currency: 'USD',
        getRate: function (data) {
            return data.zcash.usd;
        }
    },
    {
        name: 'Bitfinex',
        url: 'https://api.bitfinex.com/v1/pubticker/zecusd',
        homepage: 'https://www.bitfinex.com/',
        currency: 'USD',
        getRate: function (data) {
            return data.last_price;
        }
    },
    {
        name: 'Binance',
        url: 'https://www.binance.com/api/v3/ticker/price?symbol=ZECUSDT',
        homepage: 'https://www.binance.com/',
        currency: 'USD',
        getRate: function (data) {
            return data.price;
        }
    },
    {
        name: 'Sideshift',
        url: 'https://sideshift.ai/api/v2/pair/zcash-shielded/usdt-arbitrum',
        homepage: 'https://www.sideshift.ai/',
        currency: 'USD',
        getRate: function (data) {
            return data.rate;
        }
    },
    {
        name: 'Fawazahmed0',
        url: 'https://cdn.jsdelivr.net/gh/fawazahmed0/currency-api@1/latest/currencies/zec.json',
        homepage: 'https://github.com/fawazahmed0/currency-api',
        currency: 'USD',
        getRate: function (data) {
            return data.zec.usdt;
        }
    },
];

var currencyApiUrl = 'http://api.fixer.io';

var currencySymbols = {
    'USD': '$',  // US Dollar
};

function getRate(source, currency, callback) {
    var source = typeof source === 'undefined' ? getSourceByName('Cryptonator') : getSourceByName(source);

    if (source === null) return false;

    var xhr = new XMLHttpRequest();
    xhr.open('GET', source.url, true);
    xhr.onreadystatechange = function () {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                var data = JSON.parse(xhr.responseText);
                var rate = source.getRate(data);
                if (source.currency !== currency) {
                    convert(rate, source.currency, currency, callback);
                    return;
                }
                callback(rate);
            } else {
                console.error('Request failed with status:', xhr.status);
            }
        }
    };
    xhr.send();
    return true;
}

function getSourceByName(name) {
    for (var i = 0; i < sources.length; i++) {
        if (sources[i].name == name) {
            return sources[i];
        }
    }
    return null;
}

function getAllSources() {
    var sourceNames = [];
    for (var i = 0; i < sources.length; i++) {
        sourceNames.push(sources[i].name);
    }
    return sourceNames;
}

function getAllCurrencies() {
    var currencies = [];
    Object.keys(currencySymbols).forEach(function eachKey(key) {
        currencies.push(key);
    });
    return currencies;
}

function convert(value, from, to, callback) {
    var xhr = new XMLHttpRequest();
    xhr.open('GET', currencyApiUrl + '/latest?base=' + from, true);
    xhr.onreadystatechange = function () {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                var data = JSON.parse(xhr.responseText);
                var rate = data.rates[to];
                callback(value * rate);
            } else {
                console.error('Request failed with status:', xhr.status);
            }
        }
    };
    xhr.send();
}

