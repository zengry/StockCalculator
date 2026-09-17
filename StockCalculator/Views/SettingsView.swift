import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var viewModel: TradeViewModel
    
    @State private var showResetSuccess = false
    
    // Use string bindings for TextFields to handle decimals properly
    // Values outside the valid range are rejected to keep calculations sane
    private var commissionBinding: Binding<String> {
        Binding(
            get: { String(viewModel.settings.commissionRate) },
            set: { if let val = Double($0), (0...10).contains(val) { viewModel.settings.commissionRate = val } }
        )
    }
    
    private var minCommissionBinding: Binding<String> {
        Binding(
            get: { String(viewModel.settings.minCommission) },
            set: { if let val = Double($0), (0...10000).contains(val) { viewModel.settings.minCommission = val } }
        )
    }
    
    private var stampDutyBinding: Binding<String> {
        Binding(
            get: { String(viewModel.settings.stampDutyRate) },
            set: { if let val = Double($0), (0...10).contains(val) { viewModel.settings.stampDutyRate = val } }
        )
    }
    
    private var transferFeeBinding: Binding<String> {
        Binding(
            get: { String(viewModel.settings.transferFeeRate) },
            set: { if let val = Double($0), (0...1).contains(val) { viewModel.settings.transferFeeRate = val } }
        )
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("A股交易费率"), footer: Text("默认费率说明").multilineTextAlignment(.center).frame(maxWidth: .infinity)) {
                    SettingRow(title: "佣金费率", subtitle: "买卖双边均收", unit: "%", text: commissionBinding)
                    SettingRow(title: "最低佣金", subtitle: "不足则按最低收取", unit: "元/笔", text: minCommissionBinding)
                    SettingRow(title: "印花税率", subtitle: "仅卖出时收取", unit: "%", text: stampDutyBinding)
                    SettingRow(title: "过户费率", subtitle: "买卖双边均收", unit: "%", text: transferFeeBinding)
                }
                
                Section(header: Text("外观与语言")) {
                    Picker(selection: Binding(
                        get: { viewModel.settings.appearanceMode },
                        set: { viewModel.settings.appearanceMode = $0 }
                    )) {
                        Text("跟随系统").tag(0)
                        Text("浅色").tag(1)
                        Text("深色").tag(2)
                    } label: {
                        Text("外观")
                    }
                    Picker(selection: Binding(
                        get: { viewModel.settings.languageMode },
                        set: { viewModel.settings.languageMode = $0 }
                    )) {
                        Text("跟随系统").tag(0)
                        Text("中文").tag(1)
                        Text("English").tag(2)
                    } label: {
                        Text("语言")
                    }
                }

                Section {
                    Button(action: {
                        viewModel.resetSettings()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        withAnimation(.snappy) { showResetSuccess = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                            withAnimation(.snappy) { showResetSuccess = false }
                        }
                    }) {
                        Label(
                            showResetSuccess ? "已恢复默认值" : "恢复默认值",
                            systemImage: showResetSuccess ? "checkmark.circle.fill" : "arrow.counterclockwise"
                        )
                        .foregroundColor(showResetSuccess ? .green : .red)
                        .frame(maxWidth: .infinity)
                        .contentTransition(.symbolEffect(.replace.byLayer.downUp))
                    }
                }
            }
            .navigationTitle("费率设置")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SettingRow: View {
    let title: String
    let subtitle: String
    let unit: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(LocalizedStringKey(title))
                Spacer()
                // 与计算器页一致的无边框输入样式
                PlainTextField(
                    text: $text,
                    placeholder: "",
                    keyboardType: .decimalPad,
                    textAlignment: .right,
                    textColor: .systemBlue
                )
                .frame(width: 80)
                Text(LocalizedStringKey(unit)).foregroundColor(.secondary)
            }
            Text(LocalizedStringKey(subtitle)).font(.caption).foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
