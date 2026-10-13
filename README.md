![MeshTerm OpenWrt](https://github.com/IoTThinks/EasySkyMesh/blob/main/README.md)

# MeshTerm for OpenWrt GTW360

[![Version](https://img.shields.io/badge/version-0.11.0-blue)](https://github.com/jpmartineau/MeshTerm)
[![OpenWrt](https://img.shields.io/badge/OpenWrt-23.05.4-green)](https://openwrt.org/)
[![License](https://img.shields.io/badge/license-Apache--2.0-orange)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-ARMv7--musl-red)](https://openwrt.org/)

Full-featured TUI MeshTerm client for Meshtastic network, adapted for OpenWrt / OpenLumi GTW360 and other ARM Cortex-A7 boards.

![MeshTerm Screenshot](https://raw.githubusercontent.com/jpmartineau/MeshTerm/main/docs/assets/screenshot.png)

## Features

- ✅ Full MeshTerm TUI interface in terminal
- ✅ Web-based terminal via LuCI integration
- ✅ Support for USB and TCP companions
- ✅ Optimized for 32-bit ARM (ARMv7) with musl libc
- ✅ Automatic dependency installation
- ✅ Idempotent installation script
- ✅ One-line installation

## Hardware Compatibility

**Tested on:**
- 📦 Geniatech GTW360 (OpenLumi)
- 📦 OpenWrt 23.05.4
- 📦 ARM Cortex-A7 NEON VFPv4
- 📦 512MB RAM

**Compatible with:**
- Other imx/cortexa7 boards
- OpenWrt 23.05.x
- 32-bit ARM (armv7l, armv6l)
- musl libc

**NOT compatible with:**
- ❌ 64-bit ARM (aarch64) - use official [linux-arm64 build](https://github.com/jpmartineau/MeshTerm/releases)
- ❌ glibc systems - use official PyInstaller builds

## Quick Installation

### One-line Installation (Recommended)

```bash
ssh root@your-router
curl -fsSL https://raw.githubusercontent.com/Securond/MeshTerm-OpenWrt/main/install.sh | sh
```

Replace `Securond` with your GitHub username.

That's it! The script will:
- Install all dependencies
- Clone MeshTerm from GitHub
- Set up Python virtual environment
- Install MeshTerm with web terminal
- Configure LuCI integration

### Manual Installation

```bash
# SSH to your router
ssh root@your-router

# Clone this repository
opkg update
opkg install git-http ca-bundle
git clone --depth 1 https://github.com/Securond/MeshTerm-OpenWrt.git /opt/meshterm-install

# Run the setup script
cd /opt/meshterm-install
sh openwrt-setup.sh
```

## Installation Details

The setup script performs the following steps:

1. **Preflight** - Checks CPU architecture and libc type
2. **Swap** - Creates swap file on eMMC for native builds (256MB)
3. **System packages** - Installs Python 3.11, pip, venv, compiler, USB drivers
4. **Checkout** - Clones MeshTerm from GitHub
5. **Venv + pip** - Creates Python virtual environment and installs MeshTerm
6. **Wrapper** - Creates `/usr/bin/meshterm` with proper UTF-8 and TERM settings
7. **LuCI integration** - Installs web terminal via ttyd (optional)

**Note:** Installation may take 5-10 minutes because some Python packages (dbus-fast, pycryptodome) need to be compiled from source on ARMv7 musl. The script uses `--prefer-binary` to use pre-built wheels when available for faster installation.

## Configuration Options

You can customize the installation with environment variables:

```bash
# Install without LuCI web interface
sh openwrt-setup.sh INSTALL_LUCI=0

# Skip swap file creation (if you have enough RAM)
sh openwrt-setup.sh SKIP_SWAP=1

# Install with Bluetooth support
sh openwrt-setup.sh WITH_BLE=1

# Custom installation directory
sh openwrt-setup.sh PREFIX=/custom/path

# Custom swap file size (in MB)
sh openwrt-setup.sh SWAP_MB=512
```

## Usage

### SSH Terminal

```bash
# Interactive TUI (requires PTY)
ssh -t root@your-router meshterm

# Simulator mode
ssh root@your-router
meshterm --mock

# USB companion
meshterm --port /dev/ttyACM0
# or /dev/ttyUSB0 (check: ls /dev/ttyUSB* /dev/ttyACM*)

# TCP companion
meshterm --tcp HOST:PORT
```

### Web Terminal (LuCI)

1. Open LuCI in your browser: `http://your-router`
2. Login as root
3. Navigate to **Services → MeshTerm**
4. Web terminal opens with MeshTerm running

Or access directly: `http://your-router:7681`

![LuCI MeshTerm](https://raw.githubusercontent.com/jpmartineau/MeshTerm/main/docs/assets/luci.png)

## File Locations

- **Binary wrapper:** `/usr/bin/meshterm`
- **Installation directory:** `/opt/meshterm`
- **Python venv:** `/opt/meshterm/.venv`
- **Source code:** `/opt/meshterm/src`
- **Data directory:** `/root/.meshterm`
- **LuCI controller:** `/usr/lib/lua/luci/controller/admin/meshterm.lua`
- **LuCI template:** `/usr/lib/lua/luci/view/admin_services/meshterm.htm`
- **Web terminal init:** `/etc/init.d/meshterm-web`

## Service Management

### MeshTerm Web Terminal

```bash
# Start
/etc/init.d/meshterm-web start

# Stop
/etc/init.d/meshterm-web stop

# Restart
/etc/init.d/meshterm-web restart

# Enable autostart
/etc/init.d/meshterm-web enable

# Disable autostart
/etc/init.d/meshterm-web disable
```

### LuCI

```bash
# Restart LuCI web interface
/etc/init.d/uhttpd restart
```

## Troubleshooting

### Installation fails due to insufficient RAM

If you get OOM errors during compilation:

```bash
# Increase swap size
sh openwrt-setup.sh SWAP_MB=512

# Or stop heavy services first
/etc/init.d/homeassistant stop  # if running
sh openwrt-setup.sh
```

### Web terminal not accessible

```bash
# Check if ttyd is running
ps | grep ttyd

# Restart the service
/etc/init.d/meshterm-web restart

# Check LuCI logs
logread | grep uhttpd
```

### MeshTerm not found

```bash
# Check wrapper script
cat /usr/bin/meshterm

# Check venv
ls -la /opt/meshterm/.venv/bin/meshterm

# Reinstall wrapper
sh /opt/meshterm/src/scripts/openwrt-gtw360/openwrt-setup.sh
```

### USB companion not detected

```bash
# Check USB devices
ls /dev/ttyUSB* /dev/ttyACM*

# Check if kernel modules are loaded
lsmod | grep usb_serial

# Load USB modules manually
insmod usbserial
insmod cp210x  # or ftdi_sio, pl2303, etc.
```

## Uninstallation

```bash
# Stop services
/etc/init.d/meshterm-web disable
/etc/init.d/meshterm-web stop

# Remove files
rm -rf /opt/meshterm
rm /usr/bin/meshterm
rm /etc/init.d/meshterm-web
rm /usr/lib/lua/luci/controller/admin/meshterm.lua
rm /usr/lib/lua/luci/view/admin_services/meshterm.htm
rm /usr/share/acl.d/meshterm_acl.json

# Remove installed packages (optional)
opkg remove ttyd luci-compat python3-pip python3-venv python3-dev python3-cffi gcc make

# Restart LuCI
/etc/init.d/uhttpd restart
```

## Requirements

The following packages will be automatically installed:

- Python 3.11+ with pip and venv
- GCC, make, and build tools
- USB serial drivers (ACM, CP210x, FTDI, PL2303)
- ttyd (web terminal)
- LuCI and ucode runtime
- BlueZ (optional, for BLE support)

## Development

To modify the installation script:

```bash
# Clone this repository
git clone https://github.com/Securond/MeshTerm-OpenWrt.git
cd MeshTerm-OpenWrt

# Edit the script
vi openwrt-setup.sh

# Test on device
scp openwrt-setup.sh root@your-router:/tmp/
ssh root@your-router
sh /tmp/openwrt-setup.sh
```

## License

Apache License 2.0 - see [LICENSE](LICENSE) for details.

## Credits

- **Original MeshTerm:** [jpmartineau/MeshTerm](https://github.com/jpmartineau/MeshTerm)
- **OpenWrt:** [openwrt/openwrt](https://github.com/openwrt/openwrt)
- **ttyd:** [tsl0922/ttyd](https://github.com/tsl0922/ttyd)
- **Meshtastic:** [meshtastic](https://meshtastic.org)

## Support

For issues and questions:
- 🐛 Open an issue on GitHub
- 📖 Check the main [MeshTerm documentation](https://github.com/jpmartineau/MeshTerm)
- 🌐 Visit [Meshtastic documentation](https://meshtastic.org/docs)
- 💬 Join [Meshtastic Discord](https://discord.gg/meshtastic)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

# MeshTerm для OpenWrt GTW360

Полнофункциональный TUI клиент для сети Meshtastic, адаптированный для OpenWrt / OpenLumi GTW360 и других плат на базе ARM Cortex-A7.

## Возможности

- ✅ Полный интерфейс MeshTerm TUI в терминале
- ✅ Веб-терминал через интеграцию с LuCI
- ✅ Поддержка USB и TCP компаньонов
- ✅ Оптимизирован для 32-бит ARM (ARMv7) с musl libc
- ✅ Автоматическая установка зависимостей
- ✅ Идемпотентный скрипт установки
- ✅ Установка в одну строку

## Совместимость оборудования

**Протестировано на:**
- 📦 Geniatech GTW360 (OpenLumi)
- 📦 OpenWrt 23.05.4
- 📦 ARM Cortex-A7 NEON VFPv4
- 📦 512MB RAM

**Совместимо с:**
- Другими платами imx/cortexa7
- OpenWrt 23.05.x
- 32-бит ARM (armv7l, armv6l)
- musl libc

**НЕ совместимо с:**
- ❌ 64-бит ARM (aarch64) - используйте официальную сборку [linux-arm64](https://github.com/jpmartineau/MeshTerm/releases)
- ❌ Системами с glibc - используйте официальные сборки PyInstaller

## Быстрая установка

### Установка в одну строку (Рекомендуется)

```bash
ssh root@your-router
curl -fsSL https://raw.githubusercontent.com/Securond/MeshTerm-OpenWrt/main/install.sh | sh
```

Всё! Скрипт автоматически:
- Установит все зависимости
- Склонирует MeshTerm из GitHub
- Настроит виртуальное окружение Python
- Установит MeshTerm с веб-терминалом
- Настроит интеграцию с LuCI

### Ручная установка

```bash
# Подключитесь к роутеру по SSH
ssh root@your-router

# Клонируйте этот репозиторий
opkg update
opkg install git-http ca-bundle
git clone --depth 1 https://github.com/Securond/MeshTerm-OpenWrt.git /opt/meshterm-install

# Запустите скрипт установки
cd /opt/meshterm-install
sh openwrt-setup.sh
```

## Детали установки

Скрипт установки выполняет следующие шаги:

1. **Preflight** - Проверка архитектуры CPU и типа libc
2. **Swap** - Создание swap-файла на eMMC для нативной сборки (256MB)
3. **Системные пакеты** - Установка Python 3.11, pip, venv, компилятора, драйверов USB
4. **Checkout** - Клонирование MeshTerm из GitHub
5. **Venv + pip** - Создание виртуального окружения Python и установка MeshTerm
6. **Wrapper** - Создание `/usr/bin/meshterm` с правильными настройками UTF-8 и TERM
7. **Интеграция LuCI** - Установка веб-терминала через ttyd (опционально)

**Примечание:** Установка может занять 5-10 минут, так как некоторые Python пакеты (dbus-fast, pycryptodome) нужно скомпилировать из исходников на ARMv7 musl. Скрипт использует `--prefer-binary` для использования готовых wheels когда они доступны для более быстрой установки.

## Параметры конфигурации

Вы можете настроить установку с помощью переменных окружения:

```bash
# Установка без веб-интерфейса LuCI
sh openwrt-setup.sh INSTALL_LUCI=0

# Пропустить создание swap-файла (если достаточно RAM)
sh openwrt-setup.sh SKIP_SWAP=1

# Установка с поддержкой Bluetooth
sh openwrt-setup.sh WITH_BLE=1

# Кастомный каталог установки
sh openwrt-setup.sh PREFIX=/custom/path

# Размер swap-файла (в MB)
sh openwrt-setup.sh SWAP_MB=512
```

## Использование

### SSH терминал

```bash
# Интерактивный TUI (требует PTY)
ssh -t root@your-router meshterm

# Режим симулятора
ssh root@your-router
meshterm --mock

# USB компаньон
meshterm --port /dev/ttyACM0
# или /dev/ttyUSB0 (проверьте: ls /dev/ttyUSB* /dev/ttyACM*)

# TCP компаньон
meshterm --tcp HOST:PORT
```

### Веб-терминал (LuCI)

1. Откройте LuCI в браузере: `http://your-router`
2. Авторизуйтесь как root
3. Перейдите в **Services → MeshTerm**
4. Откроется веб-терминал с запущенным MeshTerm

Или откройте напрямую: `http://your-router:7681`

## Расположение файлов

- **Обёртка:** `/usr/bin/meshterm`
- **Каталог установки:** `/opt/meshterm`
- **Python venv:** `/opt/meshterm/.venv`
- **Исходный код:** `/opt/meshterm/src`
- **Каталог данных:** `/root/.meshterm`
- **Контроллер LuCI:** `/usr/lib/lua/luci/controller/admin/meshterm.lua`
- **Шаблон LuCI:** `/usr/lib/lua/luci/view/admin_services/meshterm.htm`
- **Init веб-терминала:** `/etc/init.d/meshterm-web`

## Управление сервисами

### Веб-терминал MeshTerm

```bash
# Запуск
/etc/init.d/meshterm-web start

# Остановка
/etc/init.d/meshterm-web stop

# Перезапуск
/etc/init.d/meshterm-web restart

# Автозапуск
/etc/init.d/meshterm-web enable

# Отключение автозапуска
/etc/init.d/meshterm-web disable
```

### LuCI

```bash
# Перезапуск веб-интерфейса LuCI
/etc/init.d/uhttpd restart
```

## Устранение проблем

### Установка не удалась из-за нехватки RAM

Если возникают ошибки OOM при компиляции:

```bash
# Увеличьте размер swap
sh openwrt-setup.sh SWAP_MB=512

# Или остановите тяжёлые сервисы перед установкой
/etc/init.d/homeassistant stop  # если запущен
sh openwrt-setup.sh
```

### Веб-терминал недоступен

```bash
# Проверьте, запущен ли ttyd
ps | grep ttyd

# Перезапустите сервис
/etc/init.d/meshterm-web restart

# Проверьте логи LuCI
logread | grep uhttpd
```

### MeshTerm не найден

```bash
# Проверьте скрипт-обёртку
cat /usr/bin/meshterm

# Проверьте venv
ls -la /opt/meshterm/.venv/bin/meshterm

# Переустановите обёртку
sh /opt/meshterm/src/scripts/openwrt-gtw360/openwrt-setup.sh
```

### USB компаньон не обнаруживается

```bash
# Проверьте USB устройства
ls /dev/ttyUSB* /dev/ttyACM*

# Проверьте загружены ли модули ядра
lsmod | grep usb_serial

# Загрузите USB модули вручную
insmod usbserial
insmod cp210x  # или ftdi_sio, pl2303, и т.д.
```

## Удаление

```bash
# Остановите сервисы
/etc/init.d/meshterm-web disable
/etc/init.d/meshterm-web stop

# Удалите файлы
rm -rf /opt/meshterm
rm /usr/bin/meshterm
rm /etc/init.d/meshterm-web
rm /usr/lib/lua/luci/controller/admin/meshterm.lua
rm /usr/lib/lua/luci/view/admin_services/meshterm.htm
rm /usr/share/acl.d/meshterm_acl.json

# Удалите установленные пакеты (опционально)
opkg remove ttyd luci-compat python3-pip python3-venv python3-dev python3-cffi gcc make

# Перезапустите LuCI
/etc/init.d/uhttpd restart
```

## Требования

Следующие пакеты будут установлены автоматически:

- Python 3.11+ с pip и venv
- GCC, make и инструменты сборки
- Драйверы USB serial (ACM, CP210x, FTDI, PL2303)
- ttyd (веб-терминал)
- LuCI и ucode runtime
- BlueZ (опционально, для BLE)

## Разработка

Для изменения скрипта установки:

```bash
# Клонируйте этот репозиторий
git clone https://github.com/Securond/MeshTerm-OpenWrt.git
cd MeshTerm-OpenWrt

# Отредактируйте скрипт
vi openwrt-setup.sh

# Протестируйте на устройстве
scp openwrt-setup.sh root@your-router:/tmp/
ssh root@your-router
sh /tmp/openwrt-setup.sh
```

## Лицензия

Apache License 2.0 - см. [LICENSE](LICENSE) для деталей.

## Благодарности

- **Оригинальный MeshTerm:** [jpmartineau/MeshTerm](https://github.com/jpmartineau/MeshTerm)
- **OpenWrt:** [openwrt/openwrt](https://github.com/openwrt/openwrt)
- **ttyd:** [tsl0922/ttyd](https://github.com/tsl0922/ttyd)
- **Meshtastic:** [meshtastic](https://meshtastic.org)

## Поддержка

Для проблем и вопросов:
- 🐛 Откройте issue на GitHub
- 📖 Проверьте основную [документацию MeshTerm](https://github.com/jpmartineau/MeshTerm)
- 🌐 Посетите [документацию Meshtastic](https://meshtastic.org/docs)
- 💬 Присоединитесь к [Meshtastic Discord](https://discord.gg/meshtastic)

## Вклад

Вклады приветствуются! Не стесняйтесь отправлять Pull Request.

1. Форкните репозиторий
2. Создайте ветку функции (`git checkout -b feature/AmazingFeature`)
3. Закоммитьте изменения (`git commit -m 'Add some AmazingFeature'`)
4. Отправьте в ветку (`git push origin feature/AmazingFeature`)
5. Откройте Pull Request
