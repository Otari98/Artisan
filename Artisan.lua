local maxCraftReagents = 8
local craftSkillHeight = 16
local craftsDisplayed = 12
local maxTabs = 7
local searchResults = {}
local playerProfessions = {}
craftingSkills = craftingSkills or {}
collapsedHeaders = collapsedHeaders or {}
customCategories = customCategories or {}
local professions = {
    ["primary"] = {
        ["Alchemy"]=true,
        ["Blacksmithing"]=true,
        ["Leatherworking"]=true,
        ["Tailoring"]=true,
        ["Engineering"]=true,
        ["Jewelcrafting"]=true,
        ["Enchanting"]=true,
        ["Smelting"]=true,
    },
    ["secondary"] = {
        ["First Aid"]=true,
        ["Cooking"]=true,
        ["Survival"]=true,
    },
    ["special"] = {
        ["Beast Training"]=true,
        ["Poisons"]=true,
    }
}

local patternsToHeaders = {
    ["Enchanting"] = {
        ["Bracer"] = {"bracer"},
        ["Boots"] = {"boots"},
        ["Gloves"] = {"gloves"},
        ["2H weapon"] = {"2h weapon"},
        ["Weapon"] = {"enchant weapon"},
        ["Wand"] = {"wand"},
        ["Consumable"] = {"mana oil$", "wizard oil$"},
        ["Cloak"] = {"cloak"},
        ["Chest"] = {"chest"},
        ["Shield"] = {"shield"},
        ["Miscellaneous"] = {"rod$", "gemstone oil$", "leather$", "thorium$", "shard$", "^smoking heart"},
    }
}

local TypeColor = {}
TypeColor["optimal"] = { r = 1.00, g = 0.50, b = 0.25 }
TypeColor["medium"]	 = { r = 1.00, g = 1.00, b = 0.00 }
TypeColor["easy"]	 = { r = 0.25, g = 0.75, b = 0.25 }
TypeColor["trivial"] = { r = 0.50, g = 0.50, b = 0.50 }
TypeColor["header"]	 = { r = 1.00, g = 0.82, b = 0 }
TypeColor["used"]    = { r = 0.50, g = 0.50, b = 0.50 }
TypeColor["none"]	 = { r = 0.25, g = 0.75, b = 0.25 }

UIPanelWindows["ArtisanFrame"] = { area = "left", pushable = 4 }

local YELLOW = NORMAL_FONT_COLOR_CODE
local WHITE = HIGHLIGHT_FONT_COLOR_CODE
local GREEN = GREEN_FONT_COLOR_CODE
local GREY = GRAY_FONT_COLOR_CODE
local BLUE = "|cff0070de"

function printf(...)
    local t = {}
    for i = 1, arg.n do
        if arg[i] == nil then
            arg[i] = "nil"
        end
        if type(arg[i] == "boolean") then
            if arg[i] == true then
                arg[i] = "true"
            end
            if arg[i] == false then
                arg[i] = "false"
            end
        end
        -- if arg[i] == "" then
        --     arg[i] = '""'
        -- end
        t[i] = arg[i]
    end
    local msg = t[1]
    if table.getn(t) > 1 then
        for j = 2, table.getn(t) do
            msg = msg..", "..t[j]
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage(GREY.."["..GetTime().."]|r "..WHITE..msg.."|r")
end

local debugging = true
local function debug(a)
    if not debugging then
        return
    end
    local msg = a
    if a == nil then
        msg = "Attempt to print a nil value."
    elseif type(msg) == "boolean" then
        if a then
            msg = "true"
        else
            msg = "false"
        end
    elseif type(a) == "table" then
        msg = "Attempt to print a table value."
    elseif type(a) == "userdata" then
        msg = "Attempt to print a userdata value."
    elseif type(a) == "function" then
        msg = "Attempt to print a function value."
    end
    DEFAULT_CHAT_FRAME:AddMessage(BLUE .."[Artisan]|r"..GREY.."["..GetTime().."]|r"..WHITE.."["..msg.."]|r")
end

local function listContains(list, key, value)
    if not list then
        return false
    end
    if not key and value then
        for _, v in pairs(list) do
            if v == value then
                return true
            end
        end
    end
    if key and not value then
        return list[key] ~= nil
    end
    return list[key] == value
end

local function addToList(list, key)
    if not list or not key then
        return false
    end
    list[key] = true
end

function ArtisanFrame_Search()
	searchResults = {}
	local query = strlower(ArtisanFrameSearchBox:GetText())

    if query == "" then
        ArtisanFrame_Update()
        return
    end

    local numSkills = Artisan_GetNumCrafts()

    for i = 1, numSkills do
        local skillName, skillType = Artisan_GetCraftInfo(i)

        if skillName then
            if skillType == "header" then
                Artisan_ExpandCraftSkillLine(i)
            else
                if strfind(strlower(skillName), query, 1, true) then
                    table.insert(searchResults, i)
                end
            end
        end
    end
    ArtisanListScrollFrame:SetVerticalScroll(0)
	ArtisanFrame_Update()
end

function ArtisanFrame_OnLoad()
    this:RegisterEvent("ADDON_LOADED")
    this:RegisterEvent("BAG_UPDATE")
    this:RegisterEvent("PLAYER_ENTERING_WORLD")
    this:RegisterEvent("UNIT_PORTRAIT_UPDATE")
    this:RegisterEvent("TRADE_SKILL_UPDATE")
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
            getglobal("ArtisanReagent"..i):SetScript("OnMouseUp", tradeSkillOnMouseUp)
        end
    end

    ArtisanFrame.selectedSkill = 0
    ArtisanFrame.originalScroll = ArtisanDetailScrollFrame:GetScript("OnMouseWheel")
    FauxScrollFrame_SetOffset(TradeSkillListScrollFrame, 0)
    ArtisanConfig = ArtisanConfig or {}
    ArtisanConfig.sorting = ArtisanConfig.sorting or "default"
    if ArtisanConfig.sorting == "default" then
        ArtisanSortDefault:SetChecked(1)
    elseif ArtisanConfig.sorting == "custom" then
        ArtisanSortCustom:SetChecked(1)
    end
