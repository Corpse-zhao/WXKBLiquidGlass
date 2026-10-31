TARGET := iphone:clang:16.5:14.0
ARCHS := arm64 arm64e

# 设备是 roothide 越狱（iOS 16.6 / arm64e）
# rootless 打出来的 Architecture 是 iphoneos-arm64，roothide 的 Sileo 会直接拒装；
# 必须用 roothide scheme（产物后缀 iphoneos-arm64e，载荷路径不带 /var/jb）
THEOS_PACKAGE_SCHEME := roothide

INSTALL_TARGET_PROCESSES := WeChat

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := WXKBLiquidGlass
WXKBLiquidGlass_FILES := Tweak.xm
WXKBLiquidGlass_CFLAGS := -fobjc-arc -Wno-deprecated-declarations
WXKBLiquidGlass_FRAMEWORKS := UIKit
WXKBLiquidGlass_EXTRA_FRAMEWORKS :=
WXKBLiquidGlass_LIBRARIES :=
WXKBLiquidGlass_LOGOSFLAGS :=

include $(THEOS_MAKE_PATH)/tweak.mk
