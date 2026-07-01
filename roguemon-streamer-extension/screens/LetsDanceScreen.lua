-- LetsDanceScreen.lua
-- Dedicated screen for interactive Let's Dance move replacement menu.

local print = RoguemonStreamer.print

LetsDanceScreen = {
    Colors = {
        text = "Lower box text",
        border = "Lower box border",
        boxFill = "Lower box background",
    },
    ActiveRequest = nil,
    PreviousScreen = nil,
    Buttons = {},
    cachedMoves = {},
    cachedPersonality = 0,
}

function LetsDanceScreen.initialize()
    for _, button in pairs(LetsDanceScreen.Buttons) do
        if button.textColor == nil then
            button.textColor = LetsDanceScreen.Colors.text
        end
        if button.boxColors == nil then
            button.boxColors = { LetsDanceScreen.Colors.border, LetsDanceScreen.Colors.boxFill }
        end
        if button.updateSelf then
            button:updateSelf()
        end
    end
end

function LetsDanceScreen.show(request)
    LetsDanceScreen.ActiveRequest = request
    LetsDanceScreen.PreviousScreen = Program.currentScreen or TrackerScreen
    
    -- Cache current personality and moves to detect swaps/changes
    local moves, pps = RoguemonStreamer.getPartyMonMovesAndPPs(1)
    LetsDanceScreen.cachedMoves = moves
    
    local partyAddress = GameSettings.pstats
    LetsDanceScreen.cachedPersonality = (partyAddress and Memory.readdword(partyAddress)) or 0
    
    -- Dynamically build buttons for the 4 moves and the Random option
    LetsDanceScreen.Buttons = {}
    
    local boxX = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN
    local boxY = Constants.SCREEN.MARGIN
    local boxWidth = Constants.SCREEN.RIGHT_GAP - (Constants.SCREEN.MARGIN * 2)
    
    local yStart = boxY + 38
    local count = 0
    
    for i = 1, 4 do
        local moveId = moves[i] or 0
        if moveId > 0 then
            count = count + 1
            local move = MoveData.Moves[moveId] or {}
            local moveName = move.name or ("Move " .. i)
            local moveType = move.type or "normal"
            local typeColor = Constants.MoveTypeColors[moveType] or 0xFFFFFFFF
            local btnKey = "Move" .. i
            LetsDanceScreen.Buttons[btnKey] = {
                type = Constants.ButtonTypes.FULL_BORDER,
                getText = function(self) return moveName end,
                box = { boxX + 15, yStart + (count - 1) * 19, boxWidth - 30, 16 },
                textColor = typeColor,
                boxColors = { "Lower box border", "Lower box background" },
                onClick = function(self)
                    RoguemonStreamer.applyLetsDanceChange(i, false)
                    LetsDanceScreen.close()
                end,
            }
        end
    end
    
    -- Add RANDOM button
    count = count + 1
    LetsDanceScreen.Buttons["RandomOption"] = {
        type = Constants.ButtonTypes.FULL_BORDER,
        getText = function(self) return "RANDOM" end,
        box = { boxX + 15, yStart + (count - 1) * 19, boxWidth - 30, 16 },
        textColor = 0xFFFFFFFF, -- Pure white color for Random option
        boxColors = { "Lower box border", "Lower box background" },
        onClick = function(self)
            RoguemonStreamer.applyLetsDanceChange(nil, true)
            LetsDanceScreen.close()
        end,
    }
    
    LetsDanceScreen.initialize()
    Program.changeScreenView(LetsDanceScreen)
end

function LetsDanceScreen.close()
    LetsDanceScreen.ActiveRequest = nil
    if RoguemonStreamer then
        RoguemonStreamer.ActiveLetsDanceRequest = nil
    end
    local prevScreen = LetsDanceScreen.PreviousScreen or TrackerScreen
    LetsDanceScreen.PreviousScreen = nil
    Program.changeScreenView(prevScreen)
end

-- USER INPUT FUNCTIONS
function LetsDanceScreen.checkInput(xmouse, ymouse)
    Input.checkButtonsClicked(xmouse, ymouse, LetsDanceScreen.Buttons)
end

-- DRAWING FUNCTIONS
function LetsDanceScreen.drawScreen()
    -- Check if lead Pokemon or moves changed (swap Pokemon or change move position)
    local partyAddress = GameSettings.pstats
    local currentPersonality = (partyAddress and Memory.readdword(partyAddress)) or 0
    local currentMoves, _ = RoguemonStreamer.getPartyMonMovesAndPPs(1)
    
    local changed = (currentPersonality ~= LetsDanceScreen.cachedPersonality)
    if not changed then
        for i = 1, 4 do
            if (currentMoves[i] or 0) ~= (LetsDanceScreen.cachedMoves[i] or 0) then
                changed = true
                break
            end
        end
    end
    
    if changed then
        -- Rebuild buttons dynamically to match new layout/Pokemon
        LetsDanceScreen.show(LetsDanceScreen.ActiveRequest)
        return
    end

    Drawing.drawBackgroundAndMargins()
    gui.defaultTextBackground(Theme.COLORS[LetsDanceScreen.Colors.boxFill])

    local box = {
        x = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN,
        y = Constants.SCREEN.MARGIN,
        width = Constants.SCREEN.RIGHT_GAP - (Constants.SCREEN.MARGIN * 2),
        height = Constants.SCREEN.HEIGHT - (Constants.SCREEN.MARGIN * 2),
        text = Theme.COLORS[LetsDanceScreen.Colors.text],
        border = Theme.COLORS[LetsDanceScreen.Colors.border],
        fill = Theme.COLORS[LetsDanceScreen.Colors.boxFill],
        shadow = Utils.calcShadowColor(Theme.COLORS[LetsDanceScreen.Colors.boxFill]),
    }

    -- Draw border box
    gui.drawRectangle(box.x, box.y, box.width, box.height, box.border, box.fill)

    -- Header
    local headerText = "LET'S DANCE!"
    local headerX = Utils.getCenteredTextX(headerText, box.width) + box.x - 2
    Drawing.drawText(headerX, box.y + 10, headerText, Theme.COLORS["Header text"], box.shadow)

    -- Subheader
    local subText = "Select a move to dance:"
    local subX = Utils.getCenteredTextX(subText, box.width) + box.x - 2
    Drawing.drawText(subX, box.y + 25, subText, box.text, box.shadow)

    -- Draw buttons
    for _, button in pairs(LetsDanceScreen.Buttons) do
        Drawing.drawButton(button, box.shadow)
    end
end
