-- Raid Callouts configuration
-- Standalone World of Warcraft 3.3.5 configuration window.

local optionsPanel
local pages = {}
local tabs = {}
local controls = {}
local messageRows = {}
local messageScroll
local messageContent
local activeMessageBox
local activeTab = 1
local refreshing = false

local BLUE = {
    background = { 0.005, 0.025, 0.07, 0.98 },
    panel = { 0.01, 0.07, 0.14, 0.97 },
    button = { 0.015, 0.10, 0.19, 0.98 },
    buttonHover = { 0.02, 0.22, 0.38, 1 },
    border = { 0.03, 0.55, 0.90, 1 },
    accent = { 0.10, 0.84, 1, 1 },
    text = { 0.68, 0.92, 1, 1 },
    muted = { 0.35, 0.62, 0.76, 1 },
}

local function db()
    return RaidCallouts.GetDB()
end

local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function setBackdrop(frame, color)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 11,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(unpack(color or BLUE.panel))
    frame:SetBackdropBorderColor(unpack(BLUE.border))
end

local function createLabel(parent, text, x, y, fontObject)
    local label = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(text)
    label:SetTextColor(unpack(BLUE.text))
    return label
end

local function createButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetWidth(width)
    button:SetHeight(height)
    setBackdrop(button, BLUE.button)

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER")
    label:SetText(text)
    label:SetTextColor(unpack(BLUE.text))
    button.label = label

    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(BLUE.buttonHover))
        self:SetBackdropBorderColor(unpack(BLUE.accent))
        self.label:SetTextColor(0.92, 0.99, 1)
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(BLUE.button))
        self:SetBackdropBorderColor(unpack(BLUE.border))
        self.label:SetTextColor(unpack(BLUE.text))
    end)

    return button
end

local function createCheckbox(parent, text, key, x, y, inverted)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    checkbox:SetWidth(24)
    checkbox:SetHeight(24)

    local label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", checkbox, "RIGHT", 3, 0)
    label:SetText(text)
    label:SetTextColor(unpack(BLUE.text))
    checkbox.label = label

    checkbox:SetScript("OnClick", function(self)
        if refreshing then
            return
        end
        local checked = self:GetChecked() and true or false
        if inverted then
            db()[key] = not checked
        else
            db()[key] = checked
        end
        RaidCallouts.ApplySettings()
    end)

    controls[key] = {
        widget = checkbox,
        inverted = inverted,
        kind = "checkbox",
    }
    return checkbox
end

local sliderCount = 0
local function createSlider(parent, text, key, minimum, maximum, step, x, y, width, formatter)
    sliderCount = sliderCount + 1
    local name = "RaidCalloutsOptionsSlider" .. sliderCount
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    slider:SetWidth(width)
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(step)

    _G[name .. "Low"]:SetText(tostring(minimum))
    _G[name .. "High"]:SetText(tostring(maximum))
    _G[name .. "Text"]:SetText(text)
    _G[name .. "Text"]:SetTextColor(unpack(BLUE.text))
    _G[name .. "Low"]:SetTextColor(unpack(BLUE.muted))
    _G[name .. "High"]:SetTextColor(unpack(BLUE.muted))

    local valueLabel = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueLabel:SetPoint("TOP", slider, "BOTTOM", 0, -2)
    valueLabel:SetTextColor(unpack(BLUE.accent))
    slider.valueLabel = valueLabel

    slider:SetScript("OnValueChanged", function(self, value)
        local formatted = formatter and formatter(value) or tostring(math.floor(value + 0.5))
        self.valueLabel:SetText(formatted)
        if refreshing then
            return
        end
        db()[key] = value
        RaidCallouts.ApplySettings()
    end)

    controls[key] = {
        widget = slider,
        kind = "slider",
    }
    return slider
end

