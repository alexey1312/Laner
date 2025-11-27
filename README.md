# Swiftlane

[![CI](https://github.com/alexey1312/Swiftlane/actions/workflows/ci.yml/badge.svg)](https://github.com/alexey1312/Swiftlane/actions/workflows/ci.yml)

A Swift-native CI/CD automation tool for iOS and macOS projects.

---

<details>
<summary><strong>🇷🇺 Инструкция на русском языке</strong></summary>

## Инструкция по использованию Swiftlane

### Требования

- macOS 13.0+
- Swift 6.0+
- Xcode 16.0+ (для операций сборки iOS/macOS)

### Установка

#### Через mise (рекомендуется)

```bash
mise use -g ubi:alexey1312/Swiftlane
```

Или добавьте в `.mise.toml`:

```toml
[tools]
"ubi:alexey1312/Swiftlane" = "latest"
```

#### Из исходников

```bash
git clone https://github.com/alexey1312/Swiftlane.git
cd Swiftlane
swift build -c release
```

Исполняемый файл будет доступен по пути `.build/release/swiftlane`.

#### Ручная загрузка

Скачайте с [GitHub Releases](https://github.com/alexey1312/Swiftlane/releases).

### Быстрый старт

#### Шаг 1: Проверка окружения

Убедитесь, что все необходимые инструменты установлены:

```bash
swiftlane doctor
```

Команда проверит:
- Версию Swift
- Версию Git
- Наличие Xcode (только macOS)
- Доступность xcodebuild
- Доступность codesign

#### Шаг 2: Инициализация проекта

Создайте конфигурационный файл в вашем проекте:

```bash
cd /путь/к/вашему/проекту
swiftlane init
```

Это создаст файл `Swiftlane/Swiftlanefile.swift` с примером конфигурации.

#### Шаг 3: Настройка lanes

Отредактируйте `Swiftlane/Swiftlanefile.swift` под ваши нужды:

```swift
import SwiftlaneDSL

let swiftlane = Swiftlanefile(
    lanes: [
        Lane("build") {
            gym(scheme: "МойПроект", configuration: .debug)
        },
        Lane("test") {
            scan(scheme: "МойПроектTests", codeCoverage: true)
        },
        Lane("release") {
            match(type: .appstore)
            gym(scheme: "МойПроект", configuration: .release)
            archive(scheme: "МойПроект", exportMethod: .appStore)
        }
    ]
)
```

#### Шаг 4: Запуск lanes

```bash
# Просмотр доступных lanes
swiftlane lanes

# Запуск конкретного lane
swiftlane lane build
swiftlane lane test
swiftlane lane release
```

### Основные команды

| Команда | Описание |
|---------|----------|
| `swiftlane version` | Показать версию Swiftlane |
| `swiftlane doctor` | Проверить окружение |
| `swiftlane init` | Инициализировать проект |
| `swiftlane lanes` | Список доступных lanes |
| `swiftlane lane <имя>` | Выполнить lane |
| `swiftlane build` | Собрать проект |
| `swiftlane test` | Запустить тесты |
| `swiftlane match sync` | Синхронизировать сертификаты |
| `swiftlane upload testflight` | Загрузить в TestFlight |

### Настройка Code Signing (Match)

#### Шаг 1: Настройка переменных окружения

```bash
export MATCH_PASSWORD="ваш_пароль_шифрования"
export MATCH_GIT_URL="git@github.com:org/certificates.git"
export MATCH_TEAM_ID="TEAM123"
```

#### Шаг 2: Инициализация Match

```bash
swiftlane match init --git-url git@github.com:org/certificates.git --team-id TEAM123
```

#### Шаг 3: Синхронизация сертификатов

```bash
# Синхронизация сертификатов для App Store
swiftlane match sync --type appstore

# Синхронизация сертификатов для разработки
swiftlane match sync --type development
```

#### Шаг 4: Регистрация устройств

```bash
swiftlane match register --devices-file devices.txt
```

### Загрузка в TestFlight

#### Шаг 1: Настройка API ключей App Store Connect

```bash
export APP_STORE_CONNECT_API_KEY_ID="D383SF739"
export APP_STORE_CONNECT_API_ISSUER_ID="6053b7fe-68a8-4acb-89be-165aa6465141"
export APP_STORE_CONNECT_API_KEY_PATH="/путь/к/AuthKey.p8"
```

#### Шаг 2: Загрузка IPA

```bash
# Базовая загрузка
swiftlane upload testflight --ipa путь/к/app.ipa --app-id 123456789

# С распределением по группам бета-тестеров
swiftlane upload testflight --ipa путь/к/app.ipa --app-id 123456789 \
    --groups "Internal,External Testers" \
    --changelog "Исправления ошибок"
```

### Глобальные опции

Все команды поддерживают:

```bash
-v, --verbose     # Подробный вывод (уровень debug)
-q, --quiet       # Тихий режим (только ошибки)
-d, --directory   # Запуск в другой директории
```

### Пример полного CI/CD пайплайна

```swift
import SwiftlaneDSL

let swiftlane = Swiftlanefile(
    lanes: [
        // Сборка для разработки
        Lane("dev") {
            gym(scheme: "App", configuration: .debug)
        },

        // Запуск тестов
        Lane("test") {
            scan(scheme: "AppTests", codeCoverage: true)
        },

        // Релиз в TestFlight
        Lane("testflight") {
            match(type: .appstore, readonly: true)
            gym(scheme: "App", exportMethod: .appStore)
            pilot(
                appId: "123456789",
                changelog: "Новые функции и исправления",
                groups: ["Internal Testers"]
            )
        },

        // Бета-сборка с новыми устройствами
        Lane("beta") {
            registerDevices(file: "devices.txt")
            match(type: .adhoc, forceForNewDevices: true)
            gym(scheme: "App", configuration: .release)
        }
    ]
)
```

### Устранение неполадок

#### Ошибка "Command not found"
Убедитесь, что swiftlane добавлен в PATH:
```bash
export PATH="$PATH:/путь/к/swiftlane"
```

#### Ошибки Code Signing
1. Проверьте MATCH_PASSWORD
2. Убедитесь в доступе к Git репозиторию сертификатов
3. Запустите `swiftlane match sync --type development`

#### Ошибки TestFlight
1. Проверьте API ключи App Store Connect
2. Убедитесь, что App ID корректен
3. Используйте `--verbose` для отладки

</details>

---

<details open>
<summary><strong>🇬🇧 English Instructions</strong></summary>

## Usage Instructions

### Requirements

- macOS 13.0+
- Swift 6.0+
- Xcode 16.0+ (for iOS/macOS build operations)

### Installation

#### Using mise (recommended)

```bash
mise use -g ubi:alexey1312/Swiftlane
```

Or add to `.mise.toml`:

```toml
[tools]
"ubi:alexey1312/Swiftlane" = "latest"
```

#### From Source

```bash
git clone https://github.com/alexey1312/Swiftlane.git
cd Swiftlane
swift build -c release
```

The executable will be available at `.build/release/swiftlane`.

#### Manual Download

Download from [GitHub Releases](https://github.com/alexey1312/Swiftlane/releases).

### Quick Start

#### Step 1: Check Environment

Ensure all required tools are installed:

```bash
swiftlane doctor
```

This checks:
- Swift version
- Git version
- Xcode availability (macOS only)
- xcodebuild availability
- codesign availability

#### Step 2: Initialize Project

Create a configuration file in your project:

```bash
cd /path/to/your/project
swiftlane init
```

This creates `Swiftlane/Swiftlanefile.swift` with an example configuration.

#### Step 3: Configure Lanes

Edit `Swiftlane/Swiftlanefile.swift` to match your needs:

```swift
import SwiftlaneDSL

let swiftlane = Swiftlanefile(
    lanes: [
        Lane("build") {
            gym(scheme: "MyProject", configuration: .debug)
        },
        Lane("test") {
            scan(scheme: "MyProjectTests", codeCoverage: true)
        },
        Lane("release") {
            match(type: .appstore)
            gym(scheme: "MyProject", configuration: .release)
            archive(scheme: "MyProject", exportMethod: .appStore)
        }
    ]
)
```

#### Step 4: Run Lanes

```bash
# View available lanes
swiftlane lanes

# Run a specific lane
swiftlane lane build
swiftlane lane test
swiftlane lane release
```

### Core Commands

| Command | Description |
|---------|-------------|
| `swiftlane version` | Show Swiftlane version |
| `swiftlane doctor` | Check environment |
| `swiftlane init` | Initialize project |
| `swiftlane lanes` | List available lanes |
| `swiftlane lane <name>` | Execute a lane |
| `swiftlane build` | Build project |
| `swiftlane test` | Run tests |
| `swiftlane match sync` | Sync certificates |
| `swiftlane upload testflight` | Upload to TestFlight |

### Code Signing Setup (Match)

#### Step 1: Set Environment Variables

```bash
export MATCH_PASSWORD="your_encryption_password"
export MATCH_GIT_URL="git@github.com:org/certificates.git"
export MATCH_TEAM_ID="TEAM123"
```

#### Step 2: Initialize Match

```bash
swiftlane match init --git-url git@github.com:org/certificates.git --team-id TEAM123
```

#### Step 3: Sync Certificates

```bash
# Sync App Store certificates
swiftlane match sync --type appstore

# Sync development certificates
swiftlane match sync --type development
```

#### Step 4: Register Devices

```bash
swiftlane match register --devices-file devices.txt
```

### TestFlight Upload

#### Step 1: Configure App Store Connect API Keys

```bash
export APP_STORE_CONNECT_API_KEY_ID="D383SF739"
export APP_STORE_CONNECT_API_ISSUER_ID="6053b7fe-68a8-4acb-89be-165aa6465141"
export APP_STORE_CONNECT_API_KEY_PATH="/path/to/AuthKey.p8"
```

#### Step 2: Upload IPA

```bash
# Basic upload
swiftlane upload testflight --ipa path/to/app.ipa --app-id 123456789

# With beta group distribution
swiftlane upload testflight --ipa path/to/app.ipa --app-id 123456789 \
    --groups "Internal,External Testers" \
    --changelog "Bug fixes and improvements"
```

### Global Options

All commands support:

```bash
-v, --verbose     # Enable debug-level logging
-q, --quiet       # Suppress all output except errors
-d, --directory   # Run in a different directory
```

### Complete CI/CD Pipeline Example

```swift
import SwiftlaneDSL

let swiftlane = Swiftlanefile(
    lanes: [
        // Development build
        Lane("dev") {
            gym(scheme: "App", configuration: .debug)
        },

        // Run tests
        Lane("test") {
            scan(scheme: "AppTests", codeCoverage: true)
        },

        // Release to TestFlight
        Lane("testflight") {
            match(type: .appstore, readonly: true)
            gym(scheme: "App", exportMethod: .appStore)
            pilot(
                appId: "123456789",
                changelog: "New features and bug fixes",
                groups: ["Internal Testers"]
            )
        },

        // Beta build with new devices
        Lane("beta") {
            registerDevices(file: "devices.txt")
            match(type: .adhoc, forceForNewDevices: true)
            gym(scheme: "App", configuration: .release)
        }
    ]
)
```

### Troubleshooting

#### "Command not found" Error
Ensure swiftlane is in your PATH:
```bash
export PATH="$PATH:/path/to/swiftlane"
```

#### Code Signing Errors
1. Check MATCH_PASSWORD is set correctly
2. Ensure Git repository access for certificates
3. Run `swiftlane match sync --type development`

#### TestFlight Errors
1. Verify App Store Connect API keys
2. Ensure App ID is correct
3. Use `--verbose` for debugging

</details>

---

## Features

- **Build & Test**: Build and test iOS/macOS projects with xcodebuild
- **Code Signing (Match)**: Git-based certificate and profile management, Fastlane Match compatible
- **TestFlight Upload**: Upload builds to TestFlight with chunked uploads and beta distribution
- **Environment Detection**: Automatic CI detection (GitHub Actions, GitLab CI, Jenkins, etc.)
- **Lane DSL**: Define CI/CD workflows using Swift
- **Type-Safe Actions**: Build custom actions with full Swift type safety
- **Structured Logging**: Configurable logging with color support
- **Async/Await**: Modern Swift 6 concurrency throughout

## Module Structure

- **swiftlane** - CLI executable
- **SwiftlaneCore** - Internal implementation (commands, orchestration)
- **SwiftlaneDSL** - Public DSL API for defining lanes and actions
- **SwiftlaneKit** - Shared utilities (shell execution, logging, xcodebuild)
- **SwiftlanePluginKit** - Plugin development kit
- **SwiftlaneMatch** - Code signing management (Match-compatible)

## Development

```bash
# Build
swift build

# Run tests
swift test

# Run the CLI
swift run swiftlane --help

# Build for release
swift build -c release
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `MATCH_PASSWORD` | Encryption password for certificates |
| `MATCH_GIT_URL` | Git repository URL for certificate storage |
| `MATCH_TEAM_ID` | Apple Developer Team ID |
| `APP_STORE_APP_ID` | App Store Connect App ID (for pilot action) |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API Key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | App Store Connect Issuer ID |
| `APP_STORE_CONNECT_API_KEY_PATH` | Path to .p8 private key file |

## Documentation

- [Actions Reference](docs/ACTIONS.md) - Available DSL actions and custom action development
- [Environment Variables](docs/ENVIRONMENT_VARIABLES.md) - Complete environment variable reference
- [Implementation Plan](docs/IMPLEMENTATION_PLAN.md) - Architecture and development roadmap
- [Fastlane Analysis](docs/FASTLANE_ANALYSIS.md) - Comparison with Fastlane

## Roadmap

### Implemented

- [x] CLI with ArgumentParser (`build`, `test`, `doctor`, `version`, `init`, `lanes`, `lane`, `match`, `upload`)
- [x] ShellExecutor — async process runner
- [x] XcodebuildExecutor — build/test/archive wrapper
- [x] Structured logging with color support
- [x] CI environment detection
- [x] Lane and Action protocols
- [x] **Lane execution from Swift manifests** — `swiftlane lane <name>`
- [x] LaneBuilder result builder for declarative DSL
- [x] Built-in actions: `gym()`, `scan()`, `archive()`, `match()`, `registerDevices()`, `pilot()`
- [x] Manifest compilation and caching
- [x] **Code Signing (Match)** — git-based certificate management, Fastlane Match compatible
- [x] **TestFlight Upload** — chunked IPA upload via Build Upload API v4.1+, beta group distribution

### Planned

- [ ] **App Store Connect (Full)** — App Store submission (`deliver()`), metadata, screenshots, phased release
- [ ] **Firebase App Distribution** — upload and tester management
- [ ] **Notifications** — Slack, Jira integrations
- [ ] **Metrics** — build time tracking, IPA size monitoring
- [ ] **Plugin system** — extensible architecture

## License

MIT License - see LICENSE file for details.
