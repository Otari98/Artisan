local _G = _G or getfenv(0)
local maxCraftReagents = 8
local craftSkillHeight = 16
local craftsDisplayed = 12
local maxTabs = 7
local updateDelay = 0.2
local timer = nil
local searchResults = {}
local editorSearchResults = {}
local playerProfessions = {}
local collapsedHeaders = {}

BINDING_HEADER_ARTISAN_TITLE = "Artisan Bindings"
BINDING_NAME_ARTISAN_CREATE = "Create"
BINDING_NAME_ARTISAN_CREATE_ALL = "Create All"

local tabsOrder = {
    [1] = {
        ["Alchemy"] = true,
        ["Blacksmithing"] = true,
        ["Leatherworking"] = true,
        ["Tailoring"] = true,
        ["Engineering"] = true,
        ["Jewelcrafting"] = true,
        ["Enchanting"] = true,
        ["Smelting"] = true,
    },
    [2] = {
        ["First Aid"] = true,
        ["Cooking"] = true,
        ["Survival"] = true,
    },
    [3] = {
        ["Beast Training"] = true,
        ["Poisons"] = true,
        ["Disguise"] = true,
    }
}

local patternsToHeaders = {
    ["Enchanting"] = {
        ["bracer"] = "Bracer",
        ["boots"] = "Boots",
        ["gloves"] = "Gloves",
        ["2h weapon"] = "2H Weapon",
        ["enchant weapon"] = "Weapon",
        ["wand"] = "Wand",
        ["mana oil$"] = "Consumable",
        ["wizard oil$"] = "Consumable",
        ["cloak"] = "Cloak",
        ["chest"] = "Chest",
        ["shield"] = "Shield",
    }
}

local TypeColor = {
    ["optimal"] = { r = 1.00, g = 0.50, b = 0.25 },
    ["medium"]  = { r = 1.00, g = 1.00, b = 0.00 },
    ["easy"]    = { r = 0.25, g = 0.75, b = 0.25 },
    ["trivial"] = { r = 0.50, g = 0.50, b = 0.50 },
    ["header"]  = { r = 1.00, g = 0.82, b = 0.00 },
    ["used"]    = { r = 0.50, g = 0.50, b = 0.50 },
    ["none"]    = { r = 0.25, g = 0.75, b = 0.25 },
}

tinsert(UISpecialFrames, "ArtisanFrame")

local YELLOW = NORMAL_FONT_COLOR_CODE
local WHITE = HIGHLIGHT_FONT_COLOR_CODE
local GREEN = GREEN_FONT_COLOR_CODE
local GREY = GRAY_FONT_COLOR_CODE
local BLUE = "|cff0070de"

print = print or function(...)
    local size = getn(arg)
    for i = 1, size do
        arg[i] = tostring(arg[i])
    end
    local msg = size > 1 and table.concat(arg, ", ") or tostring(arg[1])
    DEFAULT_CHAT_FRAME:AddMessage(msg)
    return msg
end

local getn = table.getn
local tinsert = table.insert
local tremove = table.remove

local function wipe(tbl)
	if type(tbl) ~= "table" then return end
    for i = getn(tbl), 1, -1 do
        tremove(tbl, i)
    end
end

local function listContains(list, key, value)
    if type(list) ~= "table" then
        return false
    end
    if not key and value then
        for k, v in pairs(list) do
            if v == value then
                return k
            end
        end
    end
    if key and not value then
        return list[key] ~= nil
    end
    return list[key] == value
end

local function strtrim(s)
	return (string.gsub(s or "", "^%s*(.-)%s*$", "%1"))
end

local splitResult = {}
local function strsplit(str, delimiter)
    wipe(splitResult)
    local from = 1
    local delim_from, delim_to = string.find(str, delimiter, from, true)
    while delim_from do
        tinsert(splitResult, string.sub(str, from, delim_from - 1))
        from = delim_to + 1
        delim_from, delim_to = string.find(str, delimiter, from, true)
    end
    tinsert(splitResult, string.sub(str, from))
    return splitResult
end

function ArtisanFrame_Search()
	wipe(searchResults)
	local query = strlower(ArtisanFrameSearchBox:GetText())
    query = strtrim(query)
    local reagentsFilter = ARTISAN_CONFIG.reagents[ArtisanFrame.selectedTabName]
    if query == "" and not reagentsFilter then
        ArtisanFrame_Update()
        return
    end

    local numSkills = Artisan_GetNumCrafts()

    for i = 1, numSkills do
        local skillName, skillType, numAvailable, isExpanded = Artisan_GetCraftInfo(i)

        if skillName then
            if skillType == "header" then
                if not isExpanded then
                    Artisan_ExpandCraftSkillLine(i)
                end
            else
                if reagentsFilter and numAvailable > 0 then
                    if query ~= "" then
                        local words = strsplit(query, " ")
                        local match = true
                        for _, w in ipairs(words) do
                            if not strfind(strlower(skillName), strlower(w), 1, true) then
                                match = false
                                break
                            end
                        end
                        if match then
                            tinsert(searchResults, i)
                        end
                    else
                        tinsert(searchResults, i)
                    end
                elseif not reagentsFilter then
                    if query ~= "" then
                        local words = strsplit(query, " ")
                        local match = true
                        for _, w in ipairs(words) do
                            if not strfind(strlower(skillName), strlower(w), 1, true) then
                                match = false
                                break
                            end
                        end
                        if match then
                            tinsert(searchResults, i)
                        end
                    end
                end
            end
        end
    end
	ArtisanFrame_Update()
end

function ArtisanFrame_OnLoad()
    this:RegisterEvent("ADDON_LOADED")
    this:RegisterEvent("BAG_UPDATE")
    this:RegisterEvent("PLAYER_ENTERING_WORLD")
    this:RegisterEvent("UNIT_PORTRAIT_UPDATE")
    this:RegisterEvent("CRAFT_UPDATE")
    this:RegisterEvent("UPDATE_TRADESKILL_RECAST")
    this:RegisterEvent("SPELLS_CHANGED")
    this:RegisterEvent("UNIT_PET_TRAINING_POINTS")
    this:RegisterEvent("TRADE_SKILL_SHOW")
    this:RegisterEvent("TRADE_SKILL_CLOSE")
    this:RegisterEvent("TRADE_SKILL_UPDATE")
    this:RegisterEvent("UPDATE_TRADESKILL_RECAST")
    this:RegisterEvent("CRAFT_SHOW")
    this:RegisterEvent("CRAFT_CLOSE")
    this:RegisterEvent("CRAFT_UPDATE")
    this:RegisterEvent("REPLACE_ENCHANT")
	this:RegisterEvent("TRADE_REPLACE_ENCHANT")
    this:RegisterEvent("SKILL_LINES_CHANGED")
end

function Artisan_Init()
    if IsAddOnLoaded("Blizzard_TradeSkillUI") and IsAddOnLoaded("Blizzard_CraftUI") then
        return
    end
    EnableAddOn("Blizzard_TradeSkillUI")
    EnableAddOn("Blizzard_CraftUI")
    LoadAddOn("Blizzard_TradeSkillUI")
    LoadAddOn("Blizzard_CraftUI")
    TradeSkillFrame:UnregisterAllEvents()
    CraftFrame:UnregisterAllEvents()
    UIParent:UnregisterEvent("TRADE_SKILL_SHOW")
    UIParent:UnregisterEvent("TRADE_SKILL_CLOSE")
    UIParent:UnregisterEvent("CRAFT_SHOW")
    UIParent:UnregisterEvent("CRAFT_CLOSE")

    if ArtisanFrame then
        local tradeSkillOnMouseUp = TradeSkillReagent1:GetScript("OnMouseUp")
        for i = 1, maxCraftReagents do
            _G["ArtisanReagent"..i]:SetScript("OnMouseUp", tradeSkillOnMouseUp)
        end
    end

    ArtisanFrame.selectedSkill = 0
    ArtisanFrame.originalScroll = ArtisanDetailScrollFrame:GetScript("OnMouseWheel")
    FauxScrollFrame_SetOffset(TradeSkillListScrollFrame, 0)

    SLASH_ARTISAN1 = "/artisan"
    SlashCmdList["ARTISAN"] = function(msg)
        Artisan_SlashCommand(msg)
    end
end

function ArtisanFrame_OnUpdate(deltaTime)
    if not timer then
        return
    end
    timer = timer - deltaTime
    if timer <= 0 then
        timer = nil
        Artisan_SetupSideTabs()
        Artisan_Reselect()
        ArtisanFrame_Search()
    end
end

function ArtisanFrame_OnMouseDown()
    ArtisanFrameSearchBox:ClearFocus()
    if not ARTISAN_CONFIG.movable then
        return
    end
    ArtisanFrame:StartMoving()
end

function ArtisanFrame_OnMouseUp()
    if not ARTISAN_CONFIG.movable then
        return
    end
    ArtisanFrame:StopMovingOrSizing()
    local point, relativeTo, relativePoint, offsetX, offsetY = ArtisanFrame:GetPoint()
    ARTISAN_CONFIG.X = offsetX
    ARTISAN_CONFIG.Y = offsetY
end

function ArtisanFrame_OnEvent()
    if event == "ADDON_LOADED" and arg1 == "Artisan" then
        this:UnregisterEvent("ADDON_LOADED")
        ArtisanRankFrame:SetStatusBarColor(0.0, 0.0, 1.0, 0.5)
        ArtisanRankFrameBackground:SetVertexColor(0.0, 0.0, 0.75, 0.5)
        ARTISAN_SKILLS = type(ARTISAN_SKILLS) ~= "table" and {} or ARTISAN_SKILLS
        ARTISAN_CUSTOM = type(ARTISAN_CUSTOM) ~= "table" and {} or ARTISAN_CUSTOM
        ARTISAN_UNCATEGORIZED = type(ARTISAN_UNCATEGORIZED) ~= "table" and {} or ARTISAN_UNCATEGORIZED
        ARTISAN_CONFIG = type(ARTISAN_CONFIG) ~= "table" and {} or ARTISAN_CONFIG
        ARTISAN_CONFIG.sorting = type(ARTISAN_CONFIG.sorting) ~= "table" and {} or ARTISAN_CONFIG.sorting
        ARTISAN_CONFIG.auto = ARTISAN_CONFIG.auto == nil and true or ARTISAN_CONFIG.auto
        ARTISAN_CONFIG.icons = ARTISAN_CONFIG.icons == nil and true or ARTISAN_CONFIG.icons
        ARTISAN_CONFIG.reagents = type(ARTISAN_CONFIG.reagents) ~= "table" and {} or ARTISAN_CONFIG.reagents
        ARTISAN_CONFIG.movable = ARTISAN_CONFIG.movable == nil and false or ARTISAN_CONFIG.movable
        if not ARTISAN_CONFIG.auto then
            ArtisanFrame:UnregisterEvent("REPLACE_ENCHANT")
            ArtisanFrame:UnregisterEvent("TRADE_REPLACE_ENCHANT")
        end
        if not ARTISAN_CONFIG.movable then
            UIPanelWindows["ArtisanFrame"] = { area = "left", pushable = 4 }
        else
            ArtisanFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", ARTISAN_CONFIG.X or 0, ARTISAN_CONFIG.Y or -104)
        end
    elseif event == "SPELLS_CHANGED" then
        Artisan_SetupSideTabs()
    elseif event == "SKILL_LINES_CHANGED" then
        Artisan_SetupSideTabs()
        ArtisanFrame_Search()
    elseif event == "PLAYER_ENTERING_WORLD" then
        HideUIPanel(ArtisanFrame)
        SetPortraitTexture(ArtisanFramePortrait, "player")
        Artisan_Init()
    elseif event == "UNIT_PORTRAIT_UPDATE" and arg1 == "player" then
        SetPortraitTexture(ArtisanFramePortrait, "player")
    elseif event == "UNIT_PET_TRAINING_POINTS" then
		Artisan_UpdateTrainingPoints()
    elseif event == "TRADE_SKILL_UPDATE" or event == "CRAFT_UPDATE" then
        timer = updateDelay
    elseif event == "TRADE_SKILL_SHOW" then
        CloseCraft()
        ArtisanFrame_Show()
    elseif event == "CRAFT_SHOW" then
        CloseTradeSkill()
        ArtisanFrame_Show()
    elseif event == "TRADE_SKILL_CLOSE" or event == "CRAFT_CLOSE" then
        if GetCraftName() ~= "Beast Training" and GetCraftName() ~= "Disguise" and GetCraftDisplaySkillLine() ~= "Enchanting" and GetTradeSkillLine() == "UNKNOWN" then
            ArtisanFrame.selectedTabName = nil
        end
        if not ArtisanFrame.selectedTabName then
            if ArtisanFrame:IsShown() then
                HideUIPanel(ArtisanFrame)
            end
        end
    elseif event == "UPDATE_TRADESKILL_RECAST" then
		ArtisanFrameInputBox:SetNumber(GetTradeskillRepeatCount())
    elseif event == "BAG_UPDATE" then
        if ArtisanFrame:IsShown() then
            Artisan_Reselect()
		    ArtisanFrame_Search()
        end
    elseif event == "REPLACE_ENCHANT" then
        ReplaceEnchant()
        StaticPopup_Hide("REPLACE_ENCHANT")
    elseif event == "TRADE_REPLACE_ENCHANT" then
        ReplaceTradeEnchant()
        StaticPopup_Hide("TRADE_REPLACE_ENCHANT")
    end