local editCount = 0
local function createEditBox(parent, width, height)
    editCount = editCount + 1
    local editBox = CreateFrame("EditBox", "RaidCalloutsOptionsEdit" .. editCount, parent)
    editBox:SetWidth(width)
    editBox:SetHeight(height)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetTextColor(unpack(BLUE.text))
    editBox:SetJustifyH("LEFT")
    editBox:SetTextInsets(6, 6, 2, 2)
    setBackdrop(editBox, BLUE.background)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    return editBox
end

local function showTab(index)
    activeTab = index
    for pageIndex, page in ipairs(pages) do
        if pageIndex == index then
            page:Show()
            tabs[pageIndex]:SetBackdropColor(unpack(BLUE.buttonHover))
            tabs[pageIndex]:SetBackdropBorderColor(unpack(BLUE.accent))
        else
            page:Hide()
            tabs[pageIndex]:SetBackdropColor(unpack(BLUE.button))
            tabs[pageIndex]:SetBackdropBorderColor(unpack(BLUE.border))
        end
    end
end

local function createPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -94)
    page:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -14, 14)
    return page
end

local function createSection(parent, title, x, y, width, height)
    local section = CreateFrame("Frame", nil, parent)
    section:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    section:SetWidth(width)
    section:SetHeight(height)
    setBackdrop(section, BLUE.panel)

    local titleLabel = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleLabel:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -10)
    titleLabel:SetText(title)
    titleLabel:SetTextColor(unpack(BLUE.accent))

    local line = section:CreateTexture(nil, "ARTWORK")
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    line:SetVertexColor(unpack(BLUE.border))
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", section, "TOPLEFT", 10, -29)
    line:SetPoint("TOPRIGHT", section, "TOPRIGHT", -10, -29)

    return section
end

local function createGeneralPage()
    local page = createPage(optionsPanel)
    pages[1] = page

    local behavior = createSection(page, "BEHAVIOR", 0, 0, 285, 238)
    createCheckbox(behavior, "Lock the main window", "locked", 12, -40)
    createCheckbox(behavior, "Show the minimap button", "minimapHidden", 12, -72, true)
    createCheckbox(behavior, "Show creator credit", "showCreator", 12, -104)
    createCheckbox(behavior, "Print startup message", "showLoadMessage", 12, -136)
    createCheckbox(behavior, "Confirm warnings in chat", "showSendConfirmation", 12, -168)
    createCheckbox(behavior, "Play sound when sent", "playSound", 12, -200)

    local target = createSection(page, "TARGET PLACEHOLDER", 298, 0, 285, 126)
    createLabel(target, "Text used for %t when you have no target:", 12, -42, "GameFontNormalSmall")
    local fallback = createEditBox(target, 250, 28)
    fallback:SetPoint("TOPLEFT", target, "TOPLEFT", 12, -66)
    fallback:SetMaxLetters(40)
    fallback:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    fallback:SetScript("OnEditFocusLost", function(self)
        local value = trim(self:GetText() or "")
        if value == "" then
            value = "No Target"
            self:SetText(value)
        end
        db().targetFallback = value
    end)
    controls.targetFallback = { widget = fallback, kind = "edit" }

    local actions = createSection(page, "QUICK ACTIONS", 298, -138, 285, 100)
    local showMain = createButton(actions, "SHOW MAIN WINDOW", 122, 30)
    showMain:SetPoint("TOPLEFT", actions, "TOPLEFT", 12, -43)
    showMain:SetScript("OnClick", function()
        RaidCallouts.ShowMainPanel()
    end)

    local resetPosition = createButton(actions, "RESET POSITION", 122, 30)
    resetPosition:SetPoint("TOPRIGHT", actions, "TOPRIGHT", -12, -43)
    resetPosition:SetScript("OnClick", function()
        RaidCallouts.ResetPosition()
        RaidCallouts.ShowMainPanel()
    end)

    local about = createSection(page, "ABOUT", 0, -250, 583, 132)
    local logo = about:CreateTexture(nil, "ARTWORK")
    logo:SetTexture("Interface\\AddOns\\RaidCallouts\\Textures\\RaidCalloutsLogo")
    logo:SetWidth(72)
    logo:SetHeight(72)
    logo:SetPoint("TOPLEFT", about, "TOPLEFT", 14, -42)
    createLabel(about, "Raid Callouts 1.2.2", 98, -45)
    createLabel(about, "Created by xLT69x", 98, -70, "GameFontNormalSmall")
    local aboutText = createLabel(
        about,
        "One-click raid warnings for leaders and assistants.\\nUse %t to insert your current target.",
        98,
        -92,
        "GameFontHighlightSmall"
    )
    aboutText:SetTextColor(unpack(BLUE.muted))
end

local function applyPreset(scale, width, height, fontSize)
    local data = db()
    data.panelScale = scale
    data.panelWidth = width
    data.buttonHeight = height
    data.fontSize = fontSize
    RaidCallouts.ApplySettings()
    RaidCallouts_RefreshConfig()
end

local function createAppearancePage()
    local page = createPage(optionsPanel)
    pages[2] = page

    local frameSection = createSection(page, "WINDOW", 0, 0, 285, 244)
    createSlider(frameSection, "Window scale", "panelScale", 0.70, 1.50, 0.05, 25, -55, 230, function(value)
        return string.format("%.0f%%", value * 100)
    end)
    createSlider(frameSection, "Window width", "panelWidth", 220, 400, 10, 25, -132, 230, function(value)
        return string.format("%d px", value)
    end)
    createSlider(frameSection, "Window opacity", "panelOpacity", 0.40, 1.00, 0.05, 25, -209, 230, function(value)
        return string.format("%.0f%%", value * 100)
    end)

    local buttonSection = createSection(page, "CALLOUT BUTTONS", 298, 0, 285, 244)
    createSlider(buttonSection, "Button height", "buttonHeight", 24, 44, 1, 25, -55, 230, function(value)
        return string.format("%d px", value)
    end)
    createSlider(buttonSection, "Button opacity", "buttonOpacity", 0.40, 1.00, 0.05, 25, -132, 230, function(value)
        return string.format("%.0f%%", value * 100)
    end)
    createSlider(buttonSection, "Font size", "fontSize", 9, 18, 1, 25, -209, 230, function(value)
        return string.format("%d pt", value)
    end)

    local minimap = createSection(page, "MINIMAP", 0, -256, 285, 126)
    createSlider(minimap, "Distance from minimap", "minimapRadius", 70, 110, 1, 25, -58, 230, function(value)
        return string.format("%d px", value)
    end)

    local presets = createSection(page, "SIZE PRESETS", 298, -256, 285, 126)
    local compact = createButton(presets, "COMPACT", 78, 30)
    compact:SetPoint("TOPLEFT", presets, "TOPLEFT", 12, -48)
    compact:SetScript("OnClick", function()
        applyPreset(0.90, 230, 26, 11)
    end)
    local standard = createButton(presets, "STANDARD", 78, 30)
    standard:SetPoint("LEFT", compact, "RIGHT", 10, 0)
    standard:SetScript("OnClick", function()
        applyPreset(1.00, 252, 30, 12)
    end)
    local large = createButton(presets, "LARGE", 78, 30)
    large:SetPoint("LEFT", standard, "RIGHT", 10, 0)
    large:SetScript("OnClick", function()
        applyPreset(1.15, 310, 36, 14)
    end)
end

local function saveMessageRow(row)
    local label = trim(row.labelBox:GetText() or "")
    local message = trim(row.messageBox:GetText() or "")
    if not RaidCallouts.SaveMessage(row.index, label, message) then
        RaidCallouts_RefreshConfig()
    else
        row.saveButton.label:SetText("SAVED")
        row.saveButton:SetBackdropBorderColor(0.1, 0.9, 1, 1)
    end
