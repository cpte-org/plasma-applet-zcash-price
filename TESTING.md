# Safe Testing Protocol for Zcash Price Applet

**⚠️ IMPORTANT**: Follow these steps in order to test safely without crashing your desktop.

## Pre-Flight Checks

### 1. Verify Plasma Version
```bash
plasmashell --version
# Should show 6.0 or higher
```

### 2. Create a Backup
```bash
# If you have the old version installed
mkdir -p ~/.local/share/plasma/plasmoids-backup
# Backup any existing installation
cp -r ~/.local/share/plasma/plasmoids/org.kde.plasma.zcashprice \
      ~/.local/share/plasma/plasmoids-backup/ 2>/dev/null || echo "No existing installation"
```

### 3. Check Available Tools
```bash
which plasmoidviewer kpackagetool6
# Both should be installed. If not:
# sudo apt install plasma-sdk  # Debian/Ubuntu
# sudo pacman -S plasma-sdk    # Arch
```

---

## Phase 1: Syntax Validation (No Risk)

### Check QML Syntax
```bash
cd /home/besudo/Git/plasma-applet-zcash-price

# Check all QML files for syntax errors
for file in package/contents/ui/*.qml package/contents/ui/config/*.qml; do
    echo "Checking: $file"
    qmllint "$file" 2>&1 | grep -E "(Error|Warning)" || echo "  ✓ OK"
done
```

### Check JSON Metadata
```bash
# Validate metadata.json
python3 -m json.tool package/metadata.json > /dev/null && echo "✓ metadata.json valid" || echo "✗ metadata.json invalid"
```

---

## Phase 2: Isolated Testing (Low Risk)

This runs the widget in its own window, completely isolated from your panel/desktop.

### Test 1: Basic Load Test
```bash
cd /home/besudo/Git/plasma-applet-zcash-price

# Run in isolated window (safe - won't affect desktop)
timeout 30 plasmoidviewer --applet ./package/ --standalone
```

**What to check:**
- [ ] Window opens without errors
- [ ] Zcash icon appears
- [ ] Price displays (may take 5-10 seconds for first API call)
- [ ] No crash after 30 seconds

### Test 2: Panel Simulation Test
```bash
# Simulate running in a panel (horizontal)
timeout 30 plasmoidviewer --applet ./package/ --location top
```

### Test 3: Configuration Dialog Test
```bash
# Open the configuration dialog
timeout 30 plasmoidviewer --applet ./package/ --standalone --config
```

---

## Phase 3: User Installation (Medium Risk)

If Phase 2 passes:

### Install for Current User Only
```bash
cd /home/besudo/Git/plasma-applet-zcash-price

# Install (not system-wide)
kpackagetool6 --install ./package/ 2>&1 || kpackagetool6 --upgrade ./package/
```

### Test in Widget Explorer (Safe)
```bash
# Open widget explorer (don't add to desktop yet)
kpackagetool6 --list | grep zcash
# Should show: org.kde.plasma.zcashprice
```

### First Desktop Test (User Plasmoid)
```bash
# Run the installed widget in isolated window
plasmoidviewer --applet org.kde.plasma.zcashprice --standalone
```

---

## Phase 4: Live Desktop Testing (Higher Risk)

**⚠️ Save all work before proceeding**

### Step 1: Prepare for Crash Recovery
```bash
# Open a terminal and keep it ready
# If desktop crashes, run from TTY (Ctrl+Alt+F3):
# plasma-apply-lookandfeel -a org.kde.breeze.desktop
```

### Step 2: Add to Desktop (Not Panel)
1. Right-click on desktop → "Add Widgets..."
2. Search for "Zcash Price"
3. Drag to desktop (NOT to panel yet)

### Step 3: Monitor for Errors
```bash
# Watch Plasma logs in terminal
journalctl -f -n 50 --user _COMM=plasmashell
```

### Step 4: Test Features
- [ ] Price updates (wait 2-3 minutes)
- [ ] Click to refresh
- [ ] Open configuration
- [ ] Change price source
- [ ] Toggle WebSocket on/off
- [ ] Remove widget (right-click → Remove)

---

## Phase 5: Panel Testing (Highest Risk)

**⚠️ Panels are more sensitive. Test only if desktop testing passed.**

### Safe Panel Test Method
```bash
# Create a new test panel instead of using existing
# Right-click desktop → Add Panel → Empty Panel
# Drag Zcash widget to NEW panel only
```

### If Panel Crashes
1. Switch to TTY: `Ctrl+Alt+F3`
2. Login
3. Remove the applet:
   ```bash
   rm -rf ~/.local/share/plasma/plasmoids/org.kde.plasma.zcashprice
   ```
4. Restart Plasma:
   ```bash
   kquitapp6 plasmashell && sleep 2 && kstart6 plasmashell
   ```

---

## Quick Recovery Commands

### If Widget Causes Issues
```bash
# 1. Remove the widget
kpackagetool6 --remove org.kde.plasma.zcashprice

# 2. Restart Plasma (widgets will reload)
kquitapp6 plasmashell && sleep 2 && kstart6 plasmashell

# 3. If that fails, restart from TTY
# Ctrl+Alt+F3
# login
kquitapp6 plasmashell
kstart6 plasmashell
```

### Nuclear Option (Remove All Traces)
```bash
# Remove installation
rm -rf ~/.local/share/plasma/plasmoids/org.kde.plasma.zcashprice

# Clear cache
rm -rf ~/.cache/plasma*

# Restart
kquitapp6 plasmashell && sleep 2 && kstart6 plasmashell
```

---

## Expected Behavior

### First Launch
- Initial price shows "..." for 2-5 seconds
- Then shows actual price or error message

### Normal Operation
- Price updates every 5 minutes (default polling)
- WebSocket mode: updates in real-time (~1/sec for Binance)
- Green dot when WebSocket connected

### Error Handling
- Network errors show message in tooltip
- Rate limits automatically reduce update frequency
- Invalid prices are rejected (sanity check: $1-$100,000)

---

## Success Criteria

✅ **Safe to Use If:**
- Widget loads without console errors
- Price displays within 10 seconds
- Configuration dialog opens
- Can switch between Binance/Coingecko/Bitfinex
- WebSocket toggle works
- Removes cleanly without crash

❌ **Stop Testing If:**
- `plasmoidviewer` crashes
- Desktop freezes
- Panel disappears
- High CPU usage (>10% sustained)
- Memory leak (growing RAM usage)

---

## Debug Mode

For detailed troubleshooting:

```bash
# Run plasmoidviewer with debug output
QT_LOGGING_RULES="*.debug=true" plasmoidviewer --applet ./package/ --standalone 2>&1 | tee zcash-debug.log
```

Check `zcash-debug.log` for:
- QML binding errors
- JavaScript exceptions
- Network request failures
