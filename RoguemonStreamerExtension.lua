-- RoguemonStreamerExtension.lua
-- Standalone Twitch sub integration extension for RogueMON.
local function RoguemonStreamerExtension()
    local self = {}
    self.name = "RogueMon Streamer"
    self.author = "DrNarrow"
    self.description = "Integrate Twitch subs, gifts and channel points into Roguemon to trigger in-game events."
    self.version = "3.0.5"
    self.url = "https://github.com/drnarrow/roguemon-streamer-extension-releases"
    self.github = "drnarrow/roguemon-streamer-extension-releases"
    self.requiredExtKeys = { "RoguemonExpansion" }

    -- Define folder path
    self.extensionDir = FileManager.prependDir("extensions" .. FileManager.slash .. "roguemon-streamer-extension" .. FileManager.slash)

    function self.startup()
        -- Load supporting Lua files
        local managerPath = self.extensionDir .. "managers" .. FileManager.slash .. "TwitchEventManager.lua"
        local screenPath = self.extensionDir .. "screens" .. FileManager.slash .. "StreamerOptionsScreen.lua"
        local choiceScreenPath = self.extensionDir .. "screens" .. FileManager.slash .. "StreamerChoiceScreen.lua"
        local testScreenPath = self.extensionDir .. "screens" .. FileManager.slash .. "TwitchRedeemTestScreen.lua"
        local subEventTestScreenPath = self.extensionDir .. "screens" .. FileManager.slash .. "SubEventTestScreen.lua"
        local letsDanceScreenPath = self.extensionDir .. "screens" .. FileManager.slash .. "LetsDanceScreen.lua"
        
        if FileManager.fileExists(managerPath) then
            dofile(managerPath)
        else
            print("[RogueMon Streamer] Missing TwitchEventManager.lua")
        end

        if FileManager.fileExists(screenPath) then
            dofile(screenPath)
        else
            print("[RogueMon Streamer] Missing StreamerOptionsScreen.lua")
        end

        if FileManager.fileExists(choiceScreenPath) then
            dofile(choiceScreenPath)
        else
            print("[RogueMon Streamer] Missing StreamerChoiceScreen.lua")
        end

        if FileManager.fileExists(testScreenPath) then
            dofile(testScreenPath)
        else
            print("[RogueMon Streamer] Missing TwitchRedeemTestScreen.lua")
        end

        if FileManager.fileExists(subEventTestScreenPath) then
            dofile(subEventTestScreenPath)
        else
            print("[RogueMon Streamer] Missing SubEventTestScreen.lua")
        end

        if FileManager.fileExists(letsDanceScreenPath) then
            dofile(letsDanceScreenPath)
        else
            print("[RogueMon Streamer] Missing LetsDanceScreen.lua")
        end

        if RoguemonStreamer then
            RoguemonStreamer.initialize(self)
        end
    end

    function self.unload()
        if RoguemonStreamer then
            RoguemonStreamer.shutdown()
        end
    end

    function self.afterProgramDataUpdate()
        if RoguemonStreamer and RoguemonStreamer.initialized then
            RoguemonStreamer.afterProgramDataUpdate()
        end
    end

    function self.afterEachFrame()
        if RoguemonStreamer and RoguemonStreamer.initialized then
            RoguemonStreamer.afterEachFrame()
        end
    end

    function self.afterRedraw()
        if RoguemonStreamer and RoguemonStreamer.initialized then
            RoguemonStreamer.afterRedraw()
        end
    end

    function self.configureOptions()
        if RoguemonStreamer and RoguemonStreamer.initialized then
            RoguemonStreamer.openOptionsScreen()
        end
    end

    function self.checkForUpdates()
        if RoguemonStreamer and type(RoguemonStreamer.checkForUpdatesQuery) == "function" then
            return RoguemonStreamer.checkForUpdatesQuery()
        end
        return false, nil
    end

    function self.downloadAndInstallUpdate()
        if RoguemonStreamer and type(RoguemonStreamer.downloadAndInstallUpdate) == "function" then
            return RoguemonStreamer.downloadAndInstallUpdate()
        end
        return false
    end

    return self
end

return RoguemonStreamerExtension
