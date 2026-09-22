import SwiftUI
import UIKit

// 输入框标识，用于键盘焦点管理
enum CalculatorField: Hashable {
    case stockCode, buyPrice, sellPrice, shares
    case positionCost, positionShares, addPrice, addShares, currentPrice
    case probeBasePrice, probeShares
}

// 计算模式：交易盈亏 / 加仓成本 / 涨跌推演
enum CalculatorMode: String, CaseIterable {
    case trade = "Profit"
    case averaging = "Add Stock"
    case scenario = "推演"
}

struct CalculatorView: View {
    @EnvironmentObject var viewModel: TradeViewModel

    // 交易盈亏
    @State private var stockCode = ""
    @State private var buyPrice = ""
    @State private var sellPrice = ""
    @State private var shares = ""
    @State private var showSaveSuccess = false

    // 加仓成本
    @State private var positionCost = ""
    @State private var positionShares = ""
    @State private var addPrice = ""
    @State private var addShares = ""
    @State private var currentPrice = ""

    // 涨跌推演
    @State private var probeBasePrice = ""
    @State private var probeShares = ""
    @State private var probePercent: Double = 0

    @State private var mode: CalculatorMode = .trade
    @FocusState private var focusedField: CalculatorField?

    private var hasTradeResult: Bool { currentResult != nil }
    private var hasAveragingResult: Bool { averagingResult != nil }
    private var hasScenarioResult: Bool { scenarioBasePrice != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Picker("计算模式", selection: $mode) {
                        ForEach(CalculatorMode.allCases, id: \.self) { m in
                            Text(LocalizedStringKey(m.rawValue)).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    switch mode {
                    case .trade:
                        tradeSection
                            .transition(.opacity)
                    case .averaging:
                        averagingSection
                            .transition(.opacity)
                    case .scenario:
                        scenarioSection
                            .transition(.opacity)
                    }
                }
                .padding(.top, 16)
                .animation(.snappy, value: mode)
                .animation(.snappy, value: hasTradeResult)
                .animation(.snappy, value: hasAveragingResult)
                .animation(.snappy, value: hasScenarioResult)
                // 切换模式时收起键盘，避免键盘收起与内容过渡叠加产生跳动
                .onChange(of: mode) { _, _ in
                    focusedField = nil
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .background(Color(.systemGroupedBackground))
            // Hidden per user request: no navigation bar on the calculator page
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - 交易盈亏（买入价 + 卖出价 → 净利润，可存历史）

    // 分组小标题（灰色小字，参考风格）
    private func sectionCaption(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
    }

    private var tradeSection: some View {
        VStack(spacing: 12) {
            // Input Card
            VStack(spacing: 0) {
                InputRow(field: .stockCode, focusedField: $focusedField, icon: "number.circle.fill", iconColor: .blue,  title: "code", placeholder: "xxxxxx", text: $stockCode, keyboardType: .numberPad)
                rowDivider
                InputRow(field: .buyPrice, focusedField: $focusedField, icon: "arrow.down.circle.fill", iconColor: .red, title: "Buy", placeholder: "0.000", text: $buyPrice, unit: "", keyboardType: .decimalPad)
                rowDivider
                InputRow(field: .sellPrice, focusedField: $focusedField, icon: "arrow.up.circle.fill", iconColor: .green, title: "Sell", placeholder: "0.000", text: $sellPrice, unit: "", keyboardType: .decimalPad)
                rowDivider
                InputRow(field: .shares, focusedField: $focusedField, icon: "chart.bar", title: "Num", placeholder: "0", text: $shares, unit: "", keyboardType: .numberPad)
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            if let result = currentResult {
                ResultView(result: result)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                sectionCaption("交易")
                TradeStatsCard(result: result)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                sectionCaption("交易费用")
                FeeBreakdownView(fees: result.fees, settings: viewModel.settings)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                Button(action: saveTrade) {
                    Label(
                        showSaveSuccess ? "已保存" : "保存记录",
                        systemImage: showSaveSuccess ? "checkmark.circle.fill" : "square.and.arrow.down"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 54)
                    .contentTransition(.symbolEffect(.replace.byLayer.downUp))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .tint(showSaveSuccess ? .green : .blue)
                // 成功反馈期间禁止重复保存
                .disabled(showSaveSuccess)
                .padding(.horizontal)
                .padding(.bottom, 32)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - 加仓成本（持仓 + 加仓 → 摊薄成本，仅即时测算不入历史）

    private var averagingSection: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                InputRow(field: .positionCost, focusedField: $focusedField, icon: "dollarsign.circle", iconColor: .blue, title: "成本", placeholder: "0.000", text: $positionCost, unit: "", keyboardType: .decimalPad)
                rowDivider
                InputRow(field: .positionShares, focusedField: $focusedField, icon: "shippingbox", iconColor: .blue, title: "股数", placeholder: "0", text: $positionShares, unit: "", keyboardType: .numberPad)
                rowDivider
                InputRow(field: .addPrice, focusedField: $focusedField, icon: "plus.circle.fill", iconColor: .orange, title: "加仓价", placeholder: "0.000", text: $addPrice, unit: "", keyboardType: .decimalPad)
                rowDivider
                InputRow(field: .addShares, focusedField: $focusedField, icon: "plus.square", iconColor: .orange, title: "加仓数", placeholder: "0", text: $addShares, unit: "", keyboardType: .numberPad)
                rowDivider
                InputRow(field: .currentPrice, focusedField: $focusedField, icon: "chart.line.uptrend.xyaxis", title: "当前市价", placeholder: "0.000", text: $currentPrice, unit: "", keyboardType: .decimalPad)
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            if let result = averagingResult {
                AveragingResultView(result: result)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .padding(.bottom, 32)
            }
        }
    }

    // MARK: - 涨跌推演（基准价 + 涨跌幅滑杆 → 目标价/收益，仅即时测算不入历史）

    private var scenarioSection: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                InputRow(field: .probeBasePrice, focusedField: $focusedField, icon: "dollarsign.circle", iconColor: .blue, title: "基准价", placeholder: "0.000", text: $probeBasePrice, unit: "", keyboardType: .decimalPad)
                rowDivider
                InputRow(field: .probeShares, focusedField: $focusedField, icon: "chart.bar", title: "股数", placeholder: "选填", text: $probeShares, unit: "", keyboardType: .numberPad)
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            if let base = scenarioBasePrice {
                // 涨跌幅滑杆（A 股主板日常波动区间 ±10%）
                VStack(spacing: 10) {
                    HStack {
                        Text("涨跌幅")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%+.1f%%", probePercent))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(probePercent > 0 ? .red : (probePercent < 0 ? .green : .secondary))
                    }

                    Slider(value: $probePercent, in: -10...10, step: 0.1)

                    HStack {
                        Text("-10%")
                        Spacer()
                        Text("0%")
                        Spacer()
                        Text("+10%")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .top)))

                ScenarioResultView(basePrice: base, percent: probePercent, shares: Double(probeShares).flatMap { $0 > 0 ? $0 : nil })
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .padding(.bottom, 32)
            }
        }
    }

    // 行间全宽细分隔线
    private var rowDivider: some View {
        Divider()
    }

    private var currentResult: CalculationResult? {
        guard let bp = Double(buyPrice), bp > 0,
              let sp = Double(sellPrice), sp > 0,
              let sh = Double(shares), sh > 0 else {
            return nil
        }
        return viewModel.calculate(buyPrice: bp, sellPrice: sp, shares: sh)
    }

    private var averagingResult: AveragingResult? {
        guard let pc = Double(positionCost), pc > 0,
              let ps = Double(positionShares), ps > 0,
              let ap = Double(addPrice), ap > 0,
              let ash = Double(addShares), ash > 0 else {
            return nil
        }
        let cp = Double(currentPrice).flatMap { $0 > 0 ? $0 : nil }
        return viewModel.calculateAveraging(positionCost: pc, positionShares: ps, addPrice: ap, addShares: ash, currentPrice: cp)
    }

    // 推演有效基准价（>0 才展示滑杆与结果）
    private var scenarioBasePrice: Double? {
        Double(probeBasePrice).flatMap { $0 > 0 ? $0 : nil }
    }

    private func saveTrade() {
        guard let bp = Double(buyPrice), let sp = Double(sellPrice), let sh = Double(shares), let result = currentResult else { return }

        viewModel.saveRecord(stockCode: stockCode, buyPrice: bp, sellPrice: sp, shares: sh, result: result)

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.snappy) {
            showSaveSuccess = true
        }

        // 记录本次输入的快照；反馈期间用户若已开始输入新数据，则不覆盖
        let snapshot = (stockCode, buyPrice, sellPrice, shares)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.snappy) {
                showSaveSuccess = false
            }
            guard (stockCode, buyPrice, sellPrice, shares) == snapshot else { return }
            stockCode = ""
            buyPrice = ""
            sellPrice = ""
            shares = ""
            // 焦点回到第一行，便于立即开始下一笔计算
            focusedField = .buyPrice
        }
    }
}