end

function ArtisanFrame_OnEvent()
    if event == "ADDON_LOADED" and arg1 == "Artisan" then
        this:UnregisterEvent("ADDON_LOADED")
        ArtisanRankFrame:SetStatusBarColor(0.0, 0.0, 1.0, 0.5)
        ArtisanRankFrameBackground:SetVertexColor(0.0, 0.0, 0.75, 0.5)
        craftingSkills = craftingSkills or {}
    elseif event == "SPELLS_CHANGED" then
        Artisan_SetupSideTabs()
    elseif event == "PLAYER_ENTERING_WORLD" then
        SetPortraitTexture(ArtisanFramePortrait, "player")
        Artisan_Init()
    elseif event == "UNIT_PORTRAIT_UPDATE" and arg1 == "player" then
        SetPortraitTexture(ArtisanFramePortrait, "player")
    elseif event == "UNIT_PET_TRAINING_POINTS" then
		Artisan_UpdateTrainingPoints()
    elseif event == "TRADE_SKILL_UPDATE" then
        if (this.tick or 0.01) > GetTime() then
            return
        else
            this.tick = GetTime() + 0.01
        end
        Artisan_SetupSideTabs()
        if GetTradeSkillSelectionIndex() > 1 and GetTradeSkillSelectionIndex() <= GetNumTradeSkills() then
			Artisan_SetSelection(GetTradeSkillSelectionIndex())
		else
			if GetNumTradeSkills() > 0 then
				Artisan_SetSelection(GetFirstTradeSkill())
				FauxScrollFrame_SetOffset(ArtisanListScrollFrame, 0)
			end
			ArtisanListScrollFrameScrollBar:SetValue(0)
		end
		ArtisanFrame_Update()
    elseif event == "CRAFT_UPDATE" then
        if (this.tick or 0.01) > GetTime() then
            return
        else
            this.tick = GetTime() + 0.01
        end
        Artisan_SetupSideTabs()
        Artisan_UpdateSkillList()
        local selection = ArtisanFrame.selectedSkill
        local numCrafts = Artisan_GetNumCrafts()
		if selection > 1 and selection <= numCrafts then
			Artisan_SetSelection(selection)
		else
			if numCrafts > 0 then
                if ArtisanFrame.selectedTabName == "Beast Training" then
                    Artisan_SetSelection(1)
                else
                    Artisan_SetSelection(Artisan_GetFirstCraft())
                    FauxScrollFrame_SetOffset(ArtisanListScrollFrame, 0)
                    ArtisanListScrollFrame:SetVerticalScroll(0)
                    ArtisanListScrollFrameScrollBar:SetValue(0)
                end
			end
		end
		ArtisanFrame_Update()
    elseif event == "TRADE_SKILL_SHOW" then
        CloseCraft()
        ArtisanFrame_Show()
    elseif event == "CRAFT_SHOW" then
        CloseTradeSkill()
        ArtisanFrame_Show()
    elseif event == "TRADE_SKILL_CLOSE" or event == "CRAFT_CLOSE" then
        if GetCraftName() ~= "Beast Training" and GetCraftDisplaySkillLine() ~= "Enchanting" and GetTradeSkillLine() == "UNKNOWN" then
            ArtisanFrame.selectedTabName = nil
        end
        if not ArtisanFrame.selectedTabName then
            if ArtisanFrame:IsVisible() then
                HideUIPanel(ArtisanFrame)
            end
        end
    elseif event == "UPDATE_TRADESKILL_RECAST" then
		ArtisanFrameInputBox:SetNumber(GetTradeskillRepeatCount())
    elseif event == "BAG_UPDATE" then
        if ArtisanFrame:IsVisible() then
		    ArtisanFrame_Search()
        end
    end
end

function ArtisanFrame_Show()
    searchResults = {}

    if not ArtisanFrame:IsVisible() then
        ShowUIPanel(ArtisanFrame)
    end

    Artisan_SetupSideTabs()
    ArtisanFrame_Search()
end

