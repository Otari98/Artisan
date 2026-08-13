Artisan.EditorSelectionLeft = {}
Artisan.EditorSelectionRight = {}
Artisan.EditorLastSelectedIndexLeft = {}
Artisan.EditorLastSelectedIndexRight = {}

StaticPopupDialogs["ARTISAN_HEADER_CREATE"] = {
    text = "Enter category name:",
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = 1,
    OnShow = function()
        _G[this:GetName().."EditBox"]:SetFocus()
        _G[this:GetName().."EditBox"]:SetText("")
        StaticPopup_Hide("ARTISAN_HEADER_RENAME")
    end,
    EditBoxOnEnterPressed = function()
        Artisan.CreateHeader(this:GetText())
        this:SetText("")
        this:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function()
        this:SetText("")
        this:GetParent():Hide()
    end,
    OnAccept = function()
        Artisan.CreateHeader(_G[this:GetParent():GetName().."EditBox"]:GetText())
    end,
    timeout = 0,
    exclusive = 1,
    whileDead = 1,
    hideOnEscape = 1,
}

StaticPopupDialogs["ARTISAN_HEADER_RENAME"] = {
    text = "Enter category name:",
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = 1,
    OnShow = function()
        _G[this:GetName().."EditBox"]:SetFocus()
        _G[this:GetName().."EditBox"]:SetText("")
        StaticPopup_Hide("ARTISAN_HEADER_CREATE")
    end,
    EditBoxOnEnterPressed = function()
        Artisan.RenameHeader(this:GetText())
        this:SetText("")
        this:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function()
        this:SetText("")
        this:GetParent():Hide()
    end,
    OnAccept = function()
        Artisan.RenameHeader(_G[this:GetParent():GetName().."EditBox"]:GetText())
    end,
    timeout = 0,
    exclusive = 1,
    whileDead = 1,
    hideOnEscape = 1,
}

local function tcontains(tbl, value)
    if type(tbl) ~= "table" then return nil end
    for k, v in pairs(tbl) do
        if v == value then return k end
    end
    return nil
end

local function GetSelectedHeader()
    if not Artisan.CustomCategories or not Artisan.EditorSelectionRight[Artisan.currentTab] then return nil, nil, nil end
    for i = table.getn(Artisan.CustomCategories), 1, -1 do
        if Artisan.CustomCategories[i].skillType == "header" then
            local index = tcontains(Artisan.EditorSelectionRight[Artisan.currentTab], Artisan.CustomCategories[i].skillName)
            if index then return Artisan.CustomCategories[i].skillName, i, index end
        end
    end
    return nil, nil, nil
end

local function ValidateSelection()
    local tab = Artisan.currentTab
    if not tab then return false, false, false, false end

    local canMoveLeft, canMoveRight, canMoveUp, canMoveDown = true, true, true, true
    local headersSelected = 0
    local nonheadersSelected = 0
    if table.getn(Artisan.EditorSelectionLeft[tab]) == 0 or table.getn(Artisan.CustomCategories) == 0 then
        canMoveRight = false
    end
    if table.getn(Artisan.EditorSelectionRight[tab]) == 0 then
        canMoveLeft, canMoveUp, canMoveDown = false, false, false
    else
        for i = 1, table.getn(Artisan.CustomCategories) do
            local name = Artisan.CustomCategories[i].skillName
            local subText = Artisan.CustomCategories[i].subText
            if subText then name = name.." "..format(PARENS_TEMPLATE, subText) end
            if tcontains(Artisan.EditorSelectionRight[tab], name) then
                local isHeader = Artisan.CustomCategories[i].skillType == "header"
                if isHeader then
                    headersSelected = headersSelected + 1
                else
                    nonheadersSelected = nonheadersSelected + 1
                end
                if i == table.getn(Artisan.CustomCategories) then canMoveDown = false end
                if i < (isHeader and 2 or 3) then canMoveUp = false end
                if i == 1 and canMoveDown then
                    for j = 2, table.getn(Artisan.CustomCategories) do
                        local name2 = Artisan.CustomCategories[j].skillName
                        local subText2 = Artisan.CustomCategories[j].subText
                        if subText2 then name2 = name2.." "..format(PARENS_TEMPLATE, subText2) end
                        if not tcontains(Artisan.EditorSelectionRight[tab], name2) then
                            canMoveDown = Artisan.CustomCategories[j].skillType == "header"
                            break
                        end
                    end
                end
            end
        end
        canMoveLeft = nonheadersSelected > 0
    end
    return canMoveLeft, canMoveRight, canMoveUp, canMoveDown, headersSelected, nonheadersSelected
