local FISH_MSG       =
{
    NOROD                    = 0x01, -- You can't fish without a rod in your hands.
    NOBAIT                   = 0x02, -- You can't fish without bait on the hook.
    CANNOTFISH_MOMENT        = 0x03, -- You can't fish at the moment.
    NOCATCH                  = 0x04, -- You didn't catch anything.
    MONSTER                  = 0x05, -- <Player> caught a monster!
    LINEBREAK                = 0x06, -- Your line breaks.
    RODBREAK                 = 0x07, -- Your rod breaks.
    HOOKED_SMALL             = 0x08, -- Something caught the hook!
    LOST                     = 0x09, -- You lost your catch.
    CATCH_INV_FULL           = 0x0A, -- Caught but inventory full
    CATCH_MULTI              = 0x0E, -- <Player> caught X <Fish>
    RODBREAK_TOOBIG          = 0x11, -- Your rod breaks. Whatever caught the hook was pretty big.
    RODBREAK_TOOHEAVY        = 0x12, -- Your rod breaks. Too heavy for this rod.
    LOST_TOOSMALL            = 0x13, -- You lost your catch. Too small for this rod.
    LOST_LOWSKILL            = 0x14, -- You lost your catch due to your lack of skill.
    GOLDFISH_PAPER_RIPPED    = 0x17, -- The paper on your scoop ripped
    GOLDFISH_TINY_APPROACHES = 0x18, -- A tiny goldfish approaches!
    GOLDFISH_PLUMP_BLACK     = 0x19, -- A plump, black goldfish approaches!
    GOLDFISH_FAT_JUICY       = 0x1A, -- A fat, juicy goldfish approaches!
    NO_GOLDFISH_FOUND        = 0x1B, -- There are no goldfish to be found...
    GOLDFISH_CAUGHT_FULL     = 0x1C, -- Caught goldfish but inventory full
    GOLDFISH_SLIPPED_OFF     = 0x1D, -- The goldfish slipped off your scoop...
    GIVEUP_BAITLOSS          = 0x24, -- You give up and reel in your line.
    GIVEUP                   = 0x25, -- You give up.
    CATCH                    = 0x27, -- <Player> caught <Fish>
    WARNING                  = 0x28, -- You don't know how much longer you can keep this one on the line...
    GOOD_FEELING             = 0x29, -- You have a good feeling about this one!
    BAD_FEELING              = 0x2A, -- You have a bad feeling about this one.
    TERRIBLE_FEELING         = 0x2B, -- You have a terrible feeling about this one...
    NOSKILL_FEELING          = 0x2C, -- You don't know if you have enough skill to reel this one in.
    NOSKILL_SURE_FEELING     = 0x2D, -- You're fairly sure you don't have enough skill.
    NOSKILL_POSITIVE_FEELING = 0x2E, -- You're positive you don't have enough skill!
    HOOKED_LARGE             = 0x32, -- Something caught the hook!!!
    HOOKED_ITEM              = 0x33, -- You feel something pulling at your line.
    HOOKED_MONSTER           = 0x34, -- Something clamps onto your line ferociously!
    KEEN_ANGLERS_SENSE       = 0x35, -- Your keen angler's senses tell you this is <fish>
    EPIC_CATCH               = 0x36, -- This strength... epic catch!
    LOST_TOOBIG              = 0x3C, -- You lost your catch. Too large for this rod.
    HURRY_GOLDFISH_WARNING   = 0x3F, -- Hurry before the goldfish sees you!
    CATCH_CHEST              = 0x40, -- <Player> fishes up a large box!
    CANNOTFISH_TIME          = 0x5E, -- You can't fish at this time
}

local FISH_MSG_NAMES = {}
for name, id in pairs(FISH_MSG) do
    FISH_MSG_NAMES[id] = name
end

return
{
    MSG   = FISH_MSG,
    NAMES = FISH_MSG_NAMES,
}
