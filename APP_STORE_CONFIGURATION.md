# App Store configuration

## Local configuration

`Config/Local.xcconfig` is ignored by Git. Copy `Config/Config.example.xcconfig`
when setting up another machine. The tracked `Shared.xcconfig` intentionally
contains no credentials or production URLs.

TMDB and Watchmode credentials compiled into a distributed Mac app can still be
recovered. Apply provider-side restrictions where available. For credentials
that must remain secret, use a backend flow: Mac app → your backend → provider.

## StoreKit products

Premium UI is shown only when at least one product identifier is configured.
Create products in App Store Connect and set the matching values in
`Local.xcconfig` or CI build settings:

- `STOREKIT_WEEKLY_PRODUCT_ID`: auto-renewable weekly subscription
- `STOREKIT_MONTHLY_PRODUCT_ID`: auto-renewable monthly subscription
- `STOREKIT_ANNUAL_PRODUCT_ID`: auto-renewable yearly subscription
- `STOREKIT_LIFETIME_PRODUCT_ID`: non-consumable lifetime unlock

Put the three subscriptions in one subscription group. Configure any monthly
introductory trial in App Store Connect; do not describe a trial in metadata or
UI unless the StoreKit product actually has that offer. Complete product
localizations, review screenshots, pricing, tax/banking agreements, availability,
and sandbox testing before enabling these identifiers in a submission build.

The app uses verified StoreKit 2 transactions, current entitlements,
`Transaction.updates`, expiration/revocation checks, and `AppStore.sync()`.

For a free first release, leave all four identifiers empty. This hides the
incomplete Premium entry points and avoids presenting paid functionality.

## Legal URLs

Set `PRIVACY_POLICY_URL` to the final public HTTPS policy before submission.
Set `TERMS_OF_SERVICE_URL` before enabling StoreKit products. The app deliberately
does not contain a fake production URL.

The privacy policy and App Store privacy answers should accurately describe:

- Firebase Authentication, Firebase user ID, name, and email address
- Account creation, password-reset email, profile updates, and deletion
- TMDB metadata and images, Watchmode, and JustWatch provider availability
- External streaming-provider, Google, and YouTube links
- Local preferences, selected language, platform settings, watchlist, and recent history
- Which information stays on-device and which is sent to service providers
- Retention, account deletion, contact details, and user privacy rights

## Attribution and rights

Add TMDB's approved, unmodified logo to the asset catalog with the exact asset
name `TMDBLogo`. The About & Credits UI is already prepared to display it and
contains TMDB's required notice plus explicit Watchmode and JustWatch credits.

Before commercial release, independently verify and document:

- A commercial TMDB license and its attribution requirements
- Watchmode plan, caching, redistribution, and attribution rights
- JustWatch attribution requirements for TMDB watch-provider data
- Rights to all poster, backdrop, cast, and metadata content
- Rights to Netflix, Prime Video, Disney+, Apple TV+, Hulu, Max, Peacock, and
  IMAX names and logos
- Whether the product name “App for Netflix” is authorized and does not imply
  affiliation, endorsement, ownership, or official-client status

No licensing or trademark permission is asserted by this project.

## Remaining submission setup

Supply the final AppIcon artwork, Apple development team/signing, permanent
bundle identifier, App Store metadata and screenshots, age rating, privacy
answers, export compliance, review notes/demo account, support URL, and any IAP
review information in App Store Connect.