// MARK: - Input

struct InputRow: View {
    @EnvironmentObject var viewModel: TradeViewModel
    let field: CalculatorField
    @FocusState.Binding var focusedField: CalculatorField?
    var icon: String? = nil
    var iconColor: Color = .secondary
    let title: String
    let placeholder: String
    @Binding var text: String
    var unit: String? = nil
    var keyboardType: UIKeyboardType = .default

    // 行水平内边距
    static let rowPadding: CGFloat = 16

    var body: some View {
        // 标签在上、数值在下（参考风格），行间全宽细分隔线
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(iconColor)
                }
                Text(LocalizedStringKey(title))
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let unit = unit, !unit.isEmpty {
                    Text(LocalizedStringKey(unit))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            PlainTextField(
                text: $text,
                placeholder: viewModel.localized(placeholder),
                keyboardType: keyboardType,
                focusedField: $focusedField,
                field: field,
                font: .preferredFont(forTextStyle: .title3),
                textAlignment: .left
            )
        }
        .padding(.horizontal, InputRow.rowPadding)
        .padding(.vertical, 10)
    }
}

// 无边框输入框：iOS 26 系统 TextField 只有下划线/边框两种样式，用 UITextField 自绘干净的无框样式
struct PlainTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var keyboardType: UIKeyboardType
    // 计算器页传焦点绑定做自动聚焦；其他页面（如设置）可省略
    var focusedField: FocusState<CalculatorField?>.Binding? = nil
    var field: CalculatorField? = nil
    var font: UIFont = .preferredFont(forTextStyle: .body)
    var textAlignment: NSTextAlignment = .right
    var textColor: UIColor? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.borderStyle = .none
        tf.backgroundColor = .clear
        tf.textAlignment = textAlignment
        tf.font = font
        tf.keyboardType = keyboardType
        tf.delegate = context.coordinator
        return tf
    }

    func updateUIView(_ tf: UITextField, context: Context) {
        context.coordinator.parent = self
        if tf.text != text { tf.text = text }
        tf.placeholder = placeholder
        tf.keyboardType = keyboardType
        tf.font = font
        tf.textAlignment = textAlignment
        tf.textColor = textColor ?? .label
        // 与 SwiftUI 焦点状态同步：仅在“目标焦点发生变化”时才调用 UIKit 焦点 API。
        // 每敲一个字符都会走一次 updateUIView，若每次都 become/resign，
        // Mac Catalyst 上会引发焦点抖动，表现为一输入就失焦、需重新点选。
        guard let focusedField, let field else { return }
        let coordinator = context.coordinator
        let active = focusedField.wrappedValue == field
        if active == coordinator.focusSynced { return }
        coordinator.focusSynced = active
        if active {
            guard !tf.isFirstResponder else { return }
            // 异步请求焦点，避开 SwiftUI 渲染/键盘过渡窗口；执行前再校验目标，期间焦点已改属他人则放弃
            DispatchQueue.main.async {
                guard !tf.isFirstResponder, focusedField.wrappedValue == field else { return }
                tf.becomeFirstResponder()
            }
        } else if tf.isFirstResponder {
            tf.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: PlainTextField
        // 上次同步给 UIKit 的焦点状态；与当前一致则跳过，避免打字期间反复调用焦点 API
        var focusSynced = false
        init(parent: PlainTextField) { self.parent = parent }

        func textFieldDidBeginEditing(_ tf: UITextField) {
            if let field = parent.field {
                parent.focusedField?.wrappedValue = field
            }
        }
        func textFieldDidEndEditing(_ tf: UITextField) {
            if let field = parent.field, parent.focusedField?.wrappedValue == field {
                parent.focusedField?.wrappedValue = nil
            }
        }
        func textFieldDidChangeSelection(_ tf: UITextField) {
            parent.text = tf.text ?? ""
        }
    }
}

