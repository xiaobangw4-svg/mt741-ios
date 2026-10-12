import SwiftUI

struct ProductView: View {
    @EnvironmentObject private var productStore: ProductStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Product.all) { product in
                        productCard(product)
                    }

                    let selected = productStore.selected
                    infoRow("SPU", selected.spu, id: aid(selected, "product.spu"))
                    infoRow("目录价", String(format: "¥%.0f", selected.catalogOutPrice), id: aid(selected, "product.price"))
                    infoRow("限购", "\(selected.limitCount) 瓶", id: aid(selected, "product.limit"))
                    infoRow("检索词", selected.searchKeyword, id: aid(selected, "product.keyword"))
                    infoRow("默认数量", selected.defaultAmount, id: aid(selected, "product.amount"))
                    infoRow("抢购口", selected.rushURL.lastPathComponent, id: aid(selected, "product.rush"))

                    Text("点选商品后，屏幕上的官网页、异步和组单都跟所选 SKU 走。500ml 默认 1 瓶，100ml 默认 2 瓶。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("product.note")
                }
                .padding()
            }
            .navigationTitle("飞天")
            .background(Color(.systemGroupedBackground))
        }
    }

    private func aid(_ product: Product, _ base: String) -> String {
        product.sku == Product.sku741.sku ? base : "\(base).\(product.sku)"
    }

    private func productCard(_ product: Product) -> some View {
        let selected = productStore.selected.sku == product.sku
        return Button {
            productStore.selected = product
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("SKU \(product.sku)")
                        .font(.caption.monospaced())
                        .foregroundStyle(AppTheme.gold)
                        .accessibilityIdentifier(aid(product, "product.sku"))
                    Spacer()
                    if selected {
                        Text("已选")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.gold)
                            .accessibilityIdentifier(aid(product, "product.selected"))
                    }
                }
                Text(product.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .accessibilityIdentifier(aid(product, "product.title"))
                Text(product.volume)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .accessibilityIdentifier(aid(product, "product.volume"))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.ink)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selected ? AppTheme.gold : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(aid(product, "product.card"))
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