function Artisan_SetupSideTabs()
    local _, _, _, numSpells = GetSpellTabInfo(1)
    local i = 1
    for spell = 1, numSpells do
        local spellName = GetSpellName(spell, "SPELL")
        if listContains(professions["primary"], spellName) or
            listContains(professions["secondary"], spellName) or
            listContains(professions["special"], spellName) then
            local texture = GetSpellTexture(spell, "SPELL")
            playerProfessions[i] = {}
            playerProfessions[i].name = spellName
            playerProfessions[i].tex = texture
            i = i + 1
        end
    end
    i = 1
    local tab
    -- primary professions first
    for index = 1, table.getn(playerProfessions) do
        if listContains(professions["primary"], playerProfessions[index].name) then
            tab = getglobal("ArtisanFrameSideTab"..i)
            tab.name = playerProfessions[index].name
            tab:SetNormalTexture(playerProfessions[index].tex)
            tab:Show()
            i = i + 1
        end
    end
    -- secondary professions
    for index = 1, table.getn(playerProfessions) do
        if listContains(professions["secondary"], playerProfessions[index].name) then
            tab = getglobal("ArtisanFrameSideTab"..i)
            tab.name = playerProfessions[index].name
            tab:SetNormalTexture(playerProfessions[index].tex)
            tab:Show()
            i = i + 1
        end
    end
    -- beast training / poisons
    for index = 1, table.getn(playerProfessions) do
        if listContains(professions["special"], playerProfessions[index].name) then
            tab = getglobal("ArtisanFrameSideTab"..i)
            tab.name = playerProfessions[index].name
            tab:SetNormalTexture(playerProfessions[index].tex)
            tab:Show()
            i = i + 1
        end
    end
    -- get selected tab
    for s = 1, numSpells do
        local spellName = GetSpellName(s, "SPELL")
        if listContains(professions["primary"], spellName) or
            listContains(professions["secondary"], spellName) or
            listContains(professions["special"], spellName)
        then
            local active = IsCurrentCast(s, "SPELL")
            if active then
                ArtisanFrame.selectedTabName = spellName
                if spellName == "Beast Training" or spellName == "Enchanting" then
                    ArtisanFrame.craft = true
                else
                    ArtisanFrame.craft = false
                end
                break
            end
        end
    end
    -- glow 
    for id = 1, maxTabs do
        tab = getglobal("ArtisanFrameSideTab"..id)
        if tab.name == ArtisanFrame.selectedTabName then
            getglobal("ArtisanFrameSideTab"..id):SetChecked(1)
        else
            getglobal("ArtisanFrameSideTab"..id):SetChecked(nil)
        end
    end
end

local function C_GetNumCrafts()
    if not ArtisanFrame.craft then
        return GetNumTradeSkills()
    else
        return GetNumCrafts()
    end
end

local function C_GetCraftInfo(i)
    local craftName, craftType, numAvailable, isExpanded, craftSubSpellName, trainingPointCost, requiredLevel
    if not ArtisanFrame.craft then
        craftName, craftType, numAvailable, isExpanded, craftSubSpellName, trainingPointCost, requiredLevel = GetTradeSkillInfo(i)
    else
        craftName, craftSubSpellName, craftType, numAvailable, isExpanded, trainingPointCost, requiredLevel = GetCraftInfo(i)
    end
    return craftName, craftType, numAvailable, isExpanded, craftSubSpellName, trainingPointCost, requiredLevel
end

function Artisan_UpdateSkillList()
    local craft = ArtisanFrame.selectedTabName
    local sorting = ArtisanConfig.sorting
    if not craftingSkills[craft] then
        craftingSkills[craft] = {}
    end
    craftingSkills[craft][sorting] = {}
    
    if not collapsedHeaders then
        collapsedHeaders = {}
    end
    if not collapsedHeaders[craft] then
        collapsedHeaders[craft] = {}
    end
    if not collapsedHeaders[craft][sorting] then
        collapsedHeaders[craft][sorting] = {}
    end

    local numHeaders = 0
    if sorting == "default" then
        if craft == "Enchanting" then
            craftingSkills[craft][sorting][0] = {name = "All", type = "header", exp = 1, childs= {}}
            numHeaders = 1
            local index = 1
            local headerIndex = 0
            for header in pairs(patternsToHeaders[craft]) do
                for _, pattern in pairs(patternsToHeaders[craft][header]) do
                    for i = 1, GetNumCrafts() do
                        local craftName = GetCraftInfo(i)
                        if strfind(strlower(craftName) or "", strlower(pattern)) then
                            local found = false
                            for k, v in pairs(craftingSkills[craft][sorting]) do
                                -- header exists already
                                if v.name == header then
                                    --debug(header.." already exists")
                                    headerIndex = k
                                    found = true
                                end
                            end
                            -- add new header
                            if not found then
                                --debug("new header "..header)
                                numHeaders = numHeaders + 1
                                tinsert(craftingSkills[craft][sorting][0].childs, header)
                                craftingSkills[craft][sorting][index] = {name = header, type = "header", childs = {}}
                                if not listContains(collapsedHeaders[craft][sorting], header) then
                                    craftingSkills[craft][sorting][index].exp = 1
                                end
                                headerIndex = index
                                index = index + 1
                            end
                            -- populate header
                            for j = 1, GetNumCrafts() do
                                local name, sub, type, num, exp, tp, lvl = GetCraftInfo(j)
                                if strfind(strlower(name) or "", strlower(pattern)) then
                                    if craftingSkills[craft][sorting][headerIndex].exp == 1 then
                                        craftingSkills[craft][sorting][index] = {name = "", type = "", num = 0, id = 0}
                                        craftingSkills[craft][sorting][index].name = name
                                        craftingSkills[craft][sorting][index].type = type
                                        craftingSkills[craft][sorting][index].num = num
                                        craftingSkills[craft][sorting][index].exp = exp
                                        craftingSkills[craft][sorting][index].sub = sub
                                        craftingSkills[craft][sorting][index].tp = tp
                                        craftingSkills[craft][sorting][index].lvl = lvl
                                        craftingSkills[craft][sorting][index].id = j
                                        index = index + 1
                                    end
                                    tinsert(craftingSkills[craft][sorting][headerIndex].childs, name)
                                end
                            end
                            break
                        end
                    end
                end
            end
        elseif craft == "Beast Training" then
            local index = 1
            for i = 1, GetNumCrafts() do
                local name, sub, type, num, exp, tp, lvl = GetCraftInfo(i)
                if name then
                    craftingSkills[craft][sorting][index] = {name = "", sub = "", type = "", num = 0, exp = 0, tp = 0, lvl = 0, id = 0}
                    craftingSkills[craft][sorting][index].name = name
                    craftingSkills[craft][sorting][index].sub = sub
                    craftingSkills[craft][sorting][index].type = type
                    craftingSkills[craft][sorting][index].num = num
                    craftingSkills[craft][sorting][index].exp = exp
                    craftingSkills[craft][sorting][index].tp = tp
                    craftingSkills[craft][sorting][index].lvl = lvl
                    craftingSkills[craft][sorting][index].id = i
                    index = index + 1
                end
            end
        end
    elseif sorting == "custom" then
        craftingSkills[craft][sorting][0] = {name = "All", type = "header", exp = 1, childs= {}}
        craftingSkills[craft][sorting][1] = {name = "Uncategorized", type = "header", exp = 1, childs= {}}
        if listContains(collapsedHeaders[craft][sorting], "Uncategorized") then
            craftingSkills[craft][sorting][1].exp = nil
        end
        numHeaders = 2
        local index = 2
        local headerIndex = 1
        for i = 1, C_GetNumCrafts() do
            local name, type, num, exp, sub, tp, lvl = C_GetCraftInfo(i)
            if name and type ~="header" then
                if craftingSkills[craft][sorting][headerIndex].exp == 1 then
                    craftingSkills[craft][sorting][index] = {name = "", type = "", num = 0, id = 0}
                    craftingSkills[craft][sorting][index].name = name
                    craftingSkills[craft][sorting][index].type = type
                    craftingSkills[craft][sorting][index].num = num
                    craftingSkills[craft][sorting][index].exp = exp
                    craftingSkills[craft][sorting][index].sub = sub
                    craftingSkills[craft][sorting][index].tp = tp
                    craftingSkills[craft][sorting][index].lvl = lvl
                    craftingSkills[craft][sorting][index].id = i
                    index = index + 1
                end
                tinsert(craftingSkills[craft][sorting][headerIndex].childs, name)
            end
        end
    end

    return numHeaders
