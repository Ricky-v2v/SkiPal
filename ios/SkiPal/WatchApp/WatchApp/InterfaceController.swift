//
//  InterfaceController.swift
//  SkiPal Watch App
//
//  现代 watchOS SwiftUI 入口与滑行实时界面。
//

import SwiftUI
import WatchKit

@main
struct SkiPalWatchApp: App {
    @StateObject private var model = WatchSessionModel()

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environmentObject(model)
        }
    }
}

struct WatchHomeView: View {
    @EnvironmentObject private var model: WatchSessionModel
    @State private var showsEmergencyConfirmation = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            ScrollView {
                VStack(spacing: 8) {
                    connectionStatus
                    speedSection
                    metricsSection
                    recordingStatus
                    controls
                    emergencyControl
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            model.activate()
        }
        .confirmationDialog(
            "确认发送紧急求助？",
            isPresented: $showsEmergencyConfirmation,
            titleVisibility: .visible
        ) {
            Button("发送紧急求助", role: .destructive) {
                model.reportEmergency()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将通过 iPhone 通知紧急联系人。")
        }
    }

    private var connectionStatus: some View {
        HStack(spacing: 4) {
            Image(systemName: model.isReachable ? "iphone.radiowaves.left.and.right" : "iphone.slash")
            Text(model.isReachable ? "iPhone 已连接" : "⌚ iPhone 不可达")
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .font(.caption2)
        .foregroundStyle(model.isReachable ? .green : .orange)
    }

    private var speedSection: some View {
        VStack(spacing: -2) {
            Text(String(format: "%.1f", model.speedKilometersPerHour))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("km/h")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("当前速度 \(String(format: "%.1f", model.speedKilometersPerHour)) 公里每小时")
    }

    private var metricsSection: some View {
        HStack(spacing: 6) {
            metric(
                title: "距离",
                value: String(format: "%.2f", model.distanceKilometers),
                unit: "km"
            )
            metric(
                title: "时长",
                value: model.formattedDuration,
                unit: nil
            )
        }
    }

    private func metric(title: String, value: String, unit: String?) -> some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                if let unit {
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var recordingStatus: some View {
        Text(model.recordingState.displayName)
            .font(.caption)
            .foregroundStyle(model.recordingState.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(model.recordingState.tint.opacity(0.15), in: Capsule())
            .accessibilityLabel("录制状态：\(model.recordingState.displayName)")
    }

    private var controls: some View {
        VStack(spacing: 6) {
            Button {
                model.performPrimaryAction()
            } label: {
                Label(model.recordingState.primaryActionTitle, systemImage: model.recordingState.primaryActionIcon)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(model.recordingState.primaryActionTint)
            .disabled(!model.isReachable)

            if model.recordingState.isActive {
                Button(role: .destructive) {
                    model.sendAction(.stopRecording)
                } label: {
                    Label("结束", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!model.isReachable)
            }
        }
    }

    private var emergencyControl: some View {
        Button(role: .destructive) {
            showsEmergencyConfirmation = true
        } label: {
            Label("紧急求助", systemImage: "sos")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(!model.isReachable)
    }
}
