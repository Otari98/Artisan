_G = _G or getfenv(0)

Artisan = {}
Artisan.version = GetAddOnMetadata("Artisan", "Version")
Artisan.currentTab = nil
Artisan.selectedSkill = 0
Artisan.Tabs = {}
Artisan.Skills = {}
Artisan.Uncategorized = {}
Artisan.CustomCategories = {}
Artisan.CollapsedHeaders = {}

ArtisanConfig = {}
ArtisanCustom = {}

BINDING_HEADER_ARTISAN_TITLE = "Artisan"
BINDING_NAME_ARTISAN_CREATE = CREATE
BINDING_NAME_ARTISAN_CREATE_ALL = CREATE_ALL

local BLUE_FONT_COLOR_CODE = "|cff0070de"
local MAX_TABS = 7
local MAX_SKILLS = 12

Artisan.TabsOrder = {
    "Alchemy",
    "Blacksmithing",
    "Enchanting",
    "Engineering",
    "Leatherworking",
    "Tailoring",
    "Jewelcrafting",
    "Smelting",
    "First Aid",
    "Cooking",
    "Poisons",
    "Beast Training",
    "Survival",
    "Disguise",
}

Artisan.Patterns = {
    ["Enchanting"] = {
        ["bracer"] = "Bracer",
        ["boots"] = "Boots",
        ["gloves"] = "Gloves",
        ["2h weapon"] = "2H Weapon",
        ["enchant weapon"] = "Weapon",
        ["wand"] = "Wand",
        [" oil$"] = "Consumable",
        ["cloak"] = "Cloak",
        ["chest"] = "Chest",
        ["shield"] = "Shield",
    }
}

Artisan.TradeSkillTypeColor = {
    ["optimal"] = { r = 1.00, g = 0.50, b = 0.25 },
    ["medium"]  = { r = 1.00, g = 1.00, b = 0.00 },
    ["easy"]    = { r = 0.25, g = 0.75, b = 0.25 },
    ["trivial"] = { r = 0.50, g = 0.50, b = 0.50 },
    ["header"]  = { r = 1.00, g = 0.82, b = 0.00 },
    ["used"]    = { r = 0.50, g = 0.50, b = 0.50 },
    ["none"]    = { r = 0.25, g = 0.75, b = 0.25 },
}

Artisan.CraftsWithCooldown = {
    ["enchant:57518"] = { "item:61732", 259200 },
    -- ["enchant:7421"] = { "item:6218", 259200 },
}

local DoCraft_original = DoCraft
DoCraft = function(id)
    DoCraft_original(id)
    local link = string.gsub(GetCraftItemLink(id) or "", "^.*(enchant:%d+).*$", "%1")
    local duration = Artisan.CraftsWithCooldown[link] and Artisan.CraftsWithCooldown[link][2]
    if duration then
        ArtisanFrame:RegisterEvent("CHAT_MSG_LOOT")
    end
end

Artisan.wipe = function(tbl)
    if type(tbl) ~= "table" then return end
    for i = table.getn(tbl), 1, -1 do table.remove(tbl, i) end
    for k in pairs(tbl) do tbl[k] = nil end
end

Artisan.trim = function(s)
    return (string.gsub(s or "", "^%s*(.-)%s*$", "%1"))
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

function Artisan.OnLoad(self)
    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("UNIT_PORTRAIT_UPDATE")
    self:RegisterEvent("UPDATE_TRADESKILL_RECAST")
    self:RegisterEvent("TRADE_SKILL_SHOW")
    self:RegisterEvent("TRADE_SKILL_CLOSE")
    self:RegisterEvent("TRADE_SKILL_UPDATE")
    -- self:RegisterEvent("TRADE_SKILL_FILTER_UPDATE")
    self:RegisterEvent("REPLACE_ENCHANT")
    self:RegisterEvent("TRADE_REPLACE_ENCHANT")
    self:RegisterEvent("SKILL_LINES_CHANGED")
    self:RegisterEvent("CRAFT_SHOW")
    self:RegisterEvent("CRAFT_CLOSE")
    self:RegisterEvent("CRAFT_UPDATE")
    self:RegisterEvent("UNIT_PET_TRAINING_POINTS")
    table.insert(UISpecialFrames, "ArtisanFrame")
    ArtisanRankFrame:SetStatusBarColor(0.0, 0.0, 1.0, 0.5)
    ArtisanRankFrameBackground:SetVertexColor(0.0, 0.0, 0.75, 0.5)
    FauxScrollFrame_SetOffset(TradeSkillListScrollFrame, 0)
end

