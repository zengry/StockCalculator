import SwiftUI

// MARK: - 模式切换

struct ModeCardsView: View {
    @Binding var selection: CalculatorMode

    var body: some View {
        ViewThatFits(in: .horizontal) {
            cards(layout: AnyLayout(HStackLayout(spacing: 10)))
            cards(layout: AnyLayout(VStackLayout(spacing: 10)))
        }
        .accessibilityLabel("计算模式")
    }

    private func cards(layout: AnyLayout) -> some View {
        layout {
            ForEach(CalculatorMode.allCases) { item in
                ModeCard(mode: item, isSelected: selection == item) {
                    withAnimation(.snappy) {
                        selection = item
                    }
                }
            }
        }
    }
}

private struct ModeCard: View {
    let mode: CalculatorMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: mode.icon)
                    .font(.title3.weight(.medium))
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.titleKey)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(mode.subtitleKey)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay {
                        if isSelected {
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.16), Color.accentColor.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? Color.accentColor.opacity(0.42) : Color(.separator).opacity(0.18),
                        lineWidth: 1
                    )
            }
            .shadow(color: isSelected ? Color.accentColor.opacity(0.08) : .clear, radius: 5, y: 2)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - 卡片与自适应布局

struct CalculatorCard<Content: View>: View {
    private let title: LocalizedStringKey?
    private let systemImage: String?
    private let content: Content

    init(
        title: LocalizedStringKey? = nil,
        systemImage: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title {
                if let systemImage {
                    Label(title, systemImage: systemImage)
                        .font(.headline)
                } else {
                    Text(title)
                        .font(.headline)
                }
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }
}

struct AdaptiveInputFields<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                content
            }
            VStack(spacing: 16) {
                content
            }
        }
    }
}

// MARK: - 统一输入框

struct CalculatorInputField: View {
    let title: LocalizedStringKey
    let systemImage: String
    @Binding var text: String
    var prompt: LocalizedStringKey = "0.000"
    var keyboardType: UIKeyboardType = .decimalPad
    var capitalization: TextInputAutocapitalization = .never
    var focus: FocusState<CalculatorField?>.Binding
    let field: CalculatorField
    var sharesInHands: Binding<Bool>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField("", text: $text, prompt: Text(prompt))
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(capitalization)
                    .focused(focus, equals: field)
                    .multilineTextAlignment(.leading)
                    .font(.body.weight(.medium))
                    .monospacedDigit()
                    .accessibilityLabel(title)

                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清空")
                }

                if let sharesInHands {
                    Button {
                        let converted = Self.convertedShares(
                            text,
                            toHands: !sharesInHands.wrappedValue
                        )
                        withAnimation(.snappy) {
                            text = converted
                            sharesInHands.wrappedValue.toggle()
                        }
                    } label: {
                        Text(LocalizedStringKey(sharesInHands.wrappedValue ? "手" : "股"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(
                                sharesInHands.wrappedValue ? Color.accentColor : Color.secondary
                            )
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                Color.accentColor.opacity(sharesInHands.wrappedValue ? 0.14 : 0.07),
                                in: .capsule
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("切换手或股")
                    .accessibilityValue(
                        Text(LocalizedStringKey(sharesInHands.wrappedValue ? "手" : "股"))
                    )
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 48)
            .background(
                Color(.tertiarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        focus.wrappedValue == field ? Color.accentColor.opacity(0.5) : .clear,
                        lineWidth: 1
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func convertedShares(_ text: String, toHands: Bool) -> String {
        guard let value = Double(text), value > 0 else { return text }
        let result = toHands ? value / 100 : value * 100
        if result.rounded() == result, abs(result) < 1e15 {
            return String(Int(result))
        }
        return String(result)
    }
}

// MARK: - 高光结果卡

struct HighlightResultCard<Footer: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    let value: String
    let tint: Color
    var badge: LocalizedStringKey?
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                if let badge {
                    Text(badge)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(tint.opacity(0.12), in: .capsule)
                }
            }

            Text(value)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            footer
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Color(.secondarySystemGroupedBackground)
                LinearGradient(
                    colors: [tint.opacity(0.18), tint.opacity(0.055), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: tint.opacity(0.09), radius: 8, y: 3)
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}

struct ResultPill: View {
    let title: LocalizedStringKey
    let value: String
    let tint: Color
    var systemImage = "percent"

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
            Text(value)
                .fontWeight(.bold)
                .monospacedDigit()
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.10), in: .capsule)
        .accessibilityElement(children: .combine)
    }
}

struct TradeResultHero: View {
    @EnvironmentObject private var viewModel: TradeViewModel
    let result: CalculationResult

    private var tint: Color {
        PnLStyle.color(result.netProfit)
    }

    private var badge: LocalizedStringKey {
        if result.netProfit > 0 { return "盈利" }
        if result.netProfit < 0 { return "亏损" }
        return "持平"
    }

    var body: some View {
        HighlightResultCard(
            title: "净利润",
            systemImage: "dollarsign.circle.fill",
            value: viewModel.localizedFormat(
                "净利润格式",
                result.netProfit >= 0 ? "+" : "-",
                abs(result.netProfit)
            ),
            tint: tint,
            badge: badge
        ) {
            ResultPill(
                title: "收益率",
                value: viewModel.localizedFormat(
                    "收益率格式",
                    result.returnRate >= 0 ? "+" : "",
                    result.returnRate
                ),
                tint: tint
            )
        }
        .contentTransition(.numericText(value: result.netProfit))
        .animation(.snappy, value: result.netProfit)
    }
}

