-- SPDX-License-Identifier: GPL-3.0-or-later
local addonName, addon = ...
local title = "Pet Status Lite"
local readable = addon.Readable
local panelWidth = 218
local bubbleCount = 10

local function remainingXP(progress)
    if progress.levelsBehind == 0 then return "At your level" end
    if not progress.remaining then return end
    if progress.required == 0 then return "No XP needed" end
    return BreakUpLargeNumbers(progress.remaining)
end

local function xpPerHour(progress, pace)
    if progress.levelsBehind == 0 then return "At your level" end
    if not progress.fraction then return end
    if not pace then return "Learning pace..." end
    return BreakUpLargeNumbers(math.floor(pace * 3600 + 0.5))
end

local function catchUpETA(progress, pace)
    local levels = progress.levelsBehind
    if levels == 0 then return "Caught up" end
    if not levels or not progress.fraction then return end
    if not pace then return "Learning pace..." end

    -- Only the current level's XP requirement is available from the client.
    local remaining = progress.remaining + (levels - 1) * progress.required
    local seconds = remaining / pace
    if seconds < 60 then return "< 1 min" end
    local minutes = math.ceil(seconds / 60)
    if minutes < 60 then return ("~%d min"):format(minutes) end
    return ("~%dh %02dm"):format(math.floor(minutes / 60), minutes % 60)
end

local function loyalty()
    local rank = readable(C_PetInfo.GetPetLoyalty())
    if rank and rank ~= "" then return rank end
end

local happinessLabels = {
    PET_HAPPINESS1 or "Unhappy",
    PET_HAPPINESS2 or "Content",
    PET_HAPPINESS3 or "Happy",
}
local happinessColors = { "ffff7474", "ffffd270", "ff80e590" }

local function hunger()
    local mood = readable(C_PetInfo.GetPetHappiness())
    if mood and happinessLabels[mood] then
        return "|c" .. happinessColors[mood] .. happinessLabels[mood] .. "|r"
    end
end

local stats = {
    { key = "level", label = "Level", read = function(progress) return progress.level end },
    { key = "xp", label = "XP to next level", read = remainingXP },
    { key = "xpBar", label = "XP bubble bar" },
    { key = "xpRate", label = "XP per hour", read = xpPerHour, disabledByDefault = true },
    { key = "catchUp", label = "Catch-up ETA", read = catchUpETA, disabledByDefault = true },
    { key = "loyalty", label = "Loyalty", read = loyalty },
    { key = "hunger", label = "Hunger", option = "Hunger (happiness)", read = hunger },
}

local function createPanel(width, height)
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.055, 0.065, 0.075, 0.94)
    frame:SetBackdropBorderColor(0.37, 0.33, 0.24, 1)
    frame:Hide()
    return frame
end

local function createXPBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(panelWidth - 20, 9)
    local bubbles = {}
    local bubbleWidth, gap = 17, 3
    for index = 1, bubbleCount do
        local offset = (index - 1) * (bubbleWidth + gap)
        local background = bar:CreateTexture(nil, "BACKGROUND")
        background:SetPoint("TOPLEFT", offset, 0)
        background:SetSize(bubbleWidth, 8)
        background:SetColorTexture(0.23, 0.20, 0.31, 1)

        local fill = bar:CreateTexture(nil, "ARTWORK")
        fill:SetPoint("TOPLEFT", offset, 0)
        fill:SetHeight(8)
        fill:SetColorTexture(0.68, 0.47, 0.96, 1)
        bubbles[index] = fill
    end
    local function setFraction(fraction)
        for index, fill in ipairs(bubbles) do
            local segment = math.min(1, fraction * bubbleCount - (index - 1))
            if segment > 0 then fill:SetWidth(segment * bubbleWidth) end
            fill:SetShown(segment > 0)
        end
    end
    return bar, setFraction
end

