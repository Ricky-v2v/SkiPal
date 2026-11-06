//
//  FallDetectionView.swift
//  SkiPal
//
//  摔倒检测 UI 组件
//

import SwiftUI
import Combine

/// 摔倒警报视图 - 检测到摔倒后显示
struct FallAlertView: View {
    let fallEvent: FallEvent
    let onOkay: () -> Void
    let onNeedHelp: () -> Void

    @State private var countdown: Int = 15
    @State private var isExpanded = false

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // 警告图标
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 100, height: 100)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                }
                .padding(.top, 20)

                // 标题
                Text("检测到摔倒！")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                // 副标题
                Text("你还好吗？")
                    .font(.title3)
                    .foregroundColor(.gray)

                // 倒计时
                VStack(spacing: 8) {
                    Text("自动报警倒计时")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text("\(countdown)s")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(countdown <= 5 ? .red : .white)
                }
                .padding(.vertical)

                // 摔倒详情
                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("摔倒详情")
                            .font(.headline)
                            .foregroundColor(.gray)

                        HStack {
                            Text("时间:")
                                .foregroundColor(.gray)
                            Spacer()
                            Text(fallEvent.timestamp.formatted(date: .omitted, time: .shortened))
                                .foregroundColor(.white)
                        }

                        HStack {
                            Text("冲击力:")
                                .foregroundColor(.gray)
                            Spacer()
                            Text(String(format: "%.1fg", fallEvent.impactMagnitude))
                                .foregroundColor(.white)
                        }

                        if let location = fallEvent.location {
                            HStack {
                                Text("位置:")
                                    .foregroundColor(.gray)
                                Spacer()
                                Link("查看地图", destination: URL(string: "https://maps.apple.com/?ll=\(location.latitude),\(location.longitude)")!)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
                }

                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    Text(isExpanded ? "收起详情" : "查看详情")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                Spacer()

                // 操作按钮
                VStack(spacing: 16) {
                    // 我没事按钮
                    Button {
                        onOkay()
                    } label: {
                        Text("我没事")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    // 需要帮助按钮
                    Button {
                        onNeedHelp()
                    } label: {
                        HStack {
                            Image(systemName: "phone.fill")
                            Text("需要帮助")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 24)
            .background(Color(.systemGray6))
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(.horizontal, 20)
        }
        .onReceive(timer) { _ in
            if countdown > 0 {
                countdown -= 1
            }
            if countdown == 0 {
                // 自动升级为紧急状态
            }
        }
    }
}

/// 摔倒检测设置视图
struct FallDetectionSettingsView: View {
    @ObservedObject var fallDetector: FallDetector
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                // 开关
                Section {
                    Toggle("启用摔倒检测", isOn: $fallDetector.isEnabled)
                        .tint(.blue)
                } footer: {
                    Text("检测滑雪时的摔倒事件并发出警报")
                }

                // 灵敏度
                Section {
                    Picker("灵敏度", selection: $fallDetector.sensitivity) {
                        ForEach(FallDetector.FallSensitivity.allCases, id: \.self) { sensitivity in
                            Text(sensitivity.rawValue).tag(sensitivity)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("检测灵敏度")
                } footer: {
                    Text("高灵敏度可检测更多摔倒，但可能增加误报")
                }

                // 统计
                Section("统计") {
                    HStack {
                        Text("今日摔倒次数")
                        Spacer()
                        Text("\(fallDetector.todayFallCount)")
                            .foregroundColor(.gray)
                    }

                    HStack {
                        Text("总摔倒次数")
                        Spacer()
                        Text("\(fallDetector.fallCount)")
                            .foregroundColor(.gray)
                    }
                }

                // 说明
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label {
                            Text("摔倒检测使用加速度计监测突发冲击")
                        } icon: {
                            Image(systemName: "waveform.path")
                                .foregroundColor(.blue)
                        }

                        Label {
                            Text("检测到摔倒后会震动提醒并显示确认对话框")
                        } icon: {
                            Image(systemName: "iphone.radiowaves.left.and.right")
                                .foregroundColor(.orange)
                        }

                        Label {
                            Text("15秒内无响应将自动发送紧急通知")
                        } icon: {
                            Image(systemName: "bell.badge")
                                .foregroundColor(.red)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
            }
            .navigationTitle("摔倒检测")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// 紧急联系人视图
struct EmergencyContactsView: View {
    @ObservedObject var contactService = EmergencyContactService()
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddContact = false
    @State private var editingContact: EmergencyContact?

    var body: some View {
        NavigationView {
            List {
                if contactService.contacts.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)

                            Text("尚未添加紧急联系人")
                                .font(.headline)
                                .foregroundColor(.gray)

                            Text("摔倒时会通知您的紧急联系人")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                } else {
                    ForEach(contactService.contacts) { contact in
                        EmergencyContactRow(contact: contact) {
                            editingContact = contact
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                contactService.deleteContact(contact)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("紧急联系人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddContact = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddContact) {
                AddEmergencyContactView(contactService: contactService)
            }
            .sheet(item: $editingContact) { contact in
                AddEmergencyContactView(contactService: contactService, editingContact: contact)
            }
        }
    }
}

/// 紧急联系人行
struct EmergencyContactRow: View {
    let contact: EmergencyContact
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack {
                // 头像
                ZStack {
                    Circle()
                        .fill(contact.isPrimary ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 44, height: 44)

                    Text(String(contact.name.prefix(1)))
                        .font(.headline)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(contact.name)
                            .foregroundColor(.white)

                        if contact.isPrimary {
                            Text("主要")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }

                    Text(contact.phoneNumber)
                        .font(.caption)
                        .foregroundColor(.gray)

                    if let relationship = contact.relationship {
                        Text(relationship)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
    }
}

/// 添加/编辑紧急联系人视图
struct AddEmergencyContactView: View {
    @ObservedObject var contactService: EmergencyContactService
    @Environment(\.dismiss) private var dismiss

    var editingContact: EmergencyContact?

    @State private var name = ""
    @State private var phoneNumber = ""
    @State private var relationship = ""
    @State private var isPrimary = false

    var isEditing: Bool {
        editingContact != nil
    }

    var body: some View {
        NavigationView {
            Form {
                Section("联系人信息") {
                    TextField("姓名", text: $name)

                    TextField("电话号码", text: $phoneNumber)
                        .keyboardType(.phonePad)

                    TextField("关系 (可选)", text: $relationship)

                    Toggle("设为主要联系人", isOn: $isPrimary)
                        .tint(.blue)
                }
            }
            .navigationTitle(isEditing ? "编辑联系人" : "添加联系人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveContact()
                    }
                    .disabled(name.isEmpty || phoneNumber.isEmpty)
                }
            }
            .onAppear {
                if let contact = editingContact {
                    name = contact.name
                    phoneNumber = contact.phoneNumber
                    relationship = contact.relationship ?? ""
                    isPrimary = contact.isPrimary
                }
            }
        }
    }

    private func saveContact() {
        let contact = EmergencyContact(
            id: editingContact?.id ?? UUID(),
            name: name,
            phoneNumber: phoneNumber,
            relationship: relationship.isEmpty ? nil : relationship,
            isPrimary: isPrimary
        )

        if isEditing {
            contactService.updateContact(contact)
        } else {
            contactService.addContact(contact)
        }

        dismiss()
    }
}

// MARK: - Preview

#Preview("Fall Alert") {
    FallAlertView(
        fallEvent: FallEvent(
            timestamp: Date(),
            impactMagnitude: 3.2,
            location: FallLocation(latitude: 39.9, longitude: 116.4, altitude: 2000)
        ),
        onOkay: {},
        onNeedHelp: {}
    )
}

#Preview("Settings") {
    FallDetectionSettingsView(fallDetector: FallDetector())
}

#Preview("Emergency Contacts") {
    EmergencyContactsView()
}
