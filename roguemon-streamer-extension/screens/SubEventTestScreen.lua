-- SubEventTestScreen.lua
-- Dedicated menu to simulate Twitch Sub/Gift events by writing to Tracker-Requests.json.

local print = RoguemonStreamer.print

SubEventTestScreen = {
    Colors = {
        text = "Lower box text",
        highlight = "Intermediate text",
        border = "Lower box border",
        boxFill = "Lower box background",
    },
    Tabs = {
        Cumulative = 1,
        Milestones = 2,
    },
    Outcomes = {
        Good = 1,
        Bad = 2,
    },
    currentTab = 1,
    currentOutcome = 1,
    currentMilestone = 5,
    currentPage = 1,
}

local positive_cum = {
    "Restore PP", "Cure Status", "Restore HP",
    "Give Healing Item", "Give Status Item", "Give PP Item", "Stat Boost",
    "Power Boost", "Speed Boost", "PP Up"
}

local negative_cum = {
    "Inflict Status", "Disable Move", "Power Debuff", "Speed Debuff",
    "PP Cut", "Stat Debuff", "Temp Type Change",
    "Remove Healing Item", "Remove Status Item", "Overwhelmed"
}

local positive_m5 = {
    "Restore PP", "Give Healing Item", "Give Utility Item", "Give PP Item", "Stat Boost",
    "Permanent Type Change", "Permanent Nature Change", "Permanent Ability Change",
    "Powerhouse Boost", "No Guard Plus", "Turbo Genetics", "Evolution Power", "Let's Dance",
    "Full Restore", "Game Changer", "Try Harder"
}

local negative_m5 = {
    "Overwhelmed", "Disable Move", "Stat Debuff", "PP Deplete",
    "Permanent Type Change", "Permanent Nature Change", "Permanent Ability Change",
    "Remove Big Healing Item", "Remove Utility Item", "Out of Control",
    "No Guard Minus", "Mystification", "Let's Dance"
}

local positive_m10 = {
    "Give Healing Item", "Give Utility Items", "Give PP Item", "Stat Boost",
    "Permanent Type Change", "Permanent Nature Change", "Permanent Ability Change",
    "Powerhouse Boost", "No Guard Plus", "Omniboost", "Evolution Power", "Turbo Genetics", "Game Changer", "Try Harder", "Let's Dance",
    "Full Restore", "Increase Healing Limit", "Increase Status Limit", "Darwinism"
}

local negative_m10 = {
    "Disable Move", "Stat Debuff", "PP Deplete",
    "Permanent Type Change", "Permanent Nature Change", "Permanent Ability Change",
    "Remove Big Healing Item", "Remove Utility Items", "No Guard Minus", "Let's Dance",
    "Out of Control", "Omnimalus", "Mystification", "Overwhelmed"
}

local positive_m50 = {
    "Give Healing Item", "Give Utility Items", "Give PP Item",
    "Permanent Type Change", "Permanent Nature Change", "Permanent Ability Change",
    "Powerhouse Boost", "No Guard Plus", "Omniboost", "Game Changer", "Try Harder", "Let's Dance",
    "Increase Healing Limit", "Increase Status Limit", "Darwinism"
}

local negative_m50 = {
    "Disable Move", "Stat Debuff", "PP Deplete",
    "Permanent Type Change", "Permanent Nature Change", "Permanent Ability Change",
    "Remove Big Healing Item", "Remove Utility Items", "No Guard Minus", "Overwhelmed",
    "Out of Control", "Omnimalus", "Mystification"
}

local function getActiveKeys()
    if SubEventTestScreen.currentTab == SubEventTestScreen.Tabs.Cumulative then
        if SubEventTestScreen.currentOutcome == SubEventTestScreen.Outcomes.Good then
            return positive_cum
        else
            return negative_cum
        end
    else
        local isGood = (SubEventTestScreen.currentOutcome == SubEventTestScreen.Outcomes.Good)
        if SubEventTestScreen.currentMilestone == 5 then
            return isGood and positive_m5 or negative_m5
        elseif SubEventTestScreen.currentMilestone == 50 then
            return isGood and positive_m50 or negative_m50
        else
            return isGood and positive_m10 or negative_m10
        end
    end
