# FreeBikeControl

Нативный SwiftUI-мост Zwift Click V2 → MyWhoosh для macOS, iPhone и iPad.

## План дальнейшей работы

[Бэклог](BACKLOG.md) содержит приоритеты, зависимости, критерии готовности и матрицу проверки на Mac, iPhone и iPad. Следующие итерации можно выбирать по ID задачи. Редактор виртуальной трансмиссии уже доступен; применение её отношений к MyWhoosh/станку остаётся в FBC-023, FBC-019 и FBC-025.

## Запуск

Для самостоятельного запуска на Mac собери Release-артефакт командой `bash scripts/build-macos.sh` из этой папки. Готовый ZIP: `artifacts/FreeBikeControl-macOS.zip`. Распакуй и перенеси `freeBikeControl.app` в «Программы», затем открой его из Finder. Перед запуском заверши отладочную копию в Xcode. Скрипт проверяет локальную ad-hoc подпись и сохраняет необходимые sandbox-разрешения; это сборка для собственного Mac, без Developer ID и нотарификации для публичного распространения. Архитектура выбирается Xcode для текущего Mac.

1. Открой `freeBikeControl.xcodeproj`, выбери **My Mac** или физический iPhone/iPad и нажми Run. Для iOS проверь свою Team в Signing & Capabilities.
2. Нажми **Start ride**, разреши Bluetooth и локальную сеть.
3. Нажми кнопку на пульте, затем **Connect** рядом с найденным Click. Подключение Bluetooth и получение кнопок показываются отдельно. Убедись, что нажатия появились в журнале.
4. В актуальном MyWhoosh открой экран подключений, нажми значок **OpenBikeControl** и подтверди подключение **FreeBikeControl**.
5. Станок подключай непосредственно к MyWhoosh как power source / controllable trainer. Включи виртуальные передачи в настройках игры и начни поездку.
6. Проверь ручные кнопки передачи в FreeBikeControl, затем физические кнопки Click.

Можно запускать мост и MyWhoosh на одном Mac или на разных устройствах в одной локальной сети. Для сценария на одном iPhone/iPad сначала установи соединения в FreeBikeControl, затем открой MyWhoosh. На iOS объявлен фоновой режим `bluetooth-central` и восстановление Core Bluetooth; работа во время длительной поездки ещё не проверена на устройстве. Не закрывай мост принудительно.

## Настройка виртуальной кассеты

В разделе **Settings → Bike profile** укажи передние звёзды (например, `46, 30`) и полный ряд зубьев кассеты по возрастанию. Можно вводить запятые, пробелы, `;` или `/`. Число задних передач определяется количеством введённых звёзд; можно настроить от 1 до 30 ступеней и от 1 до 3 передних звёзд.

Для кассеты пользователя подтверждён диапазон 11–36, но промежуточные звёзды ещё неизвестны, поэтому поле кассеты изначально пустое. Диапазон `11–36` не заменяет полный ряд. Выбери режим раздельного или последовательного переключения, стартовую передачу и нажми **Save profile**. Раскрой таблицу, чтобы увидеть отношения и шаги. В последовательном режиме комбинации отсортированы от лёгкой к тяжёлой; одинаковые отношения не удаляются.

**Это пока сохранённая конфигурация и предпросмотр.** Профиль ещё не управляет передачами MyWhoosh или нагрузкой KICKR CORE 2. Физические Click продолжают работать через прежние назначения команд. Следующая задача — проверить транспорт применения отношений.

## Click V2

Поддерживается текущий цифровой формат `0x23`, active-low protobuf bitmap. UUID сервисов: `FC82` и старый Zwift custom service. Приложение подписывается на уведомления до handshake и не считает пульт готовым, пока не получит пакет кнопок. Повторные пакеты не вызывают повторные команды. Обрыв связи отпускает кнопки; удержанный ввод не воспроизводится после переподключения.

