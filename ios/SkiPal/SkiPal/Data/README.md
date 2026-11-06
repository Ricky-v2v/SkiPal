# Data/

App 内置的静态数据。JSON 不支持注释，格式说明维护在这里。

| 文件 | 职责 |
| --- | --- |
| `ski_resorts.json` | 雪场坐标库，由 `SkiResortDatabase` 加载，按 5 km 半径识别当前雪场 |

`ski_resorts.json` 结构：顶层 `{"resorts": [...]}`，每项字段与 `Models/SkiResort.swift` 对应，
包括 `id`、`name`、`nameEn`、`country`、`region`、`latitude`、`longitude`、`baseElevation`、
`summitElevation`、`totalRuns`、`difficultyDistribution` 等。修改字段需同步模型。

> 结构/内容变更需更新此文档。
