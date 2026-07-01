-- TwitchRedeemTestScreen.lua
-- Dedicated menu to simulate Twitch channel point redemptions by writing to Tracker-Requests.json.

local print = RoguemonStreamer.print

TwitchRedeemTestScreen = {
    Colors = {
        text = "Lower box text",
        highlight = "Intermediate text",
        border = "Lower box border",
        boxFill = "Lower box background",
    },
    Tabs = {
        Positive = 1,
        Negative = 2,
    },
    currentTab = 1,
    currentPage = 1,
    itemsPerPage = 6,
}

local positive_keys = {
    "restore hp",
    "restore pp",
    "cure status",
    "full restore",
    "give healing item",
    "give status item",
    "give pp item",
    "give utility item",
    "stat boost",
    "power boost",
    "speed boost",
    "pp up",
    "no guard plus",
    "powerhouse boost",
    "turbo genetics",
    "omniboost",
    "evolution power",
    "game changer",
    "try harder",
    "type change",
    "nature change",
    "ability change",
    "let's dance"
}

local negative_keys = {
    "inflict status",
    "disable move",
    "empowered disable",
    "power debuff",
    "speed debuff",
    "pp cut",
    "temp type change",
    "remove healing item",
    "remove status item",
    "remove big healing item",
    "remove utility item",
    "stat debuff",
    "empowered debuff",
    "pp deplete",
    "mystification",
    "omnimalus",
    "no guard minus",
    "out of control",
    "overwhelmed",
    "let's dance"
}

local function getActiveKeys()
    if TwitchRedeemTestScreen.currentTab == TwitchRedeemTestScreen.Tabs.Positive then
        return positive_keys
    else
        return negative_keys
    end
end

local function getEventKeyForButton(btnIndex)
    local keys = getActiveKeys()
    local index = (TwitchRedeemTestScreen.currentPage - 1) * TwitchRedeemTestScreen.itemsPerPage + btnIndex
    return keys[index]
end

TwitchRedeemTestScreen.Buttons = {
    -- TAB BUTTONS
    TabPositive = {
        type = Constants.ButtonTypes.NO_BORDER,
        getText = function(self) return "Positive" end,
        isSelected = true,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 5, Constants.SCREEN.MARGIN + 10, 58, 12 },
        updateSelf = function(self)
            self.isSelected = (TwitchRedeemTestScreen.currentTab == TwitchRedeemTestScreen.Tabs.Positive)
            self.textColor = self.isSelected and TwitchRedeemTestScreen.Colors.highlight or TwitchRedeemTestScreen.Colors.text
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
            local centeredOffsetX = Utils.getCenteredTextX("Positive", w) - 2
            Drawing.drawText(x + centeredOffsetX, y, "Positive", Theme.COLORS[self.textColor], shadowcolor)
        end,
        onClick = function(self)
            TwitchRedeemTestScreen.currentTab = TwitchRedeemTestScreen.Tabs.Positive
            TwitchRedeemTestScreen.currentPage = 1
            TwitchRedeemTestScreen.refreshButtons()
            Program.redraw(true)
        end,
    },
    TabNegative = {
        type = Constants.ButtonTypes.NO_BORDER,
        getText = function(self) return "Negative" end,
        isSelected = false,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 68, Constants.SCREEN.MARGIN + 10, 58, 12 },
        updateSelf = function(self)
            self.isSelected = (TwitchRedeemTestScreen.currentTab == TwitchRedeemTestScreen.Tabs.Negative)
            self.textColor = self.isSelected and TwitchRedeemTestScreen.Colors.highlight or TwitchRedeemTestScreen.Colors.text
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
            local centeredOffsetX = Utils.getCenteredTextX("Negative", w) - 2
            Drawing.drawText(x + centeredOffsetX, y, "Negative", Theme.COLORS[self.textColor], shadowcolor)
        end,
        onClick = function(self)
            TwitchRedeemTestScreen.currentTab = TwitchRedeemTestScreen.Tabs.Negative
            TwitchRedeemTestScreen.currentPage = 1
            TwitchRedeemTestScreen.refreshButtons()
            Program.redraw(true)
        end,
    },

    -- PAGINATION CONTROLS
    PrevPage = {
        type = Constants.ButtonTypes.FULL_BORDER,
        getText = function(self) return "<" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 5, Constants.SCREEN.MARGIN + 132, 20, 12 },
        isVisible = function(self)
            return TwitchRedeemTestScreen.currentPage > 1
        end,
        onClick = function(self)
            if TwitchRedeemTestScreen.currentPage > 1 then
                TwitchRedeemTestScreen.currentPage = TwitchRedeemTestScreen.currentPage - 1
                TwitchRedeemTestScreen.refreshButtons()
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
            return (TwitchRedeemTestScreen.currentPage * TwitchRedeemTestScreen.itemsPerPage) < #keys
        end,
        onClick = function(self)
            local keys = getActiveKeys()
            if (TwitchRedeemTestScreen.currentPage * TwitchRedeemTestScreen.itemsPerPage) < #keys then
                TwitchRedeemTestScreen.currentPage = TwitchRedeemTestScreen.currentPage + 1
                TwitchRedeemTestScreen.refreshButtons()
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

