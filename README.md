# ✦ Cosmic Dial

An interactive astronomical dashboard and celestial ephemeris widget for the [Omarchy](https://github.com/omarchy/omarchy) desktop environment, built with **Quickshell** and **QtQuick / QML**.

---

## 🌟 Overview

**Cosmic Dial** transforms your desktop panel into a real-time astronomical observatory. It combines precise celestial mechanics, dynamic 2D vector graphics, and a reactive time scrubber to visualize lunar phases, planetary positions, solar declination, seasonal shifts, and day/night transitions across the Earth.

---

## ✨ Features

- 🌓 **Dynamic Lunar Phase Morphing**: Real-time, continuous trigonometric rendering of the Moon's illuminated disc across all 8 phases (New Moon, Waxing Crescent, First Quarter, Waxing Gibbous, Full Moon, Waning Gibbous, Last Quarter, Waning Crescent).
- 🌍 **Earth-Moon Orbital Orrery**: Geocentric orbital model with real-time Earth rotation, 3D continental topography, and physical sunlight orientation.
- ☀️ **Earth-Sun Orbit & Seasons**: Keplerian elliptical orbit of Earth around the Sun featuring orbital eccentricity, equinoxes, solstices, perihelion, and aphelion.
- 📐 **Earth Axial Tilt & Seasonal Simulator**: Dedicated visual widget showing Earth's $23.44^\circ$ axial tilt relative to incoming solar rays, dynamically illustrating why and how solar declination produces opposite seasons in the Northern (`N`) and Southern (`S`) Hemispheres.
- 🗺️ **Natural Earth Day / Night Projection**: D3 Natural Earth cartographic projection rendering live day/night solar terminators according to the current solar declination.
- 🪐 **Keplerian Solar System Orrery**: Planetary ephemeris simulator calculating real orbital positions for all 8 planets (Mercury through Neptune) referenced to the J2000 epoch.
- ⏱️ **Interactive Time Scrubber**: Continuous $\pm 30$-day simulation slider with quick-step buttons (`±1h`, `±5h`, `±12h`, `±1d`, `±1w`) and one-click `⟲ LIVE` instant reset.
- 📊 **Triple-Section Ephemeris Metrics**:
  - **Lunar Cycle**: Age in days, countdown to Full Moon, countdown to New Moon, Brown Lunation Number.
  - **Dynamics & Orbit**: Illumination %, geocentric distance (km), solar declination (°), upcoming seasonal milestone.
  - **Axial Tilt & Seasons**: Graphical Earth tilt diagram ($23.44^\circ$), North/South seasonal status, and active solar declination.
- 🎨 **Native Omarchy Theme Integration**: Automatically inherits active system palette colors (`Color.accent`, `Color.urgent`, `Color.foreground`).

---

## 🌎 Understanding Earth's Axial Tilt & Seasons

Earth's axis of rotation is tilted by approximately **$23.44^\circ$** relative to the perpendicular of its orbital plane (the ecliptic):
- **Northern Summer / Southern Winter** (June Solstice): The North Pole tilts toward the Sun ($\delta \approx +23.44^\circ$), receiving concentrated solar radiation and 24-hour polar daylight (midnight sun), while the South Pole is plunged into polar night.
- **Northern Winter / Southern Summer** (December Solstice): The South Pole tilts toward the Sun ($\delta \approx -23.44^\circ$), giving the Southern Hemisphere summer and the Northern Hemisphere winter.
- **Equinoxes** (March & September): The tilt is perpendicular to the Sun-Earth line ($\delta \approx 0^\circ$), distributing equal 12-hour day and night across the globe.

The **Cosmic Dial** axial tilt widget updates in real time and with the time scrubber to illustrate this geometric phenomenon directly.

---

## 🚀 Installation

### Option 1: Using the Omarchy CLI (Recommended)

Run the following command in your terminal:

```bash
omarchy plugin add https://github.com/nestorandrespe/cosmic-dial.git --enable
```

### Option 2: Manual Installation

1. Clone the repository into your Omarchy plugins directory:
   ```bash
   git clone https://github.com/nestorandrespe/cosmic-dial.git ~/.config/omarchy/plugins/nestor.lunar-tracker
   ```

2. Add the widget to your bar in `~/.config/omarchy/shell.json` or reload the shell:
   ```bash
   omarchy-restart-shell
   ```

---

## 🛠️ Technology Stack

- **Framework**: [Quickshell](https://quickshell.outfoxxed.me/) & Qt6 QML / QtQuick
- **Rendering Engine**: HTML5 Canvas 2D API running on isolated Image framebuffers (`renderTarget: Canvas.Image`)
- **Cartography**: World GeoJSON vector data mapped to Natural Earth 1 projection
- **Ephemeris Algorithms**: Pure client-side JavaScript / Keplerian orbital physics (zero external API dependencies)

---

## 📜 License

MIT License © 2026 Nestor