end

function Artisan.EditorScrollFrameLeft_Update()
    local tab = Artisan.currentTab
    if not tab then return end
    local isCraft = Artisan.IsCraft()
    local buttons = ArtisanEditorScrollFrameLeft.buttons
    local numButtons = table.getn(buttons)
    local scrollOffset = FauxScrollFrame_GetOffset(ArtisanEditorScrollFrameLeft) or 0
    local numSkills = table.getn(Artisan.Uncategorized)
    local scrollBarShown = FauxScrollFrame_Update(ArtisanEditorScrollFrameLeft, numSkills, numButtons, 16, "ArtisanEditorSkillLeft", 242, 262)

    for i = 1, numButtons do
        local skillIndex = scrollOffset + i
        local skillButton = buttons[i]
        local data = Artisan.Uncategorized[skillIndex]
        if data and numSkills > 0 then
            local skillName, skillType, subText = data.skillName, data.skillType, data.subText
            skillButton:SetID(i)
            if subText and subText ~= "" then
                skillButton:SetText(skillName.." "..format(PARENS_TEMPLATE, subText))
            else
                skillButton:SetText(skillName)
            end
            if scrollBarShown then
                skillButton.Text:SetWidth(220)
            else
                skillButton.Text:SetWidth(235)
            end
            skillButton.skillName = skillButton:GetText()
            skillButton.skillType = skillType
            skillButton.skillIndex = skillIndex
            local color = Artisan.TradeSkillTypeColor[skillType]
            if color then
                skillButton:SetTextColor(color.r, color.g, color.b)
                skillButton.r = color.r
                skillButton.g = color.g
                skillButton.b = color.b
                skillButton.Highlight:SetVertexColor(color.r, color.g, color.b, 0.5)
            end
            if ArtisanConfig.icons then
                skillButton.Icon:SetTexture(isCraft and GetCraftIcon(data.id) or GetTradeSkillIcon(data.id))
                skillButton.Text:SetPoint("LEFT", skillButton.Icon, "RIGHT", 2, 1)
            else
                skillButton.Icon:SetTexture("")
                skillButton.Text:SetPoint("LEFT", skillButton, 2, 1)
            end
            if tcontains(Artisan.EditorSelectionLeft[tab], skillButton.skillName) then
                skillButton.Highlight:Show()
                skillButton:LockHighlight()
            else
                skillButton.Highlight:Hide()
                skillButton:UnlockHighlight()
            end
            skillButton:Show()
        else
            skillButton:Hide()
        end
    end
end

