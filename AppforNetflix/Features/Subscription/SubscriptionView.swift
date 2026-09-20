import SwiftUI
import StoreKit

struct SubscriptionView: View {

    var onPurchaseSuccess: () -> Void = { }

    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var storeKit: StoreKitService

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var selectedPlan: SubscriptionPlan = .annual
    @State private var isShowingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        ZStack(alignment: .topLeading) {

            HStack(alignment: .top, spacing: 0) {
                benefitsColumn
                    .padding(.leading, 36)
                    .padding(.trailing, 32)
                    .padding(.top, 70)
                    .padding(.bottom, 36)
                    .frame(width: 400, height: 620, alignment: .topLeading)
                    .background(Color(hex: "1D1D1F"))

                Rectangle()
                    .fill(Color.white.opacity(0.055))
                    .frame(width: 1, height: 620)

                plansColumn
                    .padding(.horizontal, 36)
                    .padding(.top, 68)
                    .padding(.bottom, 32)
                    .frame(width: 419, height: 620, alignment: .topLeading)
                    .background(Color(hex: "222224"))
            }

            closeButton
        }
        .background(Color(hex: "1D1D1F"))
        .foregroundStyle(.white)
        .frame(width: 820, height: 620  )
        .task {
            await prepareStoreKit()
        }
        .alert(
            L10n.string(
                "Purchase Information",
                languageCode: settings.languageCode
            ),
            isPresented: $isShowingAlert
        ) {
            Button(
                L10n.string(
                    "OK",
                    languageCode: settings.languageCode
                ),
                role: .cancel
            ) { }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(
                    .system(
                        size: 12,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.leading, 18)
        .padding(.top, 18)
    }

    // MARK: - Benefits Column

    private var benefitsColumn: some View {
        VStack(
            alignment: .leading,
            spacing: 28
        ) {

            Text(
                L10n.string(
                    "Subscribe for a better\nviewing experience.",
                    languageCode: settings.languageCode
                )
            )
            .font(Theme.Font.title(24))
            .fontWeight(.bold)
            .fixedSize(
                horizontal: false,
                vertical: true
            )
            .lineSpacing(2)

            VStack(spacing: 11) {

                ForEach(PremiumBenefit.all) { benefit in

                    HStack(
                        alignment: .top,
                        spacing: 12
                    ) {

                        Image(systemName: "checkmark")
                            .font(
                                .system(
                                    size: 13,
                                    weight: .bold
                                )
                            )
                            .foregroundStyle(Theme.accent)
                            .padding(.top, 2)

                        VStack(
                            alignment: .leading,
                            spacing: 2
                        ) {

                            Text(
                                L10n.string(
                                    benefit.title,
                                    languageCode: settings.languageCode
                                )
                            )
                            .font(Theme.Font.body(13))
                            .fontWeight(.semibold)

                            Text(
                                L10n.string(
                                    benefit.detail,
                                    languageCode: settings.languageCode
                                )
                            )
                            .font(Theme.Font.caption(11))
                            .foregroundStyle(
                                .white.opacity(0.6)
                            )
                            .lineSpacing(2)
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 13)
                    .frame(minHeight: 65)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .background(
                        Color.white.opacity(0.04)
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 10
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: 10
                        )
                        .stroke(
                            Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                    }
                }
            }

            Spacer()
        }
    }

    // MARK: - Plans Column

    private var plansColumn: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            HStack {

                Text(
                    L10n.string(
                        "Choose Your Plan",
                        languageCode: settings.languageCode
                    )
                )
                .font(Theme.Font.title(16))
                .fontWeight(.bold)

                Spacer()

                Button(L10n.string("Restore", languageCode: settings.languageCode)) {
                    Task { await restorePurchases() }
                }
                .buttonStyle(.plain)
                .font(Theme.Font.caption(10))
                .foregroundStyle(Theme.accent)
                .disabled(storeKit.isLoading)
            }
            .padding(.bottom, 8)

            // MARK: Plans

            VStack(spacing: 9) {

                ForEach(availablePlans) { plan in
                    planRow(plan)
                }
            }

            if !storeKit.isConfigured {
                purchaseAvailabilityMessage("Purchases are not configured for this build.")
            } else if let message = storeKit.lastErrorMessage {
                purchaseAvailabilityMessage(message)
            }

            Spacer(minLength: 0)

            // MARK: Continue Button

            Button {
                Task {
                    await purchaseSelectedPlan()
                }
            } label: {

                Text(
                    L10n.string(
                        "Continue",
                        languageCode: settings.languageCode
                    )
                )
                .font(
                    .system(
                        size: 15,
                        weight: .bold
                    )
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Theme.accent)
                .foregroundStyle(.white)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 10
                    )
                )
            }
            .buttonStyle(.plain)
            .disabled(storeKit.isLoading || selectedProduct == nil)

            // MARK: Terms & Privacy