end

local function createMessageRow(index)
    local row = CreateFrame("Frame", nil, messageContent)
    row:SetHeight(43)
    row:SetPoint("TOPLEFT", messageContent, "TOPLEFT", 0, -((index - 1) * 47))
    row:SetPoint("TOPRIGHT", messageContent, "TOPRIGHT", 0, -((index - 1) * 47))
    setBackdrop(row, BLUE.panel)

    local number = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    number:SetPoint("LEFT", row, "LEFT", 8, 0)
    number:SetWidth(22)
    number:SetTextColor(unpack(BLUE.accent))
    row.number = number

    local labelBox = createEditBox(row, 128, 27)
    labelBox:SetPoint("LEFT", row, "LEFT", 32, 0)
    labelBox:SetMaxLetters(40)
    row.labelBox = labelBox

    local messageBox = createEditBox(row, 220, 27)
    messageBox:SetPoint("LEFT", labelBox, "RIGHT", 6, 0)
    messageBox:SetMaxLetters(200)
    messageBox:SetScript("OnEditFocusGained", function(self)
        activeMessageBox = self
    end)
    row.messageBox = messageBox

    local saveButton = createButton(row, "SAVE", 46, 27)
    saveButton:SetPoint("LEFT", messageBox, "RIGHT", 6, 0)
    row.saveButton = saveButton

    local upButton = createButton(row, "^", 24, 27)
    upButton:SetPoint("LEFT", saveButton, "RIGHT", 5, 0)
    local downButton = createButton(row, "v", 24, 27)
    downButton:SetPoint("LEFT", upButton, "RIGHT", 4, 0)
    local deleteButton = createButton(row, "X", 24, 27)
    deleteButton:SetPoint("LEFT", downButton, "RIGHT", 4, 0)

    saveButton:SetScript("OnClick", function()
        saveMessageRow(row)
    end)
    labelBox:SetScript("OnEnterPressed", function(self)
        saveMessageRow(row)
        self:ClearFocus()
    end)
    messageBox:SetScript("OnEnterPressed", function(self)
        saveMessageRow(row)
        self:ClearFocus()
    end)
    upButton:SetScript("OnClick", function()
        RaidCallouts.MoveMessage(row.index, -1)
        RaidCallouts_RefreshConfig()
    end)
    downButton:SetScript("OnClick", function()
        RaidCallouts.MoveMessage(row.index, 1)
        RaidCallouts_RefreshConfig()
    end)
    deleteButton:SetScript("OnClick", function()
        if RaidCallouts.DeleteMessage(row.index) then
            RaidCallouts_RefreshConfig()
        end
    end)

    messageRows[index] = row
    return row
end

