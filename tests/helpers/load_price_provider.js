const fs = require("fs");
const path = require("path");
const vm = require("vm");

function loadPriceProvider(XMLHttpRequestImpl) {
    const providerPath = path.join(__dirname, "..", "..", "package", "contents", "code", "PriceProvider.js");
    const providerCode = fs.readFileSync(providerPath, "utf8");
    const context = {
        XMLHttpRequest: XMLHttpRequestImpl || function() {},
        console,
        Date,
        JSON,
        Math,
        parseFloat,
        parseInt,
        isFinite,
        setTimeout,
        clearTimeout
    };
    vm.createContext(context);
    vm.runInContext(providerCode, context, { filename: "PriceProvider.js" });
    return context;
}

module.exports = { loadPriceProvider };
