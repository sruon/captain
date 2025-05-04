local s =
{
    notifications =
    {
        scale        = 1,
        show         = true,
        autoHide     = true,
        hideDelay    = 5,
        max_num      = 4,
        spacing      = 8,
        offset       = -- Notifications will be offset from the bottom right of the screen
        {
            x = 20,
            y = 20,
        },
        colors       =
        {
            title = ColorEnum.SoftBlue,
            key   = ColorEnum.Purple,
            value = ColorEnum.Seafoam,
        },
        pos          =
        {
            x = 200,
            y = 50,
        },
        text         =
        {
            size  = 15,
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
    textBox = -- Default text box settings
    {
        scale = 1,
        defaults =
        {
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
                visible = true,
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
                size = 13,
                font = 'Consolas',
            },
        },
    },
}

return s