function Artisan.EditorScrollFrameRight_Update()
    local tab = Artisan.currentTab
    if not tab then return end
    local isCraft = Artisan.IsCraft()
    local buttons = ArtisanEditorScrollFrameRight.buttons
    local numButtons = table.getn(buttons)
    local scrollOffset = FauxScrollFrame_GetOffset(ArtisanEditorScrollFrameRight) or 0
    local numSkills = table.getn(Artisan.CustomCategories)
    local scrollBarShown = FauxScrollFrame_Update(ArtisanEditorScrollFrameRight, numSkills, numButtons, 16, "ArtisanEditorSkillRight", 242, 262)

    for i = 1, numButtons do
        local skillIndex = scrollOffset + i
        local skillButton = buttons[i]
        local data = Artisan.CustomCategories[skillIndex]
        if data and numSkills > 0 then
            local skillName, skillType, subText = data.skillName, data.skillType, data.subText
            skillButton:SetID(i)
            if subText and subText ~= "" then
                skillButton:SetText(skillName.." "..format(PARENS_TEMPLATE, subText))
            else
                skillButton:SetText(skillName)
            end
            if scrollBarShown then
                skillButton.Text:SetWidth(215)
            else
                skillButton.Text:SetWidth(230)
            end
            skillButton.skillName = skillButton:GetText()
            skillButton.skillType = skillType
            skillButton.skillIndex = skillIndex
            local color = Artisan.TradeSkillTypeColor[skillType]
            if color then
                skillButton:SetTextColor(color.r, color.g, color.b)
                skillButton.r = color.r
                skillButton.g = color.g
                skillButton.b = color.b
                skillButton.Highlight:SetVertexColor(color.r, color.g, color.b, 0.5)
            end
            if ArtisanConfig.icons then
                if skillType == "header" then
                    skillButton.Icon:SetTexture("")
                    skillButton.Text:SetPoint("LEFT", skillButton, 2, 1)
                else
                    skillButton.Icon:SetTexture(isCraft and GetCraftIcon(data.id) or GetTradeSkillIcon(data.id))
                    skillButton.Icon:SetPoint("LEFT", skillButton, 12, 0)
                    skillButton.Text:SetPoint("LEFT", skillButton.Icon, "RIGHT", 2, 1)
                end
            else
                if skillType == "header" then
                    skillButton.Icon:SetTexture("")
                    skillButton.Text:SetPoint("LEFT", skillButton, 2, 1)
                else
                    skillButton.Icon:SetTexture("")
                    skillButton.Text:SetPoint("LEFT", skillButton, 12, 1)
                end
            end
            if tcontains(Artisan.EditorSelectionRight[tab], skillButton.skillName) then
                skillButton.Highlight:Show()
                skillButton:LockHighlight()
            else
                skillButton.Highlight:Hide()
                skillButton:UnlockHighlight()
            end
            skillButton:Show()
        else
            skillButton:Hide()
        end
    end
end

function Artisan.UpdateEditor()
    local tab = Artisan.currentTab
    if not tab then return end

    Artisan.EditorScrollFrameLeft_Update()
    Artisan.EditorScrollFrameRight_Update()

    if not Artisan.EditorSelectionLeft[tab] then Artisan.EditorSelectionLeft[tab] = {} end
    if not Artisan.EditorSelectionRight[tab] then Artisan.EditorSelectionRight[tab] = {} end

    local canMoveLeft, canMoveRight, canMoveUp, canMoveDown, headersSelected = ValidateSelection()
    if canMoveLeft then
        ArtisanEditorMoveLeft:Enable()
    else
        ArtisanEditorMoveLeft:Disable()
    end
    if canMoveRight then
        ArtisanEditorMoveRight:Enable()
    else
        ArtisanEditorMoveRight:Disable()
    end
    if canMoveUp then
        AdrtisanEditorMoveUp:Enable()
    else
        AdrtisanEditorMoveUp:Disable()
    end
    if canMoveDown then
        AdrtisanEditorMoveDown:Enable()
    else
        AdrtisanEditorMoveDown:Disable()
    end

    if headersSelected == 1 then
        ArtisanEditorDeleteHeader:Enable()
        ArtisanEditorRenameHeader:Enable()
    else
        ArtisanEditorDeleteHeader:Disable()
        ArtisanEditorRenameHeader:Disable()
    end

    Artisan.EditorSearchBox_OnTextChanged(ArtisanEditorSearchBox)
end

