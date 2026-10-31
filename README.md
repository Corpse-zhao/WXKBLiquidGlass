# WeChat 输入法键盘 Liquid Glass（实验版 v1.0.0）

注入目标扩展：`com.tencent.wetype.keyboard`（微信输入法键盘扩展）
设备环境：**roothide 越狱 / iOS 16.6 / arm64e**

## 它做什么

Hook `UIInputView` 与 `UIInputSetContainerView` 的 `didMoveToWindow` / `layoutSubviews`，
在键盘容器最底层插入一层 `UIVisualEffectView`（`UIBlurEffectStyleSystemThinMaterial`，16pt 圆角）。
玻璃层 `userInteractionEnabled = NO`，按键与触摸派发完全不受影响。

## 构建（GitHub Actions 已配好）

- `.github/workflows/build.yml`：macOS runner + `roothide/theos` + `iPhoneOS16.5.sdk`
- 打包参数：`gmake package THEOS_PACKAGE_SCHEME=roothide FINALPACKAGE=1`
- 产物：`packages/com.zhao.wxkb-liquid-glass_<ver>_iphoneos-arm64e.deb`
- CI 内含 Preflight 静态自检 + deb 结构校验（Architecture / 路径前缀 / 双切片）

## 安装

Sileo / Filza 直接打开 deb 安装；或命令行：

```sh
dpkg -i com.zhao.wxkb-liquid-glass_1.0.0_iphoneos-arm64e.deb
killall -9 WeChat     # 必须让输入法扩展进程重启，否则不会注入
```

装完在微信里调起输入法键盘即可。日志确认注入：`log stream | grep WXKBLiquidGlass`。

## 已知限制

- 系统键盘自带的背板（`UIKBInputBackdropView` / `_UIVisualEffectBackdropView`）在层级上通常
  **盖在这层玻璃之上**，所以最可能的表现是「装了但看不出变化」。这是已知的实验边界，
  不是安装失败。要真正生效需再加一层「找到并适度调淡系统背板」的逻辑
  （必须真机确认层级，调错会把按键一起弄没，故本版刻意不做）。
- 没有设置面板、没有开关；不喜欢直接卸包。
- 只在微信输入法键盘扩展内生效，不影响系统键盘与其它 App。

## 目录

```
Makefile                  # TARGET iphone:clang:16.5:14.0 / ARCHS arm64+arm64e / roothide
control                   # Architecture: iphoneos-arm64e
Tweak.xm                  # 全部逻辑（2 个 %hook）
WXKBLiquidGlass.plist     # MobileSubstrate filter（Bundles = com.tencent.wetype.keyboard）
.github/workflows/build.yml
```
