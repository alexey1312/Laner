# Analysis of Fastlane's Fundamental Problems

> Created: 2025-11-27

## Overview

Fastlane is an open-source automation tool for iOS and Android development that simplifies building, testing, and releasing apps. Despite its widespread adoption, it has several fundamental architectural and technical problems.

---

## 1. Dependency on Private Apple APIs (Spaceship)

**This is Fastlane's main architectural problem.**

Historically, Spaceship (Fastlane's core for interacting with Apple) used undocumented private Apple APIs:

### Problems:

- **Frequent breakages**: Apple periodically changes these APIs without notice. In 2019, a major breakage occurred when Apple removed endpoints that Fastlane was using
- **Unpredictability**: Users report that functionality can stop working suddenly — "worked two days ago, doesn't work today"
- **Incomplete migration**: Since 2018 (after the official App Store Connect API announcement), gradual migration has been underway, but it's still not complete

### Current Status:

Fastlane 3.0 plans to fully transition to the official App Store Connect API and use code generation from OpenAPI specifications.

### Sources:

- [Error 410 Gone Issue #14572](https://github.com/fastlane/fastlane/issues/14572)
- [Fastlane 3.0 Discussion #20463](https://github.com/fastlane/fastlane/discussions/20463)
- [SPACESHIP_SKIP_2FA_UPGRADE Issue #21301](https://github.com/fastlane/fastlane/issues/21301)

---

## 2. Ruby as a Technology Choice

Ruby creates numerous problems for iOS/Android developers:

### Version Conflicts

- Constant issues between system Ruby, Homebrew Ruby, RVM, rbenv
- Users regularly encounter version incompatibility errors

### Deprecated Gems

In Ruby 3.4+, gems `mutex_m` and `abbrev` are no longer included by default, breaking Fastlane. In Ruby 3.5+, `ostruct` will also be removed from the standard library.

### Environment Setup Complexity

- Requires Bundler and Gemfile
- Proper PATH configuration
- UTF-8 locale (`LC_ALL`, `LANG`)
- Many points of failure

### Foreign Ecosystem

Swift/Objective-C developers are forced to understand the Ruby ecosystem, creating an additional barrier to entry.

### Fastlane Recommendations:

```ruby
# Gemfile
gem "fastlane"

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
```

### Sources:

- [Ruby Version Problems Issue #16790](https://github.com/fastlane/fastlane/issues/16790)
- [Ruby 3.0 Support Plan Issue #17931](https://github.com/fastlane/fastlane/issues/17931)
- [Buildkite Fastlane Troubleshooting](https://buildkite.com/docs/pipelines/hosted-agents/mobile-delivery-cloud/troubleshooting-fastlane)

---

## 3. Code Signing Remains Complex

Despite `match` simplifying certificate management, code signing remains a problematic area:

### Match Complexity:

- Requires a separate Git repository (or Google Cloud/S3) for certificate storage
- Complex initial setup
- Need to synchronize between developers and CI

### Comparison with Alternatives:

Xcode Cloud solves code signing "out of the box" with automatic signing — in Apple's style, "it just works".

### Example Match Usage:

```ruby
lane :beta do
  match(type: "appstore", readonly: is_ci)
  gym(scheme: "Release")
end
```

### Sources:

- [Code Signing Troubleshooting](https://docs.fastlane.tools/codesigning/troubleshooting/)
- [Common Code Signing Issues](https://docs.fastlane.tools/codesigning/common-issues/)
- [Thoughts on Xcode Cloud](https://www.oliverbinns.co.uk/posts/xcode-cloud-thoughts/)

---

## 4. Maintenance Mode

Fastlane feels like a project in maintenance mode:

### Signs:

- **Outdated documentation**: references to Xcode 7-8, while the current version is Xcode 15+
- **Bug accumulation**: minor bugs go unfixed for years
- **Slowed development**: after Google's acquisition (2017) and subsequent transfer to the open-source community, activity has decreased

### History:

- 2015: Fastlane creation
- 2017: Acquired by Google/Fabric
- 2019: Transferred to open-source community
- 2021-2024: Maintenance mode, slow migration to official APIs

### Sources:

- [Fastlane for Indies (2024)](https://www.jessesquires.com/blog/2024/01/22/fastlane-for-indies/)

---

## 5. Limited Scope

Fastlane focuses only on release automation:

### What Fastlane Does NOT Do:

- Infrastructure management
- Full CI/CD pipeline
- Continuous Integration (only CD)
- Monitoring and alerting

### Integration Required:

For a complete CI/CD, integration with external systems is necessary:

- Jenkins
- GitHub Actions
- GitLab CI
- Bitrise
- CircleCI

### Sources:

- [Comparing Mobile CI/CD Providers](https://www.runway.team/blog/comparing-the-top-10-mobile-ci-cd-providers)

---

## 6. Two-Factor Authentication (2FA) Issues

### Current Situation:

- Apple requires 2FA for all developer accounts
- `fastlane spaceauth` creates temporary sessions that expire
- On CI, this requires manual updates or using an API Key

### Solution — API Key:

```ruby
app_store_connect_api_key(
  key_id: "D383SF739",
  issuer_id: "6053b7fe-68a8-4acb-89be-165aa6465141",
  key_filepath: "./AuthKey_D383SF739.p8"
)
```

Using an API key eliminates the need to deal with 2FA on CI machines.

### Sources:

- [2FA with Fastlane - Stack Overflow](https://stackoverflow.com/questions/63508108/two-factor-authentication-with-fastlane)

---

## 7. Comparison with Alternatives

| Aspect              | Fastlane             | Xcode Cloud   | GitHub Actions        |
| ------------------- | -------------------- | ------------- | --------------------- |
| **Code Signing**    | Complex (match)      | "Just works"  | Requires fastlane     |
| **Cost**            | Free                 | $50/100 hours | $4.80/hour Mac runner |
| **Customization**   | High                 | Limited       | High                  |
| **Setup**           | Complex              | Simple        | Medium                |
| **Dependencies**    | Ruby, gems           | None          | YAML workflows        |
| **Android Support** | Yes                  | No            | Yes                   |
| **Notifications**   | Slack, email, custom | Slack, email  | Any                   |

### When to Use Fastlane:

- Cross-platform projects (iOS + Android)
- Complex custom workflows
- Integration with existing CI systems
- Limited budget

### When to Consider Alternatives:

- **Xcode Cloud**: Solo developers, small iOS-only teams
- **GitHub Actions**: Open-source projects, already using GitHub
- **Bitrise**: Need UI for setup, mobile-first approach

---

## 8. Recommendations for Working with Fastlane

### Minimizing Problems:

1. **Use API Key** instead of Apple ID authentication
2. **Bundler is mandatory**: `bundle exec fastlane ...`
3. **Pin versions** in Gemfile.lock
4. **readonly mode on CI**: `match(readonly: true)`
5. **Verbose mode for debugging**: `fastlane [lane] --verbose`

### Example Gemfile:

```ruby
source "https://rubygems.org"

gem "fastlane", "~> 2.220"

# For Ruby 3.4+
gem "mutex_m"
gem "abbrev"

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
```

---

## 9. Conclusions for Laner Project

Analysis of Fastlane's problems reveals key areas that Laner can improve:

1. **Native Swift**: Eliminates Ruby dependency, understandable to iOS developers
2. **Official APIs**: Uses only App Store Connect API from the start
3. **Simple code signing**: Minimizes configuration for typical scenarios
4. **Type safety**: Errors at compile time, not runtime
5. **Modern architecture**: async/await, Swift Concurrency
6. **Ecosystem integration**: SPM, Xcode, Swift Package plugins

---

## Sources

- [Fastlane GitHub Issues](https://github.com/fastlane/fastlane/issues)
- [Fastlane 3.0 Discussion](https://github.com/fastlane/fastlane/discussions/20463)
- [Fastlane Troubleshooting Docs](https://docs.fastlane.tools/codesigning/troubleshooting/)
- [Comparing Mobile CI/CD Providers](https://www.runway.team/blog/comparing-the-top-10-mobile-ci-cd-providers)
- [Thoughts on Xcode Cloud](https://www.oliverbinns.co.uk/posts/xcode-cloud-thoughts/)
- [Fastlane for Indies (2024)](https://www.jessesquires.com/blog/2024/01/22/fastlane-for-indies/)
- [Buildkite Fastlane Troubleshooting](https://buildkite.com/docs/pipelines/hosted-agents/mobile-delivery-cloud/troubleshooting-fastlane)
- [Fastlane Docs](https://docs.fastlane.tools/)
