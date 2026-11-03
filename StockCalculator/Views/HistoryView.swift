import SwiftUI

// MARK: - 历史记录日期格式化

private enum RecordDateFormat {
    static let full: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("j:mm")
        return formatter
    }()

    static let sectionHeader: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMdEEEE")
        return formatter
    }()

    static let sectionHeaderWithYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("yMMMdEEEE")
        return formatter
    }()
}

// MARK: - 历史列表

struct HistoryView: View {
    @EnvironmentObject private var viewModel: TradeViewModel
    @Binding var selectedTab: ContentView.AppTab

    @State private var recordPendingDeletion: TradeRecord?

    // 按天分组，新的日期在前，组内新的记录在前
    private var groupedRecords: [(date: String, records: [TradeRecord])] {
        let grouped = Dictionary(grouping: viewModel.records.reversed()) { String($0.date.prefix(10)) }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (date: $0.key, records: $0.value) }
    }

    var body: some View {
        Group {
            if groupedRecords.isEmpty {
                ContentUnavailableView {
                    Label("暂无记录", systemImage: "tray")
                } description: {
                    Text("在计算器页面保存交易记录")
                } actions: {
                    Button {
                        selectedTab = .calculator
                    } label: {
                        Label("去计算", systemImage: "plus.forwardslash.minus")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            } else {
                List {
                    ForEach(groupedRecords, id: \.date) { group in
                        Section {
                            ForEach(group.records) { record in
                                NavigationLink {
                                    RecordDetailView(record: record)
                                } label: {
                                    HistoryRow(record: record)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        recordPendingDeletion = record
                                    } label: {
                                        Label("删除记录", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            sectionHeader(date: group.date, records: group.records)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .sensoryFeedback(.impact(weight: .light), trigger: viewModel.records.count)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .navigationTitle("历史记录")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            viewModel.localized("确认删除标题"),
            isPresented: Binding(
                get: { recordPendingDeletion != nil },
                set: { if !$0 { recordPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                if let record = recordPendingDeletion {
                    withAnimation(.snappy) {
                        viewModel.deleteRecord(id: record.id)
                    }
                }
                recordPendingDeletion = nil
            } label: {
                Text(LocalizedStringKey("删除记录"))
            }
            Button(role: .cancel) {
                recordPendingDeletion = nil
            } label: {
                Text(LocalizedStringKey("取消"))
            }
        } message: {
            Text(LocalizedStringKey("删除后无法恢复"))
        }
    }

    private func sectionHeader(date: String, records: [TradeRecord]) -> some View {
        let dayNet = records.reduce(0) { $0 + $1.netProfit }

        return HStack(spacing: 8) {
            if let value = RecordDateFormat.day.date(from: date) {
                Text(sectionTitle(for: value))
                    .tracking(0.5)
            } else {
                Text(date)
                    .tracking(0.5)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(viewModel.localizedFormat("笔数格式", records.count))
                Text(viewModel.localizedFormat("日盈亏格式", dayNet >= 0 ? "+" : "-", abs(dayNet)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PnLStyle.color(dayNet))
            }
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
    }

    // 今年内的记录省略年份，跨年记录补上年份
    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        let isCurrentYear = calendar.component(.year, from: date) == calendar.component(.year, from: Date())
        let template = isCurrentYear ? "MMMdEEEE" : "yMMMdEEEE"
        let formatter = isCurrentYear ? RecordDateFormat.sectionHeader : RecordDateFormat.sectionHeaderWithYear
        formatter.locale = viewModel.effectiveLocale
        // 模板在 setLocalizedDateFormatFromTemplate 调用瞬间按 locale 烘焙，
        // 事后改 locale 不会重套——必须重新套用，否则英文模式下渲染出设备 locale 格式（"11月2日 Monday"）
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
}

// MARK: - 历史记录行

private struct HistoryRow: View {
    let record: TradeRecord
    @EnvironmentObject private var viewModel: TradeViewModel

    private var timeText: String {
        guard let date = RecordDateFormat.full.date(from: record.date) else { return record.date }
        RecordDateFormat.time.locale = viewModel.effectiveLocale
        // setLocalizedDateFormatFromTemplate 只在调用瞬间按 locale 烘焙模板，
        // 事后改 locale 不会重套，需显式重新套用，否则英文模式下渲染出设备 locale 的格式
        RecordDateFormat.time.setLocalizedDateFormatFromTemplate("j:mm")
        return RecordDateFormat.time.string(from: date)
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            // 优先紧凑布局：买卖价与代码胶囊同行
            rowLayout(pricesBesideTag: true)
            // 宽度不足时降级：买卖价移到第二行，保证完整可读（不缩字、不截断）
            rowLayout(pricesBesideTag: false)
        }
        .padding(.vertical, 8)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("查看交易详情")
    }

    /// 行内容双布局。窄屏时价格换行而非缩字——Dynamic Type 友好
    @ViewBuilder
    private func rowLayout(pricesBesideTag: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                if pricesBesideTag {
                    HStack(spacing: 8) {
                        tagCapsule
                        pricePair
                    }
                    secondaryLine
                } else {
                    HStack(spacing: 8) {
                        tagCapsule
                        secondaryLine
                    }
                    pricePair
                }
            }

            Spacer(minLength: 8)

            profitColumn
        }
    }

    private var tagCapsule: some View {
        Text(LocalizedStringKey(record.stockCode))
            .font(.caption.weight(.bold))
            .foregroundStyle(record.hasName ? Color.stockTagText : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                record.hasName
                    ? AnyShapeStyle(Color.stockTag)
                    : AnyShapeStyle(.quaternary),
                in: .capsule
            )
    }

    private var pricePair: some View {
        HStack(spacing: 4) {
            Text(String(format: "%.3f", record.buyPrice))
                .lineLimit(1)
                .monospacedDigit()
            Image(systemName: "arrow.right")
                .imageScale(.small)
                .foregroundStyle(.tertiary)
            Text(String(format: "%.3f", record.sellPrice))
                .lineLimit(1)
                .monospacedDigit()
        }
        .font(.subheadline)
    }

    private var secondaryLine: some View {
        Text(viewModel.localizedFormat("股数时间格式", Int(record.shares), timeText))
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var profitColumn: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(String(format: "%@%.3f", record.netProfit >= 0 ? "+" : "-", abs(record.netProfit)))
                .font(.headline.weight(.semibold))
                .foregroundStyle(PnLStyle.color(record.netProfit))
                .monospacedDigit()
                .lineLimit(1)

            Text(String(format: "%@%.2f%%", record.returnRate >= 0 ? "+" : "", record.returnRate))
                .font(.caption.weight(.semibold))
                .foregroundStyle(PnLStyle.color(record.returnRate))
                .monospacedDigit()
                .lineLimit(1)
        }
    }
}

// MARK: - 记录详情

private struct RecordDetailView: View {
    let record: TradeRecord
    @EnvironmentObject private var viewModel: TradeViewModel

    var body: some View {
        Form {
            Section {
                LabeledContent("代码") {
                    Text(LocalizedStringKey(record.stockCode))
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 44)

                LabeledContent("净利润") {
                    Text(String(format: "%@%.3f", record.netProfit >= 0 ? "+" : "-", abs(record.netProfit)))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(PnLStyle.color(record.netProfit))
                }
                .frame(minHeight: 44)

                LabeledContent("收益率") {
                    Text(String(format: "%@%.2f%%", record.returnRate >= 0 ? "+" : "", record.returnRate))
                        .foregroundStyle(PnLStyle.color(record.returnRate))
                }
                .frame(minHeight: 44)

                LabeledContent("时间") {
                    Text(record.date)
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 44)
            }

            Section("交易") {
                LabeledContent("买入") {
                    Text(String(format: "%.3f × %lld", record.buyPrice, Int(record.shares)))
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 44)

                LabeledContent("卖出") {
                    Text(String(format: "%.3f × %lld", record.sellPrice, Int(record.shares)))
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 44)

                LabeledContent("买入成本") {
                    Text(String(format: "%.3f", record.buyAmount))
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 44)

                LabeledContent("卖出金额") {
                    Text(String(format: "%.3f", record.sellAmount))
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 44)
            }

            Section {
                DisclosureGroup {
                    Text(LocalizedStringKey("买入费用"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    LabeledContent("买入佣金") {
                        Text(String(format: "%.3f", record.fees.buyCommission))
                            .foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 44)

                    LabeledContent("过户费") {
                        Text(String(format: "%.3f", record.fees.buyTransferFee))
                            .foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 44)

                    Text(LocalizedStringKey("卖出费用"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    LabeledContent("卖出佣金") {
                        Text(String(format: "%.3f", record.fees.sellCommission))
                            .foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 44)

                    LabeledContent("印花税") {
                        Text(String(format: "%.3f", record.fees.stampDuty))
                            .foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 44)

                    LabeledContent("过户费") {
                        Text(String(format: "%.3f", record.fees.sellTransferFee))
                            .foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 44)
                } label: {
                    Label("费用明细", systemImage: "list.bullet")
                }
            }

            Section {
                LabeledContent("合计费用") {
                    Text(String(format: "%.3f", record.fees.total))
                        .fontWeight(.bold)
                }
                .frame(minHeight: 44)
            }
        }
        .navigationTitle(LocalizedStringKey(record.stockCode))
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
    }
}
