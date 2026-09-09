-- Raid Callouts
-- A lightweight raid-warning button panel for World of Warcraft 3.3.5.

local addonName = "RaidCallouts"
local panel
local titleText
local creatorText
local buttonContainer
local minimapButton
local togglePanel
local buttons = {}

local defaults = {
    locked = false,
    minimapAngle = 225,
    minimapHidden = false,
    minimapRadius = 80,
    panelScale = 1,
    panelWidth = 252,
    panelOpacity = 0.97,
    buttonHeight = 30,
    buttonOpacity = 0.98,
    fontSize = 12,
    showCreator = true,
    showLoadMessage = true,
    showSendConfirmation = true,
    playSound = false,
    targetFallback = "No Target",
    point = { "CENTER", "CENTER", 0, 140 },
    messages = {
        { label = "Everyone Follow Me", text = "Everyone Follow Me" },
        { label = "Back to me", text = "Back to me" },
        { label = "Go Go GO !", text = "Go Go GO !" },
        { label = "Kill > %t <", text = "Kill > %t <" },
    },
}

local raidMarkerTokens = {
    star = "{rt1}",
    circle = "{rt2}",
    diamond = "{rt3}",
    triangle = "{rt4}",
    moon = "{rt5}",
    square = "{rt6}",
    cross = "{rt7}",
    x = "{rt7}",
    skull = "{rt8}",
    rt1 = "{rt1}",
    rt2 = "{rt2}",
    rt3 = "{rt3}",
    rt4 = "{rt4}",
    rt5 = "{rt5}",
    rt6 = "{rt6}",
    rt7 = "{rt7}",
    rt8 = "{rt8}",
}

local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function copyDefaults()
    local database = {
        locked = defaults.locked,
        minimapAngle = defaults.minimapAngle,
        minimapHidden = defaults.minimapHidden,
        minimapRadius = defaults.minimapRadius,
        panelScale = defaults.panelScale,
        panelWidth = defaults.panelWidth,
        panelOpacity = defaults.panelOpacity,
        buttonHeight = defaults.buttonHeight,
        buttonOpacity = defaults.buttonOpacity,
        fontSize = defaults.fontSize,
        showCreator = defaults.showCreator,
        showLoadMessage = defaults.showLoadMessage,
        showSendConfirmation = defaults.showSendConfirmation,
        playSound = defaults.playSound,
        targetFallback = defaults.targetFallback,
        point = {
            defaults.point[1],
            defaults.point[2],
            defaults.point[3],
            defaults.point[4],
        },
        messages = {},
    }

    for index, message in ipairs(defaults.messages) do
        database.messages[index] = {
            label = message.label,
            text = message.text,
        }
    end

    return database
end

local function ensureDatabase()
    if type(RaidCalloutsDB) ~= "table" then
        RaidCalloutsDB = copyDefaults()
        return
    end

    if type(RaidCalloutsDB.messages) ~= "table" then
        RaidCalloutsDB.messages = {}
    end

    if type(RaidCalloutsDB.point) ~= "table" then
        RaidCalloutsDB.point = {
            defaults.point[1],
            defaults.point[2],
            defaults.point[3],
            defaults.point[4],
        }
    end

    if RaidCalloutsDB.locked == nil then
        RaidCalloutsDB.locked = defaults.locked
    end

    if type(RaidCalloutsDB.minimapAngle) ~= "number" then
        RaidCalloutsDB.minimapAngle = defaults.minimapAngle
    end

    if RaidCalloutsDB.minimapHidden == nil then
        RaidCalloutsDB.minimapHidden = defaults.minimapHidden
    end

    local settingDefaults = {
        minimapRadius = defaults.minimapRadius,
        panelScale = defaults.panelScale,
        panelWidth = defaults.panelWidth,
        panelOpacity = defaults.panelOpacity,
        buttonHeight = defaults.buttonHeight,
        buttonOpacity = defaults.buttonOpacity,
        fontSize = defaults.fontSize,
        showCreator = defaults.showCreator,
        showLoadMessage = defaults.showLoadMessage,
        showSendConfirmation = defaults.showSendConfirmation,
        playSound = defaults.playSound,
        targetFallback = defaults.targetFallback,
    }

    for key, value in pairs(settingDefaults) do
        if RaidCalloutsDB[key] == nil then
            RaidCalloutsDB[key] = value
        end
    end
