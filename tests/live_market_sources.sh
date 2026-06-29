#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

SOURCES=(
  "Binance|https://api.binance.com/api/v3/ticker/24hr|10"
  "Coingecko|https://api.coingecko.com/api/v3/coins/list|1000"
  "Bitfinex|https://api-pub.bitfinex.com/v2/conf/pub:list:pair:exchange|10"
  "Kraken|https://api.kraken.com/0/public/AssetPairs|10"
  "Coinbase|https://api.exchange.coinbase.com/products|10"
)

passed=0
skipped=0
failed=0

echo "live_market_sources.sh:"

for entry in "${SOURCES[@]}"; do
  IFS='|' read -r source url minimum <<< "$entry"
  out="$TMPDIR/$source.json"
  if ! curl -L -sS --max-time 20 -H "Accept: application/json" -o "$out" "$url"; then
    echo "  $source: skipped (curl failed)"
    skipped=$((skipped + 1))
    continue
  fi
  if node "$ROOT/tests/parse_live_market_file.js" "$source" "$out" "$minimum" | sed 's/^/  /'; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
  fi
done

if [ "$failed" -gt 0 ]; then
  echo "live_market_sources.sh: failed ($failed source parser failures)"
  exit 1
fi

if [ "$passed" -eq 0 ]; then
  echo "live_market_sources.sh: skipped, no live sources reachable"
  exit 0
fi

if [ "$skipped" -gt 0 ]; then
  echo "live_market_sources.sh: ok ($passed passed, $skipped skipped)"
else
  echo "live_market_sources.sh: ok"
fi