function Artisan.EditorButtonLeft_OnClick(self, button)
    local skillName = self.skillName
    local skillIndex = self.skillIndex
    local tab = Artisan.currentTab
    if not Artisan.EditorSelectionLeft[tab] then Artisan.EditorSelectionLeft[tab] = {} end
    local selectionIndex = tcontains(Artisan.EditorSelectionLeft[tab], skillName)
    local multipleSelected = table.getn(Artisan.EditorSelectionLeft[tab]) > 1
    local lastSelectedIndex = Artisan.EditorLastSelectedIndexLeft[tab] or 1
    if selectionIndex then
        -- remove selection
        if IsControlKeyDown() then
            table.remove(Artisan.EditorSelectionLeft[tab], selectionIndex)
            Artisan.EditorLastSelectedIndexLeft[tab] = skillIndex
        elseif IsShiftKeyDown() then
            Artisan.wipe(Artisan.EditorSelectionLeft[tab])
            for i = min(lastSelectedIndex, skillIndex), max(lastSelectedIndex, skillIndex) do
                local name = Artisan.Uncategorized[i].skillName
                local subText = Artisan.Uncategorized[i].subText
                if subText then name = name.." "..format(PARENS_TEMPLATE, subText) end
                table.insert(Artisan.EditorSelectionLeft[tab], name)
            end
        else
            Artisan.wipe(Artisan.EditorSelectionLeft[tab])
            if multipleSelected then
                table.insert(Artisan.EditorSelectionLeft[tab], skillName)
            end
            Artisan.EditorLastSelectedIndexLeft[tab] = skillIndex
        end
    else
        -- add selection
        if IsControlKeyDown() then
            table.insert(Artisan.EditorSelectionLeft[tab], skillName)
            Artisan.EditorLastSelectedIndexLeft[tab] = skillIndex
        elseif IsShiftKeyDown() then
            Artisan.wipe(Artisan.EditorSelectionLeft[tab])
            for i = min(lastSelectedIndex, skillIndex), max(lastSelectedIndex, skillIndex) do
                local name = Artisan.Uncategorized[i].skillName
                local subText = Artisan.Uncategorized[i].subText
                if subText then name = name.." "..format(PARENS_TEMPLATE, subText) end
                table.insert(Artisan.EditorSelectionLeft[tab], name)
            end
        else
            Artisan.wipe(Artisan.EditorSelectionLeft[tab])
            table.insert(Artisan.EditorSelectionLeft[tab], skillName)
            Artisan.EditorLastSelectedIndexLeft[tab] = skillIndex
        end
    end

    Artisan.UpdateEditor()
end

function Artisan.EditorButtonRight_OnClick(self, button)
    local skillName = self.skillName
    local skillIndex = self.skillIndex
    local tab = Artisan.currentTab
    if not Artisan.EditorSelectionRight[tab] then Artisan.EditorSelectionRight[tab] = {} end
    local selectionIndex = tcontains(Artisan.EditorSelectionRight[tab], skillName)
    local multipleSelected = table.getn(Artisan.EditorSelectionRight[tab]) > 1
    local lastSelectedIndex = Artisan.EditorLastSelectedIndexRight[tab] or 1
    if selectionIndex then
        -- remove selection
        if IsControlKeyDown() then
            table.remove(Artisan.EditorSelectionRight[tab], selectionIndex)
            Artisan.EditorLastSelectedIndexRight[tab] = skillIndex
        elseif IsShiftKeyDown() then
            Artisan.wipe(Artisan.EditorSelectionRight[tab])
            for i = min(lastSelectedIndex, skillIndex), max(lastSelectedIndex, skillIndex) do
                local name = Artisan.CustomCategories[i].skillName
                local subText = Artisan.CustomCategories[i].subText
                if subText then name = name.." "..format(PARENS_TEMPLATE, subText) end
                table.insert(Artisan.EditorSelectionRight[tab], name)
            end
        else
            Artisan.wipe(Artisan.EditorSelectionRight[tab])
            if multipleSelected then
                table.insert(Artisan.EditorSelectionRight[tab], skillName)
            end
            Artisan.EditorLastSelectedIndexRight[tab] = skillIndex
        end
    else
        -- add selection
        if IsControlKeyDown() then
            table.insert(Artisan.EditorSelectionRight[tab], skillName)
            Artisan.EditorLastSelectedIndexRight[tab] = skillIndex
        elseif IsShiftKeyDown() then
            Artisan.wipe(Artisan.EditorSelectionRight[tab])
            for i = min(lastSelectedIndex, skillIndex), max(lastSelectedIndex, skillIndex) do
                local name = Artisan.CustomCategories[i].skillName
                local subText = Artisan.CustomCategories[i].subText
                if subText then name = name.." "..format(PARENS_TEMPLATE, subText) end
                table.insert(Artisan.EditorSelectionRight[tab], name)
            end
        else
            Artisan.wipe(Artisan.EditorSelectionRight[tab])
            table.insert(Artisan.EditorSelectionRight[tab], skillName)
            Artisan.EditorLastSelectedIndexRight[tab] = skillIndex
        end
    end
    Artisan.UpdateEditor()