end

function ArtisanFrame_Show()
    wipe(searchResults)

    if not ArtisanFrame:IsShown() then
        ShowUIPanel(ArtisanFrame)
    end

    Artisan_SetupSideTabs()
    ArtisanFrame_Search()
    if ARTISAN_CONFIG.sorting[ArtisanFrame.selectedTabName] == "default" then
        ArtisanSortDefault:SetChecked(1)
        ArtisanSortCustom:SetChecked(nil)
        ArtisanFrameEditButton:Hide()
    elseif ARTISAN_CONFIG.sorting[ArtisanFrame.selectedTabName] == "custom" then
        ArtisanSortCustom:SetChecked(1)
        ArtisanSortDefault:SetChecked(nil)
        ArtisanFrameEditButton:Show()
    end
    if ARTISAN_CONFIG.reagents[ArtisanFrame.selectedTabName] then
        ArtisanHaveReagents:Show()
        ArtisanHaveReagents:SetChecked(1)
    else
        ArtisanHaveReagents:SetChecked(nil)
    end
end

function Artisan_Reselect()
    local tab = ArtisanFrame.selectedTabName
    local sorting = ARTISAN_CONFIG.sorting[tab]
    if sorting == "default" and not ArtisanFrame.craft then
        if GetTradeSkillSelectionIndex() > 1 and GetTradeSkillSelectionIndex() <= GetNumTradeSkills() then
            Artisan_SetSelection(GetTradeSkillSelectionIndex())
        else
            Artisan_SetSelection(GetFirstTradeSkill())
            FauxScrollFrame_SetOffset(ArtisanListScrollFrame, 0)
            ArtisanListScrollFrameScrollBar:SetValue(0)
        end
    else
        Artisan_UpdateSkillList()
        local selection = ArtisanFrame.selectedSkill
        local numCrafts = Artisan_GetNumCrafts()
        if selection > 1 and selection <= numCrafts then
            Artisan_SetSelection(selection)
        else
            Artisan_SetSelection(Artisan_GetFirstCraft())
            FauxScrollFrame_SetOffset(ArtisanListScrollFrame, 0)
            ArtisanListScrollFrame:SetVerticalScroll(0)
            ArtisanListScrollFrameScrollBar:SetValue(0)
        end
    end
end

function Artisan_SetupSideTabs()
    local _, _, _, numSpells = GetSpellTabInfo(1)
    local tabIndex = 1
    for spell = 1, numSpells do
        local spellName = GetSpellName(spell, "SPELL")
        if tabsOrder[1][spellName] or tabsOrder[2][spellName] or tabsOrder[3][spellName] then
            playerProfessions[tabIndex] = playerProfessions[tabIndex] or {}
            playerProfessions[tabIndex].name = spellName
            playerProfessions[tabIndex].tex = GetSpellTexture(spell, "SPELL")
            playerProfessions[tabIndex].active = IsCurrentCast(spell, "SPELL")
            tabIndex = tabIndex + 1
        end
    end
    tabIndex = 1
    local tabButton

    for p = 1, getn(tabsOrder) do
        for index = 1, getn(playerProfessions) do
            local spellName = playerProfessions[index].name
            local active = playerProfessions[index].active
            if tabsOrder[p][spellName] then
                tabButton = _G["ArtisanFrameSideTab"..tabIndex]
                tabButton.name = spellName
                tabButton:SetNormalTexture(playerProfessions[index].tex)
                tabButton:Show()
                tabButton:SetChecked(active)
                if active then
                    ArtisanFrame.selectedTabName = spellName
                    ArtisanFrame.craft = spellName == "Beast Training" or spellName == "Enchanting" or spellName == "Disguise"
                end
                tabIndex = tabIndex + 1
            end
        end
    end

    ARTISAN_CONFIG.sorting = ARTISAN_CONFIG.sorting or {}
    for _, v in pairs(playerProfessions) do
        ARTISAN_CONFIG.sorting[v.name] = ARTISAN_CONFIG.sorting[v.name] or "default"
        ARTISAN_CONFIG.reagents[v.name] = ARTISAN_CONFIG.reagents[v.name] or false
    end
end

local function C_GetNumCrafts()
    if not ArtisanFrame.craft then
        for i = GetNumTradeSkills(), 1, -1 do
            local _, type, _, isExpanded = GetTradeSkillInfo(i)
            if type == "header" and not isExpanded then
                ExpandTradeSkillSubClass(i)
            end
        end
        return GetNumTradeSkills()
    else
        return GetNumCrafts()
    end
end

local function C_GetCraftInfo(originalIndex)
    local craftName, craftType, numAvailable, isExpanded, craftSubSpellName, trainingPointCost, requiredLevel
    if not ArtisanFrame.craft then
        craftName, craftType, numAvailable, isExpanded, craftSubSpellName, trainingPointCost, requiredLevel = GetTradeSkillInfo(originalIndex)
    else
        craftName, craftSubSpellName, craftType, numAvailable, isExpanded, trainingPointCost, requiredLevel = GetCraftInfo(originalIndex)
    end
    return craftName, craftType, numAvailable, isExpanded, craftSubSpellName, trainingPointCost, requiredLevel
end

function Artisan_UpdateSkillList()
    local tab = ArtisanFrame.selectedTabName
    local sorting = ARTISAN_CONFIG.sorting[tab]
    local numHeaders = 0

    ARTISAN_SKILLS[tab] = ARTISAN_SKILLS[tab] or {}
    ARTISAN_SKILLS[tab][sorting] = ARTISAN_SKILLS[tab][sorting] or {}

    collapsedHeaders = collapsedHeaders or {}
    collapsedHeaders[tab] = collapsedHeaders[tab] or {}
    collapsedHeaders[tab][sorting] = collapsedHeaders[tab][sorting] or {}

    wipe(ARTISAN_SKILLS[tab][sorting])

    if sorting == "default" then
        if tab == "Enchanting" then
            ARTISAN_SKILLS[tab][sorting][0] = ARTISAN_SKILLS[tab][sorting][0] or { name = "All", type = "header", exp = 1, childs = {} }
            wipe(ARTISAN_SKILLS[tab][sorting][0].childs)
            ARTISAN_SKILLS[tab][sorting][0].exp = 1
            numHeaders = 1
            local headerIndex = 0
            for i = 1, GetNumCrafts() do
                local name, sub, type, num, exp, tp, lvl = GetCraftInfo(i)
                if type ~= "header" then
                    -- default to Miscellaneous
                    local header = "Miscellaneous"
                    for pattern, hdr in pairs(patternsToHeaders[tab]) do
                        if strfind(strlower(name), strlower(pattern)) then
                            header = hdr
                            break
                        end
                    end
                    local found = false
                    for k, v in pairs(ARTISAN_SKILLS[tab][sorting]) do
                        if v.name == header then
                            -- header exists already
                            headerIndex = k
                            found = true
                        end
                    end
                    if not found then
                        -- add new header
                        numHeaders = numHeaders + 1
                        tinsert(ARTISAN_SKILLS[tab][sorting][0].childs, header)
                        tinsert(ARTISAN_SKILLS[tab][sorting], { name = header, type = "header", childs = {} })
                        headerIndex = getn(ARTISAN_SKILLS[tab][sorting])
                        if not collapsedHeaders[tab][sorting][header] then
                            ARTISAN_SKILLS[tab][sorting][headerIndex].exp = 1
                        end
                    end
                    -- add this skill
                    tinsert(ARTISAN_SKILLS[tab][sorting][headerIndex].childs, name)
                    if ARTISAN_SKILLS[tab][sorting][headerIndex].exp == 1 then
                        tinsert(ARTISAN_SKILLS[tab][sorting], headerIndex + 1, {
                            name = name,
                            type = type,
                            num = num,
                            exp = exp,
                            sub = sub,
                            tp = tp,
                            lvl = lvl,
                            id = i,
                        })
                    end
                end
            end
        elseif tab == "Beast Training" or tab == "Disguise" then
            -- no headers for these professions atm
            for i = 1, GetNumCrafts() do
                local name, sub, type, num, exp, tp, lvl = GetCraftInfo(i)
                if name then
                    tinsert(ARTISAN_SKILLS[tab][sorting], {
                        name = name,
                        sub = sub,
                        type = type,
                        num = num,
                        exp = exp,
                        tp = tp,
                        lvl = lvl,
                        id = i,
                    })
                end
            end
        end
    elseif sorting == "custom" then
        ARTISAN_SKILLS[tab][sorting][0] = ARTISAN_SKILLS[tab][sorting][0] or { name = "All", type = "header", exp = 1, childs = {} }
        ARTISAN_SKILLS[tab][sorting][0].exp = 1
        wipe(ARTISAN_SKILLS[tab][sorting][0].childs)
        ARTISAN_CUSTOM[tab] = ARTISAN_CUSTOM[tab] or {}
        -- copy custom categories into main table
        for i = 1, getn(ARTISAN_CUSTOM[tab]) do
            tinsert(ARTISAN_SKILLS[tab][sorting], ARTISAN_CUSTOM[tab][i])
        end
        -- make "Uncategorized" category if possible
        if not ARTISAN_UNCATEGORIZED[tab] then
            ArtisanEditor_OnShow()
        end
        if next(ARTISAN_UNCATEGORIZED[tab]) then
            local isExpanded = not collapsedHeaders[tab][sorting]["Uncategorized"] and 1 or nil
            tinsert(ARTISAN_SKILLS[tab][sorting], { name = "Uncategorized", type = "header", exp = isExpanded, childs = {} })
            local uncatHeaderIndex = getn(ARTISAN_SKILLS[tab][sorting])
            for i = 1, getn(ARTISAN_UNCATEGORIZED[tab]) do
                if isExpanded then
                    tinsert(ARTISAN_SKILLS[tab][sorting], ARTISAN_UNCATEGORIZED[tab][i])
                end
                tinsert(ARTISAN_SKILLS[tab][sorting][uncatHeaderIndex].childs, ARTISAN_UNCATEGORIZED[tab][i].name)
            end
            numHeaders = numHeaders + 1
        end
        -- set headers expanded state
        for i = 1, getn(ARTISAN_SKILLS[tab][sorting]) do
            if ARTISAN_SKILLS[tab][sorting][i].type == "header" then
                numHeaders = numHeaders + 1
                tinsert(ARTISAN_SKILLS[tab][sorting][0].childs, ARTISAN_SKILLS[tab][sorting][i].name)
                ARTISAN_SKILLS[tab][sorting][i].exp = not collapsedHeaders[tab][sorting][ARTISAN_SKILLS[tab][sorting][i].name] and 1 or nil
            end
        end
        -- remove skills that belong to collapsed headers
        for _, v in pairs(ARTISAN_SKILLS[tab][sorting]) do
            if v.type == "header" and not v.exp then
                for _, v2 in pairs(v.childs) do
                    for k3, v3 in pairs(ARTISAN_SKILLS[tab][sorting]) do
                        if v3.name == v2 then
                            tremove(ARTISAN_SKILLS[tab][sorting], k3)
                        end
                    end
                end
            end
        end
        -- update atributes
        for i = 1, getn(ARTISAN_SKILLS[tab][sorting]) do
            if ARTISAN_SKILLS[tab][sorting].type ~= "header" then
                for id = 1, C_GetNumCrafts() do
                    local craftName, craftType, numAvailable, isExpanded, craftSubSpellName, trainingPointCost, requiredLevel = C_GetCraftInfo(id)
                    if craftType ~= "header" then
                        if craftSubSpellName and craftSubSpellName ~= "" then
                            craftName = craftName.."  "..format(PARENS_TEMPLATE, craftSubSpellName)
                        end
                        if craftName == ARTISAN_SKILLS[tab][sorting][i].name then
                            ARTISAN_SKILLS[tab][sorting][i].id = id
                            ARTISAN_SKILLS[tab][sorting][i].name = craftName
                            ARTISAN_SKILLS[tab][sorting][i].type = craftType
                            ARTISAN_SKILLS[tab][sorting][i].num = numAvailable
                            ARTISAN_SKILLS[tab][sorting][i].sub = craftSubSpellName
                            ARTISAN_SKILLS[tab][sorting][i].tp = trainingPointCost
                            ARTISAN_SKILLS[tab][sorting][i].lvl = requiredLevel
                            break
                        end
                    end
                end
            end
        end
    end

    return numHeaders
