# Crypto Price Applet - Makefile for KDE Plasma 6

.PHONY: install install-user uninstall uninstall-user run test zip clean restart-plasma reload

# Default target
all: install-user

# Install for current user
install-user:
	kpackagetool6 --type Plasma/Applet --install ./package/ || kpackagetool6 --type Plasma/Applet --upgrade ./package/

# Install system-wide (requires root)
install:
	sudo kpackagetool6 --global --type Plasma/Applet --install ./package/ || sudo kpackagetool6 --global --type Plasma/Applet --upgrade ./package/

# Uninstall for current user
uninstall-user:
	kpackagetool6 --type Plasma/Applet --remove org.kde.plasma.zcashprice

# Uninstall system-wide
uninstall:
	sudo kpackagetool6 --global --type Plasma/Applet --remove org.kde.plasma.zcashprice

# Run in plasmoidviewer for testing
run:
	plasmoidviewer --applet ./package/

# Run in a standalone window for testing
run-windowed:
	plasmoidviewer --applet ./package/ --standalone

# Test in a panel-like environment
run-panel:
	plasmoidviewer --applet ./package/ --location top

# Check QML syntax and common issues
lint:
	@echo "Checking QML files for syntax errors..."
	@for file in package/contents/ui/*.qml package/contents/ui/config/*.qml; do \
		echo "Checking $$file..."; \
		qml6 $$file --quit 2>&1 | head -5 || true; \
	done

# Restart plasmashell (picks up upgraded applet without logging out)
restart-plasma:
	-kquitapp6 plasmashell 2>/dev/null || killall plasmashell 2>/dev/null
	@sleep 1
	@kstart plasmashell >/dev/null 2>&1 &
	@echo "plasmashell restarted"

# Upgrade install + restart plasma in one shot
reload: install-user restart-plasma

# Create distributable package
zip:
	zip -r crypto-price-3.4.0.plasmoid ./package/

# Clean build artifacts
clean:
	rm -f zcash-price-*.plasmoid

# Show help
help:
	@echo "Crypto Price Applet - Makefile targets:"
	@echo ""
	@echo "  install-user    Install for current user (default)"
	@echo "  install         Install system-wide (requires sudo)"
	@echo "  uninstall-user  Remove user installation"
	@echo "  uninstall       Remove system-wide installation"
	@echo "  run             Run in plasmoidviewer"
	@echo "  run-windowed    Run in standalone window"
	@echo "  run-panel       Run simulating panel environment"
	@echo "  lint            Check QML files for syntax issues"
	@echo "  restart-plasma  Kill and restart plasmashell"
	@echo "  reload          install-user + restart-plasma"
	@echo "  zip             Create distributable .plasmoid file"
	@echo "  clean           Remove build artifacts"
	@echo "  help            Show this help message"
