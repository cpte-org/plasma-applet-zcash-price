# Crypto Price Tracker — Plasma 6 Applet

A lightweight, silent KDE Plasma 6 widget that tracks the live price of any of 50 supported cryptocurrencies.

![Version](https://img.shields.io/badge/version-3.4.0-blue)
![Plasma](https://img.shields.io/badge/Plasma-6.0+-1d99f3)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

## Features

- **Three display modes**:
  - **Single** — one coin, original compact look.
  - **Rotation** — TV-news style: cycles through your watchlist with a cross-fade every 5s. Hover to pause.
  - **Stacked** — all watched coins side-by-side; auto-scrolls (marquee) when content exceeds available width. Hover to pause. Click any coin to open its market site.
- **Multi-symbol WebSockets**: one socket per source streams updates for many coins (Binance combined-stream, Bitfinex multi-channel). Watching 10 coins on Binance = 1 socket, not 10.
- **Dynamic width**: stacked mode yields panel space to other widgets; the marquee handles overflow when crowded.
- **50 coins**: ZEC, BTC, ETH, SOL, XRP, ADA, AVAX, DOT, LINK, ATOM, NEAR, APT, SUI, TON, HBAR, ICP, XLM, ALGO, XTZ, EGLD, ARB, OP, POL, MNT, TIA, STX, UNI, AAVE, MKR, LDO, CRV, RUNE, GMX, DYDX, COMP, FIL, GRT, RNDR, API3, VET, INJ, MINA, KAVA, ROSE, SEI, FLOW, THETA, ZIL, IOTA, NEO.
- **5 sources**: Binance, Coingecko, Bitfinex, Kraken, Coinbase. Source list auto-filters to the ones that actually list the picked coin.
- **Live updates** via WebSocket (Binance, Bitfinex). REST polling fallback for the others or when WS is unavailable.
- **Themed coin badge** (no bundled logo). Ticker text on a coin-colored circle, scales cleanly at any panel size.
- **Event-driven recovery** from sleep/suspend and network state changes via DBus (login1 + NetworkManager).
- **Silent**: no tooltip, no logging, no error dialogs. Just the price.
- 24h change indicator (theme-correct positive/negative colors).
- Configurable refresh interval, decimal precision, click action.
- Panel and desktop modes.

## Requirements

- KDE Plasma 6.0+
- Qt 6.0+
- KDE Frameworks 6
- `dbus-monitor` (for event-driven recovery; usually pre-installed)

## Installation

```bash
git clone https://github.com/cpte-org/plasma-applet-zcash-price.git
cd plasma-applet-zcash-price
make install-user
```

System-wide:
```bash
sudo make install
```

After install, right-click the panel → "Add Widgets…" → search "Crypto Price".

## Configuration

Right-click the widget → "Configure Crypto Price…":

- **Display mode**: single / rotation / stacked.
- **Coin** (single mode): ticker symbol (defaults to ZEC).
- **Watchlist** (rotation/stacked): pick any number of coins.
- **Source**: filtered to sources that list the chosen coin (defaults to Binance). In multi-coin modes, the preferred source is applied per coin with auto-fallback if a coin isn't listed there.
- **WebSocket**: live updates when supported.
- **Currency**: USD/EUR/GBP/JPY/BTC/ETH (display formatting only).
- **Decimal places**, **24h change**, **coin badge**, **price text**, **background**.
- **Refresh interval** (REST mode only).
- **Click action**: refresh price or open market website.

## Source coverage

| Source    | REST | WebSocket | Coins                     |
|-----------|------|-----------|---------------------------|
| Binance   | ✅   | ✅         | All 50                    |
| Coingecko | ✅   | ❌         | All 50                    |
| Bitfinex  | ✅   | ✅         | Most majors and L2s       |
| Kraken    | ✅   | ❌         | Most majors and L2s       |
| Coinbase  | ✅   | ❌         | Majors plus broad altcoin |

## Reliability

- **Unbounded WebSocket reconnects** with capped exponential backoff (1s → 60s) plus jitter.
- **Resume from sleep**: subscribed to `org.freedesktop.login1.Manager.PrepareForSleep` via DBus. Triggers an immediate WS reconnect + REST fetch on wake.
- **Network state changes**: subscribed to `org.freedesktop.NetworkManager.StateChanged`. Same trigger path.
- **Wall-clock drift watchdog** (30s tick) as a safety net if DBus signals are unavailable.
- **REST polling** runs whenever WS isn't connected; stops automatically once WS is live again.
- All failures are silent — only the small connection dot reflects state.

## Project layout

```
package/
├── metadata.json
└── contents/
    ├── code/
    │   └── PriceProvider.js          # Coin registry + REST providers
    ├── config/
    │   ├── config.qml
    │   └── main.xml
    └── ui/
        ├── main.qml                   # Widget, state machine, DBus listener
        ├── WebSocketProvider.qml      # Provider-agnostic WS client
        └── config/
            └── configGeneral.qml
```

## Development

```bash
make run             # plasmoidviewer
make run-windowed    # standalone window
make run-panel       # panel-simulated
make lint            # qml syntax check
make reload          # install-user + restart plasmashell (iteration loop)
make zip             # build distributable .plasmoid
```

See [TESTING.md](TESTING.md) for the safe testing protocol.

## Migration from 2.x (Zcash-only)

Configuration is preserved across upgrade. The default coin is `ZEC` and default source `Binance`, so existing setups continue to behave the same. To track a different coin, just open the widget settings and pick from the new **Coin** dropdown.

The bundled `zcash.png` was removed in 3.x — the widget renders a themed ticker badge instead, so any cached references to the image are no longer needed.

## Troubleshooting

- **Widget shows `…` indefinitely** — the chosen coin/source pair may not be supported, or the network is offline. Try Binance + ZEC to verify the install works, then narrow from there.
- **Live indicator stays red** — WebSocket is being blocked (firewall, captive portal). The widget falls back to REST polling automatically; price still updates.
- **No event-driven recovery on resume** — `dbus-monitor` is missing. Install it (`sudo pacman -S dbus` / `apt install dbus`). The wall-clock watchdog still covers wake events at 30s granularity.

## License

GPL-3.0 — see [LICENSE](LICENSE).