end

local function showMessage(message, r, g, b)
    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff22d3ffRaid Callouts:|r |cff8de9ff" .. message .. "|r",
        r or 0.55,
        g or 0.91,
        b or 1
    )
end

local function canSendRaidWarning()
    if GetNumRaidMembers() == 0 then
        showMessage("You must be in a raid to send a raid warning.", 1, 0.3, 0.3)
        return false
    end

    if IsRaidLeader and IsRaidLeader() then
        return true
    end

    if IsRaidOfficer and IsRaidOfficer() then
        return true
    end

    local playerName = UnitName("player")
    local shortPlayerName = playerName and playerName:match("^([^-]+)") or playerName
    for index = 1, GetNumRaidMembers() do
        local raidMemberName, raidRank = GetRaidRosterInfo(index)
        local shortRaidMemberName = raidMemberName and raidMemberName:match("^([^-]+)") or raidMemberName
        if raidMemberName == playerName or shortRaidMemberName == shortPlayerName then
            if raidRank == 1 or raidRank == 2 then
                return true
            end

            showMessage("You need to be raid leader or assistant to send raid warnings.", 1, 0.3, 0.3)
            return false
        end
    end

    showMessage("Could not find your raid rank. Try again after the raid roster updates.", 1, 0.3, 0.3)
    return false
end

local function resolveTarget(text)
    local targetName = UnitName("target") or RaidCalloutsDB.targetFallback or defaults.targetFallback
    return text:gsub("%%t", function()
        return targetName
    end)
end

local function resolveRaidMarkers(text)
    return text:gsub("{([^{}]+)}", function(marker)
        local normalized = string.lower(trim(marker))
        return raidMarkerTokens[normalized] or "{" .. marker .. "}"
    end)
end

local function announce(message)
    if not canSendRaidWarning() then
        return
    end

    local resolvedMessage = resolveRaidMarkers(resolveTarget(message))
    SendChatMessage(resolvedMessage, "RAID_WARNING")
    if RaidCalloutsDB.showSendConfirmation then
        showMessage("Sent: " .. resolvedMessage, 0.5, 1, 0.5)
    end
    if RaidCalloutsDB.playSound then
        PlaySound("igMainMenuOptionCheckBoxOn")
    end
end

local function updatePanelSize()
    local messageCount = #RaidCalloutsDB.messages
    local rowHeight = RaidCalloutsDB.buttonHeight + 4
    local height = 78 + (messageCount * rowHeight) + 10
    if height < 120 then
        height = 120
    end
    panel:SetHeight(height)
end

local function createButton(index)
    local button = CreateFrame("Button", addonName .. "Button" .. index, buttonContainer)
    button:SetHeight(RaidCalloutsDB.buttonHeight)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 11,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    button:SetBackdropColor(0.015, 0.07, 0.14, RaidCalloutsDB.buttonOpacity)
    button:SetBackdropBorderColor(0.05, 0.48, 0.78, 0.95)

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER")
    label:SetJustifyH("CENTER")
    label:SetWidth(195)
    label:SetTextColor(0.68, 0.92, 1)
    local fontPath = GameFontNormal:GetFont()
    label:SetFont(fontPath, RaidCalloutsDB.fontSize)
    button.label = label

    local pulse = button:CreateTexture(nil, "ARTWORK")
    pulse:SetTexture("Interface\\Buttons\\WHITE8X8")
    pulse:SetVertexColor(0.05, 0.72, 1, 0.75)
    pulse:SetPoint("LEFT", button, "LEFT", 4, 0)
    pulse:SetWidth(2)
    pulse:SetHeight(math.max(12, RaidCalloutsDB.buttonHeight - 10))

    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.02, 0.20, 0.35, 1)
        self:SetBackdropBorderColor(0.12, 0.82, 1, 1)
        self.label:SetTextColor(0.9, 0.98, 1)
    end)

    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.015, 0.07, 0.14, RaidCalloutsDB.buttonOpacity)
        self:SetBackdropBorderColor(0.05, 0.48, 0.78, 0.95)
        self.label:SetTextColor(0.68, 0.92, 1)
    end)

    return button
