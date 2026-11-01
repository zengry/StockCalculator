import SwiftUI

// MARK: - 输入焦点

enum CalculatorField: Hashable {
    case stockCode, buyPrice, sellPrice, shares
    case positionCost, positionShares, addPrice, addShares
    case probeBasePrice, probeShares
}

// MARK: - 计算模式

enum CalculatorMode: String, CaseIterable, Identifiable {
    case trade = "Profit"
    case averaging = "Add Stock"
    case scenario = "推演"

    var id: String { rawValue }
}

// MARK: - 计算器

struct CalculatorView: View {
    @EnvironmentObject private var viewModel: TradeViewModel

    @State private var mode: CalculatorMode = .trade
    @FocusState private var focusedField: CalculatorField?

    // 交易盈亏
    @State private var stockCode = ""
    @State private var buyPrice = ""
    @State private var sellPrice = ""
    @State private var shares = ""
    @State private var sharesInHands = false   // 股数按"手"输入（1 手 = 100 股）
    @State private var didSave = false
    @State private var saveCount = 0
    @State private var feesExpanded = false   // 费用明细默认折叠，渐进披露

    // 加仓成本
    @State private var positionCost = ""
    @State private var positionShares = ""
    @State private var positionSharesInHands = false
    @State private var addPrice = ""
    @State private var addShares = ""
    @State private var addSharesInHands = false

    // 涨跌推演
    @State private var probeBasePrice = ""
    @State private var probeShares = ""
    @State private var probeSharesInHands = false
    @State private var probePercent: Double = 0

    private var hasTradeResult: Bool { currentResult != nil }
    private var hasAveragingResult: Bool { averagingResult != nil }
    private var hasScenarioResult: Bool { scenarioBasePrice != nil }

