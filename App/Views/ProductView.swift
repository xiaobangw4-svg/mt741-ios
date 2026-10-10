import SwiftUI

struct ProductView: View {
    let product = Product.sku741

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SKU \(product.sku)")
                            .font(.caption.monospaced())
                            .foregroundStyle(AppTheme.gold)
                            .accessibilityIdentifier("product.sku")
                        Text(product.name)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .accessibilityIdentifier("product.title")
                        Text(product.volume)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .accessibilityIdentifier("product.volume")
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    infoRow("SPU", product.spu, id: "product.spu")
                    infoRow("目录价", String(format: "¥%.0f", product.catalogOutPrice), id: "product.price")
                    infoRow("限购", "\(product.limitCount) 瓶", id: "product.limit")
                    infoRow("检索词", product.searchKeyword, id: "product.keyword")

                    Text("本页只展示 741 / 飞天 500ml 商品卡。登录走「登录」页，官方页面走「H5」页。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("product.note")
                }
                .padding()
            }
            .navigationTitle("飞天 500ml")
            .background(Color(.systemGroupedBackground))
        }
    }

    private func infoRow(_ title: String, _ value: String, id: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body.monospaced())
                .accessibilityIdentifier(id)
        }
        .padding(.vertical, 8)
    }
}