end

local function rebuildButtons()
    for _, button in ipairs(buttons) do
        button:Hide()
    end

    for index, message in ipairs(RaidCalloutsDB.messages) do
        local button = buttons[index]
        if not button then
            button = createButton(index)
            buttons[index] = button
        end

        local rowHeight = RaidCalloutsDB.buttonHeight + 4
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", buttonContainer, "TOPLEFT", 0, -((index - 1) * rowHeight))
        button:SetPoint("TOPRIGHT", buttonContainer, "TOPRIGHT", 0, -((index - 1) * rowHeight))
        button:SetHeight(RaidCalloutsDB.buttonHeight)
        button:SetBackdropColor(0.015, 0.07, 0.14, RaidCalloutsDB.buttonOpacity)
        local fontPath = GameFontNormal:GetFont()
        button.label:SetFont(fontPath, RaidCalloutsDB.fontSize)
        button.label:SetWidth(math.max(120, RaidCalloutsDB.panelWidth - 55))
        button.label:SetText(message.label)
        button.message = message
        button:SetScript("OnClick", function(self)
            if self.message and self.message.text and self.message.text ~= "" then
                announce(self.message.text)
            else
                showMessage("This callout button has no message.", 1, 0.3, 0.3)
            end
        end)
        button:Show()
    end

    updatePanelSize()
end

local function applyLockState()
    panel:EnableMouse(true)
    if RaidCalloutsDB.locked then
        titleText:SetTextColor(0.35, 0.68, 0.82)
        titleText:SetText("RAID CALLOUTS  //  LOCKED")
    else
        titleText:SetTextColor(0.18, 0.84, 1)
        titleText:SetText("RAID CALLOUTS  //  COMMAND")
    end
end

local function applyAppearance()
    panel:SetWidth(RaidCalloutsDB.panelWidth)
    panel:SetScale(RaidCalloutsDB.panelScale)
    panel:SetAlpha(RaidCalloutsDB.panelOpacity)

    if RaidCalloutsDB.showCreator then
        creatorText:Show()
    else
        creatorText:Hide()
    end

    rebuildButtons()
end