end

function ArtisanFrame_Update()
    local tab = ArtisanFrame.selectedTabName
    if not tab then
        return
    end

	local craftOffset = FauxScrollFrame_GetOffset(ArtisanListScrollFrame)
    local numCrafts = Artisan_GetNumCrafts()
    local name, rank, maxRank = Artisan_GetCraftSkillLine()
    local headers = 0

    headers = Artisan_UpdateSkillList()
    if ArtisanFrame.craft then
        ArtisanFrameBottomLeftTex:SetTexture("Interface\\AddOns\\Artisan\\Textures\\BottomLeft2")
        ArtisanFrameCreateButton:SetText(_G[GetCraftButtonToken()])
        ArtisanFrameCreateAllButton:Hide()
        ArtisanFrameDecrementButton:Hide()
        ArtisanFrameInputBox:Hide()
        ArtisanFrameIncrementButton:Hide()
    else
        ArtisanFrameBottomLeftTex:SetTexture("Interface\\AddOns\\Artisan\\Textures\\BottomLeft")
        ArtisanFrameCreateButton:SetText(CREATE)
        ArtisanFrameCreateAllButton:Show()
        ArtisanFrameDecrementButton:Show()
        ArtisanFrameInputBox:Show()
        ArtisanFrameIncrementButton:Show()
    end
    -- Setup status bar
    ArtisanRankFrameSkillName:SetText(tab)
    if name then
        ArtisanRankFrame:Show()
        ArtisanRankFrame:SetMinMaxValues(0, maxRank)
		ArtisanRankFrame:SetValue(rank)
		ArtisanRankFrameSkillRank:SetText(rank.."/"..maxRank)
        ArtisanFrameTitleText:Hide()
    else -- Beast Training / Disguise
        ArtisanFrameTitleText:SetText(GetCraftName())
        ArtisanFrameTitleText:Show()
        ArtisanRankFrame:Hide()
    end

	if (numCrafts - headers < 0) then
		ArtisanSkillName:Hide()
        ArtisanSkillIcon:Hide()
		ArtisanRequirementLabel:Hide()
		ArtisanRequirementText:SetText("")
        ArtisanCraftDescription:SetText("")
        ArtisanCraftCost:SetText("")
		for i = 1, maxCraftReagents do
			_G["ArtisanReagent"..i]:Hide()
		end
	else
		ArtisanSkillName:Show()
		ArtisanSkillIcon:Show()
        if ArtisanFrameSearchBox:GetText() ~= "" or ARTISAN_CONFIG.reagents[tab] then
		    ArtisanCollapseAllButton:Disable()
        elseif ArtisanFrameSearchBox:GetText() == "" and not ARTISAN_CONFIG.reagents[tab] then
            ArtisanCollapseAllButton:Enable()
        end
        if tab == "Beast Training" and ARTISAN_CONFIG.sorting[tab] == "default" then
            ArtisanCollapseAllButton:Disable()
            ARTISAN_CONFIG.reagents[tab] = false
            ArtisanHaveReagents:Hide()
        elseif tab ~= "Beast Training" then
            ArtisanHaveReagents:Show()
        end
	end

    -- If player has training points show them here
    Artisan_UpdateTrainingPoints()
    ArtisanHighlightFrame:Hide()

    local results = getn(searchResults)
    local craftsToUpdate = results == 0 and numCrafts or results
    FauxScrollFrame_Update(ArtisanListScrollFrame, craftsToUpdate, craftsDisplayed, craftSkillHeight, nil, nil, nil, ArtisanHighlightFrame, 293, 316 )

    for i=1, craftsDisplayed, 1 do
        local craftIndex = 0
        if ArtisanFrameSearchBox:GetText() ~= "" or ARTISAN_CONFIG.reagents[tab] then
            if results > 0 then
                if searchResults[i + craftOffset] then
                    craftIndex = searchResults[i + craftOffset]
                end
            else
                craftIndex = -1
            end
        else
            craftIndex = i + craftOffset
        end

        local craftName, craftType, numAvailable, isExpanded, craftSubSpellName, trainingPointCost = Artisan_GetCraftInfo(craftIndex)
        local craftButton = _G["ArtisanFrameSkill"..i]
        local craftButtonSubText = _G["ArtisanFrameSkill"..i.."SubText"]
        local craftButtonCost = _G["ArtisanFrameSkill"..i.."Cost"]
        local craftButtonIcon = _G["ArtisanFrameSkill"..i.."Icon"]
        local indent = " "
        if ARTISAN_CONFIG.icons then
            indent = "   "
        end
        craftButtonCost:SetText("")

        if ( craftIndex > 0 and craftIndex <= numCrafts ) then
            -- Set button widths if scrollbar is shown or hidden
            if ( ArtisanListScrollFrame:IsShown() ) then
                craftButton:SetWidth(293)
            else
                craftButton:SetWidth(323)
            end
            local color = TypeColor[craftType]
            if color then
                craftButton:SetTextColor(color.r, color.g, color.b)
                craftButton.r = color.r
                craftButton.g = color.g
                craftButton.b = color.b
                craftButtonCost:SetTextColor(color.r, color.g, color.b)
                craftButtonSubText:SetTextColor(color.r, color.g, color.b)
            end
            craftButton:SetID(craftIndex)
            craftButton.type = craftType
            craftButton:Show()
            -- Handle headers
            if ( craftType == "header" ) then
                craftButton:SetText(craftName)
                craftButtonSubText:SetText("")
                if ( isExpanded == 1 ) then
                    craftButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
                else
                    craftButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
                end
                _G["ArtisanFrameSkill"..i.."Highlight"]:SetTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
                craftButton:UnlockHighlight()
                craftButtonIcon:SetTexture("")
            else
                craftButton:SetNormalTexture("")
                if ARTISAN_CONFIG.icons then
                    craftButtonIcon:SetTexture(Artisan_GetCraftIcon(craftIndex))
                else
                    craftButtonIcon:SetTexture("")
                end
                _G["ArtisanFrameSkill"..i.."Highlight"]:SetTexture("")
                if craftName then
                    -- remove (Rank) from name
                    craftName = gsub(craftName, "  %(Rank %d+%)", "")
                    if ( numAvailable == 0 ) then
                        craftButton:SetText(indent..craftName)
                    else
                        craftButton:SetText(indent..craftName.." ["..numAvailable.."]")
                    end
                end
                -- (Rank)
                if ( craftSubSpellName and craftSubSpellName ~= "" ) then
                    craftButtonSubText:SetText(format(PARENS_TEMPLATE, craftSubSpellName))
                else
                    craftButtonSubText:SetText("")
                end
                -- TP
                craftButtonCost:SetText("")
                if tab == "Beast Training" and UnitName("pet") then
                    if ( trainingPointCost and trainingPointCost > 0 ) then
                        craftButtonCost:SetText(format(TRAINER_LIST_TP, trainingPointCost))
                    else
                        craftButtonCost:SetText("")
                    end
                end
                craftButtonSubText:SetPoint("LEFT", "ArtisanFrameSkill"..i.."Text", "RIGHT", 10, 0)
                -- Place the highlight and lock the highlight state
                if (ArtisanFrame.selectedSkill == craftIndex) then
                    ArtisanHighlightFrame:SetPoint("TOPLEFT", "ArtisanFrameSkill"..i, "TOPLEFT", 0, 0)
                    ArtisanHighlightFrame:Show()
                    craftButtonSubText:SetTextColor(1.0, 1.0, 1.0)
                    craftButtonCost:SetTextColor(1.0, 1.0, 1.0)
                    craftButton:LockHighlight()
                else
                    craftButton:UnlockHighlight()
                end
                if MouseIsOver(craftButton) then
                    craftButtonSubText:SetTextColor(1.0, 1.0, 1.0)
                    craftButtonCost:SetTextColor(1.0, 1.0, 1.0)
                end
            end
        else
            craftButton:Hide()
        end
    end
    -- Set the expand/collapse all button texture
    local numHeaders = 0
    local notExpanded = 0
    for i = 1, numCrafts, 1 do
        local craftName, craftType, numAvailable, isExpanded = Artisan_GetCraftInfo(i)
        if ( craftName and craftType == "header" ) then
            numHeaders = numHeaders + 1
            if ( not isExpanded or isExpanded == 0) then
                notExpanded = notExpanded + 1
            end
        end
        if ( ArtisanFrame.selectedSkill and ArtisanFrame.selectedSkill == i ) then
            -- Set the max makeable items for the create all button
            ArtisanFrame.numAvailable = numAvailable
        end
    end
    -- If all headers are not expanded then show collapse button, otherwise show the expand button
    if ( notExpanded ~= numHeaders ) then
        ArtisanCollapseAllButton.collapsed = nil
        ArtisanCollapseAllButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
    else
        ArtisanCollapseAllButton.collapsed = 1
        ArtisanCollapseAllButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
    end
end

