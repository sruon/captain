-- Credits: sruon
-- Tracks mob immunities and resistances to magic spells

---@class ImmunityTrackAddon : AddonInterface
local addon =
{
    name            = 'ImmunityTrack',
    filters         =
    {
        incoming =
        {
            [PacketId.GP_SERV_COMMAND_BATTLE2]        = true, -- Action packets
            [PacketId.GP_SERV_COMMAND_BATTLE_MESSAGE] = true, -- Battle messages (defeat)
        },
    },
    mobImmunities   = {}, -- Track immunities per mob during combat: { [mob_id] = { [spell_name] = count } }
    mobTraitResists = {}, -- Track trait-based resists per mob: { [mob_id] = { [spell_name] = true } }
    mobResists      = {}, -- Track regular resists per mob: { [mob_id] = { [spell_name] = { casts = X, resists = Y } } }
}

-- Helper to build sorted spell list from a table
local function getSpellList(data)
    local spells = {}
    for spell_name in pairs(data) do
        table.insert(spells, spell_name)
    end
    table.sort(spells)
    return spells
end

-- Helper to ensure mob tracking table exists
local function ensureMobTable(table, mobId)
    if not table[mobId] then
        table[mobId] = {}
    end
end

addon.onIncomingPacket = function(id, data, size, packet)
    if not packet then
        return
    end

    -- Handle defeat messages
    if id == PacketId.GP_SERV_COMMAND_BATTLE_MESSAGE then
        if (packet.MessageNum == 6 or packet.MessageNum == 20) and packet.UniqueNoTar then
            local defeatedId   = packet.UniqueNoTar
            local immunityData = addon.mobImmunities[defeatedId]
            local traitData    = addon.mobTraitResists[defeatedId]
            local resistData   = addon.mobResists[defeatedId]

            -- Only print if we have tracked data
            if (immunityData and next(immunityData)) or (traitData and next(traitData)) or (resistData and next(resistData)) then
                local mob_name = backend.get_mob_by_id(defeatedId)
                mob_name       = mob_name and mob_name.name or tostring(defeatedId)

                -- Line 1: Complete immunities
                if immunityData and next(immunityData) then
                    backend.msg('ImmunityTrack',
                        string.format('%s - Immune: %s', mob_name, table.concat(getSpellList(immunityData), ', ')))
                end

                -- Line 2: Trait resists
                if traitData and next(traitData) then
                    backend.msg('ImmunityTrack',
                        string.format('%s - Traits Resist: %s', mob_name, table.concat(getSpellList(traitData), ', ')))
                end

                -- Line 3: Regular resists with per-spell breakdown
                if resistData and next(resistData) then
                    local resistStrings = {}
                    for spell_name, data in pairs(resistData) do
                        if data.resists > 0 then
                            table.insert(resistStrings, string.format('%s: %d/%d (%.1f%%)',
                                spell_name, data.resists, data.casts,
                                data.casts > 0 and (data.resists * 100 / data.casts) or 0))
                        end
                    end
                    if #resistStrings > 0 then
                        table.sort(resistStrings)
                        backend.msg('ImmunityTrack',
                            string.format('%s - Resists: %s', mob_name, table.concat(resistStrings, ', ')))
                    end
                end

                -- Clear this mob's data
                addon.mobImmunities[defeatedId]   = nil
                addon.mobTraitResists[defeatedId] = nil
                addon.mobResists[defeatedId]      = nil
            end
        end
        return
    end

    if id ~= PacketId.GP_SERV_COMMAND_BATTLE2 then
        return
    end

    -- Check if this is a magic finish (category 4)
    if packet.cmd_no ~= 4 then
        return
    end

    -- cmd_arg should contain the spell ID
    local spell_id = packet.cmd_arg
    if not spell_id or spell_id == 0 then
        return
    end

    -- Get spell name
    local spell_name = backend.get_spell_name(spell_id)

    -- Iterate through all targets
    if packet.target then
        for i = 1, #packet.target do
            local target = packet.target[i]
            if target.result then
                for j = 1, #target.result do
                    local result          = target.result[j]

                    -- Check for immunity message (655)
                    local is_immunity     = result.message == 655
                    -- Check for resist message (85)
                    local is_resist       = result.message == 85
                    -- Check if 2nd bit is set in bit field (trait resist)
                    local is_trait_resist = is_resist and result.bit and (bit.band(result.bit, 0x02) ~= 0)

                    if is_immunity then
                        ensureMobTable(addon.mobImmunities, target.m_uID)
                        addon.mobImmunities[target.m_uID][spell_name] = (addon.mobImmunities[target.m_uID][spell_name] or 0) +
                        1
                    elseif is_trait_resist then
                        ensureMobTable(addon.mobTraitResists, target.m_uID)
                        addon.mobTraitResists[target.m_uID][spell_name] = true
                    else
                        -- Track all casts and regular resists
                        ensureMobTable(addon.mobResists, target.m_uID)
                        if not addon.mobResists[target.m_uID][spell_name] then
                            addon.mobResists[target.m_uID][spell_name] = { casts = 0, resists = 0 }
                        end
                        addon.mobResists[target.m_uID][spell_name].casts = addon.mobResists[target.m_uID][spell_name]
                        .casts + 1
                        if is_resist then
                            addon.mobResists[target.m_uID][spell_name].resists = addon.mobResists[target.m_uID]
                            [spell_name].resists + 1
                        end
                    end
                end
            end
        end
    end
end

return addon