end

function Artisan.EditorMoveRight_OnClick(self, button)
    local canMoveLeft, canMoveRight, canMoveUp, canMoveDown = ValidateSelection()
    if not canMoveRight then return end
    local tab = Artisan.currentTab
    local insertionIndex = table.getn(Artisan.CustomCategories) + 1
    for i = table.getn(Artisan.CustomCategories), 1, -1 do
        local name = Artisan.CustomCategories[i].skillName
        local subText = Artisan.CustomCategories[i].subText
        if subText then name = name.." "..format(PARENS_TEMPLATE, subText) end
        if tcontains(Artisan.EditorSelectionRight[tab], name) then
            insertionIndex = i + 1
            break
        end
    end
    for i = 1, table.getn(Artisan.Uncategorized) do
        local name = Artisan.Uncategorized[i].skillName
        local subText = Artisan.Uncategorized[i].subText
        if subText then name = name.." "..format(PARENS_TEMPLATE, subText) end
        if tcontains(Artisan.EditorSelectionLeft[tab], name) then
            table.insert(Artisan.CustomCategories, insertionIndex, Artisan.Uncategorized[i])
            insertionIndex = insertionIndex + 1
        end
    end
    Artisan.wipe(Artisan.EditorSelectionLeft[tab])
    Artisan.EditorLastSelectedIndexLeft[tab] = nil
    Artisan.EditorSaveChanges()
    Artisan.UpdateSkills()
    Artisan.UpdateEditor()
    Artisan.UpdateFrame()
end

function Artisan.EditorMoveLeft_OnClick(self, button)
    local canMoveLeft, canMoveRight, canMoveUp, canMoveDown = ValidateSelection()
    local tab = Artisan.currentTab
    if not canMoveLeft then return end
    for i = table.getn(Artisan.CustomCategories), 1, -1 do
        local name = Artisan.CustomCategories[i].skillName
        local subText = Artisan.CustomCategories[i].subText
        if subText then name = name.." "..format(PARENS_TEMPLATE, subText) end
        local index = tcontains(Artisan.EditorSelectionRight[tab], name)
        if index then
            if Artisan.CustomCategories[i].skillType ~= "header" then
                table.remove(Artisan.CustomCategories, i)
                table.remove(Artisan.EditorSelectionRight[tab], index)
            end
        end
    end
    Artisan.EditorSaveChanges()
    Artisan.UpdateSkills()
    Artisan.UpdateEditor()
    Artisan.UpdateFrame()
end

function Artisan.EditorMoveUp_OnClick(self, button)
    local canMoveLeft, canMoveRight, canMoveUp, canMoveDown = ValidateSelection()
    if not canMoveUp then return end
    local tab = Artisan.currentTab
    for i = 1, table.getn(Artisan.CustomCategories) do
        local name = Artisan.CustomCategories[i].skillName
        local subText = Artisan.CustomCategories[i].subText
        if subText then name = name.." "..format(PARENS_TEMPLATE, subText) end
        local selected = tcontains(Artisan.EditorSelectionRight[tab], name)
        if selected then
            if i < 2 then return end
            Artisan.CustomCategories[i - 1], Artisan.CustomCategories[i] = Artisan.CustomCategories[i], Artisan.CustomCategories[i - 1]
        end
    end
    Artisan.EditorLastSelectedIndexRight[tab] = Artisan.EditorLastSelectedIndexRight[tab] - 1
    Artisan.EditorSaveChanges()
    Artisan.UpdateSkills()
    Artisan.UpdateEditor()
    Artisan.UpdateFrame()
end

