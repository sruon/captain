require('libs/colors/enums')

---@class ColorData
---@field chatColorCode string
---@field rgb integer[]

---@type table<number, ColorData>
local ColorManager = {
    [ColorEnum.White]       = { chatColorCode = string.char(0x1F, 1), rgb = { 255, 255, 255 } },
    [ColorEnum.Cyan]        = { chatColorCode = string.char(0x1F, 17), rgb = { 230, 255, 255 } },
    [ColorEnum.Pink]        = { chatColorCode = string.char(0x1F, 20), rgb = { 255, 200, 230 } },
    [ColorEnum.Salmon]      = { chatColorCode = string.char(0x1F, 2), rgb = { 255, 180, 185 } },
    [ColorEnum.Red]         = { chatColorCode = string.char(0x1F, 3), rgb = { 255, 150, 150 } },
    [ColorEnum.HotPink]     = { chatColorCode = string.char(0x1F, 123), rgb = { 255, 115, 170 } },
    [ColorEnum.Crimson]     = { chatColorCode = string.char(0x1F, 39), rgb = { 255, 60, 90 } },
    [ColorEnum.Ivory]       = { chatColorCode = string.char(0x1F, 129), rgb = { 255, 255, 215 } },
    [ColorEnum.Tan]         = { chatColorCode = string.char(0x1F, 53), rgb = { 225, 220, 185 } },
    [ColorEnum.LightYellow] = { chatColorCode = string.char(0x1F, 63), rgb = { 255, 255, 185 } },
    [ColorEnum.Yellow]      = { chatColorCode = string.char(0x1F, 36), rgb = { 255, 255, 90 } },
    [ColorEnum.Lavender]    = { chatColorCode = string.char(0x1F, 8), rgb = { 255, 205, 255 } },
    [ColorEnum.Magenta]     = { chatColorCode = string.char(0x1F, 4), rgb = { 255, 150, 255 } },
    [ColorEnum.Violet]      = { chatColorCode = string.char(0x1E, 72), rgb = { 250, 60, 255 } },
    [ColorEnum.Orchid]      = { chatColorCode = string.char(0x1F, 200), rgb = { 190, 90, 255 } },
    [ColorEnum.Blue]        = { chatColorCode = string.char(0x1E, 3), rgb = { 150, 150, 255 } },
    [ColorEnum.Sky]         = { chatColorCode = string.char(0x1E, 71), rgb = { 115, 170, 255 } },
    [ColorEnum.SoftBlue]    = { chatColorCode = string.char(0x1F, 207), rgb = { 150, 175, 255 } },
    [ColorEnum.Purple]      = { chatColorCode = string.char(0x1F, 7), rgb = { 200, 160, 255 } },
    [ColorEnum.Aqua]        = { chatColorCode = string.char(0x1F, 30), rgb = { 205, 255, 255 } },
    [ColorEnum.Seafoam]     = { chatColorCode = string.char(0x1F, 6), rgb = { 170, 255, 235 } },
    [ColorEnum.Turquoise]   = { chatColorCode = string.char(0x1F, 5), rgb = { 90, 255, 255 } },
    [ColorEnum.Teal]        = { chatColorCode = string.char(0x1E, 83), rgb = { 65, 255, 210 } },
    [ColorEnum.Green]       = { chatColorCode = string.char(0x1F, 158), rgb = { 30, 255, 70 } },
    [ColorEnum.Slate]       = { chatColorCode = string.char(0x1F, 160), rgb = { 155, 155, 195 } },
    [ColorEnum.Navy]        = { chatColorCode = string.char(0x1E, 65), rgb = { 60, 60, 110 } },
}

return ColorManager