    var body: some View {
        Form {
            Section {
                Picker("计算模式", selection: $mode) {
                    ForEach(CalculatorMode.allCases) { item in
                        Text(LocalizedStringKey(item.rawValue)).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(minHeight: 44)
                .accessibilityLabel("计算模式")
            }

            switch mode {
            case .trade:
                tradeSection
            case .averaging:
                averagingSection
            case .scenario:
                scenarioSection
            }
        }
        .navigationTitle("计算器")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: mode) { _, _ in
            focusedField = nil
        }
        .onChange(of: viewModel.settings.scenarioLimit) { _, limit in
            // 幅度上限改小后，当前涨跌幅夹取到新范围内
            probePercent = min(max(probePercent, -Double(limit)), Double(limit))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: mode)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hasTradeResult)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hasAveragingResult)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hasScenarioResult)
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if currentResult != nil {
                saveButton
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.bar)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    focusedField = nil
                }
                .accessibilityLabel("完成输入")
            }
        }
    }

    // MARK: 交易盈亏

    private var tradeSection: some View {
        Group {
            Section {
                // 2×2 紧凑布局：买入｜卖出 一行，代码｜股数 一行
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        TradeInputCell(title: "买入", systemImage: "arrow.down.circle") {
                            TextField("", text: $buyPrice, prompt: Text("0.000"))
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .buyPrice)
                                .multilineTextAlignment(.trailing)
                                .accessibilityLabel("买入价")
                        }
                        TradeColumnDivider()
                        TradeInputCell(title: "卖出", systemImage: "arrow.up.circle") {
                            TextField("", text: $sellPrice, prompt: Text("0.000"))
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .sellPrice)
                                .multilineTextAlignment(.trailing)
                                .accessibilityLabel("卖出价")
                        }
                    }
                    .frame(minHeight: 52)

                    Divider()

                    HStack(spacing: 0) {
                        TradeInputCell(title: "代码", systemImage: "number") {
                            TextField("", text: $stockCode, prompt: Text("xxxxxx"))
                                .keyboardType(.numberPad)
                                .textInputAutocapitalization(.characters)
                                .focused($focusedField, equals: .stockCode)
                                .multilineTextAlignment(.trailing)
                                .accessibilityLabel("股票代码")
                        }
                        TradeColumnDivider()
                        TradeInputCell(title: "股数", systemImage: "chart.bar") {
                            SharesField(text: $shares, inHands: $sharesInHands, focus: $focusedField, field: .shares)
                                .accessibilityLabel("股数")
                        }
                    }
                    .frame(minHeight: 52)
                }
            } header: {
                Label("交易", systemImage: "arrow.left.arrow.right")
            }

            if let result = currentResult {
                // 结果主卡（hero）：全屏最大的答案，红绿分明的强调数字 + 左侧色条
                Section {
                    TradeResultHero(result: result)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // 明细：结果主卡的从属数据，退为次级层级（避免与 hero 抢视觉权重）
                Section {
                    LabeledContent("买入成本") {
                        Text(String(format: "¥%.3f", result.buyAmount))
                            .foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 44)

                    LabeledContent("卖出金额") {
                        Text(String(format: "¥%.3f", result.sellAmount))
                            .foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 44)

                    LabeledContent("毛利润") {
                        Text(viewModel.localizedFormat("毛利润格式", result.grossProfit >= 0 ? "+" : "-", abs(result.grossProfit)))
                            .fontWeight(.semibold)
                            .foregroundStyle(PnLStyle.color(result.grossProfit))
                    }
                    .frame(minHeight: 44)

                    LabeledContent("盈亏平衡价") {
                        Text(String(format: "¥%.3f", viewModel.breakevenPrice(for: result)))
                            .fontWeight(.semibold)
                    }
                    .frame(minHeight: 44)
                } header: {
                    Label("明细", systemImage: "doc.text.magnifyingglass")
                }

                // 费用明细：渐进披露，默认折叠，明确从属于结果
                Section {
                    DisclosureGroup(isExpanded: $feesExpanded) {
                        FeeRow(
                            title: "买入佣金",
                            amount: result.fees.buyCommission,
                            note: viewModel.localizedFormat("佣金说明格式", "\(viewModel.settings.commissionRate)", "\(viewModel.settings.minCommission)")
                        )
                        FeeRow(
                            title: "过户费",
                            amount: result.fees.buyTransferFee,
                            note: viewModel.localizedFormat("过户说明格式", "\(viewModel.settings.transferFeeRate)")
                        )
                        FeeRow(
                            title: "卖出佣金",
                            amount: result.fees.sellCommission,
                            note: viewModel.localizedFormat("佣金说明格式", "\(viewModel.settings.commissionRate)", "\(viewModel.settings.minCommission)")
                        )
                        FeeRow(
                            title: "印花税",
                            amount: result.fees.stampDuty,
                            note: viewModel.localizedFormat("印花说明格式", "\(viewModel.settings.stampDutyRate)")
                        )
                        FeeRow(
                            title: "过户费",
                            amount: result.fees.sellTransferFee,
                            note: viewModel.localizedFormat("过户说明格式", "\(viewModel.settings.transferFeeRate)")
                        )

                        LabeledContent("合计费用") {
                            Text(String(format: "¥%.3f", result.fees.total))
                                .fontWeight(.bold)
                        }
                        .frame(minHeight: 44)
                    } label: {
                        Label("费用明细", systemImage: "list.bullet")
                    }
                }
            }
        }
    }

    // MARK: 保存按钮（底部固定，独立于滚动内容）

    /// 主操作：保存当前交易记录。固定在底部安全区，始终可达；
    /// 不作为 Form 分组卡片内的全宽胶囊，避免与卡片圆角冲突产生“异形”。
    private var saveButton: some View {
        Button(action: saveTrade) {
            Label(
                didSave ? "已保存" : "保存记录",
                systemImage: didSave ? "checkmark.circle.fill" : "square.and.arrow.down"
            )
            .font(.headline)
        }
        .frame(maxWidth: .infinity, minHeight: 50)
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(didSave)
        .sensoryFeedback(.success, trigger: saveCount)
        .accessibilityLabel(didSave ? "已保存" : "保存记录")
    }

    // MARK: 加仓成本

    private var averagingSection: some View {
        Group {
            Section {
                // 一行：持仓成本｜持仓股数（已删除"当前市价"）
                HStack(spacing: 0) {
                    TradeInputCell(title: "持仓成本", systemImage: "dollarsign.circle") {
                        TextField("", text: $positionCost, prompt: Text("0.000"))
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .positionCost)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("持仓成本")
                    }
                    TradeColumnDivider()
                    TradeInputCell(title: "持仓股数", systemImage: "chart.bar") {
                        SharesField(text: $positionShares, inHands: $positionSharesInHands, focus: $focusedField, field: .positionShares)
                            .accessibilityLabel("持仓股数")
                    }
                }
                .frame(minHeight: 52)
            } header: {
                Label("持仓", systemImage: "shippingbox")
            }

            Section {
                // 一行：加仓价｜加仓股数
                HStack(spacing: 0) {
                    TradeInputCell(title: "加仓价", systemImage: "plus.circle") {
                        TextField("", text: $addPrice, prompt: Text("0.000"))
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .addPrice)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("加仓价")
                    }
                    TradeColumnDivider()
                    TradeInputCell(title: "加仓股数", systemImage: "plus.square") {
                        SharesField(text: $addShares, inHands: $addSharesInHands, focus: $focusedField, field: .addShares)
                            .accessibilityLabel("加仓股数")
                    }
                }
                .frame(minHeight: 52)
            } header: {
                Label("加仓", systemImage: "plus.circle")
            }

            if let result = averagingResult {
                Section {
                    LabeledContent("平均成本") {
                        Text(String(format: "¥%.3f", result.averageCost))
                            .font(.title3.weight(.bold))
                    }
                    .frame(minHeight: 48)

                    LabeledContent("总股数") {
                        Text(viewModel.localizedFormat("总股数格式", "\(Int(result.totalShares))"))
                            .fontWeight(.semibold)
                    }
                    .frame(minHeight: 44)

                    LabeledContent("总投入") {
                        Text(String(format: "¥%.3f", result.totalInvested))
                            .foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 44)

                    LabeledContent("加仓金额") {
                        Text(String(format: "¥%.3f", result.addAmount))
                            .foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 44)

                    LabeledContent("新买入费用") {
                        Text(String(format: "¥%.3f", result.newBuyFee))
                            .foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 44)

                    if let profit = result.unrealizedProfit, let rate = result.unrealizedRate {
                        LabeledContent("浮动盈亏") {
                            Text(viewModel.localizedFormat("浮动盈亏格式", profit >= 0 ? "+" : "-", abs(profit), rate >= 0 ? "+" : "", rate))
                                .fontWeight(.semibold)
                                .foregroundStyle(PnLStyle.color(profit))
                        }
                        .frame(minHeight: 44)
                    }
                } header: {
                    Label("平均成本", systemImage: "chart.pie")
                }
            }
        }
    }

    // MARK: 涨跌推演

    private var scenarioSection: some View {
        Group {
            Section {
                // 一行：基准价｜股数
                HStack(spacing: 0) {
                    TradeInputCell(title: "基准价", systemImage: "dollarsign.circle") {
                        TextField("", text: $probeBasePrice, prompt: Text("0.000"))
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .probeBasePrice)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("基准价")
                    }
                    TradeColumnDivider()
                    TradeInputCell(title: "股数", systemImage: "chart.bar") {
                        SharesField(text: $probeShares, inHands: $probeSharesInHands, prompt: "选填", focus: $focusedField, field: .probeShares)
                            .accessibilityLabel("股数")
                    }
                }
                .frame(minHeight: 52)
            } header: {
                Label("推演", systemImage: "chart.line.uptrend.xyaxis")
            }

            if let basePrice = scenarioBasePrice {
                Section {
                    // 一行：滑块(左，约 80%) ｜ 涨跌幅(右)
                    HStack(spacing: 12) {
                        Slider(value: $probePercent, in: -probeLimit...probeLimit, step: 0.1)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("涨跌幅")
                            .accessibilityValue(Text(String(format: "%+.1f%%", probePercent)))

                        Text(String(format: "%+.1f%%", probePercent))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PnLStyle.color(probePercent))
                            .monospacedDigit()
                            .frame(minWidth: 64, maxWidth: 88, alignment: .trailing)
                            .accessibilityHidden(true) // 数值已由滑块的 accessibilityValue 播报
                    }
                    .frame(minHeight: 44)
                } header: {
                    Label("涨跌幅", systemImage: "slider.horizontal.3")
                }

                Section {
                    // 2×2：目标价｜涨跌额 一行，预计收益｜持仓市值 一行
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            TradeReadoutCell(title: "目标价", value: String(format: "¥%.3f", basePrice * (1 + probePercent / 100)), emphasize: true)
                            TradeColumnDivider()
                            TradeReadoutCell(
                                title: "涨跌额",
                                value: viewModel.localizedFormat("毛利润格式", priceDiff(basePrice: basePrice) >= 0 ? "+" : "-", abs(priceDiff(basePrice: basePrice))),
                                valueColor: PnLStyle.color(priceDiff(basePrice: basePrice))
                            )
                        }
                        .frame(minHeight: 52)

                        Divider()

                        if let shares = effectiveShares(probeShares, inHands: probeSharesInHands) {
                            let profit = priceDiff(basePrice: basePrice) * shares
                            HStack(spacing: 0) {
                                TradeReadoutCell(
                                    title: "预计收益",
                                    value: viewModel.localizedFormat("净利润格式", profit >= 0 ? "+" : "-", abs(profit)),
                                    valueColor: PnLStyle.color(profit)
                                )
                                TradeColumnDivider()
                                TradeReadoutCell(
                                    title: "持仓市值",
                                    value: String(format: "¥%.3f", basePrice * (1 + probePercent / 100) * shares),
                                    valueColor: Color.secondary
                                )
                            }
                            .frame(minHeight: 52)
                        } else {
                            Text("输入股数看收益")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(minHeight: 52)
                        }
                    }
                } header: {
                    Label("目标价", systemImage: "flag.checkered")
                }
            }
        }
    }

    // MARK: 计算

    // 股数上限（手/股来自设置）
    private var probeLimit: Double { Double(viewModel.settings.scenarioLimit) }

    // 股数输入统一换算：开启"手"时 1 手 = 100 股
    private func effectiveShares(_ text: String, inHands: Bool) -> Double? {
        guard let value = Double(text), value > 0 else { return nil }
        let shares = inHands ? value * 100 : value
        return shares > 0 ? shares : nil
    }

    private var currentResult: CalculationResult? {
        guard let buy = Double(buyPrice), buy > 0,
              let sell = Double(sellPrice), sell > 0,
              let count = effectiveShares(shares, inHands: sharesInHands) else {
            return nil
        }
        return viewModel.calculate(buyPrice: buy, sellPrice: sell, shares: count)
    }

    private var averagingResult: AveragingResult? {
        guard let cost = Double(positionCost), cost > 0,
              let held = effectiveShares(positionShares, inHands: positionSharesInHands),
              let price = Double(addPrice), price > 0,
              let count = effectiveShares(addShares, inHands: addSharesInHands) else {
            return nil
        }
        return viewModel.calculateAveraging(positionCost: cost, positionShares: held, addPrice: price, addShares: count, currentPrice: nil)
    }

    private var scenarioBasePrice: Double? {
        Double(probeBasePrice).flatMap { $0 > 0 ? $0 : nil }
    }

    private func priceDiff(basePrice: Double) -> Double {
        basePrice * probePercent / 100
    }

    private func saveTrade() {
        guard let buy = Double(buyPrice),
              let sell = Double(sellPrice),
              let count = effectiveShares(shares, inHands: sharesInHands),
              let result = currentResult else {
            return
        }

        viewModel.saveRecord(stockCode: stockCode, buyPrice: buy, sellPrice: sell, shares: count, result: result)
        saveCount += 1

        let snapshot = (stockCode, buyPrice, sellPrice, shares)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            didSave = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                didSave = false
            }
            guard (stockCode, buyPrice, sellPrice, shares) == snapshot else { return }
            stockCode = ""
            buyPrice = ""
            sellPrice = ""
            shares = ""
            focusedField = .buyPrice
        }
    }
}