end

local function getItemsPerPage()
    if SubEventTestScreen.currentTab == SubEventTestScreen.Tabs.Cumulative then
        return 5
    else
        return 4
    end
end

local function getEventKeyForButton(btnIndex)
    local keys = getActiveKeys()
    local ipp = getItemsPerPage()
    local index = (SubEventTestScreen.currentPage - 1) * ipp + btnIndex
    return keys[index]
end

SubEventTestScreen.Buttons = {
    -- TABS
    TabCumulative = {
        type = Constants.ButtonTypes.NO_BORDER,
        getText = function(self) return "Cumulative" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 5, Constants.SCREEN.MARGIN + 10, 58, 12 },
        updateSelf = function(self)
            self.isSelected = (SubEventTestScreen.currentTab == SubEventTestScreen.Tabs.Cumulative)
            self.textColor = self.isSelected and SubEventTestScreen.Colors.highlight or SubEventTestScreen.Colors.text
        end,
        draw = function(self, shadowcolor)
            local x, y = self.box[1], self.box[2]
            local w, h = self.box[3], self.box[4]
            local color = Theme.COLORS[self.boxColors[1]]
            local bgColor = Theme.COLORS[self.boxColors[2]]
            gui.drawRectangle(x + 1, y + 1, w - 1, h - 2, bgColor, bgColor)
            if not self.isSelected then
                gui.drawRectangle(x + 1, y + 1, w - 1, h - 2, Drawing.ColorEffects.DARKEN, Drawing.ColorEffects.DARKEN)
            end
            gui.drawLine(x + 1, y, x + w - 1, y, color)
            gui.drawLine(x, y + 1, x, y + h - 1, color)
            gui.drawLine(x + w, y + 1, x + w, y + h - 1, color)
            if self.isSelected then
                gui.drawLine(x + 1, y + h, x + w - 1, y + h, bgColor)
            end
            local centeredOffsetX = Utils.getCenteredTextX("Cumulative", w) - 2
            Drawing.drawText(x + centeredOffsetX, y, "Cumulative", Theme.COLORS[self.textColor], shadowcolor)
        end,
        onClick = function(self)
            SubEventTestScreen.currentTab = SubEventTestScreen.Tabs.Cumulative
            SubEventTestScreen.currentPage = 1
            SubEventTestScreen.refreshButtons()
            Program.redraw(true)
        end,
    },
    TabMilestones = {
        type = Constants.ButtonTypes.NO_BORDER,
        getText = function(self) return "Milestones" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 68, Constants.SCREEN.MARGIN + 10, 58, 12 },
        updateSelf = function(self)
            self.isSelected = (SubEventTestScreen.currentTab == SubEventTestScreen.Tabs.Milestones)
            self.textColor = self.isSelected and SubEventTestScreen.Colors.highlight or SubEventTestScreen.Colors.text
        end,
        draw = function(self, shadowcolor)
            local x, y = self.box[1], self.box[2]
            local w, h = self.box[3], self.box[4]
            local color = Theme.COLORS[self.boxColors[1]]
            local bgColor = Theme.COLORS[self.boxColors[2]]
            gui.drawRectangle(x + 1, y + 1, w - 1, h - 2, bgColor, bgColor)
            if not self.isSelected then
                gui.drawRectangle(x + 1, y + 1, w - 1, h - 2, Drawing.ColorEffects.DARKEN, Drawing.ColorEffects.DARKEN)
            end
            gui.drawLine(x + 1, y, x + w - 1, y, color)
            gui.drawLine(x, y + 1, x, y + h - 1, color)
            gui.drawLine(x + w, y + 1, x + w, y + h - 1, color)
            if self.isSelected then
                gui.drawLine(x + 1, y + h, x + w - 1, y + h, bgColor)
            end
            local centeredOffsetX = Utils.getCenteredTextX("Milestones", w) - 2
            Drawing.drawText(x + centeredOffsetX, y, "Milestones", Theme.COLORS[self.textColor], shadowcolor)
        end,
        onClick = function(self)
            SubEventTestScreen.currentTab = SubEventTestScreen.Tabs.Milestones
            SubEventTestScreen.currentPage = 1
            SubEventTestScreen.refreshButtons()
            Program.redraw(true)
        end,
    },

    -- OUTCOME SELECTORS (GOOD / BAD)
    BtnGood = {
        type = Constants.ButtonTypes.FULL_BORDER,
        getText = function(self) return "Good" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 5, Constants.SCREEN.MARGIN + 25, 58, 12 },
        updateSelf = function(self)
            self.isSelected = (SubEventTestScreen.currentOutcome == SubEventTestScreen.Outcomes.Good)
            self.boxColors = self.isSelected and { "Positive text", "Lower box background" } or { SubEventTestScreen.Colors.border, SubEventTestScreen.Colors.boxFill }
        end,
        onClick = function(self)
            SubEventTestScreen.currentOutcome = SubEventTestScreen.Outcomes.Good
            SubEventTestScreen.currentPage = 1
            SubEventTestScreen.refreshButtons()
            Program.redraw(true)
        end,
    },
    BtnBad = {
        type = Constants.ButtonTypes.FULL_BORDER,
        getText = function(self) return "Bad" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 68, Constants.SCREEN.MARGIN + 25, 58, 12 },
        updateSelf = function(self)
            self.isSelected = (SubEventTestScreen.currentOutcome == SubEventTestScreen.Outcomes.Bad)
            self.boxColors = self.isSelected and { "Negative text", "Lower box background" } or { SubEventTestScreen.Colors.border, SubEventTestScreen.Colors.boxFill }
        end,
        onClick = function(self)
            SubEventTestScreen.currentOutcome = SubEventTestScreen.Outcomes.Bad
            SubEventTestScreen.currentPage = 1
            SubEventTestScreen.refreshButtons()
            Program.redraw(true)
        end,
    },

    -- MILESTONE SELECTORS (5 / 10 / 20 / 50)
    BtnM5 = {
        type = Constants.ButtonTypes.FULL_BORDER,
        getText = function(self) return "5" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 5, Constants.SCREEN.MARGIN + 40, 26, 12 },
        isVisible = function(self) return SubEventTestScreen.currentTab == SubEventTestScreen.Tabs.Milestones end,
        updateSelf = function(self)
            self.isSelected = (SubEventTestScreen.currentMilestone == 5)
            self.boxColors = self.isSelected and { SubEventTestScreen.Colors.highlight, "Lower box background" } or { SubEventTestScreen.Colors.border, SubEventTestScreen.Colors.boxFill }
        end,
        onClick = function(self)
            SubEventTestScreen.currentMilestone = 5
            SubEventTestScreen.currentPage = 1
            SubEventTestScreen.refreshButtons()
            Program.redraw(true)
        end,
    },
    BtnM10 = {
        type = Constants.ButtonTypes.FULL_BORDER,
        getText = function(self) return "10" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 36, Constants.SCREEN.MARGIN + 40, 26, 12 },
        isVisible = function(self) return SubEventTestScreen.currentTab == SubEventTestScreen.Tabs.Milestones end,
        updateSelf = function(self)
            self.isSelected = (SubEventTestScreen.currentMilestone == 10)
            self.boxColors = self.isSelected and { SubEventTestScreen.Colors.highlight, "Lower box background" } or { SubEventTestScreen.Colors.border, SubEventTestScreen.Colors.boxFill }
        end,
        onClick = function(self)
            SubEventTestScreen.currentMilestone = 10
            SubEventTestScreen.currentPage = 1
            SubEventTestScreen.refreshButtons()
            Program.redraw(true)
        end,
    },
    BtnM20 = {
        type = Constants.ButtonTypes.FULL_BORDER,
        getText = function(self) return "20" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 67, Constants.SCREEN.MARGIN + 40, 26, 12 },
        isVisible = function(self) return SubEventTestScreen.currentTab == SubEventTestScreen.Tabs.Milestones end,
        updateSelf = function(self)
            self.isSelected = (SubEventTestScreen.currentMilestone == 20)
            self.boxColors = self.isSelected and { SubEventTestScreen.Colors.highlight, "Lower box background" } or { SubEventTestScreen.Colors.border, SubEventTestScreen.Colors.boxFill }
        end,
        onClick = function(self)
            SubEventTestScreen.currentMilestone = 20
            SubEventTestScreen.currentPage = 1
            SubEventTestScreen.refreshButtons()
            Program.redraw(true)
        end,
    },
    BtnM50 = {
        type = Constants.ButtonTypes.FULL_BORDER,
        getText = function(self) return "50" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 98, Constants.SCREEN.MARGIN + 40, 26, 12 },
        isVisible = function(self) return SubEventTestScreen.currentTab == SubEventTestScreen.Tabs.Milestones end,
        updateSelf = function(self)
            self.isSelected = (SubEventTestScreen.currentMilestone == 50)
            self.boxColors = self.isSelected and { SubEventTestScreen.Colors.highlight, "Lower box background" } or { SubEventTestScreen.Colors.border, SubEventTestScreen.Colors.boxFill }
        end,
        onClick = function(self)
            SubEventTestScreen.currentMilestone = 50
            SubEventTestScreen.currentPage = 1
            SubEventTestScreen.refreshButtons()
            Program.redraw(true)
        end,
    },

    -- PAGINATION CONTROLS
    PrevPage = {
        type = Constants.ButtonTypes.FULL_BORDER,
        getText = function(self) return "<" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 5, Constants.SCREEN.MARGIN + 132, 20, 12 },
        isVisible = function(self)
            return SubEventTestScreen.currentPage > 1
        end,
        onClick = function(self)
            if SubEventTestScreen.currentPage > 1 then
                SubEventTestScreen.currentPage = SubEventTestScreen.currentPage - 1
                SubEventTestScreen.refreshButtons()
                Program.redraw(true)
            end
        end,
    },
    NextPage = {
        type = Constants.ButtonTypes.FULL_BORDER,
        getText = function(self) return ">" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 107, Constants.SCREEN.MARGIN + 132, 20, 12 },
        isVisible = function(self)
            local keys = getActiveKeys()
            local ipp = getItemsPerPage()
            return (SubEventTestScreen.currentPage * ipp) < #keys
        end,
        onClick = function(self)
            local keys = getActiveKeys()
            local ipp = getItemsPerPage()
            if (SubEventTestScreen.currentPage * ipp) < #keys then
                SubEventTestScreen.currentPage = SubEventTestScreen.currentPage + 1
                SubEventTestScreen.refreshButtons()
                Program.redraw(true)
            end
        end,
    },

    -- BACK BUTTON
    Back = {
        type = Constants.ButtonTypes.FULL_BORDER,
        getText = function(self) return "Back" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 32, Constants.SCREEN.MARGIN + 132, 68, 12 },
        onClick = function(self)
            Program.changeScreenView(StreamerOptionsScreen)
        end,
    },
}