// MARK: - Result

// 蓝色渐变主卡（参考风格：白色文字 + 细分隔线页脚行）
struct BlueHeroCard<Content: View, Footer: View>: View {
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)

            Divider().background(Color.white.opacity(0.35))

            footer
                .foregroundColor(.white)
                .padding(.horizontal)
                .padding(.vertical, 12)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.52, blue: 1.0), Color(red: 0.19, green: 0.63, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

struct ResultView: View {
    @EnvironmentObject var viewModel: TradeViewModel
    let result: CalculationResult

    // 盈亏平衡价：卖出收入恰好覆盖买入金额与全部费用时的最低卖出价
    private var breakevenPrice: Double {
        result.shares > 0 ? (result.buyAmount + result.fees.total) / result.shares : 0
    }

    var body: some View {
        BlueHeroCard {
            // 净利润 + 收益率
            VStack(spacing: 8) {
                Text("净利润")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.85))

                Text(viewModel.localizedFormat("净利润格式", result.netProfit >= 0 ? "+" : "-", abs(result.netProfit)))
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .foregroundColor(.white)
                    .textSelection(.enabled)

                Text(viewModel.localizedFormat("收益率格式", result.returnRate >= 0 ? "+" : "", result.returnRate))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.25))
                    .clipShape(Capsule())
            }
        } footer: {
            HStack {
                Text("盈亏平衡价").font(.subheadline)
                Spacer()
                Text(String(format: "¥%.3f", breakevenPrice))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
    }
}

