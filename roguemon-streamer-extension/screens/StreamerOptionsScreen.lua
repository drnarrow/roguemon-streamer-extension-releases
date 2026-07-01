-- StreamerOptionsScreen.lua
-- Configuration Options and Testing Panel for Twitch Streamer Extension

local print = RoguemonStreamer.print

StreamerOptionsScreen = {
    Colors = {
        text = "Lower box text",
        highlight = "Intermediate text",
        border = "Lower box border",
        boxFill = "Lower box background",
    },
    Tabs = {
        Config = 1,
        Test = 2,
    },
    currentTab = 1,
    testScale = 1,
    testOutcome = "Bad",
}

StreamerOptionsScreen.Buttons = {
    -- TAB BUTTONS
    TabConfig = {
        type = Constants.ButtonTypes.NO_BORDER,
        getText = function(self) return "Config" end,
        isSelected = true,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 5, Constants.SCREEN.MARGIN + 10, 45, 12 },
        updateSelf = function(self)
            self.isSelected = (StreamerOptionsScreen.currentTab == StreamerOptionsScreen.Tabs.Config)
            self.textColor = self.isSelected and StreamerOptionsScreen.Colors.highlight or StreamerOptionsScreen.Colors.text
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
            local centeredOffsetX = Utils.getCenteredTextX("Config", w) - 2
            Drawing.drawText(x + centeredOffsetX, y, "Config", Theme.COLORS[self.textColor], shadowcolor)
        end,
        onClick = function(self)
            StreamerOptionsScreen.currentTab = StreamerOptionsScreen.Tabs.Config
            StreamerOptionsScreen.refreshButtons()
            Program.redraw(true)
        end,
    },
    TabTest = {
        type = Constants.ButtonTypes.NO_BORDER,
        getText = function(self) return "Test Events" end,
        isSelected = false,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 52, Constants.SCREEN.MARGIN + 10, 65, 12 },
        updateSelf = function(self)
            self.isSelected = (StreamerOptionsScreen.currentTab == StreamerOptionsScreen.Tabs.Test)
            self.textColor = self.isSelected and StreamerOptionsScreen.Colors.highlight or StreamerOptionsScreen.Colors.text
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
            local centeredOffsetX = Utils.getCenteredTextX("Test Events", w) - 2
            Drawing.drawText(x + centeredOffsetX, y, "Test Events", Theme.COLORS[self.textColor], shadowcolor)
        end,
        onClick = function(self)
            StreamerOptionsScreen.currentTab = StreamerOptionsScreen.Tabs.Test
            StreamerOptionsScreen.refreshButtons()
            Program.redraw(true)
        end,
    },

    -- CONFIG TAB CONTROLS
    SubGoalDown = {
        type = Constants.ButtonTypes.NO_BORDER,
        getText = function(self) return "-" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 75, Constants.SCREEN.MARGIN + 27, 10, 10 },
        isVisible = function(self) return StreamerOptionsScreen.currentTab == StreamerOptionsScreen.Tabs.Config end,
        onClick = function(self)
            RoguemonStreamer.settings.cumulativeGoal = math.max(1, RoguemonStreamer.settings.cumulativeGoal - 1)
            RoguemonStreamer.saveSettings()
            StreamerOptionsScreen.refreshButtons()
            Program.redraw(true)
        end,
    },
    SubGoalUp = {
        type = Constants.ButtonTypes.NO_BORDER,
        getText = function(self) return "+" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 112, Constants.SCREEN.MARGIN + 27, 10, 10 },
        isVisible = function(self) return StreamerOptionsScreen.currentTab == StreamerOptionsScreen.Tabs.Config end,
        onClick = function(self)
            RoguemonStreamer.settings.cumulativeGoal = RoguemonStreamer.settings.cumulativeGoal + 1
            RoguemonStreamer.saveSettings()
            StreamerOptionsScreen.refreshButtons()
            Program.redraw(true)
        end,
    },
    GoodChanceDown = {
        type = Constants.ButtonTypes.NO_BORDER,
        getText = function(self) return "-" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 75, Constants.SCREEN.MARGIN + 39, 10, 10 },
        isVisible = function(self) return StreamerOptionsScreen.currentTab == StreamerOptionsScreen.Tabs.Config end,
        onClick = function(self)
            RoguemonStreamer.settings.goodChance = math.max(0, RoguemonStreamer.settings.goodChance - 5)
            RoguemonStreamer.saveSettings()
            StreamerOptionsScreen.refreshButtons()
            Program.redraw(true)
        end,
    },
    GoodChanceUp = {
        type = Constants.ButtonTypes.NO_BORDER,
        getText = function(self) return "+" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 112, Constants.SCREEN.MARGIN + 40, 10, 10 },
        isVisible = function(self) return StreamerOptionsScreen.currentTab == StreamerOptionsScreen.Tabs.Config end,
        onClick = function(self)
            RoguemonStreamer.settings.goodChance = math.min(100, RoguemonStreamer.settings.goodChance + 5)
            RoguemonStreamer.saveSettings()
            StreamerOptionsScreen.refreshButtons()
            Program.redraw(true)
        end,
    },

    -- Milestone Checkboxes
    Milestone5 = {
        type = Constants.ButtonTypes.CHECKBOX,
        getText = function(self) return "   5-Sub Gifter's Choice" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 8, Constants.SCREEN.MARGIN + 53, 8, 8 },
        clickableArea = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 8, Constants.SCREEN.MARGIN + 53, 140, 8 },
        toggleState = true,
        updateSelf = function(self) self.toggleState = RoguemonStreamer.settings.milestones["5"] end,
        isVisible = function(self) return StreamerOptionsScreen.currentTab == StreamerOptionsScreen.Tabs.Config end,
        onClick = function(self)
            RoguemonStreamer.settings.milestones["5"] = not RoguemonStreamer.settings.milestones["5"]
            RoguemonStreamer.saveSettings()
            StreamerOptionsScreen.refreshButtons()
            Program.redraw(true)
        end,
    },
    Milestone10 = {
        type = Constants.ButtonTypes.CHECKBOX,
        getText = function(self) return " 10-Sub Gifter's Choice" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 8, Constants.SCREEN.MARGIN + 63, 8, 8 },
        clickableArea = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 8, Constants.SCREEN.MARGIN + 63, 140, 8 },
        toggleState = true,
        updateSelf = function(self) self.toggleState = RoguemonStreamer.settings.milestones["10"] end,
        isVisible = function(self) return StreamerOptionsScreen.currentTab == StreamerOptionsScreen.Tabs.Config end,
        onClick = function(self)
            RoguemonStreamer.settings.milestones["10"] = not RoguemonStreamer.settings.milestones["10"]
            RoguemonStreamer.saveSettings()
            StreamerOptionsScreen.refreshButtons()
            Program.redraw(true)
        end,
    },
    Milestone20 = {
        type = Constants.ButtonTypes.CHECKBOX,
        getText = function(self) return " 20-Sub Gifter's Choice" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 8, Constants.SCREEN.MARGIN + 73, 8, 8 },
        clickableArea = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 8, Constants.SCREEN.MARGIN + 73, 140, 8 },
        toggleState = true,
        updateSelf = function(self) self.toggleState = RoguemonStreamer.settings.milestones["20"] end,
        isVisible = function(self) return StreamerOptionsScreen.currentTab == StreamerOptionsScreen.Tabs.Config end,
        onClick = function(self)
            RoguemonStreamer.settings.milestones["20"] = not RoguemonStreamer.settings.milestones["20"]
            RoguemonStreamer.saveSettings()
            StreamerOptionsScreen.refreshButtons()
            Program.redraw(true)
        end,
    },
    Milestone50 = {
        type = Constants.ButtonTypes.CHECKBOX,
        getText = function(self) return " 50-Sub Gifter's Choice" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 8, Constants.SCREEN.MARGIN + 83, 8, 8 },
        clickableArea = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 8, Constants.SCREEN.MARGIN + 83, 140, 8 },
        toggleState = true,
        updateSelf = function(self) self.toggleState = RoguemonStreamer.settings.milestones["50"] end,
        isVisible = function(self) return StreamerOptionsScreen.currentTab == StreamerOptionsScreen.Tabs.Config end,
        onClick = function(self)
            RoguemonStreamer.settings.milestones["50"] = not RoguemonStreamer.settings.milestones["50"]
            RoguemonStreamer.saveSettings()
            StreamerOptionsScreen.refreshButtons()
            Program.redraw(true)
        end,
    },
    ToggleAnimations = {
        type = Constants.ButtonTypes.CHECKBOX,
        getText = function(self) return " Enable Event Animations" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 8, Constants.SCREEN.MARGIN + 93, 8, 8 },
        clickableArea = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 8, Constants.SCREEN.MARGIN + 93, 140, 8 },
        toggleState = false,
        updateSelf = function(self) self.toggleState = (RoguemonStreamer.settings.enableAnimations == true) end,
        isVisible = function(self) return StreamerOptionsScreen.currentTab == StreamerOptionsScreen.Tabs.Config end,
        onClick = function(self)
            RoguemonStreamer.settings.enableAnimations = not RoguemonStreamer.settings.enableAnimations
            RoguemonStreamer.saveSettings()
            StreamerOptionsScreen.refreshButtons()
            Program.redraw(true)
        end,
    },

    ResetStats = {
        type = Constants.ButtonTypes.FULL_BORDER,
        getText = function(self) return "Reset Goals & Stats" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 5, Constants.SCREEN.MARGIN + 134, 114, 12 },
        isVisible = function(self) return StreamerOptionsScreen.currentTab == StreamerOptionsScreen.Tabs.Config end,
        onClick = function(self)
            RoguemonStreamer.settings.currentProgress = 0
            RoguemonStreamer.settings.stats.totalSubs = 0
            RoguemonStreamer.settings.stats.totalEvents = 0
            RoguemonStreamer.settings.persistent.hpCapBoost = 0
            RoguemonStreamer.settings.persistent.statusCapBoost = 0
            RoguemonStreamer.settings.persistent.statBuffs = {}
            RoguemonStreamer.settings.persistent.outOfControlTurns = 0
            RoguemonStreamer.settings.persistent.tempTypeChange = nil
            RoguemonStreamer.settings.persistent.tempTypeApplied = nil
            RoguemonStreamer.settings.persistent.queuedTempTypes = {}
            RoguemonStreamer.saveSettings()
            print("[RogueMon Streamer] Sub counts and temporary state reset successfully.")
            StreamerOptionsScreen.refreshButtons()
            Program.redraw(true)
        end,
    },

    -- TEST TAB EVENTS
    TestGoodEvent = {
        type = Constants.ButtonTypes.FULL_BORDER,
        getText = function(self) return "Good Event" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 5, Constants.SCREEN.MARGIN + 28, 64, 13 },
        isVisible = function(self) return StreamerOptionsScreen.currentTab == StreamerOptionsScreen.Tabs.Test end,
        onClick = function(self)
            SubEventTestScreen.currentTab = SubEventTestScreen.Tabs.Cumulative
            SubEventTestScreen.currentOutcome = SubEventTestScreen.Outcomes.Good
            SubEventTestScreen.currentPage = 1
            SubEventTestScreen.initialize()
            Program.changeScreenView(SubEventTestScreen)
        end,
    },
    TestBadEvent = {
        type = Constants.ButtonTypes.FULL_BORDER,
        getText = function(self) return "Bad Event" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 73, Constants.SCREEN.MARGIN + 28, 64, 13 },
        isVisible = function(self) return StreamerOptionsScreen.currentTab == StreamerOptionsScreen.Tabs.Test end,
        onClick = function(self)
            SubEventTestScreen.currentTab = SubEventTestScreen.Tabs.Cumulative
            SubEventTestScreen.currentOutcome = SubEventTestScreen.Outcomes.Bad
            SubEventTestScreen.currentPage = 1
            SubEventTestScreen.initialize()
            Program.changeScreenView(SubEventTestScreen)
        end,
    },
    TestChoice5 = {
        type = Constants.ButtonTypes.FULL_BORDER,
        getText = function(self) return "Choice 5" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 5, Constants.SCREEN.MARGIN + 45, 64, 13 },
        isVisible = function(self) return StreamerOptionsScreen.currentTab == StreamerOptionsScreen.Tabs.Test end,
        onClick = function(self)
            SubEventTestScreen.currentTab = SubEventTestScreen.Tabs.Milestones
            SubEventTestScreen.currentOutcome = SubEventTestScreen.Outcomes.Good
            SubEventTestScreen.currentMilestone = 5
            SubEventTestScreen.currentPage = 1
            SubEventTestScreen.initialize()
            Program.changeScreenView(SubEventTestScreen)
        end,
    },
    TestChoice10 = {
        type = Constants.ButtonTypes.FULL_BORDER,
        getText = function(self) return "Choice 10" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 73, Constants.SCREEN.MARGIN + 45, 64, 13 },
        isVisible = function(self) return StreamerOptionsScreen.currentTab == StreamerOptionsScreen.Tabs.Test end,
        onClick = function(self)
            SubEventTestScreen.currentTab = SubEventTestScreen.Tabs.Milestones
            SubEventTestScreen.currentOutcome = SubEventTestScreen.Outcomes.Good
            SubEventTestScreen.currentMilestone = 10
            SubEventTestScreen.currentPage = 1
            SubEventTestScreen.initialize()
            Program.changeScreenView(SubEventTestScreen)
        end,
    },
    TestChoice20 = {
        type = Constants.ButtonTypes.FULL_BORDER,
        getText = function(self) return "Choice 20" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 5, Constants.SCREEN.MARGIN + 62, 64, 13 },
        isVisible = function(self) return StreamerOptionsScreen.currentTab == StreamerOptionsScreen.Tabs.Test end,
        onClick = function(self)
            SubEventTestScreen.currentTab = SubEventTestScreen.Tabs.Milestones
            SubEventTestScreen.currentOutcome = SubEventTestScreen.Outcomes.Good
            SubEventTestScreen.currentMilestone = 20
            SubEventTestScreen.currentPage = 1
            SubEventTestScreen.initialize()
            Program.changeScreenView(SubEventTestScreen)
        end,
    },
    TestChoice50 = {
        type = Constants.ButtonTypes.FULL_BORDER,
        getText = function(self) return "Choice 50" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 73, Constants.SCREEN.MARGIN + 62, 64, 13 },
        isVisible = function(self) return StreamerOptionsScreen.currentTab == StreamerOptionsScreen.Tabs.Test end,
        onClick = function(self)
            SubEventTestScreen.currentTab = SubEventTestScreen.Tabs.Milestones
            SubEventTestScreen.currentOutcome = SubEventTestScreen.Outcomes.Good
            SubEventTestScreen.currentMilestone = 50
            SubEventTestScreen.currentPage = 1
            SubEventTestScreen.initialize()
            Program.changeScreenView(SubEventTestScreen)
        end,
    },
    TestTwitchRedeem = {
        type = Constants.ButtonTypes.FULL_BORDER,
        getText = function(self) return "Twitch Redeem" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 5, Constants.SCREEN.MARGIN + 79, 132, 13 },
        isVisible = function(self) return StreamerOptionsScreen.currentTab == StreamerOptionsScreen.Tabs.Test end,
        onClick = function(self)
            TwitchRedeemTestScreen.initialize()
            Program.changeScreenView(TwitchRedeemTestScreen)
        end,
    },


    -- BACK BUTTON
    Back = Drawing.createUIElementBackButton(function()
        Program.changeScreenView(SingleExtensionScreen)
    end),
}

