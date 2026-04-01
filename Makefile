APP_DIR    = /Applications/hops.app
MACOS_DIR  = $(APP_DIR)/Contents/MacOS
LSREGISTER = /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
VERSION   := $(shell git describe --tags --always 2>/dev/null || echo dev)

.PHONY: build test install clean

build:
	swift build -c release
	mkdir -p $(MACOS_DIR)
	cp .build/release/hops $(MACOS_DIR)/

test:
	swift test

install: build
	sed 's/<string>1.0<\/string>/<string>$(VERSION)<\/string>/g' Info.plist > $(APP_DIR)/Contents/Info.plist
	mkdir -p $(APP_DIR)/Contents/Resources
	cp AppIcon.icns $(APP_DIR)/Contents/Resources/
	$(LSREGISTER) -f $(APP_DIR)

clean:
	swift package clean
	rm -rf $(APP_DIR)
