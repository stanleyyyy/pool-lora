# pool-lora

A battery-powered pool thermometer that lasts years instead of weeks. A tiny
LoRa transmitter floats in the pool, wakes every ten minutes, sends one packet
and goes back to sleep; a USB-powered receiver indoors forwards the reading to
Home Assistant. Both sides are plain [ESPHome](https://esphome.io) configs.

```
  float (battery)                                indoors (USB)
 ┌──────────────────────────┐     LoRa       ┌──────────────────────────┐
 │ XIAO nRF52840 + SX1262   │  868.1 MHz     │ XIAO ESP32-S3 + SX1262   │   Wi-Fi    Home
 │ NTC thermistor, LiPo     │ ─────────────► │ ESPHome API              │ ─────────► Assistant
 │ sleeps between readings  │   6 bytes      │ always listening         │
 └──────────────────────────┘                └──────────────────────────┘
```

Wi-Fi on the transmitter was the reason the previous ESP32 pool sensor died in
a few weeks: every wake-up re-associated with the access point. Here the
transmitter has no Wi-Fi at all. It keeps the nRF52840 asleep, powers the
thermistor divider only while measuring, sends a single 6-byte LoRa packet and
puts the radio back to sleep.

## Hardware

| | Transmitter (`pool-tx.yaml`) | Receiver (`pool-rx.yaml`) |
| --- | --- | --- |
| Board | Seeed XIAO nRF52840 & Wio-SX1262 kit | Seeed XIAO ESP32-S3 & Wio-SX1262 kit |
| Power | single-cell LiPo on the XIAO `BAT+`/`BAT-` pads, charged over USB-C | USB |
| Antenna | the kit's adhesive FPC antenna, hidden inside the float | kit antenna |
| Sensor | 50 kΩ NTC thermistor + 47 kΩ resistor | — |

### Transmitter wiring

The Wio-SX1262 in the nRF52840 kit uses D1–D5 and D8–D10, which leaves D0, D6
and D7 free. The thermistor divider is powered from a GPIO so it draws nothing
while the board sleeps:

```
D6 (P1.11) ── 47 kΩ ──┬── D0 (P0.02 / AIN0)
                      │
                     NTC 50 kΩ
                      │
                     GND
```

An optional 100 nF capacitor from D0 to GND helps the SAADC with the ~24 kΩ
source impedance of the divider. The battery is read through the XIAO's own
1 MΩ / 510 kΩ divider on P0.31.

| XIAO pin | nRF52840 | Use |
| --- | --- | --- |
| D0 | P0.02 / AIN0 | NTC divider (ADC) |
| D1 | P0.03 | SX1262 DIO1 |
| D2 | P0.28 | SX1262 RST |
| D3 | P0.29 | SX1262 BUSY |
| D4 | P0.04 | SX1262 NSS |
| D5 | P0.05 | Wio RF switch |
| D6 | P1.11 | NTC divider power |
| D8–D10 | P1.13–P1.15 | SPI SCK / MISO / MOSI |
| — | P0.06 | blue LED, flashes on every transmission |

### Receiver pins

The ESP32-S3 kit comes in two mechanical versions. `pool-rx.yaml` defaults to
the board-to-board connector version (NSS GPIO41, RST GPIO42, DIO1 GPIO39, BUSY
GPIO40, RF switch GPIO38); the pin-header mapping is right below it in the
substitutions, commented out.

## Radio link

| | |
| --- | --- |
| Frequency | 868.1 MHz |
| Modulation | LoRa, SF9, 125 kHz, CR 4/5, preamble 8, CRC on |
| Sync word | `0x14 0x24` (private network) |
| TX power | 14 dBm |

Packet, 7 bytes, little-endian:

| byte | content |
| --- | --- |
| 0 | `0x50` (`'P'`) |
| 1 | sensor id (`0x01`) |
| 2–3 | temperature, `int16`, 0.01 °C |
| 4–5 | battery voltage, `uint16`, mV |
| 6 | sequence number, +1 per packet |

The receiver ignores anything that doesn't match (a 6-byte packet from older
transmitter firmware is still accepted) and publishes to Home Assistant:

| entity | |
| --- | --- |
| Teplota v bazéne | pool temperature |
| Batéria senzora | transmitter battery voltage |
| LoRa RSSI, LoRa SNR | of the last packet |
| LoRa link margin | SNR above the SF9 demodulation limit (about −12.5 dB); how much worse the link can get before packets drop |
| LoRa packets received / lost, LoRa packet loss | from gaps in the sequence number since the receiver started |
| LoRa last packet | seconds since the last packet |
| Senzor online | off when nothing arrived for `offline_after_s` (25 min) |

The receiver also serves the ESPHome web page on port 80. Its firmware upload
page is turned off; updates go through OTA, which is encrypted with the API
key. `pool-rx.yaml` still carries a one-time `allow_plaintext_upload` plus the
old OTA password so a receiver flashed with the password-only firmware can
take the first encrypted image; remove both once that install is done.

## Getting started

Needs Python 3.11 or newer. Everything else lives in a local `.venv`, created
by the setup script from `requirements.txt`, which pins the tested ESPHome
(2026.11.0, the first release with nRF52 hardware SPI) and ESPHome Device
Builder versions.

```bat
git clone https://github.com/stanleyyyy/pool-lora
cd pool-lora
setup.bat
```

On Linux or macOS run `./setup.sh`. Setup creates `.venv`, installs the
pinned packages and copies `secrets.example.yaml` to `secrets.yaml`; edit that
with your Wi-Fi and Home Assistant API values. Running it again only updates
what is missing.

| script | what it does |
| --- | --- |
| `setup.bat` / `setup.sh` | creates `.venv`, installs `requirements.txt`, creates `secrets.yaml` |
| `dashboard.bat` | starts ESPHome Device Builder on http://localhost:6052 for this folder |
| `flash-tx.bat` | builds `pool-tx.yaml` and copies the `.uf2` onto the XIAO nRF52840 bootloader drive |

`dashboard.bat` and `flash-tx.bat` run the setup themselves when `.venv` is
missing, so a fresh clone works by double-clicking either of them.

The receiver flashes like any ESP32, `.venv\Scripts\esphome run pool-rx.yaml`,
and takes updates over the air from then on. If the factory Meshtastic firmware blocks the first flash, hold **B**
while plugging in USB to enter the ESP32-S3 download mode.

### Flashing the nRF52840

The serial DFU upload is unreliable on this board: the transmitter is asleep
most of the time and the factory Adafruit bootloader (0.6.1) drops off the bus
mid-transfer on some Windows machines. The UF2 drive always works:

1. run `flash-tx.bat`,
2. double-press the reset button when asked,
3. the script finds the `XIAO-SENSE` drive by its `INFO_UF2.TXT` and copies the
   firmware; the board reboots into it.

Use a data cable. A charge-only or flaky cable shows up as a bootloader whose
drive reports "No Media" and whose COM port "is not functioning".

For development set `sleep_time: 30s` in `pool-tx.yaml` instead of waiting ten
minutes per packet.

## Power

Each cycle wakes the nRF52840 for well under a second: the thermistor and
battery reading, one SF9 transmission (~200 ms airtime at 14 dBm) and a short
LED flash. Everything else is spent in sleep with the SX1262 in warm sleep and
the divider unpowered. Set `logger: level: NONE` for the final build and
measure the sleep current before sealing the float.

## License

MIT
