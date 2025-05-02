local function padLeft(str, length, char)
    local padded = string.rep(char or ' ', length - #str) .. str
    return padded
end

local function padRight(str, length, char)
    local padded = str .. string.rep(char or ' ', length - #str)
    return padded
end

---@class BoxManager
---@field boxes table
---@field frozen boolean
---@field settings { show: boolean, max_num: number, autoHide: boolean, hideDelay: number, spacing: number, pos: { x: number, y: number }, bg: table, text: table }
---@field render fun(self: BoxManager)
---@field renderSegments fun(self: BoxManager, templatedSegments: { text: string, color: string, padLeft: number, padRight: number, newline: boolean }[], data: { [string]: any }): { text: string, color: string }[]
---@field create fun(self: BoxManager, segments: { text: string, color: string, padLeft: number, padRight: number, newline: boolean }[], freeze: boolean)

---@class BoxManagerClass
---@field new fun(settings: { show: boolean, max_num: number, autoHide: boolean, hideDelay: number, spacing: number, pos: { x: number, y: number }, bg: table, text: table }): BoxManager


---@type BoxManager
local boxManager = {}
boxManager.__index = boxManager

---@param settings { show: boolean, max_num: number, autoHide: boolean, hideDelay: number, spacing: number, pos: { x: number, y: number }, bg: { [string]: any }, text: { [string]: any } }
---@return BoxManager
function boxManager.new(settings)
    ---@type BoxManager
    local self = setmetatable({}, boxManager)
    self.boxes = {}
    self.frozen = false
    self.settings = settings
    return self
end

function boxManager:renderSegments(templatedSegments, data)
    local renderedSegments = {}

    for _, segment in ipairs(templatedSegments) do
        if segment.text then
            local pos = 1
            while pos <= #segment.text do
                local start_pos, end_pos, key, fmt = segment.text:find("%${(.-)|(.-)}", pos)
                if start_pos then
                    -- Static text before field
                    if start_pos > pos then
                        local static_text = segment.text:sub(pos, start_pos - 1)
                        table.insert(renderedSegments, { text = static_text, color = segment.color })
                    end

                    -- Field itself
                    local value = data[key]
                    if value == nil then
                        value = 'nil'
                    else
                        value = string.format(fmt, value)
                    end

                    -- Apply padding if specified
                    if segment.padLeft then
                        value = padLeft(value, segment.padLeft)
                    elseif segment.padRight then
                        value = padRight(value, segment.padRight)
                    end

                    table.insert(renderedSegments, { text = value, color = segment.color })

                    pos = end_pos + 1
                else
                    -- Remaining static text
                    local remaining = segment.text:sub(pos)
                    table.insert(renderedSegments, { text = remaining, color = segment.color })
                    break
                end
            end
        elseif segment.newline then
            table.insert(renderedSegments, { newline = true })
        end
    end

    return renderedSegments
end

function boxManager:create(segments, freeze)
    if not self.settings.show or not segments then
        return
    end

    self.frozen = freeze

    local box =
    {
        id = ('%d-%d'):format(os.time(), math.random(100000, 999999)),
        segments = segments
    }

    table.insert(self.boxes, box)
    if #self.boxes > self.settings.max_num then
        if type(backend.boxDestroy) == 'function' then
            backend.boxDestroy(self.boxes[1])
        end

        table.remove(self.boxes)
    end

    if self.settings.autoHide then
        local box_ref = box

        local function wait_for_unfreeze()
            if self.frozen then
                backend.schedule(wait_for_unfreeze, 1.0)
            else
                local function try_remove()
                    for i = #self.boxes, 1, -1 do
                        if self.boxes[i] == box_ref then
                            if type(backend.boxDestroy) == 'function' then
                                backend.boxDestroy(self.boxes[i])
                            end

                            table.remove(self.boxes, i)
                            return
                        end
                    end
                end

                backend.schedule(try_remove, self.settings.hideDelay or 6.0)
            end
        end

        backend.schedule(wait_for_unfreeze, 1.0)
    end
end

function boxManager:render()
    if not self.settings.show then
        return
    end

    local x = self.settings.pos.x
    local y = self.settings.pos.y

    for i = #self.boxes, 1, -1 do
        local box              = self.boxes[i]

        -- Windower has pre-created boxes, just need the display slot
        box.displayIndex       =  captain.settings.box.max_num - #self.boxes + i
        -- Ashita deals with coordinates directly
        box.x                  = x
        box.y                  = y

        box.max_chars_per_line = 60
        box.max_lines          = 5
        box.bg                 = setmetatable({}, { __index = self.settings.bg })
        box.text               = setmetatable({}, { __index = self.settings.text })

        local box_height       = backend.boxDraw(box)

        y                      = y - (box_height + self.settings.spacing)
    end
end

return boxManager
