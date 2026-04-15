import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let litra = Litra()
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var isOn = false
    private var brightness = 100
    private var temperature = 4500

    private var toggleItem: NSMenuItem!
    private var brightnessLabel: NSMenuItem!
    private var brightnessSlider: NSSlider!
    private var temperatureLabel: NSMenuItem!
    private var temperatureSlider: NSSlider!
    private var launchAtLoginItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

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
        brightnessLabel.isEnabled = false
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
        temperatureLabel.isEnabled = false
        menu.addItem(temperatureLabel)
        temperatureSlider = makeSlider(
            min: Double(Litra.temperatureMin),
            max: Double(Litra.temperatureMax),
            value: Double(temperature),
            action: #selector(temperatureChanged)
        )
        menu.addItem(wrap(temperatureSlider))

        menu.addItem(.separator())

        launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        refreshLaunchAtLoginState()

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

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

    private func makeSlider(min: Double, max: Double, value: Double, action: Selector) -> NSSlider {
        let slider = NSSlider(value: value, minValue: min, maxValue: max, target: self, action: action)
        slider.isContinuous = true
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

    @objc private func toggle() {
        do {
            if isOn { try litra.turnOff() } else { try litra.turnOn() }
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
        do { try litra.setBrightness(brightness) } catch { presentError(error) }
    }

    @objc private func temperatureChanged(_ sender: NSSlider) {
        temperature = Int((sender.doubleValue / 100.0).rounded()) * 100
        temperatureLabel.title = "Temperature: \(temperature) K"
        do { try litra.setTemperature(temperature) } catch { presentError(error) }
    }

    private func presentError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Litra Glow"
        alert.informativeText = "\(error)"
        alert.alertStyle = .warning
        alert.runModal()
    }
}
