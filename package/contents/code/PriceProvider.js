/*
 *   Copyright (C) 2024 Zcash Price Applet Contributors
 *   SPDX-License-Identifier: GPL-3.0
 *
 *   Price Provider System
 *   
 *   Note: WebSocket is handled by WebSocketProvider.qml (declarative)
 *   This file only handles REST API calls
 */

// Currency symbols mapping
var currencySymbols = {
    'USD': '$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'BTC': '₿',
    'ETH': 'Ξ'
};

// Factory function to create the appropriate provider
function createProvider(name, config) {
    switch (name) {
        case 'Binance':
            return new BinanceProvider(config);
        case 'Coingecko':
            return new CoingeckoProvider(config);
        case 'Bitfinex':
            return new BitfinexProvider(config);
        default:
            return null;
    }
}

// Get list of available sources
function getSources() {
    return ['Binance', 'Coingecko', 'Bitfinex'];
}

// Get list of available currencies
function getCurrencies() {
    return Object.keys(currencySymbols);
}

// Base Provider Class
function BaseProvider(config) {
    this.config = config;
    this.name = "Base";
    this.homepage = "";
    this.supportsWebSocket = false;
    this.wsUrl = "";  // For WebSocketProvider.qml to use
    this.httpRequest = null;
    this.retryCount = 0;
    this.maxRetries = 3;
    this.retryDelay = 5000; // 5 seconds
}

BaseProvider.prototype.fetchPrice = function(callback) {
    throw new Error("fetchPrice must be implemented by subclass");
};

BaseProvider.prototype.disconnect = function() {
    // WebSocket is handled by WebSocketProvider.qml
    // Just abort any pending HTTP requests
    if (this.httpRequest) {
        try {
            this.httpRequest.abort();
        } catch (e) {
            // Ignore abort errors
        }
        this.httpRequest = null;
    }
};

BaseProvider.prototype.destroy = function() {
    this.disconnect();
};

BaseProvider.prototype.handleNetworkError = function(status, statusText) {
    let message = "";
    switch (status) {
        case 0:
            message = i18n("Network error - check your internet connection");
            break;
        case 429:
            message = i18n("Rate limit exceeded - please wait");
            break;
        case 403:
            message = i18n("Access denied by API");
            break;
        case 404:
            message = i18n("API endpoint not found");
            break;
        case 500:
        case 502:
        case 503:
        case 504:
            message = i18n("Server error - try again later");
            break;
        default:
            message = i18n("Request failed (HTTP %1)", status);
    }
    if (this.config.onError) {
        this.config.onError(message);
    }
};

BaseProvider.prototype.safeJsonParse = function(jsonString, context) {
    if (!jsonString || typeof jsonString !== 'string') {
        console.error("ZcashPrice: Empty or invalid JSON string in", context);
        return null;
    }
    
    // Check for HTML error pages
    if (jsonString.trim().startsWith('<')) {
        console.error("ZcashPrice: Received HTML instead of JSON from", context);
        if (this.config.onError) {
            this.config.onError(i18n("%1 returned an error page", this.name));
        }
        return null;
    }
    
    try {
        return JSON.parse(jsonString);
    } catch (e) {
        console.error("ZcashPrice: JSON parse error in", context, ":", e.message);
        console.error("ZcashPrice: Raw response:", jsonString.substring(0, 200));
        if (this.config.onError) {
            this.config.onError(i18n("Invalid response from %1", this.name));
        }
        return null;
    }
};

// Data validation helpers
BaseProvider.prototype.isValidNumber = function(value) {
    if (value === null || value === undefined) return false;
    var num = parseFloat(value);
    return !isNaN(num) && isFinite(num) && num > 0;
};

BaseProvider.prototype.validatePrice = function(price, context) {
    if (!this.isValidNumber(price)) {
        console.error("ZcashPrice: Invalid price from", context, ":", price);
        if (this.config.onError) {
            this.config.onError(i18n("Invalid price data from %1", this.name));
        }
        return false;
    }
    // Sanity check: ZEC price should be between $1 and $100000
    var numPrice = parseFloat(price);
    if (numPrice < 1 || numPrice > 100000) {
        console.error("ZcashPrice: Price out of reasonable range:", numPrice);
        return false;
    }
    return true;
};

