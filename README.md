# StockCalculator

A 股快速测算工具（iOS / Mac Catalyst），SwiftUI + MVVM。

## 功能

- **交易盈亏**：输入买入价、卖出价、股数（支持按"手"输入），自动计入佣金、印花税、过户费（费率可自定义），算出净利润、收益率和精确盈亏平衡价，可保存历史记录
- **加仓成本**：旧持仓 + 加仓即时测算摊薄成本，填当前市价可看浮动盈亏（即算即走，不入历史）
- **涨跌推演**：输入基准价，滑动涨跌幅滑杆实时推算目标价、涨跌额，幅度上限可配置（±5% ST / ±10% 主板 / ±20% 创业板·科创板 / ±30% 北交所），填股数后附预计收益与持仓市值
- **历史记录**：按时间保存的交易记录，按天分组并显示当日合计盈亏，可展开查看费用明细、删除（带确认）
- **中英双语**、**浅色/深色/跟随系统**外观切换

## 技术要点

- SwiftUI + MVVM，`NavigationStack`，iOS 17+ 部署目标
- 本地化：中文为 key 的 `.strings` 双表方案，运行时可切换语言
- Mac Catalyst 通过 `UIWindowSceneDelegate` 放宽窗口最小尺寸限制

## 构建运行

```bash
xcodebuild -project StockCalculator.xcodeproj -scheme StockCalculator \
  -configuration Release -destination 'platform=macOS,variant=Mac Catalyst' build
```

构建产物位于 `DerivedData/.../Release-maccatalyst/StockCalculator.app`，可拷入 `/Applications` 使用。

## 下载

见 [Releases](https://github.com/zengry/StockCalculator/releases)：下载 `StockCalculator.dmg`，拖入 Applications。首次打开如被 Gatekeeper 拦截，右键 → 打开。

## 截图

（待补充）

## License

MIT