end

function ArtisanFrame_Update()
    if not ArtisanFrame.selectedTabName then
        return
    end

	local craftOffset = FauxScrollFrame_GetOffset(ArtisanListScrollFrame)
    local numCrafts = Artisan_GetNumCrafts()
    local name, rank, maxRank = Artisan_GetCraftSkillLine()
    local headers = 0

    headers = Artisan_UpdateSkillList()
    if ArtisanFrame.craft then
        ArtisanFrameBottomLeftTex:SetTexture("Interface\\ClassTrainerFrame\\UI-ClassTrainer-BotLeft")
        ArtisanFrameCreateButton:SetText(getglobal(GetCraftButtonToken()))
        ArtisanFrameCreateAllButton:Hide()
        ArtisanFrameDecrementButton:Hide()
        ArtisanFrameInputBox:Hide()
        ArtisanFrameIncrementButton:Hide()
    else
        ArtisanFrameBottomLeftTex:SetTexture("Interface\\TradeSkillFrame\\UI-TradeSkill-BotLeft")
        ArtisanFrameCreateButton:SetText("Create")
        ArtisanFrameCreateAllButton:Show()
        ArtisanFrameDecrementButton:Show()
        ArtisanFrameInputBox:Show()
        ArtisanFrameIncrementButton:Show()
    end
    -- Setup status bar
    ArtisanRankFrameSkillName:SetText(ArtisanFrame.selectedTabName)
    if name then
        ArtisanRankFrame:Show()
        ArtisanRankFrame:SetMinMaxValues(0, maxRank)
		ArtisanRankFrame:SetValue(rank)
		ArtisanRankFrameSkillRank:SetText(rank.."/"..maxRank)
        ArtisanFrameTitleText:Hide()
    else -- Beast Training
        ArtisanFrameTitleText:SetText(GetCraftName())
        ArtisanFrameTitleText:Show()
        ArtisanRankFrame:Hide()
    end

	if (not ArtisanFrame.craft and numCrafts < 0) or (ArtisanFrame.craft and (numCrafts - headers) < 0) then
		ArtisanSkillName:Hide()
        ArtisanSkillIcon:Hide()
		ArtisanRequirementLabel:Hide()
		ArtisanRequirementText:SetText("")
		for i = 1, maxCraftReagents do
			getglobal("ArtisanReagent"..i):Hide()
		end
	else
		ArtisanSkillName:Show()
		ArtisanSkillIcon:Show()
        if ArtisanFrameSearchBox:GetText() ~= "" then
		    ArtisanCollapseAllButton:Disable()
        else
            ArtisanCollapseAllButton:Enable()
        end
        if ArtisanFrame.selectedTabName == "Beast Training" then
            ArtisanCollapseAllButton:Disable()
        end
	end

    -- If player has training points show them here
    Artisan_UpdateTrainingPoints()
    ArtisanHighlightFrame:Hide()

    local results = table.getn(searchResults)
    local craftsToUpdate = results == 0 and numCrafts or results
    FauxScrollFrame_Update(ArtisanListScrollFrame, craftsToUpdate, craftsDisplayed, craftSkillHeight, nil, nil, nil, ArtisanHighlightFrame, 293, 316 )

    for i=1, craftsDisplayed, 1 do
        local craftIndex = 0
        if ArtisanFrameSearchBox:GetText() ~= "" then
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
        local craftButton = getglobal("ArtisanFrameSkill"..i)
        local craftButtonSubText = getglobal("ArtisanFrameSkill"..i.."SubText")
        local craftButtonCost = getglobal("ArtisanFrameSkill"..i.."Cost")
        craftButtonCost:SetText("")

        if ( craftIndex > 0 and craftIndex <= numCrafts ) then
            -- Set button widths if scrollbar is shown or hidden
            if ( ArtisanListScrollFrame:IsVisible() ) then
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
                getglobal("ArtisanFrameSkill"..i.."Highlight"):SetTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
                craftButton:UnlockHighlight()
            else
                craftButton:SetNormalTexture("")
                getglobal("ArtisanFrameSkill"..i.."Highlight"):SetTexture("")
                if craftName then
                    if ( numAvailable == 0 ) then
                        craftButton:SetText(" "..craftName)
                    else
                        craftButton:SetText(" "..craftName.." ["..numAvailable.."]")
                    end
                end
                -- (Rank)
                if ( craftSubSpellName and craftSubSpellName ~= "" ) then
                    craftButtonSubText:SetText(format(TEXT(PARENS_TEMPLATE), craftSubSpellName))
                else
                    craftButtonSubText:SetText("")
                end
                -- TP
                craftButtonCost:SetText("")
                if ArtisanFrame.selectedTabName == "Beast Training" and UnitName("pet") then
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
        if ( GetTradeSkillSelectionIndex() == i ) then
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
    
    if ArtisanFrameSearchBox:GetText() ~= "" and table.getn(searchResults) == 0 then
        return
    end

    ArtisanHighlightFrame:Show()

    local craftName, craftType, numAvailable, isExpanded, craftSubSpellName, trainingPointCost, requiredLevel = Artisan_GetCraftInfo(id)
    -- If the type of the selection is header, don't process all the craft details
    if ( craftType == "header" ) then
        ArtisanHighlightFrame:Hide()
        if (table.getn(searchResults) == 0) then
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

    ArtisanSkillName:SetText(craftName)
    ArtisanSkillIcon:SetNormalTexture(Artisan_GetCraftIcon(id))
    ArtisanSkillCooldown:SetText("")
    ArtisanSkillIconCount:SetText("")
    ArtisanCraftCost:Hide()
    ArtisanCraftDescription:Hide()
    -- Cooldown
    if GetTradeSkillCooldown(id) then
        ArtisanSkillCooldown:SetText(COOLDOWN_REMAINING.." "..SecondsToTime(GetTradeSkillCooldown(id)))
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
        local minMade, maxMade = GetTradeSkillNumMade(id)
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
        local reagent = getglobal("ArtisanReagent"..i)
        local name = getglobal("ArtisanReagent"..i.."Name")
        local count = getglobal("ArtisanReagent"..i.."Count")
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
        getglobal("ArtisanReagent"..i):Hide()
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
    if numReagents > 2 then
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
        ArtisanDetailScrollFrame:SetVerticalScroll(0)
		Artisan_SetSelection(this:GetID())
		ArtisanFrame_Update()
	end
    ArtisanFrameSearchBox:ClearFocus()
