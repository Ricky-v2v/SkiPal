//
//  ShareCardService.swift
//  SkiPal
//
//  分享卡片服务 - 生成可分享的滑雪记录图片
//

import UIKit
import CoreLocation
import MapKit

/// 分享卡片模板
enum ShareCardTemplate: String, CaseIterable, Identifiable {
    case classic = "经典黑金"
    case fresh = "清新蓝白"
    case vibrant = "活力橙红"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var primaryColor: UIColor {
        switch self {
        case .classic: return UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        case .fresh: return UIColor(red: 0.0, green: 0.48, blue: 0.75, alpha: 1.0)
        case .vibrant: return UIColor(red: 1.0, green: 0.27, blue: 0.0, alpha: 1.0)
        }
    }

    var secondaryColor: UIColor {
        switch self {
        case .classic: return UIColor(red: 0.84, green: 0.71, blue: 0.22, alpha: 1.0)
        case .fresh: return UIColor.white
        case .vibrant: return UIColor(red: 1.0, green: 0.59, blue: 0.0, alpha: 1.0)
        }
    }

    var textColor: UIColor {
        return .white
    }

    var accentColor: UIColor {
        switch self {
        case .classic: return UIColor(red: 0.84, green: 0.71, blue: 0.22, alpha: 1.0)
        case .fresh: return UIColor(red: 0.0, green: 0.75, blue: 1.0, alpha: 1.0)
        case .vibrant: return UIColor.yellow
        }
    }
}

/// 分享卡片服务
class ShareCardService {
    static let shared = ShareCardService()
    
    private init() {}
    
    /// 生成分享卡片
    func generateShareCard(
        for session: SkiSession,
        template: ShareCardTemplate = .classic,
        mapSnapshot: UIImage? = nil,
        completion: @escaping (UIImage?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let image = self.renderShareCard(session: session, template: template, mapSnapshot: mapSnapshot)
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
    
    /// 渲染分享卡片
    private func renderShareCard(
        session: SkiSession,
        template: ShareCardTemplate,
        mapSnapshot: UIImage?
    ) -> UIImage {
        let size = CGSize(width: 1080, height: 1350)  // 4:5 比例，适合社交媒体
        
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let ctx = context.cgContext
            
            // 1. 绘制背景
            template.primaryColor.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            
            // 2. 绘制渐变效果
            drawGradient(ctx: ctx, size: size, template: template)
            
            // 3. 绘制地图快照 (如果有)
            if let mapSnapshot = mapSnapshot {
                drawMapSnapshot(ctx: ctx, image: mapSnapshot, size: size)
            } else {
                drawMapPlaceholder(ctx: ctx, size: size, template: template)
            }
            
            // 4. 绘制统计信息
            drawStatistics(ctx: ctx, session: session, size: size, template: template)

            // 5. 绘制成就星级
            drawAchievementStars(ctx: ctx, stars: session.achievementStars, title: session.achievementTitle, size: size, template: template)
            
            // 6. 绘制标题和日期
            drawHeader(ctx: ctx, session: session, size: size, template: template)
            
            // 7. 绘制品牌标识
            drawBranding(ctx: ctx, size: size, template: template)
        }
    }
    
    // MARK: - 绘制辅助方法
    
    private func drawGradient(ctx: CGContext, size: CGSize, template: ShareCardTemplate) {
        guard let colorSpace = CGColorSpaceCreateGenericRGB().into() else { return }
        
        let colors = [
            template.primaryColor.cgColor,
            template.primaryColor.withAlphaComponent(0.8).cgColor
        ] as CFArray
        
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) else { return }
        
        let startPoint = CGPoint(x: size.width / 2, y: 0)
        let endPoint = CGPoint(x: size.width / 2, y: size.height)
        
        ctx.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
    }
    
