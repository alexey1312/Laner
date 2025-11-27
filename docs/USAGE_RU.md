# Руководство по использованию Swiftlane

Пошаговые инструкции по использованию Swiftlane.

**Другие языки:** [English](USAGE.md)

## Требования

- macOS 13.0+
- Swift 6.0+
- Xcode 16.0+ (для операций сборки iOS/macOS)

## Установка

### Через mise (рекомендуется)

```bash
mise use -g ubi:alexey1312/Swiftlane
```

Или добавьте в `.mise.toml`:

```toml
[tools]
"ubi:alexey1312/Swiftlane" = "latest"
```

### Из исходников

```bash
git clone https://github.com/alexey1312/Swiftlane.git
cd Swiftlane
swift build -c release
```

Исполняемый файл будет доступен по пути `.build/release/swiftlane`.

### Ручная загрузка

Скачайте с [GitHub Releases](https://github.com/alexey1312/Swiftlane/releases).

## Быстрый старт

### Шаг 1: Проверка окружения

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

### Шаг 2: Инициализация проекта

Создайте конфигурационный файл в вашем проекте:

```bash
cd /путь/к/вашему/проекту
swiftlane init
```

Это создаст файл `Swiftlane/Swiftlanefile.swift` с примером конфигурации.

### Шаг 3: Настройка lanes

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

### Шаг 4: Запуск lanes

```bash
# Просмотр доступных lanes
swiftlane lanes

# Запуск конкретного lane
swiftlane lane build
swiftlane lane test
swiftlane lane release
```

## Основные команды

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

## Настройка Code Signing (Match)

### Шаг 1: Настройка переменных окружения

```bash
export MATCH_PASSWORD="ваш_пароль_шифрования"
export MATCH_GIT_URL="git@github.com:org/certificates.git"
export MATCH_TEAM_ID="TEAM123"
```

### Шаг 2: Инициализация Match

```bash
swiftlane match init --git-url git@github.com:org/certificates.git --team-id TEAM123
```

### Шаг 3: Синхронизация сертификатов

```bash
# Синхронизация сертификатов для App Store
swiftlane match sync --type appstore

# Синхронизация сертификатов для разработки
swiftlane match sync --type development
```

### Шаг 4: Регистрация устройств

```bash
swiftlane match register --devices-file devices.txt
```

## Загрузка в TestFlight

### Шаг 1: Настройка API ключей App Store Connect

```bash
export APP_STORE_CONNECT_API_KEY_ID="D383SF739"
export APP_STORE_CONNECT_API_ISSUER_ID="6053b7fe-68a8-4acb-89be-165aa6465141"
export APP_STORE_CONNECT_API_KEY_PATH="/путь/к/AuthKey.p8"
```

### Шаг 2: Загрузка IPA

```bash
# Базовая загрузка
swiftlane upload testflight --ipa путь/к/app.ipa --app-id 123456789

# С распределением по группам бета-тестеров
swiftlane upload testflight --ipa путь/к/app.ipa --app-id 123456789 \
    --groups "Internal,External Testers" \
    --changelog "Исправления ошибок"
```

## Глобальные опции

Все команды поддерживают:

```bash
-v, --verbose     # Подробный вывод (уровень debug)
-q, --quiet       # Тихий режим (только ошибки)
-d, --directory   # Запуск в другой директории
```

## Пример полного CI/CD пайплайна

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

## Устранение неполадок

### Ошибка "Command not found"

Убедитесь, что swiftlane добавлен в PATH:

```bash
export PATH="$PATH:/путь/к/swiftlane"
```

### Ошибки Code Signing

1. Проверьте MATCH_PASSWORD
2. Убедитесь в доступе к Git репозиторию сертификатов
3. Запустите `swiftlane match sync --type development`

### Ошибки TestFlight

1. Проверьте API ключи App Store Connect
2. Убедитесь, что App ID корректен
3. Используйте `--verbose` для отладки
