# Project Structure
```
well/
├── README.md
├── well.lua
├── lib/
│   └── well_engine.lua       # optional: for any additional modules
└── docs/
    └── screenshots/
        └── well_screen.png   # add your own screenshots
```

# README.md content:
# Well

A deep audio well with circular ripples for monome norns.

## Description

Well creates cascading echoes that transpose up or down while getting quieter. Visual feedback shows concentric circles that respond to the audio, and grid integration allows for melodic input with rippling light patterns.

## Requirements

- norns (required)
- grid (optional)

## Features

- Descending or ascending pitch cascades
- Variable echo speed and decay
- Multiple musical scales
- Note holding functionality
- Visual feedback with concentric circles
- Grid integration with light ripples
- Choice between sample playback and PolyPerc engine

## Documentation

### Controls

#### Encoders
- E1: Change scale (Major, Minor, Pentatonic, Chromatic)
- E2: Switch direction (Up/Down)
- E3: Adjust Speed (mode 1) or Hold time (mode 2)

#### Keys
- K2: Toggle mode
- K3: Toggle sound source (Sample/PolyPerc)

#### Grid
- Press keys to trigger notes
- Hold keys for repeating notes
- Higher notes toward top of grid
- Visual ripple effect from pressed keys

### Installation

From maiden type:
```
;install https://github.com/PonchoMcGee/well
```

## Version History

- 1.0.0 Initial release
