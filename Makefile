TARGET := iphone:clang:16.2
INSTALL_TARGET_PROCESSES = Instagram
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SCInsta

$(TWEAK_NAME)_FILES = $(shell find src -type f \( -iname \*.x -o -iname \*.xm -o -iname \*.m \)) $(wildcard modules/JGProgressHUD/*.m)
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation CoreGraphics Photos CoreServices SystemConfiguration SafariServices Security QuartzCore
$(TWEAK_NAME)_PRIVATE_FRAMEWORKS = Preferences

LIBBOX_FRAMEWORK := $(THEOS_PROJECT_DIR)/vendor-libbox/Libbox.xcframework/ios-arm64/Libbox.framework
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -Wno-unsupported-availability-guard -Wno-unused-value -Wno-deprecated-declarations -Wno-nullability-completeness -Wno-unused-function -Wno-incompatible-pointer-types -I$(LIBBOX_FRAMEWORK)/Versions/A/Headers
$(TWEAK_NAME)_FRAMEWORKS += CoreTelephony Network
$(TWEAK_NAME)_LDFLAGS += -F$(dir $(LIBBOX_FRAMEWORK)) -framework Libbox -lresolv -lc++
$(TWEAK_NAME)_LOGOSFLAGS = --c warnings=none

CCFLAGS += -std=c++11

include $(THEOS_MAKE_PATH)/tweak.mk

# Build FLEXing for sideloading (not building in dev-mode)
ifdef SIDELOAD
	$(TWEAK_NAME)_SUBPROJECTS += modules/flexing
endif