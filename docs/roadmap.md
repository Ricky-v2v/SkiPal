# 想法池与后续工作

> 记录在此**不代表批准实施**。进入实施需在 [PRD](PRD.md) 建条目并经用户批准（规则见 [AGENTS.md §4](../AGENTS.md#4-需求分流与批准边界)）。
> 未立项的想法不分配编号；已进入 PRD 的条目保留编号与链接，完成后勾选并写结论。

## 已立项（见 PRD）

- [ ] [F1 滑行评分引擎](PRD.md#f1-滑行评分引擎)：待验收，本机验证结果与未验项见 [progress](progress.md#最近验证)
- [ ] [F2 雪地可读主题](PRD.md#f2-暗色高对比雪地可读主题)：待批准
- [ ] [F3 演示与文档](PRD.md#f3-演示与文档)：待批准
- [x] [O1 建立四文件开发闭环](PRD.md#o1-建立四文件开发闭环)：闭环已建立，补充本地覆盖配置忽略规则与公开提交检查；当前交付和验证见 [progress](progress.md)

- [x] [O2 关闭 Git 提交中的 Claude 署名](PRD.md#o2-关闭-git-提交中的-claude-署名)：项目配置已随本地快照保存，配置检查结果见 [progress](progress.md#最近验证)。

## 已批准未实施

（暂无）

## 待决事项

- [ ] F1 评分结果是否接入界面（会话详情页 / 分享卡片 / AI 教练），以及接入哪里
- [ ] F1 是否需要按原规格把雪质指数纳入评分输入
- [ ] Kiroween 参赛类别与最终范围
- [ ] 两套教练实现（`AICoachService`+`AICoachView` 与 `SkiCoach`+`SkiCoachView`）保留哪套；两个视图目前都没有入口
- [ ] 两套跌倒检测（`FallDetectionService` 与 `FallDetector`）是否合并
- [ ] `VideoRecordingService` 已注入但没有界面入口：接入还是移除

## 候选想法

- 整理超过 500 行建议值的存量文件（`SkiCoach.swift`、`AICoachService.swift`、`VideoRecordingService.swift`、`AICoachView.swift`、`SkiCoachView.swift`、`FallDetector.swift`）。按 [AGENTS.md §11](../AGENTS.md#11-源代码行数约束) 在相关修改时逐步进行，可能随上面的取舍一并解决
- CI（`.github/workflows/ios-build.yml`）目前只构建、不跑单元测试，可考虑加 `xcodebuild test`
- 当前构建存在 Swift 并发隔离、非 Sendable 捕获、弃用 API 等警告，后续按涉及模块整理；证据见 [F1 验证记录](evidence/F1-2026-11-06.md)。本次不扩大修复范围
- F1 的负速度测试实际验证了模型将负速度置零，并未触达引擎负速度过滤分支；异常点过滤后的距离与爬升仍取原始会话汇总，需补充场景验证并确认规则，见 [验证记录](evidence/F1-2026-11-06.md)
- 存量源文件补 `@Input/@Output/@Pos/@UpdateRule` 文件头（按规则在修改时顺手补）
- `QUICKSTART.md` 标题仍是 "Phase 2"，内容可与 architecture.md 合并或更新

## 跨版本方向

以下来自旧版 `ios/README.md` 的规划，均未评估：好友系统、排行榜、动态分享、活动组织、装备管理、滑雪教学。
注意其中社交类与 PRD 的[非目标](PRD.md#3-范围)冲突，若要推进需先修改非目标。