local function createPanel()
    panel = CreateFrame("Frame", addonName .. "Panel", UIParent)
    panel:SetWidth(RaidCalloutsDB.panelWidth)
    panel:SetHeight(230)
    panel:SetFrameStrata("MEDIUM")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:SetToplevel(true)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 15,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:SetBackdropColor(0.005, 0.025, 0.07, 0.97)
    panel:SetBackdropBorderColor(0.02, 0.54, 0.88, 1)

    panel:SetPoint(
        RaidCalloutsDB.point[1],
        UIParent,
        RaidCalloutsDB.point[2],
        RaidCalloutsDB.point[3],
        RaidCalloutsDB.point[4]
    )

    local header = panel:CreateTexture(nil, "BACKGROUND")
    header:SetTexture("Interface\\Buttons\\WHITE8X8")
    header:SetVertexColor(0.015, 0.12, 0.23, 0.95)
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 7, -7)
    header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -7, -7)
    header:SetHeight(51)

    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetTexture("Interface\\AddOns\\RaidCallouts\\Textures\\RaidCalloutsLogo")
    logo:SetWidth(36)
    logo:SetHeight(36)
    logo:SetPoint("TOPLEFT", panel, "TOPLEFT", 15, -14)

    titleText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", panel, "TOPLEFT", 57, -16)
    titleText:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -13, -16)
    titleText:SetJustifyH("LEFT")

    creatorText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    creatorText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -4)
    creatorText:SetText("CREATED BY xLT69x")
    creatorText:SetTextColor(0.30, 0.62, 0.78)

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetTexture("Interface\\Buttons\\WHITE8X8")
    divider:SetVertexColor(0.05, 0.72, 1, 0.9)
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -58)
    divider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -58)

    local topGlow = panel:CreateTexture(nil, "ARTWORK")
    topGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
    topGlow:SetVertexColor(0.1, 0.86, 1, 0.9)
    topGlow:SetHeight(2)
    topGlow:SetPoint("TOPLEFT", panel, "TOPLEFT", 19, -5)
    topGlow:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -19, -5)

    buttonContainer = CreateFrame("Frame", nil, panel)
    buttonContainer:SetPoint("TOPLEFT", panel, "TOPLEFT", 15, -69)
    buttonContainer:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -15, -69)
    buttonContainer:SetHeight(1)

    panel:SetScript("OnMouseDown", function(self, mouseButton)
        if mouseButton == "LeftButton" and not RaidCalloutsDB.locked then
            self:StartMoving()
        end
    end)

    panel:SetScript("OnMouseUp", function(self, mouseButton)
        if mouseButton == "LeftButton" then
            self:StopMovingOrSizing()
            local point, _, relativePoint, x, y = self:GetPoint()
            RaidCalloutsDB.point = { point, relativePoint, x, y }
        end
    end)

    applyLockState()
    applyAppearance()
end

local function updateMinimapPosition()
    local angle = math.rad(RaidCalloutsDB.minimapAngle or defaults.minimapAngle)
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint(
        "CENTER",
        Minimap,
        "CENTER",
        math.cos(angle) * RaidCalloutsDB.minimapRadius,
        math.sin(angle) * RaidCalloutsDB.minimapRadius
    )
end

local function createMinimapButton()
    minimapButton = CreateFrame("Button", addonName .. "MinimapButton", Minimap)
    minimapButton:SetWidth(33)
    minimapButton:SetHeight(33)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapButton:RegisterForDrag("LeftButton")

    local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\AddOns\\RaidCallouts\\Textures\\RaidCalloutsLogo")
    icon:SetWidth(23)
    icon:SetHeight(23)
    icon:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)
    minimapButton.icon = icon

    local ring = minimapButton:CreateTexture(nil, "OVERLAY")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    ring:SetWidth(55)
    ring:SetHeight(55)
    ring:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 0, 0)

    local highlight = minimapButton:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    highlight:SetWidth(46)
    highlight:SetHeight(46)
    highlight:SetPoint("CENTER")

    minimapButton:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            RaidCalloutsDB.locked = not RaidCalloutsDB.locked
            applyLockState()
            if RaidCallouts_RefreshConfig then
                RaidCallouts_RefreshConfig()
            end
            showMessage(RaidCalloutsDB.locked and "Panel locked." or "Panel unlocked.")
        else
            togglePanel()
        end
    end)

    minimapButton:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local cursorX, cursorY = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            local centerX, centerY = Minimap:GetCenter()
            cursorX = cursorX / scale
            cursorY = cursorY / scale
            RaidCalloutsDB.minimapAngle = math.deg(math.atan2(cursorY - centerY, cursorX - centerX))
            updateMinimapPosition()
        end)
    end)

    minimapButton:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cff22d3ffRaid Callouts|r")
        GameTooltip:AddLine("|cff8de9ffLeft-click:|r Show or hide panel", 1, 1, 1)
        GameTooltip:AddLine("|cff8de9ffRight-click:|r Lock or unlock panel", 1, 1, 1)
        GameTooltip:AddLine("|cff8de9ffDrag:|r Move around minimap", 1, 1, 1)
        GameTooltip:Show()
    end)

    minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    updateMinimapPosition()
    if RaidCalloutsDB.minimapHidden then
        minimapButton:Hide()
    end
