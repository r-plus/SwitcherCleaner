export GO_EASY_ON_ME=1
include theos/makefiles/common.mk

TWEAK_NAME = SwitcherCleaner
SwitcherCleaner_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk
