import SwiftUI
import AppKit

struct HardwareMetricsView: View {
    @ObservedObject private var monitoring = HardwareMonitoringState.shared
    @AppStorage("appLanguage") private var language = "system"
    @State private var cpuDetailsHovered = false
    @State private var cpuDetailsAnchor: NSView?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 16) {
                if monitoring.sample != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        metrics(title: monitoring.sample?.cpuInfo.model ?? "CPU", values: cpuValues)
                        cpuDetailsRow
                    }
                }
                if !gpuValues.isEmpty {
                    metrics(title: monitoring.sample?.gpuModel ?? "GPU", values: gpuValues)
                }
            }

            if let discharge = monitoring.sample?.batteryDischarge {
                if monitoring.sample != nil || !gpuValues.isEmpty {
                    Divider()
                        .padding(.vertical, 3)
                }
                HStack {
                    Text(L10n.text("电池放电功率"))
                    Spacer()
                    Text(String(format: "%.2f W", discharge))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var cpuDetailsRow: some View {
        Button(action: showCPUDetails) {
            HStack(spacing: 8) {
                Text(L10n.text("详细信息"))
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
            }
            .background(NativeMenuAnchor(view: $cpuDetailsAnchor))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(cpuDetailsHovered ? Color.white : Color.primary)
            .background(cpuDetailsHovered ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, -10)
        .onHover { cpuDetailsHovered = $0 }
    }

    private func showCPUDetails() {
        guard let anchor = cpuDetailsAnchor else { return }
        let menu = NSMenu()
        menu.autoenablesItems = false
        for detail in cpuDetails.isEmpty ? [L10n.text("暂无 CPU 信息")] : cpuDetails {
            let item = NSMenuItem(title: detail, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        if let sample = monitoring.sample?.cpu?.details {
            let cores = NSMenu(title: L10n.text("每核心"))
            cores.autoenablesItems = false
            for index in sample.coreFrequenciesMHz.indices {
                let item = NSMenuItem(title: coreDetail(sample, index: index), action: nil, keyEquivalent: "")
                item.isEnabled = false
                cores.addItem(item)
            }
            let coreItem = NSMenuItem(title: L10n.text("每核心"), action: nil, keyEquivalent: "")
            coreItem.submenu = cores
            menu.addItem(coreItem)
            if !sample.pStateDefinitions.isEmpty {
                let states = NSMenu(title: L10n.text("P-state 定义"))
                states.autoenablesItems = false
                for index in sample.pStateDefinitions.indices {
                    let item = NSMenuItem(title: pStateDetail(sample, index: index), action: nil, keyEquivalent: "")
                    item.isEnabled = false
                    states.addItem(item)
                }
                let stateItem = NSMenuItem(title: L10n.text("P-state 定义"), action: nil, keyEquivalent: "")
                stateItem.submenu = states
                menu.addItem(stateItem)
            }
        }
        menu.popUp(positioning: nil, at: NSPoint(x: anchor.bounds.maxX, y: anchor.bounds.maxY), in: anchor)
    }

    private var cpuDetails: [String] {
        guard let info = monitoring.sample?.cpuInfo else { return [] }
        var details: [String] = []
        if let model = info.model { details.append(L10n.pair("型号", model)) }
        if let vendor = info.vendor { details.append(L10n.pair("厂商", vendor)) }
        if let family = info.family { details.append(L10n.pair("系列", "\(family)")) }
        if let model = info.modelNumber { details.append(L10n.pair("型号编号", "\(model)")) }
        if let stepping = info.stepping { details.append(L10n.pair("步进", "\(stepping)")) }
        if let cores = info.physicalCores { details.append(L10n.pair("物理核心", "\(cores)")) }
        if let cores = info.logicalCores { details.append(L10n.pair("逻辑核心", "\(cores)")) }
        if let cache = info.l1InstructionCache { details.append(L10n.pair("L1 指令缓存", ByteCountFormatter.string(fromByteCount: Int64(cache), countStyle: .memory))) }
        if let cache = info.l1DataCache { details.append(L10n.pair("L1 数据缓存", ByteCountFormatter.string(fromByteCount: Int64(cache), countStyle: .memory))) }
        if let cache = info.l2Cache { details.append(L10n.pair("L2 缓存", ByteCountFormatter.string(fromByteCount: Int64(cache), countStyle: .memory))) }
        if let cache = info.l3Cache { details.append(L10n.pair("L3 缓存", ByteCountFormatter.string(fromByteCount: Int64(cache), countStyle: .memory))) }
        for label in ["频率", "温度", "风扇", "功耗"] {
            if let value = cpuValues[label] { details.append(L10n.pair(label, value)) }
        }
        if let sample = monitoring.sample?.cpu?.details {
            if let version = sample.driverVersion { details.append(L10n.pair("AMD 驱动版本", version)) }
            if let state = sample.pState { details.append("P-state：\(state)") }
            if let count = sample.instructionDelta { details.append(L10n.pair("指令增量", "\(count)")) }
            if let supported = sample.boostSupported {
                details.append(L10n.pair("CPU Boost 支持", L10n.text(supported ? "是" : "否")))
            }
            if let enabled = sample.boostEnabled { details.append(L10n.pair("CPU Boost", L10n.text(enabled ? "开启" : "关闭"))) }
            if let enabled = sample.powerManagement { details.append(L10n.pair("电源管理", L10n.text(enabled ? "开启" : "关闭"))) }
            if let enabled = sample.lowPowerMode { details.append(L10n.pair("低功耗模式", L10n.text(enabled ? "开启" : "关闭"))) }
            if let cores = sample.highPriorityCores { details.append(L10n.pair("高优先级核心值", "\(cores)")) }
            if let vendor = sample.boardVendor { details.append(L10n.pair("主板厂商", vendor)) }
            if let name = sample.boardName { details.append(L10n.pair("主板型号", name)) }
            if sample.cpuIdentification.count == 8 {
                let cpu = sample.cpuIdentification
                details.append(L10n.pair("AMD 驱动 CPU 系列", "\(cpu[0])"))
                details.append(L10n.pair("AMD 驱动 CPU 型号", "\(cpu[1])"))
                details.append(L10n.pair("AMD 驱动物理核心", "\(cpu[2])"))
                details.append(L10n.pair("AMD 驱动逻辑核心", "\(cpu[3])"))
                details.append(L10n.pair("AMD 驱动 L1 缓存", "\(cpu[4]) KB"))
                details.append(L10n.pair("AMD 驱动 L2 缓存", "\(cpu[5]) KB"))
                details.append(L10n.pair("AMD 驱动 L3 缓存", "\(cpu[6]) KB"))
                details.append(L10n.pair("AMD 驱动支持", L10n.text(cpu[7] != 0 ? "是" : "否")))
            }
        }
        return details
    }

    private func coreDetail(_ sample: AMDRyzenSample, index: Int) -> String {
        var detail = L10n.pair("\(L10n.text("核心")) \(index + 1)", String(format: "%.0f MHz", sample.coreFrequenciesMHz[index]))
        if index < sample.coreLoads.count, let load = sample.coreLoads[index] {
            detail += ", \(L10n.text("负载")) " + String(format: "%.0f%%", load * 100)
        }
        return detail
    }

    private func pStateDetail(_ sample: AMDRyzenSample, index: Int) -> String {
        let raw = sample.pStateDefinitions[index]
        var detail = String(format: "P%d：0x%016llX", index, raw)
        if index < sample.pStateFrequenciesMHz.count {
            detail += String(format: "，%.0f MHz", sample.pStateFrequenciesMHz[index])
        }
        return detail
    }

    private var cpuValues: [String: String] {
        var values: [String: String] = [:]
        if let sample = monitoring.sample?.cpu {
            values["频率"] = String(format: "%.2f GHz", sample.frequencyMHz / 1000)
            values["温度"] = String(format: "%.0f °C", sample.temperatureCelsius)
            values["功耗"] = String(format: "%.1f W", sample.powerWatts)
        }
        if let rpm = monitoring.sample?.fans?.cpuRPM { values["风扇"] = "\(rpm) RPM" }
        return values
    }

    private var gpuValues: [String: String] {
        var values: [String: String] = [:]
        if let frequency = monitoring.sample?.gpuStatistics?.frequencyMHz { values["频率"] = String(format: "%.0f MHz", frequency) }
        if let power = monitoring.sample?.gpuStatistics?.powerWatts { values["功耗"] = String(format: "%.1f W", power) }
        if let rpm = monitoring.sample?.fans?.gpuRPM { values["风扇"] = "\(rpm) RPM" }
        if let temperature = monitoring.sample?.gpuTemperature { values["温度"] = "\(temperature) °C" }
        return values
    }

    private func metrics(title: String, values: [String: String]) -> some View {
        let labels = ["频率", "温度", "风扇", "功耗"].filter { values[$0] != nil }
        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            ForEach(labels, id: \.self) { label in
                HStack(spacing: 4) {
                    Text(L10n.text(label))
                    Spacer(minLength: 0)
                    Text(values[label] ?? "")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