end

togglePanel = function()
    if panel:IsShown() then
        panel:Hide()
    else
        panel:Show()
    end
end

local function printHelp()
    showMessage("Commands:", 1, 0.82, 0.35)
    DEFAULT_CHAT_FRAME:AddMessage("  /rc — show or hide the callout panel")
    DEFAULT_CHAT_FRAME:AddMessage("  /rc config — open the standalone configuration")
    DEFAULT_CHAT_FRAME:AddMessage("  /rc add Label | Message — add a button")
    DEFAULT_CHAT_FRAME:AddMessage("  /rc remove Number — remove a button")
    DEFAULT_CHAT_FRAME:AddMessage("  /rc lock / unlock — lock or move the panel")
    DEFAULT_CHAT_FRAME:AddMessage("  /rc minimap — show or hide the minimap button")
    DEFAULT_CHAT_FRAME:AddMessage("  /rc reset — restore the four default buttons")
    DEFAULT_CHAT_FRAME:AddMessage("  Use %t in a message to insert your target's name.")
end

local function handleSlashCommand(message)
    local command = trim(message or "")
    local action, rest = command:match("^(%S+)%s*(.*)$")
    action = string.lower(action or "")
    rest = trim(rest or "")

    if action == "" or action == "show" then
        panel:Show()
        return
    end

    if action == "hide" then
        panel:Hide()
        return
    end

    if action == "toggle" then
        togglePanel()
        return
    end

    if action == "config" or action == "options" then
        if RaidCallouts_OpenConfig then
            RaidCallouts_OpenConfig()
        end
        return
    end

    if action == "lock" or action == "unlock" then
        RaidCalloutsDB.locked = action == "lock"
        applyLockState()
        if RaidCallouts_RefreshConfig then
            RaidCallouts_RefreshConfig()
        end
        showMessage(RaidCalloutsDB.locked and "Panel locked." or "Panel unlocked.")
        return
    end

    if action == "minimap" then
        RaidCalloutsDB.minimapHidden = not RaidCalloutsDB.minimapHidden
        if RaidCalloutsDB.minimapHidden then
            minimapButton:Hide()
            showMessage("Minimap button hidden. Type /rc minimap to show it again.")
        else
            minimapButton:Show()
            showMessage("Minimap button shown.")
        end
        if RaidCallouts_RefreshConfig then
            RaidCallouts_RefreshConfig()
        end
        return
    end

    if action == "reset" then
        RaidCallouts.ResetAll()
        return
    end

    if action == "add" then
        local label, text = rest:match("^(.-)%s*|+%s*(.+)$")
        if not label or not text then
            showMessage("Usage: /rc add Button Label | Raid warning text", 1, 0.3, 0.3)
            return
        end

        label = trim(label)
        text = trim(text)
        if label == "" or text == "" then
            showMessage("Both the button label and message are required.", 1, 0.3, 0.3)
            return
        end

        table.insert(RaidCalloutsDB.messages, { label = label, text = text })
        rebuildButtons()
        if RaidCallouts_RefreshConfig then
            RaidCallouts_RefreshConfig()
        end
        showMessage("Added button: " .. label, 0.5, 1, 0.5)
        return
    end

    if action == "remove" or action == "delete" then
        local index = tonumber(rest)
        if not index or not RaidCalloutsDB.messages[index] then
            showMessage("Usage: /rc remove ButtonNumber", 1, 0.3, 0.3)
            return
        end

        local removed = table.remove(RaidCalloutsDB.messages, index)
        rebuildButtons()
        if RaidCallouts_RefreshConfig then
            RaidCallouts_RefreshConfig()
        end
        showMessage("Removed button: " .. removed.label, 0.5, 1, 0.5)
        return
    end

    if action == "help" then
        printHelp()
        return
    end

    -- A bare message is useful for quickly testing a warning from chat.
    if command ~= "" then
        announce(command)
        return
    end

    printHelp()
