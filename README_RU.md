# Ежечасный сигнал (dkoropenko.hourly-notify)

Плагин оболочки Omarchy: подаёт звуковой сигнал каждый час в ровный час (:00)
и даёт визуальный интерфейс для настройки.

- **id:** `dkoropenko.hourly-notify`
- **виды:** `service`, `bar-widget`
- **расположение:** `~/.config/omarchy/plugins/dkoropenko.hourly-notify/`
- **версия:** 1.0.0

## Файлы

| Файл | Назначение |
|------|------------|
| `manifest.json` | Манифест плагина: id, виды, точки входа, схема настроек |
| `Service.qml` | Синглтон-сервис: таймер на ровный час и воспроизведение звука |
| `BarWidget.qml` | Иконка-колокольчик в баре, хранение настроек в `shell.json` |
| `Panel.qml` | Панель настроек (открывается по клику на иконку) |

## Как работает

Часовая логика вынесена в `service`-синглтон, поэтому сигнал срабатывает
ровно один раз, даже если бар отрисован на нескольких мониторах. Таймер
выставляется на ближайший ровный час (а не «через час после запуска») и после
каждого срабатывания пересчитывается заново по настенным часам. Если сигнал
пропущен из-за сна компьютера, ложное срабатывание в минуту пробуждения
подавляется, а таймер заново выравнивается на ближайший :00.

Звук воспроизводится командой:

```
pw-play --volume <уровень> <файл>
```

`--volume` задаёт громкость отдельного аудиопотока сигнала — это независимый
от системного ползунка параметр. Переменная окружения `LC_ALL=C` выставлена
специально, чтобы десятичная точка в `--volume` не зависела от локали
(на этой машине `LC_NUMERIC` использует запятую).

Настройки хранятся в строке бар-виджета в `~/.config/omarchy/shell.json`:

```json
{ "id": "dkoropenko.hourly-notify", "enabled": true, "sound": "/usr/share/sounds/freedesktop/stereo/complete.oga", "volume": 0.6 }
```

## Интерфейс

Открывается кликом по иконке колокольчика в правой части бара.
Иконка меняется на перечёркнутый колокольчик, когда оповещение выключено.

- Переключатель вкл/выкл.
- Выбор звука — список всех файлов из `/usr/share/sounds`,
  `~/.local/share/sounds`, `~/.config/omarchy/sounds`
  (расширения `.oga`, `.ogg`, `.wav`, `.flac`, `.mp3`).
- Ползунок громкости сигнала (0–100%), не связанный с системной громкостью.
- Кнопка «Проверить сигнал».

Клавиатура: `j`/`k` или стрелки — перемещение по элементам, `h`/`l` — громкость,
`Enter`/`Space` — действие, `t` — тест, `Esc` — закрыть. Пока открыт список
звуков, клавиши переходят к нему.

## Управление из скриптов и кейбиндингов

Target для IPC — `dkoropenko.hourly-notify`:

```bash
omarchy-shell dkoropenko.hourly-notify togglenotify          # переключить вкл/выкл
omarchy-shell dkoropenko.hourly-notify setEnabled true      # включить (true|1)
omarchy-shell dkoropenko.hourly-notify setEnabled false     # выключить
omarchy-shell dkoropenko.hourly-notify setVolume 60         # громкость в процентах 0-100
omarchy-shell dkoropenko.hourly-notify setSound /path/to.oga
omarchy-shell dkoropenko.hourly-notify notify                # проиграть один раз
omarchy-shell dkoropenko.hourly-notify open                 # открыть панель
omarchy-shell dkoropenko.hourly-notify close
omarchy-shell dkoropenko.hourly-notify toggle
```

Установить на клавиши в `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + C", "Ежечасный сигнал", "omarchy-shell dkoropenko.hourly-notify togglenotify")
```

## Установка и включение

```bash
omarchy-shell shell rescanPlugins
omarchy plugin enable dkoropenko.hourly-notify --section right
```

Отключить: `omarchy plugin disable dkoropenko.hourly-notify`.
Правка файлов плагина подхватывается автоматически; при необходимости —
`omarchy-shell shell rescanPlugins`. Смена окружения IPC-обработчиков
требует `omarchy restart shell`.

## Зависимости

- `pw-play` (PipeWire) — воспроизведение звука;
- `find` (GNU findutils) — поиск доступных звуков.

## Нюанс про громкость

Ползунок задаёт собственную громкость потока сигнала, отдельно от системного
слайдера. Но физически звук идёт через системный аудио-выход, поэтому общая
(мастер) громкость и mute на него всё равно влияют. Полностью «поверх»
системы сигнал не звучал бы — для такого поведения нужен отдельный
аудиовыход (отдельный sink).