end

function ArtisanSideTab_OnCLick()
    if this.name == ArtisanFrame.selectedTabName then
        this:SetChecked(1)
        return
    end
    
    if this.name ~= ArtisanFrame.selectedTabName then
        if this.name == "Enchanting" or this.name == "Beast Training" then
            ArtisanFrame.craft = true
        else
            ArtisanFrame.craft = false
        end
        ArtisanFrame.selectedTabName = this.name
        ArtisanFrame.selectedSkill = Artisan_GetFirstCraft()
        CastSpellByName(this.name)
        Artisan_SetSelection(Artisan_GetFirstCraft())
    end

    for i = 1, maxTabs do
        local tab = getglobal("ArtisanFrameSideTab"..i)
        if this:GetID() == i then
            tab:SetChecked(1)
        else
            tab:SetChecked(nil)
        end
    end

    ArtisanListScrollFrame:SetVerticalScroll(0)
    ArtisanDetailScrollFrame:SetVerticalScroll(0)
    ArtisanFrameSearchBox:SetText("")
    ArtisanFrameSearchBox:ClearFocus()
    PlaySound("igCharacterInfoTab")
    ArtisanFrame_Update()
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
		if aux_frame and aux_frame:IsVisible() then
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
		elseif ChatFrameEditBox:IsVisible() then
			ChatFrameEditBox:Insert(link)
        end
    end
end

function Artisan_GetCraftInfo(index)
    local craft = ArtisanFrame.selectedTabName
    local sorting = ArtisanConfig.sorting
    if not ArtisanFrame.selectedTabName then
        return
    end

    if not ArtisanFrame.craft then
        return GetTradeSkillInfo(index)
    end

    local craftName = ""
    local craftType = ""
    local numAvailable = 0
    local isExpanded = nil
    local craftSubSpellName = ""
    local trainingPointCost = 0
    local requiredLevel = 0

    if craftingSkills[craft][sorting][index] then
        craftName = craftingSkills[craft][sorting][index].name or ""
        craftType = craftingSkills[craft][sorting][index].type or ""
        numAvailable = craftingSkills[craft][sorting][index].num or 0
        isExpanded = craftingSkills[craft][sorting][index].exp or nil
        craftSubSpellName = craftingSkills[craft][sorting][index].sub or ""
        trainingPointCost = craftingSkills[craft][sorting][index].tp or 0
        requiredLevel = craftingSkills[craft][sorting][index].lvl or 0
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
    if not ArtisanFrame.craft then
        CollapseTradeSkillSubClass(id)
        ArtisanFrame_Update()
        return
    end

    local craft = ArtisanFrame.selectedTabName
    local sorting = ArtisanConfig.sorting
    if not collapsedHeaders[craft] then
        collapsedHeaders[craft] = {}
    end
    if not collapsedHeaders[craft][sorting] then
        collapsedHeaders[craft][sorting] = {}
    end
    if craftingSkills[craft][sorting][id].type ~= "header" then
        return
    end

    if id == 0 then
        ArtisanFrame.selectedSkill = 0
        -- collapse all
        for i = 0, table.getn(craftingSkills[craft][sorting]) do
            if craftingSkills[craft][sorting][i].type == "header" and 
                not listContains(collapsedHeaders[craft][sorting], craftingSkills[craft][sorting][i].name) then
                addToList(collapsedHeaders[craft][sorting], craftingSkills[craft][sorting][i].name)
            end
        end
        Artisan_UpdateSkillList()
    else
        -- collapse only 1
        local headerName = craftingSkills[craft][sorting][id].name
        if craftingSkills[craft][sorting][id].type == "header"  and not listContains(collapsedHeaders[craft][sorting], headerName) then
            addToList(collapsedHeaders[craft][sorting], headerName)
        end
        local skill = ArtisanFrame.selectedSkill
        local skillName = Artisan_GetCraftInfo(ArtisanFrame.selectedSkill)
        local offset = getn(craftingSkills[craft][sorting][id].childs) or 0
        Artisan_UpdateSkillList()
        local first = Artisan_GetFirstCraft()
        if first == 0 then
            skill = 0
        elseif id < ArtisanFrame.selectedSkill then
            skill = ArtisanFrame.selectedSkill - offset
            if first > skill or listContains(craftingSkills[craft][sorting][id].childs, nil, skillName) then
                skill = first
            end
        end
        Artisan_SetSelection(skill)
    end
    ArtisanFrame_Update()
