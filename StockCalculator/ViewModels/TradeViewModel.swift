import Foundation
import Combine
import SwiftUI

class TradeViewModel: ObservableObject {
    @Published var settings: FeeSettings {
        didSet {
            saveSettings()
        }
    }
    
    @Published var records: [TradeRecord] = [] {
        didSet {
            saveRecords()
        }
    }
    
    init() {
        // Load settings
        if let data = UserDefaults.standard.data(forKey: "stk-settings"),
           let decoded = try? JSONDecoder().decode(FeeSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = FeeSettings.defaultSettings
        }
        
        // Load records
        if let data = UserDefaults.standard.data(forKey: "stk-records"),
           let decoded = try? JSONDecoder().decode([TradeRecord].self, from: data) {
            self.records = decoded
        }
    }
    
    func calculate(buyPrice: Double, sellPrice: Double, shares: Double) -> CalculationResult {
        let buyAmount = buyPrice * shares
        let sellAmount = sellPrice * shares
        let grossProfit = sellAmount - buyAmount
        
        let buyCommission = max(buyAmount * settings.commissionRate / 100, settings.minCommission)
        let sellCommission = max(sellAmount * settings.commissionRate / 100, settings.minCommission)
        let stampDuty = sellAmount * settings.stampDutyRate / 100
        let buyTransferFee = buyAmount * settings.transferFeeRate / 100
        let sellTransferFee = sellAmount * settings.transferFeeRate / 100
        
        let totalFees = buyCommission + buyTransferFee + sellCommission + stampDuty + sellTransferFee
        let netProfit = grossProfit - totalFees
        // Return rate is measured against the full capital outlay, including buy-side fees
        let buyCost = buyAmount + buyCommission + buyTransferFee
        let returnRate = buyCost > 0 ? (netProfit / buyCost) * 100 : 0
        
        return CalculationResult(
            buyAmount: buyAmount,
            sellAmount: sellAmount,
            grossProfit: grossProfit,
            netProfit: netProfit,
            returnRate: returnRate,
            shares: shares,
            fees: FeeBreakdown(
                buyCommission: buyCommission,
                buyTransferFee: buyTransferFee,
                sellCommission: sellCommission,
                stampDuty: stampDuty,
                sellTransferFee: sellTransferFee,
                total: totalFees
            )
        )
    }
    
    // 加仓成本测算：旧持仓按输入成本价加权，新买入的佣金 + 过户费摊入平均成本
    func calculateAveraging(positionCost: Double, positionShares: Double, addPrice: Double, addShares: Double, currentPrice: Double?) -> AveragingResult {
        let addAmount = addPrice * addShares
        let commission = max(addAmount * settings.commissionRate / 100, settings.minCommission)
        let transferFee = addAmount * settings.transferFeeRate / 100
        let newBuyFee = commission + transferFee

        let totalShares = positionShares + addShares
        let totalInvested = positionCost * positionShares + addAmount + newBuyFee
        let averageCost = totalShares > 0 ? totalInvested / totalShares : 0

        var unrealizedProfit: Double? = nil
        var unrealizedRate: Double? = nil
        if let cp = currentPrice, cp > 0, averageCost > 0 {
            unrealizedProfit = (cp - averageCost) * totalShares
            unrealizedRate = (cp - averageCost) / averageCost * 100
        }

        return AveragingResult(
            totalShares: totalShares,
            averageCost: averageCost,
            totalInvested: totalInvested,
            addAmount: addAmount,
            newBuyFee: newBuyFee,
            unrealizedProfit: unrealizedProfit,
            unrealizedRate: unrealizedRate
        )
    }

    func saveRecord(stockCode: String, buyPrice: Double, sellPrice: Double, shares: Double, result: CalculationResult) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let dateString = formatter.string(from: Date())
        
        let record = TradeRecord(
            id: UUID().uuidString,
            stockCode: stockCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未命名" : stockCode.uppercased(),
            buyPrice: buyPrice,
            sellPrice: sellPrice,
            shares: shares,
            buyAmount: result.buyAmount,
            sellAmount: result.sellAmount,
            grossProfit: result.grossProfit,
            netProfit: result.netProfit,
            returnRate: result.returnRate,
            date: dateString,
            fees: result.fees
        )
        records.append(record)
    }
    
    func deleteRecord(id: String) {
        records.removeAll { $0.id == id }
    }

    // MARK: - 外观与语言

    var effectiveColorScheme: ColorScheme? {
        switch settings.appearanceMode {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    var effectiveLocale: Locale {
        switch settings.languageMode {
        case 1: return Locale(identifier: "zh-Hans")
        case 2: return Locale(identifier: "en")
        default: return .current
        }
    }

    // 当前语言对应的本地化资源包
    private var localizedBundle: Bundle {
        let tableName = effectiveLocale.identifier.hasPrefix("zh") ? "zh-Hans" : "en"
        return Bundle.main.path(forResource: tableName, ofType: "lproj")
            .flatMap { Bundle(path: $0) } ?? .main
    }

    // 无参数文案的本地化查找
    func localized(_ key: String) -> String {
        localizedBundle.localizedString(forKey: key, value: nil, table: nil)
    }

    // 动态字符串的本地化格式化：按 key 从对应语言的 .lproj 取文案，再代入参数
    func localizedFormat(_ key: String, _ args: CVarArg...) -> String {
        let template = localizedBundle.localizedString(forKey: key, value: nil, table: nil)
        return String(format: template, locale: effectiveLocale, arguments: args)
    }

    func resetSettings() {
        settings = FeeSettings.defaultSettings
    }
    
    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: "stk-settings")
        }
    }
    
    private func saveRecords() {
        if let encoded = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(encoded, forKey: "stk-records")
        }
    }
}