struct AveragingResultHero: View {
    @EnvironmentObject private var viewModel: TradeViewModel
    let result: AveragingResult

    var body: some View {
        HighlightResultCard(
            title: "摊薄成本",
            systemImage: "dollarsign.circle.fill",
            value: String(format: "%.3f", result.averageCost),
            tint: .accentColor
        ) {
            Label(
                viewModel.localizedFormat("总股数格式", "\(Int(result.totalShares))"),
                systemImage: "square.stack.3d.up"
            )
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .contentTransition(.numericText(value: result.averageCost))
        .animation(.snappy, value: result.averageCost)
    }
}

struct ScenarioResultHero: View {
    @EnvironmentObject private var viewModel: TradeViewModel
    let basePrice: Double
    let percent: Double
    let shares: Double?

    private var targetPrice: Double {
        basePrice * (1 + percent / 100)
    }

    private var priceDifference: Double {
        basePrice * percent / 100
    }

    private var tint: Color {
        percent == 0 ? .accentColor : PnLStyle.color(percent)
    }

    var body: some View {
        HighlightResultCard(
            title: "目标价",
            systemImage: "chart.line.uptrend.xyaxis",
            value: String(format: "%.3f", targetPrice),
            tint: tint
        ) {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    ResultPill(
                        title: "涨跌幅",
                        value: String(format: "%+.1f%%", percent),
                        tint: tint
                    )

                    Spacer(minLength: 8)

                    HeroMetric(
                        title: "涨跌额",
                        value: viewModel.localizedFormat(
                            "毛利润格式",
                            priceDifference >= 0 ? "+" : "-",
                            abs(priceDifference)
                        ),
                        valueColor: tint,
                        alignment: .trailing
                    )
                }

                if let shares {
                    let profit = priceDifference * shares

                    Divider()
                        .overlay(tint.opacity(0.16))

                    HStack(spacing: 16) {
                        HeroMetric(
                            title: "预计收益",
                            value: viewModel.localizedFormat(
                                "净利润格式",
                                profit >= 0 ? "+" : "-",
                                abs(profit)
                            ),
                            valueColor: PnLStyle.color(profit),
                            alignment: .leading
                        )

                        Spacer(minLength: 8)

                        HeroMetric(
                            title: "持仓市值",
                            value: String(format: "%.3f", targetPrice * shares),
                            valueColor: .primary,
                            alignment: .trailing
                        )
                    }
                } else {
                    Label("输入股数看收益", systemImage: "square.stack.3d.up")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentTransition(.numericText(value: targetPrice))
        .animation(.snappy, value: targetPrice)
    }
}

private struct HeroMetric: View {
    let title: LocalizedStringKey
    let value: String
    let valueColor: Color
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

// MARK: - 次级指标

struct MetricTile: View {
    let title: LocalizedStringKey
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .padding(12)
        .background(
            Color(.tertiarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }
}

// MARK: - 费用行

struct FeeRow: View {
    let title: LocalizedStringKey
    let amount: Double
    let note: String
    var emphasize = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(emphasize ? .body.weight(.semibold) : .body)
                if !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Text(String(format: "%.3f", amount))
                .font(emphasize ? .body.weight(.bold) : .body.weight(.medium))
                .monospacedDigit()
        }
        .frame(minHeight: 44)
    }
}

// MARK: - 涨跌控制

struct ScenarioControlCard: View {
    @Binding var percent: Double
    let limit: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tint: Color {
        percent == 0 ? .accentColor : PnLStyle.color(percent)
    }

    var body: some View {
        CalculatorCard {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Label("涨跌幅", systemImage: "percent")
                        .font(.headline)

                    Spacer()

                    Text(String(format: "%+.1f%%", percent))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(tint)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: percent))
                }

                HStack(spacing: 12) {
                    adjustmentButton(systemImage: "minus", delta: -1, label: "减少 1%")
                        .disabled(percent <= -limit)

                    Slider(value: $percent, in: -limit...limit, step: 0.1)
                        .tint(tint)
                        .accessibilityLabel("涨跌幅")
                        .accessibilityValue(Text(String(format: "%+.1f%%", percent)))

                    adjustmentButton(systemImage: "plus", delta: 1, label: "增加 1%")
                        .disabled(percent >= limit)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: Int(percent))
    }

    private func adjustmentButton(
        systemImage: String,
        delta: Double,
        label: LocalizedStringKey
    ) -> some View {
        Button {
            adjust(by: delta)
        } label: {
            Image(systemName: systemImage)
                .font(.body.weight(.bold))
                .frame(width: 44, height: 44)
                .background(
                    Color(.tertiarySystemGroupedBackground),
                    in: .circle
                )
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(label)
    }

    private func adjust(by delta: Double) {
        let adjusted = min(max(percent + delta, -limit), limit)
        withAnimation(reduceMotion ? nil : .snappy) {
            percent = (adjusted * 10).rounded() / 10
        }
    }
}