function Artisan_SetSelection(id)
    if not ArtisanFrame.selectedTabName then
        return
    end
    
    if ArtisanFrameSearchBox:GetText() ~= "" and getn(searchResults) == 0 then
        return
    end

    ArtisanHighlightFrame:Show()

    local craftName, craftType, numAvailable, isExpanded, craftSubSpellName, trainingPointCost, requiredLevel = Artisan_GetCraftInfo(id)
    -- If the type of the selection is header, don't process all the craft details
    if ( craftType == "header" ) then
        ArtisanHighlightFrame:Hide()
        if (getn(searchResults) == 0) then
            if ( isExpanded and isExpanded == 1 ) then
                Artisan_CollapseCraftSkillLine(id)
            else
                Artisan_ExpandCraftSkillLine(id)
            end
        end
        return
    end

    ArtisanFrame.selectedSkill = id
    Artisan_SelectCraft(id)

    if ( id > Artisan_GetNumCrafts() ) then
        return
    end

    local color = TypeColor[craftType]
    if color then
        ArtisanHighlightTexture:SetVertexColor(color.r, color.g, color.b)
    end
    craftName = gsub(craftName or "", "  %(Rank %d+%)", "")
    ArtisanSkillName:SetText(craftName)
    ArtisanSkillIcon:SetNormalTexture(Artisan_GetCraftIcon(id))
    ArtisanSkillCooldown:SetText("")
    ArtisanSkillIconCount:SetText("")
    ArtisanCraftCost:Hide()
    ArtisanCraftDescription:Hide()
    -- Cooldown
    if GetTradeSkillCooldown(GetTradeSkillSelectionIndex()) and not ArtisanFrame.craft then
        ArtisanSkillCooldown:SetText(COOLDOWN_REMAINING.." "..SecondsToTime(GetTradeSkillCooldown(GetTradeSkillSelectionIndex())))
    else
        ArtisanSkillCooldown:SetText("")
    end
    -- Description text
    if ( Artisan_GetCraftDescription(id) and ArtisanFrame.selectedTabName == "Beast Training") then
        ArtisanCraftDescription:Show()
        ArtisanCraftDescription:SetText(Artisan_GetCraftDescription(id))
        ArtisanReagentLabel:Hide()
    else
        ArtisanReagentLabel:Show()
        ArtisanCraftDescription:Hide()
    end
    if not ArtisanFrame.craft then
        -- Amount made
        local minMade, maxMade = GetTradeSkillNumMade(GetTradeSkillSelectionIndex())
        if maxMade > 1 then
            if minMade == maxMade then
                ArtisanSkillIconCount:SetText(minMade)
            else
                ArtisanSkillIconCount:SetText(minMade.."-"..maxMade)
            end
            if ArtisanSkillIconCount:GetWidth() > 39 then
                ArtisanSkillIconCount:SetText("~"..floor((minMade + maxMade)/2))
            end
        else
            ArtisanSkillIconCount:SetText("")
        end
    end
    -- Reagents
    local creatable = 1
    local numReagents = Artisan_GetCraftNumReagents(id)
    for i=1, numReagents, 1 do
        local reagentName, reagentTexture, reagentCount, playerReagentCount = Artisan_GetCraftReagentInfo(id, i)
        local reagent = _G["ArtisanReagent"..i]
        local name = _G["ArtisanReagent"..i.."Name"]
        local count = _G["ArtisanReagent"..i.."Count"]
        if ( not reagentName or not reagentTexture ) then
            reagent:Hide()
        else
            reagent:Show()
            SetItemButtonTexture(reagent, reagentTexture)
            name:SetText(reagentName)
            -- Grayout items
            if ( playerReagentCount < reagentCount ) then
                SetItemButtonTextureVertexColor(reagent, 0.5, 0.5, 0.5)
                name:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
                creatable = nil
            else
                SetItemButtonTextureVertexColor(reagent, 1.0, 1.0, 1.0)
                name:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
            end
            if ( playerReagentCount >= 100 ) then
                playerReagentCount = "*"
            end
            count:SetText(playerReagentCount.." /"..reagentCount)
        end
    end

    for i=numReagents + 1, maxCraftReagents, 1 do
        _G["ArtisanReagent"..i]:Hide()
    end

    local tools = BuildColoredListString(Artisan_GetCraftTools(id))
    if ( tools ) then
        ArtisanRequirementLabel:Show()
        ArtisanRequirementText:SetText(tools)
    elseif ( requiredLevel and requiredLevel > 0 ) then
        if ( UnitLevel("pet") >= requiredLevel ) then
            ArtisanRequirementLabel:Show()
            ArtisanRequirementText:SetText(format(TRAINER_PET_LEVEL, requiredLevel))
        else
            ArtisanRequirementLabel:Show()
            ArtisanRequirementText:SetText(format(TRAINER_PET_LEVEL_RED, requiredLevel))
        end
    else
        ArtisanRequirementLabel:Hide()
        ArtisanRequirementText:SetText("")
    end

    if ( trainingPointCost and trainingPointCost > 0 ) then
        local totalPoints, spent = GetPetTrainingPoints()
        local usablePoints = totalPoints - spent
        if ( usablePoints >= trainingPointCost ) then
            ArtisanCraftCost:SetText(COSTS_LABEL.." "..trainingPointCost.." "..TRAINING_POINTS_LABEL)
        else
            ArtisanCraftCost:SetText(COSTS_LABEL.." "..RED_FONT_COLOR_CODE..trainingPointCost..FONT_COLOR_CODE_CLOSE.." "..TRAINING_POINTS_LABEL)
        end
        ArtisanCraftCost:Show()
    else
        ArtisanCraftCost:Hide()
    end

    if ( craftType == "used" ) then
        creatable = nil
    end

    if ( creatable ) then
        ArtisanFrameCreateButton:Enable()
        ArtisanFrameCreateAllButton:Enable()
    else
        ArtisanFrameCreateButton:Disable()
        ArtisanFrameCreateAllButton:Disable()
    end

    Artisan_UpdateDetailScrollFrame(numReagents)
    -- if using aux addon, setup total reagent cost
    if aux_frame then
        local aux = require("aux")
        local info = require("aux.util.info")
        local money = require("aux.util.money")
        local history = require("aux.core.history")
        local total_cost = 0
        local function cost_label(cost)
            local label = LIGHTYELLOW_FONT_COLOR_CODE .. '(Total Cost: ' .. FONT_COLOR_CODE_CLOSE
            label = label .. (cost and money.to_string2(cost, nil, LIGHTYELLOW_FONT_COLOR_CODE) or GRAY_FONT_COLOR_CODE .. '?' .. FONT_COLOR_CODE_CLOSE)
            label = label .. LIGHTYELLOW_FONT_COLOR_CODE .. ')' .. FONT_COLOR_CODE_CLOSE
            return label
        end
        for i = 1, numReagents do
            local link = Artisan_GetReagentItemLink(id, i)
            if not link then
                total_cost = nil
                break
            end
            local item_id, suffix_id = info.parse_link(link)
            local count = aux.select(3, Artisan_GetCraftReagentInfo(id, i))
            local _, price, limited = info.merchant_info(item_id)
            local value = price and not limited and price or history.value(item_id .. ':' .. suffix_id)
            if not value then
                total_cost = nil
                break
            else
                total_cost = total_cost + value * count
            end
        end
        ArtisanReagentLabel:SetText(SPELL_REAGENTS .. ' ' .. cost_label(total_cost))
    end
end

function Artisan_UpdateTrainingPoints()
    local totalPoints, spent = GetPetTrainingPoints()
	if totalPoints > 0 and ArtisanFrame.selectedTabName == "Beast Training" then
		ArtisanFramePointsLabel:Show()
		ArtisanFramePointsText:Show()
		ArtisanFramePointsText:SetText(totalPoints - spent)
	else
		ArtisanFramePointsLabel:Hide()
		ArtisanFramePointsText:Hide()
	end
end

function Artisan_UpdateDetailScrollFrame(numReagents)
    if numReagents > 4 then
        ArtisanDetailScrollFrame:SetAlpha(1)
        ArtisanDetailScrollChildFrame:SetAlpha(1)
        ArtisanDetailScrollFrame:SetScript("OnMouseWheel", ArtisanFrame.originalScroll)
        ArtisanDetailScrollFrameScrollBar:EnableMouse(1)
        ArtisanDetailScrollFrameScrollBar:Show()
        ArtisanDetailScrollFrame:UpdateScrollChildRect()
    else
        ArtisanDetailScrollFrame:SetAlpha(0)
        ArtisanDetailScrollChildFrame:SetAlpha(1)
        ArtisanDetailScrollFrame:SetScript("OnMouseWheel", nil)
        ArtisanDetailScrollFrameScrollBar:EnableMouse(nil)
        ArtisanDetailScrollFrameScrollBar:Hide()
    end
end

function ArtisanCollapseAllButton_OnClick()
	if (this.collapsed) then
		this.collapsed = nil
        ArtisanListScrollFrameScrollBar:SetValue(0)
        Artisan_ExpandCraftSkillLine(0)
	else
		this.collapsed = 1
		ArtisanListScrollFrameScrollBar:SetValue(0)
        Artisan_CollapseCraftSkillLine(0)
	end
    ArtisanFrameSearchBox:ClearFocus()
end

function ArtisanSkillButton_OnClick(button)
    if button == "LeftButton" then
        if IsShiftKeyDown() then
            local tab = ArtisanFrame.selectedTabName
            local sorting = ARTISAN_CONFIG.sorting[tab]
            local craftIndex = this:GetID()
            local channel, chatNumber

            if not this.type or this.type == "header" or this.type == "none" or this.type == "used" then
                return
            end

            if WIM_EditBoxInFocus then
                channel = "WHISPER"
                chatNumber = WIM_EditBoxInFocus:GetParent().theUser
            else
                channel = ChatFrameEditBox.chatType
                if channel == "WHISPER" then
                    chatNumber = ChatFrameEditBox.tellTarget
                elseif channel == "CHANNEL" then
                    chatNumber = ChatFrameEditBox.channelTarget
                end
            end

            local numMade = ""
            if not ArtisanFrame.craft then
                local selection = craftIndex
                if sorting == "custom" then
                    selection = ARTISAN_SKILLS[tab][sorting][craftIndex].id
                end
                local minMade, maxMade = GetTradeSkillNumMade(selection)
                if maxMade ~= minMade then
                    numMade = minMade.."-"..maxMade.."x"
                elseif minMade ~= 1 then
                    numMade = minMade.."x"
                end
            end

            local itemLink = Artisan_GetItemLink(craftIndex)
            local linksCount = 0
            local msg = ""

            SendChatMessage(numMade..itemLink.." reagents:", channel, nil, chatNumber)
            for reagentIndex = 1, Artisan_GetCraftNumReagents(craftIndex) do
                local _, _, reagentsNeeded = Artisan_GetCraftReagentInfo(craftIndex, reagentIndex)
                local reagentLink = Artisan_GetReagentItemLink(craftIndex, reagentIndex)
        
                msg = msg..reagentsNeeded.."x"..reagentLink.." "
                linksCount = linksCount + 1
                if linksCount == 4 then
                    SendChatMessage(msg, channel, nil, chatNumber)
                    msg = ""
                    linksCount = 0
                end
            end
            if linksCount > 0 then
                SendChatMessage(msg, channel, nil, chatNumber)
            end
        else
            ArtisanDetailScrollFrame:SetVerticalScroll(0)
            Artisan_SetSelection(this:GetID())
            ArtisanFrame_Search()
        end
	end
    ArtisanFrameSearchBox:ClearFocus()
end

function ArtisanSideTab_OnCLick()
    if this.name == ArtisanFrame.selectedTabName then
        this:SetChecked(1)
        return
    end

    if this.name ~= ArtisanFrame.selectedTabName then
        ArtisanFrame.craft = this.name == "Enchanting" or this.name == "Beast Training" or this.name == "Disguise"
        ArtisanFrame.selectedTabName = this.name
        Artisan_UpdateSkillList()
        ArtisanFrame.selectedSkill = Artisan_GetFirstCraft()
        CastSpellByName(this.name)
        Artisan_SetSelection(Artisan_GetFirstCraft())
    end

    for i = 1, maxTabs do
        local tab = _G["ArtisanFrameSideTab"..i]
        if this:GetID() == i then
            tab:SetChecked(1)
        else
            tab:SetChecked(nil)
        end
    end

    if ArtisanEditor:IsShown() then
        if ARTISAN_CONFIG.sorting[ArtisanFrame.selectedTabName] == "custom" then
            ArtisanEditor:Hide()
            ArtisanEditor:Show()
            ArtisanEditor_Search()
            ArtisanEditorRight_Update()
        else
            ArtisanEditor:Hide()
        end
    end

    ArtisanListScrollFrame:SetVerticalScroll(0)
    ArtisanDetailScrollFrame:SetVerticalScroll(0)
    PlaySound("igCharacterInfoTab")
    ArtisanFrame_Search()
end

function ArtisanFrameIncrementButton_OnClick()
	if ( ArtisanFrameInputBox:GetNumber() < 100 ) then
		ArtisanFrameInputBox:SetNumber(ArtisanFrameInputBox:GetNumber() + 1)
	end
    ArtisanFrameSearchBox:ClearFocus()