end

function Artisan_ExpandCraftSkillLine(id)
    if not ArtisanFrame.craft then
        ExpandTradeSkillSubClass(id)
        ArtisanFrame_Update()
        return
    end
    local craft = ArtisanFrame.selectedTabName
    local sorting = ArtisanConfig.sorting
    local headerName = craftingSkills[craft][sorting][id].name
    local offset = getn(craftingSkills[craft][sorting][id].childs) or 0

    if craftingSkills[craft][sorting][id].type ~= "header" then
        return
    end

    if id == 0 then
        --expand all
        for i = 1, table.getn(craftingSkills[craft][sorting]) do
            if craftingSkills[craft][sorting][i].type == "header" then
                headerName = craftingSkills[craft][sorting][i].name
                if listContains(collapsedHeaders[craft][sorting], headerName) then
                    collapsedHeaders[craft][sorting][headerName] = nil
                end
            end
        end
        Artisan_UpdateSkillList()
        Artisan_SetSelection(Artisan_GetFirstCraft())
    else
        --expand 1
        if listContains(collapsedHeaders[craft][sorting], headerName) then
            collapsedHeaders[craft][sorting][headerName] = nil
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
    ArtisanFrame_Update()
end

function Artisan_GetItemLink(index)
	if ArtisanFrame.craft then
        local originalID = craftingSkills[ArtisanFrame.selectedTabName][ArtisanConfig.sorting][index].id
		return GetCraftItemLink(originalID)
	else
		return GetTradeSkillItemLink(index)
	end
end

function Artisan_GetReagentItemLink(index, id)
    if ArtisanFrame.craft then
        local originalIndex = craftingSkills[ArtisanFrame.selectedTabName][ArtisanConfig.sorting][index].id
        return GetCraftReagentItemLink(originalIndex, id)
    else
        return GetTradeSkillReagentItemLink(index, id)
    end
end

function Artisan_GetFirstCraft()
    if not ArtisanFrame.craft then
        return GetFirstTradeSkill()
    end
    local craft = ArtisanFrame.selectedTabName
    local sorting = ArtisanConfig.sorting
    if not craft then
        return
    end

    if craft == "Beast Training" then
        if sorting == "default" then
            return 1
        end
    end

    for k = 1, table.getn(craftingSkills[craft][sorting]) do
        if craftingSkills[craft][sorting][k].type == "header" and craftingSkills[craft][sorting][k].exp == 1 then
            return k + 1
        end
    end

    return 0
end

function Artisan_GetNumCrafts()
    if not ArtisanFrame.craft then
        return GetNumTradeSkills()
    end

    return getn(craftingSkills[ArtisanFrame.selectedTabName][ArtisanConfig.sorting])
end

function Artisan_SelectCraft(id)
    if not ArtisanFrame.craft then
        return SelectTradeSkill(id)
    end
    local originalID = craftingSkills[ArtisanFrame.selectedTabName][ArtisanConfig.sorting][id].id
    SelectCraft(originalID)
end

function Artisan_GetCraftIcon(id)
    if not ArtisanFrame.craft then
        return GetTradeSkillIcon(id)
    end
    local originalID = craftingSkills[ArtisanFrame.selectedTabName][ArtisanConfig.sorting][id].id
    return GetCraftIcon(originalID)
end

function Artisan_GetCraftDescription(id)
    if not ArtisanFrame.craft then
        return nil
    end
    local originalID = craftingSkills[ArtisanFrame.selectedTabName][ArtisanConfig.sorting][id].id
    return GetCraftDescription(originalID)
end

function Artisan_GetCraftNumReagents(id)
    if not ArtisanFrame.craft then
        return GetTradeSkillNumReagents(id)
    end
    local originalID = craftingSkills[ArtisanFrame.selectedTabName][ArtisanConfig.sorting][id].id
    return GetCraftNumReagents(originalID)
end

function Artisan_GetCraftReagentInfo(id, i)
    if not ArtisanFrame.craft then
        return GetTradeSkillReagentInfo(id, i)
    end
    local originalID = craftingSkills[ArtisanFrame.selectedTabName][ArtisanConfig.sorting][id].id
    return GetCraftReagentInfo(originalID, i)
end