-- Create dynamic buttons EventBtn1..5
for i = 1, 5 do
    local btnName = "EventBtn" .. i
    SubEventTestScreen.Buttons[btnName] = {
        type = Constants.ButtonTypes.FULL_BORDER,
        index = i,
        getText = function(self)
            local key = getEventKeyForButton(self.index)
            return key or ""
        end,
        box = {
            Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 5,
            0, -- calculated dynamically below
            122,
            13
        },
        updateSelf = function(self)
            local yOffset = 0
            if SubEventTestScreen.currentTab == SubEventTestScreen.Tabs.Cumulative then
                yOffset = Constants.SCREEN.MARGIN + 40
            else
                yOffset = Constants.SCREEN.MARGIN + 55
            end
            self.box[2] = yOffset + (self.index - 1) * 15
        end,
        isVisible = function(self)
            local ipp = getItemsPerPage()
            if self.index > ipp then return false end
            return getEventKeyForButton(self.index) ~= nil
        end,
        onClick = function(self)
            local key = getEventKeyForButton(self.index)
            if key then
                local isPositive = (SubEventTestScreen.currentOutcome == SubEventTestScreen.Outcomes.Good)
                local subCount = 1
                if SubEventTestScreen.currentTab == SubEventTestScreen.Tabs.Milestones then
                    subCount = SubEventTestScreen.currentMilestone
                end
                RoguemonStreamer.simulateSubRedeem(key, isPositive, subCount)
            end
        end,
    }