local function refreshMessageRows()
    if not messageContent then
        return
    end

    local messages = db().messages
    for index, message in ipairs(messages) do
        local row = messageRows[index] or createMessageRow(index)
        row.index = index
        row.number:SetText(index)
        row.labelBox:SetText(message.label)
        row.messageBox:SetText(message.text)
        row.saveButton.label:SetText("SAVE")
        row:Show()
    end

    for index = #messages + 1, #messageRows do
        messageRows[index]:Hide()
    end

    messageContent:SetHeight(math.max(325, #messages * 47))
end

local function createMessagesPage()
    local page = createPage(optionsPanel)
    pages[3] = page

    createLabel(page, "EDIT CALLOUT BUTTONS", 4, -2)
    local hint = createLabel(
        page,
        "Change warning text. Use %t for your target; marker buttons insert raid icons.",
        4,
        -25,
        "GameFontHighlightSmall"
    )
    hint:SetTextColor(unpack(BLUE.muted))

    createLabel(page, "INSERT MARKER:", 4, -53, "GameFontNormalSmall")
    local markerNames = {
        { name = "Star", token = "{rt1}", icon = 1 },
        { name = "Circle", token = "{rt2}", icon = 2 },
        { name = "Diamond", token = "{rt3}", icon = 3 },
        { name = "Triangle", token = "{rt4}", icon = 4 },
        { name = "Moon", token = "{rt5}", icon = 5 },
        { name = "Square", token = "{rt6}", icon = 6 },
        { name = "Cross", token = "{rt7}", icon = 7 },
        { name = "Skull", token = "{rt8}", icon = 8 },
    }
    for index, marker in ipairs(markerNames) do
        local markerInfo = marker
        local markerButton = createButton(page, "", 27, 27)
        markerButton:SetPoint("TOPLEFT", page, "TOPLEFT", 92 + ((index - 1) * 32), -47)

        local markerIcon = markerButton:CreateTexture(nil, "ARTWORK")
        markerIcon:SetTexture(
            "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. markerInfo.icon
        )
        markerIcon:SetWidth(19)
        markerIcon:SetHeight(19)
        markerIcon:SetPoint("CENTER")

        markerButton:SetScript("OnClick", function()
            if activeMessageBox then
                activeMessageBox:SetText(
                    (activeMessageBox:GetText() or "") .. markerInfo.token
                )
                activeMessageBox:SetFocus()
            else
                DEFAULT_CHAT_FRAME:AddMessage(
                    "|cff22d3ffRaid Callouts:|r Click inside a callout message first."
                )
            end
        end)
        markerButton:SetScript("OnEnter", function(self)
            self:SetBackdropColor(unpack(BLUE.buttonHover))
            self:SetBackdropBorderColor(unpack(BLUE.accent))
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(markerInfo.name .. "  " .. markerInfo.token)
            GameTooltip:Show()
        end)
        markerButton:SetScript("OnLeave", function(self)
            self:SetBackdropColor(unpack(BLUE.button))
            self:SetBackdropBorderColor(unpack(BLUE.border))
            GameTooltip:Hide()
        end)
    end

    messageScroll = CreateFrame(
        "ScrollFrame",
        "RaidCalloutsMessageScrollFrame",
        page,
        "UIPanelScrollFrameTemplate"
    )
    messageScroll:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -82)
    messageScroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -29, 56)

    messageContent = CreateFrame("Frame", nil, messageScroll)
    messageContent:SetWidth(548)
    messageContent:SetHeight(325)
    messageScroll:SetScrollChild(messageContent)

    local addButton = createButton(page, "ADD CALLOUT", 132, 32)
    addButton:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 8)
    addButton:SetScript("OnClick", function()
        RaidCallouts.AddMessage()
        RaidCallouts_RefreshConfig()
        messageScroll:SetVerticalScroll(messageContent:GetHeight())
    end)

    local resetButton = createButton(page, "RESET DEFAULT CALLOUTS", 176, 32)
    resetButton:SetPoint("LEFT", addButton, "RIGHT", 10, 0)
    resetButton:SetScript("OnClick", function()
        RaidCallouts.ResetMessages()
        RaidCallouts_RefreshConfig()
    end)

    local testButton = createButton(page, "SEND FIRST CALLOUT", 160, 32)
    testButton:SetPoint("LEFT", resetButton, "RIGHT", 10, 0)
    testButton:SetScript("OnClick", function()
        local first = db().messages[1]
        if first then
            RaidCallouts.Announce(first.text)
        end
    end)
end

function RaidCallouts_RefreshConfig()
    if not optionsPanel then
        return
    end

    refreshing = true
    local data = db()
    for key, control in pairs(controls) do
        if control.kind == "checkbox" then
            local value = data[key] and true or false
            if control.inverted then
                control.widget:SetChecked(not value)
            else
                control.widget:SetChecked(value)
            end
        elseif control.kind == "slider" then
            control.widget:SetValue(data[key])
        elseif control.kind == "edit" then
            control.widget:SetText(data[key] or "")
        end
    end
    refreshMessageRows()
    refreshing = false
