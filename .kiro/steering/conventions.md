# 代码规范（SkiPal）

## 通用

- 说明文档、注释使用中文；代码标识符使用英文；界面文案走双语资源（`zh-Hans` / `en`）
- 单个生产源文件建议控制在 500 行以内，硬上限 1000 行；接近上限时按职责拆成子组件
- 不提交 `DerivedData/`、`.build/`、`xcuserdata/`、`.DS_Store`、签名证书与描述文件
- 不在仓库内写入密钥、令牌、账号密码、个人设备路径或真实联系人信息

## Swift / SwiftUI

- 视图只做渲染与交互编排，逻辑放 `Services/` 或模型的计算属性里
- 状态用 `@State` / `@StateObject` / `@EnvironmentObject`，避免视图内自建观察者
- Core Location 与传感器回调统一收敛到服务层，视图层不直接接触 `CLLocationManager`
- 权限申请前置到功能触发点（点“开始滑雪”再问定位），不在启动时一次性索要
- 新增算法必须配套单元测试；边界值（0 速度、极短距离、无信号）要有用例

## 提交前检查

```bash
cd ios/SkiPal && xcodegen generate
xcodebuild -project ios/SkiPal/SkiPal.xcodeproj -scheme SkiPal \
  -destination 'platform=iOS Simulator,name=iPhone 15' clean build
```
