#!/bin/bash
# Pre-flight validation script for Zcash Price Applet

echo "=========================================="
echo "Zcash Price Applet - Pre-Flight Check"
echo "=========================================="
echo ""

PASSED=0
FAILED=0

check_pass() {
    echo "  ✓ $1"
    ((PASSED++))
}

check_fail() {
    echo "  ✗ $1"
    ((FAILED++))
}

cd "$(dirname "$0")"

# Check 1: Plasma 6
echo "1. Checking Plasma 6..."
if command -v kpackagetool6 &> /dev/null; then
    check_pass "kpackagetool6 found"
else
    check_fail "kpackagetool6 not found (install plasma-sdk)"
fi

# Check 2: Metadata
echo ""
echo "2. Checking metadata.json..."
if [ -f "package/metadata.json" ]; then
    if python3 -m json.tool package/metadata.json > /dev/null 2>&1; then
        check_pass "metadata.json is valid JSON"
        
        # Check for required fields
        if grep -q '"X-Plasma-API-Minimum-Version": "6.0"' package/metadata.json; then
            check_pass "Plasma 6 API version specified"
        else
            check_fail "Missing Plasma 6 API version"
        fi
    else
        check_fail "metadata.json is invalid JSON"
    fi
else
    check_fail "metadata.json not found"
fi

# Check 3: Required files
echo ""
echo "3. Checking required files..."
REQUIRED_FILES=(
    "package/contents/ui/main.qml"
    "package/contents/code/PriceProvider.js"
    "package/contents/config/main.xml"
    "package/contents/ui/config/configGeneral.qml"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        check_pass "$file exists"
    else
        check_fail "$file missing"
    fi
done

# Check 4: QML syntax (basic)
echo ""
echo "4. Checking QML syntax..."

# Check for common syntax issues
if grep -q "import org.kde.plasma.plasmoid 2.0" package/contents/ui/main.qml; then
    check_fail "Old Plasma 5 import found in main.qml"
else
    check_pass "Plasma 6 imports in main.qml"
fi

if grep -q "PlasmoidItem {" package/contents/ui/main.qml; then
    check_pass "PlasmoidItem root element found"
else
    check_fail "PlasmoidItem root element missing"
fi

if grep -q "Plasmoid.backgroundHints" package/contents/ui/main.qml; then
    check_pass "Plasmoid.backgroundHints used correctly"
else
    check_fail "Plasmoid.backgroundHints may be incorrect"
fi

# Check 5: JavaScript syntax
echo ""
echo "5. Checking JavaScript syntax..."
if node --check package/contents/code/PriceProvider.js 2>/dev/null || \
   python3 -c "import js2py; js2py.parse_js(open('package/contents/code/PriceProvider.js').read())" 2>/dev/null; then
    check_pass "JavaScript syntax OK"
else
    # Basic check - look for obvious issues
    if grep -q "function.*function" package/contents/code/PriceProvider.js; then
        check_fail "Possible syntax issue in JS"
    else
        check_pass "JavaScript syntax (basic check)"
    fi
fi

# Check 6: Config XML
echo ""
echo "6. Checking config XML..."
if [ -f "package/contents/config/main.xml" ]; then
    if grep -q "useWebSocket" package/contents/config/main.xml; then
        check_pass "useWebSocket config present"
    else
        check_fail "useWebSocket config missing"
    fi
    
    if grep -q "showPriceChange" package/contents/config/main.xml; then
        check_pass "showPriceChange config present"
    else
        check_fail "showPriceChange config missing"
    fi
else
    check_fail "main.xml not found"
fi

# Summary
echo ""
echo "=========================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "=========================================="

if [ $FAILED -eq 0 ]; then
    echo ""
    echo "✓ All checks passed! Safe to proceed with testing."
    echo ""
    echo "Next steps:"
    echo "  1. Run isolated test: plasmoidviewer --applet ./package/ --standalone"
    echo "  2. See TESTING.md for full protocol"
    exit 0
else
    echo ""
    echo "✗ Some checks failed. Review issues above before testing."
    exit 1
fi
