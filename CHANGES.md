# Changelog

## 3.1.0

### Multi-coin support
- Tracks any of 50 coins (ZEC, BTC, ETH, SOL, XRP, ADA, AVAX, DOT, LINK, ATOM, NEAR, APT, SUI, TON, HBAR, ICP, XLM, ALGO, XTZ, EGLD, ARB, OP, POL, MNT, TIA, STX, UNI, AAVE, MKR, LDO, CRV, RUNE, GMX, DYDX, COMP, FIL, GRT, RNDR, API3, VET, INJ, MINA, KAVA, ROSE, SEI, FLOW, THETA, ZIL, IOTA, NEO).
- New `coin` config setting (default `ZEC`).
- Source dropdown auto-filters to sources that actually list the chosen coin; switching coins moves to a compatible source if needed.
- Auto-precision price formatting (handles sub-dollar coins like ZIL at $0.0034).

### Two new sources
- **Kraken** (REST).
- **Coinbase Exchange** (REST).

Total sources: Binance, Coingecko, Bitfinex, Kraken, Coinbase.

### Event-driven recovery
- DBus listener via `org.kde.plasma.plasma5support` watching:
  - `org.freedesktop.login1.Manager.PrepareForSleep` (sleep/wake).
  - `org.freedesktop.NetworkManager.StateChanged` (link/IP changes).
- On any matching signal: WebSocket forced to reconnect, immediate REST fetch.
- Pipeline self-restarts after each event so memory stays bounded.
- Wall-clock drift watchdog (30s) kept as a safety net for systems without `dbus-monitor`.

### WebSocket reliability
- Unbounded retries (was: 3-attempt cap).
- Capped exponential backoff: 1s → 2s → 4s → … → 60s, plus 0–1s jitter (was: linear 5s × n).
- Provider-agnostic WS client — providers supply `wsSubscribeMessage()` / `wsParseMessage()`. No more per-source branching.

### REST polling
- Polls only when WebSocket is not connected. Stops automatically once WS comes back live, restarts when it drops.
- Removed client-side polling backoff (it was leaving users on 12× intervals after a transient outage).
- Fixed broken `Qt.callLater(fn, 10000)` (the second arg was ignored — replaced with a real Timer; subsequently removed entirely).

### UI / UX
- **Zcash logo removed**. Bundled `zcash.png` deleted. Replaced with a scalable, themed ticker badge (coin-colored circle with the ticker symbol).
- **Tooltip removed**. No HTML on hover. No tooltip at all.
- 24h change colors now use `Kirigami.Theme.positiveTextColor` / `negativeTextColor` (was hard-coded `#4CAF50` / `#F44336`).
- Popup heading shows full coin name; "Updated HH:MM" replaces the static "every N min" once data is available.
- Refresh button no longer disabled while WS is connected — always available.

### Silent operation
- All `console.log` / `console.warn` / `console.error` removed across the codebase.
- All user-facing error strings removed. Failures return `null` silently. The connection dot is the only state indicator.
- `errorMessage` state and rendering removed.

### Code quality
- `consecutiveErrors`, `backoffMultiplier`, `maxConsecutiveErrors`, `wsFallbackTimer`, `wsUpgradeTimer`, `errorMessage` all dropped — single rule replaces them: REST polls when WS isn't connected.
- Coin registry is the single source of truth for per-source identifiers, brand colors, and display names.
- `metadata.json` icon set to `office-chart-line`; name is "Crypto Price".

### Breaking
- `metadata.json` `Name` changed from "Zcash Price" to "Crypto Price". `Id` (`org.kde.plasma.zcashprice`) is unchanged so existing installs upgrade cleanly.
- `images/zcash.png` deleted.
- `console.*` and `errorMessage` removed (anyone reading widget logs for debugging will see nothing — this is by design).

---

## 3.0.0 (internal)

Multi-coin foundation, provider-agnostic WS, theme-correct colors, initial DBus-less reconnect fixes (wall-clock drift detector, capped exponential backoff). Superseded by 3.1.0.

---

## 2.0.0

Plasma 5 → Plasma 6 migration. Zcash-only. WebSocket support added for Binance and Bitfinex. See git history for details.