end

RaidCallouts = RaidCallouts or {}

function RaidCallouts.GetDB()
    return RaidCalloutsDB
end

function RaidCallouts.ApplySettings()
    applyLockState()
    applyAppearance()
    updateMinimapPosition()
    if RaidCalloutsDB.minimapHidden then
        minimapButton:Hide()
    else
        minimapButton:Show()
    end
end

function RaidCallouts.ShowMainPanel()
    panel:Show()
end

function RaidCallouts.Announce(message)
    announce(message)
end

function RaidCallouts.ResolveMessage(message)
    return resolveRaidMarkers(resolveTarget(message))
end

function RaidCallouts.SaveMessage(index, label, text)
    local message = RaidCalloutsDB.messages[index]
    label = trim(label or "")
    text = trim(text or "")
    if not message or label == "" or text == "" then
        return false
    end

    message.label = label
    message.text = text
    rebuildButtons()
    return true
end

function RaidCallouts.AddMessage()
    table.insert(RaidCalloutsDB.messages, {
        label = "New Callout",
        text = "Raid warning message",
    })
    rebuildButtons()
    return #RaidCalloutsDB.messages
end

function RaidCallouts.DeleteMessage(index)
    if #RaidCalloutsDB.messages <= 1 or not RaidCalloutsDB.messages[index] then
        return false
    end

    table.remove(RaidCalloutsDB.messages, index)
    rebuildButtons()
    return true
end

function RaidCallouts.MoveMessage(index, direction)
    local destination = index + direction
    if not RaidCalloutsDB.messages[index] or not RaidCalloutsDB.messages[destination] then
        return false
    end

    RaidCalloutsDB.messages[index], RaidCalloutsDB.messages[destination] =
        RaidCalloutsDB.messages[destination], RaidCalloutsDB.messages[index]
    rebuildButtons()
    return true
end

function RaidCallouts.ResetMessages()
    RaidCalloutsDB.messages = {}
    for index, message in ipairs(defaults.messages) do
        RaidCalloutsDB.messages[index] = {
            label = message.label,
            text = message.text,
        }
    end
    rebuildButtons()
end

function RaidCallouts.ResetPosition()
    RaidCalloutsDB.point = {
        defaults.point[1],
        defaults.point[2],
        defaults.point[3],
        defaults.point[4],
    }
    panel:ClearAllPoints()
    panel:SetPoint(
        RaidCalloutsDB.point[1],
        UIParent,
        RaidCalloutsDB.point[2],
        RaidCalloutsDB.point[3],
        RaidCalloutsDB.point[4]
    )
end

function RaidCallouts.ResetAll()
    RaidCalloutsDB = copyDefaults()
    RaidCallouts.ResetPosition()
    RaidCallouts.ApplySettings()
    if RaidCallouts_RefreshConfig then
        RaidCallouts_RefreshConfig()
    end
    showMessage("All settings and default callouts restored.")
end

SLASH_RAIDCALLOUTS1 = "/rc"
SLASH_RAIDCALLOUTS2 = "/raidcallouts"
SlashCmdList["RAIDCALLOUTS"] = handleSlashCommand

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if event ~= "ADDON_LOADED" or loadedAddon ~= addonName then
        return
    end

    ensureDatabase()
    createPanel()
    createMinimapButton()
    if RaidCallouts_CreateConfigPanel then
        RaidCallouts_CreateConfigPanel()
    end
    if RaidCalloutsDB.showLoadMessage then
        showMessage("Created by xLT69x loaded. Type /rc help for commands.")
    end
    self:UnregisterEvent("ADDON_LOADED")
end)