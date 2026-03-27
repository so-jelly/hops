APP_DIR    = $(HOME)/Applications/hops.app
MACOS_DIR  = $(APP_DIR)/Contents/MacOS
LSREGISTER = /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister

.PHONY: build test install clean

build:
	swift build -c release
	mkdir -p $(MACOS_DIR)
	cp .build/release/hops $(MACOS_DIR)/

test:
	swift test

install: build
	cp Info.plist $(APP_DIR)/Contents/
	$(LSREGISTER) -f $(APP_DIR)

clean:
	swift package clean
	rm -rf $(APP_DIR)
