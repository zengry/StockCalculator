import Foundation

struct FeeSettings: Codable, Equatable {
    var commissionRate: Double
    var minCommission: Double
    var stampDutyRate: Double
    var transferFeeRate: Double
    var appearanceMode: Int      // 0 跟随系统 / 1 浅色 / 2 深色
    var languageMode: Int        // 0 跟随系统 / 1 中文 / 2 English
    var scenarioLimit: Int       // 涨跌推演滑杆幅度上限 %：5 ST / 10 主板 / 20 创业板·科创板 / 30 北交所

    static let defaultSettings = FeeSettings(
        commissionRate: 0.03,
        minCommission: 5,
        stampDutyRate: 0.05,
        transferFeeRate: 0.001,
        appearanceMode: 0,
        languageMode: 0,
        scenarioLimit: 10
    )

    // 旧版本存档缺少新增字段，逐个给默认值，避免解码失败重置用户费率
    init(commissionRate: Double, minCommission: Double, stampDutyRate: Double, transferFeeRate: Double, appearanceMode: Int = 0, languageMode: Int = 0, scenarioLimit: Int = 10) {
        self.commissionRate = commissionRate
        self.minCommission = minCommission
        self.stampDutyRate = stampDutyRate
        self.transferFeeRate = transferFeeRate
        self.appearanceMode = appearanceMode
        self.languageMode = languageMode
        self.scenarioLimit = scenarioLimit
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        commissionRate = try c.decodeIfPresent(Double.self, forKey: .commissionRate) ?? 0.03
        minCommission = try c.decodeIfPresent(Double.self, forKey: .minCommission) ?? 5
        stampDutyRate = try c.decodeIfPresent(Double.self, forKey: .stampDutyRate) ?? 0.05
        transferFeeRate = try c.decodeIfPresent(Double.self, forKey: .transferFeeRate) ?? 0.001
        appearanceMode = try c.decodeIfPresent(Int.self, forKey: .appearanceMode) ?? 0
        languageMode = try c.decodeIfPresent(Int.self, forKey: .languageMode) ?? 0
        scenarioLimit = try c.decodeIfPresent(Int.self, forKey: .scenarioLimit) ?? 10
    }
}

struct FeeBreakdown: Codable {
    var buyCommission: Double
    var buyTransferFee: Double
    var sellCommission: Double
    var stampDuty: Double
    var sellTransferFee: Double
    var total: Double
}

struct TradeRecord: Identifiable, Codable {
    var id: String
    var stockCode: String
    var buyPrice: Double
    var sellPrice: Double
    var shares: Double
    var buyAmount: Double
    var sellAmount: Double
    var grossProfit: Double
    var netProfit: Double
    var returnRate: Double
    var date: String
    var fees: FeeBreakdown
}

struct CalculationResult {
    var buyAmount: Double
    var sellAmount: Double
    var grossProfit: Double
    var netProfit: Double
    var returnRate: Double
    var shares: Double
    var fees: FeeBreakdown
}

// 加仓成本测算结果
struct AveragingResult {
    var totalShares: Double      // 加仓后总股数
    var averageCost: Double      // 摊薄成本价（新买入费用已摊入）
    var totalInvested: Double    // 总投入（旧持仓成本 + 新买入金额 + 新买入费用）
    var addAmount: Double        // 本次加仓金额（不含费）
    var newBuyFee: Double        // 新买入费用（佣金 + 过户费）
    var unrealizedProfit: Double? // 浮动盈亏（填了当前市价时非空）
    var unrealizedRate: Double?   // 浮动收益率 %
}