function Artisan_GetCraftTools(id)
    if not ArtisanFrame.craft then
        return GetTradeSkillTools(id)
    end
    local originalID = craftingSkills[ArtisanFrame.selectedTabName][ArtisanConfig.sorting][id].id
    return GetCraftSpellFocus(originalID)
end

function ArtisanEditButton_OnClick()
    if ArtisanEditor:IsVisible() then
        ArtisanEditor:Hide()
    else
        ArtisanEditor:Show()
        ArtisanEditorLeft_Update()
        ArtisanEditorRight_Update()
    end
end

function ArtisanSortDefault_OnClick()
    if ArtisanConfig.sorting ~= "default" then
        ArtisanConfig.sorting = "default"
        this:SetChecked(1)
        ArtisanSortCustom:SetChecked(nil)
        Artisan_UpdateSkillList()
        Artisan_SetSelection(Artisan_GetFirstCraft())
        ArtisanFrame_Update()
    else
        this:SetChecked(1)
    end
end

function ArtisanSortCustom_OnClick()
    if ArtisanConfig.sorting ~= "custom" then
        ArtisanConfig.sorting = "custom"
        this:SetChecked(1)
        ArtisanSortDefault:SetChecked(nil)
        Artisan_UpdateSkillList()
        Artisan_SetSelection(Artisan_GetFirstCraft())
        ArtisanFrame_Update()
    else
        this:SetChecked(1)
    end
end

function ArtisanSortSkill_OnClick()

end

function ArtisanSortName_OnClick()

end

local skillsOnly = {}
function ArtisanEditorLeftButton_OnClick()
    if ArtisanEditor.currentHeader then
        local headerIndex = ArtisanEditor.currentHeader
        local tabName = ArtisanFrame.selectedTabName
        local name = this:GetText()
        if this.type ~= "header" then
            tinsert(customCategories[tabName], headerIndex + 1, {name = name, type = this.type})
            tinsert(customCategories[tabName][headerIndex].childs, name)
        end
        tremove(skillsOnly[tabName], this:GetID())
        ArtisanEditorLeft_Update()
        ArtisanEditorRight_Update()
    end
end

function ArtisanEditorRightButton_OnClick()
    if this.type == "header" then
        ArtisanEditor.currentHeader = this:GetID()
    end
    ArtisanEditorRight_Update()
end

function ArtisanRightButtonUp_OnClick(arg1)

end

function ArtisanRightButtonDown_OnClick()
    
end

function ArtisanRightButtonDelete_OnClick()
    local tabName = ArtisanFrame.selectedTabName
    local button = getglobal("ArtisanEditorSkilRight"..this:GetID())
    if button.type ~= "header" then
        tinsert(skillsOnly[tabName], {button:GetText(), button.type}) 
    else
        for _, v in pairs(customCategories[tabName][this:GetID()].childs) do
            for k2, v2 in pairs(customCategories[tabName]) do
                if v2.name == v then
                    tremove(customCategories[tabName], k2)
                    tinsert(skillsOnly[tabName], {v2.name, v2.type})
                end
            end
        end
    end
    table.sort(skillsOnly[tabName], function(a,b) return a[1] < b[1] end)
    tremove(customCategories[tabName], this:GetID())
    ArtisanEditorLeft_Update()
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
    for i = 1, 25 do
        if not listRight[i] then
            listRight[i] = CreateFrame("Button", "ArtisanEditorSkilRight"..i, ArtisanEditor, "ArtisanEditorRightButtonTemplate")
            listRight[i]:SetPoint("TOPRIGHT", ArtisanEditor, -30 , -30 - ((i - 1) * craftSkillHeight))
            listRight[i]:Hide()
            
            listRight[i].up = CreateFrame("Button", "ArtisanEditorRightUp"..i, ArtisanEditor, "ArtisanRightButtonUpTemplate")
            listRight[i].up:SetPoint("CENTER", "ArtisanEditorSkilRight"..i, "RIGHT", -55, 0)
            listRight[i].up:SetFrameLevel(getglobal("ArtisanEditorSkilRight"..i):GetFrameLevel() + 1)
            listRight[i].up:SetID(i)
            listRight[i].up:Hide()

            listRight[i].down = CreateFrame("Button", "ArtisanEditorRightDown"..i, ArtisanEditor, "ArtisanRightButtonDownTemplate")
            listRight[i].down:SetPoint("CENTER", "ArtisanEditorRightUp"..i, "RIGHT", 10, 0)
            listRight[i].down:SetFrameLevel(getglobal("ArtisanEditorSkilRight"..i):GetFrameLevel() + 1)
            listRight[i].down:SetID(i)
            listRight[i].down:Hide()

            listRight[i].delete = CreateFrame("Button", "ArtisanEditorRightDelete"..i, ArtisanEditor, "ArtisanRightButtonDeleteTemplate")
            listRight[i].delete:SetPoint("CENTER", "ArtisanEditorRightDown"..i, "RIGHT", 10, 0)
            listRight[i].delete:SetFrameLevel(getglobal("ArtisanEditorSkilRight"..i):GetFrameLevel() + 1)
            listRight[i].delete:SetID(i)
            listRight[i].delete:Hide()
        end
    end
end

