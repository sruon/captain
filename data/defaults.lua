local s =
{
    box =
    {
        show         = true,
        autoHide     = true,
        frozen       = false,
        hideDelay    = 5,
        hide_ticking = false,
        max_num      = 4,
        spacing      = 8,
        pos          =
        {
            x = 200,
            y = 200,
        },
        text         =
        {
            size  = 14,
            font  = 'Consolas',
            alpha = 255,
            red   = 255,
            green = 255,
            blue  = 255,
        },
        flags        =
        {
            right     = false,
            bottom    = false,
            bold      = false,
            italic    = false,
            draggable = true,
        },
        padding      = 0,
        bg           =
        {
            red   = 30,
            green = 30,
            blue  = 60,
            alpha = 230,
        },
    },
    textBox =       -- Default text box settings
    {
        store = {}, -- Windower only: Individual box settings
        defaults = {
            pos =
            {
                x = 290,
                y = 0,
            },
            bg =
            {
                alpha   = 64,
                red     = 0,
                green   = 0,
                blue    = 0,
                visible = true
            },
            flags =
            {
                right     = false,
                bottom    = false,
                bold      = false,
                italic    = false,
                draggable = true,
            },
            padding = 3,
            text =
            {
                size = 12,
                font = 'Consolas',
            }
        }
    }
}

return s
