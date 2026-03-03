//
//  ShareCardView.swift
//  SkiPal
//
//  分享卡片视图 - 预览和生成分享卡片
//

import SwiftUI
import UIKit

/// 分享卡片视图
struct ShareCardView: View {
    let session: SkiSession
    @State private var selectedTemplate: ShareCardTemplate = .classic
    @State private var generatedImage: UIImage?
    @State private var isGenerating = false
    @State private var showingShareSheet = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 卡片预览
                    cardPreviewSection
                    
                    // 模板选择
                    templateSelectorSection
                    
                    // 操作按钮
                    actionButtonsSection
                }
                .padding()
            }
            .navigationTitle("分享记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let image = generatedImage {
                    ShareSheet(items: [image])
                }
            }
        }
    }
    
    // MARK: - 子视图
    
    private var cardPreviewSection: some View {
        VStack(spacing: 10) {
            Text("预览")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let image = generatedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            } else {
                VStack(spacing: 15) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("正在生成卡片...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
            }
        }
    }
    
    private var templateSelectorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("选择模板")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                ForEach(ShareCardTemplate.allCases, id: \.self) { template in
                    TemplateButton(
                        template: template,
                        isSelected: selectedTemplate == template,
                        action: {
                            selectedTemplate = template
                            generateCard()
                        }
                    )
                }
            }
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: shareCard) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                    Text("分享卡片")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(generatedImage != nil ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(generatedImage == nil)
            
            Button(action: saveToPhotos) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title3)
                    Text("保存到相册")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(generatedImage != nil ? Color.green : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(generatedImage == nil)
        }
    }
    
    // MARK: - 操作
    
    private func generateCard() {
        isGenerating = true
        generatedImage = nil
        
        ShareCardService.shared.generateShareCard(
            for: session,
            template: selectedTemplate
        ) { image in
            generatedImage = image
            isGenerating = false
        }
    }
    
    private func shareCard() {
        guard let image = generatedImage else { return }
        showingShareSheet = true
    }
    
    private func saveToPhotos() {
        guard let image = generatedImage else { return }
        
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        
        // 显示成功提示
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
}

// MARK: - 模板按钮

struct TemplateButton: View {
    let template: ShareCardTemplate
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(template.primaryColor)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                    )
                    .overlay(
                        Circle()
                            .fill(template.secondaryColor)
                            .frame(width: 20, height: 20)
                    )
                
                Text(template.displayName)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - 分享 Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 预览

struct ShareCardView_Previews: PreviewProvider {
    static var previews: some View {
        ShareCardView(
            session: SkiSession(
                startTime: Date().addingTimeInterval(-3600),
                locations: [
                    SkiLocation(from: CLLocation(latitude: 40.3, longitude: 116.6, altitude: 500, horizontalAccuracy: 0, verticalAccuracy: 0, speed: 15, course: 0, timestamp: Date()))
                ],
                resortName: "南山滑雪场"
            )
        )
    }
}
