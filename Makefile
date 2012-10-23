ARCHS = armv7
TARGET = iphone:latest:5.0
include theos/makefiles/common.mk

TWEAK_NAME = SwitcherCleaner
SwitcherCleaner_FILES = Tweak.xm
SwitcherCleaner_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