// 「交易」统计卡：标签在左、数值在右的行列表
struct TradeStatsCard: View {
    @EnvironmentObject var viewModel: TradeViewModel
    let result: CalculationResult

    var body: some View {
        VStack(spacing: 0) {
            statRow("买入成本", String(format: "¥%.3f", result.buyAmount), color: nil)
            Divider().padding(.leading)
            statRow("卖出金额", String(format: "¥%.3f", result.sellAmount), color: nil)
            Divider().padding(.leading)
            statRow(
                "毛利润",
                viewModel.localizedFormat("毛利润格式", result.grossProfit >= 0 ? "+" : "-", abs(result.grossProfit)),
                color: result.grossProfit > 0 ? .red : (result.grossProfit < 0 ? .green : .secondary)
            )
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func statRow(_ title: LocalizedStringKey, _ value: String, color: Color?) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.subheadline).fontWeight(.semibold)
                .foregroundColor(color ?? .primary)
        }
        .padding(.horizontal)
        .padding(.vertical, 13)
    }
}

// MARK: - Fee Breakdown

struct FeeBreakdownView: View {
    @EnvironmentObject var viewModel: TradeViewModel
    let fees: FeeBreakdown
    let settings: FeeSettings

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("费用明细")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()

            // Buy Fees
            FeeSection(title: "买入费用", color: .blue, subtotal: fees.buyCommission + fees.buyTransferFee, items: [
                ("买入佣金", fees.buyCommission, viewModel.localizedFormat("佣金说明格式", "\(settings.commissionRate)", "\(settings.minCommission)")),
                ("过户费", fees.buyTransferFee, viewModel.localizedFormat("过户说明格式", "\(settings.transferFeeRate)"))
            ])

            // Sell Fees
            FeeSection(title: "卖出费用", color: .orange, subtotal: fees.sellCommission + fees.stampDuty + fees.sellTransferFee, items: [
                ("卖出佣金", fees.sellCommission, viewModel.localizedFormat("佣金说明格式", "\(settings.commissionRate)", "\(settings.minCommission)")),
                ("印花税", fees.stampDuty, viewModel.localizedFormat("印花说明格式", "\(settings.stampDutyRate)")),
                ("过户费", fees.sellTransferFee, viewModel.localizedFormat("过户说明格式", "\(settings.transferFeeRate)"))
            ])

            // Total
            HStack {
                Text("合计费用").fontWeight(.semibold)
                Spacer()
                Text(String(format: "¥%.3f", fees.total)).fontWeight(.bold)
            }
            .padding()
            .background(Color(.systemGray6))
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

struct FeeSection: View {
    let title: String
    let color: Color
    let subtotal: Double
    let items: [(String, Double, String)]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Rectangle().fill(color).frame(width: 3, height: 13).cornerRadius(1.5)
                Text(LocalizedStringKey(title)).font(.footnote).fontWeight(.semibold)
                Spacer()
                Text(String(format: "¥%.3f", subtotal)).font(.footnote).foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(color.opacity(0.1))

