# Zcash Price Applet v2.0.0 - Changes Summary

## Major Changes (Plasma 5 → 6 Migration)

### 1. Metadata Format
- **Changed**: `metadata.desktop` → `metadata.json`
- **Added**: `X-Plasma-API-Minimum-Version: "6.0"`

### 2. Root Element
- **Changed**: `Item` → `PlasmoidItem`
- **Impact**: Required for Plasma 6 compatibility

### 3. Import Statements
- **Removed**: Version numbers from all imports
- **Old**: `import org.kde.plasma.core 2.0 as PlasmaCore`
- **New**: `import org.kde.plasma.core as PlasmaCore`

### 4. Configuration UI
- **Changed**: `Kirigami.FormLayout` → `KCM.SimpleKCM` with `Kirigami.FormLayout`
- **Old**: Direct property assignments
- **New**: `cfg_` prefixed property binding

### 5. Attached Properties
- **Fixed**: `backgroundHints` → `Plasmoid.backgroundHints`
- **Note**: Must use `Plasmoid.` prefix for attached properties

## New Features

### WebSocket Support
- **Binance**: Real-time streaming via WebSocket
- **Bitfinex**: Real-time streaming via WebSocket
- **Coingecko**: REST only (no WebSocket available)
- **Auto-reconnect**: With exponential backoff
- **Fallback**: Automatic switch to polling on WebSocket failure

### Enhanced Display
- **24h Price Change**: Shows percentage with color coding (green/red)
- **Connection Indicator**: Green dot when WebSocket is live
- **Error Display**: User-friendly error messages in tooltip and popup

### Stability Improvements
- **Exponential Backoff**: Reduces API load during connection issues
- **Health Check Timer**: Detects stale data and auto-refreshes
- **Data Validation**: Sanity checks prevent displaying invalid prices
- **Error Recovery**: Automatic reset after successful requests

### Configuration Options (New)
- `useWebSocket`: Toggle WebSocket for real-time updates
- `showPriceChange`: Display 24h price change percentage

## Code Quality

### Error Handling
- **JSON Parsing**: All `JSON.parse()` wrapped in try-catch
- **HTML Detection**: Rejects HTML error pages
- **Price Validation**: Sanity check ($1-$100,000 range)
- **Network Timeouts**: 15-second timeout on all requests

### Defensive Programming
- **Null Checks**: All property access guarded
- **Type Validation**: Required fields verified before use
- **State Tracking**: Consecutive errors tracked with backoff

## File Structure Changes

```
Before (v1.x):
├── metadata.desktop
└── contents/
    ├── code/
    │   └── zcash.js (122 lines)
    └── ui/
        └── main.qml (161 lines)

After (v2.0):
├── metadata.json
└── contents/
    ├── code/
    │   └── PriceProvider.js (601 lines, WebSocket support)
    └── ui/
        └── main.qml (498 lines, hardened)
```

## API Sources Tested

| Source | REST | WebSocket | Status |
|--------|------|-----------|--------|
| Binance | ✓ | ✓ | Recommended |
| Coingecko | ✓ | ✗ | Rate limited |
| Bitfinex | ✓ | ✓ | Good alternative |

## Breaking Changes

1. **Configuration not preserved** - Users must reconfigure after upgrade
2. **Plasma 5 no longer supported** - Requires Plasma 6.0+
3. **Default source changed** - Now defaults to Binance (was Cryptonator, removed)

## Testing

### Validation
```bash
./validate.sh  # Pre-flight check
```

### Safe Testing
```bash
plasmoidviewer --applet ./package/ --standalone
```

See [TESTING.md](TESTING.md) for complete testing protocol.

## Migration for Users

### From v1.x:
1. Remove old version: `kpackagetool5 --remove org.kde.plasma.zcashprice`
2. Install new version: `make install-user`
3. Reconfigure settings (not preserved)

### Clean Install:
```bash
make install-user
```

## Known Limitations

1. **Coingecko Rate Limits**: Free tier allows ~30 calls/minute
2. **WebSocket Firewalls**: Some networks block WebSocket connections
3. **No Multi-Currency Conversion**: Only USD display supported currently

## Performance

- **Memory Usage**: ~10-15 MB (typical)
- **CPU Usage**: <1% (idle), brief spikes during updates
- **Network**: 
  - Polling: 1 request per 5 minutes (default)
  - WebSocket: Persistent connection, ~1 msg/sec
