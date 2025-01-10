local maxCraftReagents = 8
local craftSkillHeight = 16
local skillsDisplayed = 12
local max_tabs = 7
local searchResults = {}
local playerProfessions = {}
craftingSkills = craftingSkills or {}
collapsedHeaders = collapsedHeaders or {}

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
        ["bracer"] = "Bracer",
        ["boots"] = "Boots",
        ["gloves"] = "Gloves",
        ["2h weapon"] = "2H weapon",
        ["enchant weapon"] = "Weapon",
        ["wand"] = "Wand",
        ["oil$"] = "Consumable",
        ["cloak"] = "Cloak",
        ["chest"] = "Chest",
        ["shield"] = "Shield",
        ["rod$"] = "Miscellaneous",
        ["leather$"] = "Miscellaneous",
        ["thorium$"] = "Miscellaneous",
        ["shard$"] = "Miscellaneous",
        ["^smoking heart"] = "Miscellaneous",
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

local print = true
function a_print(...)
    if not print then
        return
    end
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
        if arg[i] == "" then
            arg[i] = '""'
        end
        t[i] = arg[i]
    end
    local msg = t[1]
    if table.getn(t) > 1 then
        for j = 2, table.getn(t) do
            msg = msg..", "..t[j]
        end
    end
    ChatFrame1:AddMessage(msg)
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
    local profession = ArtisanFrame.selectedTabName
	local query = strlower(ArtisanFrameSearchBox:GetText())

    if query == "" then
        ArtisanFrame_Update()
        return
    end

    local numSkills
    local craft = false
    if profession == "Beast Training" or profession == "Enchanting" then
        craft = true
        numSkills = table.getn(craftingSkills[profession])
    else
        numSkills = GetNumTradeSkills()
    end
	
    for i = 1, numSkills do
        local skillName, skillType

        if craft then
            skillName, _, skillType = Artisan_GetCraftInfo(i)
        else
            skillName, skillType = GetTradeSkillInfo(i)
        end
        if skillName then
            if skillType == "header" then
                if craft then
                    Artisan_ExpandCraftSkillLine(i)
                else
                    ExpandTradeSkillSubClass(i)
                end
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

function Artisan_GetFirstCraft(craft)
    if not craft then
        return
    end

    if craft == "Beast Training" then
        return 1
    end

    for k = 1, table.getn(craftingSkills[craft]) do
        if craftingSkills[craft][k].type == "header" and craftingSkills[craft][k].exp == 1 then
            return k + 1
        end
    end

    return 0
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

    ArtisanFrame.selectedSkill = 2
    ArtisanFrame.originalScroll = ArtisanDetailScrollFrame:GetScript("OnMouseWheel")
    FauxScrollFrame_SetOffset(TradeSkillListScrollFrame, 0)
end