-- Add the 6 event buttons dynamically to TwitchRedeemTestScreen.Buttons
for i = 1, 6 do
    local btnName = "EventBtn" .. i
    TwitchRedeemTestScreen.Buttons[btnName] = {
        type = Constants.ButtonTypes.FULL_BORDER,
        index = i,
        getText = function(self)
            local key = getEventKeyForButton(self.index)
            if not key then return "" end
            -- Return capitalized display name
            return key:gsub("(%a)([%w_']*)", function(first, rest) return first:upper() .. rest end)
        end,
        box = {
            Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 5,
            Constants.SCREEN.MARGIN + 28 + (i - 1) * 16,
            122,
            13
        },
        isVisible = function(self)
            return getEventKeyForButton(self.index) ~= nil
        end,
        onClick = function(self)
            local key = getEventKeyForButton(self.index)
            if key then
                RoguemonStreamer.simulateTwitchRedeem(key)
            end
        end,
    }
end

function TwitchRedeemTestScreen.initialize()
    for _, button in pairs(TwitchRedeemTestScreen.Buttons) do
        if button.textColor == nil then
            button.textColor = TwitchRedeemTestScreen.Colors.text
        end
        if button.boxColors == nil then
            button.boxColors = { TwitchRedeemTestScreen.Colors.border, TwitchRedeemTestScreen.Colors.boxFill }
        end
        if button.updateSelf then
            button:updateSelf()
        end
    end
    TwitchRedeemTestScreen.refreshButtons()
end

function TwitchRedeemTestScreen.refreshButtons()
    for _, button in pairs(TwitchRedeemTestScreen.Buttons) do
        if button.updateSelf then
            button:updateSelf()
        end
    end
end

function TwitchRedeemTestScreen.checkInput(xmouse, ymouse)
    Input.checkButtonsClicked(xmouse, ymouse, TwitchRedeemTestScreen.Buttons)
end

function TwitchRedeemTestScreen.drawScreen()
    Drawing.drawBackgroundAndMargins()
    gui.defaultTextBackground(Theme.COLORS[TwitchRedeemTestScreen.Colors.boxFill])

    local tabHeight = 12
    local box = {
        x = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN,
        y = Constants.SCREEN.MARGIN + 10,
        width = Constants.SCREEN.RIGHT_GAP - (Constants.SCREEN.MARGIN * 2),
        height = Constants.SCREEN.HEIGHT - (Constants.SCREEN.MARGIN * 2) - 10,
        text = Theme.COLORS[TwitchRedeemTestScreen.Colors.text],
        border = Theme.COLORS[TwitchRedeemTestScreen.Colors.border],
        fill = Theme.COLORS[TwitchRedeemTestScreen.Colors.boxFill],
        shadow = Utils.calcShadowColor(Theme.COLORS[TwitchRedeemTestScreen.Colors.boxFill]),
    }

    -- Draw header text
    local headerShadow = Utils.calcShadowColor(Theme.COLORS["Main background"])
    Drawing.drawText(box.x, Constants.SCREEN.MARGIN - 2, "TWITCH REDEEM SIMULATOR", Theme.COLORS["Header text"], headerShadow)

    -- Draw top border box
    gui.drawRectangle(box.x, box.y + tabHeight, box.width, box.height - tabHeight, box.border, box.fill)
    -- Draw bottom edge for the window tab bars
    gui.drawLine(box.x, box.y + tabHeight, box.x + box.width, box.y + tabHeight, box.border)

    -- Draw pagination page info text
    local keys = getActiveKeys()
    local maxPage = math.ceil(#keys / TwitchRedeemTestScreen.itemsPerPage)
    local pageStr = string.format("Pg %d/%d", TwitchRedeemTestScreen.currentPage, maxPage)
    -- Let's put page text right below the buttons: y = 124
    Drawing.drawText(box.x + 48, box.y + 110, pageStr, box.text, box.shadow)

    -- Draw all buttons
    for _, button in pairs(TwitchRedeemTestScreen.Buttons) do
        Drawing.drawButton(button, box.shadow)
    end
end