end

function ArtisanFrameDecrementButton_OnClick()
	if ( ArtisanFrameInputBox:GetNumber() > 0 ) then
		ArtisanFrameInputBox:SetNumber(ArtisanFrameInputBox:GetNumber() - 1)
	end
    ArtisanFrameSearchBox:ClearFocus()
end

function Artisan_ItemOnClick(link)
    if not link then
        return
    end
	if arg1 and arg1 == "RightButton" then
		if aux_frame and aux_frame:IsShown() then
			local _, _, id = string.find(link, "item:(%d+)")
			local ref
			if not id then
				_, _, id = string.find(link, "enchant:(%d+)")
				ref = string.format("enchant:%d", tonumber(id or 0))
			else
				ref = string.format("item:%d", tonumber(id or 0))
			end
			SetItemRef(ref, "", "RightButton")
		elseif CanSendAuctionQuery() and BrowseName then
			BrowseName:SetText(link)
			AuctionFrameBrowse_Search()
			BrowseNoResultsText:SetText(BROWSE_NO_RESULTS)
		end
	elseif IsControlKeyDown() then
		DressUpItemLink(link)
	elseif IsShiftKeyDown() then
		if WIM_EditBoxInFocus then
			WIM_EditBoxInFocus:Insert(link)
		elseif ChatFrameEditBox:IsShown() then
			ChatFrameEditBox:Insert(link)
        end
    end
end

function Artisan_GetCraftInfo(index)
    local tab = ArtisanFrame.selectedTabName
    local sorting = ARTISAN_CONFIG.sorting[tab]
    if not tab then
        return
    end

    if not ArtisanFrame.craft and sorting == "default" then
        return GetTradeSkillInfo(index)
    end

    local craftName = ""
    local craftType = ""
    local numAvailable = 0
    local isExpanded = nil
    local craftSubSpellName = ""
    local trainingPointCost = 0
    local requiredLevel = 0

    if ARTISAN_SKILLS[tab][sorting][index] then
        craftName = ARTISAN_SKILLS[tab][sorting][index].name or ""
        craftType = ARTISAN_SKILLS[tab][sorting][index].type or ""
        numAvailable = ARTISAN_SKILLS[tab][sorting][index].num or 0
        isExpanded = ARTISAN_SKILLS[tab][sorting][index].exp or nil
        craftSubSpellName = ARTISAN_SKILLS[tab][sorting][index].sub or ""
        trainingPointCost = ARTISAN_SKILLS[tab][sorting][index].tp or 0
        requiredLevel = ARTISAN_SKILLS[tab][sorting][index].lvl or 0
    end

    return craftName, craftType, numAvailable, isExpanded, craftSubSpellName, trainingPointCost, requiredLevel
end

function Artisan_GetCraftSkillLine()
    if not ArtisanFrame.craft then
        return GetTradeSkillLine()
    end

    return GetCraftDisplaySkillLine()
end

function Artisan_CollapseCraftSkillLine(id)
    local tab = ArtisanFrame.selectedTabName
    local sorting = ARTISAN_CONFIG.sorting[tab]

    if not ArtisanFrame.craft and sorting == "default" then
        CollapseTradeSkillSubClass(id)
        ArtisanFrame_Search()
        return
    end

    collapsedHeaders[tab] = collapsedHeaders[tab] or {}
    collapsedHeaders[tab][sorting] = collapsedHeaders[tab][sorting] or {}

    if ARTISAN_SKILLS[tab][sorting][id].type ~= "header" then
        return
    end

    if id == 0 then
        ArtisanFrame.selectedSkill = 0
        -- collapse all
        for i = 0, getn(ARTISAN_SKILLS[tab][sorting]) do
            if ARTISAN_SKILLS[tab][sorting][i].type == "header" and not collapsedHeaders[tab][sorting][ARTISAN_SKILLS[tab][sorting][i].name] then
                collapsedHeaders[tab][sorting][ARTISAN_SKILLS[tab][sorting][i].name] = true
            end
        end
        Artisan_UpdateSkillList()
    else
        -- collapse only 1
        local headerName = ARTISAN_SKILLS[tab][sorting][id].name
        if not collapsedHeaders[tab][sorting][headerName]then
            collapsedHeaders[tab][sorting][headerName] = true
        end
        local skill = ArtisanFrame.selectedSkill
        local skillName = Artisan_GetCraftInfo(ArtisanFrame.selectedSkill)
        local offset = getn(ARTISAN_SKILLS[tab][sorting][id].childs) or 0
        Artisan_UpdateSkillList()
        local first = Artisan_GetFirstCraft()
        if first == 0 then
            skill = 0
        elseif id < ArtisanFrame.selectedSkill then
            skill = ArtisanFrame.selectedSkill - offset
            if first > skill or listContains(ARTISAN_SKILLS[tab][sorting][id].childs, nil, skillName) then
                skill = first
            end
        end
        Artisan_SetSelection(skill)
    end
    ArtisanFrame_Search()
end

function Artisan_ExpandCraftSkillLine(id)
    local tab = ArtisanFrame.selectedTabName
    local sorting = ARTISAN_CONFIG.sorting[tab]

    if not ArtisanFrame.craft and sorting == "default" then
        ExpandTradeSkillSubClass(id)
        ArtisanFrame_Search()
        return
    end

	if not ARTISAN_SKILLS[tab][sorting][id].childs then
		return
	end

    local headerName = ARTISAN_SKILLS[tab][sorting][id].name
    local offset = getn(ARTISAN_SKILLS[tab][sorting][id].childs) or 0

    if ARTISAN_SKILLS[tab][sorting][id].type ~= "header" then
        return
    end

    if id == 0 then
        -- expand all
        for i = 1, getn(ARTISAN_SKILLS[tab][sorting]) do
            if ARTISAN_SKILLS[tab][sorting][i].type == "header" then
                headerName = ARTISAN_SKILLS[tab][sorting][i].name
                if collapsedHeaders[tab] and collapsedHeaders[tab][sorting] then
                    collapsedHeaders[tab][sorting][headerName] = nil
                end
            end
        end
        Artisan_UpdateSkillList()
        Artisan_SetSelection(Artisan_GetFirstCraft())
    else
        -- expand 1
        if collapsedHeaders[tab][sorting][headerName] then
            collapsedHeaders[tab][sorting][headerName] = nil
        end
        Artisan_UpdateSkillList()
        if id > ArtisanFrame.selectedSkill then
            if ArtisanFrame.selectedSkill ~= 0 then
                Artisan_SetSelection(ArtisanFrame.selectedSkill)
            else
                Artisan_SetSelection(Artisan_GetFirstCraft())
            end
        else
            Artisan_SetSelection(ArtisanFrame.selectedSkill + offset)
        end
    end
    ArtisanFrame_Search()
end

function Artisan_GetItemLink(index)
    local tab = ArtisanFrame.selectedTabName
    local sorting = ARTISAN_CONFIG.sorting[tab]
	if ArtisanFrame.craft then
        local originalID = ARTISAN_SKILLS[tab][sorting][index] and ARTISAN_SKILLS[tab][sorting][index].id or 0
		return GetCraftItemLink(originalID)
	else
        if sorting ~= "custom" then
		    return GetTradeSkillItemLink(index)
        else
            local originalID = ARTISAN_SKILLS[tab][sorting][index] and ARTISAN_SKILLS[tab][sorting][index].id or 0
            return GetTradeSkillItemLink(originalID)
        end
	end
end

function Artisan_GetReagentItemLink(craftIndex, reagentIndex)
    local tab = ArtisanFrame.selectedTabName
    local sorting = ARTISAN_CONFIG.sorting[tab]
    if ArtisanFrame.craft then
        local originalIndex = ARTISAN_SKILLS[tab][sorting][craftIndex] and ARTISAN_SKILLS[tab][sorting][craftIndex].id or 0
        return GetCraftReagentItemLink(originalIndex, reagentIndex)
    else
        if sorting ~= "custom" then
            return GetTradeSkillReagentItemLink(craftIndex, reagentIndex)
        else
            local originalIndex = ARTISAN_SKILLS[tab][sorting][craftIndex] and ARTISAN_SKILLS[tab][sorting][craftIndex].id or 0
            return GetTradeSkillReagentItemLink(originalIndex, reagentIndex)
        end
    end
end

function Artisan_GetFirstCraft()
    local tab = ArtisanFrame.selectedTabName
    local sorting = ARTISAN_CONFIG.sorting[tab]

    if not tab then
        return
    end

    if not ArtisanFrame.craft and sorting == "default" then
        return GetFirstTradeSkill()
    end

    if tab == "Beast Training" or tab == "Disguise" then
        if sorting == "default" then
            return 1
        end
    end

    ARTISAN_SKILLS[tab] = ARTISAN_SKILLS[tab] or {}
    ARTISAN_SKILLS[tab][sorting] = ARTISAN_SKILLS[tab][sorting] or {}

    for k = 1, getn(ARTISAN_SKILLS[tab][sorting]) do
        if ARTISAN_SKILLS[tab][sorting][k].type == "header" and ARTISAN_SKILLS[tab][sorting][k].exp == 1 then
            return k + 1
        end
    end

    return 0
end

function Artisan_DoCraft(numAvailable)
    local tab = ArtisanFrame.selectedTabName
    local sorting = ARTISAN_CONFIG.sorting[tab]
    local skill = ArtisanFrame.selectedSkill
    if ArtisanFrame.craft then
        local originalID = ARTISAN_SKILLS[tab][sorting][skill] and ARTISAN_SKILLS[tab][sorting][skill].id or 0
        DoCraft(originalID)
    else
        local amount = ArtisanFrameInputBox:GetNumber()
        if numAvailable then
            amount = numAvailable
        end
        if sorting == "custom" then
            local originalID = ARTISAN_SKILLS[tab][sorting][skill] and ARTISAN_SKILLS[tab][sorting][skill].id or 0
            DoTradeSkill(originalID, amount)
        else
            DoTradeSkill(skill, amount)
        end
    end
    ArtisanFrameInputBox:ClearFocus()
end

function Artisan_GetNumCrafts()
    local tab = ArtisanFrame.selectedTabName
    local sorting = ARTISAN_CONFIG.sorting[tab]
    if not ArtisanFrame.craft and sorting == "default" then
        return GetNumTradeSkills()
    end

    return getn(ARTISAN_SKILLS[tab][sorting])
end

function Artisan_SelectCraft(id)
    local tab = ArtisanFrame.selectedTabName
    local sorting = ARTISAN_CONFIG.sorting[tab]
    if not ArtisanFrame.craft then
        if sorting == "default" then
            return SelectTradeSkill(id)
        else
            local originalID = ARTISAN_SKILLS[tab][sorting][id] and ARTISAN_SKILLS[tab][sorting][id].id or 0
            return SelectTradeSkill(originalID)
        end
    end
    if ARTISAN_SKILLS[tab][sorting][id] then
        local originalID = ARTISAN_SKILLS[tab][sorting][id] and ARTISAN_SKILLS[tab][sorting][id].id or 0
        SelectCraft(originalID)
    end
end

function Artisan_GetCraftIcon(id)
    local tab = ArtisanFrame.selectedTabName
    local sorting = ARTISAN_CONFIG.sorting[tab]
    if not ArtisanFrame.craft then
        if sorting == "default" then
            return GetTradeSkillIcon(id)
        else
            local originalID = ARTISAN_SKILLS[tab][sorting][id] and ARTISAN_SKILLS[tab][sorting][id].id or 0
            return GetTradeSkillIcon(originalID)
        end
    end
    local originalID = ARTISAN_SKILLS[tab][sorting][id] and ARTISAN_SKILLS[tab][sorting][id].id or 0
    return GetCraftIcon(originalID)
end

