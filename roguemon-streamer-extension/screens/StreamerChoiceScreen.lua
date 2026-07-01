-- StreamerChoiceScreen.lua
-- Dedicated screen for interactive Gifter's Choice overlay

local print = RoguemonStreamer.print

StreamerChoiceScreen = {
    Colors = {
        text = "Lower box text",
        border = "Lower box border",
        boxFill = "Lower box background",
        goodText = "Positive text",
        badText = "Negative text",
    },
    ActiveRequest = nil,
    PreviousScreen = nil,
}

StreamerChoiceScreen.Buttons = {
    GoodEvent = {
        type = Constants.ButtonTypes.FULL_BORDER,
        getText = function(self) return "GOOD EVENT" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 5, Constants.SCREEN.MARGIN + 75, 60, 18 },
        updateSelf = function(self)
            self.textColor = "Positive text"
        end,
        onClick = function(self)
            if StreamerChoiceScreen.ActiveRequest then
                StreamerChoiceScreen.ActiveRequest.Choice = "Good"
                print("[RogueMon Streamer] Streamer chose GOOD event.")
                if StreamerChoiceScreen.ActiveRequest.IsTest and RoguemonStreamer and RoguemonStreamer.executeChoice then
                    RoguemonStreamer.executeChoice(StreamerChoiceScreen.ActiveRequest, "Good")
                end
            end
            StreamerChoiceScreen.close()
        end,
    },
    BadEvent = {
        type = Constants.ButtonTypes.FULL_BORDER,
        getText = function(self) return "BAD EVENT" end,
        box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 75, Constants.SCREEN.MARGIN + 75, 60, 18 },
        updateSelf = function(self)
            self.textColor = "Negative text"
        end,
        onClick = function(self)
            if StreamerChoiceScreen.ActiveRequest then
                StreamerChoiceScreen.ActiveRequest.Choice = "Bad"
                print("[RogueMon Streamer] Streamer chose BAD event.")
                if StreamerChoiceScreen.ActiveRequest.IsTest and RoguemonStreamer and RoguemonStreamer.executeChoice then
                    RoguemonStreamer.executeChoice(StreamerChoiceScreen.ActiveRequest, "Bad")
                end
            end
            StreamerChoiceScreen.close()
        end,
    },
}

function StreamerChoiceScreen.initialize()
    for _, button in pairs(StreamerChoiceScreen.Buttons) do
        if button.textColor == nil then
            button.textColor = StreamerChoiceScreen.Colors.text
        end
        if button.boxColors == nil then
            button.boxColors = { StreamerChoiceScreen.Colors.border, StreamerChoiceScreen.Colors.boxFill }
        end
        if button.updateSelf then
            button:updateSelf()
        end
    end
end

function StreamerChoiceScreen.show(request)
    StreamerChoiceScreen.ActiveRequest = request
    StreamerChoiceScreen.PreviousScreen = Program.currentScreen or TrackerScreen
    StreamerChoiceScreen.initialize()
    Program.changeScreenView(StreamerChoiceScreen)
end

function StreamerChoiceScreen.close()
    StreamerChoiceScreen.ActiveRequest = nil
    if RoguemonStreamer then
        RoguemonStreamer.ActiveChoiceRequest = nil
    end
    local prevScreen = StreamerChoiceScreen.PreviousScreen or TrackerScreen
    StreamerChoiceScreen.PreviousScreen = nil
    Program.changeScreenView(prevScreen)
end

-- USER INPUT FUNCTIONS
function StreamerChoiceScreen.checkInput(xmouse, ymouse)
    Input.checkButtonsClicked(xmouse, ymouse, StreamerChoiceScreen.Buttons)
end

-- DRAWING FUNCTIONS
function StreamerChoiceScreen.drawScreen()
    Drawing.drawBackgroundAndMargins()
    gui.defaultTextBackground(Theme.COLORS[StreamerChoiceScreen.Colors.boxFill])

    local box = {
        x = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN,
        y = Constants.SCREEN.MARGIN,
        width = Constants.SCREEN.RIGHT_GAP - (Constants.SCREEN.MARGIN * 2),
        height = Constants.SCREEN.HEIGHT - (Constants.SCREEN.MARGIN * 2),
        text = Theme.COLORS[StreamerChoiceScreen.Colors.text],
        border = Theme.COLORS[StreamerChoiceScreen.Colors.border],
        fill = Theme.COLORS[StreamerChoiceScreen.Colors.boxFill],
        shadow = Utils.calcShadowColor(Theme.COLORS[StreamerChoiceScreen.Colors.boxFill]),
    }

    -- Draw border box
    gui.drawRectangle(box.x, box.y, box.width, box.height, box.border, box.fill)

    -- Header
    local headerText = "GIFTER'S CHOICE!"
    local headerX = Utils.getCenteredTextX(headerText, box.width) + box.x - 2
    Drawing.drawText(headerX, box.y + 10, headerText, Theme.COLORS["Header text"], box.shadow)

    -- Info labels
    local username = StreamerChoiceScreen.ActiveRequest and StreamerChoiceScreen.ActiveRequest.Username or "Gifter"
    local subs = StreamerChoiceScreen.ActiveRequest and (StreamerChoiceScreen.ActiveRequest.OriginalSubCount or (StreamerChoiceScreen.ActiveRequest.Args and StreamerChoiceScreen.ActiveRequest.Args.SubCount)) or 1
    
    local line1 = string.format("%s", username)
    local line1X = Utils.getCenteredTextX(line1, box.width) + box.x - 2
    Drawing.drawText(line1X, box.y + 30, line1, Theme.COLORS["Intermediate text"], box.shadow)

    local line2 = string.format("gifted %d subs!", subs)
    local line2X = Utils.getCenteredTextX(line2, box.width) + box.x - 2
    Drawing.drawText(line2X, box.y + 42, line2, box.text, box.shadow)

    local instructionText = "Ask chat and select:"
    local instX = Utils.getCenteredTextX(instructionText, box.width) + box.x - 2
    Drawing.drawText(instX, box.y + 58, instructionText, box.text, box.shadow)

    -- Draw choice buttons
    for _, button in pairs(StreamerChoiceScreen.Buttons) do
        Drawing.drawButton(button, box.shadow)
    end
end