            ForEach(items, id: \.0) { item in
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey(item.0)).font(.subheadline)
                            Text(item.2).font(.caption2).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(String(format: "¥%.3f", item.1)).font(.subheadline)
                    }
                    .padding(.horizontal)
                    .padding(.leading, 12)
                    .padding(.vertical, 9)

                    Divider().padding(.leading)
                }
            }
        }
    }
}

// MARK: - Averaging Result

struct AveragingResultView: View {
    @EnvironmentObject var viewModel: TradeViewModel
    let result: AveragingResult

    var body: some View {
        VStack(spacing: 12) {
            // 蓝色渐变主卡：平均成本 + 总股数页脚行
            BlueHeroCard {
                VStack(spacing: 8) {
                    Text("平均成本")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.85))

                    Text(String(format: "¥%.3f", result.averageCost))
                        .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                        .foregroundColor(.white)
                        .textSelection(.enabled)
                }
            } footer: {
                HStack {
                    Text("总股数").font(.subheadline)
                    Spacer()
                    Text(String(format: "%.0f 股", result.totalShares))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            // 「交易」明细卡
            VStack(spacing: 0) {
                statRow("总投入", String(format: "¥%.3f", result.totalInvested), color: nil)
                Divider().padding(.leading)
                statRow("加仓金额", String(format: "¥%.3f", result.addAmount), color: nil)
                Divider().padding(.leading)
                statRow("新买入费用", String(format: "¥%.3f", result.newBuyFee), color: nil)

                // 浮动盈亏（填了当前市价时显示，红涨绿跌）
                if let profit = result.unrealizedProfit, let rate = result.unrealizedRate {
                    Divider().padding(.leading)
                    HStack {
                        Text("浮动盈亏")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(viewModel.localizedFormat("浮动盈亏格式", profit >= 0 ? "+" : "-", abs(profit), rate >= 0 ? "+" : "", rate))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(profit > 0 ? .red : (profit < 0 ? .green : .secondary))
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 13)
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }

    private func statRow(_ title: LocalizedStringKey, _ value: String, color: Color?) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.subheadline).fontWeight(.semibold)
                .foregroundColor(color ?? .primary)
        }
        .padding(.horizontal)
        .padding(.vertical, 13)
    }
}

// MARK: - Scenario Result

// 涨跌推演结果：目标价主卡 + 收益明细卡（毛收益，未扣手续费）
struct ScenarioResultView: View {
    @EnvironmentObject var viewModel: TradeViewModel
    let basePrice: Double
    let percent: Double      // 涨跌幅 %
    let shares: Double?      // 持股数量（选填）

    private var targetPrice: Double { basePrice * (1 + percent / 100) }
    private var priceDiff: Double { targetPrice - basePrice }

    var body: some View {
        VStack(spacing: 12) {
            // 蓝色渐变主卡：目标价 + 涨跌幅
            BlueHeroCard {
                VStack(spacing: 8) {
                    Text("目标价")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.85))

                    Text(String(format: "¥%.3f", targetPrice))
                        .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                        .foregroundColor(.white)
                        .textSelection(.enabled)

                    Text(String(format: "%+.1f%%", percent))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.25))
                        .clipShape(Capsule())
                }
            } footer: {
                HStack {
                    Text("涨跌额").font(.subheadline)
                    Spacer()
                    Text(viewModel.localizedFormat("毛利润格式", priceDiff >= 0 ? "+" : "-", abs(priceDiff)))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            // 收益明细卡：填了股数显示预计收益/市值，否则提示输入股数
            VStack(spacing: 0) {
                if let shares {
                    let profit = priceDiff * shares
                    statRow(
                        "预计收益",
                        viewModel.localizedFormat("净利润格式", profit >= 0 ? "+" : "-", abs(profit)),
                        color: profit > 0 ? .red : (profit < 0 ? .green : .secondary)
                    )
                    Divider().padding(.leading)
                    statRow("持仓市值", String(format: "¥%.3f", targetPrice * shares), color: nil)
                } else {
                    Text("输入股数看收益")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.vertical, 13)
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }

    private func statRow(_ title: LocalizedStringKey, _ value: String, color: Color?) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.subheadline).fontWeight(.semibold)
                .foregroundColor(color ?? .primary)
        }
        .padding(.horizontal)
        .padding(.vertical, 13)
    }
}