function Artisan_GetCraftDescription(id)
    local tab = ArtisanFrame.selectedTabName
    local sorting = ARTISAN_CONFIG.sorting[tab]
    if not ArtisanFrame.craft then
        return nil
    end
    local originalID = ARTISAN_SKILLS[tab][sorting][id] and ARTISAN_SKILLS[tab][sorting][id].id or 0
    return GetCraftDescription(originalID)
end

function Artisan_GetCraftNumReagents(id)
    local tab = ArtisanFrame.selectedTabName
    local sorting = ARTISAN_CONFIG.sorting[tab]
    if not ArtisanFrame.craft then
        if sorting == "default" then
            return GetTradeSkillNumReagents(id)
        else
            local originalID = ARTISAN_SKILLS[tab][sorting][id] and ARTISAN_SKILLS[tab][sorting][id].id or 0
            return GetTradeSkillNumReagents(originalID)
        end
    end
    local originalID = ARTISAN_SKILLS[tab][sorting][id] and ARTISAN_SKILLS[tab][sorting][id].id or 0
    return GetCraftNumReagents(originalID)
end

function Artisan_GetCraftReagentInfo(id, i)
    local tab = ArtisanFrame.selectedTabName
    local sorting = ARTISAN_CONFIG.sorting[tab]
    if not ArtisanFrame.craft then
        if sorting == "default" then
            return GetTradeSkillReagentInfo(id, i)
        else
            local originalID = ARTISAN_SKILLS[tab][sorting][id] and ARTISAN_SKILLS[tab][sorting][id].id or 0
            return GetTradeSkillReagentInfo(originalID, i)
        end
    end
    local originalID = ARTISAN_SKILLS[tab][sorting][id] and ARTISAN_SKILLS[tab][sorting][id].id or 0
    return GetCraftReagentInfo(originalID, i)
end

function Artisan_GetCraftTools(id)
    local tab = ArtisanFrame.selectedTabName
    local sorting = ARTISAN_CONFIG.sorting[tab]
    if not ArtisanFrame.craft then
        if sorting == "default" then
            return GetTradeSkillTools(id)
        else
            local originalID = ARTISAN_SKILLS[tab][sorting][id] and ARTISAN_SKILLS[tab][sorting][id].id or 0
            return GetTradeSkillTools(originalID)
        end
    end
    local originalID = ARTISAN_SKILLS[tab][sorting][id] and ARTISAN_SKILLS[tab][sorting][id].id or 0
    return GetCraftSpellFocus(originalID)
end

function ArtisanEditButton_OnClick()
    if ArtisanEditor:IsShown() then
        ArtisanEditor:Hide()
    else
        ArtisanEditor:Show()
        Artisan_UpdateSkillList()
        ArtisanEditor_Search()
        ArtisanEditorRight_Update()
    end
end

function ArtisanSortDefault_OnClick()
    if ARTISAN_CONFIG.sorting[ArtisanFrame.selectedTabName] ~= "default" then
        ARTISAN_CONFIG.sorting[ArtisanFrame.selectedTabName] = "default"
        this:SetChecked(1)
        ArtisanSortCustom:SetChecked(nil)
        Artisan_UpdateSkillList()
        Artisan_SetSelection(Artisan_GetFirstCraft())
        ArtisanFrame_Search()
        ArtisanFrameEditButton:Hide()
        if ArtisanEditor:IsShown() then
            ArtisanEditor:Hide()
        end
    else
        this:SetChecked(1)
    end
    ArtisanDetailScrollFrame:SetVerticalScroll(0)
end

function ArtisanSortCustom_OnClick()
    if ARTISAN_CONFIG.sorting[ArtisanFrame.selectedTabName] ~= "custom" then
        ARTISAN_CONFIG.sorting[ArtisanFrame.selectedTabName] = "custom"
        this:SetChecked(1)
        ArtisanSortDefault:SetChecked(nil)
        ArtisanEditor_OnShow()
        Artisan_UpdateSkillList()
        Artisan_SetSelection(Artisan_GetFirstCraft())
        ArtisanFrame_Search()
        ArtisanFrameEditButton:Show()
    else
        this:SetChecked(1)
    end
    ArtisanDetailScrollFrame:SetVerticalScroll(0)
end

function Artisan_HaveReagents_OnClick()
    if ARTISAN_CONFIG.reagents[ArtisanFrame.selectedTabName] ~= true then
        ARTISAN_CONFIG.reagents[ArtisanFrame.selectedTabName] = true
        this:SetChecked(1)
    else
        ARTISAN_CONFIG.reagents[ArtisanFrame.selectedTabName] = false
        this:SetChecked(nil)
    end
    Artisan_UpdateSkillList()
    ArtisanFrame_Search()
end

function ArtisanEditorLeftButton_OnClick()
    if ArtisanEditor.currentHeader then
        local parentIndex = ArtisanEditor.currentHeader
        local tabName = ArtisanFrame.selectedTabName
        local name, type, num, sub, tp, lvl, id = this.name, this.type, this.num, this.sub, this.tp, this.lvl, this.id
        if this.type ~= "header" then
            tinsert(ARTISAN_CUSTOM[tabName][parentIndex].childs, 1, name)
            tinsert(ARTISAN_CUSTOM[tabName], parentIndex + 1, {name = name, type = type, num = num, sub = sub, tp = tp, lvl = lvl, id = id, parent = parentIndex})
        end
        tremove(ARTISAN_UNCATEGORIZED[tabName], this:GetID())
        -- increment parent index for skills that belong to headers below
        for _, v in pairs(ARTISAN_CUSTOM[tabName]) do
            if v.parent and v.parent > parentIndex then
                v.parent = v.parent + 1
            end
        end
        ArtisanEditor_Search()
        ArtisanEditorRight_Update()
    end
end

function ArtisanEditorRightButton_OnClick()
    if this.type == "header" then
        ArtisanEditor.currentHeader = this:GetID()
    else
        ArtisanEditor.currentHeader = this.parent
    end
    ArtisanEditorRight_Update()
end

function ArtisanRightButtonUp_OnClick()
    local thisButton = _G["ArtisanEditorSkillRight"..this:GetID()]
    local craftIndex = thisButton:GetID()
	local prevIndex = craftIndex - 1
    local tabName = ArtisanFrame.selectedTabName
    local parentIndex = ARTISAN_CUSTOM[tabName][craftIndex].parent
	local currentHeaderName
	if ArtisanEditor.currentHeader then
		currentHeaderName = ARTISAN_CUSTOM[tabName][ArtisanEditor.currentHeader].name
	end

    if (craftIndex and craftIndex > 2) then
        if thisButton.type ~= "header" then

            local temp = ARTISAN_CUSTOM[tabName][craftIndex]
            ARTISAN_CUSTOM[tabName][craftIndex] = ARTISAN_CUSTOM[tabName][prevIndex]
            ARTISAN_CUSTOM[tabName][prevIndex] = temp

            if ARTISAN_CUSTOM[tabName][craftIndex].type ~= "header" then
                ARTISAN_CUSTOM[tabName][parentIndex].childs = {}
                for i = 1, getn(ARTISAN_CUSTOM[tabName]) do
                    if ARTISAN_CUSTOM[tabName][i].parent and ARTISAN_CUSTOM[tabName][i].parent == parentIndex then
                        tinsert(ARTISAN_CUSTOM[tabName][parentIndex].childs, ARTISAN_CUSTOM[tabName][i].name)
                    end
                end
            else
                local prevParentIndex = ARTISAN_CUSTOM[tabName][craftIndex - 2].parent
                ARTISAN_CUSTOM[tabName][craftIndex].parent = nil
                ARTISAN_CUSTOM[tabName][prevIndex].parent = prevParentIndex
                for i = 1, getn(ARTISAN_CUSTOM[tabName]) do
                    if ARTISAN_CUSTOM[tabName][i].parent then
                        if ARTISAN_CUSTOM[tabName][i].parent == prevIndex then
                            ARTISAN_CUSTOM[tabName][i].parent = craftIndex
                        end
                    end
                end

                ARTISAN_CUSTOM[tabName][craftIndex].childs = {}
                ARTISAN_CUSTOM[tabName][prevParentIndex].childs = {}
                for i = 1, getn(ARTISAN_CUSTOM[tabName]) do
                    if ARTISAN_CUSTOM[tabName][i].parent then
                        if ARTISAN_CUSTOM[tabName][i].parent == craftIndex then
                            tinsert(ARTISAN_CUSTOM[tabName][craftIndex].childs, ARTISAN_CUSTOM[tabName][i].name)
                        elseif ARTISAN_CUSTOM[tabName][i].parent == prevParentIndex then
                            tinsert(ARTISAN_CUSTOM[tabName][prevParentIndex].childs, ARTISAN_CUSTOM[tabName][i].name)
                        end
                    end
                end
            end
        else
			local headerAbove
            if ARTISAN_CUSTOM[tabName][prevIndex].type ~= "header" then
                headerAbove = ARTISAN_CUSTOM[tabName][prevIndex].parent
            else
                headerAbove = prevIndex
            end
            local offset = craftIndex + getn(ARTISAN_CUSTOM[tabName][craftIndex].childs)
            local temp = {}
            for i = offset, craftIndex, -1 do
                tinsert(temp, ARTISAN_CUSTOM[tabName][i])
                tremove(ARTISAN_CUSTOM[tabName], i)
            end
            for i = 1, getn(temp) do
                tinsert(ARTISAN_CUSTOM[tabName], headerAbove, temp[i])
            end
            local newParent = 1
            for i = 2, getn(ARTISAN_CUSTOM[tabName]) do
                if ARTISAN_CUSTOM[tabName][i].parent then
                    ARTISAN_CUSTOM[tabName][i].parent = newParent
                else
                    newParent = i
                end
            end
        end
		if currentHeaderName then
			for k, v in pairs(ARTISAN_CUSTOM[tabName]) do
				if v.name == currentHeaderName then
					ArtisanEditor.currentHeader = k
				end
			end
		end
        ArtisanEditorRight_Update()
    end
end

