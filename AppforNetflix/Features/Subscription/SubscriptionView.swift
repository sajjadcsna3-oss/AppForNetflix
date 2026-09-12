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

            HStack(spacing: 0) {

                benefitsColumn
                    .frame(width: 380)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 40)
                    .padding(.top, 10)

                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.vertical, 32)

                plansColumn
                    .frame(width: 440)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 40)
            }

            closeButton
        }
        .background(Color(hex: "151517"))
        .foregroundStyle(.white)
        .frame(width: 960, height: 650)
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
                        size: 13,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.leading, 24)
        .padding(.top, 24)
    }

    // MARK: - Benefits Column

    private var benefitsColumn: some View {
        VStack(
            alignment: .leading,
            spacing: 30
        ) {

            Text(
                L10n.string(
                    "Subscribe for a better\nviewing experience.",
                    languageCode: settings.languageCode
                )
            )
            .font(Theme.Font.title(28))
            .fontWeight(.bold)
            .fixedSize(
                horizontal: false,
                vertical: true
            )
            .lineSpacing(4)
            .padding(.bottom, 4)

            VStack(spacing: 12) {

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
                            spacing: 4
                        ) {

                            Text(
                                L10n.string(
                                    benefit.title,
                                    languageCode: settings.languageCode
                                )
                            )
                            .font(Theme.Font.body(14))
                            .fontWeight(.semibold)

                            Text(
                                L10n.string(
                                    benefit.detail,
                                    languageCode: settings.languageCode
                                )
                            )
                            .font(Theme.Font.caption(12))
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
                    .padding(16)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .background(
                        Color.white.opacity(0.04)
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 12
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: 12
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
            spacing: 16
        ) {

            HStack {

                Text(
                    L10n.string(
                        "Choose Your Plan",
                        languageCode: settings.languageCode
                    )
                )
                .font(Theme.Font.title(22))
                .fontWeight(.bold)
            }
            .padding(.bottom, 8)

            // MARK: Plans

            VStack(spacing: 12) {

                ForEach(availablePlans) { plan in
                    planRow(plan)
                }
            }

            if !storeKit.isConfigured {
                purchaseAvailabilityMessage("Purchases are not configured for this build.")
            } else if let message = storeKit.lastErrorMessage {
                purchaseAvailabilityMessage(message)
            }

            Spacer()

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
                        size: 16,
                        weight: .bold
                    )
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
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

            Button(
                L10n.string(
                    "Restore Purchases",
                    languageCode: settings.languageCode
                )
            ) {
                Task {
                    await restorePurchases()
                }
            }
            .buttonStyle(.plain)
            .font(Theme.Font.caption(12))
            .foregroundStyle(.white.opacity(0.7))
            .disabled(storeKit.isLoading)

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
            .font(Theme.Font.caption(11))
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

            HStack {

                // MARK: Plan Information

                VStack(
                    alignment: .leading,
                    spacing: 6
                ) {

                    HStack(spacing: 8) {

                        Text(
                            L10n.string(
                                displayName(for: plan),
                                languageCode: settings.languageCode
                            )
                        )
                        .font(Theme.Font.body(15))
                        .fontWeight(.bold)

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
                    .font(Theme.Font.caption(12))
                    .foregroundStyle(
                        .white.opacity(0.6)
                    )
                }

                Spacer()

                // MARK: Price

                VStack(
                    alignment: .trailing,
                    spacing: 2
                ) {

                    Text(displayPrice(for: plan))
                    .font(Theme.Font.heading(20))
                    .fontWeight(.bold)

                    if !displayPeriod(for: plan).isEmpty {

                        Text(
                            L10n.string(
                                displayPeriod(for: plan),
                                languageCode: settings.languageCode
                            )
                        )
                        .font(Theme.Font.caption(11))
                        .foregroundStyle(
                            .white.opacity(0.5)
                        )
                    }
                }
            }
            .padding(18)
            .background(
                Color.white.opacity(0.04)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 12
                )
            )
            .overlay {

                RoundedRectangle(
                    cornerRadius: 12
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
                    size: 10,
                    weight: .heavy
                )
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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
        if let product = storeKit.product(for: plan) {
            return product.displayPrice
        }
        return "—"
    }

    private func displayName(for plan: SubscriptionPlan) -> String {
        storeKit.product(for: plan)?.displayName ?? plan.title
    }

    private func displayDescription(for plan: SubscriptionPlan) -> String {
        storeKit.product(for: plan)?.description ?? plan.detail
    }

    private func displayPeriod(for plan: SubscriptionPlan) -> String {
        guard let product = storeKit.product(for: plan) else { return plan.period }
        guard let period = product.subscription?.subscriptionPeriod else { return "" }
        let unit: String
        switch period.unit {
        case .day: unit = period.value == 1 ? "day" : "days"
        case .week: unit = period.value == 1 ? "week" : "weeks"
        case .month: unit = period.value == 1 ? "month" : "months"
        case .year: unit = period.value == 1 ? "year" : "years"
        @unknown default: return ""
        }
        let localizedUnit = L10n.string(unit, languageCode: settings.languageCode)
        return period.value == 1 ? "/\(localizedUnit)" : "/\(period.value) \(localizedUnit)"
    }

    private func badge(for plan: SubscriptionPlan) -> String? {
        guard storeKit.isPlanConfigured(plan) else { return plan.badge }
        guard plan == .monthly else { return plan.badge }
        return storeKit.product(for: plan)?.subscription?.introductoryOffer == nil
            ? nil
            : plan.badge
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
