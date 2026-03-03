//
//  ShareCardGenerator.swift
//  SkiPal
//
//  分享卡片生成器 - 使用 UIGraphicsImageRenderer 生成分享图片
//

import SwiftUI
import UIKit
import MapKit
import CoreLocation

// Note: ShareCardTemplate is defined in ShareCardService.swift to avoid duplication

/// 分享卡片生成器
class ShareCardGenerator {

    /// 生成分享卡片图片
    static func generateCard(
        for session: SkiSession,
        template: ShareCardTemplate,
        mapSnapshot: UIImage? = nil
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 390, height: 520))
        let image = renderer.image { context in
            let ctx = context.cgContext

            // 绘制背景
            drawBackground(ctx: ctx, template: template, size: renderer.format.bounds.size)

            // 绘制内容
            let cgRect = renderer.format.bounds

            // 雪场名称和日期
            drawHeader(ctx: ctx, session: session, template: template, rect: cgRect)

            // 地图快照
            if let snapshot = mapSnapshot {
                drawMapSnapshot(snapshot: snapshot, ctx: ctx, rect: cgRect, template: template)
            } else {
                drawPlaceholderMap(ctx: ctx, rect: cgRect, template: template)
            }

            // 统计数据
            drawStatistics(ctx: ctx, session: session, template: template, rect: cgRect)

            // 成就星星
            drawAchievements(ctx: ctx, session: session, template: template, rect: cgRect)

            // 底部品牌
            drawBranding(ctx: ctx, template: template, rect: cgRect)
        }

        return image
    }

    // MARK: - 绘制方法

    private static func drawBackground(ctx: CGContext, template: ShareCardTemplate, size: CGSize) {
        let colors: [CGColor]

        switch template {
        case .classic:
            colors = [
                UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1).cgColor,
                UIColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1).cgColor
            ]
        case .fresh:
            colors = [
                UIColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1).cgColor,
                UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1).cgColor
            ]
        case .vibrant:
            colors = [
                UIColor(red: 1.0, green: 0.4, blue: 0.2, alpha: 1).cgColor,
                UIColor(red: 0.9, green: 0.2, blue: 0.3, alpha: 1).cgColor
            ]
        }

        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size.width, y: size.height), options: [])

        // 添加装饰图案
        drawDecorations(ctx: ctx, template: template, size: size)
    }

    private static func drawDecorations(ctx: CGContext, template: ShareCardTemplate, size: CGSize) {
        ctx.saveGState()

        switch template {
        case .classic:
            // 金色装饰线条
            ctx.setStrokeColor(UIColor(red: 0.85, green: 0.7, blue: 0.3, alpha: 0.3).cgColor)
            ctx.setLineWidth(1)

            for i in stride(from: 0, through: Int(size.width), by: 30) {
                ctx.move(to: CGPoint(x: CGFloat(i), y: 0))
                ctx.addLine(to: CGPoint(x: CGFloat(i) + 50, y: size.height))
            }
            ctx.strokePath()

        case .fresh:
            // 雪花装饰
            let snowflakeColor = UIColor.white.withAlphaComponent(0.1).cgColor
            ctx.setFillColor(snowflakeColor)

            for _ in 0..<20 {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let radius = CGFloat.random(in: 5...20)

                ctx.fillEllipse(in: CGRect(x: x - radius/2, y: y - radius/2, width: radius, height: radius))
            }

        case .vibrant:
            // 几何图形装饰
            ctx.setFillColor(UIColor.white.withAlphaComponent(0.05).cgColor)

            let path = UIBezierPath()
            path.move(to: CGPoint(x: size.width, y: 0))
            path.addLine(to: CGPoint(x: size.width - 100, y: 0))
            path.addLine(to: CGPoint(x: size.width, y: 100))
            path.close()
            ctx.addPath(path.cgPath)
            ctx.fillPath()
        }

        ctx.restoreGState()
    }

    private static func drawHeader(ctx: CGContext, session: SkiSession, template: ShareCardTemplate, rect: CGRect) {
        let textColor: UIColor
        let accentColor: UIColor

        switch template {
        case .classic:
            textColor = .white
            accentColor = UIColor(red: 0.85, green: 0.7, blue: 0.3, alpha: 1)
        case .fresh:
            textColor = .white
            accentColor = .white
        case .vibrant:
            textColor = .white
            accentColor = .white
        }

        // 雪场名称
        let resortName = session.resortName ?? "滑雪记录"
        let nameFont = UIFont.systemFont(ofSize: 28, weight: .bold)
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: nameFont,
            .foregroundColor: textColor
        ]
        let nameString = NSAttributedString(string: resortName, attributes: nameAttrs)
        nameString.draw(at: CGPoint(x: 24, y: 30))

        // 日期
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        let dateString = dateFormatter.string(from: session.startTime)

        let dateFont = UIFont.systemFont(ofSize: 16, weight: .medium)
        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: dateFont,
            .foregroundColor: accentColor
        ]
        let dateStringAttr = NSAttributedString(string: dateString, attributes: dateAttrs)
        dateStringAttr.draw(at: CGPoint(x: 24, y: 66))
    }

    private static func drawMapSnapshot(snapshot: UIImage, ctx: CGContext, rect: CGRect, template: ShareCardTemplate) {
        let mapRect = CGRect(x: 24, y: 100, width: rect.width - 48, height: 180)

        // 绘制圆角矩形裁剪区域
        let path = UIBezierPath(roundedRect: mapRect, cornerRadius: 16)
        ctx.addPath(path.cgPath)
        ctx.clip()

        // 绘制地图
        snapshot.draw(in: mapRect)

        // 恢复裁剪区域
        ctx.resetClip()

        // 绘制边框
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.3).cgColor)
        ctx.setLineWidth(2)
        ctx.addPath(UIBezierPath(roundedRect: mapRect, cornerRadius: 16).cgPath)
        ctx.strokePath()
    }

    private static func drawPlaceholderMap(ctx: CGContext, rect: CGRect, template: ShareCardTemplate) {
        let mapRect = CGRect(x: 24, y: 100, width: rect.width - 48, height: 180)

        // 绘制占位背景
        let bgColor: UIColor
        switch template {
        case .classic:
            bgColor = UIColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 1)
        case .fresh:
            bgColor = UIColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 1)
        case .vibrant:
            bgColor = UIColor(red: 0.95, green: 0.9, blue: 0.85, alpha: 1)
        }

        ctx.setFillColor(bgColor.cgColor)
        let path = UIBezierPath(roundedRect: mapRect, cornerRadius: 16)
        ctx.addPath(path.cgPath)
        ctx.fillPath()

        // 绘制滑雪图标
        let iconFont = UIFont.systemFont(ofSize: 60)
        let iconAttrs: [NSAttributedString.Key: Any] = [
            .font: iconFont,
            .foregroundColor: UIColor.white.withAlphaComponent(0.5)
        ]
        let iconString = NSAttributedString(string: "⛷️", attributes: iconAttrs)
        let iconSize = iconString.size()
        iconString.draw(at: CGPoint(
            x: mapRect.midX - iconSize.width / 2,
            y: mapRect.midY - iconSize.height / 2
        ))
    }

    private static func drawStatistics(ctx: CGContext, session: SkiSession, template: ShareCardTemplate, rect: CGRect) {
        let stats: [(String, String, String)] = [
            ("📏", String(format: "%.1f", session.totalDistance / 1000), "km"),
            ("⚡️", String(format: "%.1f", session.maxSpeed * 3.6), "km/h"),
            ("⬆️", String(format: "%.0f", session.elevationGain), "m"),
            ("⏱️", session.formattedDuration, "")
        ]

        let startX: CGFloat = 24
        let spacing: CGFloat = (rect.width - 48) / CGFloat(stats.count)
        let y: CGFloat = 310

        for (index, stat) in stats.enumerated() {
            let x = startX + spacing * CGFloat(index) + spacing / 2

            // 图标
            let iconFont = UIFont.systemFont(ofSize: 20)
            let iconAttrs: [NSAttributedString.Key: Any] = [
                .font: iconFont,
                .foregroundColor: UIColor.white
            ]
            let iconString = NSAttributedString(string: stat.0, attributes: iconAttrs)
            let iconSize = iconString.size()
            iconString.draw(at: CGPoint(x: x - iconSize.width / 2, y: y))

            // 数值
            let valueFont = UIFont.systemFont(ofSize: 24, weight: .bold)
            let textColor: UIColor = .white
            let valueAttrs: [NSAttributedString.Key: Any] = [
                .font: valueFont,
                .foregroundColor: textColor
            ]
            let valueString = NSAttributedString(string: stat.1, attributes: valueAttrs)
            let valueSize = valueString.size()
            valueString.draw(at: CGPoint(x: x - valueSize.width / 2, y: y + 28))

            // 单位
            if !stat.2.isEmpty {
                let unitFont = UIFont.systemFont(ofSize: 12, weight: .medium)
                let unitAttrs: [NSAttributedString.Key: Any] = [
                    .font: unitFont,
                    .foregroundColor: UIColor.white.withAlphaComponent(0.7)
                ]
                let unitString = NSAttributedString(string: stat.2, attributes: unitAttrs)
                let unitSize = unitString.size()
                unitString.draw(at: CGPoint(x: x - unitSize.width / 2, y: y + 56))
            }
        }
    }

    private static func drawAchievements(ctx: CGContext, session: SkiSession, template: ShareCardTemplate, rect: CGRect) {
        let y: CGFloat = 400
        let stars = String(repeating: "⭐", count: session.achievementStars)
        let emptyStars = String(repeating: "☆", count: 5 - session.achievementStars)
        let starString = stars + emptyStars

        let starFont = UIFont.systemFont(ofSize: 28)
        let starAttrs: [NSAttributedString.Key: Any] = [
            .font: starFont,
            .foregroundColor: UIColor.white
        ]
        let attrString = NSAttributedString(string: starString, attributes: starAttrs)
        let size = attrString.size()
        attrString.draw(at: CGPoint(x: (rect.width - size.width) / 2, y: y))

        // 成就标题
        let titleFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.white.withAlphaComponent(0.9)
        ]
        let titleAttrString = NSAttributedString(string: session.achievementTitle, attributes: titleAttrs)
        let titleSize = titleAttrString.size()
        titleAttrString.draw(at: CGPoint(x: (rect.width - titleSize.width) / 2, y: y + 40))
    }

    private static func drawBranding(ctx: CGContext, template: ShareCardTemplate, rect: CGRect) {
        let brandFont = UIFont.systemFont(ofSize: 14, weight: .medium)
        let brandAttrs: [NSAttributedString.Key: Any] = [
            .font: brandFont,
            .foregroundColor: UIColor.white.withAlphaComponent(0.6)
        ]

        let brandString = NSAttributedString(string: "SkiPal 🎿", attributes: brandAttrs)
        let brandSize = brandString.size()
        brandString.draw(at: CGPoint(x: (rect.width - brandSize.width) / 2, y: rect.height - 40))
    }

    // MARK: - 地图快照

    /// 生成地图快照
    static func generateMapSnapshot(for session: SkiSession, completion: @escaping (UIImage?) -> Void) {
        guard !session.locations.isEmpty else {
            print("⚠️ 无法生成地图快照：无位置数据")

            completion(nil)
            return
        }

        let coordinates = session.locations.map { $0.coordinate }

        // 计算区域
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            guard coord.latitude >= -90 && coord.latitude <= 90 else { continue }
            guard coord.longitude >= -180 && coord.longitude <= 180 else { continue }

            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.3, 0.01),
            longitudeDelta: max((maxLon - minLon) * 1.3, 0.01)
        )

        let region = MKCoordinateRegion(center: center, span: span)

        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = CGSize(width: 342, height: 180)
        options.mapType = .standard
        options.showsBuildings = true

        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start { snapshot, error in
            guard let snapshot = snapshot, error == nil else {
                completion(nil)
                return
            }

            // 在地图上绘制轨迹
            let image = drawPolylineOnSnapshot(snapshot: snapshot, coordinates: coordinates)
            completion(image)
        }
    }

    private static func drawPolylineOnSnapshot(snapshot: MKMapSnapshotter.Snapshot, coordinates: [CLLocationCoordinate2D]) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: snapshot.image.size)

        return renderer.image { context in
            // 绘制原始地图
            snapshot.image.draw(at: .zero)

            // 绘制轨迹线
            let ctx = context.cgContext
            ctx.setStrokeColor(UIColor.systemBlue.cgColor)
            ctx.setLineWidth(3)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            let path = UIBezierPath()
            for (index, coord) in coordinates.enumerated() {
                let point = snapshot.point(for: coord)
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            ctx.addPath(path.cgPath)
            ctx.strokePath()

            // 绘制起点和终点标记
            if let first = coordinates.first, let last = coordinates.last {
                let startPoint = snapshot.point(for: first)
                let endPoint = snapshot.point(for: last)

                // 起点
                ctx.setFillColor(UIColor.systemGreen.cgColor)
                ctx.fillEllipse(in: CGRect(x: startPoint.x - 6, y: startPoint.y - 6, width: 12, height: 12))

                // 终点
                ctx.setFillColor(UIColor.systemRed.cgColor)
                ctx.fillEllipse(in: CGRect(x: endPoint.x - 6, y: endPoint.y - 6, width: 12, height: 12))
            }
        }
    }
}