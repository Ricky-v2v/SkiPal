//
//  RunScoreSection.swift
//  SkiPal
//
//  会话详情页的滑行评分区：总分、三项维度分与改进建议
//
//  @Input      SkiSession；RunScoreEngine.score(for:) 计算结果
//  @Output     RunScoreSection 视图（纯展示，无交互）
//  @Pos        Views 层，会话详情页评分区，PRD F1-UI
//  @UpdateRule 修改展示内容或文案键时同步更新此头、Views/README.md 与 Localizable.strings
//

import SwiftUI

struct RunScoreSection: View {
    let session: SkiSession

    var body: some View {
        let result = RunScoreEngine.score(for: session)
        let scoreStyle: HierarchicalShapeStyle = result.isReliable ? .primary : .secondary

        VStack(alignment: .leading, spacing: 16) {
            Text("滑行评分")
                .font(.headline)

            // 总分
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(result.totalScore)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(scoreStyle)
                Text("总分")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !result.isReliable {
                Label("数据不足，评分仅供参考", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange.opacity(0.8))
            }

            // 三项维度分
            HStack(spacing: 12) {
                DimensionScoreView(dimension: .route, score: result.routeScore, style: scoreStyle)
                DimensionScoreView(dimension: .rhythm, score: result.rhythmScore, style: scoreStyle)
                DimensionScoreView(dimension: .stamina, score: result.staminaScore, style: scoreStyle)
            }

            if !result.advices.isEmpty {
                Divider()

                Text("改进建议")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(result.advices.enumerated()), id: \.offset) { _, advice in
                        AdviceRow(advice: advice)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

// MARK: - 维度分
private struct DimensionScoreView: View {
    let dimension: RunScoreAdvice.Dimension
    let score: Int
    let style: HierarchicalShapeStyle

    var body: some View {
        VStack(spacing: 4) {
            Text("\(score)")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(style)
            Text(LocalizedStringKey(dimension.rawValue))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.6))
        )
    }
}

// MARK: - 建议行
private struct AdviceRow: View {
    let advice: RunScoreAdvice

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(LocalizedStringKey(advice.dimension.rawValue))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.blue.opacity(0.12)))

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(advice.title))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
                Text(LocalizedStringKey(advice.action))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    RunScoreSection(session: SkiSession())
}