function Artisan.OnEvent(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= "Artisan" then return end
        self:UnregisterEvent("ADDON_LOADED")
        if not ArtisanConfig then ArtisanConfig = {} end
        if ArtisanConfig.auto == nil then ArtisanConfig.auto = true end
        if ArtisanConfig.icons == nil then ArtisanConfig.icons = true end
        if ArtisanConfig.movable == nil then ArtisanConfig.movable = false end
        if type(Artisan.Skills) ~= "table" then Artisan.Skills = {} end
        if type(ArtisanCustom) ~= "table" then ArtisanCustom = {} end
        if type(ArtisanConfig.sorting) ~= "table" then ArtisanConfig.sorting = {} end
        if type(ArtisanConfig.reagents) ~= "table" then ArtisanConfig.reagents = {} end
        if not ArtisanConfig.auto then
            self:UnregisterEvent("REPLACE_ENCHANT")
            self:UnregisterEvent("TRADE_REPLACE_ENCHANT")
        end
        if not ArtisanConfig.movable then
            UIPanelWindows["ArtisanFrame"] = { area = "left", pushable = 4 }
        else
            self:SetPoint("TOPLEFT", UIParent, "TOPLEFT", ArtisanConfig.X or 0, ArtisanConfig.Y or -104)
        end
        self:SetMovable(ArtisanConfig.movable)
    elseif event == "SKILL_LINES_CHANGED" then
        Artisan.UpdateTabs()
        if self:IsShown() then
            Artisan.UpdateFrame()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        SetPortraitTexture(ArtisanFramePortrait, "player")
        HideUIPanel(ArtisanFrame)
    elseif event == "UNIT_PORTRAIT_UPDATE" then
        if not self:IsShown() then return end
        if arg1 == "player" then
            SetPortraitTexture(ArtisanFramePortrait, "player")
        end
    elseif event == "UNIT_PET_TRAINING_POINTS" then
        if not self:IsShown() then return end
        if arg1 == "pet" then
            Artisan.UpdateTrainingPoints()
        end
    elseif event == "TRADE_SKILL_UPDATE" or event == "CRAFT_UPDATE" or event == "TRADE_SKILL_FILTER_UPDATE" then
        if not self:IsShown() then return end
        self.timer = event == "TRADE_SKILL_FILTER_UPDATE" and 0 or 0.2
    elseif event == "TRADE_SKILL_SHOW" or event == "CRAFT_SHOW" then
        ShowUIPanel(self)
        if not self:IsShown() then return end
        Artisan.currentTab = Artisan.GetTradeSkillLine()
        if event == "TRADE_SKILL_SHOW" then
            CloseCraft()
        elseif event == "CRAFT_SHOW" then
            CloseTradeSkill()
        end
        Artisan.UpdateSkills()
        if ArtisanConfig.sorting[Artisan.currentTab] ~= "CUSTOM" and ArtisanEditor:IsShown() then
            ArtisanEditor:Hide()
        end
        ArtisanFrameCreateButton:Disable()
        ArtisanFrameCreateAllButton:Disable()
        local selectionIndex = Artisan.GetTradeSkillSelectionIndex()
        if selectionIndex == 0 then
            Artisan.SetSelection(Artisan.GetFirstTradeSkill())
        else
            Artisan.SetSelection(selectionIndex)
        end
        FauxScrollFrame_SetOffset(ArtisanListScrollFrame, 0)
        ArtisanListScrollFrameScrollBar:SetMinMaxValues(0, 0)
        ArtisanListScrollFrameScrollBar:SetValue(0)
        SetPortraitTexture(ArtisanFramePortrait, "player")
        Artisan.UpdateFrame()
    elseif event == "TRADE_SKILL_CLOSE" or event == "CRAFT_CLOSE" then
        if not self:IsShown() then return end
        Artisan.currentTab = Artisan.GetTradeSkillLine()
        if not Artisan.IsCraft() and not Artisan.IsTradeSkill() then
            Artisan.currentTab = nil
            HideUIPanel(self)
        end
    elseif event == "UPDATE_TRADESKILL_RECAST" then
        if not self:IsShown() then return end
        ArtisanFrameInputBox:SetNumber(GetTradeskillRepeatCount())
    elseif event == "REPLACE_ENCHANT" then
        ReplaceEnchant()
        StaticPopup_Hide("REPLACE_ENCHANT")
    elseif event == "TRADE_REPLACE_ENCHANT" then
        ReplaceTradeEnchant()
        StaticPopup_Hide("TRADE_REPLACE_ENCHANT")
    elseif event == "CHAT_MSG_LOOT" then
        local _, _, itemLink = string.find(arg1 or "", (string.gsub(LOOT_ITEM_CREATED_SELF, "%%s", "(.+)")))
        local itemID = string.gsub(itemLink or "", "^.*(item:%d+).*$", "%1")
        if not itemID then return end
        for enchant, info in pairs(Artisan.CraftsWithCooldown) do
            if info[1] == itemID then
                if not ArtisanCustom.cd then ArtisanCustom.cd = {} end
                ArtisanCustom.cd[enchant] = time()
                self:UnregisterEvent("CHAT_MSG_LOOT")
                break
            end
        end
    end
end

function Artisan.OnUpdate(self, elapsed)
    if not self.timer then return end
    self.timer = self.timer - elapsed
    if self.timer <= 0 then
        self.timer = nil
        Artisan.currentTab = Artisan.GetTradeSkillLine()
        if not Artisan.currentTab then return end
        if not ArtisanConfig.sorting[Artisan.currentTab] then ArtisanConfig.sorting[Artisan.currentTab] = "DEFAULT" end
        Artisan.UpdateSkills()
        if ArtisanConfig.sorting[Artisan.currentTab] ~= "CUSTOM" and ArtisanEditor:IsShown() then
            ArtisanEditor:Hide()
        end
        ArtisanFrameCreateButton:Disable()
        ArtisanFrameCreateAllButton:Disable()
        local selectionIndex = Artisan.GetTradeSkillSelectionIndex()
        local firstSkill = Artisan.GetFirstTradeSkill()
        if selectionIndex >= firstSkill and selectionIndex <= Artisan.GetNumTradeSkills() then
            Artisan.SetSelection(selectionIndex)
        else
            Artisan.SetSelection(firstSkill)
            FauxScrollFrame_SetOffset(ArtisanListScrollFrame, 0)
            ArtisanListScrollFrameScrollBar:SetValue(0)
        end
        Artisan.UpdateFrame()
        if ArtisanEditor:IsShown() then
            Artisan.UpdateEditor()
        end
    end
end

function Artisan.UpdateTabs()
    local name, texture, offset, numSpells = GetSpellTabInfo(1)
    local numTabs = 0

    for i = 1, table.getn(Artisan.TabsOrder) do
        for spell = 1, numSpells do
            local spellName = GetSpellName(spell, BOOKTYPE_SPELL)
            if spellName == Artisan.TabsOrder[i] then
                numTabs = numTabs + 1
                if not Artisan.Tabs[numTabs] then Artisan.Tabs[numTabs] = {} end
                Artisan.Tabs[numTabs].name = spellName
                Artisan.Tabs[numTabs].texure = GetSpellTexture(spell, BOOKTYPE_SPELL)
                Artisan.Tabs[numTabs].spell = spell
                break
            end
        end
    end

    -- in case we abandoned skills
    for i = table.getn(Artisan.Tabs), numTabs + 1, -1 do table.remove(Artisan.Tabs, i) end

    for i = 1, MAX_TABS do
        local tabButton = _G["ArtisanFrameTab"..i]
        if i <= numTabs then
            tabButton.name = Artisan.Tabs[i].name
            tabButton:SetNormalTexture(Artisan.Tabs[i].texure)
            tabButton:Show()
            Artisan.Tabs[i].frame = tabButton
        else
            tabButton:Hide()
        end
    end

    if not ArtisanConfig.sorting then ArtisanConfig.sorting = {} end

    for _, v in pairs(Artisan.Tabs) do
        ArtisanConfig.sorting[v.name] = ArtisanConfig.sorting[v.name] or "DEFAULT"
        ArtisanConfig.reagents[v.name] = ArtisanConfig.reagents[v.name] or false
    end
end

function Artisan.UpdateFrame()
    local tab = Artisan.currentTab
    local numTradeSkills = Artisan.GetNumTradeSkills()
    local selectionIndex = Artisan.GetTradeSkillSelectionIndex()

    if numTradeSkills == 0 then
        ArtisanSkillName:Hide()
        ArtisanSkillIcon:Hide()
        ArtisanRequirementLabel:Hide()
        ArtisanRequirementText:Hide()
        ArtisanSkillDescription:SetText("")
        ArtisanSkillCost:SetText("")
        ArtisanCollapseAllButton:Disable()
        for i = 1, MAX_TRADE_SKILL_REAGENTS do
            _G["ArtisanReagent"..i]:Hide()
        end
    else
        ArtisanSkillName:Show()
        ArtisanSkillIcon:Show()
        ArtisanRequirementText:Show()
        ArtisanCollapseAllButton:Enable()
    end

    local skillLineName, skillLineRank, skillLineMaxRank = Artisan.GetTradeSkillLine()
    if skillLineMaxRank > 0 then
        ArtisanRankFrameSkillName:SetText(format(TRADE_SKILL_TITLE, skillLineName))
        ArtisanRankFrame:SetMinMaxValues(0, skillLineMaxRank)
        ArtisanRankFrame:SetValue(skillLineRank)
        ArtisanRankFrameSkillRank:SetText(skillLineRank.."/"..skillLineMaxRank)
        ArtisanRankFrame:Show()
        ArtisanFrameTitleText:Hide()
    else
        ArtisanFrameTitleText:SetText(skillLineName)
        ArtisanFrameTitleText:Show()
        ArtisanRankFrame:Hide()
    end

    if Artisan.IsCraft() then
        ArtisanFrameBottomLeftTexture:SetTexture("Interface\\AddOns\\Artisan\\Textures\\BottomLeft2")
        ArtisanFrameCreateButton:SetText(_G[GetCraftButtonToken()])
        ArtisanFrameCreateAllButton:Hide()
        ArtisanFrameDecrementButton:Hide()
        ArtisanFrameInputBox:Hide()
        ArtisanFrameIncrementButton:Hide()
    else
        ArtisanFrameBottomLeftTexture:SetTexture("Interface\\AddOns\\Artisan\\Textures\\BottomLeft")
        ArtisanFrameCreateButton:SetText(CREATE)
        ArtisanFrameCreateAllButton:Show()
        ArtisanFrameDecrementButton:Show()
        ArtisanFrameInputBox:Show()
        ArtisanFrameIncrementButton:Show()
    end

    ArtisanHighlightFrame:Hide()

    local numHeaders = 0
    local notExpanded = 0
    for i = 1, numTradeSkills do
        local skillName, skillType, numAvailable, isExpanded = Artisan.GetTradeSkillInfo(i)
        if skillName and skillType == "header" then
            numHeaders = numHeaders + 1
            if not isExpanded then notExpanded = notExpanded + 1 end
        end
        if selectionIndex == i then Artisan.numAvailable = math.abs(numAvailable or 0) end
    end
    if notExpanded ~= numHeaders then
        ArtisanCollapseAllButton.collapsed = false
        ArtisanCollapseAllButton:SetDisabledTexture("Interface\\Buttons\\UI-MinusButton-Disabled")
        ArtisanCollapseAllButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
    elseif numHeaders > 0 then
        ArtisanCollapseAllButton.collapsed = true
        ArtisanCollapseAllButton:SetDisabledTexture("Interface\\Buttons\\UI-PlusButton-Disabled")
        ArtisanCollapseAllButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
    end
    if numHeaders == 0 then
        -- ArtisanExpandButtonFrame:Hide()
        ArtisanCollapseAllButton:Disable()
    else
        -- ArtisanExpandButtonFrame:Show()
        ArtisanCollapseAllButton:Enable()
    end

    if tab ~= "Beast Training" then
        ArtisanHaveReagents:Show()
    else
        ArtisanHaveReagents:Hide()
    end

    FauxScrollFrame_Update(ArtisanListScrollFrame, numTradeSkills, MAX_SKILLS, TRADE_SKILL_HEIGHT, "ArtisanFrameSkill", 293, 316, ArtisanHighlightFrame, 293, 316)

    local hasPet = Artisan.UpdateTrainingPoints()
    local offset = FauxScrollFrame_GetOffset(ArtisanListScrollFrame)

    for i = 1, MAX_SKILLS do
        local skillIndex = i + offset
        local skillName, skillType, numAvailable, isExpanded, subText, trainingPointCost, requiredLevel = Artisan.GetTradeSkillInfo(skillIndex)
        local button = _G["ArtisanFrameSkill"..i]
        local buttonText = _G["ArtisanFrameSkill"..i.."Text"]
        local buttonCount = _G["ArtisanFrameSkill"..i.."Count"]
        local buttonIcon = _G["ArtisanFrameSkill"..i.."Icon"]
        local buttonSubText = _G["ArtisanFrameSkill"..i.."SubText"]
        local buttonCost = _G["ArtisanFrameSkill"..i.."Cost"]
        local buttonHighlight = _G["ArtisanFrameSkill"..i.."Highlight"]
        if skillIndex <= numTradeSkills then
            local color = Artisan.TradeSkillTypeColor[skillType]
            if color then
                button:SetTextColor(color.r, color.g, color.b)
                buttonSubText:SetTextColor(color.r, color.g, color.b)
                buttonCost:SetTextColor(color.r, color.g, color.b)
                buttonCount:SetVertexColor(color.r, color.g, color.b)
                button.r = color.r
                button.g = color.g
                button.b = color.b
            end
            button:SetID(skillIndex)
            button:Show()
            if skillType == "header" then
                buttonText:SetText(skillName)
                buttonText:SetPoint("LEFT", buttonHighlight, "RIGHT", 2, 1)
                buttonSubText:SetText("")
                buttonCost:SetText("")
                buttonCount:SetText("")
                if isExpanded then
                    button:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
                else
                    button:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
                end
                buttonHighlight:Show()
                button:UnlockHighlight()
                buttonIcon:SetTexture("")
            else
                if skillName then
                    button:SetNormalTexture("")
                    buttonHighlight:Hide()
                    if numAvailable == 0 then
                        buttonText:SetText(skillName)
                    else
                        buttonText:SetText(skillName.." ["..numAvailable.."]")
                    end
                    if ArtisanConfig.icons then
                        buttonIcon:SetTexture(Artisan.GetTradeSkillIcon(skillIndex))
                        buttonIcon:SetPoint("LEFT", button, "LEFT", numHeaders == 0 and 2 or 13, 0)
                        buttonText:SetPoint("LEFT", buttonIcon, "RIGHT", 2, 1)
                    else
                        buttonIcon:SetTexture("")
                        buttonText:SetPoint("LEFT", buttonHighlight, "RIGHT", numHeaders == 0 and -13 or 2, 1)
                    end
                    -- (Rank)
                    if subText then
                        buttonSubText:SetText(format(PARENS_TEMPLATE, subText))
                        buttonSubText:SetPoint("LEFT", buttonText, "RIGHT", 10, 0)
                    else
                        buttonSubText:SetText("")
                    end
                    -- TP
                    if hasPet and trainingPointCost and trainingPointCost > 0 then
                        buttonCost:SetText(format(TRAINER_LIST_TP, trainingPointCost))
                    else
                        buttonCost:SetText("")
                    end
                end
                if selectionIndex == skillIndex then
                    ArtisanHighlightFrame:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
                    ArtisanHighlightFrame:Show()
                    buttonCount:SetVertexColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
                    buttonSubText:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
                    buttonCost:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
                    button:LockHighlight()
                else
                    button:UnlockHighlight()
                end
            end
        else
            button:Hide()
        end
    end

    for i = 1, table.getn(Artisan.Tabs) do
        _G["ArtisanFrameTab"..i]:SetChecked(IsCurrentCast(Artisan.Tabs[i].spell, BOOKTYPE_SPELL))
    end

    local sorting = ArtisanConfig.sorting[tab] or "DEFAULT"
    ArtisanSortDefault:SetChecked(sorting == "DEFAULT")
    ArtisanSortCustom:SetChecked(sorting == "CUSTOM")
    ArtisanHaveReagents:SetChecked(ArtisanConfig.reagents[tab])
    if sorting == "CUSTOM" then
        ArtisanToggleEditorButton:Show()
    else
        ArtisanToggleEditorButton:Hide()
    end

    Artisan.EnableControls(not ArtisanEditor:IsShown())

    if C_TradeSkillUI and (C_TradeSkillUI.GetTradeSkillListLink() or C_TradeSkillUI.GetCraftListLink()) then
        ArtisanLinkButton:Show()
    else
        ArtisanLinkButton:Hide()
    end
end

function Artisan.UpdateTrainingPoints()
    local hasPetUI, canGainXP = HasPetUI()
    if hasPetUI and canGainXP and Artisan.currentTab == "Beast Training" then
        local totalPoints, spent = GetPetTrainingPoints()
        ArtisanFramePointsLabel:Show()
        ArtisanFramePointsText:Show()
        ArtisanFramePointsText:SetText(totalPoints - spent)
        return true
    else
        ArtisanFramePointsLabel:Hide()
        ArtisanFramePointsText:Hide()
        return false
    end
end

function Artisan.SetSelection(id)
    if not id then return end

    local skillName, skillType, numAvailable, isExpanded, subText, trainingPointCost, requiredLevel = Artisan.GetTradeSkillInfo(id)

    if skillType == "header" then
        if isExpanded then
            Artisan.CollapseTradeSkillSubClass(id)
        else
            Artisan.ExpandTradeSkillSubClass(id)
        end
        ArtisanHighlightFrame:Hide()
        return
    else
        ArtisanHighlightFrame:Show()
    end

    if id > Artisan.GetNumTradeSkills() then
        return
    end

    Artisan.SelectTradeSkill(id)
    Artisan.selectedSkill = id

    local color = Artisan.TradeSkillTypeColor[skillType]
    if color then
        ArtisanHighlightFrameTexture:SetVertexColor(color.r, color.g, color.b)
    end

    ArtisanSkillIcon:SetNormalTexture(Artisan.GetTradeSkillIcon(id))
    ArtisanSkillName:SetText(skillName)
    ArtisanSkillCost:SetText("")
    ArtisanSkillDescription:SetText("")

    local cooldown = Artisan.GetTradeSkillCooldown(id)
    if cooldown then
        ArtisanSkillCooldown:SetText(COOLDOWN_REMAINING.." "..SecondsToTime(cooldown))
    else
        ArtisanSkillCooldown:SetText("")
    end

    local minMade, maxMade = Artisan.GetTradeSkillNumMade(id)
    if maxMade > 1 then
        if minMade == maxMade then
            ArtisanSkillIconCount:SetText(minMade)
        else
            ArtisanSkillIconCount:SetText(minMade.."-"..maxMade)
        end
        if ArtisanSkillIconCount:GetWidth() > 39 then
            ArtisanSkillIconCount:SetText("~"..floor((minMade + maxMade) / 2))
        end
    else
        ArtisanSkillIconCount:SetText("")
    end

    local creatable = skillName and true or false
    local numReagents = Artisan.GetTradeSkillNumReagents(id)
    if numReagents > 0 then
        ArtisanReagentLabel:Show()
    else
        ArtisanReagentLabel:Hide()
    end
    for i = 1, MAX_TRADE_SKILL_REAGENTS do
        local reagentName, reagentTexture, reagentCount, playerReagentCount = Artisan.GetTradeSkillReagentInfo(id, i)
        local reagent = _G["ArtisanReagent"..i]
        local name = _G["ArtisanReagent"..i.."Name"]
        local count = _G["ArtisanReagent"..i.."Count"]
        if i <= numReagents then
            if not (reagentName and reagentTexture) then
                creatable = false
                reagent:Hide()
            else
                reagent:Show()
                SetItemButtonTexture(reagent, reagentTexture)
                name:SetText(reagentName)
                if playerReagentCount < reagentCount then
                    SetItemButtonTextureVertexColor(reagent, 0.5, 0.5, 0.5)
                    name:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
                    creatable = false
                else
                    SetItemButtonTextureVertexColor(reagent, 1.0, 1.0, 1.0)
                    name:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
                end
                if playerReagentCount >= 100 then
                    playerReagentCount = "*"
                end
                count:SetText(playerReagentCount.." /"..reagentCount)
            end
        else
            reagent:Hide()
        end
    end

    if skillType == "used" then
        creatable = false
    end

    if creatable then
        ArtisanFrameCreateButton:Enable()
        ArtisanFrameCreateAllButton:Enable()
    else
        ArtisanFrameCreateButton:Disable()
        ArtisanFrameCreateAllButton:Disable()
    end

    local spellFocus = BuildColoredListString(Artisan.GetTradeSkillTools(id))
    if spellFocus then
        ArtisanRequirementLabel:Show()
        ArtisanRequirementText:SetText(spellFocus)
    elseif requiredLevel and requiredLevel > 0 then
        if UnitLevel("pet") >= requiredLevel then
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

    local description = Artisan.GetTradeSkillDescription(id)
    if description and numReagents == 0 then
        ArtisanSkillDescription:SetText(description)
        ArtisanReagentLabel:SetPoint("TOPLEFT", "ArtisanSkillDescription", "BOTTOMLEFT", 3, -5)
    else
        ArtisanSkillDescription:SetText("")
        ArtisanReagentLabel:SetPoint("TOPLEFT", "ArtisanSkillIcon", "BOTTOMLEFT", 0, -5)
    end

    if trainingPointCost and trainingPointCost > 0 then
        local totalPoints, spent = GetPetTrainingPoints()
        local usablePoints = totalPoints - spent
        if usablePoints >= trainingPointCost then
            ArtisanSkillCost:SetText(COSTS_LABEL.." "..trainingPointCost.." "..TRAINING_POINTS_LABEL)
        else
            ArtisanSkillCost:SetText(COSTS_LABEL.." "..RED_FONT_COLOR_CODE..trainingPointCost..FONT_COLOR_CODE_CLOSE.." "..TRAINING_POINTS_LABEL)
        end
        ArtisanSkillCost:Show()
    else
        ArtisanSkillCost:Hide()
    end

    -- Reset the number of items to be created
    ArtisanFrameInputBox:SetNumber(GetTradeskillRepeatCount())

    -- if using aux addon, setup total reagent cost
    if aux_frame then
        local aux = require("aux")
        local info = require("aux.util.info")
        local money = require("aux.util.money")
        local history = require("aux.core.history")
        local total_cost = 0
        local today_cost = 0
        local function cost_label(cost, cost_other)
            local label = LIGHTYELLOW_FONT_COLOR_CODE..'(Total Cost: '..FONT_COLOR_CODE_CLOSE
            label = label..(cost and money.to_string2(cost, nil, LIGHTYELLOW_FONT_COLOR_CODE) or GRAY_FONT_COLOR_CODE..'?'..FONT_COLOR_CODE_CLOSE)
            if cost_other > 0 then
                label = label..LIGHTYELLOW_FONT_COLOR_CODE..' Today: '..FONT_COLOR_CODE_CLOSE..(cost_other and money.to_string2(cost_other, nil, LIGHTYELLOW_FONT_COLOR_CODE) or GRAY_FONT_COLOR_CODE..'?'..FONT_COLOR_CODE_CLOSE)
            end
            label = label..LIGHTYELLOW_FONT_COLOR_CODE..')'..FONT_COLOR_CODE_CLOSE
            return label
        end
        for i = 1, numReagents do
            local link = Artisan.GetTradeSkillReagentItemLink(id, i)
            if not link then
                total_cost = nil
                break
            end
            local item_id, suffix_id = info.parse_link(link)
            local count = aux.select(3, Artisan.GetTradeSkillReagentInfo(id, i))
            local _, price, limited = info.merchant_info(item_id)
            local value = price and not limited and price or history.value(item_id..':'..suffix_id)
            local market_value = history.market_value(item_id..':'..suffix_id) or 0
            if not value then
                total_cost = nil
                break
            else
                total_cost = total_cost + value * count
                today_cost = today_cost + market_value * count
            end
        end
        ArtisanReagentLabel:SetText(SPELL_REAGENTS..' '..cost_label(total_cost, today_cost))
    end
    ArtisanDetailScrollFrame:UpdateScrollChildRect()
end

local function GetSearchResult(data, textFilter)
    if not data then return false end
    if not data.skillName or data.skillName == "" then return false end
    if data.skillType == "header" then return false end
    for word in string.gfind(string.lower(textFilter), "%S+") do
        if not string.find(string.lower(data.skillName), word, 1, true) then return false end
    end
    return true
end

function Artisan.UpdateSkills()
    local tab = Artisan.currentTab
    local sorting = ArtisanConfig.sorting[tab]
    if not (tab and sorting) then return end
    if not Artisan.CollapsedHeaders[tab] then Artisan.CollapsedHeaders[tab] = {} end
    if not ArtisanCustom[tab] then ArtisanCustom[tab] = {} end

    local onlyShowMakeable = ArtisanConfig.reagents[tab]
    local textFilter = ArtisanFrameSearchBox:GetText()
    local isCraft = Artisan.IsCraft()
    local numSkills = isCraft and GetNumCrafts() or GetNumTradeSkills()
    local selectionName, selectionSubText
    if isCraft then
        selectionName, selectionSubText = GetCraftInfo(GetCraftSelectionIndex())
        if selectionSubText == "" then selectionSubText = nil end
    else
        selectionName = GetTradeSkillInfo(GetTradeSkillSelectionIndex())
    end

    Artisan.wipe(Artisan.Skills)

    if sorting == "DEFAULT" then
        local patterns = Artisan.Patterns[tab]
        if patterns and isCraft then
            for skill = numSkills, 1, -1 do
                local headerName = "Miscellaneous"
                local skillName, subText, skillType, numAvailable, isExpanded, trainingPointCost, requiredLevel = GetCraftInfo(skill)
                if subText == "" then subText = nil end
                for pattern, header in pairs(patterns) do
                    if string.find(string.lower(skillName), string.lower(pattern)) then
                        headerName = header
                        break
                    end
                end
                local insertionIndex = 0
                for index, value in pairs(Artisan.Skills) do
                    if value.skillType == "header" and value.skillName == headerName then
                        insertionIndex = index + 1
                        break
                    end
                end
                if insertionIndex == 0 then
                    table.insert(Artisan.Skills, 1, {
                        skillName = headerName,
                        skillType = "header",
                        numAvailable = 0,
                        isExpanded = not Artisan.CollapsedHeaders[tab][headerName] and 1 or nil,
                        id = nil,
                    })
                    insertionIndex = 2
                end
                table.insert(Artisan.Skills, insertionIndex, {
                    skillName = skillName,
                    skillType = skillType,
                    numAvailable = numAvailable,
                    isExpanded = nil,
                    subText = subText,
                    trainingPointCost = trainingPointCost,
                    requiredLevel = requiredLevel,
                    id = skill,
                })
            end
        elseif isCraft then
            for skill = 1, numSkills do
                local skillName, subText, skillType, numAvailable, isExpanded, trainingPointCost, requiredLevel = GetCraftInfo(skill)
                if subText == "" then subText = nil end
                table.insert(Artisan.Skills, {
                    skillName = skillName,
                    skillType = skillType,
                    numAvailable = numAvailable,
                    isExpanded = nil,
                    subText = subText,
                    trainingPointCost = trainingPointCost,
                    requiredLevel = requiredLevel,
                    id = skill,
                })
            end
        elseif not isCraft then
            for skill = 1, numSkills do
                local skillName, skillType, numAvailable, isExpanded = GetTradeSkillInfo(skill)
                table.insert(Artisan.Skills, {
                    skillName = skillName,
                    skillType = skillType,
                    numAvailable = numAvailable,
                    isExpanded = skillType == "header" and not Artisan.CollapsedHeaders[tab][skillName] and 1 or nil,
                    subText = nil,
                    trainingPointCost = 0,
                    requiredLevel = 0,
                    id = skill,
                })
            end
        end
    elseif sorting == "CUSTOM" then
        Artisan.wipe(Artisan.CustomCategories)
        -- copy custom headers from saved variable
        for i = 1, table.getn(ArtisanCustom[tab]) do
            local data = ArtisanCustom[tab][i]
            if data.isHeader then
                table.insert(Artisan.Skills, {
                    skillName = data.skillName,
                    skillType = "header",
                    numAvailable = 0,
                    isExpanded = not Artisan.CollapsedHeaders[tab][data.skillName] and 1 or nil,
                    id = nil,
                })
                table.insert(Artisan.CustomCategories, Artisan.Skills[table.getn(Artisan.Skills)])
            else
                for skill = 1, numSkills do
                    local skillName, skillType, numAvailable, isExpanded
                    local subText, trainingPointCost, requiredLevel
                    if isCraft then
                        skillName, subText, skillType, numAvailable, isExpanded, trainingPointCost, requiredLevel = GetCraftInfo(skill)
                        if subText == "" then subText = nil end
                    else
                        skillName, skillType, numAvailable, isExpanded = GetTradeSkillInfo(skill)
                    end
                    if skillName == data.skillName then
                        local insert = true
                        if data.subText and subText then
                            insert = data.subText == subText
                        end
                        if insert then
                            table.insert(Artisan.Skills, {
                                skillName = skillName,
                                skillType = skillType,
                                numAvailable = numAvailable,
                                isExpanded = nil,
                                subText = subText,
                                trainingPointCost = trainingPointCost,
                                requiredLevel = requiredLevel,
                                id = skill,
                            })
                            table.insert(Artisan.CustomCategories, Artisan.Skills[table.getn(Artisan.Skills)])
                            break
                        end
                    end
                end
            end
        end
        -- put remaining skills into uncategorized header
        table.insert(Artisan.Skills, {
            skillName = "Uncategorized",
            skillType = "header",
            numAvailable = 0,
            isExpanded = not Artisan.CollapsedHeaders[tab]["Uncategorized"] and 1 or nil,
            id = nil,
        })
        Artisan.wipe(Artisan.Uncategorized)
        for skill = 1, numSkills do
            local skillName, skillType, numAvailable, isExpanded
            local subText, trainingPointCost, requiredLevel
            if isCraft then
                skillName, subText, skillType, numAvailable, isExpanded, trainingPointCost, requiredLevel = GetCraftInfo(skill)
                if subText == "" then subText = nil end
            else
                skillName, skillType, numAvailable, isExpanded = GetTradeSkillInfo(skill)
            end
            if skillType ~= "header" then
                local addToUncategorized = true
                for k, v in pairs(Artisan.Skills) do
                    if subText and subText == v.subText and skillName == v.skillName then
                        addToUncategorized = false
                        break
                    elseif not subText and skillName == v.skillName then
                        addToUncategorized = false
                        break
                    end
                end
                if addToUncategorized then
                    table.insert(Artisan.Skills, {
                        skillName = skillName,
                        skillType = skillType,
                        numAvailable = numAvailable,
                        isExpanded = nil,
                        subText = subText,
                        trainingPointCost = trainingPointCost,
                        requiredLevel = requiredLevel,
                        id = skill,
                    })
                    table.insert(Artisan.Uncategorized, Artisan.Skills[table.getn(Artisan.Skills)])
                end
            end
        end
    end

    -- apply filters
    if onlyShowMakeable or textFilter ~= "" then
        for i = table.getn(Artisan.Skills), 1, -1 do
            local data = Artisan.Skills[i]
            local name = data.skillName
            if data.subText then name = name.." "..data.subText end
            name = string.lower(name)
            if (onlyShowMakeable and data.numAvailable == 0) or (textFilter ~= "" and not GetSearchResult(data, textFilter)) then
                table.remove(Artisan.Skills, i)
            end
        end
    end

    -- remove headers that dont contain any skills and collapsed headers
    local remove
    local i = 1
    while i <= table.getn(Artisan.Skills) do
        if Artisan.Skills[i].skillType == "header" then
            remove = not Artisan.Skills[i].isExpanded
            if (Artisan.Skills[i + 1] and Artisan.Skills[i + 1].skillType == "header") or not Artisan.Skills[i + 1] then
                table.remove(Artisan.Skills, i)
            else
                i = i + 1
            end
        else
            if remove then
                table.remove(Artisan.Skills, i)
            else
                i = i + 1
            end
        end
    end

    -- update selection index
    if selectionName then
        for i = 1, table.getn(Artisan.Skills) do
            local data = Artisan.Skills[i]
            if data.skillName == selectionName then
                if selectionSubText and data.subText then
                    if selectionSubText == data.subText then
                        Artisan.SelectTradeSkill(i)
                        return
                    end
                else
                    Artisan.SelectTradeSkill(i)
                    return
                end
            end
        end
    end
    Artisan.SelectTradeSkill(0)
end

function Artisan.DetailScrollFrame_OnScrollRangeChanged(self, xrange, yrange)
    local name = self:GetName()
    local scrollbar = _G[name.."ScrollBar"]
    local top = _G[name.."Top"]
    local bottom = _G[name.."Bottom"]
    if Artisan.GetTradeSkillNumReagents(Artisan.selectedSkill) <= 4 then
        yrange = 0
    end
    scrollbar:SetValue(0)
    ScrollFrame_OnScrollRangeChanged(yrange)
    if yrange == 0 then
        top:Hide()
        bottom:Hide()
    else
        top:Show()
        bottom:Show()
    end
end

function Artisan.SkillButton_OnClick(self, button)
    if IsShiftKeyDown() then
        local skillIndex = self:GetID()
        local skillType = Artisan.Skills[skillIndex].skillType
        local channel, chatNumber

        if not skillType or skillType == "header" or skillType == "none" or skillType == "used" then
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
        if not Artisan.IsCraft() then
            local minMade, maxMade = Artisan.GetTradeSkillNumMade(skillIndex)
            if maxMade ~= minMade then
                numMade = minMade.."-"..maxMade.."x"
            elseif minMade ~= 1 then
                numMade = minMade.."x"
            end
        end

        local itemLink = Artisan.GetTradeSkillItemLink(skillIndex)
        if not itemLink then return end

        local linksCount = 0
        local msg = ""

        SendChatMessage(numMade..itemLink.." reagents:", channel, nil, chatNumber)
        for reagentIndex = 1, Artisan.GetTradeSkillNumReagents(skillIndex) do
            local _, _, reagentsNeeded = Artisan.GetTradeSkillReagentInfo(skillIndex, reagentIndex)
            local reagentLink = Artisan.GetTradeSkillReagentItemLink(skillIndex, reagentIndex)
            if not reagentLink then return end
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
    elseif button == "LeftButton" then
        ArtisanDetailScrollFrame:SetVerticalScroll(0)
        Artisan.SetSelection(self:GetID())
        Artisan.UpdateFrame()
    end
    ArtisanFrameSearchBox:ClearFocus()
end

function Artisan.IncrementButton_OnClick(self, button)
    if ArtisanFrameInputBox:GetNumber() < 100 then
        ArtisanFrameInputBox:SetNumber(ArtisanFrameInputBox:GetNumber() + 1)
    end
    ArtisanFrameSearchBox:ClearFocus()
end

function Artisan.DecrementButton_OnClick(self, button)
    if ArtisanFrameInputBox:GetNumber() > 0 then
        ArtisanFrameInputBox:SetNumber(ArtisanFrameInputBox:GetNumber() - 1)
    end
    ArtisanFrameSearchBox:ClearFocus()
end

function Artisan.CollapseAllButton_OnClick(self, button)
    if self.collapsed then
        self.collapsed = false
        Artisan.ExpandTradeSkillSubClass(0)
    else
        self.collapsed = true
        ArtisanListScrollFrameScrollBar:SetValue(0)
        Artisan.CollapseTradeSkillSubClass(0)
    end
end

function Artisan.Tab_OnCLick(self, button)
    if not self.name then return end
    if self.name == Artisan.currentTab then
        self:SetChecked(true)
        return
    end
    if self.name ~= Artisan.currentTab then
        ArtisanDetailScrollFrame:SetVerticalScroll(0)
        Artisan.currentTab = self.name
        CastSpellByName(self.name)
        PlaySound("igCharacterInfoTab")
    end
end

function Artisan.HaveReagents_OnClick(self, button)
    ArtisanFrameSearchBox:ClearFocus()
    local checked = self:GetChecked() and true or false
    ArtisanConfig.reagents[Artisan.currentTab] = checked
    PlaySound("igMainMenuOptionCheckBoxOn")
    Artisan.OnEvent(ArtisanFrame, "TRADE_SKILL_FILTER_UPDATE")
end

function Artisan.SortDefault_OnClick(self, button)
    ArtisanFrameSearchBox:ClearFocus()
    local checked = self:GetChecked() and true or false
    if not checked then
        self:SetChecked(true)
        return
    end
    ArtisanConfig.sorting[Artisan.currentTab] = "DEFAULT"
    PlaySound("igMainMenuOptionCheckBoxOn")
    Artisan.OnEvent(ArtisanFrame, "TRADE_SKILL_FILTER_UPDATE")
    ArtisanEditor:Hide()
end

function Artisan.SortCustom_OnClick(self, button)
    ArtisanFrameSearchBox:ClearFocus()
    local checked = self:GetChecked() and true or false
    if not checked then
        self:SetChecked(true)
        return
    end
    ArtisanConfig.sorting[Artisan.currentTab] = "CUSTOM"
    PlaySound("igMainMenuOptionCheckBoxOn")
    Artisan.OnEvent(ArtisanFrame, "TRADE_SKILL_FILTER_UPDATE")
end

function Artisan.ToggleEditorButton_OnClick(self, button)
    ArtisanFrameSearchBox:ClearFocus()
    if ArtisanEditor:IsShown() then
        ArtisanEditor:Hide()
    else
        ArtisanEditor:Show()
    end
end

function Artisan.IsCraft()
    local tab = Artisan.currentTab
    return tab and (tab == "Enchanting" or tab == "Beast Training" or tab == "Disguise")
end

function Artisan.IsTradeSkill()
    local tab = Artisan.currentTab
    return tab and tab ~= "Enchanting" and tab ~= "Beast Training" and tab ~= "Disguise"
end

function Artisan.GetTradeSkillLine()
    local name
    local current, max = 0, 0
    name, current, max = GetTradeSkillLine()
    if max > 0 then return name, current, max end
    name, current, max = GetCraftDisplaySkillLine()
    if name and max > 0 then
        return name, current, max
    end
    name = GetCraftName()
    if name == "Beast Training" or name == "Disguise" or name == "Enchanting" then
        return name, current, max
    end
    return nil, 0, 0
end

function Artisan.GetNumTradeSkills()
    return table.getn(Artisan.Skills)
end

function Artisan.GetFirstTradeSkill()
    local id = 0
    for i = 1, table.getn(Artisan.Skills) do
        if Artisan.Skills[i].skillType and Artisan.Skills[i].skillType ~= "header" then
            return i
        end
    end
    return id
end

function Artisan.SelectTradeSkill(id)
    id = math.max(0, id)
    local isCraft = Artisan.IsCraft()
    id = Artisan.Skills[id] and Artisan.Skills[id].id or 0
    if isCraft then
        SelectCraft(id)
    else
        SelectTradeSkill(id)
    end
end

function Artisan.GetTradeSkillSelectionIndex()
    local isCraft = Artisan.IsCraft()
    local trueIndex = isCraft and GetCraftSelectionIndex() or GetTradeSkillSelectionIndex()
    local selectionIndex = trueIndex
    for index, data in pairs(Artisan.Skills) do
        if data.id == trueIndex then
            selectionIndex = index
            break
        end
    end
    return selectionIndex, trueIndex
end

function Artisan.GetTradeSkillInfo(id)
    if not id or id <= 0 then return nil, nil, 0, nil, nil, 0, 0 end
    local skillName, skillType, isExpanded, subText
    local numAvailable, trainingPointCost, requiredLevel = 0, 0, 0
    local data = Artisan.Skills[id]
    if data then
        skillName, skillType, numAvailable, isExpanded, subText, trainingPointCost, requiredLevel = data.skillName, data.skillType, data.numAvailable or 0, data.isExpanded, data.subText, data.trainingPointCost or 0, data.requiredLevel or 0
    end
    return skillName, skillType, numAvailable, isExpanded, subText, trainingPointCost, requiredLevel
end

function Artisan.GetTradeSkillIcon(id)
    if not id or id <= 0 then return nil end
    local isCraft = Artisan.IsCraft()
    id = Artisan.Skills[id] and Artisan.Skills[id].id or 0
    if isCraft then
        return GetCraftIcon(id)
    else
        return GetTradeSkillIcon(id)
    end
end

function Artisan.GetTradeSkillCooldown(id)
    local isCraft = Artisan.IsCraft()
    id = Artisan.Skills[id] and Artisan.Skills[id].id or 0
    if isCraft then
        if C_Spell then
            local spellID = GetCraftSpellID(id)
            local info = C_Spell.GetSpellCooldown(spellID or 0)
            if info then
                local cd = info.startTime + info.duration - GetTime()
                return cd > 0 and cd or nil
            end
        else
            local link = string.gsub(GetCraftItemLink(id) or "", "^.*(enchant:%d+).*$", "%1")
            local duration = Artisan.CraftsWithCooldown[link] and Artisan.CraftsWithCooldown[link][2]
            local startTime =  ArtisanCustom.cd and ArtisanCustom.cd[link]
            if startTime and duration then
                local cd = startTime + duration - time()
                return cd > 0 and cd or nil
            end
        end
        return nil
    else
        return GetTradeSkillCooldown(id)
    end
end

function Artisan.GetTradeSkillNumReagents(id)
    if not id or id <= 0 then return 0 end
    local isCraft = Artisan.IsCraft()
    id = Artisan.Skills[id] and Artisan.Skills[id].id or 0
    if isCraft then
        return GetCraftNumReagents(id)
    else
        return GetTradeSkillNumReagents(id)
    end
end

function Artisan.GetTradeSkillReagentInfo(id, i)
    if not (id and id > 0 and i and i > 0) then return nil, nil, nil, nil end
    local isCraft = Artisan.IsCraft()
    id = Artisan.Skills[id] and Artisan.Skills[id].id or 0
    if isCraft then
        return GetCraftReagentInfo(id, i)
    else
        return GetTradeSkillReagentInfo(id, i)
    end
end

function Artisan.GetTradeSkillTools(id)
    local isCraft = Artisan.IsCraft()
    id = Artisan.Skills[id] and Artisan.Skills[id].id or 0
    if isCraft then
        return GetCraftSpellFocus(id)
    else
        return GetTradeSkillTools(id)
    end
end

function Artisan.GetTradeSkillNumMade(id)
    local isCraft = Artisan.IsCraft()
    id = Artisan.Skills[id] and Artisan.Skills[id].id or 0
    if isCraft then
        return 1, 1
    else
        return GetTradeSkillNumMade(id)
    end
end

function Artisan.GetTradeSkillDescription(id)
    local isCraft = Artisan.IsCraft()
    id = Artisan.Skills[id] and Artisan.Skills[id].id or 0
    if isCraft then
        return GetCraftDescription(id)
    else
        return nil
    end
end

function Artisan.GetTradeSkillItemLink(id)
    if not id then return end
    local isCraft = Artisan.IsCraft()
    id = Artisan.Skills[id] and Artisan.Skills[id].id or 0
    if isCraft then
        return GetCraftItemLink(id)
    else
        return GetTradeSkillItemLink(id)
    end
end

function Artisan.GetTradeSkillReagentItemLink(id, i)
    if not id then return end
    local isCraft = Artisan.IsCraft()
    id = Artisan.Skills[id] and Artisan.Skills[id].id or 0
    if isCraft then
        return GetCraftReagentItemLink(id, i)
    else
        return GetTradeSkillReagentItemLink(id, i)
    end
end

function Artisan.CollapseTradeSkillSubClass(id)
    local tab = Artisan.currentTab
    if not Artisan.CollapsedHeaders[tab] then Artisan.CollapsedHeaders[tab] = {} end
    if id <= 0 then
        for i = 1, table.getn(Artisan.Skills) do
            if Artisan.Skills[i].skillType == "header" then
                Artisan.CollapsedHeaders[tab][Artisan.Skills[i].skillName] = true
            end
        end
        Artisan.OnEvent(ArtisanFrame, "TRADE_SKILL_FILTER_UPDATE")
    else
        if Artisan.Skills[id].skillType ~= "header" then return end
        Artisan.CollapsedHeaders[tab][Artisan.Skills[id].skillName] = true
        Artisan.OnEvent(ArtisanFrame, "TRADE_SKILL_FILTER_UPDATE")
    end
end

function Artisan.ExpandTradeSkillSubClass(id)
    local tab = Artisan.currentTab
    if not Artisan.CollapsedHeaders[tab] then Artisan.CollapsedHeaders[tab] = {} end
    if id <= 0 then
        for i = 1, table.getn(Artisan.Skills) do
            if Artisan.Skills[i].skillType == "header" then
                Artisan.CollapsedHeaders[tab][Artisan.Skills[i].skillName] = false
            end
        end
        Artisan.OnEvent(ArtisanFrame, "TRADE_SKILL_FILTER_UPDATE")
    else
        if Artisan.Skills[id].skillType ~= "header" then return end
        Artisan.CollapsedHeaders[tab][Artisan.Skills[id].skillName] = false
        Artisan.OnEvent(ArtisanFrame, "TRADE_SKILL_FILTER_UPDATE")
    end
end

function Artisan.EnableControls(enable)
    if enable then
        ArtisanHaveReagents:Enable()
        ArtisanFrameSearchBox:EnableMouse(true)
        ArtisanFrameSearchBox:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
        ArtisanFrameSearchBoxClearButton:Enable()
        ArtisanFrameSearchBoxClearButton:SetAlpha(0.6)
        ArtisanFrameSearchBoxIcon:SetAlpha(0.6)
        for i = 1, MAX_SKILLS do
            _G["ArtisanFrameSkill"..i]:EnableMouse(true)
            _G["ArtisanFrameSkill"..i]:SetAlpha(1)
        end
        ArtisanCollapseAllButton:EnableMouse(true)
        ArtisanCollapseAllButton:SetAlpha(1)
        ArtisanListScrollFrameScrollBar:EnableMouse(true)
        ArtisanListScrollFrameScrollBarScrollUpButton:Enable()
        ArtisanListScrollFrameScrollBarScrollDownButton:Enable()
        ArtisanListScrollFrame:EnableMouseWheel(true)
    else
        ArtisanHaveReagents:Disable()
        ArtisanFrameSearchBox:EnableMouse(false)
        ArtisanFrameSearchBox:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
        ArtisanFrameSearchBoxClearButton:Disable()
        ArtisanFrameSearchBoxClearButton:SetAlpha(0.3)
        ArtisanFrameSearchBoxIcon:SetAlpha(0.3)
        for i = 1, MAX_SKILLS do
            _G["ArtisanFrameSkill"..i]:EnableMouse(false)
            _G["ArtisanFrameSkill"..i]:SetAlpha(0.5)
        end
        ArtisanCollapseAllButton:EnableMouse(false)
        ArtisanCollapseAllButton:SetAlpha(0.5)
        ArtisanListScrollFrameScrollBar:EnableMouse(false)
        ArtisanListScrollFrameScrollBarScrollUpButton:Disable()
        ArtisanListScrollFrameScrollBarScrollDownButton:Disable()
        ArtisanListScrollFrame:EnableMouseWheel(false)
    end
end

function Artisan.SkillIcon_OnEnter(self)
    local _, trueSkill = Artisan.GetTradeSkillSelectionIndex()
    if trueSkill ~= 0 then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if Artisan.IsCraft() then
            GameTooltip:SetCraftSpell(trueSkill)
        else
            GameTooltip:SetTradeSkillItem(trueSkill)
        end
        CursorUpdate(self)
    end
end

function Artisan.SkillIcon_OnClick(self, button)
    Artisan.Item_OnClick(self, button, Artisan.GetTradeSkillItemLink(Artisan.selectedSkill))
end

function Artisan.Reagent_OnEnter(self)
    local _, trueSkill = Artisan.GetTradeSkillSelectionIndex()
    if trueSkill ~= 0 then
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        if Artisan.IsCraft() then
            GameTooltip:SetCraftItem(trueSkill, self:GetID())
        else
            GameTooltip:SetTradeSkillItem(trueSkill, self:GetID())
        end
        CursorUpdate(self)
    end
end

function Artisan.Reagent_OnClick(self, button)
    Artisan.Item_OnClick(self, button, Artisan.GetTradeSkillReagentItemLink(Artisan.selectedSkill, self:GetID()))
end

function Artisan.Item_OnClick(self, button, link)
    if not link then return end
    if button == "RightButton" then
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

function Artisan.TradeSkillFilter_OnTextChanged(self)
    if self:IsMouseEnabled() then
        Artisan.OnEvent(ArtisanFrame, "TRADE_SKILL_FILTER_UPDATE")
    end
end

function Artisan.OnMouseDown(self, button)
    ArtisanFrameSearchBox:ClearFocus()
    if ArtisanFrame:IsMovable() then
        ArtisanFrame:StartMoving()
    end
end

function Artisan.OnMouseUp(self, button)
    if ArtisanFrame:IsMovable() then
        ArtisanFrame:StopMovingOrSizing()
        local point, relativeTo, relativePoint, offsetX, offsetY = ArtisanFrame:GetPoint()
        ArtisanConfig.X = offsetX
        ArtisanConfig.Y = offsetY
    end
end


SLASH_ARTISAN1 = "/artisan"

SlashCmdList["ARTISAN"] = function(cmd)
    local function status(parameter)
        local str = ""
        if parameter then
            str = "("..GREEN_FONT_COLOR_CODE.."ON|r)"
        else
            str = "("..GRAY_FONT_COLOR_CODE.."OFF|r)"
        end
        return str
    end
    cmd = string.lower(Artisan.trim(cmd))
    if cmd == "auto" then
        if ArtisanConfig.auto then
            ArtisanConfig.auto = false
            ArtisanFrame:UnregisterEvent("REPLACE_ENCHANT")
            ArtisanFrame:UnregisterEvent("TRADE_REPLACE_ENCHANT")
        else
            ArtisanConfig.auto = true
            ArtisanFrame:RegisterEvent("REPLACE_ENCHANT")
            ArtisanFrame:RegisterEvent("TRADE_REPLACE_ENCHANT")
        end
        DEFAULT_CHAT_FRAME:AddMessage(BLUE_FONT_COLOR_CODE.."[Artisan]|r auto confirmation is now "..status(ArtisanConfig.auto))
    elseif cmd == "icons" then
        if ArtisanConfig.icons then
            ArtisanConfig.icons = false
        else
            ArtisanConfig.icons = true
        end
        DEFAULT_CHAT_FRAME:AddMessage(BLUE_FONT_COLOR_CODE.."[Artisan]|r skill icons is now "..status(ArtisanConfig.icons))
    elseif cmd == "movable" then
        HideUIPanel(ArtisanFrame)
        if ArtisanConfig.movable then
            ArtisanConfig.movable = false
            UIPanelWindows["ArtisanFrame"] = { area = "left", pushable = 4 }
            ArtisanFrame:ClearAllPoints()
            ArtisanFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
        else
            ArtisanConfig.movable = true
            UIPanelWindows["ArtisanFrame"] = nil
            local point, relativeTo, relativePoint, offsetX, offsetY = ArtisanFrame:GetPoint()
            ArtisanConfig.X = offsetX
            ArtisanConfig.Y = offsetY
        end
        ArtisanFrame:SetMovable(ArtisanConfig.movable)
        DEFAULT_CHAT_FRAME:AddMessage(BLUE_FONT_COLOR_CODE.."[Artisan]|r movable window is now "..status(ArtisanConfig.movable))
    else
        DEFAULT_CHAT_FRAME:AddMessage(BLUE_FONT_COLOR_CODE.."[Artisan]|r version "..GetAddOnMetadata("Artisan", "version"))
        DEFAULT_CHAT_FRAME:AddMessage(NORMAL_FONT_COLOR_CODE.."/artisan auto|r - auto confirmation of enchant replacements "..status(ArtisanConfig.auto))
        DEFAULT_CHAT_FRAME:AddMessage(NORMAL_FONT_COLOR_CODE.."/artisan icons|r - icons next to skill names "..status(ArtisanConfig.icons))
        DEFAULT_CHAT_FRAME:AddMessage(NORMAL_FONT_COLOR_CODE.."/artisan movable|r - movable window "..status(ArtisanConfig.movable))
    end
end