// MARK: - 交易输入单元（2×2 紧凑布局）

/// 交易区每个输入格：小标签在上、输入在下，左对齐；
/// 中性 secondary 色，把颜色预算留给红绿盈亏主卡。
private struct TradeInputCell<Content: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 两列之间的竖向分隔线
private struct TradeColumnDivider: View {
    var body: some View {
        Divider()
            .frame(maxHeight: 44)
            .padding(.horizontal, 14)
    }
}

/// 结果只读单元：小标签在上、数值在下（与 TradeInputCell 视觉对齐）
private struct TradeReadoutCell: View {
    let title: LocalizedStringKey
    let value: String
    var valueColor: Color? = nil
    var emphasize: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(emphasize ? .title3.weight(.bold) : .subheadline.weight(.semibold))
                .foregroundStyle(valueColor ?? .primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 股数输入（支持"手/股"切换，1 手 = 100 股）

private struct SharesField: View {
    @Binding var text: String
    @Binding var inHands: Bool
    var prompt: LocalizedStringKey = "0"
    var focus: FocusState<CalculatorField?>.Binding
    var field: CalculatorField

    var body: some View {
        HStack(spacing: 8) {
            TextField("", text: $text, prompt: Text(prompt))
                .keyboardType(.numberPad)
                .focused(focus, equals: field)
                .multilineTextAlignment(.trailing)
                .labelsHidden()

            // 手/股切换：切换时按 1 手 = 100 股换算已有输入
            Button {
                let converted = Self.converted(text, toHands: !inHands)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    text = converted
                    inHands.toggle()
                }
            } label: {
                Text(LocalizedStringKey(inHands ? "手" : "股"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(inHands ? Color.white : Color.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        inHands ? AnyShapeStyle(Color.blue) : AnyShapeStyle(.quaternary),
                        in: .capsule
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("切换手或股")
            .accessibilityValue(Text(LocalizedStringKey(inHands ? "手" : "股")))
        }
    }

    /// 切换单位时换算数值：股 → 手除以 100，手 → 股乘以 100；整数去掉小数尾
    private static func converted(_ text: String, toHands: Bool) -> String {
        guard let value = Double(text), value > 0 else { return text }
        let result = toHands ? value / 100 : value * 100
        return result.rounded() == result && abs(result) < 1e15 ? String(Int(result)) : String(result)
    }
}

// MARK: - 费用行

private struct FeeRow: View {
    let title: LocalizedStringKey
    let amount: Double
    let note: String

    var body: some View {
        LabeledContent {
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "¥%.3f", amount))
                    .fontWeight(.medium)
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } label: {
            Text(title)
        }
        .frame(minHeight: 48)
    }
}

// MARK: - 结果主卡（hero）

/// 把"净利润"从 Form 的普通行里拎出来，做成全屏最大的答案区：
/// 大号等宽红绿数字 + 涨跌胶囊 + 左侧语义色条，建立明确视觉重点。
private struct TradeResultHero: View {
    let result: CalculationResult
    @EnvironmentObject private var viewModel: TradeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("净利润")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(result.netProfit >= 0 ? "盈利" : "亏损")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PnLStyle.color(result.netProfit))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(PnLStyle.color(result.netProfit).opacity(0.12), in: .capsule)
            }

            Text(viewModel.localizedFormat("净利润格式", result.netProfit >= 0 ? "+" : "-", abs(result.netProfit)))
                .font(.system(size: 38, weight: .semibold, design: .default))
                .monospacedDigit()
                .foregroundStyle(PnLStyle.color(result.netProfit))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("收益率")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(viewModel.localizedFormat("收益率格式", result.returnRate >= 0 ? "+" : "", result.returnRate))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PnLStyle.color(result.returnRate))
                    .monospacedDigit()
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: .rect(cornerRadius: 14))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(PnLStyle.color(result.netProfit))
                .frame(width: 4)
                .padding(.vertical, 18)
        }
    }
}
