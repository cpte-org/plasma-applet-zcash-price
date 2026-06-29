# Changelog

## 3.6.0

### Added
- Added one-shot watched-coin price alarms with KDE desktop notifications when a price breaks above or below a configured threshold.
- Alarms are evaluated from the shared price-update path, so they work with both REST polling and WebSocket updates.
- Alarm rules are stored in Plasma config, can be enabled/disabled or deleted, and use the selected display currency at creation time.
- Triggered alarms are disabled, marked as triggered, and can be explicitly re-enabled from settings instead of automatically re-arming.
- Split settings into focused **Coins**, **Alarms**, and **Display** pages instead of keeping every control in one General tab.

### Hardening
- Source market lists are cached in Plasma config for fast config search after plasmashell restarts.
- Market-list cache uses a 24-hour TTL, loads cached data first, and refreshes only when missing, expired, or manually requested.
- Added a manual **Refresh markets** action in settings with lightweight refresh status.
- Added a `curl` fallback for settings market search when Plasma/QML `XMLHttpRequest` cannot load a source market list.
- Added `make test` with static applet contract checks, provider/parser/cache coverage, and live `curl` smoke tests for market discovery behavior.

## 3.5.0

### Added
- **Source-backed market search**: users can now track built-in coins or search the selected source for any listed USD/USDT market.
- Dynamic asset keys preserve provider-specific market IDs, so custom Binance, Coingecko, Bitfinex, Kraken, and Coinbase selections keep working after restart.
- Multi-coin watchlists can include both curated built-in coins and source-discovered markets.

### Reliability
- Repeated REST failures for a tracked market now clear stale prices back to `...`, so delisted or API-changed markets do not leave old values displayed indefinitely.

## 3.4.0

### Fixed
- **Currency conversion**: picking EUR/GBP/JPY/BTC/ETH now actually converts the price instead of just changing the symbol on a USD value. All upstream sources return USD; conversion happens client-side.

### Currency
- USD→{EUR,GBP,JPY,BTC,ETH} rate fetcher in `PriceProvider.js` (`ensureFxRates`, `convertFromUsd`, `invalidateFxRates`). Rates pulled from Coingecko using USDT as the USD proxy, cached in-memory for 1 hour, with concurrent-call coalescing.
- Rates auto-refresh on wake/network-change events (cache invalidated in `handleWakeup`).

### Changed
- Each row stores raw `priceUsd`; display strings derive from it via `convertFromUsd` at format time.
- Currency and decimal-places changes no longer tear down providers — they trigger `reformatAllPrices()`, so the switch is instant with no WebSocket reconnect or provider churn.

---

## 3.3.0

### Multi-coin display modes
- New **Display mode** setting with three options:
  - **Single** — original behavior, one coin (backward compatible).
  - **Rotation** — TV-news cross-fade through the watchlist every 5s. Hover pauses.
  - **Stacked** — all watched coins side-by-side; marquee auto-scrolls at 30 px/s when content exceeds available width. Hover pauses. Click a coin to open its site.
- New **Watchlist** config (`coins` StringList, default `ZEC,BTC,ETH`) — checkbox grid, used by rotation and stacked modes.
- Per-coin source resolution with auto-fallback: each coin uses the configured source if listed there, otherwise the first available.

### WebSocket multiplexing
- One socket per source streams updates for all watched coins, instead of one socket per coin.
- **Binance**: combined stream (`/stream?streams=...`) with per-symbol routing.
- **Bitfinex**: multi-channel subscribe with chanId→coin mapping.
- `WebSocketProvider.qml` now consumes a `multiSocket` descriptor and emits `priceUpdate(coin, price, change24h)` per symbol.

### Dynamic panel width
- Stacked mode uses `Layout.fillWidth: true` with content-driven max (capped at 600 px) and a 120 px minimum, so the applet shrinks when the panel needs space for app icons; the marquee absorbs overflow.
- Single/rotation modes stay fixed at content width.

### UI
- Compact representation re-architected around a `ListModel` of watched coins with reactive role bindings, so prices live-update inside delegates without manual refresh paths.
- Popup now lists every watched coin with badge, price, 24h change, and live status; click a row to open its market site.

### Tooling
- New `make restart-plasma` and `make reload` targets for fast iteration (`reload` = `install-user` + `restart-plasma`).

---

## 3.2.0

### Fixed
- Coin changes from **Crypto Price Settings** now rebuild the active provider immediately.
- Stale REST responses from the previous coin/source are ignored after settings change, so the old coin cannot repaint the applet.
- The display resets while switching providers, making coin changes visible immediately.
- If a saved source is not valid for the selected coin, the applet falls back to the first supported source.
- Hover tooltip/popup behavior is explicitly disabled so hovering the panel applet stays silent.
- User install/uninstall Makefile targets now specify `--type Plasma/Applet`, avoiding stale generic KPackage installs.

---

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
