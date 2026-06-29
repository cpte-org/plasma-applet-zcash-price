#!/usr/bin/env node
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");

function read(rel) {
    return fs.readFileSync(path.join(root, rel), "utf8");
}

function assert(condition, message) {
    if (!condition) throw new Error(message);
}

function assertIncludes(file, needle, message) {
    assert(read(file).includes(needle), message || `${file} should include ${needle}`);
}

function run() {
    const metadata = JSON.parse(read("package/metadata.json"));
    const version = metadata.KPlugin.Version;

    assertIncludes("README.md", `version-${version}-blue`, "README version badge should match metadata");
    assertIncludes("Makefile", `crypto-price-${version}.plasmoid`, "Makefile zip target should match metadata");
    assertIncludes("CHANGES.md", `## ${version}`, "CHANGES should include current version section");

    assertIncludes("package/contents/config/config.qml", 'name: i18n("Coins")', "config should expose Coins page");
    assertIncludes("package/contents/config/config.qml", 'source: "config/configGeneral.qml"', "Coins page should point at configGeneral");
    assertIncludes("package/contents/config/config.qml", 'name: i18n("Alarms")', "config should expose Alarms page");
    assertIncludes("package/contents/config/config.qml", 'source: "config/configAlarms.qml"', "Alarms page should point at configAlarms");
    assertIncludes("package/contents/config/config.qml", 'name: i18n("Display")', "config should expose Display page");
    assertIncludes("package/contents/config/config.qml", 'source: "config/configDisplay.qml"', "Display page should point at configDisplay");

    [
        "coin", "displayMode", "coins", "source", "marketCache", "priceAlarms",
        "useWebSocket", "currency", "showDecimals", "showPriceChange",
        "refreshRate", "showIcon", "showText", "showBackground", "onClickAction"
    ].forEach((key) => {
        assertIncludes("package/contents/config/main.xml", `name="${key}"`, `main.xml should define ${key}`);
    });

    assertIncludes("package/contents/ui/main.qml", "evaluatePriceAlarms", "main.qml should evaluate alarms");
    assertIncludes("package/contents/ui/main.qml", "notify-send", "main.qml should send desktop notifications");
    assertIncludes("package/contents/ui/main.qml", "triggeredAt", "main.qml should persist triggered alarms");
    assertIncludes("package/contents/ui/main.qml", "PriceProvider.fxReady()", "non-USD alarms should wait for FX rates");

    assertIncludes("package/contents/ui/config/configAlarms.qml", "triggeredAt", "alarms UI should track triggered state");
    assertIncludes("package/contents/ui/config/configAlarms.qml", 'i18n("Triggered")', "alarms UI should show triggered state");
    assertIncludes("package/contents/ui/config/configAlarms.qml", 'text: i18n("Enable")', "alarms UI should offer enable action");
    assertIncludes("package/contents/ui/config/configAlarms.qml", 'text: i18n("Disable")', "alarms UI should offer disable action");

    assertIncludes("package/contents/ui/config/configGeneral.qml", "marketStatusText()", "Coins page should use a shared market status label");
    assertIncludes("package/contents/ui/config/configGeneral.qml", "fetchSourceMarketsWithCurl", "Coins page should fall back to curl when QML XHR fails");
    assertIncludes("package/contents/ui/config/configGeneral.qml", "PriceProvider.parseSourceAssets", "curl fallback should use shared provider parser");
    assertIncludes("package/contents/ui/config/configGeneral.qml", "PriceProvider.storeSourceAssets", "curl fallback should populate provider cache");
    assertIncludes("package/contents/ui/config/configGeneral.qml", "marketCurlSource", "Coins page should define executable data source for curl fallback");
    assert(!read("package/contents/ui/config/configGeneral.qml").includes("Could not refresh"), "market status should not use alarming generic failure copy");
    assert(!read("package/contents/ui/config/configGeneral.qml").includes("Refresh failed"), "market status should use neutral search-unavailable copy");

    assertIncludes("package/contents/ui/config/configDisplay.qml", "cfg_onClickAction", "Display page should own click action config");
    assertIncludes("package/contents/ui/config/configDisplay.qml", "cfg_showBackground", "Display page should own widget appearance config");

    console.log("static_contracts.test.js: ok");
}

try {
    run();
} catch (error) {
    console.error(error && error.stack ? error.stack : error);
    process.exit(1);
}
