//
//  MovieLibraryControls.swift
//  AppforNetflix
//
//  Created by Mac Mini on 16/09/2026.
//
import SwiftUI

struct MovieLibraryControls: View {
    let movie: Movie
    @ObservedObject var libraryViewModel: LibraryViewModel

    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                statusButton(.wantToWatch, icon: "bookmark")
                statusButton(.watching, icon: "play.circle")
                statusButton(.watched, icon: "checkmark.circle")

                if libraryViewModel.status(for: movie) != .none {
                    Divider()
                    Button {
                        libraryViewModel.setStatus(.none, for: movie)
                    } label: {
                        Label(
                            L10n.string("Clear Status", languageCode: settings.languageCode),
                            systemImage: "xmark.circle"
                        )
                    }
                }
            } label: {
                Label(
                    L10n.string(statusTitle, languageCode: settings.languageCode),
                    systemImage: statusIcon
                )
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(Color.white.opacity(0.15))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .menuStyle(.borderlessButton)

            Button {
                libraryViewModel.toggleFavorite(movie)
            } label: {
                Label(
                    L10n.string(
                        libraryViewModel.isFavorite(movie) ? "Favorited" : "Favorite",
                        languageCode: settings.languageCode
                    ),
                    systemImage: libraryViewModel.isFavorite(movie) ? "heart.fill" : "heart"
                )
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(Color.white.opacity(0.15))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func statusButton(_ status: LibraryStatus, icon: String) -> some View {
        Button {
            libraryViewModel.setStatus(status, for: movie)
        } label: {
            Label(
                L10n.string(status.title, languageCode: settings.languageCode),
                systemImage: libraryViewModel.status(for: movie) == status
                    ? "\(icon).fill"
                    : icon
            )
        }
    }

    private var statusTitle: String {
        let status = libraryViewModel.status(for: movie)
        return status == .none ? "My Status" : status.title
    }

    private var statusIcon: String {
        switch libraryViewModel.status(for: movie) {
        case .none: "plus.circle"
        case .wantToWatch: "bookmark.fill"
        case .watching: "play.circle.fill"
        case .watched: "checkmark.circle.fill"
        }
    }
}
