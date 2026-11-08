# Windows XP Style Quickshell Bar

**Disclaimer:** This is **not** a pixel-perfect copy of the original Windows XP taskbar. It is a modern, functional bar for Wayland compositors (tested on `labwc`), powered by the **Quickshell** engine, and merely **styled** after the classic Windows XP Luna theme.
All logic is written in QML and uses modern Wayland protocols, PipeWire, and MPRIS.

## Features

- **Start Menu:** Opens a menu with app search, installed programs, and quick access to custom folders. Supports arrow key navigation and Enter to launch.
- **Taskbar:** Displays open windows. Supports **Drag-and-Drop** to reorder buttons. Left-click activates, right-click closes.
- **System Tray:** Displays background app icons (with a fallback to prevent broken icons). Supports context menus and scrolling.
- **Media Player (MPRIS):** Built-in mini-player in Windows Media Player style. Shows album art, track title, supports seeking, play/pause, and per-app volume control.
- **System Monitor:** Displays real-time CPU usage and temperature.
- **Audio Control:** Adjust system volume via mouse wheel and toggle mute with a click.
- **Hotkeys:** Press `Escape` to close all menus.

## Dependencies

To run correctly, you will need:
- [Quickshell](https://github.com/quickshell-mirror/quickshell) (latest version).
- A Wayland compositor (e.g., `labwc`).
- `pipewire` and `wireplumber` (for audio).
- `lm_sensors` (for CPU temperature).
- `thunar` (or another file manager if you change the path command).
- `Tahoma` font (or an equivalent metric-compatible font like `ttf-ms-fonts`) for authentic text rendering.

## Installation

1. Clone the repository or download the `shell.qml` file:
   ```bash
   git clone https://github.com/DogHotDog88/quickshell-xp-bar.git

    Copy the config to the Quickshell folder:
    bash

    mkdir -p ~/.config/quickshell
    cp shell.qml ~/.config/quickshell/

    Add to autostart. Open ~/.config/labwc/autostart and add:
    bash

    quickshell >/dev/null 2>&1 &

Usage and Keybindings

To open the Start Menu with the keyboard, add the following keybind to your ~/.config/labwc/rc.xml:
xml

<keybind key="Super_L" onRelease="yes">
    <action name="Execute">
        <command>qs ipc call startmenu toggle</command>
    </action>
</keybind>

Customization
1. How to set the Avatar in the Start Menu

By default, the code looks for an image at ~/.config/quickshell/avatar.png.
To set your own avatar:

    Take any image (preferably a square one, e.g., 100x100 pixels).

    Convert it to .png format.

    Rename it to avatar.png and place it exactly in the folder ~/.config/quickshell/.

    If you want to use a different filename or format (like .jpg), open shell.qml, find the line with avatar.png inside the Start Menu section, and change the path:
    qml

    Image { anchors.fill: parent; source: "file:///home/your-username/.config/quickshell/your-image.jpg"; fillMode: Image.PreserveAspectCrop }

2. How to change the custom folders in the Start Menu

You can easily change the folder paths in the right column of the Start Menu. Find the customFolders array in the code and edit it:
qml

property var customFolders: [
    { "name": "archi", "path": "/home/archi/" },
    { "name": "games", "path": "/disk2/games/" },
    // add or change your folders here...
]

3. How the System Monitor works

The bar reads /proc/stat to calculate CPU usage and runs the sensors -j command to get the CPU temperature. Make sure lm_sensors is installed and configured (sudo sensors-detect) on your system.
License

This project is distributed under the MIT License. Feel free to fork, modify, and improve it!

---

### 2

---

# Бар для Quickshell в стиле Windows XP

**Внимание:** Это **не** полная и точная копия оригинальной панели задач Windows XP. Это современный, функциональный бар для Wayland-композиторов (тестировался на `labwc`), который использует движок **Quickshell** и лишь **стилизован** под классическую тему Windows XP Luna. 
Вся логика написана на QML и использует современные протоколы Wayland, PipeWire и MPRIS.

## Возможности

- **Кнопка «Пуск»:** Открывает меню с поиском приложений, списком установленных программ и быстрым доступом к вашим папкам. Поддерживает навигацию стрелками и запуск по Enter.
- **Панель задач:** Отображает открытые окна. Поддерживает **Drag-and-Drop** (перетаскивание) для изменения порядка кнопок. Клик активирует окно, правый клик — закрывает его.
- **Системный трей:** Отображает иконки фоновых приложений (с защитой от «сломанных» иконок). Поддерживает контекстные меню и скролл.
- **Медиаплеер (MPRIS):** Встроенный мини-плеер в стиле Windows Media Player. Показывает обложку, название трека, поддерживает перемотку, паузу и регулировку громкости конкретного приложения.
- **Мониторинг системы:** Отображает текущую загрузку CPU и температуру процессора в реальном времени.
- **Громкость:** Регулировка системной громкости (PipeWire) прокруткой колесика мыши и отключение звука по клику.
- **Горячие клавиши:** Закрытие всех меню по клавише `Escape`.

## Зависимости

Для корректной работы вам понадобятся:
- [Quickshell](https://github.com/quickshell-mirror/quickshell) (последняя версия).
- Композитор Wayland (например, `labwc`).
- `pipewire` и `wireplumber` (для работы звука).
- `lm_sensors` (для отображения температуры процессора).
- `thunar` (или другой файловый менеджер, если хотите изменить команду открытия папок).
- Шрифт `Tahoma` (или его метрический аналог, например, `ttf-ms-fonts`), чтобы текст выглядел аутентично.

## Установка

1. Клонируйте репозиторий или просто скачайте файл `shell.qml`:
   ```bash
   git clone https://github.com/DogHotDog88/quickshell-xp-bar.git

    Скопируйте конфигурацию в папку Quickshell:
    bash

    mkdir -p ~/.config/quickshell
    cp shell.qml ~/.config/quickshell/

    Добавьте автозапуск. Откройте файл ~/.config/labwc/autostart и добавьте туда строку:
    bash

    quickshell >/dev/null 2>&1 &

Использование и горячие клавиши

Чтобы открыть меню «Пуск» с клавиатуры, добавьте следующую привязку в ваш ~/.config/labwc/rc.xml:
xml

<keybind key="Super_L" onRelease="yes">
    <action name="Execute">
        <command>qs ipc call startmenu toggle</command>
    </action>
</keybind>

Настройка
1. Как поставить аватарку в меню «Пуск»

По умолчанию код ищет картинку по пути ~/.config/quickshell/avatar.png.
Чтобы поставить свою аватарку:

    Возьмите любую картинку (желательно квадратную, например, 100x100 пикселей).

    Конвертируйте её в формат .png.

    Переименуйте её в avatar.png и положите ровно в папку ~/.config/quickshell/.

    Если вы хотите использовать другое имя файла или формат (например, .jpg), откройте shell.qml, найдите строку с avatar.png в блоке меню «Пуск» и измените путь:
    qml

    Image { anchors.fill: parent; source: "file:///home/ваш-юзер/.config/quickshell/ваша-картинка.jpg"; fillMode: Image.PreserveAspectCrop }

2. Как изменить папки в меню «Пуск»

Вы можете легко изменить пути к папкам в правой колонке меню «Пуск». Найдите в коде массив customFolders и отредактируйте его под себя:

property var customFolders: [
    { "name": "archi", "path": "/home/archi/" },
    { "name": "games", "path": "/disk2/games/" },
    // добавьте или измените свои папки здесь...
]

3. Как работает мониторинг системы

Бар читает файл /proc/stat для расчета загрузки процессора и выполняет команду sensors -j для получения температуры. Убедитесь, что пакет lm_sensors установлен и настроен (sudo sensors-detect) в вашей системе.
Лицензия

Этот проект распространяется под лицензией MIT. Делайте с ним что хотите, форкайте и улучшайте!
