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
        h5URL: URL(string: "https://h5.moutai519.com.cn/mt/item/smsp-detail?appConfig=2_1_2")!,
        rushURL: URL(string: "https://h5.moutai519.com.cn/xhr/front/trade/priority/rushPurchase/hot/branch/one")!
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
        h5URL: URL(string: "https://h5.moutai519.com.cn/mt/item/xft-detail?appConfig=2_1_2&sourceId=IMTP1000006")!,
        rushURL: URL(string: "https://h5.moutai519.com.cn/xhr/front/trade/priority/rushPurchase/hot/branch/five")!
    )

    static let all: [Product] = [sku741, sku10193]

    static func named(_ sku: String) -> Product {
        all.first { $0.sku == sku } ?? sku741
    }
}

final class ProductStore: ObservableObject {
    static let defaultsKey = "mt741.selectedSku"

    @Published var selected: Product {
        didSet { UserDefaults.standard.set(selected.sku, forKey: Self.defaultsKey) }
    }

    init(selected: Product? = nil) {
        if let selected {
            self.selected = selected
            return
        }
        let sku = UserDefaults.standard.string(forKey: Self.defaultsKey) ?? Product.sku741.sku
        self.selected = Product.named(sku)
    }
}