// ========== Binance Provider ==========
// Supports both REST API and WebSocket
function BinanceProvider(config) {
    BaseProvider.call(this, config);
    this.name = "Binance";
    this.homepage = "https://www.binance.com/en/price/zcash";
    this.supportsWebSocket = true;
    this.restUrl = "https://api.binance.com/api/v3/ticker/24hr?symbol=ZECUSDT";
    this.wsUrl = "wss://stream.binance.com:9443/ws/zecusdt@ticker";
}

BinanceProvider.prototype = Object.create(BaseProvider.prototype);
BinanceProvider.prototype.constructor = BinanceProvider;

BinanceProvider.prototype.fetchPrice = function(callback) {
    var self = this;
    
    this.httpRequest = new XMLHttpRequest();
    this.httpRequest.timeout = 15000;
    
    this.httpRequest.onreadystatechange = function() {
        if (self.httpRequest.readyState === XMLHttpRequest.DONE) {
            var status = self.httpRequest.status;
            var responseText = self.httpRequest.responseText;
            self.httpRequest = null;
            
            if (status === 200) {
                self.retryCount = 0;
                var data = self.safeJsonParse(responseText, "Binance REST");
                if (data && data.lastPrice) {
                    var price = parseFloat(data.lastPrice);
                    var change24h = data.priceChangePercent ? parseFloat(data.priceChangePercent) : null;
                    
                    if (self.validatePrice(price, "Binance REST")) {
                        callback(price, change24h);
                    } else {
                        callback(null, null);
                    }
                } else {
                    callback(null, null);
                }
            } else {
                self.handleNetworkError(status, "");
                callback(null, null);
            }
        }
    };
    
    this.httpRequest.ontimeout = function() {
        self.httpRequest = null;
        if (self.config.onError) {
            self.config.onError(i18n("Request timeout - Binance API not responding"));
        }
        callback(null, null);
    };
    
    this.httpRequest.onerror = function() {
        self.httpRequest = null;
        self.handleNetworkError(0, "Network Error");
        callback(null, null);
    };
    
    try {
        this.httpRequest.open("GET", this.restUrl, true);
        this.httpRequest.setRequestHeader("Accept", "application/json");
        this.httpRequest.send();
    } catch (e) {
        console.error("ZcashPrice: Binance request error:", e);
        if (this.config.onError) {
            this.config.onError(i18n("Failed to connect to Binance"));
        }
        callback(null, null);
    }
};

// ========== Coingecko Provider ==========
// REST API only (no WebSocket support)
function CoingeckoProvider(config) {
    BaseProvider.call(this, config);
    this.name = "Coingecko";
    this.homepage = "https://www.coingecko.com/en/coins/zcash";
    this.supportsWebSocket = false;
    this.restUrl = "https://api.coingecko.com/api/v3/simple/price?ids=zcash&vs_currencies=usd&include_24hr_change=true";
}

CoingeckoProvider.prototype = Object.create(BaseProvider.prototype);
CoingeckoProvider.prototype.constructor = CoingeckoProvider;

