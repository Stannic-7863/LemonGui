package main

import cu "../"

PRIMARY_COLOR :: cu.Color{120, 113, 108, 255} // warm gray-500 (#78716C)
ON_PRIMARY_COLOR :: cu.Color{255, 255, 255, 255} // white

BACKGROUND_COLOR :: cu.Color{20, 20, 22, 255} // neutral dark gray (#141416)
SURFACE_COLOR :: cu.Color{34, 34, 36, 255} // slightly lighter (#222224)
ELEVATED_SURFACE_COLOR :: cu.Color{58, 58, 60, 255} // soft charcoal (#3A3A3C)

TEXT_PRIMARY_COLOR :: cu.Color{245, 245, 244, 255} // warm gray-100 (#F5F5F4)
TEXT_SECONDARY_COLOR :: cu.Color{168, 162, 158, 255} // warm gray-400 (#A8A29E)
TEXT_DISABLED_COLOR :: cu.Color{120, 113, 108, 255} // warm gray-500 (#78716C)

SUCCESS_COLOR :: cu.Color{77, 124, 15, 255} // olive green (#4D7C0F)
WARNING_COLOR :: cu.Color{202, 138, 4, 255} // golden amber (#CA8A04)
ERROR_COLOR :: cu.Color{153, 27, 27, 255} // dark red (#991B1B)
INFO_COLOR :: cu.Color{115, 115, 115, 255} // neutral gray (#737373)

BORDER_COLOR :: cu.Color{87, 83, 78, 255} // warm gray-700 (#57534E)
DIVIDER_COLOR :: cu.Color{113, 109, 104, 255} // warm gray-600 (#716D68)

main :: proc() {
	demo_nanovg()
}