end

function RaidCallouts_CreateConfigPanel()
    if optionsPanel then
        return
    end

    optionsPanel = CreateFrame("Frame", "RaidCalloutsOptionsPanel", UIParent)
    optionsPanel:SetWidth(640)
    optionsPanel:SetHeight(540)
    optionsPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    optionsPanel:SetFrameStrata("DIALOG")
    optionsPanel:SetClampedToScreen(true)
    optionsPanel:SetMovable(true)
    optionsPanel:EnableMouse(true)
    optionsPanel:Hide()

    local buildSucceeded, buildError = pcall(function()
    local background = CreateFrame("Frame", nil, optionsPanel)
    background:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 4, -4)
    background:SetPoint("BOTTOMRIGHT", optionsPanel, "BOTTOMRIGHT", -4, 4)
    setBackdrop(background, BLUE.background)

    local logo = background:CreateTexture(nil, "ARTWORK")
    logo:SetTexture("Interface\\AddOns\\RaidCallouts\\Textures\\RaidCalloutsLogo")
    logo:SetWidth(50)
    logo:SetHeight(50)
    logo:SetPoint("TOPLEFT", background, "TOPLEFT", 14, -12)

    local title = background:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", background, "TOPLEFT", 72, -18)
    title:SetText("RAID CALLOUTS // CONFIGURATION")
    title:SetTextColor(unpack(BLUE.accent))

    local subtitle = background:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Created by xLT69x  //  World of Warcraft 3.3.5")
    subtitle:SetTextColor(unpack(BLUE.muted))

    local closeButton = createButton(background, "X", 30, 28)
    closeButton:SetPoint("TOPRIGHT", background, "TOPRIGHT", -12, -12)
    closeButton:SetScript("OnClick", function()
        optionsPanel:Hide()
    end)

    local tabNames = { "GENERAL", "APPEARANCE", "CALLOUTS" }
    for index, tabName in ipairs(tabNames) do
        local tabIndex = index
        local tab = createButton(background, tabName, 135, 28)
        tab:SetPoint("TOPLEFT", background, "TOPLEFT", 16 + ((index - 1) * 145), -64)
        tab:SetScript("OnClick", function()
            showTab(tabIndex)
        end)
        tabs[index] = tab
    end

    optionsPanel.content = background
    optionsPanel:SetScript("OnShow", function()
        RaidCallouts_RefreshConfig()
        showTab(activeTab)
    end)
    optionsPanel.default = function()
        RaidCallouts.ResetAll()
    end
    optionsPanel:SetScript("OnMouseDown", function(self, mouseButton)
        if mouseButton == "LeftButton" then
            self:StartMoving()
        end
    end)
    optionsPanel:SetScript("OnMouseUp", function(self, mouseButton)
        if mouseButton == "LeftButton" then
            self:StopMovingOrSizing()
        end
    end)

    createGeneralPage()
    createAppearancePage()
    createMessagesPage()
    showTab(1)
    end)

    if not buildSucceeded then
        optionsPanel.configBuildError = tostring(buildError)
        local errorText = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        errorText:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 24, -40)
        errorText:SetWidth(540)
        errorText:SetJustifyH("LEFT")
        errorText:SetText(
            "|cffff5555Raid Callouts configuration failed to build:|r\n" ..
            optionsPanel.configBuildError
        )
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff22d3ffRaid Callouts config error:|r " .. optionsPanel.configBuildError
        )
    end
end

function RaidCallouts_OpenConfig()
    if not optionsPanel then
        RaidCallouts_CreateConfigPanel()
    end
    if not optionsPanel then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff22d3ffRaid Callouts:|r Could not create the configuration window."
        )
        return
    end
    optionsPanel:Show()
    if optionsPanel.configBuildError then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff22d3ffRaid Callouts config error:|r " ..
            optionsPanel.configBuildError
        )
    end
end