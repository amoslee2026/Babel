# ASAP7 IO Pad Reference

## Input Pads
| Cell Name  | Width (um) | Height (um) | Description          |
|------------|-----------|-------------|----------------------|
| IO_IN_V1   | 10.0      | 20.0        | Standard input pad   |
| IO_IN_V2   | 10.0      | 25.0        | Input pad with clamp |
| IO_IN_DIFF | 15.0      | 20.0        | Differential input   |

## Output Pads
| Cell Name  | Width (um) | Height (um) | Drive (mA) |
|------------|-----------|-------------|------------|
| IO_OUT_2   | 10.0      | 20.0        | 2          |
| IO_OUT_4   | 10.0      | 20.0        | 4          |
| IO_OUT_8   | 12.0      | 20.0        | 8          |
| IO_OUT_16  | 15.0      | 20.0        | 16         |

## Bidirectional Pads
| Cell Name  | Width (um) | Height (um) | Description |
|------------|-----------|-------------|-------------|
| IO_BIDI_2  | 12.0      | 20.0        | 2mA bidi    |
| IO_BIDI_4  | 12.0      | 20.0        | 4mA bidi    |
| IO_BIDI_8  | 15.0      | 20.0        | 8mA bidi    |

## Power Pads
| Cell Name  | Width (um) | Height (um) | Description        |
|------------|-----------|-------------|--------------------|
| IO_PWR     | 10.0      | 20.0        | Power/ground pad   |
| IO_CORNER  | 10.0      | 10.0        | Corner filler       |

## Placement Guidelines
- Minimum pad-to-pad spacing: 2.0 um
- Power pad every 10 IO pads recommended
- Corner pads required at all die corners
- Orientations: N (north), S (south), E (east), W (west)
- Pad height matches standard cell row height (20 um)
- 7nm: use IO_OUT_4 or higher for reliable signaling