function ArtisanFrame_OnEvent()
    if event == "ADDON_LOADED" and arg1 == "Artisan" then
        this:UnregisterEvent("ADDON_LOADED")
        ArtisanRankFrame:SetStatusBarColor(0.0, 0.0, 1.0, 0.5)
        ArtisanRankFrameBackground:SetVertexColor(0.0, 0.0, 0.75, 0.5)
        craftingSkills = craftingSkills or {}
    end
    if event == "SPELLS_CHANGED" then
        Artisan_SetupSideTabs()
    end
    if event == "PLAYER_ENTERING_WORLD" then
        SetPortraitTexture(ArtisanFramePortrait, "player")
        Artisan_Init()
    end
    if event == "UNIT_PORTRAIT_UPDATE" and arg1 == "player" then
        SetPortraitTexture(ArtisanFramePortrait, "player")
    end
    if event == "UNIT_PET_TRAINING_POINTS" then
		Artisan_UpdateTrainingPoints()
	end
    if event == "TRADE_SKILL_UPDATE" then
        Artisan_SetupSideTabs()
		if GetTradeSkillSelectionIndex() > 1 and GetTradeSkillSelectionIndex() <= GetNumTradeSkills() then
			Artisan_SetSelection(GetTradeSkillSelectionIndex())
		else
			if GetNumTradeSkills() > 0 then
				Artisan_SetSelection(GetFirstTradeSkill())
				FauxScrollFrame_SetOffset(ArtisanListScrollFrame, 0)
                ArtisanListScrollFrame:SetVerticalScroll(0)
			end
			ArtisanListScrollFrameScrollBar:SetValue(0)
		end
		ArtisanFrame_Update()
    end
    if event == "CRAFT_UPDATE" then
        Artisan_SetupSideTabs()
        Artisan_UpdateSkillList()
        local craft = ArtisanFrame.selectedTabName
        local selection = ArtisanFrame.selectedSkill
        local numCrafts = table.getn(craftingSkills[craft])
		if selection > 0 and selection <= numCrafts then
			Artisan_SetSelection(selection)
		else
			if numCrafts > 0 then
				Artisan_SetSelection(Artisan_GetFirstCraft(craft))
				FauxScrollFrame_SetOffset(ArtisanListScrollFrame, 0)
                ArtisanListScrollFrame:SetVerticalScroll(0)
			end
            ArtisanListScrollFrameScrollBar:SetValue(0)
		end
		ArtisanFrame_Update()
    end
    if event == "TRADE_SKILL_SHOW" then
        CloseCraft()
        ArtisanFrame_Show()
    end
    if event == "CRAFT_SHOW" then
        CloseTradeSkill()
        ArtisanFrame_Show()
    end
    if event == "TRADE_SKILL_CLOSE" or event == "CRAFT_CLOSE" then
        if GetCraftName() ~= "Beast Training" and GetCraftDisplaySkillLine() ~= "Enchanting" and GetTradeSkillLine() == "UNKNOWN" then
            ArtisanFrame.selectedTabName = nil
        end
        if not ArtisanFrame.selectedTabName then
            if ArtisanFrame:IsVisible() then
                HideUIPanel(ArtisanFrame)
            end
        end
    end
    if event == "UPDATE_TRADESKILL_RECAST" then
		ArtisanFrameInputBox:SetNumber(GetTradeskillRepeatCount())
    end
    if event == "BAG_UPDATE" then
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

function Artisan_CollapseCraftSkillLine(id)
    local craft = ArtisanFrame.selectedTabName
    
    if not collapsedHeaders[craft] then
        collapsedHeaders[craft] = {}
    end
    
    if craftingSkills[craft][id].type ~= "header" then
        return
    end

    if id == 0 then
        ArtisanFrame.selectedSkill = 0
        -- collapse all
        for i = 0, table.getn(craftingSkills[craft]) do
            if craftingSkills[craft][i].type == "header" and not listContains(collapsedHeaders[craft], craftingSkills[craft][i].name) then
                addToList(collapsedHeaders[craft], craftingSkills[craft][i].name)
            end
        end
    else
        -- collapse only 1
        local headerName = craftingSkills[craft][id].name
        if craftingSkills[craft][id].type == "header"  and not listContains(collapsedHeaders[craft], headerName) then
            addToList(collapsedHeaders[craft], headerName)
        end
        local skill = ArtisanFrame.selectedSkill
        local skillName = Artisan_GetCraftInfo(ArtisanFrame.selectedSkill)
        local offset = getn(craftingSkills[craft][id].childs) or 0
        Artisan_UpdateSkillList()
        local first = Artisan_GetFirstCraft(craft)
        if first == 0 then
            skill = 0
        elseif id < ArtisanFrame.selectedSkill then
            skill = ArtisanFrame.selectedSkill - offset
            if first > skill or listContains(craftingSkills[craft][id].childs, nil, skillName) then
                skill = first
            end
        end
        Artisan_SetSelection(skill)
    end
    ArtisanFrame_Update()
end

function Artisan_ExpandCraftSkillLine(id)
    local craft = ArtisanFrame.selectedTabName
    local headerName = craftingSkills[craft][id].name
    local offset = getn(craftingSkills[craft][id].childs) or 0

    if craftingSkills[craft][id].type ~= "header" then
        return
    end

    if id == 0 then
        --expand all
        for i = 1, table.getn(craftingSkills[craft]) do
            if craftingSkills[craft][i].type == "header" then
                headerName = craftingSkills[craft][i].name
                if listContains(collapsedHeaders[craft], headerName) then
                    collapsedHeaders[craft][headerName] = nil
                end
            end
        end
        Artisan_UpdateSkillList()
        Artisan_SetSelection(Artisan_GetFirstCraft(craft))
    else
        --expand 1
        if listContains(collapsedHeaders[craft], headerName) then
            collapsedHeaders[craft][headerName] = nil
        end
        Artisan_UpdateSkillList()
        if id > ArtisanFrame.selectedSkill then
            if ArtisanFrame.selectedSkill ~= 0 then
                Artisan_SetSelection(ArtisanFrame.selectedSkill)
            else
                Artisan_SetSelection(Artisan_GetFirstCraft(craft))
            end
        else
            Artisan_SetSelection(ArtisanFrame.selectedSkill + offset)
        end
    end
    ArtisanFrame_Update()
