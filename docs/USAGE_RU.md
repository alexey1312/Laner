# Руководство по использованию Laner

Пошаговые инструкции по использованию Laner.

**Другие языки:** [English](USAGE.md)

## Требования

- macOS 13.0+
- Swift 6.0+
- Xcode 16.0+ (для операций сборки iOS/macOS)

## Установка

### Через mise (рекомендуется)

```bash
mise use -g ubi:alexey1312/Laner
```

Или добавьте в `.mise.toml`:

```toml
[tools]
"ubi:alexey1312/Laner" = "latest"
```

### Из исходников

```bash
git clone https://github.com/alexey1312/Laner.git
cd Laner
swift build -c release
```

Исполняемый файл будет доступен по пути `.build/release/laner`.

### Ручная загрузка

Скачайте с [GitHub Releases](https://github.com/alexey1312/Laner/releases).

## Быстрый старт

### Шаг 1: Проверка окружения

Убедитесь, что все необходимые инструменты установлены:

```bash
laner doctor
```

Команда проверит:

- Версию Swift
- Версию Git
- Наличие Xcode (только macOS)
- Доступность xcodebuild
- Доступность codesign
- Pkl runtime (встроенный)

### Шаг 2: Инициализация проекта

Создайте конфигурационный файл в вашем проекте:

```bash
cd /путь/к/вашему/проекту
laner init
```

Это создаст `Laner/Lanerfile.pkl` (конфигурация) и `Laner/pkl/Lanerfile.pkl` (схема).

### Шаг 3: Настройка lanes

Отредактируйте `Laner/Lanerfile.pkl` под ваши нужды:

```pkl
amends "pkl/Lanerfile.pkl"

lanes {
  new {
    name = "build"
    description = "Сборка приложения"
    actions {
      new GymAction {
        scheme = "МойПроект"
        configuration = "debug"
      }
    }
  }

  new {
    name = "test"
    description = "Запуск тестов"
    actions {
      new ScanAction {
        scheme = "МойПроект"
        codeCoverage = true
      }
    }
  }

  new {
    name = "release"
    description = "Сборка и архивация для релиза"
    actions {
      new MatchAction {
        certificateType = "appstore"
      }
      new GymAction {
        scheme = "МойПроект"
        configuration = "release"
      }
      new ArchiveAction {
        scheme = "МойПроект"
        exportMethod = "app-store"
      }
    }
  }
}
```

### Шаг 4: Запуск lanes

```bash
# Просмотр доступных lanes
laner lanes

# Запуск конкретного lane
laner lane build
laner lane test
laner lane release
```

## Основные команды

| Команда                   | Описание                     |
| ------------------------- | ---------------------------- |
| `laner version`           | Показать версию Laner        |
| `laner doctor`            | Проверить окружение          |
| `laner init`              | Инициализировать проект      |
| `laner lanes`             | Список доступных lanes       |
| `laner lane <имя>`        | Выполнить lane               |
| `laner build`             | Собрать проект               |
| `laner test`              | Запустить тесты              |
| `laner match sync`        | Синхронизировать сертификаты |
| `laner upload testflight` | Загрузить в TestFlight       |

## Доступные действия

| Действие                | Описание                                     |
| ----------------------- | -------------------------------------------- |
| `GymAction`             | Сборка iOS/macOS приложения через xcodebuild |
| `ScanAction`            | Запуск тестов через xcodebuild               |
| `ArchiveAction`         | Архивация приложения и экспорт IPA           |
| `MatchAction`           | Синхронизация сертификатов и профилей        |
| `PilotAction`           | Загрузка сборки в TestFlight                 |
| `RegisterDevicesAction` | Регистрация устройств в Apple Dev Portal     |
| `ShellAction`           | Выполнение произвольной shell-команды        |

## Настройка Code Signing (Match)

### Шаг 1: Настройка переменных окружения

```bash
export MATCH_PASSWORD="ваш_пароль_шифрования"
export MATCH_GIT_URL="git@github.com:org/certificates.git"
export MATCH_TEAM_ID="TEAM123"
```

### Шаг 2: Инициализация Match

```bash
laner match init --git-url git@github.com:org/certificates.git --team-id TEAM123
```

### Шаг 3: Синхронизация сертификатов

```bash
# Синхронизация сертификатов для App Store
laner match sync --type appstore

# Синхронизация сертификатов для разработки
laner match sync --type development
```

### Шаг 4: Регистрация устройств

```bash
laner match register --devices-file devices.txt
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
laner upload testflight --ipa путь/к/app.ipa --app-id 123456789

# С распределением по группам бета-тестеров
laner upload testflight --ipa путь/к/app.ipa --app-id 123456789 \
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

```pkl
amends "pkl/Lanerfile.pkl"

local isCI = read?("env:CI") == "true"

lanes {
  // Сборка для разработки
  new {
    name = "dev"
    description = "Сборка для разработки"
    actions {
      new GymAction {
        scheme = "App"
        configuration = "debug"
      }
    }
  }

  // Запуск тестов
  new {
    name = "test"
    description = "Запуск тестов с покрытием"
    actions {
      new ScanAction {
        scheme = "App"
        codeCoverage = true
      }
    }
  }

  // Релиз в TestFlight
  new {
    name = "testflight"
    description = "Сборка и загрузка в TestFlight"
    actions {
      new MatchAction {
        certificateType = "appstore"
        readonly = isCI
      }
      new GymAction {
        scheme = "App"
        configuration = "release"
      }
      new ArchiveAction {
        scheme = "App"
        exportMethod = "app-store"
      }
      new PilotAction {
        appId = "123456789"
        changelog = "Новые функции и исправления"
        groups {
          "Internal Testers"
        }
      }
    }
  }

  // Бета-сборка с новыми устройствами
  new {
    name = "beta"
    description = "Регистрация устройств и бета-сборка"
    actions {
      new RegisterDevicesAction {
        file = "devices.txt"
      }
      new MatchAction {
        certificateType = "adhoc"
        forceForNewDevices = true
      }
      new GymAction {
        scheme = "App"
        configuration = "release"
      }
    }
  }

  // Shell-команды
  new {
    name = "lint"
    description = "Запуск линтера"
    actions {
      new ShellAction {
        command = "swiftlint"
        arguments {}
      }
    }
  }
}
```

## Возможности конфигурации Pkl

Pkl — язык конфигурации от Apple, который обеспечивает:

- **Типобезопасность** — схема валидирует конфигурацию до выполнения
- **Быстрое вычисление** — миллисекунды вместо секунд (без компиляции)
- **Условная логика** — используйте `read?("env:CI")` для условий на основе окружения
- **Без компиляции Swift** — конфигурация полностью декларативна

## Устранение неполадок

### Ошибка "Command not found"

Убедитесь, что laner добавлен в PATH:

```bash
export PATH="$PATH:/путь/к/laner"
```

### Ошибки Code Signing

1. Проверьте MATCH_PASSWORD
2. Убедитесь в доступе к Git репозиторию сертификатов
3. Запустите `laner match sync --type development`

### Ошибки TestFlight

1. Проверьте API ключи App Store Connect
2. Убедитесь, что App ID корректен
3. Используйте `--verbose` для отладки

### Ошибки вычисления Pkl

1. Проверьте синтаксис `Laner/Lanerfile.pkl`
2. Убедитесь, что файл схемы `Laner/pkl/Lanerfile.pkl` существует
3. Запустите `laner doctor` для валидации конфигурации
