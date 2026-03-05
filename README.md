# Zcash Price Tracker Plasma 6 Applet

A sleek and lightweight KDE Plasma 6 widget to monitor Zcash (ZEC) price in real-time.

![Version](https://img.shields.io/badge/version-2.0.0-blue)
![Plasma](https://img.shields.io/badge/Plasma-6.0+-1d99f3)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

## Features

- **Real-time Price Updates**: WebSocket support for live price streaming (Binance & Bitfinex)
- **Multiple Data Sources**: Choose from Binance, Coingecko, or Bitfinex
- **24h Price Change**: Display percentage change with color indicators
- **Customizable Display**: Toggle icon, text, decimals, and background
- **Fallback Polling**: Automatic fallback to REST API polling when WebSocket unavailable
- **Error Resilience**: Robust error handling with user-friendly messages
- **Auto-Reconnection**: WebSocket automatically reconnects on connection loss
- **Exponential Backoff**: Reduces API load during connection issues
- **Health Monitoring**: Detects stale data and auto-refreshes
- **Data Validation**: Sanity checks prevent displaying invalid prices
- **Panel & Desktop**: Works seamlessly in both panel and desktop modes

## Requirements

- KDE Plasma 6.0 or higher
- Qt 6.0 or higher
- KDE Frameworks 6.0 or higher

## Testing (Safe Method)

**⚠️ Never test directly on your main panel!**

### Quick Validation
```bash
./validate.sh  # Check code before testing
```

### Isolated Testing (Safe)
```bash
# Test in isolated window (won't affect desktop)
plasmoidviewer --applet ./package/ --standalone

# Test panel mode
plasmoidviewer --applet ./package/ --location top
```

### Full Testing Protocol
See [TESTING.md](TESTING.md) for complete safe testing procedures.

## Installation

### From Source

```bash
git clone https://github.com/cpte-org/plasma-applet-zcash-price.git
cd plasma-applet-zcash-price
make install-user
```

**Note**: Only install after successful isolated testing!

To install system-wide (requires root):
```bash
sudo make install
```

### Manual Installation

1. Download the latest `zcash-price-2.0.0.plasmoid` from releases
2. Right-click on your desktop → "Add Widgets"
3. Click "Get New Widgets" → "Install Widget From Local File"
4. Select the downloaded `.plasmoid` file

## Usage

After installation, add the widget to your panel or desktop:

1. Right-click on the panel or desktop
2. Select "Add Widgets..."
3. Search for "Zcash Price"
4. Drag it to your desired location

### Configuration

Right-click the widget and select "Configure Zcash Price..." to customize:

- **Data Source**: Select your preferred price provider
- **WebSocket**: Enable real-time streaming (if supported by source)
- **Currency**: Display price in USD, EUR, GBP, JPY, BTC, or ETH
- **Display Options**: Toggle icon, text, decimals, and price change
- **Refresh Interval**: Set polling frequency (for non-WebSocket mode)
- **Interaction**: Choose click action (refresh or open website)

## Supported Data Sources

| Source | REST API | WebSocket | 24h Change |
|--------|----------|-----------|------------|
| Binance | ✅ | ✅ | ✅ |
| Coingecko | ✅ | ❌ | ✅ |
| Bitfinex | ✅ | ✅ | ✅ |

### WebSocket Support

When WebSocket is enabled and supported by the selected source:
- Prices update in real-time (no polling delay)
- Connection status shown with colored indicator
- Auto-reconnection with exponential backoff
- Falls back to polling if WebSocket fails

## Development

### Testing Locally

```bash
# Run in plasmoidviewer
make run

# Run in standalone window
make run-windowed

# Run simulating panel
make run-panel
```

### Project Structure

```
package/
├── metadata.json           # Plasma 6 metadata
├── contents/
│   ├── code/
│   │   └── PriceProvider.js    # Price fetching with WebSocket support
│   ├── config/
│   │   ├── config.qml          # Config categories
│   │   └── main.xml            # Configuration schema
│   ├── ui/
│   │   ├── main.qml            # Main widget UI
│   │   └── config/
│   │       └── configGeneral.qml   # Settings UI
│   └── images/
│       └── zcash.png           # Zcash logo
```

### Building Package

```bash
make zip
```

This creates `zcash-price-2.0.0.plasmoid` for distribution.

## Troubleshooting

### Widget not appearing

Ensure you're running Plasma 6.0 or higher:
```bash
plasmashell --version
```

### WebSocket connection issues

- Check your firewall settings
- Some networks may block WebSocket connections
- The widget will automatically fall back to polling

### Rate limiting

- **Coingecko**: Has strict rate limits (10-30 calls/minute on free tier)
- **Binance**: More generous limits (~1200 calls/minute)
- **Bitfinex**: Reasonable limits
- If you see rate limit errors, the widget will automatically reduce update frequency

### WebSocket connection issues

- Check your firewall settings (ports 9443 for Binance, 443 for Bitfinex)
- Some corporate networks block WebSocket connections
- The widget automatically falls back to polling mode

## Migration from Plasma 5

This version (2.0.0+) is a complete rewrite for Plasma 6. If upgrading from v1.x:

1. Remove the old widget: `kpackagetool5 --remove org.kde.plasma.zcashprice`
2. Install the new version: `make install-user`
3. Reconfigure your settings (configuration is not preserved)

## License

This project is licensed under GPL-3.0 - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Zcash logo used under fair use
- Thanks to the KDE Plasma team for the excellent widget framework
- Price data provided by Binance, Coingecko, and Bitfinex APIs