end

function SubEventTestScreen.initialize()
    for _, button in pairs(SubEventTestScreen.Buttons) do
        if button.textColor == nil then
            button.textColor = SubEventTestScreen.Colors.text
        end
        if button.boxColors == nil then
            button.boxColors = { SubEventTestScreen.Colors.border, SubEventTestScreen.Colors.boxFill }
        end
        if button.updateSelf then
            button:updateSelf()
        end
    end
    SubEventTestScreen.refreshButtons()
end

function SubEventTestScreen.refreshButtons()
    for _, button in pairs(SubEventTestScreen.Buttons) do
        if button.updateSelf then
            button:updateSelf()
        end
    end
end

function SubEventTestScreen.checkInput(xmouse, ymouse)
    Input.checkButtonsClicked(xmouse, ymouse, SubEventTestScreen.Buttons)
end

function SubEventTestScreen.drawScreen()
    Drawing.drawBackgroundAndMargins()
    gui.defaultTextBackground(Theme.COLORS[SubEventTestScreen.Colors.boxFill])

    local tabHeight = 12
    local box = {
        x = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN,
        y = Constants.SCREEN.MARGIN + 10,
        width = Constants.SCREEN.RIGHT_GAP - (Constants.SCREEN.MARGIN * 2),
        height = Constants.SCREEN.HEIGHT - (Constants.SCREEN.MARGIN * 2) - 10,
        text = Theme.COLORS[SubEventTestScreen.Colors.text],
        border = Theme.COLORS[SubEventTestScreen.Colors.border],
        fill = Theme.COLORS[SubEventTestScreen.Colors.boxFill],
        shadow = Utils.calcShadowColor(Theme.COLORS[SubEventTestScreen.Colors.boxFill]),
    }

    -- Draw header text
    local headerShadow = Utils.calcShadowColor(Theme.COLORS["Main background"])
    Drawing.drawText(box.x, Constants.SCREEN.MARGIN - 2, "SUB EVENT SIMULATOR", Theme.COLORS["Header text"], headerShadow)

    -- Draw top border box
    gui.drawRectangle(box.x, box.y + tabHeight, box.width, box.height - tabHeight, box.border, box.fill)
    -- Draw bottom edge for the window tab bars
    gui.drawLine(box.x, box.y + tabHeight, box.x + box.width, box.y + tabHeight, box.border)

    -- Draw pagination page info text
    local keys = getActiveKeys()
    local ipp = getItemsPerPage()
    local maxPage = math.ceil(#keys / ipp)
    if maxPage == 0 then maxPage = 1 end
    local pageStr = string.format("Pg %d/%d", SubEventTestScreen.currentPage, maxPage)
    Drawing.drawText(box.x + 48, box.y + 110, pageStr, box.text, box.shadow)

    -- Draw all buttons
    for _, button in pairs(SubEventTestScreen.Buttons) do
        Drawing.drawButton(button, box.shadow)
    end
end
