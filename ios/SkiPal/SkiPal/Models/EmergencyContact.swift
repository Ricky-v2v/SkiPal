//
//  EmergencyContact.swift
//  SkiPal
//
//  紧急联系人模型
//

import Foundation
import Contacts

/// 紧急联系人
struct EmergencyContact: Identifiable, Codable {
    let id: UUID
    var name: String
    var phoneNumber: String
    var relationship: String?
    var isPrimary: Bool

    init(id: UUID = UUID(), name: String, phoneNumber: String, relationship: String? = nil, isPrimary: Bool = false) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.relationship = relationship
        self.isPrimary = isPrimary
    }

    /// 格式化显示的电话号码
    var formattedPhone: String {
        // 简单格式化：添加空格
        var result = ""
        for (index, char) in phoneNumber.enumerated() {
            if index > 0 && index % 4 == 0 {
                result += " "
            }
            result.append(char)
        }
        return result
    }
}

/// 紧急联系人管理服务
class EmergencyContactService: ObservableObject {
    @Published var contacts: [EmergencyContact] = []
    @Published var isAuthorized: Bool = false

    private let storeKey = "skipal_emergency_contacts"

    init() {
        loadContacts()
    }

    // MARK: - CRUD Operations

    func addContact(_ contact: EmergencyContact) {
        // 如果设为主要联系人，取消其他主要联系人
        var newContact = contact
        if newContact.isPrimary {
            contacts = contacts.map { var c = $0; c.isPrimary = false; return c }
        }
        contacts.append(newContact)
        saveContacts()
    }

    func updateContact(_ contact: EmergencyContact) {
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            // 如果设为主要联系人，取消其他主要联系人
            var updatedContact = contact
            if updatedContact.isPrimary {
                contacts = contacts.map { var c = $0; c.isPrimary = false; return c }
            }
            contacts[index] = updatedContact
            saveContacts()
        }
    }

    func deleteContact(_ contact: EmergencyContact) {
        contacts.removeAll { $0.id == contact.id }
        saveContacts()
    }

    /// 获取主要联系人
    var primaryContact: EmergencyContact? {
        contacts.first { $0.isPrimary } ?? contacts.first
    }

    // MARK: - Persistence

    private func saveContacts() {
        if let data = try? JSONEncoder().encode(contacts) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }

    private func loadContacts() {
        if let data = UserDefaults.standard.data(forKey: storeKey),
           let savedContacts = try? JSONDecoder().decode([EmergencyContact].self, from: data) {
            contacts = savedContacts
        }
    }

    // MARK: - Contacts Integration

    /// 从系统通讯录选择联系人
    func importFromContacts(completion: @escaping (EmergencyContact?) -> Void) {
        // 这里需要 UI 层配合，使用 CNContactPickerViewController
        // 此方法由 UI 层调用并处理结果
    }

    /// 生成紧急消息内容
    func generateEmergencyMessage(location: FallLocation?) -> String {
        let locationString: String
        if let loc = location {
            locationString = "位置: https://maps.apple.com/?ll=\(loc.latitude),\(loc.longitude)"
        } else {
            locationString = "位置: 未知"
        }

        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)

        return """
        【SkiPal 紧急求助】

        我在滑雪时发生了摔倒，可能需要帮助。

        时间: \(timestamp)
        \(locationString)

        这是由 SkiPal 应用自动发送的紧急求助信息。
        """
    }
}