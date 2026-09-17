import SwiftUI

// 历史记录的日期解析与展示格式化
private enum RecordDateFormat {
    static let full: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()
    static let day: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static let time: DateFormatter = {
        let f = DateFormatter()
        // 按 12/24 小时制本地化（"14:30" / "2:30 PM"）
        f.setLocalizedDateFormatFromTemplate("j:mm")
        return f
    }()
    // 分组标题："9月17日 周三"（跨年记录带年份），语序按语言本地化
    static let sectionHeader: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMMdEEEE")
        f.locale = Locale(identifier: "zh-Hans")
        return f
    }()
    static let sectionHeaderWithYear: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("yMMMdEEEE")
        f.locale = Locale(identifier: "zh-Hans")
        return f
    }()
}

struct HistoryView: View {
    @EnvironmentObject var viewModel: TradeViewModel
    @Binding var selectedTab: Int
    
    // Group records by day, newest section first, newest record first within each section
    private var groupedRecords: [(date: String, records: [TradeRecord])] {
        let grouped = Dictionary(grouping: viewModel.records.reversed()) { String($0.date.prefix(10)) }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (date: $0.key, records: $0.value) }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if groupedRecords.isEmpty {
                    VStack {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .imageScale(.large)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 10)
                        Text("暂无记录").font(.headline)
                        Text("在计算器页面保存交易记录")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 14)
                        Button {
                            selectedTab = 0
                        } label: {
                            Label("去计算", systemImage: "yensign.circle")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 14))
                        .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, minHeight: 400)
                } else {
                    LazyVStack(spacing: 10, pinnedViews: [.sectionHeaders]) {
                        ForEach(groupedRecords.indices, id: \.self) { index in
                            let section = groupedRecords[index]
                            Section {
                                ForEach(section.records) { record in
                                    HistoryRow(record: record)
                                }
                            } header: {
                                sectionHeader(section.date, count: section.records.count)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("历史记录")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func sectionHeader(_ date: String, count: Int) -> some View {
        HStack {
            if let d = RecordDateFormat.day.date(from: date) {
                Text(sectionTitle(for: d))
            } else {
                Text(date)
            }
            Spacer()
            Text(viewModel.localizedFormat("笔数格式", count))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundColor(.secondary)
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(Color(.systemGroupedBackground))
    }

    // 今年内的记录省略年份，跨年记录补上
    private func sectionTitle(for date: Date) -> String {
        let cal = Calendar.current
        let isCurrentYear = cal.component(.year, from: date) == cal.component(.year, from: Date())
        let formatter = isCurrentYear ? RecordDateFormat.sectionHeader : RecordDateFormat.sectionHeaderWithYear
        formatter.locale = viewModel.effectiveLocale
        return formatter.string(from: date)
    }
}

struct HistoryRow: View {
    let record: TradeRecord
    @EnvironmentObject var viewModel: TradeViewModel
    @State private var isExpanded = false
    
    // 灰色胶囊信息标签（参考风格）
    private func infoChip(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemGray5))
            .clipShape(Capsule())
    }

    // 通过日期解析取时间部分；旧版仅有日期的记录回退为原字符串
    private var timeText: String {
        guard let d = RecordDateFormat.full.date(from: record.date) else { return record.date }
        RecordDateFormat.time.locale = viewModel.effectiveLocale
        return RecordDateFormat.time.string(from: d)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Summary
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                VStack(spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(LocalizedStringKey(record.stockCode))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(record.stockCode == "未命名" ? .secondary : .blue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(record.stockCode == "未命名" ? Color(.systemGray5) : Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                                
                                Text(String(format: "¥%.2f → ¥%.2f", record.buyPrice, record.sellPrice))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                            Text(viewModel.localizedFormat("股数时间格式", Int(record.shares), timeText))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%@¥%.2f", record.netProfit >= 0 ? "+" : "-", abs(record.netProfit)))
                                .font(.headline)
                                .foregroundColor(record.netProfit > 0 ? .red : (record.netProfit < 0 ? .green : .secondary))
                            
                            Text(String(format: "%@%.2f%%", record.returnRate >= 0 ? "+" : "", record.returnRate))
                                .font(.caption)
                                .foregroundColor(record.returnRate > 0 ? .red : (record.returnRate < 0 ? .green : .secondary))
                        }
                    }
                    
                    HStack {
                        infoChip(viewModel.localizedFormat("买入格式", record.buyAmount))
                        infoChip(viewModel.localizedFormat("费用格式", record.fees.total))
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                }
                .padding()
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Divider()
                // Buy Fees
                VStack(spacing: 0) {
                    HStack {
                        Rectangle().fill(Color.blue).frame(width: 3, height: 13).cornerRadius(1.5)
                        Text("买入费用").font(.footnote).fontWeight(.semibold)
                        Spacer()
                        Text(String(format: "¥%.2f", record.fees.buyCommission + record.fees.buyTransferFee)).font(.footnote).foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.05))
                    
                    FeeDetailRow(title: "买入佣金", amount: record.fees.buyCommission)
                    FeeDetailRow(title: "过户费", amount: record.fees.buyTransferFee)
                }
                
                Divider()
                // Sell Fees
                VStack(spacing: 0) {
                    HStack {
                        Rectangle().fill(Color.orange).frame(width: 3, height: 13).cornerRadius(1.5)
                        Text("卖出费用").font(.footnote).fontWeight(.semibold)
                        Spacer()
                        Text(String(format: "¥%.2f", record.fees.sellCommission + record.fees.stampDuty + record.fees.sellTransferFee)).font(.footnote).foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.05))
                    
                    FeeDetailRow(title: "卖出佣金", amount: record.fees.sellCommission)
                    FeeDetailRow(title: "印花税", amount: record.fees.stampDuty)
                    FeeDetailRow(title: "过户费", amount: record.fees.sellTransferFee)
                }
                
                HStack {
                    Text("合计费用").font(.subheadline).fontWeight(.semibold)
                    Spacer()
                    Text(String(format: "¥%.2f", record.fees.total)).font(.subheadline).fontWeight(.bold)
                }
                .padding()
                .background(Color(.systemGray6))
                
                Divider()
                Button(role: .destructive) {
                    viewModel.deleteRecord(id: record.id)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("删除记录")
                    }
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .foregroundColor(.red)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        // 分组列表惯例：细描边而非投影
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 0.5)
        )
        // 不展开也可直接长按删除
        .contextMenu {
            Button(role: .destructive) {
                viewModel.deleteRecord(id: record.id)
            } label: {
                Label("删除记录", systemImage: "trash")
            }
        }
    }
}

struct FeeDetailRow: View {
    let title: String
    let amount: Double
    
    var body: some View {
        HStack {
            Text(LocalizedStringKey(title)).font(.footnote).foregroundColor(.primary)
            Spacer()
            Text(String(format: "¥%.2f", amount)).font(.footnote).foregroundColor(.primary)
        }
        .padding(.horizontal)
        .padding(.leading, 12)
        .padding(.vertical, 6)
    }
}
