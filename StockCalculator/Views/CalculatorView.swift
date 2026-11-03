import SwiftUI

// MARK: - 输入与模式

enum CalculatorField: Hashable {
    case stockCode, buyPrice, sellPrice, shares
    case positionCost, positionShares, addPrice, addShares
    case probeBasePrice, probeShares
}

enum CalculatorMode: String, CaseIterable, Identifiable {
    case trade, averaging, scenario

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .trade: "交易盈亏"
        case .averaging: "加仓成本"
        case .scenario: "涨跌推演"
        }
    }

    var subtitleKey: LocalizedStringKey {
        switch self {
        case .trade: "算净利润"
        case .averaging: "算平均价"
        case .scenario: "看目标收益"
        }
    }

    var icon: String {
        switch self {
        case .trade: "arrow.left.arrow.right"
        case .averaging: "plus.circle"
        case .scenario: "chart.line.uptrend.xyaxis"
        }
    }
}

// MARK: - 计算器

struct CalculatorView: View {
    @EnvironmentObject private var viewModel: TradeViewModel

    @State private var mode: CalculatorMode = .trade
    @State private var showingSettings = false
    @FocusState private var focusedField: CalculatorField?

    // 交易盈亏
    @State private var stockCode = ""
    @State private var buyPrice = ""
    @State private var sellPrice = ""
    @State private var shares = ""
    @State private var sharesInHands = false
    @State private var didSave = false
    @State private var saveCount = 0
    @State private var feesExpanded = false

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
        ScrollView {
            LazyVStack(spacing: 16) {
                ModeCardsView(selection: $mode)

                switch mode {
                case .trade:
                    tradeContent
                case .averaging:
                    averagingContent
                case .scenario:
                    scenarioContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("计算器")
        .navigationBarTitleDisplayMode(.large)
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .animation(.snappy, value: mode)
        .animation(.snappy, value: hasTradeResult)
        .animation(.snappy, value: hasAveragingResult)
        .animation(.snappy, value: hasScenarioResult)
        .sensoryFeedback(.selection, trigger: mode)
        .onChange(of: mode) { _, _ in
            focusedField = nil
        }
        .onChange(of: viewModel.settings.scenarioLimit) { _, limit in
            probePercent = min(max(probePercent, -Double(limit)), Double(limit))
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if mode == .trade, currentResult != nil {
                saveButton
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.bar)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("费率设置")
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    focusedField = nil
                }
                .accessibilityLabel("完成输入")
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") {
                                showingSettings = false
                            }
                        }
                    }
            }
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: 交易盈亏

    @ViewBuilder
    private var tradeContent: some View {
        if let result = currentResult {
            TradeResultHero(result: result)
                .transition(.move(edge: .top).combined(with: .opacity))
        }

        CalculatorCard(title: "交易参数", systemImage: "arrow.left.arrow.right") {
            VStack(spacing: 16) {
                AdaptiveInputFields {
                    CalculatorInputField(
                        title: "买入",
                        systemImage: "arrow.down.circle",
                        text: $buyPrice,
                        focus: $focusedField,
                        field: .buyPrice
                    )
                    CalculatorInputField(
                        title: "卖出",
                        systemImage: "arrow.up.circle",
                        text: $sellPrice,
                        focus: $focusedField,
                        field: .sellPrice
                    )
                }

                AdaptiveInputFields {
                    CalculatorInputField(
                        title: "代码",
                        systemImage: "number",
                        text: $stockCode,
                        prompt: "xxxxxx",
                        keyboardType: .numberPad,
                        capitalization: .characters,
                        focus: $focusedField,
                        field: .stockCode
                    )
                    CalculatorInputField(
                        title: "股数",
                        systemImage: "square.stack.3d.up",
                        text: $shares,
                        prompt: "0",
                        focus: $focusedField,
                        field: .shares,
                        sharesInHands: $sharesInHands
                    )
                }
            }
        }

        if let result = currentResult {
            CalculatorCard(title: "明细", systemImage: "doc.text.magnifyingglass") {
                LazyVGrid(columns: metricColumns, spacing: 12) {
                    MetricTile(title: "买入成本", value: number(result.buyAmount))
                    MetricTile(title: "卖出金额", value: number(result.sellAmount))
                    MetricTile(
                        title: "毛利润",
                        value: signedNumber(result.grossProfit),
                        valueColor: PnLStyle.color(result.grossProfit)
                    )
                    MetricTile(
                        title: "盈亏平衡价",
                        value: number(viewModel.breakevenPrice(for: result))
                    )
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))

            CalculatorCard {
                DisclosureGroup(isExpanded: $feesExpanded) {
                    VStack(spacing: 4) {
                        FeeRow(
                            title: "买入佣金",
                            amount: result.fees.buyCommission,
                            note: viewModel.localizedFormat(
                                "佣金说明格式",
                                "\(viewModel.settings.commissionRate)",
                                "\(viewModel.settings.minCommission)"
                            )
                        )
                        FeeRow(
                            title: "买入过户费",
                            amount: result.fees.buyTransferFee,
                            note: viewModel.localizedFormat(
                                "过户说明格式",
                                "\(viewModel.settings.transferFeeRate)"
                            )
                        )
                        FeeRow(
                            title: "卖出佣金",
                            amount: result.fees.sellCommission,
                            note: viewModel.localizedFormat(
                                "佣金说明格式",
                                "\(viewModel.settings.commissionRate)",
                                "\(viewModel.settings.minCommission)"
                            )
                        )
                        FeeRow(
                            title: "印花税",
                            amount: result.fees.stampDuty,
                            note: viewModel.localizedFormat(
                                "印花说明格式",
                                "\(viewModel.settings.stampDutyRate)"
                            )
                        )
                        FeeRow(
                            title: "卖出过户费",
                            amount: result.fees.sellTransferFee,
                            note: viewModel.localizedFormat(
                                "过户说明格式",
                                "\(viewModel.settings.transferFeeRate)"
                            )
                        )

                        Divider()
                            .padding(.vertical, 4)

                        FeeRow(
                            title: "合计费用",
                            amount: result.fees.total,
                            note: "",
                            emphasize: true
                        )
                    }
                    .padding(.top, 12)
                } label: {
                    Label("费用明细", systemImage: "list.bullet")
                        .font(.headline)
                }
                .tint(.secondary)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var saveButton: some View {
        Button(action: saveTrade) {
            Label(
                didSave ? "已保存" : "保存记录",
                systemImage: didSave ? "checkmark.circle.fill" : "square.and.arrow.down"
            )
            .font(.headline)
            .contentTransition(.symbolEffect(.replace.byLayer.downUp))
        }
        .frame(maxWidth: .infinity, minHeight: 50)
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(didSave)
        .sensoryFeedback(.success, trigger: saveCount)
        .accessibilityLabel(didSave ? "已保存" : "保存记录")
    }

    // MARK: 加仓成本

    @ViewBuilder
    private var averagingContent: some View {
        if let result = averagingResult {
            AveragingResultHero(result: result)
                .transition(.move(edge: .top).combined(with: .opacity))
        }

        CalculatorCard(title: "持仓", systemImage: "shippingbox") {
            AdaptiveInputFields {
                CalculatorInputField(
                    title: "持仓成本",
                    systemImage: "dollarsign.circle",
                    text: $positionCost,
                    focus: $focusedField,
                    field: .positionCost
                )
                CalculatorInputField(
                    title: "持仓股数",
                    systemImage: "square.stack.3d.up",
                    text: $positionShares,
                    prompt: "0",
                    focus: $focusedField,
                    field: .positionShares,
                    sharesInHands: $positionSharesInHands
                )
            }
        }

        CalculatorCard(title: "加仓", systemImage: "plus.circle") {
            AdaptiveInputFields {
                CalculatorInputField(
                    title: "加仓价",
                    systemImage: "dollarsign.circle",
                    text: $addPrice,
                    focus: $focusedField,
                    field: .addPrice
                )
                CalculatorInputField(
                    title: "加仓股数",
                    systemImage: "plus.square.on.square",
                    text: $addShares,
                    prompt: "0",
                    focus: $focusedField,
                    field: .addShares,
                    sharesInHands: $addSharesInHands
                )
            }
        }

        if let result = averagingResult {
            CalculatorCard(title: "明细", systemImage: "chart.pie") {
                LazyVGrid(columns: metricColumns, spacing: 12) {
                    MetricTile(
                        title: "总股数",
                        value: String(Int(result.totalShares))
                    )
                    MetricTile(title: "总投入", value: number(result.totalInvested))
                    MetricTile(title: "加仓金额", value: number(result.addAmount))
                    MetricTile(title: "新买入费用", value: number(result.newBuyFee))
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: 涨跌推演

    @ViewBuilder
    private var scenarioContent: some View {
        if let basePrice = scenarioBasePrice {
            ScenarioResultHero(
                basePrice: basePrice,
                percent: probePercent,
                shares: effectiveShares(probeShares, inHands: probeSharesInHands)
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }

        CalculatorCard(title: "推演", systemImage: "chart.line.uptrend.xyaxis") {
            AdaptiveInputFields {
                CalculatorInputField(
                    title: "基准价",
                    systemImage: "dollarsign.circle",
                    text: $probeBasePrice,
                    focus: $focusedField,
                    field: .probeBasePrice
                )
                CalculatorInputField(
                    title: "股数",
                    systemImage: "square.stack.3d.up",
                    text: $probeShares,
                    prompt: "选填",
                    focus: $focusedField,
                    field: .probeShares,
                    sharesInHands: $probeSharesInHands
                )
            }
        }

        if scenarioBasePrice != nil {
            ScenarioControlCard(percent: $probePercent, limit: probeLimit)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: 计算与格式化

    private var metricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 140), spacing: 12)]
    }

    private var probeLimit: Double {
        Double(viewModel.settings.scenarioLimit)
    }

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
        return viewModel.calculateAveraging(
            positionCost: cost,
            positionShares: held,
            addPrice: price,
            addShares: count,
            currentPrice: nil
        )
    }

    private var scenarioBasePrice: Double? {
        Double(probeBasePrice).flatMap { $0 > 0 ? $0 : nil }
    }

    private func number(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    private func signedNumber(_ value: Double) -> String {
        viewModel.localizedFormat("毛利润格式", value >= 0 ? "+" : "-", abs(value))
    }

    private func saveTrade() {
        guard let buy = Double(buyPrice),
              let sell = Double(sellPrice),
              let count = effectiveShares(shares, inHands: sharesInHands),
              let result = currentResult else {
            return
        }

        viewModel.saveRecord(
            stockCode: stockCode,
            buyPrice: buy,
            sellPrice: sell,
            shares: count,
            result: result
        )
        saveCount += 1

        let snapshot = (stockCode, buyPrice, sellPrice, shares)
        withAnimation(.snappy) {
            didSave = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.snappy) {
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

// MARK: - Preview

#Preview("标准") {
    NavigationStack {
        CalculatorView()
    }
    .environmentObject(TradeViewModel())
}

#Preview("深色与大字体") {
    NavigationStack {
        CalculatorView()
    }
    .environmentObject(TradeViewModel())
    .preferredColorScheme(.dark)
    .environment(\.dynamicTypeSize, .accessibility2)
}