end

function Artisan_UpdateSkillList()
    local craft = ArtisanFrame.selectedTabName
    craftingSkills[craft] = {}
    
    if not collapsedHeaders then
        collapsedHeaders = {}
    end
    if not collapsedHeaders[craft] then
        collapsedHeaders[craft] = {}
    end

    local numHeaders = 0
    if craft == "Enchanting" then
        craftingSkills[craft][0] = {name = "All", sub = "", type = "header", num = 0, exp = 1, tp = 0, lvl = 0, id = 0, childs= {}}
        numHeaders = 1
        local index = 1
        local headerIndex = 0
        for pattern, header in pairs(patternsToHeaders[craft]) do
            for i = 1, GetNumCrafts() do
                local craftName, craftSub, craftType, numAvailable, isExpanded, trainingPointCost, requiredLevel = GetCraftInfo(i)
                if strfind(strlower(craftName) or "", strlower(pattern)) then
                    numHeaders = numHeaders + 1
                    tinsert(craftingSkills[craft][0].childs, header)
                    craftingSkills[craft][index] = {name = "", sub = "", type = "", num = 0, exp = 0, tp = 0, lvl = 0, id = 0, childs = {}}
                    craftingSkills[craft][index].name = header
                    craftingSkills[craft][index].type = "header"
                    if not listContains(collapsedHeaders[craft], header) then
                        craftingSkills[craft][index].exp = 1
                    end
                    index = index + 1
                    headerIndex = index - 1
                    --if craftingSkills[craft][headerIndex].exp == 1 then
                        for j = 1, GetNumCrafts() do
                            local name, sub, type, num, exp, tp, lvl = GetCraftInfo(j)
                            if strfind(strlower(name) or "", strlower(pattern)) then
                                if craftingSkills[craft][headerIndex].exp == 1 then
                                    craftingSkills[craft][index] = {name = "", sub = "", type = "", num = 0, exp = 0, tp = 0, lvl = 0, id = 0}
                                    craftingSkills[craft][index].name = name
                                    craftingSkills[craft][index].sub = sub
                                    craftingSkills[craft][index].type = type
                                    craftingSkills[craft][index].num = num
                                    craftingSkills[craft][index].exp = exp
                                    craftingSkills[craft][index].tp = tp
                                    craftingSkills[craft][index].lvl = lvl
                                    craftingSkills[craft][index].id = j
                                    index = index + 1
                                end
                                tinsert(craftingSkills[craft][headerIndex].childs, name)
                                --craftingSkills[craft][headerIndex].childs = craftingSkills[craft][headerIndex].childs + 1
                            end
                        end
                    --end
                    break
                end
            end
        end
        --craftingSkills[craft][0].childs = numHeaders - 1
    elseif craft == "Beast Training" then
        local index = 1
        for i = 1, GetNumCrafts() do
            local name, sub, type, num, exp, tp, lvl = GetCraftInfo(i)
            if name then
                craftingSkills[craft][index] = {name = "", sub = "", type = "", num = 0, exp = 0, tp = 0, lvl = 0, id = 0}
                craftingSkills[craft][index].name = name
                craftingSkills[craft][index].sub = sub
                craftingSkills[craft][index].type = type
                craftingSkills[craft][index].num = num
                craftingSkills[craft][index].exp = exp
                craftingSkills[craft][index].tp = tp
                craftingSkills[craft][index].lvl = lvl
                craftingSkills[craft][index].id = i
                index = index + 1
            end
        end
    end

    return numHeaders
end

