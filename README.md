# Distortionz Money Laundering

> Premium dirty money cleaning system for Qbox/FiveM — laundering NUI dashboard, fee preview, money-counting animation, police alerts, cooldowns.

![FiveM](https://img.shields.io/badge/FiveM-cerulean-yellow?style=flat-square&labelColor=181b20)
![Qbox](https://img.shields.io/badge/Qbox-required-red?style=flat-square&labelColor=dfb317)
![License](https://img.shields.io/badge/License-MIT-brightgreen?style=flat-square)
![Version](https://img.shields.io/github/v/release/Distortionzz/Distortionz_Moneylaundering?style=flat-square&color=d4aa62&label=version)

---

## Overview

Underground laundromat for converting marked/dirty bills to clean cash. Players visit a contact ped, enter the amount they want to launder, see a live fee preview + clean payout, and watch a money-counting animation while the contact processes the deposit.

## Features

- Premium laundering NUI with dirty money balance + fee preview
- Live clean cash payout calculation
- Money-counting animation during processing
- Ped clipboard animation
- Configurable fee tiers and rates
- Police alert chance
- Per-player cooldowns
- Protected ped flagging

## Dependencies

| Resource | Required | Purpose |
|---|---|---|
| `qbx_core` | yes | Player data, money |
| `ox_lib` | yes | Callbacks, notify fallback |
| `ox_target` | yes | Contact ped interaction |
| `ox_inventory` | yes | Dirty money item handling |
| `distortionz_notify` | optional | Branded notifications |

## Installation

```cfg
ensure distortionz_moneylaundering
```

## Configuration

See [`config.lua`](config.lua) for ped location, fee rates, max launder amounts, cooldowns, and police alert thresholds.

## Credits

- **Author:** Distortionz
- **Framework:** [Qbox Project](https://github.com/Qbox-project)

## License

MIT — see [LICENSE](LICENSE).