Левый Click V2 может требовать ежедневной активации через Zwift. Подключи оба пульта в Zwift, убедись, что они работают, затем закрой Zwift, чтобы он освободил Bluetooth, и подключи пульты здесь. Сохранение разблокировки зависит от прошивки; это не гарантируется. Если левый пульт недоступен, подключи правый и включи **Right controller only: + shifts up, B shifts down**.

Автоматическая разблокировка через Zwift и специальный механизм предотвращения сна Click V2 **не реализованы**. Если пульт перестал передавать кнопки, разбуди его кнопкой и проверь журнал. Парные пульты на некоторых прошивках могут представляться одной Bluetooth-связью — проверяй получение нажатий обоих пультов, а не количество устройств в списке.

## Интерфейс

Интерфейс, подсказки, сообщения и запросы разрешений переведены на английский.

На экране **Ride** показаны шаги подключения, схемы обоих Click с подсветкой физических нажатий, состояние MyWhoosh и доступные команды проверки. Нажатие кнопки на схеме открывает её назначение. На Mac и широком iPad карточки расположены в две колонки, на узких экранах — в одну.

**Settings** содержат назначения и сохранённый профиль велосипеда; **Diagnostics** — устройства и журнал. Подсказка следующего шага зависит от текущего соединения. Передачи по умолчанию использует MyWhoosh; редактор собственного профиля необязателен и пока служит предпросмотром.

## Возможности

- Поиск, ручное подключение, автоматическое переподключение выбранных пультов.
- Переключение передач и другие команды, которые MyWhoosh объявляет поддерживаемыми.
- Сохранение назначений кнопок и режима правого пульта.
- TCP-сервер OpenBikeControl с Bonjour, информацией о приложении и проверкой его возможностей.
- Ручные кнопки проверки и ограниченный журнал диагностики.

Это первая версия, не полная замена BikeControl. Она не управляет сопротивлением станка самостоятельно, не записывает тренировки, не подтверждает изменение передачи в игре и не показывает выдуманный номер передачи. Редактор трансмиссии реализован, применение его отношений к нагрузке пока отсутствует. Не реализованы другие контроллеры, старые варианты bitmap и шифрованный протокол. Необходима проверка с реальным Click V2, его прошивкой и MyWhoosh на каждой целевой платформе. iOS Simulator не подходит для тестирования Bluetooth.

## Проверки

Текущие deployment targets исходного Xcode-проекта: iOS 26.2 и macOS 15.7.

Из этой папки:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /tmp/freebike-core-tests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project freeBikeControl.xcodeproj -scheme freeBikeControl -destination 'platform=macOS' -derivedDataPath /tmp/freebike-build CODE_SIGNING_ALLOWED=NO build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project freeBikeControl.xcodeproj -scheme freeBikeControl -destination 'generic/platform=iOS' -derivedDataPath /tmp/freebike-ios-build CODE_SIGNING_ALLOWED=NO build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -parse-as-library freeBikeControl/ControlProtocol.swift freeBikeControl/TrainerBridge.swift Tests/Integration/BridgeSmoke.swift -o /tmp/freebike-bridge-smoke
/tmp/freebike-bridge-smoke
```

21 unit-тест проверяют bitmap кнопок, некорректные protobuf-пакеты, разбиение и объединение TCP-сообщений, capabilities, повторные уведомления и удержанные кнопки при переподключении/смене назначений. Отдельный интеграционный тест запускает production TCP-мост и локальный клиент, проверяет конкретные байты press/release и очистку после отключения. Эти проверки не подтверждают совместимость с физическими пультами или MyWhoosh.

## Источники протоколов

Реализация на Swift написана для этого проекта. BikeControl не включён как библиотека; публичные материалы использованы для сверки протокольных UUID, handshake и актуальных bit positions.

- [OpenBikeControl specification](https://github.com/OpenBikeControl/openbikecontrol-protocol) — MIT.
- [Click V2 transport reference](https://github.com/OpenBikeControl/bikecontrol/tree/main/lib/bluetooth/devices/zwift).
- [Core Bluetooth background processing](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html).

FreeBikeControl не связан со Zwift, MyWhoosh или разработчиками BikeControl.
