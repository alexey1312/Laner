# Future Proposal: Full App Store Connect Integration

## Summary

Extended App Store Connect functionality beyond MVP. This document captures future features researched from Apple's App Store Connect API documentation.

## Prerequisites

- `add-appstore-connect-upload` change must be implemented first
- Build Upload API v4.1+ working with chunked uploads
- pilot() action functional

## Phase 2: App Store Submission (deliver)

### Features

```toon
features[6]{feature,description}:
  deliver() action,DSL action for App Store submission
  Version creation,Create new app store versions via API
  Build attachment,Attach processed build to version
  Review submission,Submit for App Review
  Phased release,Gradual rollout management
  CLI commands,swiftlane deliver and swiftlane appstore commands
```

### API Endpoints

- POST /v1/appStoreVersions - Create version
- GET /v1/appStoreVersions/{id} - Get version
- PATCH /v1/appStoreVersions/{id} - Update version
- POST /v1/appStoreVersionSubmissions - Submit for review
- POST /v1/appStoreVersionPhasedReleases - Start phased release
- PATCH /v1/appStoreVersionPhasedReleases/{id} - Pause/resume/complete

### New Components

```swift
actor SubmissionService {
    func createVersion(appId: String, version: String, platform: Platform) async throws -> AppStoreVersion
    func attachBuild(versionId: String, buildId: String) async throws
    func submitForReview(versionId: String) async throws -> ReviewSubmission
    func createPhasedRelease(versionId: String) async throws -> PhasedRelease
    func pausePhasedRelease(releaseId: String) async throws
    func resumePhasedRelease(releaseId: String) async throws
    func completePhasedRelease(releaseId: String) async throws
}
```

---

## Phase 3: Metadata Management

### Features

```toon
features[5]{feature,description}:
  Version localizations,App description keywords whatsNew per locale
  Screenshots,Upload screenshots for all device types
  App previews,Video previews for app store
  Age rating,IDFA and content declarations
  metadata() action,DSL action for metadata updates
```

### API Endpoints

- POST /v1/appStoreVersionLocalizations - Create localization
- PATCH /v1/appStoreVersionLocalizations/{id} - Update description/keywords
- POST /v1/appScreenshots - Upload screenshot
- POST /v1/appPreviews - Upload video preview
- PATCH /v1/ageRatingDeclarations/{id} - Update age rating

### New Components

```swift
actor MetadataService {
    func setLocalization(versionId: String, locale: String, description: String?, keywords: String?, whatsNew: String?) async throws
    func uploadScreenshot(localizationId: String, displayTarget: DisplayTarget, imageData: Data) async throws
    func uploadPreview(localizationId: String, displayTarget: DisplayTarget, videoURL: URL) async throws
    func setAgeRating(versionId: String, declaration: AgeRatingDeclaration) async throws
}
```

---

## Phase 4: Analytics & Engagement

### Features

```toon
features[4]{feature,description}:
  Customer reviews,List and respond to reviews
  Review responses,Reply to user feedback
  Review filtering,Filter by rating territory date
  CLI commands,swiftlane reviews list and respond
```

### API Endpoints

- GET /v1/apps/{id}/customerReviews - List reviews
- GET /v1/customerReviews/{id} - Get review
- POST /v1/customerReviewResponses - Respond to review
- DELETE /v1/customerReviewResponses/{id} - Delete response

### New Components

```swift
actor ReviewsService {
    func listReviews(appId: String, filter: ReviewFilter?) async throws -> [CustomerReview]
    func getReview(id: String) async throws -> CustomerReview
    func respondToReview(reviewId: String, responseBody: String) async throws -> CustomerReviewResponse
    func deleteResponse(responseId: String) async throws
}

struct ReviewFilter {
    var territory: String?
    var rating: Int?
    var sort: ReviewSort?
}
```

---

## Phase 5: Monetization

### Features

```toon
features[4]{feature,description}:
  In-app purchases,Create and manage IAPs
  Subscriptions,Subscription groups and products
  Price management,Pricing tiers by territory
  CLI commands,swiftlane iap and subscriptions commands
```

### API Endpoints

- GET /v1/apps/{id}/inAppPurchasesV2 - List IAPs
- POST /v1/inAppPurchases - Create IAP
- GET /v1/subscriptionGroups - List subscription groups
- POST /v1/subscriptions - Create subscription

### New Components

```swift
actor MonetizationService {
    func listInAppPurchases(appId: String) async throws -> [InAppPurchase]
    func createInAppPurchase(appId: String, productId: String, type: IAPType, attributes: IAPAttributes) async throws
    func listSubscriptionGroups(appId: String) async throws -> [SubscriptionGroup]
    func createSubscription(groupId: String, productId: String, attributes: SubscriptionAttributes) async throws
}
```

---

## Implementation Priority

```toon
priority[4]{phase,priority,rationale}:
  Phase 2 deliver,High,Complete App Store workflow
  Phase 3 metadata,Medium,Common automation need
  Phase 4 reviews,Low,Nice to have for engagement
  Phase 5 monetization,Low,Specialized use case
```

## Documentation Source

Apple App Store Connect API documentation available via Sosumi.ai proxy:
```
https://sosumi.ai/documentation/appstoreconnectapi
```

Replace `developer.apple.com` with `sosumi.ai` in any Apple doc URL to get AI-readable markdown.
