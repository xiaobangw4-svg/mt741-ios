import Foundation

struct Product: Equatable {
    let sku: String
    let spu: String
    let name: String
    let volume: String
    let limitCount: Int
    let catalogOutPrice: Double
    let searchKeyword: String
    let h5URL: URL

    static let sku741 = Product(
        sku: "741",
        spu: "IMTP1000313",
        name: "飞天53%vol 500ml贵州茅台酒（带杯）",
        volume: "500ml",
        limitCount: 6,
        catalogOutPrice: 1639,
        searchKeyword: "飞天茅台1499",
        h5URL: URL(string: "https://h5.moutai519.com.cn/mt/item/smsp-detail?appConfig=2_1_2")!
    )
}
