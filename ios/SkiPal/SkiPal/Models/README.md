# Models/

纯数据模型与可计算属性（距离、速度、坡度、成就星级），不依赖服务和 UI。

| 文件 | 职责 |
| --- | --- |
| `SkiSession.swift` | 滑雪会话与轨迹点 `SkiLocation`；距离、最高/平均速度、爬升、坡度、成就等计算属性 |
| `SkiSession+CloudKit.swift` | `SkiSession` ⇄ `CKRecord` 转换 |
| `SkiResort.swift` | 雪场模型（坐标、海拔、雪道数、难度分布） |
| `EmergencyContact.swift` | 紧急联系人模型 |

> 结构/内容变更需更新此文档。
