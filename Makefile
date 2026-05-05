# Crypto Price Applet - Makefile for KDE Plasma 6

.PHONY: install install-user uninstall uninstall-user run test zip clean

# Default target
all: install-user

# Install for current user
install-user:
	kpackagetool6 --install ./package/ || kpackagetool6 --upgrade ./package/

# Install system-wide (requires root)
install:
	sudo kpackagetool6 --global --install ./package/ || sudo kpackagetool6 --global --upgrade ./package/

# Uninstall for current user
uninstall-user:
	kpackagetool6 --remove org.kde.plasma.zcashprice

# Uninstall system-wide
uninstall:
	sudo kpackagetool6 --global --remove org.kde.plasma.zcashprice

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

# Create distributable package
zip:
	zip -r crypto-price-3.2.0.plasmoid ./package/

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
	@echo "  zip             Create distributable .plasmoid file"
	@echo "  clean           Remove build artifacts"
	@echo "  help            Show this help message"