local function initialize()
    if type(PetStatusLiteDB) ~= "table" then PetStatusLiteDB = {} end
    local db = PetStatusLiteDB
    if type(db.visible) ~= "boolean" then db.visible = true end
    if type(db.stats) ~= "table" then db.stats = {} end
    for _, stat in ipairs(stats) do
        if type(db.stats[stat.key]) ~= "boolean" then
            db.stats[stat.key] = not stat.disabledByDefault
        end
    end

    local panel = createPanel(panelWidth, 60)
    if db.position then
        local position = db.position
        panel:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    else
        panel:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -24, -285)
    end
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    local function stopMoving(self)
        if not self.isMoving then return end
        self:StopMovingOrSizing()
        self.isMoving = nil
        local point, _, relativePoint, x, y = self:GetPoint()
        db.position = { point = point, relativePoint = relativePoint, x = x, y = y }
    end
    panel:SetScript("OnDragStart", function(self)
        self:StartMoving()
        self.isMoving = true
    end)
    panel:SetScript("OnDragStop", stopMoving)

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading:SetPoint("TOPLEFT", 10, -9)
    heading:SetPoint("TOPRIGHT", -10, -9)
    heading:SetJustifyH("LEFT")

    local empty = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    empty:SetPoint("TOPLEFT", 10, -30)
    local bar, setFraction = createXPBar(panel)
    local rows = {}
    for _, stat in ipairs(stats) do
        if stat.read then
            local row = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row:SetWidth(panelWidth - 20)
            row:SetJustifyH("LEFT")
            rows[stat.key] = row
        end
    end

    local function refresh(progress, pace)
        heading:SetText(progress and readable(UnitName("pet")) or title)
        local y = 30
        for _, stat in ipairs(stats) do
            local row = rows[stat.key] or bar
            local shown = progress and db.stats[stat.key] and (stat.read or progress.fraction)
            row:SetShown(not not shown)
            if shown then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 10, -y)
                if stat.read then
                    row:SetText(("|cffb8b5ab%s|r  %s"):format(stat.label, stat.read(progress, pace) or "Unavailable"))
                    y = y + row:GetStringHeight() + 3
                else
                    setFraction(progress.fraction)
                    y = y + 13
                end
            end
        end
        empty:SetShown(y == 30)
        if y == 30 then
            local message = "No active pet"
            if progress then
                message = db.stats.xpBar and "No pet XP to display" or "Choose stats in Options"
            end
            empty:SetText(message)
            y = y + empty:GetStringHeight()
        end
        panel:SetHeight(y + 9)
    end

    local trackPace = addon.CreatePaceTracker()
    local ticker
    local function update()
        local progress = addon.ReadProgress()
        local pace = trackPace((db.stats.catchUp or db.stats.xpRate) and progress or nil, GetTime())
        if panel:IsShown() then refresh(progress, pace) end
    end
    local function syncTicker()
        if panel:IsShown() or db.stats.catchUp or db.stats.xpRate then
            if not ticker then ticker = C_Timer.NewTicker(1, update) end
        elseif ticker then
            ticker:Cancel()
            ticker = nil
        end
    end
    panel:SetScript("OnShow", function()
        update()
        syncTicker()
    end)
    panel:SetScript("OnHide", function(self)
        stopMoving(self)
        syncTicker()
    end)

    local options = createPanel(panelWidth, 51 + 27 * #stats)
    options:SetPoint("CENTER")
    options:SetFrameStrata("DIALOG")
    options:EnableMouse(true)

    local optionsTitle = options:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    optionsTitle:SetPoint("TOPLEFT", 12, -12)
    optionsTitle:SetText(title .. " Options")

    local close = CreateFrame("Button", nil, options, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() options:Hide() end)

    for index, stat in ipairs(stats) do
        local key = stat.key
        local checkbox = CreateFrame("CheckButton", nil, options, "UICheckButtonTemplate")
        checkbox:SetSize(24, 24)
        checkbox:SetPoint("TOPLEFT", 10, -34 - (index - 1) * 27)
        checkbox:SetHitRectInsets(0, -165, 0, 0)
        checkbox:SetChecked(db.stats[key])
        local label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
        label:SetText(stat.option or stat.label)
        checkbox:SetScript("OnClick", function(self)
            db.stats[key] = not not self:GetChecked()
            update()
            syncTicker()
        end)
    end

    local function togglePanel()
        db.visible = not db.visible
        panel:SetShown(db.visible)
    end

    local function toggleOptions()
        options:SetShown(not options:IsShown())
    end

    local button = CreateFrame("Button", nil, Minimap)
    button:SetSize(28, 28)
    button:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", 7, 7)
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER")
    icon:SetSize(19, 19)
    icon:SetTexture("Interface\\Icons\\Ability_Hunter_BeastCall")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local rim = button:CreateTexture(nil, "OVERLAY")
    rim:SetSize(50, 50)
    rim:SetPoint("TOPLEFT")
    rim:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            toggleOptions()
        else
            togglePanel()
        end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(title)
        GameTooltip:AddLine("Left-click to toggle the panel", 1, 1, 1)
        GameTooltip:AddLine("Right-click for options", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    SLASH_PETSTATUSLITE1 = "/petstatuslite"
    SlashCmdList.PETSTATUSLITE = function(message)
        if message:match("^%s*options%s*$") then
            toggleOptions()
        else
            togglePanel()
        end
    end

    panel:SetShown(db.visible)
    if not db.visible then
        update()
        syncTicker()
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, loadedAddon)
    if loadedAddon ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")

    local _, class = UnitClass("player")
    if class == "HUNTER" then initialize() end
end)