function Artisan_GetCraftInfo(index)
    local craft = ArtisanFrame.selectedTabName

    if not ArtisanFrame.selectedTabName then
        return
    end

    local craftName, craftSubSpellName, craftType, numAvailable, isExpanded, trainingPointCost, requiredLevel
    craftName = ""
    craftSubSpellName = ""
    craftType = ""
    numAvailable = 0
    isExpanded = 0
    trainingPointCost = 0
    requiredLevel = 0

    if craftingSkills[craft][index] then
        craftName = craftingSkills[craft][index].name or ""
        craftSubSpellName = craftingSkills[craft][index].sub or ""
        craftType = craftingSkills[craft][index].type or ""
        numAvailable = craftingSkills[craft][index].num or 0
        isExpanded = craftingSkills[craft][index].exp or 0
        trainingPointCost = craftingSkills[craft][index].tp or 0
        requiredLevel = craftingSkills[craft][index].lvl or 0
    end

    return craftName, craftSubSpellName, craftType, numAvailable, isExpanded, trainingPointCost, requiredLevel
end

function ArtisanFrame_Update()
    if not ArtisanFrame.selectedTabName then
        return
    end

    -- ArtisanSubClassDropDown:Hide()
    -- ArtisanInvSlotDropDown:Hide()
    ArtisanCollapseAllButton:Enable()

	local skillOffset = FauxScrollFrame_GetOffset(ArtisanListScrollFrame)
    local numTradeSkills, numCrafts
    local name, rank, maxRank
    local headers = 0
    if ArtisanFrame.craft then
        headers = Artisan_UpdateSkillList()
        ArtisanFrameBottomLeftTex:SetTexture("Interface\\ClassTrainerFrame\\UI-ClassTrainer-BotLeft")
        ArtisanFrameCreateButton:SetText(getglobal(GetCraftButtonToken()))
        ArtisanFrameCreateAllButton:Hide()
        ArtisanFrameDecrementButton:Hide()
        ArtisanFrameInputBox:Hide()
        ArtisanFrameIncrementButton:Hide()
        name, rank, maxRank = GetCraftDisplaySkillLine()
        numCrafts = table.getn(craftingSkills[ArtisanFrame.selectedTabName])
    else
        ArtisanFrameBottomLeftTex:SetTexture("Interface\\TradeSkillFrame\\UI-TradeSkill-BotLeft")
        ArtisanFrameCreateButton:SetText("Create")
        ArtisanFrameCreateAllButton:Show()
        ArtisanFrameDecrementButton:Show()
        ArtisanFrameInputBox:Show()
        ArtisanFrameIncrementButton:Show()
        numTradeSkills = GetNumTradeSkills()
        name, rank, maxRank = GetTradeSkillLine()
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

	if (not ArtisanFrame.craft and numTradeSkills < 0) or (ArtisanFrame.craft and (numCrafts - headers) < 0) then
		ArtisanSkillName:Hide()
        ArtisanSkillIcon:Hide()
		ArtisanRequirementLabel:Hide()
		ArtisanRequirementText:SetText("")
		for i=1, MAX_TRADE_SKILL_REAGENTS do
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

    -- Crafts (Beast Training / Enchanting)
    if ArtisanFrame.craft then
        local results = table.getn(searchResults)
        local skillsToUpdate = (results == 0 and numCrafts) or results
        FauxScrollFrame_Update(ArtisanListScrollFrame, skillsToUpdate, skillsDisplayed, craftSkillHeight, nil, nil, nil, ArtisanHighlightFrame, 293, 316 )

        local craftIndex, craftButton, craftButtonSubText, craftButtonCost
        for i=1, skillsDisplayed, 1 do
            craftIndex = 0
            if ArtisanFrameSearchBox:GetText() ~= "" then
                if results > 0 then
                    if searchResults[i + skillOffset] then
                        craftIndex = searchResults[i + skillOffset]
                    end
                else
                    craftIndex = -1
                end
            else
                craftIndex = i + skillOffset
            end

            local craftName, craftSubSpellName, craftType, numAvailable, isExpanded, trainingPointCost = Artisan_GetCraftInfo(craftIndex)
            
            craftButton = getglobal("ArtisanFrameSkill"..i)
            craftButtonSubText = getglobal("ArtisanFrameSkill"..i.."SubText")
            craftButtonCost = getglobal("ArtisanFrameSkill"..i.."Cost")
            craftButtonCost:Hide()

            if ( craftIndex > 0 and craftIndex <= numCrafts ) then
                -- Set button widths if scrollbar is shown or hidden
                if ( ArtisanListScrollFrame:IsVisible() ) then
                    craftButton:SetWidth(293)
                else
                    craftButton:SetWidth(323)
                end
                local color = TypeColor[craftType]
                craftButton:SetTextColor(color.r, color.g, color.b)
                craftButton.r = color.r
                craftButton.g = color.g
                craftButton.b = color.b
                craftButtonCost:SetTextColor(color.r, color.g, color.b)
                craftButtonSubText:SetTextColor(color.r, color.g, color.b)
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
                    getglobal("ArtisanFrameSkill"..i):UnlockHighlight()
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
                    if ( craftSubSpellName ~= "" ) then
                        craftButtonSubText:SetText(format(TEXT(PARENS_TEMPLATE), craftSubSpellName))
                    else
                        craftButtonSubText:SetText("")
                    end
                    -- TP
                    craftButtonCost:Hide()
                    if ArtisanFrame.selectedTabName == "Beast Training" and UnitName("pet") then
                        if ( trainingPointCost > 0 ) then
                            craftButtonCost:SetText(format(TRAINER_LIST_TP, trainingPointCost))
                            craftButtonCost:Show()
                        else
                            craftButtonCost:Hide()
                        end
                    end
                    craftButtonSubText:SetPoint("LEFT", "ArtisanFrameSkill"..i.."Text", "RIGHT", 10, 0)
                    -- Place the highlight and lock the highlight state
                    if (ArtisanFrame.selectedSkill == craftIndex ) then
                        ArtisanHighlightFrame:SetPoint("TOPLEFT", "ArtisanFrameSkill"..i, "TOPLEFT", 0, 0)
                        ArtisanHighlightFrame:Show()
                        craftButtonSubText:SetTextColor(1.0, 1.0, 1.0)
                        craftButtonCost:SetTextColor(1.0, 1.0, 1.0)
                        getglobal("ArtisanFrameSkill"..i):LockHighlight()
                    else
                        getglobal("ArtisanFrameSkill"..i):UnlockHighlight()
                    end
                end
            else
                craftButton:Hide()
            end
        end
        -- Set the expand/collapse all button texture
        local numHeaders = 0
        local notExpanded = 0
        for i=1, numCrafts, 1 do
            local craftName, craftSubSpellName, craftType, numAvailable, isExpanded = Artisan_GetCraftInfo(i)
            if ( craftName and craftType == "header" ) then
                numHeaders = numHeaders + 1
                if ( isExpanded == 0 ) then
                    notExpanded = notExpanded + 1
                end
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

    -- Trade Skills
    else
        local results = table.getn(searchResults)
	    local skillsToUpdate = results == 0 and numTradeSkills or results
        FauxScrollFrame_Update(ArtisanListScrollFrame, skillsToUpdate, skillsDisplayed, TRADE_SKILL_HEIGHT, nil, nil, nil, ArtisanHighlightFrame, 293, 316 )

        for i=1, skillsDisplayed do
            local skillIndex = 0
            if ArtisanFrameSearchBox:GetText() ~= "" then
                if results > 0 then
                    if searchResults[i + skillOffset] then
                        skillIndex = searchResults[i + skillOffset]
                    end
                else
                    skillIndex = -1
                end
            else
                skillIndex = i + skillOffset
            end
            local skillName, skillType, numAvailable, isExpanded = GetTradeSkillInfo(skillIndex)
            local skillButton = getglobal("ArtisanFrameSkill"..i)
            getglobal("ArtisanFrameSkill"..i.."SubText"):SetText("")
            getglobal("ArtisanFrameSkill"..i.."Cost"):SetText("")
            if ( skillIndex > 0 and skillIndex <= numTradeSkills ) then
                -- Set button widths if scrollbar is shown or hidden
                if ( ArtisanListScrollFrame:IsVisible() ) then
                    skillButton:SetWidth(293)
                else
                    skillButton:SetWidth(323)
                end
                local color = TypeColor[skillType]
                if ( color ) then
                    skillButton:SetTextColor(color.r, color.g, color.b)
                end
                skillButton:SetID(skillIndex)
                skillButton:Show()
                -- Handle headers
                if ( skillType == "header" ) then
                    skillButton:SetText(skillName)
                    if ( isExpanded ) then
                        skillButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
                    else
                        skillButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
                    end
                    getglobal("ArtisanFrameSkill"..i.."Highlight"):SetTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
                    getglobal("ArtisanFrameSkill"..i):UnlockHighlight()
                else
                    if ( not skillName ) then
                        return
                    end
                    skillButton:SetNormalTexture("")
                    getglobal("ArtisanFrameSkill"..i.."Highlight"):SetTexture("")
                    if ( numAvailable == 0 ) then
                        skillButton:SetText(" "..skillName)
                    else
                        skillButton:SetText(" "..skillName.." ["..numAvailable.."]")
                    end
                    -- Place the highlight and lock the highlight state
                    if ( GetTradeSkillSelectionIndex() == skillIndex ) then
                        ArtisanHighlightFrame:SetPoint("TOPLEFT", "ArtisanFrameSkill"..i, "TOPLEFT", 0, 0)
                        ArtisanHighlightFrame:Show()
                        getglobal("ArtisanFrameSkill"..i):LockHighlight()
                    else
                        getglobal("ArtisanFrameSkill"..i):UnlockHighlight()
                    end
                end
            else
                skillButton:Hide()
            end
        end
        -- Set the expand/collapse all button texture
        local numHeaders = 0
        local notExpanded = 0
        for i=1, numTradeSkills, 1 do
            local skillName, skillType, numAvailable, isExpanded = GetTradeSkillInfo(i)
            if ( skillName and skillType == "header" ) then
                numHeaders = numHeaders + 1
                if ( not isExpanded ) then
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
end

