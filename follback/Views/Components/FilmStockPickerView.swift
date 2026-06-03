import SwiftUI
import Kingfisher

struct FilmStockPickerView: View {
    @Binding var selectedFilmName: String
    @State private var searchText = ""

    private var filteredStocks: [(brand: String, stocks: [FilmStock])] {
        if searchText.isEmpty {
            return FilmStock.groupedByBrandPopularFirst
        }
        let query = searchText.lowercased()
        return FilmStock.groupedByBrandPopularFirst.compactMap { group in
            let filtered = group.stocks.filter {
                $0.displayName.lowercased().contains(query) ||
                $0.brand.lowercased().contains(query)
            }
            return filtered.isEmpty ? nil : (brand: group.brand, stocks: filtered)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                // Search
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15))
                        .foregroundColor(Color.filmTertiary)
                    TextField("Search film stocks...", text: $searchText)
                        .font(.system(size: 15))
                        .foregroundColor(Color.filmText)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.filmSurface)
                )
                .padding(.horizontal, 16)

                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(filteredStocks, id: \.brand) { group in
                        Section {
                            ForEach(group.stocks) { stock in
                                Button {
                                    selectedFilmName = stock.displayName
                                } label: {
                                    HStack(spacing: 12) {
                                        if let url = stock.githubCoverUrl, let coverURL = URL(string: url) {
                                            KFImage(coverURL)
                                                .downsampling(size: CGSize(width: 80, height: 80))
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 40, height: 40)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        } else {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.filmSurface)
                                                .frame(width: 40, height: 40)
                                                .overlay(
                                                    Image(systemName: "film")
                                                        .font(.system(size: 16))
                                                        .foregroundColor(Color.filmTertiary)
                                                )
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(stock.displayName)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(Color.filmText)
                                            Text("ISO \(stock.isoValue)")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color.filmTertiary)
                                        }
                                        Spacer()
                                        if selectedFilmName == stock.displayName {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(Color.filmAccent)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text(group.brand)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color.filmText)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.filmBackground)
                        }
                    }
                }
            }
        }
        .background(Color.filmBackground.ignoresSafeArea())
    }
}
