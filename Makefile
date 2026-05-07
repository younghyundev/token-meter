APP_NAME = TokenMeter
BUNDLE_ID = com.tokenmeter.app
BUILD_DIR = .build/release
APP_DIR = $(BUILD_DIR)/$(APP_NAME).app

.PHONY: build clean install uninstall

build:
	swift build -c release
	mkdir -p "$(APP_DIR)/Contents/MacOS"
	mkdir -p "$(APP_DIR)/Contents/Resources"
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(APP_DIR)/Contents/MacOS/$(APP_NAME)"
	cp Resources/Info.plist "$(APP_DIR)/Contents/Info.plist"
	cp Resources/tokenmeter-icon-16.png "$(APP_DIR)/Contents/Resources/"
	cp Resources/tokenmeter-icon-32.png "$(APP_DIR)/Contents/Resources/"
	cp Resources/menubar-icon-16.png "$(APP_DIR)/Contents/Resources/"
	cp Resources/menubar-icon-32.png "$(APP_DIR)/Contents/Resources/"
	cp Resources/AppIcon.icns "$(APP_DIR)/Contents/Resources/"
	@echo "✓ Built $(APP_DIR)"

clean:
	swift package clean
	rm -rf .build

install: build
	cp -r "$(APP_DIR)" /Applications/
	@echo "✓ Installed to /Applications/$(APP_NAME).app"

uninstall:
	rm -rf "/Applications/$(APP_NAME).app"
	@echo "✓ Uninstalled $(APP_NAME)"

run: build
	-pkill -x "$(APP_NAME)"
	@sleep 1
	open "$(APP_DIR)"