function Artisan_SetSelection(id)
    if not ArtisanFrame.selectedTabName then
        return
    end
    
    if ArtisanFrameSearchBox:GetText() ~= "" and table.getn(searchResults) == 0 then
        return
    end

    ArtisanHighlightFrame:Show()
    -- Crafts
    if ArtisanFrame.craft then
        local craftName, craftSubSpellName, craftType, numAvailable, isExpanded, trainingPointCost, requiredLevel = Artisan_GetCraftInfo(id)
        -- If the type of the selection is header, don't process all the craft details
        if ( craftType == "header" ) then
            ArtisanHighlightFrame:Hide()
            if (table.getn(searchResults) == 0) then
                if ( isExpanded == 1 ) then
                    Artisan_CollapseCraftSkillLine(id)
                else
                    Artisan_ExpandCraftSkillLine(id)
                end
            end
            return
        end

        ArtisanFrame.selectedSkill = id
        SelectCraft(id)

        if ( id > table.getn(craftingSkills[ArtisanFrame.selectedTabName]) ) then
            return
        end

        local color = TypeColor[craftType]
        if color then
            ArtisanHighlightTexture:SetVertexColor(color.r, color.g, color.b)
        end

        local originalID = craftingSkills[ArtisanFrame.selectedTabName][id].id
        ArtisanSkillName:SetText(craftName)
        ArtisanSkillIcon:SetNormalTexture(GetCraftIcon(originalID))
        ArtisanSkillCooldown:SetText("")
        ArtisanSkillIconCount:SetText("")

        if ( GetCraftDescription(originalID) and ArtisanFrame.selectedTabName == "Beast Training") then
            ArtisanCraftDescription:Show()
            ArtisanCraftDescription:SetText(GetCraftDescription(originalID))
        else
            ArtisanCraftDescription:Hide()
        end

        -- Reagents
        local creatable = 1
        local numReagents = GetCraftNumReagents(originalID)
        for i=1, numReagents, 1 do
            local reagentName, reagentTexture, reagentCount, playerReagentCount = GetCraftReagentInfo(originalID, i)
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
                    SetItemButtonTextureVertexColor(reagent, GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
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
        if ( numReagents > 0 ) then
            ArtisanReagentLabel:Show()
        else
            ArtisanReagentLabel:Hide()
        end
        for i=numReagents + 1, maxCraftReagents, 1 do
            getglobal("ArtisanReagent"..i):Hide()
        end

        local requiredTotems = BuildColoredListString(GetCraftSpellFocus(originalID))
        if ( requiredTotems ) then
            ArtisanRequirementLabel:Show()
            ArtisanRequirementText:SetText(requiredTotems)
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
    
        if ( trainingPointCost > 0 ) then
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
        else
            ArtisanFrameCreateButton:Disable()
        end
        
        Artisan_UpdateDetailScrollFrame(numReagents)
    -- Trade Skills
    else
        local skillName, skillType, numAvailable, isExpanded = GetTradeSkillInfo(id)
        if skillType == "header" then
            ArtisanHighlightFrame:Hide()
            if (table.getn(searchResults) == 0) then
                if isExpanded then
                    CollapseTradeSkillSubClass(id)
                else
                    ExpandTradeSkillSubClass(id)
                end
            end
            return
        end
        ArtisanFrame.selectedSkill = id
        SelectTradeSkill(id)
        if GetTradeSkillSelectionIndex() > GetNumTradeSkills() then
            return
        end
        local color = TypeColor[skillType]
        if color then
            ArtisanHighlightTexture:SetVertexColor(color.r, color.g, color.b)
        end

        ArtisanSkillName:SetText(skillName)
        ArtisanCraftCost:Hide()
        ArtisanCraftDescription:Hide()
        
        if GetTradeSkillCooldown(id) then
            ArtisanSkillCooldown:SetText(COOLDOWN_REMAINING.." "..SecondsToTime(GetTradeSkillCooldown(id)))
        else
            ArtisanSkillCooldown:SetText("")
        end
        ArtisanSkillIcon:SetNormalTexture(GetTradeSkillIcon(id))
        local minMade,maxMade = GetTradeSkillNumMade(id)
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
        -- Reagents
        local creatable = 1
        local numReagents = GetTradeSkillNumReagents(id)
        for i=1, numReagents, 1 do
            local reagentName, reagentTexture, reagentCount, playerReagentCount = GetTradeSkillReagentInfo(id, i)
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
        -- Place reagent label
        local reagentToAnchorTo = numReagents
        ArtisanReagentLabel:Show()
        if ( (numReagents > 0) and (mod(numReagents, 2) == 0) ) then
            reagentToAnchorTo = reagentToAnchorTo - 1
        end
        for i=numReagents + 1, MAX_TRADE_SKILL_REAGENTS, 1 do
            getglobal("ArtisanReagent"..i):Hide()
        end
        local spellFocus = BuildColoredListString(GetTradeSkillTools(id))
        if ( spellFocus ) then
            ArtisanRequirementLabel:Show()
            ArtisanRequirementText:SetText(spellFocus)
        else
            ArtisanRequirementLabel:Hide()
            ArtisanRequirementText:SetText("")
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
    for id = 1, max_tabs do
        tab = getglobal("ArtisanFrameSideTab"..id)
        if tab.name == ArtisanFrame.selectedTabName then
            getglobal("ArtisanFrameSideTab"..id):SetChecked(1)
        else
            getglobal("ArtisanFrameSideTab"..id):SetChecked(nil)
        end
    end
end

-- function ArtisanSubClassDropDown_OnLoad()
--     UIDropDownMenu_Initialize(this, ArtisanSubClassDropDown_Initialize)
--     UIDropDownMenu_SetSelectedID(ArtisanSubClassDropDown, 1)
-- end

-- function ArtisanSubClassDropDown_OnShow()
--     UIDropDownMenu_Initialize(this, ArtisanSubClassDropDown_Initialize)
-- 	UIDropDownMenu_SetSelectedID(ArtisanSubClassDropDown, 1)
-- end

-- function ArtisanSubClassDropDown_Initialize()
--     Artisan_LoadSubClasses(GetTradeSkillSubClasses())
-- end

-- function Artisan_LoadSubClasses(...)
--     local allChecked = GetTradeSkillSubClassFilter(0)
-- 	local info = {}
-- 	if ( arg.n > 1 ) then
-- 		info.text = TEXT(ALL_SUBCLASSES)
-- 		info.func = ArtisanSubClassDropDownButton_OnClick
-- 		info.checked = allChecked
-- 		UIDropDownMenu_AddButton(info)
-- 	end
	
-- 	local checked
-- 	for i=1, arg.n, 1 do
-- 		if ( allChecked and arg.n > 1 ) then
-- 			checked = nil
-- 			UIDropDownMenu_SetText(TEXT(ALL_SUBCLASSES), ArtisanSubClassDropDown)
-- 		else
-- 			checked = GetTradeSkillSubClassFilter(i)
-- 			if ( checked ) then
-- 				UIDropDownMenu_SetText(arg[i], ArtisanSubClassDropDown)
-- 			end
-- 		end
-- 		info = {}
-- 		info.text = arg[i]
-- 		info.func = ArtisanSubClassDropDownButton_OnClick
-- 		info.checked = checked
-- 		UIDropDownMenu_AddButton(info)
-- 	end
-- end

-- function ArtisanSubClassDropDownButton_OnClick()
--     UIDropDownMenu_SetSelectedID(ArtisanSubClassDropDown, this:GetID())
-- 	SetTradeSkillSubClassFilter(this:GetID() - 1, 1, 1)
--     ArtisanFrameSearchBox:ClearFocus()
--     if table.getn(searchResults) > 0 then
--         ArtisanFrameSkill1:Click()
--     end
--     ArtisanFrame_Search()
-- end

-- function ArtisanInvSlotDropDown_OnLoad()
-- 	UIDropDownMenu_Initialize(this, ArtisanInvSlotDropDown_Initialize)
-- 	UIDropDownMenu_SetSelectedID(ArtisanInvSlotDropDown, 1)
-- end

-- function ArtisanInvSlotDropDown_OnShow()
-- 	UIDropDownMenu_Initialize(this, ArtisanInvSlotDropDown_Initialize)
-- 	UIDropDownMenu_SetSelectedID(ArtisanInvSlotDropDown, 1)
-- end

-- function ArtisanInvSlotDropDown_Initialize()
-- 	Artisan_LoadInvSlots(GetTradeSkillInvSlots())
-- end

-- function Artisan_LoadInvSlots(...)
-- 	local allChecked = GetTradeSkillInvSlotFilter(0)
-- 	local info = {}
-- 	if ( arg.n > 1 ) then
-- 		info.text = TEXT(ALL_INVENTORY_SLOTS)
-- 		info.func = ArtisanInvSlotDropDownButton_OnClick
-- 		info.checked = allChecked
-- 		UIDropDownMenu_AddButton(info)
-- 	end
	
-- 	local checked
-- 	for i=1, arg.n, 1 do
-- 		if ( allChecked and arg.n > 1 ) then
-- 			checked = nil
-- 			UIDropDownMenu_SetText(TEXT(ALL_INVENTORY_SLOTS), ArtisanInvSlotDropDown)
-- 		else
-- 			checked = GetTradeSkillInvSlotFilter(i)
-- 			if ( checked ) then
-- 				UIDropDownMenu_SetText(arg[i], ArtisanInvSlotDropDown)
-- 			end
-- 		end
-- 		info = {}
-- 		info.text = arg[i]
-- 		info.func = ArtisanInvSlotDropDownButton_OnClick
-- 		info.checked = checked
-- 		UIDropDownMenu_AddButton(info)
-- 	end
-- end

-- function ArtisanInvSlotDropDownButton_OnClick()
-- 	UIDropDownMenu_SetSelectedID(ArtisanInvSlotDropDown, this:GetID())
-- 	SetTradeSkillInvSlotFilter(this:GetID() - 1, 1, 1)
--     ArtisanFrameSearchBox:ClearFocus()
--     ArtisanFrame_Search()
--     if table.getn(searchResults) > 0 then
--         ArtisanFrameSkill1:Click()
--     end
-- end

function ArtisanCollapseAllButton_OnClick()
	if (this.collapsed) then
		this.collapsed = nil
        ArtisanListScrollFrameScrollBar:SetValue(0)
        if ArtisanFrame.craft then
            Artisan_ExpandCraftSkillLine(0)
        else
            ExpandTradeSkillSubClass(0)
        end
	else
		this.collapsed = 1
		ArtisanListScrollFrameScrollBar:SetValue(0)
        if ArtisanFrame.craft then
            Artisan_CollapseCraftSkillLine(0)
        else
            CollapseTradeSkillSubClass(0)
        end
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
            ArtisanFrame.selectedSkill = Artisan_GetFirstCraft(this.name)
            CastSpellByName(this.name)
            Artisan_SetSelection(Artisan_GetFirstCraft(this.name))
        else
            ArtisanFrame.selectedSkill = GetFirstTradeSkill()
            CastSpellByName(this.name)
            Artisan_SetSelection(GetFirstTradeSkill())
        end
        ArtisanFrame.selectedTabName = this.name
    end

    for i = 1, max_tabs do
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

function Artisan_GetItemLink(index)
	if ArtisanFrame.craft then
        local originalID = craftingSkills[ArtisanFrame.selectedTabName][index].id
		return GetCraftItemLink(originalID)
	else
		return GetTradeSkillItemLink(index)
	end
end

function Artisan_GetReagentItemLink(index, id)
    if ArtisanFrame.craft then
        local originalIndex = craftingSkills[ArtisanFrame.selectedTabName][index].id
        return GetCraftReagentItemLink(originalIndex, id)
    else
        return GetTradeSkillReagentItemLink(index, id)
    end
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