    private func drawMapSnapshot(ctx: CGContext, image: UIImage, size: CGSize) {
        let mapHeight = size.height * 0.35
        let mapRect = CGRect(x: 0, y: 0, width: size.width, height: mapHeight)
        
        ctx.saveGState()
        
        // 添加圆角裁剪
        let path = UIBezierPath(roundedRect: mapRect, byRoundingCorners: [.bottomLeft, .bottomRight], cornerRadii: CGSize(width: 30, height: 30))
        path.addClip()
        
        // 绘制图片
        image.draw(in: mapRect)
        
        // 添加渐变遮罩
        let gradientColors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.3).cgColor
        ] as CFArray
        guard let colorSpace = CGColorSpaceCreateGenericRGB().into(),
              let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0, 1]) else {
            ctx.restoreGState()
            return
        }
        
        ctx.drawLinearGradient(gradient, start: CGPoint(x: size.width/2, y: mapHeight * 0.3), end: CGPoint(x: size.width/2, y: mapHeight), options: [])
        
        ctx.restoreGState()
    }
    
    private func drawMapPlaceholder(ctx: CGContext, size: CGSize, template: ShareCardTemplate) {
        let mapHeight = size.height * 0.35
        let mapRect = CGRect(x: 0, y: 0, width: size.width, height: mapHeight)
        
        template.secondaryColor.withAlphaComponent(0.1).setFill()
        ctx.fill(mapRect)
        
        // 绘制滑雪图标
        let iconSize = CGSize(width: 80, height: 80)
        let iconRect = CGRect(
            x: (size.width - iconSize.width) / 2,
            y: (mapHeight - iconSize.height) / 2,
            width: iconSize.width,
            height: iconSize.height
        )
        
        let iconImage = UIImage(systemName: "skiing.downhill")
        iconImage?.withTintColor(template.secondaryColor, renderingMode: .alwaysOriginal).draw(in: iconRect)
    }
    
    private func drawStatistics(ctx: CGContext, session: SkiSession, size: CGSize, template: ShareCardTemplate) {
        let startY = size.height * 0.38
        let rowHeight = size.height * 0.08
        let columnWidth = size.width / 4
        
        let stats: [(String, String)] = [
            ("距离", String(format: "%.1f km", session.totalDistance / 1000)),
            ("时长", session.formattedDuration),
            ("速度", String(format: "%.1f km/h", session.averageSpeed * 3.6)),
            ("海拔", String(format: "%.0f m", session.elevationGain))
        ]
        
        for (index, stat) in stats.enumerated() {
            let x = CGFloat(index) * columnWidth + 20
            let y = startY + CGFloat(index / 2) * rowHeight * 2.5
            
            // 标签
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .medium),
                .foregroundColor: template.textColor.withAlphaComponent(0.7)
            ]
            stat.0.draw(at: CGPoint(x: x, y: y), withAttributes: labelAttrs)
            
            // 数值
            let valueAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 42, weight: .bold),
                .foregroundColor: template.accentColor
            ]
            stat.1.draw(at: CGPoint(x: x, y: y + 50), withAttributes: valueAttrs)
        }
    }
    
    private func drawAchievementStars(ctx: CGContext, stars: Int, title: String, size: CGSize, template: ShareCardTemplate) {
        let starsY = size.height * 0.72
        let starSize: CGFloat = 60
        let totalWidth = CGFloat(stars) * (starSize + 10) - 10
        let startX = (size.width - totalWidth) / 2

        for i in 0..<stars {
            let starRect = CGRect(
                x: startX + CGFloat(i) * (starSize + 10),
                y: starsY,
                width: starSize,
                height: starSize
            )

            let starImage = UIImage(systemName: "star.fill")
            starImage?.withTintColor(template.accentColor, renderingMode: .alwaysOriginal).draw(in: starRect)
        }

        // 成就标题
        let titleY = starsY + starSize + 20
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 36, weight: .semibold),
            .foregroundColor: template.textColor
        ]
        title.draw(at: CGPoint(x: (size.width - title.size(withAttributes: titleAttrs).width) / 2, y: titleY), withAttributes: titleAttrs)
    }
    
    private func drawHeader(ctx: CGContext, session: SkiSession, size: CGSize, template: ShareCardTemplate) {
        // 雪场名称
        let resortName = session.resortName ?? "滑雪记录"
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 56, weight: .bold),
            .foregroundColor: template.textColor
        ]
        let nameRect = CGRect(x: 40, y: size.height * 0.38, width: size.width - 80, height: 80)
        resortName.draw(in: nameRect, withAttributes: nameAttrs)
        
        // 日期
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy 年 MM 月 dd 日"
        let dateString = dateFormatter.string(from: session.startTime)
        
        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32, weight: .regular),
            .foregroundColor: template.textColor.withAlphaComponent(0.8)
        ]
        dateString.draw(at: CGPoint(x: 40, y: size.height * 0.38 + 90), withAttributes: dateAttrs)
    }
    
    private func drawBranding(ctx: CGContext, size: CGSize, template: ShareCardTemplate) {
        let brandingY = size.height - 100
        
        // SkiPal Logo
        let logoAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 40, weight: .bold),
            .foregroundColor: template.secondaryColor
        ]
        let logoText = "🎿 SkiPal"
        logoText.draw(at: CGPoint(x: (size.width - logoText.size(withAttributes: logoAttrs).width) / 2, y: brandingY), withAttributes: logoAttrs)
        
        // 标签
        let hashtagAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .light),
            .foregroundColor: template.textColor.withAlphaComponent(0.6)
        ]
        let hashtagText = "#SkiPal #滑雪 #WinterSports"
        hashtagText.draw(at: CGPoint(x: (size.width - hashtagText.size(withAttributes: hashtagAttrs).width) / 2, y: brandingY + 50), withAttributes: hashtagAttrs)
    }
}

// MARK: - 地图快照辅助
extension ShareCardService {
    /// 创建地图快照
    func createMapSnapshot(for locations: [SkiLocation], completion: @escaping (UIImage?) -> Void) {
        guard !locations.isEmpty else {
            print("⚠️ 无法创建地图快照：位置数据为空")

            completion(nil)
            return
        }
        
        let validLocations = locations.filter { loc in
            loc.latitude >= -90 && loc.latitude <= 90 &&
            loc.longitude >= -180 && loc.longitude <= 180
        }
        
        guard !validLocations.isEmpty else {
            completion(nil)
            return
        }
        
        let coordinateBounds = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: validLocations.reduce(0) { $0 + $1.latitude } / Double(validLocations.count),
                longitude: validLocations.reduce(0) { $0 + $1.longitude } / Double(validLocations.count)
            ),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        
        let options = MKMapSnapshotter.Options()
        options.region = coordinateBounds
        options.size = CGSize(width: 1080, height: 600)
        options.scale = UIScreen.main.scale
        
        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start { snapshot, error in
            if let error = error {
                print("❌ 地图快照失败：\(error.localizedDescription)")
                completion(nil)
                return
            }
            
            UIGraphicsBeginImageContextWithOptions(options.size, true, 0)
            snapshot?.image.draw(at: .zero)
            
            // 绘制路径
            let path = UIBezierPath()
            path.lineWidth = 8
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            UIColor.white.setStroke()
            
            for (index, location) in locations.enumerated() {
                let point = snapshot?.point(for: location.coordinate) ?? .zero
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.stroke()
            
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            completion(image)
        }
    }
}