            HStack {

                Button(
                    L10n.string(
                        "Terms of Service",
                        languageCode: settings.languageCode
                    )
                ) {
                    openConfiguredURL(
                        AppConfiguration.termsOfServiceURL
                    )
                }

                Spacer()

                Button(
                    L10n.string(
                        "Privacy Policy",
                        languageCode: settings.languageCode
                    )
                ) {
                    openConfiguredURL(
                        AppConfiguration.privacyPolicyURL
                    )
                }
            }
            .buttonStyle(.plain)
            .font(Theme.Font.caption(10))
            .foregroundStyle(
                .white.opacity(0.4)
            )
            .underline()
        }
    }

    // MARK: - Plan Row

    private func planRow(
        _ plan: SubscriptionPlan
    ) -> some View {

        let isSelected = selectedPlan == plan

        return Button {

            selectedPlan = plan

        } label: {

            HStack(spacing: 0) {

                // MARK: Plan Information

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {

                    HStack(spacing: 8) {

                        Text(
                            L10n.string(
                                displayName(for: plan),
                                languageCode: settings.languageCode
                            )
                        )
                        .font(Theme.Font.body(13))
                        .fontWeight(.bold)
                        .lineLimit(2)
                        .frame(
                            width: titleWidth(for: plan),
                            alignment: .leading
                        )

                        if let badge = badge(for: plan) {
                            badgeView(text: badge)
                        }
                    }

                    Text(
                        L10n.string(
                            displayDescription(for: plan),
                            languageCode: settings.languageCode
                        )
                    )
                    .font(Theme.Font.caption(10))
                    .foregroundStyle(
                        .white.opacity(0.6)
                    )
                }
                .frame(width: 170, alignment: .leading)

                Spacer()

                // MARK: Price

                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(displayPrice(for: plan))
                        .font(Theme.Font.heading(21))
                        .fontWeight(.bold)
                        .lineLimit(1)

                    if !displayPeriod(for: plan).isEmpty {

                        Text(
                            L10n.string(
                                displayPeriod(for: plan),
                                languageCode: settings.languageCode
                            )
                        )
                        .font(Theme.Font.caption(10))
                        .foregroundStyle(
                            .white.opacity(0.5)
                        )
                        .lineLimit(1)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(height: plan == .weekly ? 64 : 78)
            .background(
                Color.white.opacity(0.04)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 10
                )
            )
            .overlay {

                RoundedRectangle(
                    cornerRadius: 10
                )
                .stroke(
                    isSelected
                    ? Theme.accent
                    : Color.white.opacity(0.08),
                    lineWidth: isSelected ? 2 : 1
                )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Badge

    @ViewBuilder
    private func badgeView(
        text: String
    ) -> some View {

        let localizedText = L10n.string(
            text,
            languageCode: settings.languageCode
        )

        let isYellowStyle =
            text.contains("TRIAL")
            || text.contains("VALUE")

        Text(localizedText)
            .font(
                .system(
                    size: 9,
                    weight: .heavy
                )
            )
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .frame(
                width: text.contains("TRIAL") ? 66 :
                    (text.contains("VALUE") ? 43 : nil),
                alignment: .leading
            )
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                isYellowStyle
                ? Color(hex: "4D3E13")
                : Theme.accent
            )
            .foregroundStyle(
                isYellowStyle
                ? Color(hex: "FDE047")
                : .white
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 4
                )
            )
    }

    // MARK: - StoreKit

    private var selectedProduct: Product? {
        storeKit.product(for: selectedPlan)
    }

    private var availablePlans: [SubscriptionPlan] {
        let configured = SubscriptionPlan.allCases.filter(storeKit.isPlanConfigured)
        return configured.isEmpty ? SubscriptionPlan.allCases : configured
    }

    private func displayPrice(for plan: SubscriptionPlan) -> String {
        plan.fallbackDisplayPrice
    }

    private func displayName(for plan: SubscriptionPlan) -> String {
        plan.title
    }

    private func displayDescription(for plan: SubscriptionPlan) -> String {
        plan.detail
    }

    private func displayPeriod(for plan: SubscriptionPlan) -> String {
        plan.period
    }

    private func titleWidth(for plan: SubscriptionPlan) -> CGFloat {
        switch plan {
        case .weekly:
            return 82
        case .monthly:
            return 55
        case .annual:
            return 48
        case .lifetime:
            return 64
        }
    }

    private func badge(for plan: SubscriptionPlan) -> String? {
        plan.badge
    }

    private func prepareStoreKit() async {

        await storeKit.prepare()

        // Keep Annual selected by default.
        // If Annual is unavailable but another
        // StoreKit product exists, select that product.

        if storeKit.product(for: selectedPlan) == nil,
           let firstAvailablePlan = availablePlans.first(
                where: {
                    storeKit.product(for: $0) != nil
                }
           ) {

            selectedPlan = firstAvailablePlan
        }
    }

    // MARK: - Purchase

    private func purchaseSelectedPlan() async {

        guard let product = selectedProduct else {

            showAlert(
                "Purchases are not configured for this build."
            )

            return
        }

        do {

            let result = try await storeKit.purchase(product)

            switch result {

            case .purchased:
                settings.updatePremiumEntitlement(storeKit.hasPremiumEntitlement)
                onPurchaseSuccess()
                dismiss()

            case .pending:

                showAlert(
                    "Your purchase is pending approval."
                )

            case .cancelled:
                break
            }

        } catch {
            showAlert(error.localizedDescription)
        }
    }

    private func restorePurchases() async {
        do {
            try await storeKit.restorePurchases()
            settings.updatePremiumEntitlement(storeKit.hasPremiumEntitlement)
            showAlert(
                storeKit.hasPremiumEntitlement
                    ? "Your purchases were restored."
                    : "No previous purchases were found."
            )
        } catch {
            showAlert("Purchases could not be restored. Please try again.")
        }
    }

    private func purchaseAvailabilityMessage(_ message: String) -> some View {
        Text(L10n.string(message, languageCode: settings.languageCode))
            .font(Theme.Font.caption(12))
            .foregroundStyle(.white.opacity(0.65))
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - URL

    private func openConfiguredURL(
        _ url: URL?
    ) {

        guard let url else {

            showAlert(
                "This link has not been configured for this build."
            )

            return
        }

        openURL(url)
    }

    // MARK: - Alert

    private func showAlert(
        _ key: String
    ) {

        alertMessage = L10n.string(
            key,
            languageCode: settings.languageCode
        )

        isShowingAlert = true
    }
}
