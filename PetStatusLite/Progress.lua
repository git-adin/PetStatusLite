-- SPDX-License-Identifier: GPL-3.0-or-later
local _, addon = ...
local windowSeconds = 300

function addon.Readable(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

local readable = addon.Readable

function addon.ReadProgress()
    if not readable(UnitExists("pet")) then return end

    local level = readable(UnitLevel("pet"))
    local playerLevel = readable(UnitLevel("player"))
    local current, required = GetPetExperience()
    current, required = readable(current), readable(required)
    local progress = { level = level and level > 0 and level or nil }
    if progress.level and playerLevel and playerLevel > 0 then
        progress.levelsBehind = math.max(0, playerLevel - level)
    end
    if current and required and current >= 0 and required >= 0 then
        progress.current = current
        progress.required = required
        progress.remaining = math.max(0, required - current)
        if progress.levelsBehind ~= 0 and required > 0 then
            progress.fraction = math.min(1, current / required)
        end
    end
    return progress
end

function addon.CreatePaceTracker()
    local previous, petGUID, startedAt, lastGainAt, gains
    return function(progress, now)
        local guid = progress and progress.fraction and readable(UnitGUID("pet"))
        if not guid or not progress.level then
            previous, petGUID, startedAt, lastGainAt, gains = nil, nil, nil, nil, nil
            return
        end

        local gained
        if guid == petGUID then
            if progress.level == previous.level and progress.required == previous.required then
                gained = progress.current - previous.current
            elseif progress.level == previous.level + 1 then
                gained = previous.remaining + progress.current
            end
        end
        if not gained or gained < 0 then
            petGUID, startedAt, lastGainAt, gains, gained = guid, now, now, {}, 0
        elseif now - lastGainAt > windowSeconds then
            startedAt, lastGainAt, gains = now, now, {}
        end
        previous = progress

        while gains[1] and now - gains[1].time > windowSeconds do
            table.remove(gains, 1)
        end
        if gained > 0 then
            lastGainAt = now
            gains[#gains + 1] = { time = now, xp = gained }
        end
        local seconds = math.min(windowSeconds, now - startedAt)
        if #gains < 2 or seconds < 30 then return end

        local total = 0
        for _, gain in ipairs(gains) do total = total + gain.xp end
        return total / seconds
    end
end