function ArtisanEditor_OnShow()
    if not craftingSkills[ArtisanFrame.selectedTabName][ArtisanConfig.sorting] then
        return
    end
    local tabName = ArtisanFrame.selectedTabName
    if not skillsOnly[tabName] then
        skillsOnly[tabName] = {}
    end
    if not customCategories[tabName] then
        customCategories[tabName] = {}
    end
    for k in pairs(skillsOnly[tabName]) do
        skillsOnly[tabName][k] = nil
    end
    table.setn(skillsOnly[tabName],0)
    for _, v in pairs(craftingSkills[tabName][ArtisanConfig.sorting]) do
        if v.type ~= "header" then
            local name = v.name
            if v.sub and v.sub ~= "" then
                name = v.name.."  "..format(TEXT(PARENS_TEMPLATE), v.sub)
            end
            tinsert(skillsOnly[tabName], {name, v.type})
            for k in pairs(customCategories[tabName]) do
                if customCategories[tabName][k].name == name then
                    tremove(skillsOnly[tabName])
                    break
                end
            end
        end
    end
    table.sort(skillsOnly[tabName], function(a,b) return a[1] < b[1] end)
    ArtisanEditorScrollFrameLeft:SetVerticalScroll(0)
    ArtisanEditorScrollFrameRight:SetVerticalScroll(0)
end

function ArtisanEditorLeft_Update()
    local craftOffset = FauxScrollFrame_GetOffset(ArtisanEditorScrollFrameLeft) or 0
    local tabName = ArtisanFrame.selectedTabName
    local numCrafts = getn(skillsOnly[tabName])
    local buttonIndex = 1
    FauxScrollFrame_Update(ArtisanEditorScrollFrameLeft, numCrafts, 25, craftSkillHeight)
    for i = 1, 25 do
        local craftIndex = 0
        craftIndex = i + craftOffset
        if craftIndex > 0 and craftIndex <= numCrafts then
            local craftName, craftType = skillsOnly[tabName][craftIndex][1], skillsOnly[tabName][craftIndex][2]
            local craftButton = getglobal("ArtisanEditorSkillLeft"..buttonIndex)
            local color = TypeColor[craftType]
            if color then
                craftButton:SetTextColor(color.r, color.g, color.b)
                craftButton.r = color.r
                craftButton.g = color.g
                craftButton.b = color.b
            end
            craftButton:SetID(craftIndex)
            craftButton:Show()
            craftButton:SetNormalTexture("")
            getglobal("ArtisanEditorSkillLeft"..buttonIndex.."Highlight"):SetTexture("")
            craftButton:SetText(craftName)
            getglobal("ArtisanEditorSkillLeft"..buttonIndex).type = craftType
        else
            getglobal("ArtisanEditorSkillLeft"..i):Hide()
        end
        buttonIndex = buttonIndex + 1
    end
end

function ArtisanEditorRight_Update()
    local craftOffset = FauxScrollFrame_GetOffset(ArtisanEditorScrollFrameRight) or 0
    local tabName = ArtisanFrame.selectedTabName
    local numCrafts = getn(customCategories[tabName])
    local buttonIndex = 1
    FauxScrollFrame_Update(ArtisanEditorScrollFrameRight, numCrafts, 25, craftSkillHeight)
    for i = 1, 25 do
        local craftIndex = 0
        craftIndex = i + craftOffset
        if craftIndex > 0 and craftIndex <= numCrafts then
            local craftName, craftType = customCategories[tabName][craftIndex].name, customCategories[tabName][craftIndex].type
            local craftButton = getglobal("ArtisanEditorSkilRight"..buttonIndex)
            local color = TypeColor[craftType]
            if color then
                craftButton:SetTextColor(color.r, color.g, color.b)
                craftButton.r = color.r
                craftButton.g = color.g
                craftButton.b = color.b
            end
            craftButton:SetText(craftName)
            craftButton:SetID(craftIndex)
            getglobal("ArtisanEditorSkilRight"..buttonIndex).type = craftType
            craftButton:Show()
            if craftType ~= "header" then
                craftButton:SetNormalTexture("")
                getglobal("ArtisanEditorSkilRight"..buttonIndex.."Highlight"):SetTexture("")
            else
                if ArtisanEditor.currentHeader == craftIndex then
                    craftButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
                else
                    craftButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
                end
                getglobal("ArtisanEditorSkilRight"..i.."Highlight"):SetTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
                craftButton:UnlockHighlight()
            end
        else
            getglobal("ArtisanEditorSkilRight"..i):Hide()
        end
        buttonIndex = buttonIndex + 1
    end
end

function ArtisanEditorAdd_OnClick()
    StaticPopup_Show("ARTISAN_NEW_CATEGORY")
end

StaticPopupDialogs["ARTISAN_NEW_CATEGORY"] = {
    text = "Name the new category",
    button1 = TEXT(OKAY),
    button2 = TEXT(CANCEL),
    hasEditBox = 1,
    OnShow = function()
        getglobal(this:GetName().."EditBox"):SetFocus()
        getglobal(this:GetName().."EditBox"):SetText("")
        getglobal(this:GetName() .. "EditBox"):SetScript("OnEnterPressed", function()
            StaticPopup1Button1:Click()
        end)
        getglobal(this:GetName() .. "EditBox"):SetScript("OnEscapePressed", function()
            getglobal(this:GetParent():GetName() .. "EditBox"):SetText("")
            StaticPopup1Button2:Click()
        end)
    end,
    OnAccept = function()
        ArtisanEditor_AddCategory(getglobal(this:GetParent():GetName() .. "EditBox"):GetText())
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

function ArtisanEditor_AddCategory(categoryName)
    local tabName = ArtisanFrame.selectedTabName
    if categoryName ~= "" then
        tinsert(customCategories[tabName], {name = categoryName, type = "header", exp = 1, childs = {}})
        for k in pairs(customCategories[tabName]) do
            if customCategories[tabName][k].name == categoryName then
                ArtisanEditor.currentHeader = k
            end
        end
        ArtisanEditorRight_Update()
    end
end