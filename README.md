# Litra Glow Controller

A tiny macOS menu bar app to control the [Logitech Litra Glow](https://www.logitech.com/en-us/products/lighting/litra-glow.html) USB light: on/off, brightness, and color temperature. No Logitech G HUB required.

## Why

The Logitech Litra Glow is a nice little webcam light, but the only official way to control it is through Logitech G HUB — a 500+ MB app that runs a background service, launches at login, nags for updates, and does far more than anyone needs just to toggle a USB lamp. I wanted a button in my menu bar. This is that button.

## Features

- **Menu bar icon** — click to open controls, right-click to toggle on/off instantly.
- **On/off toggle**
- **Brightness slider** (20–250 cd/m²)
- **Color temperature slider** (2700–6500 K)
- **Launch at login** (optional, toggle inside the menu)

## Install

### Option A: Download the DMG

1. Grab the latest `LitraGlowController-x.y.z.dmg` from the [Releases](https://github.com/manuelbieh/litra-glow-controller/releases) page.
2. Open the DMG and drag **Litra Glow Controller.app** into **Applications**.
3. First launch: because the app is ad-hoc signed (no paid Apple Developer certificate), macOS Gatekeeper will refuse to open it normally. Right-click the app in Finder → **Open** → confirm. You only need to do this once.
4. Plug in your Litra Glow. A lightbulb icon appears in the menu bar.

### Option B: Build from source

Requires macOS 13+ and Xcode command-line tools.

```sh
git clone git@github.com:manuelbieh/litra-glow-controller.git
cd litra-glow-controller
./scripts/build.sh 0.1.0
open dist/LitraGlowController-0.1.0.dmg
```

## Usage

- **Left-click** the menu bar icon → opens menu with sliders and options.
- **Right-click** the menu bar icon → toggles the light on/off directly.
- **Launch at Login** → toggle inside the menu; uses the modern `SMAppService` API (no LaunchAgents plist to clean up).

A bonus command-line tool `litra.py` is also included for scripting:

```sh
./litra.py on
./litra.py off
./litra.py bright 150
./litra.py temp 5000
```

## Disclaimer

This is a personal hobby project. I am **not affiliated with, endorsed by, or sponsored by Logitech** in any way. "Logitech", "Litra", and "Litra Glow" are trademarks of Logitech. This project communicates with the device over USB HID using a protocol that was reverse-engineered by the open-source community and is used here at your own risk.

## License

[MIT](./LICENSE).
