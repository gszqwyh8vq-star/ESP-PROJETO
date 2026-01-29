export THEOS=/var/mobile/theos

ARCHS = arm64 
DEBUG = 0
FINALPACKAGE = 1
FOR_RELEASE = 1

include $(THEOS)/makefiles/common.mk

FRAMEWORK_NAME = FreefireESP_Satooios

$(FRAMEWORK_NAME)_FRAMEWORKS = UIKit Foundation Security QuartzCore CoreGraphics CoreText AVFoundation Accelerate GLKit SystemConfiguration GameController IOKit

$(FRAMEWORK_NAME)_EXTRA_FRAMEWORKS = 
$(FRAMEWORK_NAME)_CCFLAGS = -std=c++11 -fno-rtti -fno-exceptions -DNDEBUG
$(FRAMEWORK_NAME)_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-value
$(FRAMEWORK_NAME)_FILES = satooios.mm
$(FRAMEWORK_NAME)_LIBRARIES = substrate

$(FRAMEWORK_NAME)_LIBRARY_FLAGS = -current_version 1.0 -compatibility_version 1.0

include $(THEOS_MAKE_PATH)/framework.mk