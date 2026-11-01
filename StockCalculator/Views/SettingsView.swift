import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: TradeViewModel

    @State private var showResetSuccess = false
    @State private var resetCount = 0

    // MARK: - 费率输入策略

    // 输入过程只过滤非法字符，不拒绝中间态（如 "0."、"."）；
    // 失焦时解析并夹取到合法区间，超界或无效时给出说明文案（entering-data.md：动态校验 + 即时反馈）。
    private enum FeeField: Hashable {
        case commission, minCommission, stampDuty, transferFee
    }

    @FocusState private var focusedField: FeeField?
    @State private var commissionText = ""
    @State private var minCommissionText = ""
    @State private var stampDutyText = ""
    @State private var transferFeeText = ""
    @State private var validationNote: String?

    private let commissionRange: ClosedRange<Double> = 0...10
    private let minCommissionRange: ClosedRange<Double> = 0...10000
    private let stampDutyRange: ClosedRange<Double> = 0...10
    private let transferFeeRange: ClosedRange<Double> = 0...1

    var body: some View {
        Form {
            Section {
                SettingRow(title: "佣金费率", subtitle: "买卖双边均收", unit: "%", text: commissionBinding)
                    .focused($focusedField, equals: .commission)
                SettingRow(title: "最低佣金", subtitle: "不足则按最低收取", unit: "元/笔", text: minCommissionBinding)
                    .focused($focusedField, equals: .minCommission)
                SettingRow(title: "印花税率", subtitle: "仅卖出时收取", unit: "%", text: stampDutyBinding)
                    .focused($focusedField, equals: .stampDuty)
                SettingRow(title: "过户费率", subtitle: "买卖双边均收", unit: "%", text: transferFeeBinding)
                    .focused($focusedField, equals: .transferFee)
            } header: {
                Text("A股交易费率")
            } footer: {
                VStack(spacing: 8) {
                    if let note = validationNote {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }
                    Text("默认费率说明")
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }

            Section {
                Picker(selection: Binding(
                    get: { viewModel.settings.scenarioLimit },
                    set: { viewModel.settings.scenarioLimit = $0 }
                )) {
                    Text("5%（ST股）").tag(5)
                    Text("10%（主板）").tag(10)
                    Text("20%（创业板/科创板）").tag(20)
                    Text("30%（北交所）").tag(30)
                } label: {
                    Label("涨跌幅上限", systemImage: "slider.horizontal.3")
                }
            } header: {
                Text("涨跌推演")
            } footer: {
                Text("推演范围说明")
                    .multilineTextAlignment(.center)
            }

            Section("外观与语言") {
                Picker(selection: Binding(
                    get: { viewModel.settings.appearanceMode },
                    set: { viewModel.settings.appearanceMode = $0 }
                )) {
                    Text("跟随系统").tag(0)
                    Text("浅色").tag(1)
                    Text("深色").tag(2)
                } label: {
                    Label("外观", systemImage: "circle.lefthalf.filled")
                }

                Picker(selection: Binding(
                    get: { viewModel.settings.languageMode },
                    set: { viewModel.settings.languageMode = $0 }
                )) {
                    Text("跟随系统").tag(0)
                    Text("中文").tag(1)
                    Text("English").tag(2)
                } label: {
                    Label("语言", systemImage: "globe")
                }
            }

            Section {
                Button(action: resetSettings) {
                    Label(
                        showResetSuccess ? "已恢复默认值" : "恢复默认值",
                        systemImage: showResetSuccess ? "checkmark.circle.fill" : "arrow.counterclockwise"
                    )
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(showResetSuccess ? .green : .red)
                    .contentTransition(.symbolEffect(.replace.byLayer.downUp))
                }
                .buttonStyle(.plain)
            }

            Section("关于") {
                LabeledContent("版本") {
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .frame(minHeight: 44)

                Link(destination: URL(string: "https://github.com/zengry/StockCalculator")!) {
                    Label("项目主页", systemImage: "link")
                }
                .frame(minHeight: 44)
            }
        }
        .navigationTitle("费率设置")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .sensoryFeedback(.success, trigger: resetCount)
        .onAppear(perform: syncTextsFromSettings)
        .onChange(of: viewModel.settings) { _, _ in
            syncTextsFromSettings()
        }
        .onChange(of: focusedField) { oldFocus, _ in
            if let field = oldFocus {
                commit(field)
            }
        }
    }

    // MARK: - 输入绑定（输入时只过滤非法字符）

    private var commissionBinding: Binding<String> {
        Binding(get: { commissionText }, set: { commissionText = Self.sanitized($0) })
    }

    private var minCommissionBinding: Binding<String> {
        Binding(get: { minCommissionText }, set: { minCommissionText = Self.sanitized($0) })
    }

    private var stampDutyBinding: Binding<String> {
        Binding(get: { stampDutyText }, set: { stampDutyText = Self.sanitized($0) })
    }

    private var transferFeeBinding: Binding<String> {
        Binding(get: { transferFeeText }, set: { transferFeeText = Self.sanitized($0) })
    }

    /// 只保留数字与一个小数点，绝不拒绝中间态输入
    private static func sanitized(_ input: String) -> String {
        var result = ""
        var hasDot = false
        for character in input {
            if character.isNumber {
                result.append(character)
            } else if character == ".", !hasDot {
                hasDot = true
                result.append(character)
            }
        }
        return result
    }

    // MARK: - 提交与同步

    /// 失焦提交：解析、夹取、写回设置；无效输入还原为当前值并给出说明
    private func commit(_ field: FeeField) {
        let text: String
        let range: ClosedRange<Double>
        let keyPath: WritableKeyPath<FeeSettings, Double>

        switch field {
        case .commission:
            (text, range, keyPath) = (commissionText, commissionRange, \.commissionRate)
        case .minCommission:
            (text, range, keyPath) = (minCommissionText, minCommissionRange, \.minCommission)
        case .stampDuty:
            (text, range, keyPath) = (stampDutyText, stampDutyRange, \.stampDutyRate)
        case .transferFee:
            (text, range, keyPath) = (transferFeeText, transferFeeRange, \.transferFeeRate)
        }

        guard let value = Double(text) else {
            revert(field, keyPath: keyPath)
            validationNote = viewModel.localized("输入无效已还原")
            return
        }

        let clamped = min(max(value, range.lowerBound), range.upperBound)
        viewModel.settings[keyPath: keyPath] = clamped

        if clamped != value {
            validationNote = viewModel.localizedFormat("已按范围调整", formatRate(clamped))
        } else {
            validationNote = nil
        }
        setText(field, to: formatRate(clamped))
    }

    private func revert(_ field: FeeField, keyPath: KeyPath<FeeSettings, Double>) {
        setText(field, to: formatRate(viewModel.settings[keyPath: keyPath]))
    }

    private func setText(_ field: FeeField, to value: String) {
        switch field {
        case .commission: commissionText = value
        case .minCommission: minCommissionText = value
        case .stampDuty: stampDutyText = value
        case .transferFee: transferFeeText = value
        }
    }

    private func syncTextsFromSettings() {
        commissionText = formatRate(viewModel.settings.commissionRate)
        minCommissionText = formatRate(viewModel.settings.minCommission)
        stampDutyText = formatRate(viewModel.settings.stampDutyRate)
        transferFeeText = formatRate(viewModel.settings.transferFeeRate)
    }

    /// 整数值去掉小数尾（5.0 → "5"），小数值原样保留（0.03 → "0.03"）
    private func formatRate(_ value: Double) -> String {
        value.rounded() == value && abs(value) < 1e15 ? String(Int(value)) : String(value)
    }

    private func resetSettings() {
        viewModel.resetSettings()
        resetCount += 1
        validationNote = nil
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showResetSuccess = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showResetSuccess = false
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(version) (\(build))"
    }
}

// MARK: - 费率输入行

private struct SettingRow: View {
    let title: String
    let subtitle: String
    let unit: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(LocalizedStringKey(title))

                Spacer(minLength: 8)

                TextField("", text: $text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 72)
                    .frame(minHeight: 44)

                if !unit.isEmpty {
                    Text(LocalizedStringKey(unit))
                        .foregroundStyle(.secondary)
                }
            }

            Text(LocalizedStringKey(subtitle))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