function StreamerOptionsScreen.initialize()
    for _, button in pairs(StreamerOptionsScreen.Buttons) do
        if button.textColor == nil then
            button.textColor = StreamerOptionsScreen.Colors.text
        end
        if button.boxColors == nil then
            button.boxColors = { StreamerOptionsScreen.Colors.border, StreamerOptionsScreen.Colors.boxFill }
        end
    end
    StreamerOptionsScreen.refreshButtons()
end

function StreamerOptionsScreen.refreshButtons()
    for _, button in pairs(StreamerOptionsScreen.Buttons) do
        if button.updateSelf ~= nil then
            button:updateSelf()
        end
    end
end

-- USER INPUT FUNCTIONS
function StreamerOptionsScreen.checkInput(xmouse, ymouse)
    Input.checkButtonsClicked(xmouse, ymouse, StreamerOptionsScreen.Buttons)
end

-- DRAWING FUNCTIONS
function StreamerOptionsScreen.drawScreen()
    Drawing.drawBackgroundAndMargins()
    gui.defaultTextBackground(Theme.COLORS[StreamerOptionsScreen.Colors.boxFill])

    local tabHeight = 12
    local box = {
        x = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN,
        y = Constants.SCREEN.MARGIN + 10,
        width = Constants.SCREEN.RIGHT_GAP - (Constants.SCREEN.MARGIN * 2),
        height = Constants.SCREEN.HEIGHT - (Constants.SCREEN.MARGIN * 2) - 10,
        text = Theme.COLORS[StreamerOptionsScreen.Colors.text],
        border = Theme.COLORS[StreamerOptionsScreen.Colors.border],
        fill = Theme.COLORS[StreamerOptionsScreen.Colors.boxFill],
        shadow = Utils.calcShadowColor(Theme.COLORS[StreamerOptionsScreen.Colors.boxFill]),
    }

    -- Draw header text
    local headerShadow = Utils.calcShadowColor(Theme.COLORS["Main background"])
    Drawing.drawText(box.x, Constants.SCREEN.MARGIN - 2, "ROGUEMON STREAMER EXTENSION", Theme.COLORS["Header text"], headerShadow)

    -- Draw top border box
    gui.drawRectangle(box.x, box.y + tabHeight, box.width, box.height - tabHeight, box.border, box.fill)
    -- Draw bottom edge for the window tab bars
    gui.drawLine(box.x, box.y + tabHeight, box.x + box.width, box.y + tabHeight, box.border)

    -- Config Specific Static Texts
    if StreamerOptionsScreen.currentTab == StreamerOptionsScreen.Tabs.Config then
        Drawing.drawText(box.x + 8, box.y + 18, "Sub Goal:", box.text, box.shadow)
        Drawing.drawText(box.x + 91, box.y + 18, tostring(RoguemonStreamer.settings.cumulativeGoal), Theme.COLORS["Intermediate text"], box.shadow)

        Drawing.drawText(box.x + 8, box.y + 30, "Good Event %:", box.text, box.shadow)
        Drawing.drawText(box.x + 88, box.y + 30, tostring(RoguemonStreamer.settings.goodChance) .. "%", Theme.COLORS["Intermediate text"], box.shadow)
        
        -- Statistics at the bottom
        local statsY = box.y + 99
        Drawing.drawText(box.x + 8, statsY, "Progress: " .. RoguemonStreamer.settings.currentProgress .. " / " .. RoguemonStreamer.settings.cumulativeGoal, box.text, box.shadow)
        Drawing.drawText(box.x + 8, statsY + 10, "Total Subs: " .. RoguemonStreamer.settings.stats.totalSubs, box.text, box.shadow)
    end

    -- Draw all buttons
    for _, button in pairs(StreamerOptionsScreen.Buttons) do
        Drawing.drawButton(button, box.shadow)
    end
end
