import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let litra = Litra()
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var isOn = false
    private var brightness = 100
    private var temperature = 4500
    private var target: LitraTarget = .all

    private var toggleItem: NSMenuItem!
    private var brightnessLabel: NSMenuItem!
    private var brightnessSlider: NSSlider!
    private var temperatureLabel: NSMenuItem!
    private var temperatureSlider: NSSlider!
    private var launchAtLoginItem: NSMenuItem!
    private var lightItem: NSMenuItem!
    private var lightSubmenu: NSMenu!
    private var lightSeparator: NSMenuItem!

    private let targetDefaultsKey = "selectedLightSerial"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        target = loadSavedTarget()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        toggleItem = NSMenuItem(title: "Turn On", action: #selector(toggle), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        brightnessLabel = NSMenuItem(title: "Brightness: \(brightness)", action: nil, keyEquivalent: "")
        menu.addItem(brightnessLabel)
        brightnessSlider = makeSlider(
            min: Double(Litra.brightnessMin),
            max: Double(Litra.brightnessMax),
            value: Double(brightness),
            action: #selector(brightnessChanged)
        )
        menu.addItem(wrap(brightnessSlider))

        menu.addItem(.separator())

        temperatureLabel = NSMenuItem(title: "Temperature: \(temperature) K", action: nil, keyEquivalent: "")
        menu.addItem(temperatureLabel)
        temperatureSlider = makeSlider(
            min: Double(Litra.temperatureMin),
            max: Double(Litra.temperatureMax),
            value: Double(temperature),
            action: #selector(temperatureChanged)
        )
        menu.addItem(wrap(temperatureSlider))

        lightSeparator = .separator()
        menu.addItem(lightSeparator)
        lightSubmenu = NSMenu()
        lightItem = NSMenuItem(title: "Light", action: nil, keyEquivalent: "")
        lightItem.submenu = lightSubmenu
        menu.addItem(lightItem)

        menu.addItem(.separator())
        launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        refreshLaunchAtLoginState()

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        litra.onDevicesChanged = { [weak self] in self?.rebuildLightSubmenu() }
        rebuildLightSubmenu()
    }

    // MARK: - Light selection

    private func loadSavedTarget() -> LitraTarget {
        if let serial = UserDefaults.standard.string(forKey: targetDefaultsKey), !serial.isEmpty {
            return .serial(serial)
        }
        return .all
    }

    private func saveTarget() {
        switch target {
        case .all:
            UserDefaults.standard.removeObject(forKey: targetDefaultsKey)
        case .serial(let s):
            UserDefaults.standard.set(s, forKey: targetDefaultsKey)
        }
    }

    private func rebuildLightSubmenu() {
        let devices = litra.devices
        lightSubmenu.removeAllItems()

        let allItem = NSMenuItem(title: "All Lights", action: #selector(selectAllLights), keyEquivalent: "")
        allItem.target = self
        allItem.state = (target == .all) ? .on : .off
        lightSubmenu.addItem(allItem)

        if !devices.isEmpty {
            lightSubmenu.addItem(.separator())
            for device in devices {
                let item = NSMenuItem(title: device.displayName, action: #selector(selectLight(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = device.serial
                item.state = (target == .serial(device.serial)) ? .on : .off
                lightSubmenu.addItem(item)
            }
        }

        // Hide the whole "Light" submenu when there's at most one device —
        // no meaningful choice to make.
        let shouldShow = devices.count > 1
        lightItem.isHidden = !shouldShow
        lightSeparator.isHidden = !shouldShow
    }

    @objc private func selectAllLights() {
        target = .all
        saveTarget()
        rebuildLightSubmenu()
    }

    @objc private func selectLight(_ sender: NSMenuItem) {
        guard let serial = sender.representedObject as? String else { return }
        target = .serial(serial)
        saveTarget()
        rebuildLightSubmenu()
    }

    // MARK: - Launch at Login

    private func refreshLaunchAtLoginState() {
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            refreshLaunchAtLoginState()
        } catch {
            presentError(error)
        }
    }

    // MARK: - Click handling

    @objc private func handleClick() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            toggle()
        } else {
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        }
    }

    // MARK: - UI helpers

    private func makeSlider(min: Double, max: Double, value: Double, action: Selector) -> NSSlider {
        let slider = NSSlider(value: value, minValue: min, maxValue: max, target: self, action: action)
        slider.isContinuous = true
        slider.controlSize = .small
        slider.trackFillColor = NSColor.controlAccentColor
        slider.frame = NSRect(x: 20, y: 0, width: 200, height: 22)
        return slider
    }

    private func wrap(_ view: NSView) -> NSMenuItem {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        view.frame.origin.x = 20
        container.addSubview(view)
        let item = NSMenuItem()
        item.view = container
        return item
    }

    private func updateStatusIcon() {
        guard let button = statusItem.button else { return }
        let name = isOn ? "lightbulb.fill" : "lightbulb"
        if let image = NSImage(systemSymbolName: name, accessibilityDescription: "Litra Glow") {
            image.isTemplate = true
            button.image = image
            button.title = ""
        } else {
            button.image = nil
            button.title = isOn ? "💡" : "○"
        }
    }

    private func refreshToggleTitle() {
        toggleItem.title = isOn ? "Turn Off" : "Turn On"
    }

    // MARK: - Actions

    @objc private func toggle() {
        do {
            if isOn { try litra.turnOff(target) } else { try litra.turnOn(target) }
            isOn.toggle()
            updateStatusIcon()
            refreshToggleTitle()
        } catch {
            presentError(error)
        }
    }

    @objc private func brightnessChanged(_ sender: NSSlider) {
        brightness = Int(sender.doubleValue.rounded())
        brightnessLabel.title = "Brightness: \(brightness)"
        do { try litra.setBrightness(brightness, target) } catch { presentError(error) }
    }

    @objc private func temperatureChanged(_ sender: NSSlider) {
        temperature = Int((sender.doubleValue / 100.0).rounded()) * 100
        temperatureLabel.title = "Temperature: \(temperature) K"
        do { try litra.setTemperature(temperature, target) } catch { presentError(error) }
    }

    private func presentError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Litra Glow"
        alert.informativeText = "\(error)"
        alert.alertStyle = .warning
        alert.runModal()
    }
}
