//
//  Country.swift
//  AppForNetflix
//
//  Created by Mac Mini on 26/08/2026.
//
import Foundation

/// A country available in the region picker (Settings → Region, and the
/// top bar's content-availability filter).
struct Country: Identifiable, Hashable {
    let code: String   // ISO 3166-1 alpha-2
    let name: String

    var id: String { code }

    /// Builds the flag emoji from the ISO code (e.g. "QA" → 🇶🇦) instead of
    /// shipping flag image assets — this covers every country with zero
    /// extra files and always matches the code exactly.
    var flag: String {
        code.uppercased().unicodeScalars.reduce(into: "") { result, scalar in
            if let flagScalar = Unicode.Scalar(127397 + scalar.value) {
                result.unicodeScalars.append(flagScalar)
            }
        }
    }

    /// Countries with meaningful TMDB / streaming-availability data.
    /// Ordered alphabetically except for `pinned`, which surfaces the
    /// current region + its neighbors at the top of the list — mirrors the
    /// design showing "Kingdom of Qatar" pinned above the alphabetical list.
    static let all: [Country] = [
        Country(code: "QA", name: "Kingdom of Qatar"),
        Country(code: "US", name: "United States"),
        Country(code: "PK", name: "Pakistan"),
        Country(code: "BH", name: "Bahrain"),
        Country(code: "CN", name: "China"),
        Country(code: "CA", name: "Canada"),
        Country(code: "GB", name: "United Kingdom"),
        Country(code: "AE", name: "United Arab Emirates"),
        Country(code: "SA", name: "Saudi Arabia"),
        Country(code: "KW", name: "Kuwait"),
        Country(code: "OM", name: "Oman"),
        Country(code: "EG", name: "Egypt"),
        Country(code: "IN", name: "India"),
        Country(code: "AU", name: "Australia"),
        Country(code: "DE", name: "Germany"),
        Country(code: "FR", name: "France"),
        Country(code: "ES", name: "Spain"),
        Country(code: "IT", name: "Italy"),
        Country(code: "NL", name: "Netherlands"),
        Country(code: "SE", name: "Sweden"),
        Country(code: "NO", name: "Norway"),
        Country(code: "JP", name: "Japan"),
        Country(code: "KR", name: "South Korea"),
        Country(code: "SG", name: "Singapore"),
        Country(code: "MY", name: "Malaysia"),
        Country(code: "ID", name: "Indonesia"),
        Country(code: "PH", name: "Philippines"),
        Country(code: "TR", name: "Turkey"),
        Country(code: "BR", name: "Brazil"),
        Country(code: "MX", name: "Mexico"),
        Country(code: "ZA", name: "South Africa"),
        Country(code: "NG", name: "Nigeria")
    ]

    static func find(_ name: String) -> Country {
        all.first { $0.name == name } ?? all[0]
    }
}