CoingeckoProvider.prototype.fetchPrice = function(callback) {
    var self = this;
    
    this.httpRequest = new XMLHttpRequest();
    this.httpRequest.timeout = 15000;
    
    this.httpRequest.onreadystatechange = function() {
        if (self.httpRequest.readyState === XMLHttpRequest.DONE) {
            var status = self.httpRequest.status;
            var responseText = self.httpRequest.responseText;
            self.httpRequest = null;
            
            if (status === 200) {
                self.retryCount = 0;
                var data = self.safeJsonParse(responseText, "Coingecko");
                if (data && data.zcash && data.zcash.usd !== undefined) {
                    var price = parseFloat(data.zcash.usd);
                    var change24h = data.zcash.usd_24h_change !== undefined 
                        ? parseFloat(data.zcash.usd_24h_change) 
                        : null;
                    
                    if (self.validatePrice(price, "Coingecko")) {
                        callback(price, change24h);
                    } else {
                        callback(null, null);
                    }
                } else {
                    console.error("ZcashPrice: Coingecko response missing data.zcash.usd");
                    callback(null, null);
                }
            } else if (status === 429) {
                // Coingecko rate limits are strict
                if (self.config.onError) {
                    self.config.onError(i18n("Coingecko rate limit - wait a minute"));
                }
                callback(null, null);
            } else {
                self.handleNetworkError(status, "");
                callback(null, null);
            }
        }
    };
    
    this.httpRequest.ontimeout = function() {
        self.httpRequest = null;
        if (self.config.onError) {
            self.config.onError(i18n("Request timeout - Coingecko API not responding"));
        }
        callback(null, null);
    };
    
    this.httpRequest.onerror = function() {
        self.httpRequest = null;
        self.handleNetworkError(0, "Network Error");
        callback(null, null);
    };
    
    try {
        this.httpRequest.open("GET", this.restUrl, true);
        this.httpRequest.setRequestHeader("Accept", "application/json");
        this.httpRequest.send();
    } catch (e) {
        console.error("ZcashPrice: Coingecko request error:", e);
        if (this.config.onError) {
            self.config.onError(i18n("Failed to connect to Coingecko"));
        }
        callback(null, null);
    }
};

// ========== Bitfinex Provider ==========
// REST API with WebSocket support
function BitfinexProvider(config) {
    BaseProvider.call(this, config);
    this.name = "Bitfinex";
    this.homepage = "https://trading.bitfinex.com/t/ZEC:USD";
    this.supportsWebSocket = true;
    this.restUrl = "https://api-pub.bitfinex.com/v2/ticker/tZECUSD";
    this.wsUrl = "wss://api-pub.bitfinex.com/ws/2";
}

BitfinexProvider.prototype = Object.create(BaseProvider.prototype);
BitfinexProvider.prototype.constructor = BitfinexProvider;

BitfinexProvider.prototype.fetchPrice = function(callback) {
    var self = this;
    
    this.httpRequest = new XMLHttpRequest();
    this.httpRequest.timeout = 15000;
    
    this.httpRequest.onreadystatechange = function() {
        if (self.httpRequest.readyState === XMLHttpRequest.DONE) {
            var status = self.httpRequest.status;
            var responseText = self.httpRequest.responseText;
            self.httpRequest = null;
            
            if (status === 200) {
                self.retryCount = 0;
                var data = self.safeJsonParse(responseText, "Bitfinex");
                // Bitfinex returns array: [BID, BID_SIZE, ASK, ASK_SIZE, DAILY_CHANGE, DAILY_CHANGE_RELATIVE, LAST_PRICE, VOLUME, HIGH, LOW]
                if (data && Array.isArray(data) && data.length >= 7) {
                    var price = parseFloat(data[6]); // LAST_PRICE
                    var change24h = parseFloat(data[5]) * 100; // DAILY_CHANGE_RELATIVE as percentage
                    
                    if (self.validatePrice(price, "Bitfinex REST")) {
                        callback(price, isNaN(change24h) ? null : change24h);
                    } else {
                        callback(null, null);
                    }
                } else {
                    if (self.config.onError) {
                        self.config.onError(i18n("Unexpected response from Bitfinex"));
                    }
                    callback(null, null);
                }
            } else {
                self.handleNetworkError(status, "");
                callback(null, null);
            }
        }
    };
    
    this.httpRequest.ontimeout = function() {
        self.httpRequest = null;
        if (self.config.onError) {
            self.config.onError(i18n("Request timeout - Bitfinex API not responding"));
        }
        callback(null, null);
    };
    
    this.httpRequest.onerror = function() {
        self.httpRequest = null;
        self.handleNetworkError(0, "Network Error");
        callback(null, null);
    };
    
    try {
        this.httpRequest.open("GET", this.restUrl, true);
        this.httpRequest.setRequestHeader("Accept", "application/json");
        this.httpRequest.send();
    } catch (e) {
        console.error("ZcashPrice: Bitfinex request error:", e);
        if (this.config.onError) {
            self.config.onError(i18n("Failed to connect to Bitfinex"));
        }
        callback(null, null);
    }
};
