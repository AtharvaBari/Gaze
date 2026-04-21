import SwiftUI
import ServiceManagement
#if canImport(Sparkle)
import Sparkle
#endif

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case timer = "Timer"
    case interaction = "Interaction"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .timer: return "timer"
        case .interaction: return "eye"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    @State private var selectedTab: SettingsTab = .general
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Sidebar Header Branding
                HStack(spacing: 12) {
                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gaze").font(.headline)
                        Text("v1.0.1").font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                
                Divider()
                
                List(SettingsTab.allCases, selection: $selectedTab) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                }
                .listStyle(.sidebar)
            }
            .navigationTitle("Settings")
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch selectedTab {
                    case .general:
                        GeneralSettings(store: store, launchAtLogin: $launchAtLogin)
                    case .timer:
                        TimerSettings(store: store)
                    case .interaction:
                        InteractionSettings(store: store)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(selectedTab.rawValue)
        }
        .frame(minWidth: 550, minHeight: 400)
    }
}

struct GeneralSettings: View {
    @ObservedObject var store: SettingsStore
    @Binding var launchAtLogin: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingSection(title: "App Startup") {
                Toggle(isOn: $launchAtLogin) {
                    VStack(alignment: .leading) {
                        Text("Launch at Login")
                        Text("Automatically start Gaze when you sign in.").font(.caption).foregroundColor(.secondary)
                    }
                }
                .onChange(of: launchAtLogin) { newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        print("Failed to update launch at login: \(error)")
                    }
                }
            }
            
            SettingSection(title: "Updates & Feedback") {
                Toggle(isOn: $store.autoCheckUpdates) {
                    VStack(alignment: .leading) {
                        Text("Check for Updates Automatically")
                        Text("Keep Gaze up to date with the latest features.").font(.caption).foregroundColor(.secondary)
                    }
                }
                
                Button("Check for Updates Now") {
                    #if canImport(Sparkle)
                    SparkleManager.shared.updater.checkForUpdates(nil)
                    #else
                    NSSound.beep()
                    #endif
                }
                .buttonStyle(.bordered)
            }
            
            SettingSection(title: "Effects") {
                Toggle(isOn: $store.enableSounds) {
                    VStack(alignment: .leading) {
                        Text("UI Micro-sounds")
                        Text("Play subtle sound effects during interactions.").font(.caption).foregroundColor(.secondary)
                    }
                }
                
                Toggle(isOn: $store.hideOnInactivity) {
                    VStack(alignment: .leading) {
                        Text("Hide on Inactivity")
                        Text("Automatically hide the eye when not in use.").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct TimerSettings: View {
    @ObservedObject var store: SettingsStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingSection(title: "Pomodoro Configuration") {
                VStack(alignment: .leading, spacing: 16) {
                    CustomStepper(value: $store.workDurationMinutes, range: 1...60, label: "Work Session", unit: "min")
                    CustomStepper(value: $store.breakDurationMinutes, range: 1...30, label: "Break Session", unit: "min")
                    CustomStepper(value: $store.maxCycles, range: 1...10, label: "Pomodoro Loops", unit: "cycles")
                }
            }
        }
    }
}

struct InteractionSettings: View {
    @ObservedObject var store: SettingsStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingSection(title: "Behavior") {
                Toggle(isOn: $store.trackCursor) {
                    VStack(alignment: .leading) {
                        Text("Track Cursor")
                        Text("The Eye will follow your mouse movement.").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            
            SettingSection(title: "Periodic Peek") {
                Toggle(isOn: $store.isPeriodicPeekEnabled) {
                    VStack(alignment: .leading) {
                        Text("Enabled")
                        Text("Briefly show the eye at regular intervals.").font(.caption).foregroundColor(.secondary)
                    }
                }
                
                if store.isPeriodicPeekEnabled {
                    CustomStepper(value: $store.peekIntervalMinutes, range: 1...60, label: "Peek Every", unit: "min")
                }
            }
        }
    }
}

// MARK: - Components

struct SettingSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct CustomStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let label: String
    let unit: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            HStack(spacing: 12) {
                Text("\(value) \(unit)")
                    .foregroundColor(.secondary)
                Stepper("", value: $value, in: range)
                    .labelsHidden()
            }
        }
    }
}