function ArtisanRightButtonDown_OnClick()
    local thisButton = _G["ArtisanEditorSkillRight"..this:GetID()]
    local craftIndex = thisButton:GetID()
	local nextIndex = craftIndex + 1
    local tabName = ArtisanFrame.selectedTabName
    local parentIndex = ARTISAN_CUSTOM[tabName][craftIndex].parent
    local numSkills = getn(ARTISAN_CUSTOM[tabName])
	local currentHeaderName
	if ArtisanEditor.currentHeader then
		currentHeaderName = ARTISAN_CUSTOM[tabName][ArtisanEditor.currentHeader].name
	end

    if (craftIndex and craftIndex < numSkills) then
        if thisButton.type ~= "header" then
            local temp = ARTISAN_CUSTOM[tabName][craftIndex]
            ARTISAN_CUSTOM[tabName][craftIndex] = ARTISAN_CUSTOM[tabName][nextIndex]
            ARTISAN_CUSTOM[tabName][nextIndex] = temp

            if ARTISAN_CUSTOM[tabName][craftIndex].type ~= "header" then
                ARTISAN_CUSTOM[tabName][parentIndex].childs = {}
                for i = 1, getn(ARTISAN_CUSTOM[tabName]) do
                    if ARTISAN_CUSTOM[tabName][i].parent and ARTISAN_CUSTOM[tabName][i].parent == parentIndex then
                        tinsert(ARTISAN_CUSTOM[tabName][parentIndex].childs, ARTISAN_CUSTOM[tabName][i].name)
                    end
                end
            else
                ARTISAN_CUSTOM[tabName][craftIndex].parent = nil
                ARTISAN_CUSTOM[tabName][nextIndex].parent = craftIndex
                for i = 1, getn(ARTISAN_CUSTOM[tabName]) do
                    if ARTISAN_CUSTOM[tabName][i].parent then
                        if ARTISAN_CUSTOM[tabName][i].parent == nextIndex then
                            ARTISAN_CUSTOM[tabName][i].parent = craftIndex
                        end
                    end
                end

                ARTISAN_CUSTOM[tabName][parentIndex].childs = {}
                ARTISAN_CUSTOM[tabName][craftIndex].childs = {}
                for i = 1, getn(ARTISAN_CUSTOM[tabName]) do
                    if ARTISAN_CUSTOM[tabName][i].parent then
                        if ARTISAN_CUSTOM[tabName][i].parent == parentIndex then
                            tinsert(ARTISAN_CUSTOM[tabName][parentIndex].childs, ARTISAN_CUSTOM[tabName][i].name)
                        elseif ARTISAN_CUSTOM[tabName][i].parent == craftIndex then
                            tinsert(ARTISAN_CUSTOM[tabName][craftIndex].childs, ARTISAN_CUSTOM[tabName][i].name)
                        end
                    end
                end
            end
        else
            local headerBelow
            if ARTISAN_CUSTOM[tabName][nextIndex].type ~= "header" then
                headerBelow = craftIndex + getn(ARTISAN_CUSTOM[tabName][craftIndex].childs) + 1
            else
                headerBelow = nextIndex
            end

            if not ARTISAN_CUSTOM[tabName][headerBelow] or ARTISAN_CUSTOM[tabName][headerBelow].type ~= "header" then
                return
            end

            local pos = headerBelow + getn(ARTISAN_CUSTOM[tabName][headerBelow].childs) + 1
            local x = 0
            for i = craftIndex, craftIndex + getn(ARTISAN_CUSTOM[tabName][craftIndex].childs) do
                tinsert(ARTISAN_CUSTOM[tabName], pos + x, ARTISAN_CUSTOM[tabName][i])
                x = x + 1
            end
            x = 0
            for i = craftIndex, craftIndex + getn(ARTISAN_CUSTOM[tabName][craftIndex].childs) do
                tremove(ARTISAN_CUSTOM[tabName], i - x)
                x = x + 1
            end
            local newParent = 1
            for i = 2, getn(ARTISAN_CUSTOM[tabName]) do
                if ARTISAN_CUSTOM[tabName][i].parent then
                    ARTISAN_CUSTOM[tabName][i].parent = newParent
                else
                    newParent = i
                end
            end
        end
		if currentHeaderName then
			for k, v in pairs(ARTISAN_CUSTOM[tabName]) do
				if v.name == currentHeaderName then
					ArtisanEditor.currentHeader = k
				end
			end
		end
        ArtisanEditorRight_Update()
    end
end

function ArtisanRightButtonDelete_OnClick()
    local tabName = ArtisanFrame.selectedTabName
    local button = _G["ArtisanEditorSkillRight"..this:GetID()]
    local craftIndex = button:GetID()
	local currentHeaderName
	if ArtisanEditor.currentHeader then
		currentHeaderName = ARTISAN_CUSTOM[tabName][ArtisanEditor.currentHeader].name
	end
    local name, type, num, sub, tp, lvl, id, parentIndex = button.name, button.type, button.num, button.sub, button.tp, button.lvl, button.id, button.parent
    if button.type ~= "header" then
        -- move this skill to the left table
        tinsert(ARTISAN_UNCATEGORIZED[tabName], {name = name, type = type, num = num, sub = sub, tp = tp, lvl = lvl, id = id})
        -- remove this skill from parents header childs
        for k, v in pairs(ARTISAN_CUSTOM[tabName][parentIndex].childs) do
            if v == name then
                tremove(ARTISAN_CUSTOM[tabName][parentIndex].childs, k)
            end
        end
        -- decrement parent index for skills below if they belong to other headers
        for _, v in pairs(ARTISAN_CUSTOM[tabName]) do
            if v.parent and v.parent > parentIndex then
                v.parent = v.parent - 1
            end
        end
    else
        -- if we delete header
        local offset = getn(ARTISAN_CUSTOM[tabName][craftIndex].childs)
        -- copy childs to left list
        for _, v in pairs(ARTISAN_CUSTOM[tabName][craftIndex].childs) do
            for _, v2 in pairs(ARTISAN_CUSTOM[tabName]) do
                local tbl = {name = v2.name, type = v2.type, num = v2.num, sub = v2.sub, tp = v2.tp, lvl = v2.lvl, id = v2.id}
                if v2.name == v and not listContains(ARTISAN_UNCATEGORIZED[tabName], nil, tbl) then
                    tinsert(ARTISAN_UNCATEGORIZED[tabName], tbl)
                    break
                end
            end
        end
        -- remove childs from right list
        for i = getn(ARTISAN_CUSTOM[tabName]), 1, -1  do
            if ARTISAN_CUSTOM[tabName][i].parent and ARTISAN_CUSTOM[tabName][i].parent == craftIndex then
                tremove(ARTISAN_CUSTOM[tabName], i)
            end
        end
        -- decrement parent index for skills below by the number of childs + 1
        for _, v in pairs(ARTISAN_CUSTOM[tabName]) do
            if v.parent and v.parent > craftIndex then
                v.parent = v.parent - offset - 1
            end
        end
    end
    tremove(ARTISAN_CUSTOM[tabName], craftIndex)
	if currentHeaderName then
		ArtisanEditor.currentHeader = nil
		for k, v in pairs(ARTISAN_CUSTOM[tabName]) do
			if v.name == currentHeaderName then
				ArtisanEditor.currentHeader = k
			end
		end
	end
    table.sort(ARTISAN_UNCATEGORIZED[tabName], function(a,b) return a.name < b.name end)
    ArtisanEditor_Search()
    ArtisanEditorRight_Update()
end

local listLeft = {}
local listRight = {}
function ArtisanEditorScrollFrameLeft_OnLoad()
    for i = 1, 25 do
        if not listLeft[i] then
            listLeft[i] = CreateFrame("Button", "ArtisanEditorSkillLeft"..i, ArtisanEditor, "ArtisanEditorLeftButtonTemplate")
            listLeft[i]:SetPoint("TOPLEFT", ArtisanEditor, 10 , -30 - ((i - 1) * craftSkillHeight))
        end
    end
end

function ArtisanEditorScrollFrameRight_OnLoad()
    local addhighlight = function(frame)
        frame:SetScript("OnEnter", function()
            this:GetParent():LockHighlight()
        end)
        frame:SetScript("OnLeave", function()
            this:GetParent():UnlockHighlight()
        end)
    end
    for i = 1, 25 do
        if not listRight[i] then
            listRight[i] = CreateFrame("Button", "ArtisanEditorSkillRight"..i, ArtisanEditor, "ArtisanEditorRightButtonTemplate")
            listRight[i]:SetPoint("TOPRIGHT", ArtisanEditor, -30 , -30 - ((i - 1) * craftSkillHeight))
            _G["ArtisanEditorSkillRight"..i.."Text"]:SetWidth(210)
            
            listRight[i].up = CreateFrame("Button", "ArtisanEditorRightUp"..i, ArtisanEditor, "ArtisanRightButtonUpTemplate")
            listRight[i].up:SetPoint("CENTER", "ArtisanEditorSkillRight"..i, "RIGHT", -52, 0)
            listRight[i].up:SetFrameLevel(_G["ArtisanEditorSkillRight"..i]:GetFrameLevel() + 1)
            listRight[i].up:SetID(i)
            listRight[i].up:SetParent(listRight[i])
            addhighlight(listRight[i].up)

            listRight[i].down = CreateFrame("Button", "ArtisanEditorRightDown"..i, ArtisanEditor, "ArtisanRightButtonDownTemplate")
            listRight[i].down:SetPoint("RIGHT", "ArtisanEditorRightUp"..i, "RIGHT", 16, 0)
            listRight[i].down:SetFrameLevel(_G["ArtisanEditorSkillRight"..i]:GetFrameLevel() + 1)
            listRight[i].down:SetID(i)
            listRight[i].down:SetParent(listRight[i])
            addhighlight(listRight[i].down)

            listRight[i].delete = CreateFrame("Button", "ArtisanEditorRightDelete"..i, ArtisanEditor, "ArtisanRightButtonDeleteTemplate")
            listRight[i].delete:SetPoint("RIGHT", "ArtisanEditorRightDown"..i, "RIGHT", 22, 0)
            listRight[i].delete:SetFrameLevel(_G["ArtisanEditorSkillRight"..i]:GetFrameLevel() + 1)
            listRight[i].delete:SetID(i)
            listRight[i].delete:SetParent(listRight[i])
            addhighlight(listRight[i].delete)
        end
    end
end

local function sortByName(a, b)
	return a.name < b.name
end

function ArtisanEditor_OnShow()
    local sorting = ARTISAN_CONFIG.sorting[ArtisanFrame.selectedTabName]
	local tabName = ArtisanFrame.selectedTabName
    if not ARTISAN_SKILLS[tabName][sorting] then
        return
    end

    ARTISAN_UNCATEGORIZED[tabName] = ARTISAN_UNCATEGORIZED[tabName] or {}
    ARTISAN_CUSTOM[tabName] = ARTISAN_CUSTOM[tabName] or {}

	wipe(ARTISAN_UNCATEGORIZED[tabName])

    for i = 1, C_GetNumCrafts() do
        local name, type, num, exp, sub, tp, lvl = C_GetCraftInfo(i)
        if sub and sub ~= "" then
            name = name.."  "..format(PARENS_TEMPLATE, sub)
        end
        if type ~= "header" then
            tinsert(ARTISAN_UNCATEGORIZED[tabName], {name = name, type = type, num = num, sub = sub, tp = tp, lvl = lvl, id = i})
            for k in pairs(ARTISAN_CUSTOM[tabName]) do
                if ARTISAN_CUSTOM[tabName][k].name == name then
                    tremove(ARTISAN_UNCATEGORIZED[tabName])
                    break
                end
            end
        end
    end
    table.sort(ARTISAN_UNCATEGORIZED[tabName], sortByName)
end

function ArtisanEditor_Search()
	wipe(editorSearchResults)
	local query = strlower(ArtisanEditorSearchBox:GetText())
    local tab = ArtisanFrame.selectedTabName
    query = strtrim(query)
    if query == "" then
        ArtisanEditorLeft_Update()
        return
    end

    local numSkills = getn(ARTISAN_UNCATEGORIZED[tab])

    for i = 1, numSkills do
        local skillName = ARTISAN_UNCATEGORIZED[tab][i].name

        if skillName then
            local words = strsplit(query, " ")
            local match = true
            for _, w in ipairs(words) do
                if not strfind(strlower(skillName), strlower(w), 1, true) then
                    match = false
                    break
                end
            end
            if match then
                tinsert(editorSearchResults, i)
            end
        end
    end
	ArtisanEditorLeft_Update()
end

