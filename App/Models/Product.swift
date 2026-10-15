import Foundation
import Combine

struct Product: Equatable, Identifiable {
    var id: String { sku }
    let sku: String
    let spu: String
    let name: String
    let volume: String
    let limitCount: Int
    let catalogOutPrice: Double
    let searchKeyword: String
    let defaultAmount: String
    let captchaId: String
    let h5URL: URL
    let rushURL: URL

    static let sku741 = Product(
        sku: "741",
        spu: "IMTP1000313",
        name: "飞天53%vol 500ml贵州茅台酒（带杯）",
        volume: "500ml",
        limitCount: 6,
        catalogOutPrice: 1639,
        searchKeyword: "飞天茅台1499",
        defaultAmount: "1",
        captchaId: YidunClient.captchaId741,
        h5URL: URL(string: "https://h5.moutai519.com.cn/mt/item/smsp-detail?appConfig=2_1_2")!,
        rushURL: URL(string: "https://h5.moutai519.com.cn/xhr/front/trade/priority/rushPurchase/hot/branch/one")!
    )

    static let sku483 = Product(
        sku: "483",
        spu: "IMTP1000229",
        name: "飞天53%vol 1L贵州茅台酒",
        volume: "1L",
        limitCount: 6,
        catalogOutPrice: 3799,
        searchKeyword: "飞天茅台3799",
        defaultAmount: "1",
        captchaId: YidunClient.captchaId483,
        h5URL: URL(string: "https://h5.moutai519.com.cn/mt/item/1000ml-detail?appConfig=2_1_2&sourceId=IMTP1000229")!,
        rushURL: URL(string: "https://h5.moutai519.com.cn/xhr/front/trade/priority/rushPurchase")!
    )

    static let sku10193 = Product(
        sku: "10193",
        spu: "IMTP1000006",
        name: "飞天53%vol 100ml贵州茅台酒",
        volume: "100ml",
        limitCount: 40,
        catalogOutPrice: 249,
        searchKeyword: "飞天茅台249",
        defaultAmount: "2",
        captchaId: YidunClient.captchaId741,
        h5URL: URL(string: "https://h5.moutai519.com.cn/mt/item/xft-detail?appConfig=2_1_2&sourceId=IMTP1000006")!,
        rushURL: URL(string: "https://h5.moutai519.com.cn/xhr/front/trade/priority/rushPurchase/hot/branch/five")!
    )

    static let all: [Product] = [sku741, sku483, sku10193]

    static func named(_ sku: String) -> Product {
        all.first { $0.sku == sku } ?? sku741
    }

    /// Rush body `amount` is a decimal string. Clamp to 1...limitCount.
    func clampAmount(_ raw: String) -> String {
        let digits = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let n = Int(digits) ?? Int(defaultAmount) ?? 1
        return String(min(limitCount, max(1, n)))
    }
}

final class ProductStore: ObservableObject {
    static let defaultsKey = "mt741.selectedSku"

    static func amountDefaultsKey(_ sku: String) -> String {
        "mt741.amount.\(sku)"
    }

    @Published var selected: Product {
        didSet { UserDefaults.standard.set(selected.sku, forKey: Self.defaultsKey) }
    }

    /// Bumped on every persist so 飞天 / 异步 both refresh the stepper.
    @Published private(set) var amountRevision = 0

    init(selected: Product? = nil) {
        if let selected {
            self.selected = selected
            return
        }
        let sku = UserDefaults.standard.string(forKey: Self.defaultsKey) ?? Product.sku741.sku
        self.selected = Product.named(sku)
    }

    func amount(for product: Product) -> String {
        let saved = UserDefaults.standard.string(forKey: Self.amountDefaultsKey(product.sku)) ?? ""
        if saved.isEmpty { return product.defaultAmount }
        return product.clampAmount(saved)
    }

    func setAmount(_ raw: String, for product: Product) {
        UserDefaults.standard.set(product.clampAmount(raw), forKey: Self.amountDefaultsKey(product.sku))
        amountRevision += 1
    }

    func bumpAmount(_ delta: Int, for product: Product) {
        let cur = Int(amount(for: product)) ?? 1
        setAmount(String(cur + delta), for: product)
    }
}
