#!/usr/bin/env node
const fs = require("fs");
const { loadPriceProvider } = require("./helpers/load_price_provider");

const source = process.argv[2];
const file = process.argv[3];
const minimum = parseInt(process.argv[4] || "1", 10);

if (!source || !file) {
    console.error("usage: parse_live_market_file.js <source> <json-file> <minimum>");
    process.exit(2);
}

const provider = loadPriceProvider();
const text = fs.readFileSync(file, "utf8");
const data = JSON.parse(text);
const markets = provider._parseMarkets(source, data);

if (markets.length < minimum) {
    console.error(`${source}: parsed ${markets.length} markets, expected at least ${minimum}`);
    process.exit(1);
}

console.log(`${source}: ${markets.length} markets (${text.length} bytes)`);