function Artisan.EditorMoveDown_OnClick(self, button)
    local canMoveLeft, canMoveRight, canMoveUp, canMoveDown = ValidateSelection()
    if not canMoveDown then return end
    local tab = Artisan.currentTab
    for i = table.getn(Artisan.CustomCategories), 1, -1 do
        local name = Artisan.CustomCategories[i].skillName
        local subText = Artisan.CustomCategories[i].subText
        if subText then name = name.." "..format(PARENS_TEMPLATE, subText) end
        local selected = tcontains(Artisan.EditorSelectionRight[tab], name)
        if selected then
            if i == table.getn(Artisan.CustomCategories) then return end
            Artisan.CustomCategories[i + 1], Artisan.CustomCategories[i] = Artisan.CustomCategories[i], Artisan.CustomCategories[i + 1]
        end
    end
    Artisan.EditorLastSelectedIndexRight[tab] = Artisan.EditorLastSelectedIndexRight[tab] + 1
    Artisan.EditorSaveChanges()
    Artisan.UpdateSkills()
    Artisan.UpdateEditor()
    Artisan.UpdateFrame()
end

function Artisan.CreateHeader(title)
    if Artisan.trim(title) == "" then return end
    for i = table.getn(Artisan.CustomCategories), 1, -1 do
        if Artisan.CustomCategories[i].skillName == title then
            return
        end
    end
    local insertionIndex = table.getn(Artisan.CustomCategories) + 1
    for i = table.getn(Artisan.CustomCategories), 1, -1 do
        local name = Artisan.CustomCategories[i].skillName
        local subText = Artisan.CustomCategories[i].subText
        if subText then name = name.." "..format(PARENS_TEMPLATE, subText) end
        if tcontains(Artisan.EditorSelectionRight[Artisan.currentTab], name) then
            insertionIndex = i + 1
            break
        end
    end
    table.insert(Artisan.CustomCategories, insertionIndex, { skillName = title, skillType = "header" })
    Artisan.EditorSaveChanges()
    Artisan.UpdateSkills()
    Artisan.UpdateEditor()
    Artisan.UpdateFrame()
end

function Artisan.DeleteHeader()
    local tab = Artisan.currentTab
    local selectedHeader, customIndex, selectionIndex = GetSelectedHeader()
    if not selectedHeader then return end
    local i = customIndex
    table.remove(Artisan.CustomCategories, i)
    while i <= table.getn(Artisan.CustomCategories) do
        if Artisan.CustomCategories[i] and Artisan.CustomCategories[i].skillType == "header" then break end
        table.remove(Artisan.CustomCategories, i)
    end
    Artisan.wipe(Artisan.EditorSelectionRight[tab])
    Artisan.EditorSaveChanges()
    Artisan.UpdateSkills()
    Artisan.UpdateEditor()
    Artisan.UpdateFrame()
end

function Artisan.RenameHeader(newName)
    local tab = Artisan.currentTab
    local selectedHeader, customIndex, selectionIndex = GetSelectedHeader()
    if not selectedHeader then return end
    Artisan.CustomCategories[customIndex].skillName = newName
    Artisan.EditorSelectionRight[tab][selectionIndex] = newName
    Artisan.EditorSaveChanges()
    Artisan.UpdateSkills()
    Artisan.UpdateEditor()
    Artisan.UpdateFrame()
end

function Artisan.EditorSaveChanges()
    local tab = Artisan.currentTab
    if not tab then return end
    if not ArtisanCustom[tab] then ArtisanCustom[tab] = {} end
    Artisan.wipe(ArtisanCustom[tab])
    for i = 1, table.getn(Artisan.CustomCategories) do
        local data = Artisan.CustomCategories[i]
        table.insert(ArtisanCustom[tab], {
            skillName = data.skillName,
            subText = data.subText ~= "" and data.subText or nil,
            isHeader = data.skillType == "header" or nil
        })
    end
end

function Artisan.EditorSearchBox_OnTextChanged(self, userInput)
    Artisan.UpdateSkills()
    local text = self:GetText()
    if text ~= "" then
        for i = table.getn(Artisan.Uncategorized), 1, -1 do
            local name = Artisan.Uncategorized[i].skillName
            local subText = Artisan.Uncategorized[i].subText
            if subText then name = name.." "..format(PARENS_TEMPLATE, subText) end
            if not string.find(string.lower(name), string.lower(text), 1, true) then
                table.remove(Artisan.Uncategorized, i)
            end
        end
    end
    Artisan.EditorScrollFrameLeft_Update()
end