function ArtisanEditorLeft_Update()
    local craftOffset = FauxScrollFrame_GetOffset(ArtisanEditorScrollFrameLeft) or 0
    local tabName = ArtisanFrame.selectedTabName
    local numCrafts = getn(ARTISAN_UNCATEGORIZED[tabName])
    local buttonIndex = 1
    local results = getn(editorSearchResults)
    local craftsToUpdate = results == 0 and numCrafts or results
    FauxScrollFrame_Update(ArtisanEditorScrollFrameLeft, craftsToUpdate, 25, craftSkillHeight)
    local indent = ""
    if ARTISAN_CONFIG.icons then
        indent = "   "
    end
    for i = 1, 25 do
        local craftIndex = 0
        if ArtisanEditorSearchBox:GetText() ~= "" then
            if results > 0 then
                if editorSearchResults[i + craftOffset] then
                    craftIndex = editorSearchResults[i + craftOffset]
                end
            else
                craftIndex = -1
            end
        else
            craftIndex = i + craftOffset
        end
        if craftIndex > 0 and craftIndex <= numCrafts then
            local craftName = ARTISAN_UNCATEGORIZED[tabName][craftIndex].name
            local craftType = ARTISAN_UNCATEGORIZED[tabName][craftIndex].type
            local numAvailable = ARTISAN_UNCATEGORIZED[tabName][craftIndex].num
            local craftSubSpellName = ARTISAN_UNCATEGORIZED[tabName][craftIndex].sub
            local trainingPointCost = ARTISAN_UNCATEGORIZED[tabName][craftIndex].tp
            local requiredLevel = ARTISAN_UNCATEGORIZED[tabName][craftIndex].lvl
            local originalID = ARTISAN_UNCATEGORIZED[tabName][craftIndex].id
            local craftButton = _G["ArtisanEditorSkillLeft"..buttonIndex]
            local icon = _G["ArtisanEditorSkillLeft"..buttonIndex.."Icon"]
            craftButton.name = craftName
            craftButton.type = craftType
            craftButton.num = numAvailable
            craftButton.sub = craftSubSpellName
            craftButton.tp = trainingPointCost
            craftButton.lvl = requiredLevel
            craftButton.id = originalID
            local color = TypeColor[craftType]
            if color then
                craftButton:SetTextColor(color.r, color.g, color.b)
            end
            craftButton:SetID(craftIndex)
            craftButton:SetText(indent..craftName)
            craftButton:SetNormalTexture("")
            if ARTISAN_CONFIG.icons then
                if ArtisanFrame.craft then
                    icon:SetTexture(GetCraftIcon(originalID))
                else
                    icon:SetTexture(GetTradeSkillIcon(originalID))
                end
            else
                icon:SetTexture("")
            end
            _G["ArtisanEditorSkillLeft"..buttonIndex.."Highlight"]:SetTexture("")
            craftButton:Show()
        else
            _G["ArtisanEditorSkillLeft"..i]:Hide()
        end
        buttonIndex = buttonIndex + 1
    end
    ArtisanFrame_Search()
end

function ArtisanEditorRight_Update()
    local craftOffset = FauxScrollFrame_GetOffset(ArtisanEditorScrollFrameRight) or 0
    local tabName = ArtisanFrame.selectedTabName
    local numCrafts = getn(ARTISAN_CUSTOM[tabName])
    local buttonIndex = 1
    FauxScrollFrame_Update(ArtisanEditorScrollFrameRight, numCrafts, 25, craftSkillHeight)
    local indent = ""
    if ARTISAN_CONFIG.icons then
        indent = "   "
    end
    for i = 1, 25 do
        local craftIndex = 0
        craftIndex = i + craftOffset
        if craftIndex > 0 and craftIndex <= numCrafts then
            local craftName = ARTISAN_CUSTOM[tabName][craftIndex].name
            local craftType = ARTISAN_CUSTOM[tabName][craftIndex].type
            local numAvailable = ARTISAN_CUSTOM[tabName][craftIndex].num
            local craftSubSpellName = ARTISAN_CUSTOM[tabName][craftIndex].sub
            local trainingPointCost = ARTISAN_CUSTOM[tabName][craftIndex].tp
            local requiredLevel = ARTISAN_CUSTOM[tabName][craftIndex].lvl
            local originalID = ARTISAN_CUSTOM[tabName][craftIndex].id
            local craftButton = _G["ArtisanEditorSkillRight"..buttonIndex]
            local icon = _G["ArtisanEditorSkillRight"..buttonIndex.."Icon"]
            craftButton.name = craftName
            craftButton.type = craftType
            craftButton.num = numAvailable
            craftButton.sub = craftSubSpellName
            craftButton.tp = trainingPointCost
            craftButton.lvl = requiredLevel
            craftButton.id = originalID
            craftButton.parent = ARTISAN_CUSTOM[tabName][craftIndex].parent
            local color = TypeColor[craftType]
            if color then
                craftButton:SetTextColor(color.r, color.g, color.b)
            end
            craftButton:SetID(craftIndex)
            if craftType ~= "header" then
                craftButton:SetText(indent..craftName)
                craftButton:SetNormalTexture("")
                _G["ArtisanEditorSkillRight"..buttonIndex.."Highlight"]:SetTexture("")
                if craftButton.parent and craftButton.parent == ArtisanEditor.currentHeader then
                    _G["ArtisanEditorSkillRight"..buttonIndex.."Background"]:Show()
                else
                    _G["ArtisanEditorSkillRight"..buttonIndex.."Background"]:Hide()
                end
                if ARTISAN_CONFIG.icons then
                    if ArtisanFrame.craft then
                        icon:SetTexture(GetCraftIcon(originalID))
                    else
                        icon:SetTexture(GetTradeSkillIcon(originalID))
                    end
                else
                    icon:SetTexture("")
                end
            else
                craftButton:SetText(craftName)
                icon:SetTexture("")
                if ArtisanEditor.currentHeader == craftIndex then
                    craftButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
                    _G["ArtisanEditorSkillRight"..buttonIndex.."Background"]:Show()
                else
                    craftButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
                    _G["ArtisanEditorSkillRight"..buttonIndex.."Background"]:Hide()
                end
                _G["ArtisanEditorSkillRight"..i.."Highlight"]:SetTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
            end
            craftButton:Show()
            _G["ArtisanEditorRightDelete"..i]:Show()
            _G["ArtisanEditorRightUp"..i]:Show()
            _G["ArtisanEditorRightDown"..i]:Show()
        else
            _G["ArtisanEditorSkillRight"..i]:Hide()
            _G["ArtisanEditorRightDelete"..i]:Hide()
            _G["ArtisanEditorRightUp"..i]:Hide()
            _G["ArtisanEditorRightDown"..i]:Hide()
        end
        buttonIndex = buttonIndex + 1
    end
    if not ArtisanEditor.currentHeader then
        ArtisanEditorRenameCategory:Disable()
    else
        ArtisanEditorRenameCategory:Enable()
    end
    ArtisanFrame_Search()
end

function ArtisanEditorAdd_OnClick()
    StaticPopup_Show("ARTISAN_NEW_CATEGORY")
end

function ArtisanEditorRename_OnClick()
    if ArtisanEditor.currentHeader then
        StaticPopup_Show("ARTISAN_RENAME_CATEGORY")
    end
end

StaticPopupDialogs["ARTISAN_NEW_CATEGORY"] = {
    text = "Name the new category",
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = 1,
    OnShow = function()
        _G[this:GetName().."EditBox"]:SetFocus()
        _G[this:GetName().."EditBox"]:SetText("")
        _G[this:GetName() .. "EditBox"]:SetScript("OnEnterPressed", function()
            StaticPopup1Button1:Click()
        end)
        _G[this:GetName() .. "EditBox"]:SetScript("OnEscapePressed", function()
            _G[this:GetParent():GetName() .. "EditBox"]:SetText("")
            StaticPopup1Button2:Click()
        end)
    end,
    OnAccept = function()
        ArtisanEditor_AddCategory(_G[this:GetParent():GetName() .. "EditBox"]:GetText())
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

StaticPopupDialogs["ARTISAN_RENAME_CATEGORY"] = {
    text = "Rename into:",
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = 1,
    OnShow = function()
        _G[this:GetName().."EditBox"]:SetFocus()
        _G[this:GetName().."EditBox"]:SetText("")
        _G[this:GetName() .. "EditBox"]:SetScript("OnEnterPressed", function()
            StaticPopup1Button1:Click()
        end)
        _G[this:GetName() .. "EditBox"]:SetScript("OnEscapePressed", function()
            _G[this:GetParent():GetName() .. "EditBox"]:SetText("")
            StaticPopup1Button2:Click()
        end)
    end,
    OnAccept = function()
        ArtisanEditor_RenameCategory(_G[this:GetParent():GetName() .. "EditBox"]:GetText())
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

function ArtisanEditor_AddCategory(categoryName)
    categoryName = strtrim(categoryName)
    local tabName = ArtisanFrame.selectedTabName
    if categoryName ~= "" then
        tinsert(ARTISAN_CUSTOM[tabName], {name = categoryName, type = "header", exp = 1, childs = {}})
        for k in pairs(ARTISAN_CUSTOM[tabName]) do
            if ARTISAN_CUSTOM[tabName][k].name == categoryName then
                ArtisanEditor.currentHeader = k
            end
        end
        ArtisanEditorRight_Update()
    end
end

function ArtisanEditor_RenameCategory(into)
    into = strtrim(into)
    if into ~= "" then
        ARTISAN_CUSTOM[ArtisanFrame.selectedTabName][ArtisanEditor.currentHeader].name = into
        ArtisanEditorRight_Update()
    end
end

local function status(parameter)
    local str = ""
    if parameter then
        str = "("..GREEN.."ON|r)"
    else
        str = "("..GREY.."OFF|r)"
    end
    return str
end

function Artisan_SlashCommand(msg)
    local cmd = strtrim(msg)
    cmd = strlower(cmd)
    if cmd == "auto" then
        if ARTISAN_CONFIG.auto then
            ARTISAN_CONFIG.auto = false
            ArtisanFrame:UnregisterEvent("REPLACE_ENCHANT")
            ArtisanFrame:UnregisterEvent("TRADE_REPLACE_ENCHANT")
        else
            ARTISAN_CONFIG.auto = true
            ArtisanFrame:RegisterEvent("REPLACE_ENCHANT")
            ArtisanFrame:RegisterEvent("TRADE_REPLACE_ENCHANT")
        end
        DEFAULT_CHAT_FRAME:AddMessage(BLUE.."[Artisan]|r"..WHITE.." auto confirmation is now |r"..status(ARTISAN_CONFIG.auto))
    elseif cmd == "icons" then
        if ARTISAN_CONFIG.icons then
            ARTISAN_CONFIG.icons = false
        else
            ARTISAN_CONFIG.icons = true
        end
        DEFAULT_CHAT_FRAME:AddMessage(BLUE.."[Artisan]|r"..WHITE.." skill icons is now |r"..status(ARTISAN_CONFIG.icons))
    elseif cmd == "movable" then
        HideUIPanel(ArtisanFrame)
        if ARTISAN_CONFIG.movable then
            ARTISAN_CONFIG.movable = false
            UIPanelWindows["ArtisanFrame"] = { area = "left", pushable = 4 }
            ArtisanFrame:ClearAllPoints()
            ArtisanFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
        else
            ARTISAN_CONFIG.movable = true
            UIPanelWindows["ArtisanFrame"] = nil
            local point, relativeTo, relativePoint, offsetX, offsetY = ArtisanFrame:GetPoint()
            ARTISAN_CONFIG.X = offsetX
            ARTISAN_CONFIG.Y = offsetY
        end
        DEFAULT_CHAT_FRAME:AddMessage(BLUE.."[Artisan]|r"..WHITE.." movable window is now |r"..status(ARTISAN_CONFIG.movable))
    else
        DEFAULT_CHAT_FRAME:AddMessage(BLUE.."[Artisan]|r"..WHITE.." version "..GetAddOnMetadata("Artisan", "version").."|r")
        DEFAULT_CHAT_FRAME:AddMessage(YELLOW.."/artisan auto|r"..WHITE.." - auto confirmation of enchant replacements "..status(ARTISAN_CONFIG.auto).."|r")
        DEFAULT_CHAT_FRAME:AddMessage(YELLOW.."/artisan icons|r"..WHITE.." - icons next to skill names "..status(ARTISAN_CONFIG.icons).."|r")
        DEFAULT_CHAT_FRAME:AddMessage(YELLOW.."/artisan movable|r"..WHITE.." - movable window "..status(ARTISAN_CONFIG.movable).."|r")
    end
end

function ArtisanItem_OnEnter()
    GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
    local tab = ArtisanFrame.selectedTabName
    local sorting = ARTISAN_CONFIG.sorting[tab]
    local skill = ArtisanFrame.selectedSkill

    if ArtisanFrame.craft then
        local originalID = ARTISAN_SKILLS[tab][sorting][skill].id
        GameTooltip:SetCraftItem(originalID, this:GetID())
    else
        if sorting == "custom" then
            local originalID = ARTISAN_SKILLS[tab][sorting][skill].id
            GameTooltip:SetTradeSkillItem(originalID, this:GetID())
        else
            GameTooltip:SetTradeSkillItem(skill, this:GetID())
        end
    end
    CursorUpdate()
end