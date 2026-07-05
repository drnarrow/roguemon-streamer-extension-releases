-- TwitchEventManager.lua
-- Core manager for Twitch sub/gift event processing and RAM manipulation

local Battle = setmetatable({}, {
    __index = function(_, k)
        if k == "isWildEncounter" then
            return false
        end
        return _G.Battle[k]
    end,
    __newindex = function(_, k, v)
        _G.Battle[k] = v
    end
})

RoguemonStreamer = {
    initialized = false,
    settings = {},
    settingsPath = "",
    extensionDir = "",
    abilityPools = nil,
    ActiveChoiceRequest = nil,
    OriginalMoves = nil,
    OriginalPP = nil,
    MovesOverwritten = false,
    ActiveStatBuffsApplied = false,
}

function RoguemonStreamer.print(...)
    local isError = false
    for i = 1, select("#", ...) do
        local arg = select(i, ...)
        if type(arg) == "string" then
            local lower = arg:lower()
            if lower:find("failed") or lower:find("error") or lower:find("invalid") or lower:find("missing") then
                isError = true
                break
            end
        end
    end
    if isError or (RoguemonStreamer.settings and RoguemonStreamer.settings.debug == true) then
        _G.print(...)
    end
end

local print = RoguemonStreamer.print

local function trim(s)
    if type(s) ~= "string" then return s end
    return s:gsub("^%s*(.-)%s*$", "%1")
end


-- Item ID Constants
local ITEMS = {
    POTION = 13,
    ANTIDOTE = 14,
    BURN_HEAL = 15,
    ICE_HEAL = 16,
    AWAKENING = 17,
    PARALYZE_HEAL = 18,
    FULL_RESTORE = 19,
    MAX_POTION = 20,
    HYPER_POTION = 21,
    SUPER_POTION = 22,
    FULL_HEAL = 23,
    REVIVE = 24,
    MAX_REVIVE = 25,
    FRESH_WATER = 26,
    SODA_POP = 27,
    LEMONADE = 28,
    MOOMOO_MILK = 29,
    ENERGY_POWDER = 30,
    ENERGY_ROOT = 31,
    HEAL_POWDER = 32,
    REVIVAL_HERB = 33,
    ETHER = 34,
    MAX_ETHER = 35,
    ELIXIR = 36,
    MAX_ELIXIR = 37,
    LAVA_COOKIE = 38,
    RARE_CANDY = 68,
    ROGUESTONE = 95,
    SWEET_HEART = 13,
    BERRY_JUICE = 43,
    PP_UP = 69,
    PP_MAX = 71,
    LEPPA_BERRY = 138,
    CHESTO_BERRY = 134,
    PECHA_BERRY = 135,
    CHERI_BERRY = 133,
    MENTAL_HERB = 254,
    ASPEAR_BERRY = 137,
    PERSIM_BERRY = 140,
    RAWST_BERRY = 136,
}

local ITEM_RESOLVER = {
    POTION = { names = {"Potion"}, fallback = 13 },
    ANTIDOTE = { names = {"Antidote"}, fallback = 14 },
    BURN_HEAL = { names = {"Burn Heal"}, fallback = 15 },
    ICE_HEAL = { names = {"Ice Heal"}, fallback = 16 },
    AWAKENING = { names = {"Awakening"}, fallback = 17 },
    PARALYZE_HEAL = { names = {"Parlyz Heal", "Paralyze Heal"}, fallback = 18 },
    FULL_RESTORE = { names = {"Full Restore"}, fallback = 19 },
    MAX_POTION = { names = {"Max Potion"}, fallback = 20 },
    HYPER_POTION = { names = {"Hyper Potion"}, fallback = 21 },
    SUPER_POTION = { names = {"Super Potion"}, fallback = 22 },
    FULL_HEAL = { names = {"Full Heal"}, fallback = 23 },
    REVIVE = { names = {"Revive"}, fallback = 24 },
    MAX_REVIVE = { names = {"Max Revive"}, fallback = 25 },
    FRESH_WATER = { names = {"Fresh Water"}, fallback = 26 },
    SODA_POP = { names = {"Soda Pop"}, fallback = 27 },
    LEMONADE = { names = {"Lemonade"}, fallback = 28 },
    MOOMOO_MILK = { names = {"Moomoo Milk"}, fallback = 29 },
    ENERGY_POWDER = { names = {"EnergyPowder", "Energy Powder"}, fallback = 30 },
    ENERGY_ROOT = { names = {"Energy Root"}, fallback = 31 },
    HEAL_POWDER = { names = {"Heal Powder"}, fallback = 32 },
    REVIVAL_HERB = { names = {"Revival Herb"}, fallback = 33 },
    ETHER = { names = {"Ether"}, fallback = 34 },
    MAX_ETHER = { names = {"Max Ether"}, fallback = 35 },
    ELIXIR = { names = {"Elixir"}, fallback = 36 },
    MAX_ELIXIR = { names = {"Max Elixir"}, fallback = 37 },
    LAVA_COOKIE = { names = {"Lava Cookie", "LavaCookie"}, fallback = 38 },
    RARE_CANDY = { names = {"Rare Candy"}, fallback = 68 },
    ROGUESTONE = { names = {"Roguestone", "Moon Stone"}, fallback = 95 },
    SWEET_HEART = { names = {"Sweet Heart"}, fallback = 13 },
    BERRY_JUICE = { names = {"Berry Juice"}, fallback = 43 },
    PP_UP = { names = {"PP Up"}, fallback = 69 },
    PP_MAX = { names = {"PP Max"}, fallback = 71 },
    LEPPA_BERRY = { names = {"Leppa Berry"}, fallback = 138 },
    CHESTO_BERRY = { names = {"Chesto Berry"}, fallback = 134 },
    PECHA_BERRY = { names = {"Pecha Berry"}, fallback = 135 },
    CHERI_BERRY = { names = {"Cheri Berry"}, fallback = 133 },
    MENTAL_HERB = { names = {"Mental Herb"}, fallback = 254 },
    ASPEAR_BERRY = { names = {"Aspear Berry"}, fallback = 137 },
    PERSIM_BERRY = { names = {"Persim Berry"}, fallback = 140 },
    RAWST_BERRY = { names = {"Rawst Berry"}, fallback = 136 },
}

function RoguemonStreamer.updateItemIds()
    for key, cfg in pairs(ITEM_RESOLVER) do
        local resolvedId = nil
        
        local function lookup(name)
            local targetUpper = name:upper():gsub("%s+", "")
            
            if Roguemon and Roguemon.ItemManager and Roguemon.ItemManager.getItemIdByName then
                local id = Roguemon.ItemManager.getItemIdByName(name)
                if id then return id end
            end
            if MiscData and MiscData.Items then
                for id, itemName in pairs(MiscData.Items) do
                    local cleanName = itemName:upper():gsub("%s+", "")
                    if cleanName == targetUpper then return id end
                end
            end
            if Resources and Resources.Game and Resources.Game.ItemNames then
                for id, itemName in pairs(Resources.Game.ItemNames) do
                    local cleanName = itemName:upper():gsub("%s+", "")
                    if cleanName == targetUpper then return id end
                end
            end
            return nil
        end

        for _, name in ipairs(cfg.names) do
            local id = lookup(name)
            if id then
                resolvedId = id
                break
            end
        end

        if resolvedId then
            if ITEMS[key] ~= resolvedId then
                print(string.format("[RogueMon Streamer] Resolved item %s -> ID %d (was %s)", key, resolvedId, tostring(ITEMS[key])))
                ITEMS[key] = resolvedId
            end
        else
            if ITEMS[key] ~= cfg.fallback then
                print(string.format("[RogueMon Streamer] Fallback item %s -> ID %d (was %s)", key, cfg.fallback, tostring(ITEMS[key])))
                ITEMS[key] = cfg.fallback
            end
        end
    end
end

-- POCKET IDs
local POCKETS = {
    ITEMS = 0,
    KEY_ITEMS = 1,
    BALLS = 2,
    ROGUE_ITEMS = 3,
    TM_HM = 4,
    BERRIES = 5,
}

local POCKET_CONFIG = {
    [POCKETS.ITEMS] = { offset = "bagPocket_Items_offset", count = "bagPocket_Items_Size" },
    [POCKETS.KEY_ITEMS] = { offset = "bagPocket_KeyItems_offset", count = "bagPocket_KeyItems_Size" },
    [POCKETS.BALLS] = { offset = "bagPocket_Balls_offset", count = "bagPocket_Balls_Size" },
    [POCKETS.ROGUE_ITEMS] = { offset = "bagRoguemonOffset", count = "bagRoguemonCount", size = "bagRoguemonPocketSize" },
    [POCKETS.TM_HM] = { offset = "bagPocket_TmHm_offset", count = "bagPocket_TmHm_Size" },
    [POCKETS.BERRIES] = { offset = "bagPocket_Berries_offset", count = "bagPocket_Berries_Size" },
}

local function resolveCount(cfg)
    local count = GameSettings[cfg.count]
    if count and count > 0 then
        return count
    end
    local sizeBytes = cfg.size and GameSettings[cfg.size] or nil
    if sizeBytes and sizeBytes > 0 then
        return math.floor(sizeBytes / 4)
    end
    return 0
end

local function logDebug(msg)
    local f = io.open("c:\\Users\\nitro\\Desktop\\RogueMON\\roguemon_debug.log", "a")
    if f then
        f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. msg .. "\n")
        f:close()
    end
    print(msg)
end

local function refreshTracker()
    if Roguemon and Roguemon.TrackerDataManager and Roguemon.TrackerDataManager.readState then
        Roguemon.TrackerDataManager.readState()
    end
    if Program and Program.redraw then
        Program.redraw(true)
    end
end



local function getPermanentTypesOfPokemon(pokemon)
    if not pokemon then return nil end
    local personalityHex = string.format("0x%X", pokemon.personality or 0)
    if RoguemonStreamer.settings.alteredTypes and RoguemonStreamer.settings.alteredTypes[personalityHex] then
        local entry = RoguemonStreamer.settings.alteredTypes[personalityHex]
        return entry[1], entry[2]
    end

    local speciesInfo = PokemonData.Pokemon[pokemon.pokemonID or 0] or {}
    local speciesTypes = speciesInfo.types or {}
    
    local function getTypeIdByName(typeName)
        if not typeName then return nil end
        local lower = typeName:lower()
        for idx, name in pairs(PokemonData.TypeIndexMap) do
            if name == lower then
                return idx
            end
        end
        return nil
    end

    local t1 = getTypeIdByName(speciesTypes[1]) or 0
    local t2 = getTypeIdByName(speciesTypes[2]) or t1
    return t1, t2
end

local STAT_NAMES = {
    atk = "Attack",
    def = "Defense",
    spe = "Speed",
    spa = "Sp. Attack",
    spd = "Sp. Defense",
    acc = "Accuracy",
    eva = "Evasion"
}

local STAT_LABELS = {
    atk = "Atk",
    def = "Def",
    spe = "Spe",
    spa = "SpA",
    spd = "SpD",
    acc = "Acc",
    eva = "Eva"
}

-- Event definitions
local POSITIVE_EVENTS_CUMULATIVE = {
    "Restore PP", "Cure Status", "Restore HP",
    "Give Healing Item", "Give Status Item", "Give PP Item", "Stat Boost",
    "Power Boost", "Speed Boost", "PP Up"
}

local POSITIVE_EVENTS_MILESTONE = {
    "Restore PP", "Full Restore",
    "Give Healing Item", "Give Utility Item", "Give Utility Items", "Give PP Item", "Stat Boost",
    "Permanent Type Change", "Permanent Nature Change", "Permanent Ability Change",
    "Powerhouse Boost", "No Guard Plus", "Turbo Genetics", "Darwinism", "Let's Dance"
}

local function pickPositiveMilestoneEvent(subCount)
    -- Check if active mon is already filtered for evolution events
    local leadMon = Battle.getViewedPokemon(true)
    local isFiltered = false
    if leadMon and leadMon.personality then
        local phex = string.format("0x%X_%d", leadMon.personality, leadMon.pokemonID or 0)
        if RoguemonStreamer.settings.persistent.evolutionFilteredPids and RoguemonStreamer.settings.persistent.evolutionFilteredPids[phex] then
            isFiltered = true
        end
    end

    if subCount >= 50 then
        local roll = RoguemonStreamer.random(1, 100)
        if roll <= 5 then
            return "Increase Healing Limit"
        elseif roll <= 10 then
            return "Increase Status Limit"
        elseif roll <= 20 then
            if isFiltered then
                local others = {
                    "Give Healing Item", "Give Utility Items", "Give PP Item",
                    "Permanent Type Change", "Permanent Nature Change", "Permanent Ability Change",
                    "Powerhouse Boost", "No Guard Plus", "Omniboost", "Game Changer", "Try Harder", "Let's Dance"
                }
                return others[RoguemonStreamer.random(1, #others)]
            else
                return "Darwinism"
            end
        else
            local others = {
                "Give Healing Item", "Give Utility Items", "Give PP Item",
                "Permanent Type Change", "Permanent Nature Change", "Permanent Ability Change",
                "Powerhouse Boost", "No Guard Plus", "Omniboost", "Game Changer", "Try Harder", "Let's Dance"
            }
            return others[RoguemonStreamer.random(1, #others)]
        end
    elseif subCount >= 10 then
        local roll = RoguemonStreamer.random(1, 100)
        if roll <= 7 then
            return "Full Restore"
        elseif roll <= 10 then
            return "Increase Healing Limit"
        elseif roll <= 13 then
            return "Increase Status Limit"
        elseif roll <= 18 then
            if isFiltered then
                local others = {
                    "Give Healing Item", "Give Utility Items", "Give PP Item", "Stat Boost",
                    "Permanent Type Change", "Permanent Nature Change", "Permanent Ability Change",
                    "Powerhouse Boost", "No Guard Plus", "Omniboost", "Evolution Power",
                    "Game Changer", "Try Harder", "Let's Dance"
                }
                return others[RoguemonStreamer.random(1, #others)]
            else
                return "Darwinism"
            end
        else
            local others = {
                "Give Healing Item", "Give Utility Items", "Give PP Item", "Stat Boost",
                "Permanent Type Change", "Permanent Nature Change", "Permanent Ability Change",
                "Powerhouse Boost", "No Guard Plus", "Omniboost", "Evolution Power", "Turbo Genetics",
                "Game Changer", "Try Harder", "Let's Dance"
            }
            if isFiltered then
                for idx, name in ipairs(others) do
                    if name == "Turbo Genetics" then
                        table.remove(others, idx)
                        break
                    end
                end
            end
            return others[RoguemonStreamer.random(1, #others)]
        end
    else
        -- Standard Milestone (5-9 subs)
        local roll = RoguemonStreamer.random(1, 100)
        if roll <= 5 then
            return "Full Restore"
        elseif roll <= 10 then
            return "Game Changer"
        elseif roll <= 15 then
            return "Try Harder"
        else
            local others = {
                "Restore PP", "Give Healing Item", "Give Utility Item", "Give PP Item", "Stat Boost",
                "Permanent Type Change", "Permanent Nature Change", "Permanent Ability Change",
                "Powerhouse Boost", "No Guard Plus", "Turbo Genetics", "Evolution Power", "Let's Dance"
            }
            if isFiltered then
                for idx, name in ipairs(others) do
                    if name == "Turbo Genetics" then
                        table.remove(others, idx)
                        break
                    end
                end
            end
            return others[RoguemonStreamer.random(1, #others)]
        end
    end
end

local function pickNegativeMilestoneEvent(subCount)
    if subCount >= 50 then
        local roll = RoguemonStreamer.random(1, 100)
        if roll <= 10 then
            return "Out of Control"
        elseif roll <= 20 then
            return "Omnimalus"
        elseif roll <= 30 then
            return "Mystification"
        else
            local others = {
                "Disable Move", "PP Deplete",
                "Permanent Type Change", "Permanent Nature Change", "Permanent Ability Change",
                "Remove Big Healing Item", "Remove Utility Items", "No Guard Minus", "Overwhelmed"
            }
            return others[RoguemonStreamer.random(1, #others)]
        end
    elseif subCount >= 10 then
        local roll = RoguemonStreamer.random(1, 100)
        if roll <= 10 then
            return "Out of Control"
        elseif roll <= 20 then
            return "Omnimalus"
        elseif roll <= 30 then
            return "Mystification"
        elseif roll <= 40 then
            return "Overwhelmed"
        else
            local others = {
                "Disable Move", "Stat Debuff", "PP Deplete",
                "Permanent Type Change", "Permanent Nature Change", "Permanent Ability Change",
                "Remove Big Healing Item", "Remove Utility Items", "No Guard Minus"
            }
            return others[RoguemonStreamer.random(1, #others)]
        end
    else
        -- Standard Milestone (5-9 subs)
        local others = {
            "Overwhelmed", "Disable Move", "Stat Debuff", "PP Deplete",
            "Permanent Type Change", "Permanent Nature Change", "Permanent Ability Change",
            "Remove Big Healing Item", "Remove Utility Item", "Out of Control",
            "No Guard Minus", "Mystification", "Let's Dance"
        }
        return others[RoguemonStreamer.random(1, #others)]
    end
end



local function getDamagingMoveIds()
    local list = {}
    local total = MoveData.getTotal()
    for id = 1, total do
        local m = MoveData.Moves[id]
        if m and m.name and m.name ~= "???" then
            local powerStr = m.power or "0"
            local powerVal = tonumber(powerStr) or 0
            local category = m.category or MoveData.Categories.PHYSICAL
            if category ~= MoveData.Categories.STATUS and powerVal > 0 then
                table.insert(list, id)
            end
        end
    end
    if #list == 0 then
        list = { 1, 2, 33, 57, 85, 98 }
    end
    return list
end

local function getValidMoveIds()
    local list = {}
    local total = MoveData.getTotal()
    for id = 1, total do
        local m = MoveData.Moves[id]
        if m and m.name and m.name ~= "???" and m.name ~= "" and m.name ~= "None" then
            table.insert(list, id)
        end
    end
    if #list == 0 then
        list = { 1, 2, 33, 57, 85, 98 }
    end
    return list
end

local NEGATIVE_EVENTS_CUMULATIVE = {
    "Inflict Status", "Disable Move", "Power Debuff", "Speed Debuff",
    "PP Cut", "Stat Debuff", "Temp Type Change",
    "Remove Healing Item", "Remove Status Item", "Overwhelmed"
}

local NEGATIVE_EVENTS_MILESTONE = {
    "Overwhelmed", "Disable Move", "Stat Debuff", "PP Deplete",
    "Permanent Type Change", "Permanent Nature Change", "Permanent Ability Change",
    "Remove Big Healing Item", "Remove Utility Item", "Remove Utility Items",
    "Out of Control", "Omnimalus", "No Guard Minus", "Mystification", "Let's Dance"
}

local getPartyMonMoves
local getDisabledMoveId
local getActivePartyIndex
local getBattleMonsAddress
local getPartyMonStats
local wrapGetPokemonTypes
local wrapBuildTrackerScreenDisplay
local wrapBuildPokemonInfoDisplay
local wrapDrawMovesArea
local wrapGetAbilityId
local wrapGetEffectiveness
local wrapCheckForGameOver
local generateNature
local generateAbility
local generateTyping
local isActionSelectionPhaseActive

function RoguemonStreamer.resetRunState(isSilent)
    RoguemonStreamer.outcomeWatchRegistered = nil
    RoguemonStreamer.lastBattleOutcome = nil
    if not RoguemonStreamer.settings or not RoguemonStreamer.settings.persistent then
        return
    end

    RoguemonStreamer.settings.persistent.statBuffs = {}
    RoguemonStreamer.settings.persistent.outOfControlTurns = 0
    RoguemonStreamer.settings.persistent.queuedOutOfControlTurns = 0
    
    RoguemonStreamer.settings.persistent.tempTypeChange = nil
    RoguemonStreamer.settings.persistent.tempTypeApplied = nil
    RoguemonStreamer.settings.persistent.queuedTempTypes = {}
    
    RoguemonStreamer.settings.persistent.disabledMoveId = nil
    RoguemonStreamer.settings.persistent.disabledMoveTurns = nil
    RoguemonStreamer.settings.persistent.disabledMoveApplied = nil
    RoguemonStreamer.settings.persistent.queuedDisableTurns = {}
    
    RoguemonStreamer.settings.persistent.queuedStatuses = {}
    RoguemonStreamer.settings.persistent.queuedDamageAndStatus = {}
    RoguemonStreamer.settings.persistent.queuedConfusion = nil
    
    RoguemonStreamer.settings.persistent.noGuardPlusActive = nil
    RoguemonStreamer.settings.persistent.noGuardPlusApplied = nil
    RoguemonStreamer.settings.persistent.noGuardMinusActive = nil
    RoguemonStreamer.settings.persistent.noGuardMinusApplied = nil
    RoguemonStreamer.settings.persistent.queuedNoGuards = {}

    RoguemonStreamer.settings.persistent.omnimalusActive = nil
    RoguemonStreamer.settings.persistent.queuedOmnimalusCount = 0
    RoguemonStreamer.settings.persistent.overwhelmedActive = nil
    RoguemonStreamer.settings.persistent.queuedOverwhelmedCount = 0

    RoguemonStreamer.settings.persistent.pendingRemovals = {
        healing = 0,
        utility_status = 0,
        big_healing = 0,
        utility_valuable = 0,
    }

    RoguemonStreamer.settings.persistent.gameChangerActive = nil
    RoguemonStreamer.settings.persistent.gameChangerApplied = nil
    RoguemonStreamer.settings.persistent.tryHarderActive = nil
    RoguemonStreamer.settings.persistent.tryHarderApplied = nil
    RoguemonStreamer.settings.persistent.mystificationActive = nil
    RoguemonStreamer.settings.persistent.mystificationApplied = nil
    RoguemonStreamer.settings.persistent.hpCapBoost = 0
    RoguemonStreamer.settings.persistent.statusCapBoost = 0
    RoguemonStreamer.settings.persistent.outOfControlCP = nil

    if LetsDanceScreen and type(LetsDanceScreen.close) == "function" and (LetsDanceScreen.ActiveRequest or Program.currentScreen == LetsDanceScreen) then
        LetsDanceScreen.close()
    end
    RoguemonStreamer.ActiveLetsDanceRequest = nil

    if RequestHandler and RequestHandler.Requests then
        RequestHandler.Requests = {}
    end
    if Network and Network.CurrentConnection and Network.CurrentConnection.InboundFile then
        FileManager.encodeToJsonFile(Network.CurrentConnection.InboundFile, {})
    end
    RoguemonStreamer.saveSettings()
    print("[RogueMon Streamer] Run state has been completely reset.")
    if not isSilent then
        RoguemonStreamer.notifyStreamer("Run State Reset!", "magikarp.png")
    end
    
    if StreamerOptionsScreen and type(StreamerOptionsScreen.refreshButtons) == "function" then
        StreamerOptionsScreen.refreshButtons()
    end
    Program.redraw(true)
end

function RoguemonStreamer.checkForUpdatesQuery()
    print("[RogueMon Streamer] Checking for updates on GitHub...")
    
    local token = ""
    local diskSettings = FileManager.decodeJsonFile(RoguemonStreamer.settingsPath)
    if diskSettings and diskSettings.githubToken then
        token = diskSettings.githubToken
    end
    if token == "" and RoguemonStreamer.settings and RoguemonStreamer.settings.githubToken then
        token = RoguemonStreamer.settings.githubToken
    end
    
    local authHeader = ""
    if token ~= "" then
        authHeader = string.format('-H "Authorization: Bearer %s" ', token)
    end
    
    local url = "https://api.github.com/repos/drnarrow/roguemon-streamer-extension-releases/releases/latest"
    local cmd = string.format('curl -k -s -L %s"%s"', authHeader, url)
    
    Utils.tempDisableBizhawkSound()
    local success, fileLines = FileManager.tryOsExecute(cmd)
    Utils.tempEnableBizhawkSound()
    
    if not success or not fileLines or #fileLines == 0 then
        print("[RogueMon Streamer] Error: Unable to fetch release info from GitHub.")
        return false, nil
    end
    
    local response = table.concat(fileLines, "\n")
    local latestTag = string.match(response, '"tag_name":%s*"([^"]+)"')
    
    if not latestTag then
        print("[RogueMon Streamer] Error: Tag name not found in GitHub response.")
        return false, nil
    end
    
    local cleanTag = latestTag:gsub("^[vV]", "")
    local currentVersion = RoguemonStreamer.selfObject and RoguemonStreamer.selfObject.version
    if not currentVersion then
        print("[RogueMon Streamer] Error: Extension version not found (metadata object missing).")
        return false, nil
    end
    
    local requiresUpdate = Utils.isNewerVersion(cleanTag, currentVersion)
    if requiresUpdate then
        print(string.format("[RogueMon Streamer] New version available! Current: v%s, Latest: v%s", currentVersion, cleanTag))
        local releaseUrl = "https://github.com/drnarrow/roguemon-streamer-extension-releases/releases"
        return true, releaseUrl
    end
    
    print(string.format("[RogueMon Streamer] Extension is up to date (v%s).", currentVersion))
    return false, nil
end

function RoguemonStreamer.downloadAndInstallUpdate()
    print("[RogueMon Streamer] Starting update download and install...")
    
    local token = ""
    local diskSettings = FileManager.decodeJsonFile(RoguemonStreamer.settingsPath)
    if diskSettings and diskSettings.githubToken then
        token = diskSettings.githubToken
    end
    if token == "" and RoguemonStreamer.settings and RoguemonStreamer.settings.githubToken then
        token = RoguemonStreamer.settings.githubToken
    end
    
    local authHeader = ""
    if token ~= "" then
        authHeader = string.format('-H "Authorization: Bearer %s" ', token)
    end
    
    local tarUrl = "https://api.github.com/repos/drnarrow/roguemon-streamer-extension-releases/tarball/main"
    local archiveFilePath = "update.tar.gz"
    
    local destinationFolder = FileManager.getExtensionsFolderPath()
    local isOnWindows = (FileManager.slash == "\\")
    
    local commands = {}
    if isOnWindows then
        table.insert(commands, string.format('cd "%s"', destinationFolder))
        table.insert(commands, string.format('curl -k -L %s"%s" -o "%s" --ssl-no-revoke', authHeader, tarUrl, archiveFilePath))
        table.insert(commands, string.format('tar -xzf "%s" --strip-components=1', archiveFilePath))
        table.insert(commands, string.format('del "%s"', archiveFilePath))
    else
        table.insert(commands, string.format('cd "%s"', destinationFolder))
        table.insert(commands, string.format('curl -k -L %s"%s" -o "%s"', authHeader, tarUrl, archiveFilePath))
        table.insert(commands, string.format('tar -xzf "%s" --strip-components=1', archiveFilePath))
        table.insert(commands, string.format('rm -f "%s"', archiveFilePath))
    end
    
    local fullCmd = table.concat(commands, " && ")
    print("[RogueMon Streamer] Running update commands...")
    
    Utils.tempDisableBizhawkSound()
    local result = os.execute(fullCmd)
    Utils.tempEnableBizhawkSound()
    
    if result == true or result == 0 then
        print("[RogueMon Streamer] Update download & extract completed successfully!")
        CustomCode.reloadExtension("RoguemonStreamerExtension")
        return true
    else
        print("[RogueMon Streamer] Error: Update commands execution failed.")
        return false
    end
end

local function getBattlePpOffset()
    local statStageOffset = GameSettings.offsetBattlePokemonStatStages or 0x18
    if statStageOffset == 0x18 then
        return 0x25 -- RogueMON PP offset
    elseif statStageOffset == 0x1C then
        return 0x28 -- Standard Emerald PP offset
    else
        return 0x25 -- Fallback to RogueMON PP offset
    end
end

local function getBattleStatus1Offset()
    local volOffset = GameSettings.battleVolatilesOffset or 0x50
    return volOffset - 4
end

function RoguemonStreamer.initialize(extensionSelf)
    RoguemonStreamer.seed_lcg()
    
    RoguemonStreamer.selfObject = extensionSelf
    RoguemonStreamer.extensionDir = extensionSelf.extensionDir
    RoguemonStreamer.settingsPath = extensionSelf.extensionDir .. "data" .. FileManager.slash .. "twitch_settings.json"
    RoguemonStreamer.loadSettings()
    
    -- Register Custom Events
    if EventHandler and EventHandler.addNewEvent then
        EventHandler.addNewEvent(EventHandler.IEvent:new({
            Key = "TwitchSubEvent",
            Type = EventHandler.EventTypes.Game,
            Name = "Twitch Sub Event",
            TriggerEffect = "Processes sub and gift events to trigger positive or negative gameplay events.",
            IsEnabled = true,
            Process = function(self, request)
                return RoguemonStreamer.processRequest(request)
            end,
            Fulfill = function(self, request)
                if RoguemonStreamer.settings and RoguemonStreamer.settings.debug then
                    return request.FulfillmentResult or "Event Fulfilled Successfully"
                end
                return ""
            end
        }))
        print("[RogueMon Streamer] Registered custom TwitchSubEvent handler.")

        EventHandler.addNewEvent(EventHandler.IEvent:new({
            Key = "TwitchChannelPointsEvent",
            Type = EventHandler.EventTypes.Game,
            Name = "Twitch Channel Points Event",
            TriggerEffect = "Processes channel point redemptions to trigger specific gameplay events.",
            IsEnabled = true,
            Process = function(self, request)
                return RoguemonStreamer.processChannelPointsRequest(request)
            end,
            Fulfill = function(self, request)
                if RoguemonStreamer.settings and RoguemonStreamer.settings.debug then
                    return request.FulfillmentResult or "Event Fulfilled Successfully"
                end
                return ""
            end
        }))
        print("[RogueMon Streamer] Registered custom TwitchChannelPointsEvent handler.")
    end

    wrapGetPokemonTypes()
    wrapBuildTrackerScreenDisplay()
    wrapBuildPokemonInfoDisplay()
    wrapDrawMovesArea()
    wrapGetAbilityId()
    wrapGetEffectiveness()
    wrapCheckForGameOver()

    RoguemonStreamer.updateItemIds()
    RoguemonStreamer.applyRuntimeHooks()

    -- Dynamically inject UI controls into SingleExtensionScreen.Buttons
    if SingleExtensionScreen and SingleExtensionScreen.Buttons then
        if SingleExtensionScreen.Buttons.CheckForUpdates then
            RoguemonStreamer.originalCheckForUpdates = RoguemonStreamer.originalCheckForUpdates or {
                box = {
                    SingleExtensionScreen.Buttons.CheckForUpdates.box[1],
                    SingleExtensionScreen.Buttons.CheckForUpdates.box[2],
                    SingleExtensionScreen.Buttons.CheckForUpdates.box[3],
                    SingleExtensionScreen.Buttons.CheckForUpdates.box[4]
                },
                getText = SingleExtensionScreen.Buttons.CheckForUpdates.getText,
            }
            SingleExtensionScreen.Buttons.CheckForUpdates.box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 3, Constants.SCREEN.MARGIN + 120, 61, 11 }
            SingleExtensionScreen.Buttons.CheckForUpdates.getText = function(self)
                if self.updateStatus == "Available" then
                    return "Update!"
                elseif self.updateStatus == "No Update" then
                    return "No Update"
                elseif self.updateStatus == "Unchecked" then
                    return "Check Updates"
                else
                    return self.updateStatus
                end
            end
        end

        SingleExtensionScreen.Buttons.ResetRun = {
            type = Constants.ButtonTypes.FULL_BORDER,
            getText = function(self) return "Reset" end,
            box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 66, Constants.SCREEN.MARGIN + 120, 26, 11 },
            isVisible = function(self)
                return SingleExtensionScreen.extension ~= nil and SingleExtensionScreen.extension.selfObject.name == "RogueMon Streamer"
            end,
            onClick = function(self)
                RoguemonStreamer.resetRunState()
            end,
        }
        SingleExtensionScreen.Buttons.ResetRun.textColor = SingleExtensionScreen.Colors.text
        SingleExtensionScreen.Buttons.ResetRun.boxColors = { SingleExtensionScreen.Colors.border, SingleExtensionScreen.Colors.boxFill }

        SingleExtensionScreen.Buttons.ToggleTwitchSub = {
            type = Constants.ButtonTypes.CHECKBOX,
            getText = function(self)
                return " Twitch Subs"
            end,
            toggleState = true,
            clickableArea = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 10, Constants.SCREEN.MARGIN + 52, 130, 10 },
            box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 10, Constants.SCREEN.MARGIN + 52, 8, 8 },
            updateSelf = function(self)
                if not RoguemonStreamer or not RoguemonStreamer.settings then return end
                self.toggleState = (RoguemonStreamer.settings.enableTwitchSub == true)
            end,
            isVisible = function(self)
                return SingleExtensionScreen.extension ~= nil and SingleExtensionScreen.extension.selfObject.name == "RogueMon Streamer"
            end,
            onClick = function(self)
                if not RoguemonStreamer or not RoguemonStreamer.settings then return end
                RoguemonStreamer.settings.enableTwitchSub = not RoguemonStreamer.settings.enableTwitchSub
                RoguemonStreamer.saveSettings()
                self:updateSelf()
                Program.redraw(true)
            end,
        }
        SingleExtensionScreen.Buttons.ToggleTwitchSub.textColor = SingleExtensionScreen.Colors.text
        SingleExtensionScreen.Buttons.ToggleTwitchSub.boxColors = { SingleExtensionScreen.Colors.border, SingleExtensionScreen.Colors.boxFill }

        SingleExtensionScreen.Buttons.ToggleChannelPoints = {
            type = Constants.ButtonTypes.CHECKBOX,
            getText = function(self)
                return " Channel Points"
            end,
            toggleState = true,
            clickableArea = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 10, Constants.SCREEN.MARGIN + 66, 130, 10 },
            box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 10, Constants.SCREEN.MARGIN + 66, 8, 8 },
            updateSelf = function(self)
                if not RoguemonStreamer or not RoguemonStreamer.settings then return end
                self.toggleState = (RoguemonStreamer.settings.enableChannelPoints == true)
            end,
            isVisible = function(self)
                return SingleExtensionScreen.extension ~= nil and SingleExtensionScreen.extension.selfObject.name == "RogueMon Streamer"
            end,
            onClick = function(self)
                if not RoguemonStreamer or not RoguemonStreamer.settings then return end
                RoguemonStreamer.settings.enableChannelPoints = not RoguemonStreamer.settings.enableChannelPoints
                RoguemonStreamer.saveSettings()
                self:updateSelf()
                Program.redraw(true)
            end,
        }
        SingleExtensionScreen.Buttons.ToggleChannelPoints.textColor = SingleExtensionScreen.Colors.text
        SingleExtensionScreen.Buttons.ToggleChannelPoints.boxColors = { SingleExtensionScreen.Colors.border, SingleExtensionScreen.Colors.boxFill }

        -- Wrap SingleExtensionScreen.drawScreen to adjust layout and draw description lower
        _G.RoguemonStreamer_Backups = _G.RoguemonStreamer_Backups or {}
        if not _G.RoguemonStreamer_Backups.SingleExtensionDrawScreen then
            _G.RoguemonStreamer_Backups.SingleExtensionDrawScreen = SingleExtensionScreen.drawScreen
        end
        RoguemonStreamer.originalSingleExtensionDrawScreen = _G.RoguemonStreamer_Backups.SingleExtensionDrawScreen
        
        SingleExtensionScreen.drawScreen = function()
            local isOurs = (SingleExtensionScreen.extension ~= nil and SingleExtensionScreen.extension.selfObject.name == "RogueMon Streamer")
            local origDesc = nil
            if isOurs then
                origDesc = SingleExtensionScreen.extension.selfObject.description
                SingleExtensionScreen.extension.selfObject.description = ""
            end

            RoguemonStreamer.originalSingleExtensionDrawScreen()

            if isOurs and origDesc then
                SingleExtensionScreen.extension.selfObject.description = origDesc
                    
                    local topBox = {
                        x = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN,
                        y = Constants.SCREEN.MARGIN,
                        width = Constants.SCREEN.RIGHT_GAP - (Constants.SCREEN.MARGIN * 2),
                        height = Constants.SCREEN.HEIGHT - (Constants.SCREEN.MARGIN * 2),
                        text = Theme.COLORS[SingleExtensionScreen.Colors.text],
                        border = Theme.COLORS[SingleExtensionScreen.Colors.border],
                        fill = Theme.COLORS[SingleExtensionScreen.Colors.boxFill],
                        shadow = Utils.calcShadowColor(Theme.COLORS[SingleExtensionScreen.Colors.boxFill]),
                    }
                    
                    local textLineY = Constants.SCREEN.MARGIN + 80
                    local wrappedDesc = Utils.getWordWrapLines(origDesc, 32)
                    for _, line in pairs(wrappedDesc) do
                        Drawing.drawText(topBox.x + 2, textLineY, line, topBox.text, topBox.shadow)
                        textLineY = textLineY + Constants.SCREEN.LINESPACING
                    end
                end
            end

        print("[RogueMon Streamer] Dynamically injected 'Reset Run' & mode checkboxes into SingleExtensionScreen.")
    end

    RoguemonStreamer.initialized = true
    print("[RogueMon Streamer] Standalone Extension Initialized.")

    RoguemonStreamer.syncCapModifiers()

    if Roguemon and Roguemon.Leaderboard then
        -- Back up original functions if not already backed up
        RoguemonStreamer.originalLeaderboardFuncs = RoguemonStreamer.originalLeaderboardFuncs or {
            init = Roguemon.Leaderboard.init,
            onRomEvent = Roguemon.Leaderboard.onRomEvent,
            checkForFrameSkip = Roguemon.Leaderboard.checkForFrameSkip,
            confirmLogViewWillEndRun = Roguemon.Leaderboard.confirmLogViewWillEndRun,
            confirmOpenBookWillEndRun = Roguemon.Leaderboard.confirmOpenBookWillEndRun,
            confirmEnableWithOpenBookOff = Roguemon.Leaderboard.confirmEnableWithOpenBookOff,
        }

        if Roguemon.Leaderboard.LeaderboardUtils and not RoguemonStreamer.originalLeaderboardFuncs.isLeaderboardEnabled then
            RoguemonStreamer.originalLeaderboardFuncs.isLeaderboardEnabled = Roguemon.Leaderboard.LeaderboardUtils.isLeaderboardEnabled
        end

        -- Override to disable all leaderboard operations and allow rewind/Open Book
        Roguemon.Leaderboard.init = function() end
        Roguemon.Leaderboard.onRomEvent = function() end
        Roguemon.Leaderboard.checkForFrameSkip = function() end
        Roguemon.Leaderboard.confirmLogViewWillEndRun = function() return true end
        Roguemon.Leaderboard.confirmOpenBookWillEndRun = function() return true end
        Roguemon.Leaderboard.confirmEnableWithOpenBookOff = function() return true end
        if Roguemon.Leaderboard.LeaderboardUtils then
            Roguemon.Leaderboard.LeaderboardUtils.isLeaderboardEnabled = function() return false end
        end

        Roguemon.Leaderboard.disabled = true

        _G.print("[RogueMon Streamer] Leaderboard disabled because Streamer Extension is active.")
        if client and type(client.enablerewind) == "function" then
            client.enablerewind(true)
        end
    end
end

local lcg_state = 123456789

local function lcg_random()
    lcg_state = (1103515245 * lcg_state + 12345) % 2147483648
    return lcg_state
end

function RoguemonStreamer.seed_lcg()
    local frame = (emu and emu.framecount) and emu.framecount() or 0
    lcg_state = (os.time() + math.floor(os.clock() * 1000000) + frame) % 2147483648
    for i = 1, 10 do
        lcg_random()
    end
end

function RoguemonStreamer.random(min, max)
    local val = lcg_random()
    if max == nil then
        return math.floor((val / 2147483648) * min) + 1
    else
        local range = max - min + 1
        return math.floor((val / 2147483648) * range) + min
    end
end

function RoguemonStreamer.addStatBuff(stat, value, duration)
    RoguemonStreamer.settings.persistent.statBuffs = RoguemonStreamer.settings.persistent.statBuffs or {}
    if RoguemonStreamer.settings.persistent.statBuffs.stat ~= nil then
        RoguemonStreamer.settings.persistent.statBuffs = { RoguemonStreamer.settings.persistent.statBuffs }
    end
    
    table.insert(RoguemonStreamer.settings.persistent.statBuffs, {
        stat = stat,
        value = math.max(-6, math.min(6, value)),
        remaining = duration
    })
    
    RoguemonStreamer.saveSettings()
    logDebug(string.format("addStatBuff added: %s value=%d, duration=%d", stat, value, duration))

    if not RoguemonStreamer.suppressStatBuffArrows and Battle.inActiveBattle() then
        if value > 0 then
            RoguemonStreamer.addAnimation(RoguemonStreamer.createStatArrowsAnimation(true))
        elseif value < 0 then
            RoguemonStreamer.addAnimation(RoguemonStreamer.createStatArrowsAnimation(false))
        end
    end

    if Battle.inActiveBattle() then
        logDebug("addStatBuff: In battle, calling applyStatBuffsToBattle")
        RoguemonStreamer.ActiveStatBuffsApplied = false
        RoguemonStreamer.applyStatBuffsToBattle()
    end
end

function RoguemonStreamer.applyStatBuffsToBattle(isStartOfCombat)
    logDebug(string.format("applyStatBuffsToBattle: isStartOfCombat=%s", tostring(isStartOfCombat)))
    if not Battle.inActiveBattle() then
        logDebug(string.format("applyStatBuffsToBattle: returning early. inActiveBattle=%s", tostring(Battle.inActiveBattle())))
        return
    end
    RoguemonStreamer.ActiveStatBuffsAppliedThisBattle = true
    RoguemonStreamer.ActiveStatBuffsApplied = true
    local activeIdx = getActivePartyIndex()
    if activeIdx ~= 1 then
        return
    end
    local battleSlot = RoguemonStreamer.getBattleSlot(activeIdx)
    logDebug(string.format("applyStatBuffsToBattle: activeIdx=%s, battleSlot=%s", tostring(activeIdx), tostring(battleSlot)))
    if battleSlot == nil then
        logDebug("applyStatBuffsToBattle: battleSlot is nil, returning")
        return
    end
    local battleMonsAddress = GameSettings.gBattleMons + (battleSlot * (GameSettings.sizeofBattlePokemon or 0x58))
    logDebug(string.format("applyStatBuffsToBattle: battleMonsAddress=0x%X", battleMonsAddress or 0))
    if not battleMonsAddress then
        logDebug("applyStatBuffsToBattle: battleMonsAddress is nil/0, returning")
        return
    end

    local buffs = RoguemonStreamer.settings.persistent.statBuffs or {}
    logDebug(string.format("applyStatBuffsToBattle: count of buffs in settings = %d", #buffs))
    local accumulated = { atk = 0, def = 0, spe = 0, spa = 0, spd = 0, acc = 0, eva = 0 }
    for i, buff in ipairs(buffs) do
        logDebug(string.format("  buff %d: stat=%s, value=%s, remaining=%s", i, tostring(buff.stat), tostring(buff.value), tostring(buff.remaining)))
        if buff.remaining and buff.remaining > 0 then
            local statKey = buff.stat
            if accumulated[statKey] ~= nil then
                accumulated[statKey] = accumulated[statKey] + buff.value
            end
        end
    end

    -- Subtract 1 stage from all stats if Omnimalus is active
    local p = RoguemonStreamer.settings.persistent
    local isOmnimalusActive = p.omnimalusActive == true or (type(p.omnimalusActive) == "number" and p.omnimalusActive > 0)
    if isOmnimalusActive then
        logDebug("applyStatBuffsToBattle: Omnimalus active, subtracting 1 stage from all stats")
        for statKey, _ in pairs(accumulated) do
            accumulated[statKey] = accumulated[statKey] - 1
        end
    end

    local statStageOffset = GameSettings.offsetBattlePokemonStatStages or 0x18
    for stat, value in pairs(accumulated) do
        local cappedValue = math.max(-6, math.min(6, value))
        local finalStage = 6 + cappedValue
        local finalStageOffset = nil
        if stat == "atk" then finalStageOffset = statStageOffset + 1
        elseif stat == "def" then finalStageOffset = statStageOffset + 2
        elseif stat == "spe" then finalStageOffset = statStageOffset + 3
        elseif stat == "spa" then finalStageOffset = statStageOffset + 4
        elseif stat == "spd" then finalStageOffset = statStageOffset + 5
        elseif stat == "acc" then finalStageOffset = statStageOffset + 6
        elseif stat == "eva" then finalStageOffset = statStageOffset + 7
        end
        if finalStageOffset then
            Memory.writebyte(battleMonsAddress + finalStageOffset, finalStage)
            logDebug(string.format("  Wrote %s (+%d -> stage %d) to RAM 0x%X", stat, value, finalStage, battleMonsAddress + finalStageOffset))
        end
    end

    if Battle then
        Battle.statStageDirty = true
        logDebug("applyStatBuffsToBattle: set Battle.statStageDirty = true")
    end
    if Roguemon and Roguemon.Core and Roguemon.Core.Battle then
        Roguemon.Core.Battle.statStageDirty = true
        logDebug("applyStatBuffsToBattle: set Roguemon.Core.Battle.statStageDirty = true")
    end

    if isStartOfCombat then
        local hasPositive = false
        local hasNegative = false
        for stat, value in pairs(accumulated) do
            if value > 0 then
                hasPositive = true
            elseif value < 0 then
                hasNegative = true
            end
        end
        if hasPositive then
            RoguemonStreamer.addAnimation(RoguemonStreamer.createStatArrowsAnimation(true))
        end
        if hasNegative then
            RoguemonStreamer.addAnimation(RoguemonStreamer.createStatArrowsAnimation(false))
        end
    end

    refreshTracker()
end

function RoguemonStreamer.shutdown()
    RoguemonStreamer.initialized = false
    RoguemonStreamer.outcomeWatchRegistered = nil
    pcall(event.unregisterbyname, "RoguemonNoGuardFlags")
    pcall(event.unregisterbyname, "RoguemonStreamer_gBattleOutcome")
    if Roguemon and Roguemon.Leaderboard and RoguemonStreamer.originalLeaderboardFuncs then
        -- Restore original functions
        Roguemon.Leaderboard.init = RoguemonStreamer.originalLeaderboardFuncs.init
        Roguemon.Leaderboard.onRomEvent = RoguemonStreamer.originalLeaderboardFuncs.onRomEvent
        Roguemon.Leaderboard.checkForFrameSkip = RoguemonStreamer.originalLeaderboardFuncs.checkForFrameSkip
        Roguemon.Leaderboard.confirmLogViewWillEndRun = RoguemonStreamer.originalLeaderboardFuncs.confirmLogViewWillEndRun
        Roguemon.Leaderboard.confirmOpenBookWillEndRun = RoguemonStreamer.originalLeaderboardFuncs.confirmOpenBookWillEndRun
        Roguemon.Leaderboard.confirmEnableWithOpenBookOff = RoguemonStreamer.originalLeaderboardFuncs.confirmEnableWithOpenBookOff
        if Roguemon.Leaderboard.LeaderboardUtils and RoguemonStreamer.originalLeaderboardFuncs.isLeaderboardEnabled then
            Roguemon.Leaderboard.LeaderboardUtils.isLeaderboardEnabled = RoguemonStreamer.originalLeaderboardFuncs.isLeaderboardEnabled
        end

        -- Re-initialize the leaderboard now that the extension is disabled
        Roguemon.Leaderboard.disabled = false
        Roguemon.Leaderboard.init()
        _G.print("[RogueMon Streamer] Leaderboard reactivated.")
    end

    -- Restore SingleExtensionScreen UI elements
    if SingleExtensionScreen and SingleExtensionScreen.Buttons then
        if SingleExtensionScreen.Buttons.CheckForUpdates and RoguemonStreamer.originalCheckForUpdates then
            SingleExtensionScreen.Buttons.CheckForUpdates.box = RoguemonStreamer.originalCheckForUpdates.box
            SingleExtensionScreen.Buttons.CheckForUpdates.getText = RoguemonStreamer.originalCheckForUpdates.getText
            RoguemonStreamer.originalCheckForUpdates = nil
        end
        SingleExtensionScreen.Buttons.CheckUpdates = nil
        SingleExtensionScreen.Buttons.ResetRun = nil
        SingleExtensionScreen.Buttons.ToggleTwitchSub = nil
        SingleExtensionScreen.Buttons.ToggleChannelPoints = nil
    end
    if RoguemonStreamer.originalSingleExtensionDrawScreen then
        SingleExtensionScreen.drawScreen = RoguemonStreamer.originalSingleExtensionDrawScreen
        RoguemonStreamer.originalSingleExtensionDrawScreen = nil
    end

    print("[RogueMon Streamer] Standalone Extension Unloaded.")
end

local function splitCsvLine(line)
    local fields = {}
    local cursor = 1
    while true do
        local nextSemi = string.find(line, ";", cursor)
        if not nextSemi then
            table.insert(fields, string.sub(line, cursor))
            break
        end
        table.insert(fields, string.sub(line, cursor, nextSemi - 1))
        cursor = nextSemi + 1
    end
    return fields
end

local function readAbilityPools(filepath)
    local file = io.open(filepath, "r")
    if not file then
        print("[RogueMon Streamer] Error: Could not open " .. filepath)
        return nil
    end

    local header = file:read("*line")
    if not header then
        file:close()
        return nil
    end
    header = header:gsub("\r", ""):gsub("\n", "")

    local columns = {}
    local colIdx = 1
    local headers = splitCsvLine(header)
    for _, col in ipairs(headers) do
        col = col:gsub("^%s*(.-)%s*$", "%1") -- Trim whitespace
        columns[col] = colIdx
        colIdx = colIdx + 1
    end

    local poolColumns = {
        "Sub5Pos", "Sub10Pos", "Sub20Pos", "Sub50Pos",
        "Sub5Neg", "Sub10Neg", "Sub20Neg", "Sub50Neg"
    }

    local poolCandidates = {}
    for _, colName in ipairs(poolColumns) do
        poolCandidates[colName] = {}
    end

    for line in file:lines() do
        line = line:gsub("\r", ""):gsub("\n", "")
        if line ~= "" then
            local fields = splitCsvLine(line)
            local abilityName = fields[1]
            if abilityName and abilityName ~= "" and abilityName ~= "Name" then
                abilityName = abilityName:gsub("^%s*(.-)%s*$", "%1") -- Trim
                for _, colName in ipairs(poolColumns) do
                    local idx = columns[colName]
                    if idx then
                        local val = fields[idx]
                        if val then
                            val = val:gsub("^%s*(.-)%s*$", "%1") -- Trim
                            if val ~= "" then
                                local entry = { name = abilityName }
                                if val:lower() == "x" then
                                    entry.isX = true
                                    table.insert(poolCandidates[colName], entry)
                                else
                                    local pct = tonumber(string.match(val, "([%d%.]+)%%"))
                                    if pct then
                                        entry.explicitPct = pct
                                        table.insert(poolCandidates[colName], entry)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    file:close()

    local finalPools = {}

    local function findAbilityId(name)
        local cleanTarget = name:lower():gsub("%s+", ""):gsub("%-+", "")
        for id = 1, AbilityData.getTotal() do
            local ability = AbilityData.Abilities[id]
            if ability and ability.name then
                local cleanAbility = ability.name:lower():gsub("%s+", ""):gsub("%-+", "")
                if cleanAbility == cleanTarget then
                    return id
                end
            end
        end
        for id = 1, AbilityData.getTotal() do
            local ability = AbilityData.Abilities[id]
            if ability and ability.name then
                local cleanAbility = ability.name:lower():gsub("%s+", ""):gsub("%-+", "")
                if string.find(cleanAbility, "^" .. cleanTarget) or string.find(cleanAbility, cleanTarget) then
                    return id
                end
            end
        end
        return nil
    end

    for _, colName in ipairs(poolColumns) do
        local candidates = poolCandidates[colName]
        local explicitSum = 0
        local xCount = 0

        for _, c in ipairs(candidates) do
            if c.isX then
                xCount = xCount + 1
            elseif c.explicitPct then
                explicitSum = explicitSum + c.explicitPct
            end
        end

        local remainingPct = 100 - explicitSum
        local xWeight = 0
        if xCount > 0 then
            xWeight = remainingPct / xCount
        end

        local resolvedList = {}
        for _, c in ipairs(candidates) do
            local abId = findAbilityId(c.name)
            if abId then
                local weight = c.explicitPct or xWeight
                if weight > 0 then
                    table.insert(resolvedList, { id = abId, weight = weight })
                end
            else
                -- print("[RogueMon Streamer] Warning: Could not find GBA ability for name: " .. c.name)
            end
        end
        finalPools[colName] = resolvedList
    end

    return finalPools
end

function RoguemonStreamer.loadAbilityPools()
    if RoguemonStreamer.extensionDir and RoguemonStreamer.extensionDir ~= "" then
        local csvPath = RoguemonStreamer.extensionDir .. "data" .. FileManager.slash .. "AbilityPool.csv"
        local file = io.open(csvPath, "r")
        if file then
            file:close()
        else
            csvPath = RoguemonStreamer.extensionDir .. "AbilityPool.csv"
        end

        RoguemonStreamer.abilityPools = readAbilityPools(csvPath)
        if RoguemonStreamer.abilityPools then
            print("[RogueMon Streamer] Loaded ability pools from CSV (" .. csvPath .. "):")
            local poolColumns = {
                "Sub5Pos", "Sub10Pos", "Sub20Pos", "Sub50Pos",
                "Sub5Neg", "Sub10Neg", "Sub20Neg", "Sub50Neg"
            }
            for _, colName in ipairs(poolColumns) do
                local list = RoguemonStreamer.abilityPools[colName] or {}
                print(string.format("  - %s: %d abilities parsed", colName, #list))
            end
        end
    end
end

-- SETTINGS MANAGEMENT
function RoguemonStreamer.loadSettings()
    if RoguemonStreamer.extensionDir and RoguemonStreamer.extensionDir ~= "" then
        RoguemonStreamer.loadAbilityPools()
    end
    local decoded = FileManager.decodeJsonFile(RoguemonStreamer.settingsPath)
    if decoded then
        RoguemonStreamer.settings = decoded
        RoguemonStreamer.settings.enabled = true
        if RoguemonStreamer.settings.githubToken == nil then
            RoguemonStreamer.settings.githubToken = ""
        end
        if RoguemonStreamer.settings.debug == nil then
            RoguemonStreamer.settings.debug = false
        end
        if RoguemonStreamer.settings.enableAnimations == nil then
            RoguemonStreamer.settings.enableAnimations = false
        end
        if RoguemonStreamer.settings.cumulativeGoal == nil then
            RoguemonStreamer.settings.cumulativeGoal = 10
        end
        if RoguemonStreamer.settings.currentProgress == nil then
            RoguemonStreamer.settings.currentProgress = 0
        end
        if RoguemonStreamer.settings.goodChance == nil then
            RoguemonStreamer.settings.goodChance = 50
        end
        if RoguemonStreamer.settings.stats == nil then
            RoguemonStreamer.settings.stats = { totalSubs = 0, totalEvents = 0 }
        end
        if RoguemonStreamer.settings.milestones == nil then
            RoguemonStreamer.settings.milestones = { ["5"] = true, ["10"] = true, ["20"] = true, ["50"] = true }
        end
        if RoguemonStreamer.settings.alteredTypes == nil then
            RoguemonStreamer.settings.alteredTypes = {}
        end
        if RoguemonStreamer.settings.alteredAbilities == nil then
            RoguemonStreamer.settings.alteredAbilities = {}
        end
        if RoguemonStreamer.settings.enableTwitchSub == nil then
            RoguemonStreamer.settings.enableTwitchSub = true
        end
        if RoguemonStreamer.settings.enableChannelPoints == nil then
            RoguemonStreamer.settings.enableChannelPoints = true
        end
        RoguemonStreamer.settings.persistent = RoguemonStreamer.settings.persistent or {}
        RoguemonStreamer.settings.persistent.statBuffs = RoguemonStreamer.settings.persistent.statBuffs or {}
        
        -- Normalize duplicate stats
        if RoguemonStreamer.settings.persistent.statBuffs.stat ~= nil then
            RoguemonStreamer.settings.persistent.statBuffs = { RoguemonStreamer.settings.persistent.statBuffs }
        end
        local newBuffs = {}
        for _, buff in ipairs(RoguemonStreamer.settings.persistent.statBuffs) do
            if buff.stat and buff.remaining and buff.remaining > 0 and buff.value and buff.value ~= 0 then
                table.insert(newBuffs, {
                    stat = buff.stat,
                    value = buff.value,
                    remaining = buff.remaining
                })
            end
        end
        RoguemonStreamer.settings.persistent.statBuffs = newBuffs

        RoguemonStreamer.settings.persistent.queuedTempTypes = RoguemonStreamer.settings.persistent.queuedTempTypes or {}
        RoguemonStreamer.settings.persistent.queuedDisableTurns = RoguemonStreamer.settings.persistent.queuedDisableTurns or {}
        RoguemonStreamer.settings.persistent.queuedDamageAndStatus = RoguemonStreamer.settings.persistent.queuedDamageAndStatus or {}
        RoguemonStreamer.settings.persistent.queuedStatuses = RoguemonStreamer.settings.persistent.queuedStatuses or {}
        RoguemonStreamer.settings.persistent.queuedOutOfControlTurns = RoguemonStreamer.settings.persistent.queuedOutOfControlTurns or 0
        RoguemonStreamer.settings.persistent.queuedOverwhelmedCount = RoguemonStreamer.settings.persistent.queuedOverwhelmedCount or 0
        RoguemonStreamer.settings.persistent.hpCapBoost = RoguemonStreamer.settings.persistent.hpCapBoost or 0
        RoguemonStreamer.settings.persistent.statusCapBoost = RoguemonStreamer.settings.persistent.statusCapBoost or 0
        RoguemonStreamer.settings.persistent.lastAppliedHpBoost = RoguemonStreamer.settings.persistent.lastAppliedHpBoost or RoguemonStreamer.settings.persistent.hpCapBoost
        RoguemonStreamer.settings.persistent.lastAppliedStatusBoost = RoguemonStreamer.settings.persistent.lastAppliedStatusBoost or RoguemonStreamer.settings.persistent.statusCapBoost
        RoguemonStreamer.settings.persistent.evolutionFilteredPids = RoguemonStreamer.settings.persistent.evolutionFilteredPids or {}
        RoguemonStreamer.settings.persistent.pendingRemovals = RoguemonStreamer.settings.persistent.pendingRemovals or {
            healing = 0,
            utility_status = 0,
            big_healing = 0,
            utility_valuable = 0,
        }
        RoguemonStreamer.settings.persistent.hiddenFateActive = nil
        RoguemonStreamer.settings.persistent.hiddenFateApplied = nil
        RoguemonStreamer.settings.persistent.hiddenFateOriginalMoves = nil
        RoguemonStreamer.settings.persistent.hiddenFateOriginalPPs = nil
        RoguemonStreamer.settings.persistent.hiddenFateInitialPP = nil
        RoguemonStreamer.settings.persistent.hiddenFateUsedPP = nil
        RoguemonStreamer.settings.persistent.hiddenFateRevealed = nil
        RoguemonStreamer.settings.persistent.hiddenFatePartyIndex = nil
        RoguemonStreamer.settings.persistent.hiddenFateRealMoves = nil
        RoguemonStreamer.settings.persistent.queuedHiddenFateCount = nil
        RoguemonStreamer.saveSettings()
    else
        -- Fallback default settings
        RoguemonStreamer.settings = {
            enabled = true,
            debug = false,
            enableAnimations = false,
            enableTwitchSub = true,
            enableChannelPoints = true,
            cumulativeGoal = 10,
            currentProgress = 0,
            goodChance = 50,
            milestones = { ["5"] = true, ["10"] = true, ["20"] = true, ["50"] = true },
            stats = { totalSubs = 0, totalEvents = 0 },
            persistent = {
                hpCapBoost = 0,
                statusCapBoost = 0,
                lastAppliedHpBoost = 0,
                lastAppliedStatusBoost = 0,
                statBuffs = {},
                outOfControlTurns = 0,
                queuedOutOfControlTurns = 0,
                queuedTempTypes = {},
                queuedDisableTurns = {},
                queuedDamageAndStatus = {},
                queuedStatuses = {},
                queuedOverwhelmedCount = 0,
                pendingRemovals = {
                    healing = 0,
                    utility_status = 0,
                    big_healing = 0,
                    utility_valuable = 0,
                }
            }
        }
    end
end

function RoguemonStreamer.prettyPrintJson(jsonStr)
    local indent = 0
    local result = {}
    local inString = false
    local escaped = false
    
    for i = 1, #jsonStr do
        local c = jsonStr:sub(i, i)
        
        if inString then
            table.insert(result, c)
            if escaped then
                escaped = false
            elseif c == "\\" then
                escaped = true
            elseif c == "\"" then
                inString = false
            end
        else
            if c == "\"" then
                inString = true
                table.insert(result, c)
            elseif c == "{" or c == "[" then
                indent = indent + 1
                table.insert(result, c)
                table.insert(result, "\n" .. string.rep("  ", indent))
            elseif c == "}" or c == "]" then
                indent = indent - 1
                table.insert(result, "\n" .. string.rep("  ", indent) .. c)
            elseif c == "," then
                table.insert(result, c)
                table.insert(result, "\n" .. string.rep("  ", indent))
            elseif c == ":" then
                table.insert(result, c)
                table.insert(result, " ")
            else
                table.insert(result, c)
            end
        end
    end
    
    local formatted = table.concat(result)
    formatted = formatted:gsub("%{\n%s*%}", "{}")
    formatted = formatted:gsub("%[\n%s*%]", "[]")
    return formatted
end

function RoguemonStreamer.saveSettings()
    if not RoguemonStreamer.settings then return end
    
    local output = "[]"
    if FileManager.JsonLibrary then
        pcall(function()
            output = FileManager.JsonLibrary.encode(RoguemonStreamer.settings) or "[]"
        end)
    end
    
    local formatted = RoguemonStreamer.prettyPrintJson(output)
    
    local file = io.open(RoguemonStreamer.settingsPath, "w")
    if file then
        file:write(formatted)
        file:close()
    end
end

-- SAFETY CHECKER
local function isGamePlaySafe(request)
    if not Program.isValidMapLocation() then
        return false
    end
    if not GameSettings or not GameSettings.pstats or Memory.readdword(GameSettings.pstats) == 0 then
        return false
    end
    if not Tracker or not Tracker.getPokemon or not Tracker.getPokemon(1) then
        return false
    end

    local isInstantEvent = false
    local isStatEvent = false
    local isChangeOrTypeEvent = false
    if request then
        local eventNameInput = request.Args and request.Args.EventName or request.SanitizedInput or (request.Args and request.Args.Input) or tostring(request.Choice or (request.Args and request.Args.Choice) or "") or ""
        local cleanedName = tostring(eventNameInput):lower():gsub("^%s*(.-)%s*$", "%1")
        if cleanedName:find("restore hp", 1, true) or cleanedName:find("restore pp", 1, true) or cleanedName:find("cure status", 1, true) then
            isInstantEvent = true
        end
        if cleanedName:find("stat boost", 1, true) or cleanedName:find("power boost", 1, true) or 
           cleanedName:find("speed boost", 1, true) or cleanedName:find("powerhouse boost", 1, true) or 
           cleanedName:find("omniboost", 1, true) or cleanedName:find("stat reduce", 1, true) or 
           cleanedName:find("power reduce", 1, true) or cleanedName:find("speed reduce", 1, true) or 
           cleanedName:find("weakness", 1, true) or cleanedName:find("omnimalus", 1, true) then
            isStatEvent = true
        end
        if cleanedName:find("type change", 1, true) or cleanedName:find("ability change", 1, true) or 
           cleanedName:find("nature change", 1, true) then
            isChangeOrTypeEvent = true
        end
    end

    if Battle.inActiveBattle() then
        -- Stat events, instant events, and type/ability/nature events can bypass HandleTurnActionSelectionState check and apply mid-fight
        local bypassPhaseCheck = (isInstantEvent or isStatEvent or isChangeOrTypeEvent)

        if not bypassPhaseCheck then
            -- We must ALWAYS ensure we are in the turn action selection phase ("What will X do?" menu)
            -- to prevent memory writes from interfering with active turn calculations.
            local mainFunc = Memory.readdword(GameSettings.gBattleMainFunc)
            if mainFunc ~= GameSettings.HandleTurnActionSelectionState then
                return false
            end
        end
    end
    return true
end

-- ACTIVE PARTY INDEX HELPER
function RoguemonStreamer.getBattleSlot(partyIndex)
    if not partyIndex then return nil end
    if not Battle.inActiveBattle() then
        return nil
    end

    -- Try to read directly from GBA RAM for precise, real-time mapping
    if GameSettings.gBattlerPartyIndexes and GameSettings.gBattlerPartyIndexes ~= 0 then
        local leftOwn = Memory.readbyte(GameSettings.gBattlerPartyIndexes) + 1
        if partyIndex == leftOwn then
            return 0
        end
        if Battle.numBattlers == 4 then
            local rightOwn = Memory.readbyte(GameSettings.gBattlerPartyIndexes + 4) + 1
            if partyIndex == rightOwn then
                return 2
            end
        end
    end

    -- Fallback to the Combatants table
    if partyIndex == (Battle.Combatants.LeftOwn or 1) then
        return 0
    elseif Battle.numBattlers == 4 and partyIndex == (Battle.Combatants.RightOwn or 2) then
        return 2
    end

    return nil
end

getActivePartyIndex = function()
    if Battle.inActiveBattle() then
        local slot = Battle.Combatants.LeftOwn or 1
        if Battle.isViewingOwn and not Battle.isViewingLeft and Battle.numBattlers == 4 then
            slot = Battle.Combatants.RightOwn or slot
        end
        return slot
    else
        return 1
    end
end

-- BATTLE MONS ADDRESS HELPER
getBattleMonsAddress = function(partyIndex)
    if not GameSettings.gBattleMons then
        return nil
    end
    local battleSlot = RoguemonStreamer.getBattleSlot(partyIndex)
    if battleSlot ~= nil then
        return GameSettings.gBattleMons + (battleSlot * (GameSettings.sizeofBattlePokemon or 0x58))
    end
    return nil
end

function RoguemonStreamer.getBattleAbilityOffset()
    if GameSettings.battleMonAbilityOffset and GameSettings.battleMonAbilityOffset > 0 then
        return GameSettings.battleMonAbilityOffset
    end
    if GameSettings.battleAbilitiesOffset and GameSettings.battleAbilitiesOffset > 0 then
        return GameSettings.battleAbilitiesOffset
    end
    return 0x20
end

local function hasPendingMilestoneChoices()
    if not RequestHandler or not RequestHandler.Requests then
        return false
    end
    for _, req in pairs(RequestHandler.Requests) do
        local argsTable = req.Args or {}
        local subCount = tonumber(argsTable.SubCount) or 1
        local isGift = argsTable.IsGift == true or argsTable.IsGift == "true"
        
        -- Check if this request is a milestone (either already split, or can be split)
        local isMilestone = false
        if req.HitMilestone ~= nil then
            isMilestone = (req.HitMilestone ~= false)
        elseif isGift then
            local milestonesOrder = { 50, 20, 10, 5 }
            for _, m in ipairs(milestonesOrder) do
                local key = tostring(m)
                if subCount >= m and RoguemonStreamer.settings.milestones[key] == true then
                    isMilestone = true
                    break
                end
            end
        end
        
        local reqChoice = req.Choice or (req.Args and req.Args.Choice)
        if isMilestone and not reqChoice then
            return true
        end
    end
    return false
end

-- CHANNEL POINTS CONFIG & MAPPING
local cp_event_mapping = {
    -- Positive Events
    ["restore hp"] = { fn = "executePositiveEvent", name = "Restore HP", scale = 1 },
    ["restore pp"] = { fn = "executePositiveEvent", name = "Restore PP", scale = 1 },
    ["cure status"] = { fn = "executePositiveEvent", name = "Cure Status", scale = 1 },
    ["full restore"] = { fn = "executePositiveEvent", name = "Full Restore", scale = 1 },
    ["give healing item"] = { fn = "executePositiveEvent", name = "Give Healing Item", scale = 1 },
    ["give status item"] = { fn = "executePositiveEvent", name = "Give Status Item", scale = 1 },
    ["give pp item"] = { fn = "executePositiveEvent", name = "Give PP Item", scale = 1 },
    ["give utility item"] = { fn = "executePositiveEvent", name = "Give Utility Item", scale = 5 },
    ["give utility items"] = { fn = "executePositiveEvent", name = "Give Utility Items", scale = 10 },
    ["stat boost"] = { fn = "executePositiveEvent", name = "Stat Boost", scale = 1 },
    ["power boost"] = { fn = "executePositiveEvent", name = "Power Boost", scale = 1 },
    ["speed boost"] = { fn = "executePositiveEvent", name = "Speed Boost", scale = 1 },
    ["pp up"] = { fn = "executePositiveEvent", name = "PP Up", scale = 1 },
    ["no guard plus"] = { fn = "executePositiveEvent", name = "No Guard Plus", scale = 1 },
    ["powerhouse boost"] = { fn = "executePositiveEvent", name = "Powerhouse Boost", scale = 2 }, -- results in duration = 1 battle
    ["turbo genetics"] = { fn = "executePositiveEvent", name = "Turbo Genetics", scale = 10 },
    ["darwinism"] = { fn = "executePositiveEvent", name = "Darwinism", scale = 10 },
    ["omniboost"] = { fn = "executePositiveEvent", name = "Omniboost", scale = 10 },
    ["evolution power"] = { fn = "executePositiveEvent", name = "Evolution Power", scale = 10 },
    ["increase healing limit"] = { fn = "executePositiveEvent", name = "Increase Healing Limit", scale = 1 },
    ["increase status limit"] = { fn = "executePositiveEvent", name = "Increase Status Limit", scale = 1 },
    ["game changer"] = { fn = "executePositiveEvent", name = "Game Changer", scale = 1 }, -- 1 battle
    ["try harder"] = { fn = "executePositiveEvent", name = "Try Harder", scale = 1 }, -- 1 battle
    ["let's dance"] = { fn = "executePositiveEvent", name = "Let's Dance", scale = 1 },

    -- Negative Events
    ["inflict status"] = { fn = "executeNegativeEvent", name = "Inflict Status", scale = 1 },
    ["disable move"] = { fn = "executeNegativeEvent", name = "Disable Move", scale = 3 }, -- 3 turns
    ["empowered disable"] = { fn = "executeNegativeEvent", name = "Disable Move", scale = 10 },
    ["power debuff"] = { fn = "executeNegativeEvent", name = "Power Debuff", scale = 1 },
    ["speed debuff"] = { fn = "executeNegativeEvent", name = "Speed Debuff", scale = 1 },
    ["pp cut"] = { fn = "executeNegativeEvent", name = "PP Cut", scale = 1 },
    ["temp type change"] = { fn = "executeNegativeEvent", name = "Temp Type Change", scale = 1 },
    ["remove healing item"] = { fn = "executeNegativeEvent", name = "Remove Healing Item", scale = 1 },
    ["remove status item"] = { fn = "executeNegativeEvent", name = "Remove Status Item", scale = 1 },
    ["remove big healing item"] = { fn = "executeNegativeEvent", name = "Remove Big Healing Item", scale = 5 },
    ["remove utility item"] = { fn = "executeNegativeEvent", name = "Remove Utility Item", scale = 5 },
    ["remove utility items"] = { fn = "executeNegativeEvent", name = "Remove Utility Items", scale = 10 },
    ["stat debuff"] = { fn = "executeNegativeEvent", name = "Stat Debuff", scale = 1 },
    ["empowered debuff"] = { fn = "executeNegativeEvent", name = "Stat Debuff", scale = 10 },
    ["pp deplete"] = { fn = "executeNegativeEvent", name = "PP Deplete", scale = 1 },
    ["mystification"] = { fn = "executeNegativeEvent", name = "Mystification", scale = 1 },
    ["trick room"] = { fn = "executeNegativeEvent", name = "Mystification", scale = 1 },
    ["omnimalus"] = { fn = "executeNegativeEvent", name = "Omnimalus", scale = 5 },
    ["no guard minus"] = { fn = "executeNegativeEvent", name = "No Guard Minus", scale = 1 },
    ["out of control"] = { fn = "executeNegativeEvent", name = "Out of Control", scale = 2 }, -- 1 battle
    ["overwhelmed"] = { fn = "executeNegativeEvent", name = "Overwhelmed", scale = 5 },

    -- Completely Random Type/Nature/Ability Changes (CP unique names)
    ["type change"] = { fn = "executeRandomChange", name = "Type Change", scale = 1 },
    ["nature change"] = { fn = "executeRandomChange", name = "Nature Change", scale = 1 },
    ["ability change"] = { fn = "executeRandomChange", name = "Ability Change", scale = 1 },
}

-- COMPLETELY RANDOM CHANGES EXECUTOR (FOR CHANNEL POINTS)
function RoguemonStreamer.executeRandomChange(changeType, scale)
    RoguemonStreamer.updateItemIds()
    local activeIdx = 1
    local partyAddress = GameSettings.pstats + (activeIdx - 1) * 100
    local battleSlot = RoguemonStreamer.getBattleSlot(activeIdx)
    local battleMonsAddress = nil
    if battleSlot ~= nil then
        battleMonsAddress = GameSettings.gBattleMons + (battleSlot * (GameSettings.sizeofBattlePokemon or 0x58))
    end
    
    local detail = nil
    if changeType == "Type Change" then
        local leadMon = Battle.getViewedPokemon(true)
        if leadMon and leadMon.personality then
            local personalityHex = string.format("0x%X", leadMon.personality)
            RoguemonStreamer.settings.alteredTypes = RoguemonStreamer.settings.alteredTypes or {}
            
            local validTypes = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 17, 18, 19 }
            local t1 = validTypes[RoguemonStreamer.random(#validTypes)]
            local t2 = validTypes[RoguemonStreamer.random(#validTypes)]
            
            RoguemonStreamer.settings.alteredTypes[personalityHex] = { t1, t2 }
            RoguemonStreamer.saveSettings()
            
            if battleSlot ~= nil then
                RoguemonStreamer.writeAlteredTypesToBattle(battleSlot, t1, t2)
            end
            
            local t1Name = PokemonData.TypeIndexMap[t1] or "Unknown"
            local t2Name = PokemonData.TypeIndexMap[t2] or "Unknown"
            local typingStr = (t1Name == t2Name) and t1Name or (t1Name .. "/" .. t2Name)
            print(string.format("[RogueMon Streamer] - Completely randomly changed viewed Pokemon types to %s", typingStr))
            detail = string.format("Type Change ( %s )", trim(typingStr))
        else
            print("[RogueMon Streamer] - Type Change failed: No viewed Pokemon found")
            detail = "Type Change ( Failed )"
        end
    elseif changeType == "Nature Change" then
        local targetNature = RoguemonStreamer.random(0, 24)
        RoguemonStreamer.changePokemonPersonality(activeIdx, targetNature, nil)
        local natureNames = {
            [0] = "Hardy", [1] = "Lonely", [2] = "Brave", [3] = "Adamant", [4] = "Naughty",
            [5] = "Bold", [6] = "Docile", [7] = "Relaxed", [8] = "Impish", [9] = "Lax",
            [10] = "Timid", [11] = "Hasty", [12] = "Serious", [13] = "Jolly", [14] = "Naive",
            [15] = "Modest", [16] = "Mild", [17] = "Quiet", [18] = "Bashful", [19] = "Rash",
            [20] = "Calm", [21] = "Gentle", [22] = "Sassy", [23] = "Careful", [24] = "Quirky"
        }
        local natureName = natureNames[targetNature] or "Unknown"
        print(string.format("[RogueMon Streamer] - Completely randomly changed Pokemon nature to %s", natureName))
        detail = string.format("Nature Change ( %s )", trim(natureName))
    elseif changeType == "Ability Change" then
        local leadMon = Battle.getViewedPokemon(true)
        if leadMon and leadMon.personality then
            local personalityHex = string.format("0x%X", leadMon.personality)
            RoguemonStreamer.settings.alteredAbilities = RoguemonStreamer.settings.alteredAbilities or {}
            
            local maxAbilityId = #AbilityData.Abilities
            local newAbilityId = RoguemonStreamer.random(1, maxAbilityId)
            while not AbilityData.Abilities[newAbilityId] or AbilityData.Abilities[newAbilityId].name == "???" or AbilityData.Abilities[newAbilityId].name == "None" or AbilityData.Abilities[newAbilityId].name == "" do
                newAbilityId = RoguemonStreamer.random(1, maxAbilityId)
            end
            
            RoguemonStreamer.settings.alteredAbilities[personalityHex] = newAbilityId
            RoguemonStreamer.saveSettings()
            
            if battleMonsAddress ~= nil then
                local abilityOffset = RoguemonStreamer.getBattleAbilityOffset()
                Memory.writeword(battleMonsAddress + abilityOffset, newAbilityId)
            end
            
            local abilityName = (AbilityData.Abilities[newAbilityId] or {}).name or "Unknown"
            print(string.format("[RogueMon Streamer] - Completely randomly changed Pokemon ability to %s", abilityName))
            detail = string.format("Ability Change ( %s )", trim(abilityName))
        else
            print("[RogueMon Streamer] - Ability Change failed: No viewed Pokemon found")
            detail = "Ability Change ( Failed )"
        end
    end
    
    refreshTracker()
    local finalMsg = "Random Change: " .. (detail or changeType)
    RoguemonStreamer.notifyStreamer(finalMsg, scale)
    return finalMsg
end

-- EXECUTES A SINGLE CHANNEL POINT REQUEST
function RoguemonStreamer.executeSingleChannelPointsRequest(request)
    local eventNameInput = request.Args and request.Args.EventName or request.SanitizedInput or (request.Args and request.Args.Input) or ""
    local cleanedName = tostring(eventNameInput):lower():gsub("^%s*(.-)%s*$", "%1")
    
    print("[RogueMon Streamer] Processing request GUID: " .. tostring(request.GUID))

    local mapping = cp_event_mapping[cleanedName]
    if not mapping then
        -- Substring fallback matching
        for key, map in pairs(cp_event_mapping) do
            if cleanedName:find(key, 1, true) then
                mapping = map
                break
            end
        end
    end

    if mapping then
        RoguemonStreamer.isChannelPointsExecution = true
        
        local fn = RoguemonStreamer[mapping.fn]
        local success, result = pcall(fn, mapping.name, mapping.scale)
        
        RoguemonStreamer.isChannelPointsExecution = nil
        
        if success then
            RoguemonStreamer.settings.stats.totalEvents = RoguemonStreamer.settings.stats.totalEvents + 1
            RoguemonStreamer.saveSettings()
            request.FulfillmentResult = "Channel Point event executed: " .. mapping.name
        else
            request.FulfillmentResult = "Error executing event: " .. tostring(result)
        end
    else
        request.FulfillmentResult = "Unknown or unmapped Channel Point event: " .. tostring(eventNameInput)
    end
end

-- PROCESSES INCOMING CHANNEL POINT REQUEST
function RoguemonStreamer.processChannelPointsRequest(request)
    RoguemonStreamer.processedRequestGUIDs = RoguemonStreamer.processedRequestGUIDs or {}
    if request.GUID and RoguemonStreamer.processedRequestGUIDs[request.GUID] then
        return true
    end

    if not RoguemonStreamer.settings.enabled then
        request.FulfillmentResult = "Twitch extension is disabled."
        return true
    end
    if not RoguemonStreamer.settings.enableChannelPoints then
        request.FulfillmentResult = "Channel Points mode is disabled."
        return true
    end
    
    -- If there's an active sub choice request, Let's Dance menu, or active notification, keep channel points in queue
    local ScreenManager = Roguemon and Roguemon.ScreenManager
    if RoguemonStreamer.ActiveChoiceRequest ~= nil or RoguemonStreamer.ActiveLetsDanceRequest ~= nil or (ScreenManager and ScreenManager.isNotificationActive()) then
        return false
    end

    if not isGamePlaySafe(request) then
        return false
    end

    RoguemonStreamer.executeSingleChannelPointsRequest(request)
    if request.GUID then
        RoguemonStreamer.processedRequestGUIDs[request.GUID] = true
    end
    return true
end

-- EXECUTES ALL PENDING CHANNEL POINTS REQUESTS
function RoguemonStreamer.executePendingChannelPoints()
    if not RequestHandler or not RequestHandler.Requests then
        return
    end

    -- Collect all channel points requests
    local cpRequests = {}
    for guid, req in pairs(RequestHandler.Requests) do
        if req.EventKey == "TwitchChannelPointsEvent" then
            table.insert(cpRequests, req)
        end
    end

    -- Sort by CreatedAt
    table.sort(cpRequests, function(a, b) return (a.CreatedAt or 0) < (b.CreatedAt or 0) end)

    -- Execute and remove them
    for _, req in ipairs(cpRequests) do
        RoguemonStreamer.executeSingleChannelPointsRequest(req)
        RequestHandler.removeRequest(req.GUID)
    end
end

-- REQUEST PROCESSING
function RoguemonStreamer.processRequest(request)
    RoguemonStreamer.processedRequestGUIDs = RoguemonStreamer.processedRequestGUIDs or {}
    if request.GUID and RoguemonStreamer.processedRequestGUIDs[request.GUID] then
        return true
    end

    if not RoguemonStreamer.settings.enabled then
        request.FulfillmentResult = "Twitch extension is disabled."
        return true
    end
    if not RoguemonStreamer.settings.enableTwitchSub then
        request.FulfillmentResult = "Twitch Subscriptions mode is disabled."
        return true
    end

    local argsTable = request.Args or {}
    local subCount = tonumber(argsTable.SubCount) or 1
    local isGift = argsTable.IsGift == true or argsTable.IsGift == "true"
    
    if isGift and request.HitMilestone == nil then
        if subCount >= 40 and subCount <= 49 and RoguemonStreamer.settings.milestones["20"] == true then
            -- Special 40-49 gift split case: 2 Milestone 20s!
            request.OriginalSubCount = subCount
            request.HitMilestone = 20
            request.Args.SubCount = 20
            request.RemainingCumulative = subCount - 40
            request.IsSplitDoubleMilestone = 1 -- State 1: first Milestone 20
        else
            local hit = nil
            local milestonesOrder = { 50, 20, 10, 5 }
            for _, m in ipairs(milestonesOrder) do
                local key = tostring(m)
                if subCount >= m and RoguemonStreamer.settings.milestones[key] == true then
                    hit = m
                    break
                end
            end
            
            if hit then
                request.OriginalSubCount = subCount
                request.HitMilestone = hit
                request.RemainingCumulative = subCount - hit
                request.Args.SubCount = hit
            else
                request.HitMilestone = false
            end
        end
    end

    -- Check if it is a specific milestone gift sub event
    local isMilestoneEvent = (request.HitMilestone ~= nil and request.HitMilestone ~= false)

    if isMilestoneEvent then
        -- Postpone if Let's Dance menu or active notification is currently active
        local ScreenManager = Roguemon and Roguemon.ScreenManager
        if RoguemonStreamer.ActiveLetsDanceRequest ~= nil or (ScreenManager and ScreenManager.isNotificationActive()) then
            return false
        end

        if not isGamePlaySafe(request) then
            return false -- Postpone processing completely until gameplay is safe (e.g. valid Pokémon in party)
        end

        -- Interactive Gifter's Choice Overlay
        local choice = request.Choice or (request.Args and request.Args.Choice)
        if not choice then
            if RoguemonStreamer.ActiveChoiceRequest == nil then
                RoguemonStreamer.ActiveChoiceRequest = request
                StreamerChoiceScreen.show(request)
            end
            return false -- Keep processing, wait for streamer button click
        end

        -- Streamer choice has been registered ("Good" or "Bad")
        -- Wait until choices are selected for all pending concurrent milestone requests
        if hasPendingMilestoneChoices() then
            return false
        end

        if not isGamePlaySafe(request) then
            return false -- Wait for safe game state
        end

        -- Execute the milestone event
        RoguemonStreamer.executeChoice(request, choice)
        if request.IsSplitDoubleMilestone == 2 then
            -- We just completed the first Milestone 20, but the second one is pending.
            -- Keep the request active in the processing loop.
            return false
        end
        if request.GUID then
            RoguemonStreamer.processedRequestGUIDs[request.GUID] = true
        end
        return true
    else
        -- Cumulative event progress
        -- Postpone if any interactive screen or notification is active to avoid notification overlapping
        local ScreenManager = Roguemon and Roguemon.ScreenManager
        if RoguemonStreamer.ActiveLetsDanceRequest ~= nil or RoguemonStreamer.ActiveChoiceRequest ~= nil or (ScreenManager and ScreenManager.isNotificationActive()) then
            return false
        end

        if not isGamePlaySafe(request) then
            return false
        end

        local selectedEvent = request.SelectedEvent or (request.Args and request.Args.SelectedEvent)
        if selectedEvent then
            local choice = request.Choice or (request.Args and request.Args.Choice)
            local isPositive = (choice == "Good")
            if isPositive then
                RoguemonStreamer.executePositiveEvent(selectedEvent, 1)
            else
                RoguemonStreamer.executeNegativeEvent(selectedEvent, 1)
            end
            RoguemonStreamer.settings.stats.totalSubs = RoguemonStreamer.settings.stats.totalSubs + subCount
            RoguemonStreamer.settings.stats.totalEvents = RoguemonStreamer.settings.stats.totalEvents + 1
            RoguemonStreamer.saveSettings()
            if request.GUID then
                RoguemonStreamer.processedRequestGUIDs[request.GUID] = true
            end
            request.FulfillmentResult = "Simulated cumulative sub: " .. selectedEvent
            return true
        end

        RoguemonStreamer.settings.currentProgress = RoguemonStreamer.settings.currentProgress + subCount
        RoguemonStreamer.settings.stats.totalSubs = RoguemonStreamer.settings.stats.totalSubs + subCount
        RoguemonStreamer.saveSettings()

        request.FulfillmentResult = string.format("Added %d subs to progress. Progress: %d/%d", subCount, RoguemonStreamer.settings.currentProgress, RoguemonStreamer.settings.cumulativeGoal)
        if request.GUID then
            RoguemonStreamer.processedRequestGUIDs[request.GUID] = true
        end
        return true
    end
end

-- HELPER FUNCTIONS FOR EVENTS SELECTION
function RoguemonStreamer.pickRandomEvent(eventList)
    local idx = RoguemonStreamer.random(#eventList)
    return eventList[idx]
end

function RoguemonStreamer.notifyStreamer(message, subCountOrImage)
    if Roguemon and Roguemon.ScreenManager and Roguemon.ScreenManager.displayNotification then
        local imageName = "sub.png"
        if RoguemonStreamer.isChannelPointsExecution then
            imageName = "coin.png"
        elseif type(subCountOrImage) == "number" then
            if subCountOrImage >= 50 then
                imageName = "sub50.png"
            elseif subCountOrImage >= 20 then
                imageName = "sub20.png"
            elseif subCountOrImage >= 10 then
                imageName = "sub10.png"
            elseif subCountOrImage >= 5 then
                imageName = "sub5.png"
            end
        elseif type(subCountOrImage) == "string" and subCountOrImage ~= "" then
            imageName = subCountOrImage
        end
        local subImage = ".." .. FileManager.slash .. ".." .. FileManager.slash .. "roguemon-streamer-extension" .. FileManager.slash .. "streamer_images" .. FileManager.slash .. imageName
        
        local function customOnClose()
            RoguemonStreamer.temporaryNotifColors = nil
        end

        Roguemon.ScreenManager.displayNotification(message, subImage, nil, customOnClose)
    else
        print("[RogueMon Streamer] " .. message)
        RoguemonStreamer.temporaryNotifColors = nil
    end
end

-- IN-GAME EFFECTS (RAM WRITING AND LOGIC)

-- HP and Status Heals
function RoguemonStreamer.healHP(partyIndex)
    local partyAddress = GameSettings.pstats + (partyIndex - 1) * 100
    local maxHPOffset = GameSettings.offsetPokemonStatsMaxHpAtk or 0x58
    local maxHP = Memory.readword(partyAddress + maxHPOffset)
    local curHPOffset = GameSettings.pokemonCurHPOffset or 0x56
    Memory.writeword(partyAddress + curHPOffset, maxHP) -- current HP

    if Battle.inActiveBattle() then
        local battleSlot = RoguemonStreamer.getBattleSlot(partyIndex)
        if battleSlot ~= nil then
            local battleMonsAddress = GameSettings.gBattleMons + (battleSlot * (GameSettings.sizeofBattlePokemon or 0x58))
            local hpOffset = GameSettings.pokemonBattleHpOffset or 0x28
            Memory.writeword(battleMonsAddress + hpOffset, maxHP)
        end
    end
end

function RoguemonStreamer.cureStatus(partyIndex)
    local partyAddress = GameSettings.pstats + (partyIndex - 1) * 100
    Memory.writedword(partyAddress + 0x50, 0) -- status in party

    if Battle.inActiveBattle() then
        local battleSlot = RoguemonStreamer.getBattleSlot(partyIndex)
        if battleSlot ~= nil then
            local battleMonsAddress = GameSettings.gBattleMons + (battleSlot * (GameSettings.sizeofBattlePokemon or 0x58))
            local volOffset = GameSettings.battleVolatilesOffset or 0x50
            Memory.writedword(battleMonsAddress + getBattleStatus1Offset(), 0) -- non-volatile status in battle
            Memory.writedword(battleMonsAddress + volOffset, 0) -- volatile status in battle
        end
    end
end

-- PP Restores
function RoguemonStreamer.restorePP(partyIndex, slot)
    local partyAddress = GameSettings.pstats + (partyIndex - 1) * 100
    local personality = Memory.readdword(partyAddress)
    local otid = Memory.readdword(partyAddress + 4)
    local magicword = Utils.bit_xor(personality, otid)

    local aux = personality % 24 + 1
    local attackoffset = (MiscData.TableData.attack[aux] - 1) * 12
    local growthoffset = (MiscData.TableData.growth[aux] - 1) * 12

    -- Read decrypted attack blocks
    local attack1 = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + attackoffset), magicword)
    local attack2 = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + attackoffset + 4), magicword)
    local attack3 = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + attackoffset + 8), magicword)
    local growth3 = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + growthoffset + 8), magicword)

    local partyMoves = {
        Utils.getbits(attack1, 0, 16),
        Utils.getbits(attack1, 16, 16),
        Utils.getbits(attack2, 0, 16),
        Utils.getbits(attack2, 16, 16),
    }

    local partyPPs = {
        Utils.getbits(attack3, 0, 8),
        Utils.getbits(attack3, 8, 8),
        Utils.getbits(attack3, 16, 8),
        Utils.getbits(attack3, 24, 8),
    }

    local ppBonuses = Utils.getbits(growth3, 0, 8)

    local inBattle = Battle.inActiveBattle()
    local battleSlot = RoguemonStreamer.getBattleSlot(partyIndex)
    local battleMonsAddress = nil
    if inBattle and battleSlot ~= nil then
        battleMonsAddress = GameSettings.gBattleMons + (battleSlot * (GameSettings.sizeofBattlePokemon or 0x58))
    end

    -- Determine moves and PPs for current battle state vs overworld
    local moves = {}
    local pps = {}
    if inBattle and battleMonsAddress ~= nil then
        local ppOffset = getBattlePpOffset()
        for i = 1, 4 do
            moves[i] = Memory.readword(battleMonsAddress + 0x0C + (i - 1) * 2) or 0
            pps[i] = Memory.readbyte(battleMonsAddress + ppOffset + (i - 1)) or 0
        end
    else
        for i = 1, 4 do
            moves[i] = partyMoves[i]
            pps[i] = partyPPs[i]
        end
    end

    -- Restore active PP (either in battle or party)
    local function restoreSlot(s)
        local moveId = moves[s]
        if moveId and moveId > 0 and MoveData.Moves[moveId] then
            local basePP = tonumber(MoveData.Moves[moveId].pp) or 20
            local ppBonusVal = Utils.getbits(ppBonuses, (s - 1) * 2, 2)
            local maxPP = basePP + math.floor(basePP * 0.2) * ppBonusVal
            pps[s] = maxPP
        end
    end

    if slot then
        restoreSlot(slot)
    else
        for i = 1, 4 do restoreSlot(i) end
    end

    -- Write active PP back to battle structure if in battle
    if inBattle and battleMonsAddress ~= nil then
        local ppOffset = getBattlePpOffset()
        for i = 1, 4 do
            Memory.writebyte(battleMonsAddress + ppOffset + (i - 1), pps[i])
        end
    end

    local function restorePartySlot(s)
        local moveId = partyMoves[s]
        if moveId and moveId > 0 and MoveData.Moves[moveId] then
            local basePP = tonumber(MoveData.Moves[moveId].pp) or 20
            local ppBonusVal = Utils.getbits(ppBonuses, (s - 1) * 2, 2)
            local maxPP = basePP + math.floor(basePP * 0.2) * ppBonusVal
            partyPPs[s] = maxPP
        end
    end

    if slot then
        restorePartySlot(slot)
    else
        for i = 1, 4 do restorePartySlot(i) end
    end

    -- Encrypt and write back party PP
    local attack3_dec = partyPPs[1] + Utils.bit_lshift(partyPPs[2], 8) + Utils.bit_lshift(partyPPs[3], 16) + Utils.bit_lshift(partyPPs[4], 24)
    Memory.writedword(partyAddress + 0x20 + attackoffset + 8, Utils.bit_xor(attack3_dec, magicword))

    -- Re-checksum
    local cs = 0
    for offset = 0, 44, 4 do
        local dword = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + offset), magicword)
        cs = cs + Utils.addhalves(dword)
    end
    cs = cs % 65536
    Memory.writeword(partyAddress + 28, cs)
end

function RoguemonStreamer.applyPPUp(partyIndex)
    if not GameSettings.pstats or Memory.readdword(GameSettings.pstats) == 0 then
        return nil
    end
    local partyAddress = GameSettings.pstats + (partyIndex - 1) * 100
    local personality = Memory.readdword(partyAddress)
    local otid = Memory.readdword(partyAddress + 4)
    local magicword = Utils.bit_xor(personality, otid)

    local aux = personality % 24 + 1
    local attackoffset = (MiscData.TableData.attack[aux] - 1) * 12
    local growthoffset = (MiscData.TableData.growth[aux] - 1) * 12

    -- Read decrypted attack blocks and growth block
    local attack1 = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + attackoffset), magicword)
    local attack2 = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + attackoffset + 4), magicword)
    local attack3 = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + attackoffset + 8), magicword)
    local growth3 = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + growthoffset + 8), magicword)

    local partyMoves = {
        Utils.getbits(attack1, 0, 16),
        Utils.getbits(attack1, 16, 16),
        Utils.getbits(attack2, 0, 16),
        Utils.getbits(attack2, 16, 16),
    }

    local ppBonuses = Utils.getbits(growth3, 0, 8)

    -- Filter eligible moves (move ID > 0 and PP Up stage < 3)
    local eligible = {}
    for i = 1, 4 do
        local mId = partyMoves[i]
        if mId and mId > 0 and MoveData.Moves[mId] and MoveData.Moves[mId].name ~= "???" then
            local bonus = (ppBonuses >> ((i - 1) * 2)) & 3
            if bonus < 3 then
                table.insert(eligible, i)
            end
        end
    end

    if #eligible == 0 then
        return nil
    end

    local slot = eligible[RoguemonStreamer.random(1, #eligible)]
    local bonus = (ppBonuses >> ((slot - 1) * 2)) & 3
    local newBonus = bonus + 1
    local mask = 3 << ((slot - 1) * 2)
    ppBonuses = (ppBonuses & ~mask) | (newBonus << ((slot - 1) * 2))

    -- Write back growth3 (PP Up bonuses)
    growth3 = (growth3 & 0xFFFFFF00) | ppBonuses
    Memory.writedword(partyAddress + 0x20 + growthoffset + 8, Utils.bit_xor(growth3, magicword))

    -- Calculate PP increase (+20% of base PP)
    local moveId = partyMoves[slot]
    local basePP = tonumber(MoveData.Moves[moveId].pp) or 20
    local increase = math.floor(basePP * 0.2)

    -- Read, update, and write back current party PP
    local partyPPs = {
        Utils.getbits(attack3, 0, 8),
        Utils.getbits(attack3, 8, 8),
        Utils.getbits(attack3, 16, 8),
        Utils.getbits(attack3, 24, 8),
    }
    local currentPartyPP = partyPPs[slot]
    local newPartyPP = math.min(255, currentPartyPP + increase)
    partyPPs[slot] = newPartyPP

    local attack3_dec = partyPPs[1] + Utils.bit_lshift(partyPPs[2], 8) + Utils.bit_lshift(partyPPs[3], 16) + Utils.bit_lshift(partyPPs[4], 24)
    Memory.writedword(partyAddress + 0x20 + attackoffset + 8, Utils.bit_xor(attack3_dec, magicword))

    -- Write back current battle PP if in battle
    local inBattle = Battle.inActiveBattle()
    local battleSlot = RoguemonStreamer.getBattleSlot(partyIndex)
    local battleMonsAddress = nil
    if inBattle and battleSlot ~= nil then
        battleMonsAddress = GameSettings.gBattleMons + (battleSlot * (GameSettings.sizeofBattlePokemon or 0x58))
    end
    if battleMonsAddress then
        local ppOffset = getBattlePpOffset()
        local currentBattlePP = Memory.readbyte(battleMonsAddress + ppOffset + (slot - 1)) or 0
        local newBattlePP = math.min(255, currentBattlePP + increase)
        Memory.writebyte(battleMonsAddress + ppOffset + (slot - 1), newBattlePP)
    end

    -- Re-checksum
    local cs = 0
    for offset = 0, 44, 4 do
        local dword = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + offset), magicword)
        cs = cs + Utils.addhalves(dword)
    end
    cs = cs % 65536
    Memory.writeword(partyAddress + 28, cs)

    local moveName = MoveData.Moves[partyMoves[slot]].name
    return moveName
end

function RoguemonStreamer.writePPToParty(partyIndex, pps)
    local partyAddress = GameSettings.pstats + (partyIndex - 1) * 100
    local personality = Memory.readdword(partyAddress)
    local otid = Memory.readdword(partyAddress + 4)
    local magicword = Utils.bit_xor(personality, otid)

    local aux = personality % 24 + 1
    local attackoffset = (MiscData.TableData.attack[aux] - 1) * 12

    -- Encrypt back
    local attack3_dec = (pps[1] or 0) + Utils.bit_lshift(pps[2] or 0, 8) + Utils.bit_lshift(pps[3] or 0, 16) + Utils.bit_lshift(pps[4] or 0, 24)
    Memory.writedword(partyAddress + 0x20 + attackoffset + 8, Utils.bit_xor(attack3_dec, magicword))

    Memory.writeword(partyAddress + 28, cs)
end

function RoguemonStreamer.deductPartyPP(partyIndex, slot, extra)
    if not GameSettings.pstats or Memory.readdword(GameSettings.pstats) == 0 then
        return
    end
    local partyAddress = GameSettings.pstats + (partyIndex - 1) * 100
    local personality = Memory.readdword(partyAddress)
    local otid = Memory.readdword(partyAddress + 4)
    local magicword = Utils.bit_xor(personality, otid)

    local aux = personality % 24 + 1
    local attackoffset = (MiscData.TableData.attack[aux] - 1) * 12

    -- Read decrypted attack block 3
    local attack3 = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + attackoffset + 8), magicword)
    local partyPPs = {
        Utils.getbits(attack3, 0, 8),
        Utils.getbits(attack3, 8, 8),
        Utils.getbits(attack3, 16, 8),
        Utils.getbits(attack3, 24, 8),
    }

    partyPPs[slot] = math.max(0, (partyPPs[slot] or 0) - extra)
    
    -- Encrypt back
    local attack3_dec = (partyPPs[1] or 0) + Utils.bit_lshift(partyPPs[2] or 0, 8) + Utils.bit_lshift(partyPPs[3] or 0, 16) + Utils.bit_lshift(partyPPs[4] or 0, 24)
    Memory.writedword(partyAddress + 0x20 + attackoffset + 8, Utils.bit_xor(attack3_dec, magicword))

    -- Re-checksum
    local cs = 0
    for offset = 0, 44, 4 do
        local dword = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + offset), magicword)
        cs = cs + Utils.addhalves(dword)
    end
    cs = cs % 65536
    Memory.writeword(partyAddress + 28, cs)
end

function RoguemonStreamer.writeMovesAndPPToParty(partyIndex, moves, pps)
    local partyAddress = GameSettings.pstats + (partyIndex - 1) * 100
    local personality = Memory.readdword(partyAddress)
    local otid = Memory.readdword(partyAddress + 4)
    local magicword = Utils.bit_xor(personality, otid)

    local aux = personality % 24 + 1
    local attackoffset = (MiscData.TableData.attack[aux] - 1) * 12

    -- Encrypt and write moves and PPs
    local attack1_dec = (moves[1] or 0) + Utils.bit_lshift(moves[2] or 0, 16)
    local attack2_dec = (moves[3] or 0) + Utils.bit_lshift(moves[4] or 0, 16)
    local attack3_dec = (pps[1] or 0) + Utils.bit_lshift(pps[2] or 0, 8) + Utils.bit_lshift(pps[3] or 0, 16) + Utils.bit_lshift(pps[4] or 0, 24)

    Memory.writedword(partyAddress + 0x20 + attackoffset, Utils.bit_xor(attack1_dec, magicword))
    Memory.writedword(partyAddress + 0x20 + attackoffset + 4, Utils.bit_xor(attack2_dec, magicword))
    Memory.writedword(partyAddress + 0x20 + attackoffset + 8, Utils.bit_xor(attack3_dec, magicword))

    -- Re-checksum
    local cs = 0
    for offset = 0, 44, 4 do
        local dword = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + offset), magicword)
        cs = cs + Utils.addhalves(dword)
    end
    cs = cs % 65536
    Memory.writeword(partyAddress + 28, cs)
end

-- Items BAG Operations
RoguemonStreamer.itemNotification = nil
function RoguemonStreamer.triggerItemNotification(itemId, isAdded, quantity)
    local itemName = (Resources and Resources.Game and Resources.Game.ItemNames and Resources.Game.ItemNames[itemId]) or string.format("Item%d", itemId)
    local prefix = isAdded and "Gained" or "Lost"
    local diffSign = isAdded and "+" or "-"
    RoguemonStreamer.itemNotification = {
        text = string.format("%s: %s (%s%d)", prefix, itemName, diffSign, quantity or 1),
        time = os.time()
    }
end

function RoguemonStreamer.addItemToBag(itemId, quantity)
    local pocketId = RoguemonStreamer.getItemPocket(itemId) or POCKETS.ITEMS
    local cfg = POCKET_CONFIG[pocketId]
    if not cfg then
        print(string.format("[RogueMon Streamer] addItemToBag: No configuration found for pocket of item %d", itemId))
        return false
    end
    
    local offset = GameSettings[cfg.offset]
    local count = resolveCount(cfg)
    local saveAddr = Utils.getSaveBlock1Addr()
    if not offset or count <= 0 or not saveAddr or saveAddr == 0 then
        print(string.format("[RogueMon Streamer] addItemToBag: Save block address or offset is invalid. (saveAddr: %s)", tostring(saveAddr)))
        return false
    end

    local key = Utils.getEncryptionKey(2)

    -- Find existing stack
    local firstEmptySlotAddr = nil
    for i = 0, count - 1 do
        local slotAddr = saveAddr + offset + (i * 4)
        local slotItemId = Memory.readword(slotAddr)
        if slotItemId == itemId then
            local currentQtyEncrypted = Memory.readword(slotAddr + 2)
            local currentQty = currentQtyEncrypted
            if key then
                currentQty = Utils.bit_xor(currentQty, key)
            end
            local newQty = math.min(99, currentQty + quantity)
            local newQtyEncrypted = newQty
            if key then
                newQtyEncrypted = Utils.bit_xor(newQtyEncrypted, key)
            end
            Memory.writeword(slotAddr + 2, newQtyEncrypted)
            RoguemonStreamer.triggerItemNotification(itemId, true, quantity)
            print(string.format("[RogueMon Streamer] addItemToBag: Updated existing item %d quantity from %d to %d (RAM raw: %d -> %d)", itemId, currentQty, newQty, currentQtyEncrypted, newQtyEncrypted))
            refreshTracker()
            if Roguemon and Roguemon.ReminderManager and Roguemon.ReminderManager.checkOverCap then
                Roguemon.ReminderManager.checkOverCap()
            end
            return true
        elseif slotItemId == 0 and not firstEmptySlotAddr then
            firstEmptySlotAddr = slotAddr
        end
    end

    -- Add to empty slot
    if firstEmptySlotAddr then
        Memory.writeword(firstEmptySlotAddr, itemId)
        local quantityEncrypted = quantity
        if key then
            quantityEncrypted = Utils.bit_xor(quantityEncrypted, key)
        end
        Memory.writeword(firstEmptySlotAddr + 2, quantityEncrypted)
        RoguemonStreamer.triggerItemNotification(itemId, true, quantity)
        print(string.format("[RogueMon Streamer] addItemToBag: Added new item %d (quantity %d, RAM raw: %d) to pocket %d", itemId, quantity, quantityEncrypted, pocketId))
        refreshTracker()
        if Roguemon and Roguemon.ReminderManager and Roguemon.ReminderManager.checkOverCap then
            Roguemon.ReminderManager.checkOverCap()
        end
        return true
    end
    print(string.format("[RogueMon Streamer] addItemToBag: Failed to add item %d - pocket %d is full", itemId, pocketId))
    return false
end

function RoguemonStreamer.removeItemFromBag(itemId, quantity)
    local pocketId = RoguemonStreamer.getItemPocket(itemId) or POCKETS.ITEMS
    local cfg = POCKET_CONFIG[pocketId]
    if not cfg then
        print(string.format("[RogueMon Streamer] removeItemFromBag: No configuration found for pocket of item %d", itemId))
        return false
    end

    local offset = GameSettings[cfg.offset]
    local count = resolveCount(cfg)
    local saveAddr = Utils.getSaveBlock1Addr()
    if not offset or count <= 0 or not saveAddr or saveAddr == 0 then
        print(string.format("[RogueMon Streamer] removeItemFromBag: Save block address or offset is invalid. (saveAddr: %s)", tostring(saveAddr)))
        return false
    end

    local key = Utils.getEncryptionKey(2)
    local remaining = quantity or 1
    local totalRemoved = 0
    for i = 0, count - 1 do
        if remaining <= 0 then break end
        local slotAddr = saveAddr + offset + (i * 4)
        local slotItemId = Memory.readword(slotAddr)
        if slotItemId == itemId then
            local slotQtyEncrypted = Memory.readword(slotAddr + 2)
            local slotQty = slotQtyEncrypted
            if key then
                slotQty = Utils.bit_xor(slotQty, key)
            end
            if slotQty > remaining then
                local newQty = slotQty - remaining
                local newQtyEncrypted = newQty
                if key then
                    newQtyEncrypted = Utils.bit_xor(newQtyEncrypted, key)
                end
                Memory.writeword(slotAddr + 2, newQtyEncrypted)
                totalRemoved = totalRemoved + remaining
                remaining = 0
            else
                Memory.writeword(slotAddr, 0)
                Memory.writeword(slotAddr + 2, 0)
                totalRemoved = totalRemoved + slotQty
                remaining = remaining - slotQty
            end
        end
    end
    if totalRemoved > 0 then
        RoguemonStreamer.triggerItemNotification(itemId, false, totalRemoved)
        print(string.format("[RogueMon Streamer] removeItemFromBag: Removed %d of item %d from pocket %d", totalRemoved, itemId, pocketId))
        refreshTracker()
        if Roguemon and Roguemon.ReminderManager and Roguemon.ReminderManager.checkOverCap then
            Roguemon.ReminderManager.checkOverCap()
        end
        return remaining <= 0
    end
    print(string.format("[RogueMon Streamer] removeItemFromBag: Item %d not found in pocket %d", itemId, pocketId))
    return false
end

function RoguemonStreamer.getItemPocket(itemId)
    if not itemId or itemId <= 0 then return nil end
    
    RoguemonStreamer.updateItemIds()
    
    if Roguemon and Roguemon.ItemManager and Roguemon.ItemManager.getItemPocket then
        local pocket = Roguemon.ItemManager.getItemPocket(itemId)
        if pocket then return pocket end
    end
    
    -- Check Gen 3 Berry IDs range (133 to 175)
    if itemId >= 133 and itemId <= 175 then
        return POCKETS.BERRIES
    end
    
    -- Statically route all streamer extension items to the standard ITEMS pocket (pocket 0)
    for _, id in pairs(ITEMS) do
        if id == itemId then
            return POCKETS.ITEMS
        end
    end
    
    if not GameSettings.gItemsInfo or not GameSettings.sizeofItem or not GameSettings.offsetItemPocket then
        return nil
    end
    local base = GameSettings.gItemsInfo + (itemId * GameSettings.sizeofItem)
    local pocketByte = Memory.readbyte(base + GameSettings.offsetItemPocket)
    if not pocketByte then return nil end
    return Utils.getbits(pocketByte, 3, 5)
end

function RoguemonStreamer.removeRandomItemFromCategory(categoryList, suppressErrorPrint)
    local saveAddr = Utils.getSaveBlock1Addr()
    if not saveAddr or saveAddr == 0 then
        print("[RogueMon Streamer] removeRandomItemFromCategory: Invalid save block address.")
        return false
    end

    local key = Utils.getEncryptionKey(2)
    local foundItems = {}
    for _, itemId in ipairs(categoryList) do
        local pocketId = RoguemonStreamer.getItemPocket(itemId) or POCKETS.ITEMS
        local cfg = POCKET_CONFIG[pocketId]
        if cfg then
            local offset = GameSettings[cfg.offset]
            local count = resolveCount(cfg)
            if offset and count > 0 then
                for i = 0, count - 1 do
                    local slotAddr = saveAddr + offset + (i * 4)
                    local slotItemId = Memory.readword(slotAddr)
                    if slotItemId == itemId then
                        local qtyEncrypted = Memory.readword(slotAddr + 2)
                        local qty = qtyEncrypted
                        if key then
                            qty = Utils.bit_xor(qty, key)
                        end
                        if qty > 0 then
                            table.insert(foundItems, { itemId = itemId, slotAddr = slotAddr, qty = qty })
                        end
                    end
                end
            end
        end
    end

    if #foundItems > 0 then
        local target = foundItems[RoguemonStreamer.random(#foundItems)]
        local qty = target.qty
        RoguemonStreamer.triggerItemNotification(target.itemId, false, 1)
        if qty > 1 then
            local newQty = qty - 1
            local newQtyEncrypted = newQty
            if key then
                newQtyEncrypted = Utils.bit_xor(newQtyEncrypted, key)
            end
            Memory.writeword(target.slotAddr + 2, newQtyEncrypted)
            print(string.format("[RogueMon Streamer] removeRandomItemFromCategory: Decreased quantity of item %d from %d to %d", target.itemId, qty, qty - 1))
        else
            Memory.writeword(target.slotAddr, 0)
            Memory.writeword(target.slotAddr + 2, 0)
            print(string.format("[RogueMon Streamer] removeRandomItemFromCategory: Completely removed item %d from slot", target.itemId))
        end
        return target.itemId
    end
    if not suppressErrorPrint then
        print("[RogueMon Streamer] removeRandomItemFromCategory: No items from the specified category were found in the bag.")
    end
    return nil
end

function RoguemonStreamer.removeItemsFromCategoryWithDeficit(categoryName, categoryList, count)
    local removed = 0
    local removedItemIds = {}
    for i = 1, count do
        local id = RoguemonStreamer.removeRandomItemFromCategory(categoryList)
        if id then
            removed = removed + 1
            table.insert(removedItemIds, id)
        else
            break
        end
    end
    local deficit = count - removed
    if deficit > 0 then
        RoguemonStreamer.settings.persistent.pendingRemovals = RoguemonStreamer.settings.persistent.pendingRemovals or {
            healing = 0,
            utility_status = 0,
            big_healing = 0,
            utility_valuable = 0,
        }
        RoguemonStreamer.settings.persistent.pendingRemovals[categoryName] = (RoguemonStreamer.settings.persistent.pendingRemovals[categoryName] or 0) + deficit
        RoguemonStreamer.saveSettings()
        print(string.format("[RogueMon Streamer] - Category '%s': failed to remove %d item(s). Added to persistent debt. Total pending: %d", categoryName, deficit, RoguemonStreamer.settings.persistent.pendingRemovals[categoryName]))
    end
    return deficit, removedItemIds
end


-- HELPER FOR ITEM GRANTING
local function grantItem(itemId, qty)
    print(string.format("[RogueMon Streamer] grantItem: Direct RAM writing Item %d (qty: %d)", itemId, qty))
    RoguemonStreamer.addItemToBag(itemId, qty)
end

function RoguemonStreamer.queueOrActivateMoveEvent(eventName, scale)
    local p = RoguemonStreamer.settings.persistent
    if not p then return "Failed" end

    p.queuedOutOfControlTurns = p.queuedOutOfControlTurns or 0
    p.queuedDisableTurns = p.queuedDisableTurns or {}

    local inBattle = Battle.inActiveBattle()
    local isAnyActive = RoguemonStreamer.isAnyNegativeEventActive()

    if not inBattle or isAnyActive then
        -- Queue it!
        if eventName == "Out of Control" then
            p.queuedOutOfControlTurns = p.queuedOutOfControlTurns + scale
            RoguemonStreamer.saveSettings()
            print(string.format("[RogueMon Streamer] Queued Out of Control event for %d turns.", scale))
            return string.format("Out of Control ( %d turns )", scale)
        elseif eventName == "Disable Move" then
            table.insert(p.queuedDisableTurns, { turns = scale })
            RoguemonStreamer.saveSettings()
            print(string.format("[RogueMon Streamer] Queued %s event for %d turns.", eventName, scale))
            return string.format("%s ( %d turns )", eventName, scale)
        end
    else
        -- Activate immediately!
        if eventName == "Out of Control" then
            p.outOfControlTurns = scale
            RoguemonStreamer.saveSettings()
            print(string.format("[RogueMon Streamer] Activated Out of Control event immediately for %d turns.", scale))
            return string.format("Out of Control ( %d turns )", scale)
        elseif eventName == "Disable Move" then
            -- Pick a random move from the active battler in battle RAM
            local activeIdx = getActivePartyIndex()
            local battleSlot = nil
            if activeIdx == Battle.Combatants.LeftOwn then
                battleSlot = 0
            elseif Battle.numBattlers == 4 and activeIdx == Battle.Combatants.RightOwn then
                battleSlot = 2
            end
            local battleMonsAddress = battleSlot and (GameSettings.gBattleMons + (battleSlot * (GameSettings.sizeofBattlePokemon or 0x58)))
            local moves = {}
            if battleMonsAddress then
                for i = 1, 4 do
                    local m = Memory.readword(battleMonsAddress + 0x0C + (i - 1) * 2)
                    if m and m > 0 then table.insert(moves, m) end
                end
            end
            if #moves == 0 then
                local partyMoves = getPartyMonMoves(activeIdx)
                for _, m in ipairs(partyMoves) do
                    if m and m > 0 then table.insert(moves, m) end
                end
            end
            if #moves > 0 then
                local chosen = moves[RoguemonStreamer.random(#moves)]
                p.disabledMoveId = chosen
                p.disabledMoveTurns = scale
                p.disabledMoveApplied = false
                RoguemonStreamer.saveSettings()
                
                -- Write to GBA RAM immediately
                if battleMonsAddress and battleSlot then
                    local structSize = GameSettings.disableStructEntrySize
                    if GameSettings.gDisableStructs and structSize and GameSettings.disabledMoveOffset and GameSettings.disableTimerOffset then
                        local base = GameSettings.gDisableStructs + battleSlot * structSize
                        Memory.writeword(base + GameSettings.disabledMoveOffset, chosen)
                        Memory.writeword(base + GameSettings.disableTimerOffset, scale)
                        local status3Offset = GameSettings.battleVolatilesOffset and (GameSettings.battleVolatilesOffset + 4) or 0x54
                        local disableDword = Utils.bit_or(Memory.readdword(battleMonsAddress + status3Offset) or 0, 0x00000004)
                        Memory.writedword(battleMonsAddress + status3Offset, disableDword)
                        p.disabledMoveApplied = true
                        RoguemonStreamer.saveSettings()
                    end
                end
                print(string.format("[RogueMon Streamer] Activated %s event immediately: ID %d for %d turns.", eventName, chosen, scale))
                local moveName = (MoveData and MoveData.Moves[chosen] or {}).name or "Move"
                return string.format("%s ( %s, %d turns )", eventName, trim(moveName), scale)
            else
                print(string.format("[RogueMon Streamer] %s activation failed: No active moves found.", eventName))
                return string.format("%s ( Failed )", eventName)
            end
        end
    end
    return "Unknown"
end

function RoguemonStreamer.queueOrActivateNoGuardEvent(eventName, scale)
    local p = RoguemonStreamer.settings.persistent
    if not p then return "Failed" end

    local btlCount = 1
    if scale and scale >= 10 then
        btlCount = math.floor(scale / 2)
    elseif scale and scale >= 5 and scale <= 9 then
        btlCount = 2 -- Milestone 5: 2 battles fixed
    end
    if RoguemonStreamer.isChannelPointsExecution then
        btlCount = 1
    end

    if eventName == "No Guard Plus" then
        local current = p.noGuardPlusActive or 0
        if type(current) ~= "number" then current = 0 end
        p.noGuardPlusActive = current + btlCount
        p.noGuardPlusApplied = false
        RoguemonStreamer.saveSettings()
        print(string.format("[RogueMon Streamer] Added No Guard Plus for %d battles.", btlCount))
        return string.format("No Guard Plus ( Player moves cannot miss for %d btl )", p.noGuardPlusActive)
    else
        local current = p.noGuardMinusActive or 0
        if type(current) ~= "number" then current = 0 end
        p.noGuardMinusActive = current + btlCount
        p.noGuardMinusApplied = false
        RoguemonStreamer.saveSettings()
        print(string.format("[RogueMon Streamer] Added No Guard Minus for %d battles.", btlCount))
        return string.format("No Guard Minus ( Enemies cannot miss for %d btl )", p.noGuardMinusActive)
    end
end

function RoguemonStreamer.queueOrActivateTempTypeChange(scale)
    local p = RoguemonStreamer.settings.persistent
    if not p then return "Failed" end

    p.queuedTempTypes = p.queuedTempTypes or {}
    local inBattle = Battle.inActiveBattle()
    local isAnyActive = p.tempTypeChange ~= nil

    -- Dynamically build typing pools from ALL mono and dual-type combinations.
    -- Uses actual type effectiveness data to classify each combination into:
    --   opPool:      no x4, max 2 x2 weaknesses, ≥2 resistances (x0.5/x0.25), ≥1 immunity (x0)
    --   goodPool:    no x4, max 3 x2, ≥3 total defensive (res+imm combined)
    --   badPool:     at least 1 x4 weakness
    --   neutralPool: everything else
    local allTypeIds = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 17, 18, 19 }
    local opPool, goodPool, badPool, neutralPool = {}, {}, {}, {}

    if MoveData and MoveData.TypeToEffectiveness then
        local function getDefenseStats(typeId1, typeId2)
            local t1 = string.lower(PokemonData.TypeIndexMap[typeId1] or "")
            local t2 = string.lower(PokemonData.TypeIndexMap[typeId2] or "")
            local isMono = (typeId1 == typeId2)
            local x0, x025, x05, x2, x4 = 0, 0, 0, 0, 0
            for _, eff in pairs(MoveData.TypeToEffectiveness) do
                local m = (eff[t1] or 1)
                if not isMono then m = m * (eff[t2] or 1) end
                if     m == 0   then x0   = x0   + 1
                elseif m < 0.3  then x025 = x025 + 1   -- 0.25
                elseif m < 0.9  then x05  = x05  + 1   -- 0.5
                elseif m > 3.5  then x4   = x4   + 1   -- 4
                elseif m > 1.5  then x2   = x2   + 1   -- 2
                end
            end
            return x0, x025, x05, x2, x4
        end

        for i = 1, #allTypeIds do
            for j = i, #allTypeIds do   -- j starts at i so i==j = mono-type
                local t1, t2 = allTypeIds[i], allTypeIds[j]
                local x0, x025, x05, x2, x4 = getDefenseStats(t1, t2)
                local pureRes  = x025 + x05        -- resistances only (x0.5 + x0.25)
                local totalDef = x0 + x025 + x05   -- all defensive (res + immunity)

                if x4 >= 1 then
                    -- bad: at least 1 x4 weakness
                    table.insert(badPool, { t1, t2 })
                elseif x2 <= 2 and pureRes >= 2 and x0 >= 1 then
                    -- op: no x4, max 2 x2, ≥2 resistances (x0.5/x0.25), ≥1 immunity
                    table.insert(opPool, { t1, t2 })
                elseif x2 <= 3 and totalDef >= 3 then
                    -- good: no x4, max 3 x2, ≥3 combined defensive
                    table.insert(goodPool, { t1, t2 })
                else
                    -- neutral: everything else
                    table.insert(neutralPool, { t1, t2 })
                end
            end
        end
    else
        -- Fallback if MoveData not available: use original hardcoded lists
        badPool    = { {6,16},{13,16},{13,7},{6,13},{16,7},{15,13},{16,5} }
        neutralPool= { {1,1},{7,7},{16,16},{15,15},{13,13},{6,6},{16,15},{6,12},{6,5},{7,3},{11,6},{1,3},{13,18},{11,7} }
    end

    -- Temp type change draws from bad+neutral combined with equal probability per typing
    local combined = {}
    for _, v in ipairs(badPool)     do table.insert(combined, v) end
    for _, v in ipairs(neutralPool) do table.insert(combined, v) end
    if #combined == 0 then combined = { {6, 16} } end  -- ultimate fallback

    local picked = combined[RoguemonStreamer.random(#combined)]
    local t1, t2 = picked[1], picked[2]
    local t1Name = PokemonData.TypeIndexMap[t1] or "Unknown"
    local t2Name = PokemonData.TypeIndexMap[t2] or "Unknown"
    local typingStr = (t1Name == t2Name) and t1Name or (t1Name .. "/" .. t2Name)

    if not inBattle or isAnyActive then
        table.insert(p.queuedTempTypes, { t1, t2 })
        RoguemonStreamer.saveSettings()
        print(string.format("[RogueMon Streamer] Queued Temp Type Change: %d/%d", t1, t2))
        return string.format("Temp Type Change ( %s, 1 btl )", trim(typingStr))
    else
        p.tempTypeChange = { t1, t2 }
        p.tempTypeApplied = false
        RoguemonStreamer.saveSettings()

        -- Write to GBA battle RAM immediately if we are in battle
        local activeIdx = getActivePartyIndex()
        local battleSlot = RoguemonStreamer.getBattleSlot(activeIdx)
        if battleSlot then
            RoguemonStreamer.writeAlteredTypesToBattle(battleSlot, t1, t2)
            p.tempTypeApplied = true
            RoguemonStreamer.saveSettings()
        end
        print(string.format("[RogueMon Streamer] Activated Temp Type Change immediately: %d/%d", t1, t2))
        return string.format("Temp Type Change ( %s, 1 btl )", trim(typingStr))
    end
end


-- POSITIVE EVENT EXECUTION
function RoguemonStreamer.executePositiveEvent(eventName, scale)
    RoguemonStreamer.updateItemIds()
    local activeIdx = 1
    print(string.format("[RogueMon Streamer] Executing Positive Event: '%s' (Scale: %d, Active Party Index: %d)", eventName, scale, activeIdx))
    
    local detail = nil
    if eventName == "Restore PP" then
        if scale == 1 then
            local slot = RoguemonStreamer.random(4)
            print(string.format("[RogueMon Streamer] - Restoring PP of move slot %d", slot))
            RoguemonStreamer.restorePP(activeIdx, slot)
            detail = "Restore PP ( 1 Slot )"
        else
            print("[RogueMon Streamer] - Restoring PP of all moves")
            RoguemonStreamer.restorePP(activeIdx)
            detail = "Restore PP ( All )"
        end
    elseif eventName == "Cure Status" then
        print("[RogueMon Streamer] - Curing status conditions")
        RoguemonStreamer.cureStatus(activeIdx)
        detail = "Cure Status"
    elseif eventName == "Restore HP" then
        print("[RogueMon Streamer] - Healing HP to full")
        RoguemonStreamer.healHP(activeIdx)
        detail = "Restore HP"
    elseif eventName == "Full Restore" then
        print("[RogueMon Streamer] - Full Restoring HP, Status, and PP, and clearing temporary negative effects")
        RoguemonStreamer.healHP(activeIdx)
        RoguemonStreamer.cureStatus(activeIdx)
        RoguemonStreamer.restorePP(activeIdx)

        -- Clear Out of Control (except if duration >= 25)
        local oocTurns = RoguemonStreamer.settings.persistent.outOfControlTurns or 0
        if oocTurns < 25 then
            RoguemonStreamer.settings.persistent.outOfControlTurns = 0
            RoguemonStreamer.settings.persistent.queuedOutOfControlTurns = 0
            if RoguemonStreamer.MovesOverwritten then
                RoguemonStreamer.restoreOriginalMoves(activeIdx)
            end
        else
            print("[RogueMon Streamer] - Out of Control is immune to Full Restore (duration >= 25). Not cleared.")
        end

        -- Clear No Guard Minus
        RoguemonStreamer.settings.persistent.noGuardMinusActive = nil
        RoguemonStreamer.settings.persistent.noGuardMinusApplied = nil
        local newNoGuards = {}
        for _, entry in ipairs(RoguemonStreamer.settings.persistent.queuedNoGuards or {}) do
            local isMinus = false
            if type(entry) == "table" then
                if entry.type == "Minus" then
                    isMinus = true
                end
            elseif entry == "Minus" then
                isMinus = true
            end
            if not isMinus then
                table.insert(newNoGuards, entry)
            end
        end
        RoguemonStreamer.settings.persistent.queuedNoGuards = newNoGuards

        -- Clear queued status/damage events
        RoguemonStreamer.settings.persistent.queuedStatuses = {}
        RoguemonStreamer.settings.persistent.queuedDamageAndStatus = {}
        RoguemonStreamer.settings.persistent.overwhelmedActive = nil
        RoguemonStreamer.settings.persistent.queuedOverwhelmedCount = 0

        -- Clear Omnimalus
        RoguemonStreamer.settings.persistent.omnimalusActive = nil
        RoguemonStreamer.settings.persistent.queuedOmnimalusCount = 0

        -- Clear Mystification
        RoguemonStreamer.settings.persistent.mystificationActive = nil
        RoguemonStreamer.settings.persistent.mystificationApplied = nil
        local fsAddr = GameSettings.fieldStatusesAddr
        local ftAddr = GameSettings.fieldTimersAddr
        local ftOff = GameSettings.fieldTimerTerrainOffset
        if fsAddr and fsAddr ~= 0 and ftAddr and ftAddr ~= 0 and ftOff then
            local fs = Memory.readdword(fsAddr) or 0
            fs = Utils.bit_and(fs, 0xFFFFFFFD)
            Memory.writedword(fsAddr, fs)
            if ftOff == 12 then
                Memory.writeword(ftAddr + 8, 0)
            elseif ftOff == 6 then
                Memory.writebyte(ftAddr + 4, 0)
            else
                local off16 = ftOff - 4
                local off8 = ftOff - 2
                if off16 >= 0 then Memory.writebyte(ftAddr + off16, 0) end
                if off8 >= 0 then Memory.writebyte(ftAddr + off8, 0) end
            end
            RoguemonStreamer.isTrickRoomActivePrev = false
            print("[RogueMon Streamer] Full Restore: Cleared Mystification/Trick Room from battle RAM.")
        end

        -- Resolve battle variables if in battle
        local battleSlot = nil
        local battleMonsAddress = nil
        if Battle.inActiveBattle() then
            if activeIdx == Battle.Combatants.LeftOwn then
                battleSlot = 0
            elseif Battle.numBattlers == 4 and activeIdx == Battle.Combatants.RightOwn then
                battleSlot = 2
            end
            if battleSlot ~= nil and GameSettings.gBattleMons then
                battleMonsAddress = GameSettings.gBattleMons + (battleSlot * (GameSettings.sizeofBattlePokemon or 0x58))
            end
        end

        -- Clear active disabled move and queued disabled moves
        RoguemonStreamer.settings.persistent.disabledMoveId = nil
        RoguemonStreamer.settings.persistent.disabledMoveTurns = nil
        RoguemonStreamer.settings.persistent.disabledMoveApplied = nil
        RoguemonStreamer.settings.persistent.queuedDisableTurns = {}

        if battleSlot ~= nil then
            local structSize = GameSettings.disableStructEntrySize
            if GameSettings.gDisableStructs and structSize and GameSettings.disabledMoveOffset and GameSettings.disableTimerOffset then
                local base = GameSettings.gDisableStructs + battleSlot * structSize
                Memory.writeword(base + GameSettings.disabledMoveOffset, 0)
                Memory.writeword(base + GameSettings.disableTimerOffset, 0)
            end
            if battleMonsAddress then
                local status3Offset = GameSettings.battleVolatilesOffset and (GameSettings.battleVolatilesOffset + 4) or 0x54
                local disableDword = Memory.readdword(battleMonsAddress + status3Offset) or 0
                disableDword = disableDword & (~0x00000004)
                Memory.writedword(battleMonsAddress + status3Offset, disableDword)
            end
        end

        -- Clear active temp type change and queued temp type changes
        RoguemonStreamer.settings.persistent.tempTypeChange = nil
        RoguemonStreamer.settings.persistent.tempTypeApplied = nil
        RoguemonStreamer.settings.persistent.queuedTempTypes = {}

        if battleSlot ~= nil then
            local leadMon = Battle.getViewedPokemon(true)
            if leadMon then
                local pt1, pt2 = getPermanentTypesOfPokemon(leadMon)
                if pt1 and pt2 then
                    RoguemonStreamer.writeAlteredTypesToBattle(battleSlot, pt1, pt2)
                end
            end
        end

        -- Clear reduced stats (stat debuffs) from active buffs and battle RAM
        local buffs = RoguemonStreamer.settings.persistent.statBuffs or {}
        local accumulated = { atk = 0, def = 0, spe = 0, spa = 0, spd = 0, acc = 0, eva = 0 }
        for _, buff in ipairs(buffs) do
            if buff.remaining and buff.remaining > 0 then
                local statKey = buff.stat
                if accumulated[statKey] ~= nil then
                    accumulated[statKey] = accumulated[statKey] + buff.value
                end
            end
        end

        if battleMonsAddress then
            local statStageOffset = GameSettings.offsetBattlePokemonStatStages or 0x18
            for stat, value in pairs(accumulated) do
                if value < 0 then
                    local finalStageOffset = nil
                    if stat == "atk" then finalStageOffset = statStageOffset + 1
                    elseif stat == "def" then finalStageOffset = statStageOffset + 2
                    elseif stat == "spe" then finalStageOffset = statStageOffset + 3
                    elseif stat == "spa" then finalStageOffset = statStageOffset + 4
                    elseif stat == "spd" then finalStageOffset = statStageOffset + 5
                    elseif stat == "acc" then finalStageOffset = statStageOffset + 6
                    elseif stat == "eva" then finalStageOffset = statStageOffset + 7
                    end
                    if finalStageOffset then
                        Memory.writebyte(battleMonsAddress + finalStageOffset, 6)
                    end
                    print(string.format("[RogueMon Streamer] Full Restore reset stat stage for %s to neutral (6) in GBA RAM", stat))
                end
            end
            if Battle then
                Battle.statStageDirty = true
            end
            if Roguemon and Roguemon.Core and Roguemon.Core.Battle then
                Roguemon.Core.Battle.statStageDirty = true
            end
        end

        local activeBuffs = {}
        for _, buff in ipairs(buffs) do
            if buff.value and buff.value >= 0 then
                table.insert(activeBuffs, buff)
            end
        end
        RoguemonStreamer.settings.persistent.statBuffs = activeBuffs

        RoguemonStreamer.saveSettings()
        refreshTracker()

        detail = "Full Restore ( All negative effects cured! )"
    elseif eventName == "Increase Healing Limit" then
        local capAdd = (scale == 1) and 50 or 100
        RoguemonStreamer.settings.persistent.hpCapBoost = (RoguemonStreamer.settings.persistent.hpCapBoost or 0) + capAdd
        RoguemonStreamer.saveSettings()
        print(string.format("[RogueMon Streamer] - Increased HP cap boost by %d. New total boost: %d", capAdd, RoguemonStreamer.settings.persistent.hpCapBoost))
        
        -- Also force immediate state reload and sync to GBA RAM
        if Roguemon and Roguemon.TrackerDataManager and Roguemon.TrackerDataManager.readState then
            Roguemon.TrackerDataManager.readState()
        end
        detail = string.format("Increase Healing Limit ( +%d HP )", capAdd)
    elseif eventName == "Increase Status Limit" then
        local capAdd = (scale == 1) and 1 or 2
        RoguemonStreamer.settings.persistent.statusCapBoost = (RoguemonStreamer.settings.persistent.statusCapBoost or 0) + capAdd
        RoguemonStreamer.saveSettings()
        print(string.format("[RogueMon Streamer] - Increased Status limit cap boost by %d. New total boost: %d", capAdd, RoguemonStreamer.settings.persistent.statusCapBoost))
        
        -- Also force immediate state reload and sync to GBA RAM
        if Roguemon and Roguemon.TrackerDataManager and Roguemon.TrackerDataManager.readState then
            Roguemon.TrackerDataManager.readState()
        end
        detail = string.format("Increase Status Limit ( +%d status )", capAdd)
    elseif eventName == "Give Healing Item" then
        local itemId
        if scale == 1 then
            -- Cumulative pool: random healing item <= 50 HP (Potion, Super Potion, Energy Powder, Soda Pop, Sweet Heart, Berry Juice)
            local pool = { ITEMS.POTION, ITEMS.SUPER_POTION, ITEMS.ENERGY_POWDER, ITEMS.SODA_POP, ITEMS.SWEET_HEART, ITEMS.BERRY_JUICE }
            itemId = pool[RoguemonStreamer.random(1, #pool)]
        else
            -- Milestone 5+ pool: Lemonade, Energy Root, Moomoo Milk, Hyper Potion, Max Potion, Full Restore
            -- Guaranteed Full Restore at scale >= 50
            if scale >= 50 then
                itemId = ITEMS.FULL_RESTORE
            else
                -- More likely to get 200HP+ as scale increases
                -- low power: Lemonade (80), Moomoo Milk (100)
                -- high power: Energy Root (200), Hyper Potion (200), Max Potion (Full), Full Restore (Full)
                local highChance = math.min(95, math.floor(10 + (scale - 5) * (70 / 15))) -- e.g. 5 subs = 10%, 10 subs = 33%, 20 subs = 80%, 40 subs = 95%
                if RoguemonStreamer.random(1, 100) <= highChance then
                    local highPool = { ITEMS.ENERGY_ROOT, ITEMS.HYPER_POTION, ITEMS.MAX_POTION, ITEMS.FULL_RESTORE }
                    itemId = highPool[RoguemonStreamer.random(1, #highPool)]
                else
                    local lowPool = { ITEMS.LEMONADE, ITEMS.MOOMOO_MILK }
                    itemId = lowPool[RoguemonStreamer.random(1, #lowPool)]
                end
            end
        end
        local itemName = (Resources and Resources.Game and Resources.Game.ItemNames and Resources.Game.ItemNames[itemId]) or "Healing Item"
        print(string.format("[RogueMon Streamer] - Giving healing item: ID %d (%s)", itemId, itemName))
        grantItem(itemId, 1)
        detail = string.format("Give Healing Item ( %s )", trim(itemName))
    elseif eventName == "Give Status Item" or eventName == "Give Utility Item" or eventName == "Give Utility Items" then
        local itemId
        if scale == 1 then
            -- Cumulative pool: random single status cure (Antidote, Burn Heal, Ice Heal, Awakening, Paralyze Heal)
            local pool = { ITEMS.ANTIDOTE, ITEMS.BURN_HEAL, ITEMS.ICE_HEAL, ITEMS.AWAKENING, ITEMS.PARALYZE_HEAL }
            itemId = pool[RoguemonStreamer.random(1, #pool)]
            local itemName = (Resources and Resources.Game and Resources.Game.ItemNames and Resources.Game.ItemNames[itemId]) or "Status Item"
            print(string.format("[RogueMon Streamer] - Giving status cure item: ID %d (%s)", itemId, itemName))
            grantItem(itemId, 1)
            detail = string.format("Give Status Item ( %s )", trim(itemName))
        elseif eventName == "Give Utility Items" then
            -- Milestone 10+ pool: BOTH Full Heal and Rare Candy
            print("[RogueMon Streamer] - Giving utility items: Full Heal & Rare Candy")
            grantItem(ITEMS.FULL_HEAL, 1)
            grantItem(ITEMS.RARE_CANDY, 1)
            detail = "Give Utility Items ( Full Heal & Rare Candy )"
        else
            -- Milestone 5+ pool: Full Heal or Rare Candy (50% / 50%)
            itemId = RoguemonStreamer.random(1, 2) == 1 and ITEMS.FULL_HEAL or ITEMS.RARE_CANDY
            local itemName = (Resources and Resources.Game and Resources.Game.ItemNames and Resources.Game.ItemNames[itemId]) or "Utility Item"
            print(string.format("[RogueMon Streamer] - Giving utility item: ID %d (%s)", itemId, itemName))
            grantItem(itemId, 1)
            detail = string.format("Give Utility Item ( %s )", trim(itemName))
        end
    elseif eventName == "Give PP Item" then
        local itemId
        if scale == 1 then
            -- Cumulative: Ether, PP Up, Leppa Berry
            local pool = { ITEMS.ETHER, ITEMS.PP_UP, ITEMS.LEPPA_BERRY }
            itemId = pool[RoguemonStreamer.random(1, #pool)]
        else
            -- Milestones
            if scale >= 50 then
                -- 50+ subs: PP Max 50%, Max Elixir 50%
                local pool = { ITEMS.PP_MAX, ITEMS.MAX_ELIXIR }
                itemId = pool[RoguemonStreamer.random(1, #pool)]
            elseif scale >= 20 then
                -- 20+ subs: Max Elixir 60%, Elixir 10%, PP Max 30%
                local r = RoguemonStreamer.random(1, 100)
                if r <= 60 then
                    itemId = ITEMS.MAX_ELIXIR
                elseif r <= 70 then
                    itemId = ITEMS.ELIXIR
                else
                    itemId = ITEMS.PP_MAX
                end
            elseif scale >= 10 then
                -- 10+ subs: Elixir 50%, Max Elixir 40%, PP Max 10%
                local r = RoguemonStreamer.random(1, 100)
                if r <= 50 then
                    itemId = ITEMS.ELIXIR
                elseif r <= 90 then
                    itemId = ITEMS.MAX_ELIXIR
                else
                    itemId = ITEMS.PP_MAX
                end
            else
                -- 5+ subs: Max Ether, PP Up, Elixir
                local pool = { ITEMS.MAX_ETHER, ITEMS.PP_UP, ITEMS.ELIXIR }
                itemId = pool[RoguemonStreamer.random(1, #pool)]
            end
        end
        local itemName = (Resources and Resources.Game and Resources.Game.ItemNames and Resources.Game.ItemNames[itemId]) or "PP Item"
        print(string.format("[RogueMon Streamer] - Giving PP restore item: ID %d (%s)", itemId, itemName))
        grantItem(itemId, 1)
        detail = string.format("Give PP Item ( %s )", trim(itemName))
    elseif eventName == "Stat Boost" then
        local statKeys = { "atk", "def", "spe", "spa", "spd", "acc", "eva" }
        local stat = statKeys[RoguemonStreamer.random(1, #statKeys)]
        local duration = scale
        if scale and scale >= 5 and scale <= 9 then
            duration = 3 -- Milestone 5: 3 battles fixed
        end
        RoguemonStreamer.addStatBuff(stat, 1, duration)
        local statName = STAT_NAMES[stat] or stat
        local btlStr = duration == 1 and "btl" or "btls"
        print(string.format("[RogueMon Streamer] - Applied persistent Stat Boost: %s +1 stage for %d battles", stat, duration))
        detail = string.format("Stat Boost ( %s +1 ) for %d %s", trim(STAT_LABELS[stat] or stat), duration, btlStr)
    elseif eventName == "Power Boost" then
        local stats = getPartyMonStats(activeIdx)
        local stat = "atk"
        if stats and stats.spa > stats.atk then
            stat = "spa"
        end
        RoguemonStreamer.addStatBuff(stat, 1, 1)
        local btlStr = "btl"
        print(string.format("[RogueMon Streamer] - Applied persistent Power Boost: %s +1 stage for 1 battle", stat))
        detail = string.format("Power Boost ( %s +1 ) for 1 %s", trim(STAT_LABELS[stat] or stat), btlStr)
    elseif eventName == "Speed Boost" then
        RoguemonStreamer.addStatBuff("spe", 1, 1)
        local btlStr = "btl"
        print("[RogueMon Streamer] - Applied persistent Speed Boost: spe +1 stage for 1 battle")
        detail = string.format("Speed Boost ( Spe +1 ) for 1 %s", btlStr)
    elseif eventName == "PP Up" then
        local moveName = RoguemonStreamer.applyPPUp(activeIdx)
        if moveName then
            print(string.format("[RogueMon Streamer] - Applied PP Up to move: %s", moveName))
            detail = string.format("PP Up ( %s )", trim(moveName))
        else
            print("[RogueMon Streamer] - PP Up failed: no eligible moves found or all maxed")
            detail = "PP Up ( Failed / Maxed )"
        end
    elseif eventName == "Powerhouse Boost" then
        local stats = getPartyMonStats(activeIdx)
        local stat = "atk"
        if stats and stats.spa > stats.atk then
            stat = "spa"
        end
        local duration = 1
        if scale and scale >= 50 then
            duration = math.floor(scale / 2)
        elseif scale and scale >= 20 then
            duration = 5 -- Milestone 20: 5 battles
        elseif scale and scale >= 10 then
            duration = 3 -- Milestone 10: 3 battles
        elseif scale and scale >= 5 then
            duration = 2 -- Milestone 5: 2 battles
        else
            duration = 1
        end
        if RoguemonStreamer.isChannelPointsExecution then
            duration = 1
        end
        RoguemonStreamer.addStatBuff(stat, 1, duration)
        RoguemonStreamer.addStatBuff("spe", 1, duration)
        local btlStr = duration == 1 and "battle" or "battles"
        print(string.format("[RogueMon Streamer] - Applied persistent Powerhouse Boost: %s +1 and spe +1 stage for %d battles", stat, duration))
        detail = string.format("Powerhouse Boost ( %s +1, Spe +1 ) for %d %s", trim(STAT_LABELS[stat] or stat), duration, btlStr)
    elseif eventName == "Permanent Type Change" then
        local leadMon = Battle.getViewedPokemon(true)
        if leadMon and leadMon.personality then
            local personalityHex = string.format("0x%X", leadMon.personality)
            RoguemonStreamer.settings.alteredTypes = RoguemonStreamer.settings.alteredTypes or {}
            local t1, t2 = generateTyping(scale, true)
            RoguemonStreamer.settings.alteredTypes[personalityHex] = { t1, t2 }
            RoguemonStreamer.saveSettings()
            
            local battleSlot = nil
            if Battle.inActiveBattle() then
                if activeIdx == Battle.Combatants.LeftOwn then
                    battleSlot = 0
                elseif Battle.numBattlers == 4 and activeIdx == Battle.Combatants.RightOwn then
                    battleSlot = 2
                end
            end
            if battleSlot ~= nil then
                RoguemonStreamer.writeAlteredTypesToBattle(battleSlot, t1, t2)
            end
            local t1Name = PokemonData.TypeIndexMap[t1] or "Unknown"
            local t2Name = PokemonData.TypeIndexMap[t2] or "Unknown"
            print(string.format("[RogueMon Streamer] - Permanently changed viewed Pokemon (personality: %s) types to %s/%s (IDs: %d/%d) [Good]", personalityHex, t1Name, t2Name, t1, t2))
            if t1Name == t2Name then
                detail = string.format("Permanent Type Change ( %s )", trim(t1Name))
            else
                detail = string.format("Permanent Type Change ( %s/%s )", trim(t1Name), trim(t2Name))
            end
        else
            print("[RogueMon Streamer] - Permanent Type Change failed: No viewed Pokemon found")
            detail = "Permanent Type Change ( Failed )"
        end
    elseif eventName == "Permanent Nature Change" then
        local targetNature = generateNature(activeIdx, scale, true)
        RoguemonStreamer.changePokemonPersonality(activeIdx, targetNature, nil)
        local natureNames = {
            [0] = "Hardy", [1] = "Lonely", [2] = "Brave", [3] = "Adamant", [4] = "Naughty",
            [5] = "Bold", [6] = "Docile", [7] = "Relaxed", [8] = "Impish", [9] = "Lax",
            [10] = "Timid", [11] = "Hasty", [12] = "Serious", [13] = "Jolly", [14] = "Naive",
            [15] = "Modest", [16] = "Mild", [17] = "Quiet", [18] = "Bashful", [19] = "Rash",
            [20] = "Calm", [21] = "Gentle", [22] = "Sassy", [23] = "Careful", [24] = "Quirky"
        }
        local natureName = natureNames[targetNature] or "Unknown"
        print(string.format("[RogueMon Streamer] - Permanently changed Pokemon nature to %s (ID: %d) [Good]", natureName, targetNature))
        detail = string.format("Permanent Nature Change ( %s )", trim(natureName))
    elseif eventName == "Permanent Ability Change" then
        local leadMon = Battle.getViewedPokemon(true)
        if leadMon and leadMon.personality then
            local personalityHex = string.format("0x%X", leadMon.personality)
            local newAbilityId = generateAbility(scale, true)
            RoguemonStreamer.settings.alteredAbilities = RoguemonStreamer.settings.alteredAbilities or {}
            RoguemonStreamer.settings.alteredAbilities[personalityHex] = newAbilityId
            RoguemonStreamer.saveSettings()
            
            local battleMonsAddress = nil
            if Battle.inActiveBattle() then
                local battleSlot = nil
                if activeIdx == Battle.Combatants.LeftOwn then
                    battleSlot = 0
                elseif Battle.numBattlers == 4 and activeIdx == Battle.Combatants.RightOwn then
                    battleSlot = 2
                end
                if battleSlot ~= nil then
                    battleMonsAddress = GameSettings.gBattleMons + (battleSlot * (GameSettings.sizeofBattlePokemon or 0x58))
                end
            end
            if battleMonsAddress ~= nil then
                local abilityOffset = RoguemonStreamer.getBattleAbilityOffset()
                Memory.writeword(battleMonsAddress + abilityOffset, newAbilityId)
            end
            
            local abilityName = (AbilityData.Abilities[newAbilityId] or {}).name or "Unknown"
            print(string.format("[RogueMon Streamer] - Permanently changed Pokemon (personality: %s) ability to %s (ID: %d) [Good]", personalityHex, abilityName, newAbilityId))
            detail = string.format("Permanent Ability Change ( %s )", trim(abilityName))
        else
            print("[RogueMon Streamer] - Permanent Ability Change failed: No viewed Pokemon found")
            detail = "Permanent Ability Change ( Failed )"
        end
    elseif eventName == "Omniboost" then
        local duration = 1
        if scale and scale >= 50 then
            duration = math.floor(scale / 2) -- Milestone 50: 25 battles
        elseif scale and scale >= 20 then
            duration = 4 -- Milestone 20: 4 battles
        elseif scale and scale >= 10 then
            duration = 2 -- Milestone 10: 2 battles
        end
        if RoguemonStreamer.isChannelPointsExecution then
            duration = 1
        end
        local stats = { "atk", "def", "spe", "spa", "spd", "acc", "eva" }
        for _, stat in ipairs(stats) do
            RoguemonStreamer.addStatBuff(stat, 1, duration)
        end
        detail = string.format("Omniboost ( +1 to all stats for %d battle%s )", duration, duration == 1 and "" or "s")
    elseif eventName == "No Guard Plus" then
        detail = RoguemonStreamer.queueOrActivateNoGuardEvent("No Guard Plus", scale)
    elseif eventName == "Evolution Power" then
        print("[RogueMon Streamer] - Giving 1 Roguestone")
        grantItem(ITEMS.ROGUESTONE, 1)
        detail = "Evolution Power ( +1 Roguestone )"
    elseif eventName == "Turbo Genetics" then
        local leadMon = Battle.getViewedPokemon(true)
        local alreadyFiltered = false
        if leadMon and leadMon.personality then
            local phex = string.format("0x%X_%d", leadMon.personality, leadMon.pokemonID or 0)
            if RoguemonStreamer.settings.persistent.evolutionFilteredPids and RoguemonStreamer.settings.persistent.evolutionFilteredPids[phex] then
                alreadyFiltered = true
            end
        end

        if leadMon and leadMon.pokemonID and leadMon.pokemonID > 0 and not alreadyFiltered then
            local pokemonID = leadMon.pokemonID
            
            PokemonRevoData.tryLoadData()
            
            if PokemonRevoData.RevoData and PokemonRevoData.RevoData[pokemonID] then
                local options = PokemonRevoData.getEvoOptions(pokemonID)
                local hasFiltered = false
                
                local function filterEvoList(evoList)
                    if not evoList or #evoList == 0 then return false end
                    local tempList = {}
                    for _, entry in ipairs(evoList) do
                        if entry.id then
                            local pkData = PokemonData.Pokemon[entry.id]
                            local bst = 0
                            if pkData then
                                bst = tonumber(pkData.bst) or pkData.bstCalculated or 0
                            end
                            table.insert(tempList, {
                                id = entry.id,
                                perc = entry.perc or 0,
                                bst = bst
                            })
                        end
                    end
                    
                    if #tempList == 0 then return false end
                    
                    table.sort(tempList, function(a, b)
                        return a.bst > b.bst
                    end)
                    
                    local targetSize = math.min(10, #tempList)
                    local newList = {}
                    local totalPerc = 0
                    for i = 1, targetSize do
                        table.insert(newList, tempList[i])
                        totalPerc = totalPerc + tempList[i].perc
                    end
                    
                    if totalPerc > 0 then
                        for i = 1, targetSize do
                            newList[i].perc = (newList[i].perc / totalPerc) * 100
                        end
                    else
                        for i = 1, targetSize do
                            newList[i].perc = 100 / targetSize
                        end
                    end
                    
                    -- Roll a weighted random candidate from the top 10
                    local roll = RoguemonStreamer.random(10000) / 100.0
                    local chosenCandidate = newList[1]
                    local runningSum = 0
                    for i = 1, targetSize do
                        runningSum = runningSum + newList[i].perc
                        if roll <= runningSum then
                            chosenCandidate = newList[i]
                            break
                        end
                    end
                    
                    -- Write the chosen candidate to the GBA evolution table in memory
                    local base = GameSettings.gSpeciesInfo
                    local size = GameSettings.sizeofBaseStatsPokemon
                    local offset = GameSettings.offsetSpeciesEvolutions
                    local wroteToGBA = false
                    
                    if base and base ~= 0 and size and offset then
                        local ptr = Memory.readdword(base + (size * pokemonID) + offset)
                        if ptr and ptr ~= 0 then
                            for cursor = 0, 9 do
                                local evoType = Memory.readword(ptr + (cursor * 12))
                                if evoType == 0xFFFF or evoType == 0 then break end
                                Memory.writedword(ptr + (cursor * 12) + 4, chosenCandidate.id)
                            end
                            wroteToGBA = true
                            print(string.format("[RogueMon Streamer] Turbo Genetics: Overwrote GBA evolution target for species %d to %d", pokemonID, chosenCandidate.id))
                        end
                    end
                    
                    if not wroteToGBA then
                        print("[RogueMon Streamer] Turbo Genetics: Warning - failed to write evolution target to GBA memory.")
                    end
                    
                    -- Clear original list
                    for k = #evoList, 1, -1 do
                        table.remove(evoList, k)
                    end
                    -- Add all top 10 candidates with their normalized percentages to the Lua table
                    for i = 1, targetSize do
                        table.insert(evoList, { id = newList[i].id, perc = newList[i].perc })
                    end
                    return true, chosenCandidate.id
                end
                
                local chosenId = nil
                if options and #options > 0 then
                    for _, targetEvoId in ipairs(options) do
                        local evoList = PokemonRevoData.RevoData[pokemonID][targetEvoId]
                        local success, cid = filterEvoList(evoList)
                        if success then
                            hasFiltered = true
                            chosenId = cid
                        end
                    end
                else
                    local evoList = PokemonRevoData.RevoData[pokemonID]
                    local success, cid = filterEvoList(evoList)
                    if success then
                        hasFiltered = true
                        chosenId = cid
                    end
                end
                
                if hasFiltered and chosenId then
                    local monName = PokemonData.Pokemon[pokemonID] and PokemonData.Pokemon[pokemonID].name or "Pokemon"
                    local chosenName = PokemonData.Pokemon[chosenId] and PokemonData.Pokemon[chosenId].name or "Chosen candidate"
                    print(string.format("[RogueMon Streamer] - Turbo Genetics applied to %s. Evolution target secretly locked to %s.", monName, chosenName))
                    detail = string.format("Turbo Genetics ( Restricted %s's evolution pool to top 10 BST )", trim(monName))
                    
                    -- Record successful application to prevent future reruns
                    if leadMon and leadMon.personality then
                        local phex = string.format("0x%X_%d", leadMon.personality, leadMon.pokemonID or 0)
                        RoguemonStreamer.settings.persistent.evolutionFilteredPids = RoguemonStreamer.settings.persistent.evolutionFilteredPids or {}
                        RoguemonStreamer.settings.persistent.evolutionFilteredPids[phex] = true
                        RoguemonStreamer.saveSettings()
                    end
                else
                    print("[RogueMon Streamer] - Turbo Genetics failed to filter: Fallback giving items")
                    if scale and scale >= 50 then
                        local fullRestoreId = Roguemon.ItemManager.getItemIdByName("Full Restore") or 19
                        local rareCandyId = Roguemon.ItemManager.getItemIdByName("Rare Candy") or 68
                        grantItem(fullRestoreId, 2)
                        grantItem(rareCandyId, 1)
                        detail = "Turbo Genetics ( Failed -> +2 Full Restore, +1 Rare Candy )"
                    else
                        grantItem(ITEMS.HYPER_POTION, 1)
                        detail = "Turbo Genetics ( Failed -> +1 Hyper Potion )"
                    end
                end
            else
                print(string.format("[RogueMon Streamer] - Turbo Genetics: Species %d has no evolutions. Fallback giving items.", pokemonID))
                if scale and scale >= 50 then
                    local fullRestoreId = Roguemon.ItemManager.getItemIdByName("Full Restore") or 19
                    local rareCandyId = Roguemon.ItemManager.getItemIdByName("Rare Candy") or 68
                    grantItem(fullRestoreId, 2)
                    grantItem(rareCandyId, 1)
                    detail = "Turbo Genetics ( Fully evolved -> +2 Full Restore, +1 Rare Candy )"
                else
                    grantItem(ITEMS.HYPER_POTION, 1)
                    detail = "Turbo Genetics ( Fully evolved -> +1 Hyper Potion )"
                end
            end
        else
            if alreadyFiltered then
                print("[RogueMon Streamer] - Turbo Genetics: Active Pokémon already has filtered evolutions. Fallback giving items.")
                if scale and scale >= 50 then
                    local fullRestoreId = Roguemon.ItemManager.getItemIdByName("Full Restore") or 19
                    local rareCandyId = Roguemon.ItemManager.getItemIdByName("Rare Candy") or 68
                    grantItem(fullRestoreId, 2)
                    grantItem(rareCandyId, 1)
                    detail = "Turbo Genetics ( Already filtered -> +2 Full Restore, +1 Rare Candy )"
                else
                    grantItem(ITEMS.HYPER_POTION, 1)
                    detail = "Turbo Genetics ( Already filtered -> +1 Hyper Potion )"
                end
            else
                print("[RogueMon Streamer] - Turbo Genetics: No viewed Pokemon. Fallback giving items.")
                if scale and scale >= 50 then
                    local fullRestoreId = Roguemon.ItemManager.getItemIdByName("Full Restore") or 19
                    local rareCandyId = Roguemon.ItemManager.getItemIdByName("Rare Candy") or 68
                    grantItem(fullRestoreId, 2)
                    grantItem(rareCandyId, 1)
                    detail = "Turbo Genetics ( No Pokemon viewed -> +2 Full Restore, +1 Rare Candy )"
                else
                    grantItem(ITEMS.HYPER_POTION, 1)
                    detail = "Turbo Genetics ( No Pokemon viewed -> +1 Hyper Potion )"
                end
            end
        end
    elseif eventName == "Darwinism" then
        local leadMon = Battle.getViewedPokemon(true)
        local alreadyFiltered = false
        if leadMon and leadMon.personality then
            local phex = string.format("0x%X_%d", leadMon.personality, leadMon.pokemonID or 0)
            if RoguemonStreamer.settings.persistent.evolutionFilteredPids and RoguemonStreamer.settings.persistent.evolutionFilteredPids[phex] then
                alreadyFiltered = true
            end
        end

        if leadMon and leadMon.pokemonID and leadMon.pokemonID > 0 and not alreadyFiltered then
            local pokemonID = leadMon.pokemonID
            
            PokemonRevoData.tryLoadData()
            
            if PokemonRevoData.RevoData and PokemonRevoData.RevoData[pokemonID] then
                local options = PokemonRevoData.getEvoOptions(pokemonID)
                local hasFiltered = false
                
                -- Determine viewed species base stats to check offensive profile and stats upgrades
                local baseAtk = 0
                local baseSpa = 0
                local baseHp = 0
                local baseSpe = 0
                local pkData = PokemonData.Pokemon[pokemonID]
                if pkData and pkData.baseStats then
                    baseHp = pkData.baseStats.hp or 0
                    baseAtk = pkData.baseStats.atk or 0
                    baseSpa = pkData.baseStats.spa or 0
                    baseSpe = pkData.baseStats.spe or 0
                end
                
                local P_isPhysical = true
                if baseAtk ~= baseSpa then
                    P_isPhysical = (baseAtk > baseSpa)
                elseif leadMon.stats and leadMon.stats.atk and leadMon.stats.spa then
                    P_isPhysical = (leadMon.stats.atk >= leadMon.stats.spa)
                end
                local myMainAtk = P_isPhysical and baseAtk or baseSpa
                
                local function filterDarwinEvoList(evoList)
                    if not evoList or #evoList == 0 then return false end
                    local tempList = {}
                    local matchCount = 0
                    
                    for _, entry in ipairs(evoList) do
                        if entry.id then
                            local cData = PokemonData.Pokemon[entry.id]
                            local bst = 0
                            local cHp = 0
                            local cAtk = 0
                            local cSpa = 0
                            local cDef = 0
                            local cSpd = 0
                            local cSpe = 0
                            
                            if cData then
                                bst = tonumber(cData.bst) or cData.bstCalculated or 0
                                if cData.baseStats then
                                    cHp = cData.baseStats.hp or 0
                                    cAtk = cData.baseStats.atk or 0
                                    cSpa = cData.baseStats.spa or 0
                                    cDef = cData.baseStats.def or 0
                                    cSpd = cData.baseStats.spd or 0
                                    cSpe = cData.baseStats.spe or 0
                                end
                            end
                            
                            local C_isPhysical = (cAtk >= cSpa)
                            local matchesProfile = (C_isPhysical == P_isPhysical)
                            if matchesProfile then
                                matchCount = matchCount + 1
                            end
                            
                            table.insert(tempList, {
                                id = entry.id,
                                perc = entry.perc or 0,
                                bst = bst,
                                hp = cHp,
                                atk = cAtk,
                                spa = cSpa,
                                def = cDef,
                                spd = cSpd,
                                spe = cSpe,
                                isPhysical = C_isPhysical,
                                matchesProfile = matchesProfile
                            })
                        end
                    end
                    
                    if #tempList == 0 then return false end
                    
                    -- Calculate Darwinian Score for each candidate:
                    -- Focus strictly on maximizing HP, main Attack, and Speed, completely ignoring Defenses.
                    -- Also apply flexible upgrade priority bonuses:
                    for _, cand in ipairs(tempList) do
                        local candMainAtk = P_isPhysical and cand.atk or cand.spa
                        local score = cand.bst + cand.hp + candMainAtk + cand.spe
                        
                        -- Offensive Profile check
                        if matchCount > 0 and not cand.matchesProfile then
                            score = score - 10000
                        end
                        
                        -- Check upgrade profile
                        local hpUpgrade = (cand.hp > baseHp)
                        local atkUpgrade = (candMainAtk > myMainAtk)
                        local speUpgrade = (cand.spe > baseSpe)
                        local upgradesCount = (hpUpgrade and 1 or 0) + (atkUpgrade and 1 or 0) + (speUpgrade and 1 or 0)
                        local sumUpgrade = (cand.hp + candMainAtk + cand.spe) > (baseHp + myMainAtk + baseSpe)
                        
                        if upgradesCount == 3 then
                            -- Strict Upgrade: HP, Attack, and Speed are all strictly greater
                            score = score + 5000
                        elseif upgradesCount >= 2 or sumUpgrade then
                            -- Partial Upgrade: at least 2 stats are greater, or the sum of the 3 stats is greater
                            score = score + 2000
                        else
                            -- Downgrade: heavily penalize candidates that are mostly inferior
                            score = score - 5000
                        end
                        
                        cand.score = score
                    end
                    
                    table.sort(tempList, function(a, b)
                        return a.score > b.score
                    end)
                    
                    local targetSize = math.min(5, #tempList)
                    local newList = {}
                    local totalPerc = 0
                    for i = 1, targetSize do
                        table.insert(newList, tempList[i])
                        totalPerc = totalPerc + tempList[i].perc
                    end
                    
                    if totalPerc > 0 then
                        for i = 1, targetSize do
                            newList[i].perc = (newList[i].perc / totalPerc) * 100
                        end
                    else
                        for i = 1, targetSize do
                            newList[i].perc = 100 / targetSize
                        end
                    end
                    
                    -- Roll a weighted random candidate from the top 5
                    local roll = RoguemonStreamer.random(10000) / 100.0
                    local chosenCandidate = newList[1]
                    local runningSum = 0
                    for i = 1, targetSize do
                        runningSum = runningSum + newList[i].perc
                        if roll <= runningSum then
                            chosenCandidate = newList[i]
                            break
                        end
                    end
                    
                    -- Write the chosen candidate to the GBA evolution table in memory
                    local base = GameSettings.gSpeciesInfo
                    local size = GameSettings.sizeofBaseStatsPokemon
                    local offset = GameSettings.offsetSpeciesEvolutions
                    local wroteToGBA = false
                    
                    if base and base ~= 0 and size and offset then
                        local ptr = Memory.readdword(base + (size * pokemonID) + offset)
                        if ptr and ptr ~= 0 then
                            for cursor = 0, 9 do
                                local evoType = Memory.readword(ptr + (cursor * 12))
                                if evoType == 0xFFFF or evoType == 0 then break end
                                Memory.writedword(ptr + (cursor * 12) + 4, chosenCandidate.id)
                            end
                            wroteToGBA = true
                            print(string.format("[RogueMon Streamer] Darwinism: Overwrote GBA evolution target for species %d to %d", pokemonID, chosenCandidate.id))
                        end
                    end
                    
                    if not wroteToGBA then
                        print("[RogueMon Streamer] Darwinism: Warning - failed to write evolution target to GBA memory.")
                    end
                    
                    -- Clear original list
                    for k = #evoList, 1, -1 do
                        table.remove(evoList, k)
                    end
                    -- Add all top 5 candidates with their normalized percentages to the Lua table
                    for i = 1, targetSize do
                        table.insert(evoList, { id = newList[i].id, perc = newList[i].perc })
                    end
                    return true, chosenCandidate.id
                end
                
                local chosenId = nil
                if options and #options > 0 then
                    for _, targetEvoId in ipairs(options) do
                        local evoList = PokemonRevoData.RevoData[pokemonID][targetEvoId]
                        local success, cid = filterDarwinEvoList(evoList)
                        if success then
                            hasFiltered = true
                            chosenId = cid
                        end
                    end
                else
                    local evoList = PokemonRevoData.RevoData[pokemonID]
                    local success, cid = filterDarwinEvoList(evoList)
                    if success then
                        hasFiltered = true
                        chosenId = cid
                    end
                end
                
                if hasFiltered and chosenId then
                    local monName = PokemonData.Pokemon[pokemonID] and PokemonData.Pokemon[pokemonID].name or "Pokemon"
                    local chosenName = PokemonData.Pokemon[chosenId] and PokemonData.Pokemon[chosenId].name or "Chosen candidate"
                    print(string.format("[RogueMon Streamer] - Darwinism applied to %s. Evolution target secretly locked to %s.", monName, chosenName))
                    detail = string.format("Darwinism ( Restricted %s's evolution pool to top 5 Darwinian candidates )", trim(monName))
                    
                    -- Record successful application to prevent future reruns
                    if leadMon and leadMon.personality then
                        local phex = string.format("0x%X_%d", leadMon.personality, leadMon.pokemonID or 0)
                        RoguemonStreamer.settings.persistent.evolutionFilteredPids = RoguemonStreamer.settings.persistent.evolutionFilteredPids or {}
                        RoguemonStreamer.settings.persistent.evolutionFilteredPids[phex] = true
                        RoguemonStreamer.saveSettings()
                    end
                else
                    print("[RogueMon Streamer] - Darwinism failed to filter: Fallback giving items")
                    if scale and scale >= 50 then
                        local fullRestoreId = Roguemon.ItemManager.getItemIdByName("Full Restore") or 19
                        local rareCandyId = Roguemon.ItemManager.getItemIdByName("Rare Candy") or 68
                        grantItem(fullRestoreId, 2)
                        grantItem(rareCandyId, 1)
                        detail = "Darwinism ( Failed -> +2 Full Restore, +1 Rare Candy )"
                    else
                        grantItem(ITEMS.HYPER_POTION, 1)
                        detail = "Darwinism ( Failed -> +1 Hyper Potion )"
                    end
                end
            else
                print(string.format("[RogueMon Streamer] - Darwinism: Species %d has no evolutions. Fallback giving items.", pokemonID))
                if scale and scale >= 50 then
                    local fullRestoreId = Roguemon.ItemManager.getItemIdByName("Full Restore") or 19
                    local rareCandyId = Roguemon.ItemManager.getItemIdByName("Rare Candy") or 68
                    grantItem(fullRestoreId, 2)
                    grantItem(rareCandyId, 1)
                    detail = "Darwinism ( Fully evolved -> +2 Full Restore, +1 Rare Candy )"
                else
                    grantItem(ITEMS.HYPER_POTION, 1)
                    detail = "Darwinism ( Fully evolved -> +1 Hyper Potion )"
                end
            end
        else
            if alreadyFiltered then
                print("[RogueMon Streamer] - Darwinism: Active Pokémon already has filtered evolutions. Fallback giving items.")
                if scale and scale >= 50 then
                    local fullRestoreId = Roguemon.ItemManager.getItemIdByName("Full Restore") or 19
                    local rareCandyId = Roguemon.ItemManager.getItemIdByName("Rare Candy") or 68
                    grantItem(fullRestoreId, 2)
                    grantItem(rareCandyId, 1)
                    detail = "Darwinism ( Already filtered -> +2 Full Restore, +1 Rare Candy )"
                else
                    grantItem(ITEMS.HYPER_POTION, 1)
                    detail = "Darwinism ( Already filtered -> +1 Hyper Potion )"
                end
            else
                print("[RogueMon Streamer] - Darwinism: No viewed Pokemon. Fallback giving items.")
                if scale and scale >= 50 then
                    local fullRestoreId = Roguemon.ItemManager.getItemIdByName("Full Restore") or 19
                    local rareCandyId = Roguemon.ItemManager.getItemIdByName("Rare Candy") or 68
                    grantItem(fullRestoreId, 2)
                    grantItem(rareCandyId, 1)
                    detail = "Darwinism ( No Pokemon viewed -> +2 Full Restore, +1 Rare Candy )"
                else
                    grantItem(ITEMS.HYPER_POTION, 1)
                    detail = "Darwinism ( No Pokemon viewed -> +1 Hyper Potion )"
                end
            end
        end
    elseif eventName == "Game Changer" then
        local btlCount = 1
        if scale and scale >= 50 then
            btlCount = math.floor(scale / 2)
        elseif scale and scale >= 20 then
            btlCount = 5 -- Milestone 20: 5 battles
        elseif scale and scale >= 10 then
            btlCount = 3 -- Milestone 10: 3 battles
        elseif scale and scale >= 5 and scale <= 9 then
            btlCount = 3 -- Milestone 5: 3 battles
        end
        
        local current = RoguemonStreamer.settings.persistent.gameChangerActive or 0
        RoguemonStreamer.settings.persistent.gameChangerActive = current + btlCount
        RoguemonStreamer.settings.persistent.gameChangerApplied = false
        RoguemonStreamer.saveSettings()
        
        detail = string.format("Game Changer ( Critical hit stage +2 for %d btl )", RoguemonStreamer.settings.persistent.gameChangerActive)
    elseif eventName == "Try Harder" then
        local btlCount = 1
        if scale and scale >= 50 then
            btlCount = math.floor(scale / 2)
        elseif scale and scale >= 20 then
            btlCount = 5 -- Milestone 20: 5 battles
        elseif scale and scale >= 10 then
            btlCount = 3 -- Milestone 10: 3 battles
        elseif scale and scale >= 5 and scale <= 9 then
            btlCount = 3 -- Milestone 5: 3 battles
        end
        
        local current = RoguemonStreamer.settings.persistent.tryHarderActive or 0
        RoguemonStreamer.settings.persistent.tryHarderActive = current + btlCount
        RoguemonStreamer.settings.persistent.tryHarderApplied = false
        RoguemonStreamer.saveSettings()
        
        detail = string.format("Try Harder ( Immune to stat lowering for %d btl )", RoguemonStreamer.settings.persistent.tryHarderActive)
    elseif eventName == "Let's Dance" then
        print("[RogueMon Streamer] - Triggering Let's Dance choice menu")
        RoguemonStreamer.ActiveLetsDanceRequest = {
            Username = "Twitch",
            IsCP = RoguemonStreamer.isChannelPointsExecution,
            SubCount = scale
        }
        detail = "Let's Dance"
    end
    refreshTracker()
    local finalMsg = "Good Event: " .. (detail or eventName)
    RoguemonStreamer.notifyStreamer(finalMsg, scale)
    return finalMsg
end

getPartyMonStats = function(partyIndex)
    if not GameSettings.pstats or Memory.readdword(GameSettings.pstats) == 0 then
        return nil
    end
    local partyAddress = GameSettings.pstats + (partyIndex - 1) * 100
    local stats = {
        hp = Memory.readword(partyAddress + 0x58),
        atk = Memory.readword(partyAddress + 0x5A),
        def = Memory.readword(partyAddress + 0x5C),
        spe = Memory.readword(partyAddress + 0x5E),
        spa = Memory.readword(partyAddress + 0x60),
        spd = Memory.readword(partyAddress + 0x62),
    }
    return stats
end

generateNature = function(partyIndex, scale, isGood)
    local stats = getPartyMonStats(partyIndex)
    if not stats or not stats.atk or stats.atk == 0 then
        local baseAtk, baseSpa, baseSpe, baseDef, baseSpd = 0, 0, 0, 0, 0
        local partyAddress = GameSettings.pstats + (partyIndex - 1) * 100
        local oldPID = Memory.readdword(partyAddress)
        local otid = Memory.readdword(partyAddress + 4)
        local oldMagic = Utils.bit_xor(oldPID, otid)
        local encSpecies = Memory.readdword(partyAddress + 0x20)
        local decrypted1 = Utils.bit_xor(encSpecies, oldMagic)
        local species = Utils.getbits(decrypted1, 0, 16)
        if species and species > 0 and PokemonData and PokemonData.Pokemon then
            local pkData = PokemonData.Pokemon[species]
            if pkData and pkData.baseStats then
                baseAtk = pkData.baseStats.atk or 0
                baseSpa = pkData.baseStats.spa or 0
                baseSpe = pkData.baseStats.spe or 0
                baseDef = pkData.baseStats.def or 0
                baseSpd = pkData.baseStats.spd or 0
            end
        end
        stats = { atk = baseAtk, spa = baseSpa, spe = baseSpe, def = baseDef, spd = baseSpd }
    end
    
    local neutralNatures = { 0, 6, 12, 18, 24 }

    if scale and scale >= 5 and scale <= 9 then
        if not isGood then
            -- Rule 6: always +def -spdef or +spdef -def
            return RoguemonStreamer.random(1, 2) == 1 and 9 or 21
        end
    elseif scale and scale >= 10 and scale < 50 then
        local curStats = stats or { atk = 0, spa = 0, spe = 0, def = 0, spd = 0 }
        if isGood then
            -- Rule 10: increase higher attack (if > speed) else speed; decrease higher defense
            local highestAttack = math.max(curStats.atk or 0, curStats.spa or 0)
            local speed = curStats.spe or 0
            local incStat = "spe"
            if highestAttack > speed then
                incStat = ((curStats.atk or 0) >= (curStats.spa or 0)) and "atk" or "spa"
            else
                incStat = "spe"
            end
            
            local decStat = "def"
            if (curStats.spd or 0) > (curStats.def or 0) then
                decStat = "spd"
            end
            
            if incStat == "atk" then
                return decStat == "def" and 1 or 4
            elseif incStat == "spa" then
                return decStat == "def" and 16 or 19
            else
                return decStat == "def" and 11 or 14
            end
        else
            -- Rule 19: decrease higher attack (if > speed) else speed; increase higher defense
            local highestAttack = math.max(curStats.atk or 0, curStats.spa or 0)
            local speed = curStats.spe or 0
            local decStat = "spe"
            if highestAttack > speed then
                decStat = ((curStats.atk or 0) >= (curStats.spa or 0)) and "atk" or "spa"
            else
                decStat = "spe"
            end
            
            local incStat = "def"
            if (curStats.spd or 0) > (curStats.def or 0) then
                incStat = "spd"
            end
            
            if incStat == "def" then
                if decStat == "atk" then return 5
                elseif decStat == "spa" then return 8
                else return 7
                end
            else
                if decStat == "atk" then return 20
                elseif decStat == "spa" then return 23
                else return 22
                end
            end
        end
    end

    if scale and scale >= 50 then
        local baseAtk = 0
        local baseSpa = 0
        local baseDef = 0
        local baseSpd = 0
        
        local partyAddress = GameSettings.pstats + (partyIndex - 1) * 100
        local oldPID = Memory.readdword(partyAddress)
        local otid = Memory.readdword(partyAddress + 4)
        local oldMagic = Utils.bit_xor(oldPID, otid)
        local encSpecies = Memory.readdword(partyAddress + 0x20)
        local decrypted1 = Utils.bit_xor(encSpecies, oldMagic)
        local species = Utils.getbits(decrypted1, 0, 16)
        
        if species and species > 0 and PokemonData and PokemonData.Pokemon then
            local pkData = PokemonData.Pokemon[species]
            if pkData and pkData.baseStats then
                baseAtk = pkData.baseStats.atk or 0
                baseSpa = pkData.baseStats.spa or 0
                baseDef = pkData.baseStats.def or 0
                baseSpd = pkData.baseStats.spd or 0
            end
        end
        
        local currentAtk = stats and stats.atk or 0
        local currentSpa = stats and stats.spa or 0
        local currentDef = stats and stats.def or 0
        local currentSpd = stats and stats.spd or 0
        
        local isPhysical = true
        if baseAtk > 0 or baseSpa > 0 then
            isPhysical = (baseAtk >= baseSpa)
        elseif currentAtk > 0 or currentSpa > 0 then
            isPhysical = (currentAtk >= currentSpa)
        end
        
        local isDefHigher = true
        if baseDef > 0 or baseSpd > 0 then
            isDefHigher = (baseDef > baseSpd)
        elseif currentDef > 0 or currentSpd > 0 then
            isDefHigher = (currentDef > currentSpd)
        end
        
        if isGood then
            -- Positive: Increase highest attack, decrease lowest attack
            if baseAtk ~= baseSpa or currentAtk ~= currentSpa then
                local highestAtkIsPhysical = true
                if baseAtk ~= baseSpa then
                    highestAtkIsPhysical = (baseAtk > baseSpa)
                else
                    highestAtkIsPhysical = (currentAtk > currentSpa)
                end
                return highestAtkIsPhysical and 3 or 15 -- 3: Adamant (+Atk, -SpA), 15: Modest (+SpA, -Atk)
            else
                -- If they are equal, do + to a random attack stat, and - to the highest defense stat
                local plusAtk = (RoguemonStreamer.random(1, 2) == 1)
                local minusDef = true
                if baseDef ~= baseSpd then
                    minusDef = (baseDef > baseSpd)
                elseif currentDef ~= currentSpd then
                    minusDef = (currentDef > currentSpd)
                else
                    minusDef = (RoguemonStreamer.random(1, 2) == 1)
                end
                
                if plusAtk then
                    return minusDef and 1 or 4 -- 1: Lonely (+Atk, -Def), 4: Naughty (+Atk, -SpD)
                else
                    return minusDef and 16 or 19 -- 16: Mild (+SpA, -Def), 19: Rash (+SpA, -SpD)
                end
            end
        else
            -- Rule 3: opposite of positive 50
            if baseAtk ~= baseSpa or currentAtk ~= currentSpa then
                local highestAtkIsPhysical = true
                if baseAtk ~= baseSpa then
                    highestAtkIsPhysical = (baseAtk > baseSpa)
                else
                    highestAtkIsPhysical = (currentAtk > currentSpa)
                end
                return highestAtkIsPhysical and 15 or 3 -- Modest (-Atk, +SpA) if physical; Adamant (-SpA, +Atk) if special
            else
                if isDefHigher then
                    return isPhysical and 5 or 8 -- 5: Bold (+Def, -Atk), 8: Impish (+Def, -SpA)
                else
                    return isPhysical and 20 or 23 -- 20: Calm (+SpD, -Atk), 23: Careful (+SpD, -SpA)
                end
            end
        end
    end

    if not stats then
        if isGood then
            local goodNatures = { 1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 13, 14, 15, 16, 17, 19, 20, 21, 22, 23 }
            return goodNatures[RoguemonStreamer.random(#goodNatures)]
        else
            return RoguemonStreamer.random(0, 24)
        end
    end

    local nonNeutralNatures = {
        { id = 1,  inc = "atk", dec = "def" },
        { id = 2,  inc = "atk", dec = "spe" },
        { id = 3,  inc = "atk", dec = "spa" },
        { id = 4,  inc = "atk", dec = "spd" },
        { id = 5,  inc = "def", dec = "atk" },
        { id = 7,  inc = "def", dec = "spe" },
        { id = 8,  inc = "def", dec = "spa" },
        { id = 9,  inc = "def", dec = "spd" },
        { id = 10, inc = "spe", dec = "atk" },
        { id = 11, inc = "spe", dec = "def" },
        { id = 13, inc = "spe", dec = "spa" },
        { id = 14, inc = "spe", dec = "spd" },
        { id = 15, inc = "spa", dec = "atk" },
        { id = 16, inc = "spa", dec = "def" },
        { id = 17, inc = "spa", dec = "spe" },
        { id = 19, inc = "spa", dec = "spd" },
        { id = 20, inc = "spd", dec = "atk" },
        { id = 21, inc = "spd", dec = "def" },
        { id = 22, inc = "spd", dec = "spe" },
        { id = 23, inc = "spd", dec = "spa" },
    }

    -- Sort natures by score = stats[inc] - stats[dec]
    -- scoreA < scoreB means index 1 has the worst/most detrimental nature
    -- and index 20 has the best/most beneficial nature.
    table.sort(nonNeutralNatures, function(a, b)
        local scoreA = (stats[a.inc] or 0) - (stats[a.dec] or 0)
        local scoreB = (stats[b.inc] or 0) - (stats[b.dec] or 0)
        return scoreA < scoreB
    end)

    if isGood then
        -- Good but not OP natures (indices 14 to 17)
        local idx = RoguemonStreamer.random(14, 17)
        return nonNeutralNatures[idx].id
    else
        -- Neutral or slightly bad nature (neutral natures + indices 4 to 7)
        local candidates = {}
        for _, id in ipairs(neutralNatures) do
            table.insert(candidates, id)
        end
        for idx = 4, 7 do
            table.insert(candidates, nonNeutralNatures[idx].id)
        end
        return candidates[RoguemonStreamer.random(#candidates)]
    end
end

generateAbility = function(scale, isGood)
    if not RoguemonStreamer.abilityPools then
        RoguemonStreamer.loadAbilityPools()
    end

    local tier = 5
    if scale >= 50 then
        tier = 50
    elseif scale >= 20 then
        tier = 20
    elseif scale >= 10 then
        tier = 10
    end
    
    local poolName = "Sub" .. tier .. (isGood and "Pos" or "Neg")
    local pool = RoguemonStreamer.abilityPools and RoguemonStreamer.abilityPools[poolName]
    
    if pool and #pool > 0 then
        local totalWeight = 0
        for _, entry in ipairs(pool) do
            totalWeight = totalWeight + entry.weight
        end
        if totalWeight > 0 then
            local randVal = (RoguemonStreamer.random(1, 100000) / 100000) * totalWeight
            local currentSum = 0
            for _, entry in ipairs(pool) do
                currentSum = currentSum + entry.weight
                if randVal <= currentSum then
                    return entry.id
                end
            end
            return pool[#pool].id
        end
    end

    -- Fallback to vanilla lists if pool is empty or failed to load
    local detrimentals = { "Truant", "Slow Start", "Defeatist", "Klutz", "Stall", "Normalize" }
    local neutrals = {
        "Run Away", "Honey Gather", "Illuminate", "Ball Fetch", "Forecast",
        "Minus", "Plus", "Receiver", "Telepathy", "Symbiosis"
    }
    local ops = {
        "Huge Power", "Pure Power", "Wonder Guard", "Speed Boost", "Magic Guard",
        "Fur Coat", "Ice Scales", "Contrary", "Regenerator", "Simple",
        "Parental Bond", "As One-SR", "As One-IR", "Chilling Neigh", "Grim Neigh",
        "Moxie", "Soul-Heart", "Beast Boost", "Intrepid Sword", "Dauntless Shield",
        "Sword of Ruin", "Beads of Ruin", "Libero", "Protean", "Unaware",
        "Gale Wings", "Adaptability", "Prankster", "Gorilla Tactics",
        -- Type Immunities
        "Levitate", "Flash Fire", "Volt Absorb", "Water Absorb", "Dry Skin",
        "Storm Drain", "Sap Sipper", "Motor Drive", "Earth Eater", "Well-Baked Body",
        "Lightning Rod",
        -- Type Converters (-ate / -ize)
        "Pixilate", "Aerilate", "Refrigerate", "Galvanize"
    }
    local goods = {
        "Levitate", "Guts", "Technician", "Swift Swim", "Poison Heal",
        "Toxic Boost", "Quick Feet", "Sheer Force", "Tough Claws", "Sharpness",
        "Strong Jaw", "Mega Launcher", "Iron Fist", "Multiscale", "Shadow Shield",
        "Marvel Scale", "Natural Cure", "Sturdy", "Serene Grace", "Clear Body",
        "White Smoke", "Hyper Cutter", "Infiltrator", "Compound Eyes", "Defiant",
        "Competitive", "Justified", "Sap Sipper", "Motor Drive", "Volt Absorb",
        "Lightning Rod", "Flash Fire", "Water Absorb", "Dry Skin", "Storm Drain",
        "Rain Dish", "Shed Skin", "Overgrow", "Blaze", "Torrent", "Shield Dust",
        "Scrappy", "Inner Focus", "Tinted Lens", "Super Luck", "Reckless",
        "Rock Head", "Sand Stream", "Drizzle", "Drought", "Snow Warning", "Cloud Nine",
        "Pickup", "Damp", "Anticipation", "Forewarn", "Frisk", "Keen Eye",
        "Steadfast", "Big Pecks", "Gluttony", "Oblivious"
    }

    local function resolveIds(namesList)
        local resolved = {}
        local total = AbilityData.getTotal()
        for id = 1, total do
            local ability = AbilityData.Abilities[id]
            if ability and ability.name then
                local aName = ability.name:lower():gsub("%s+", ""):gsub("%-+", "")
                for _, target in ipairs(namesList) do
                    local tName = target:lower():gsub("%s+", ""):gsub("%-+", "")
                    if aName == tName then
                        table.insert(resolved, id)
                        break
                    end
                end
            end
        end
        return resolved
    end

    local targetList
    if isGood then
        if scale >= 50 then
            targetList = resolveIds(ops)
        else
            targetList = resolveIds(goods)
        end
    else
        if scale >= 50 then
            targetList = resolveIds(detrimentals)
        else
            targetList = resolveIds(neutrals)
            if #targetList == 0 then
                targetList = resolveIds(detrimentals)
            end
        end
    end

    if #targetList > 0 then
        return targetList[RoguemonStreamer.random(#targetList)]
    else
        return RoguemonStreamer.random(1, AbilityData.getTotal())
    end
end

local function getTypeWeaknesses(t1, t2)
    local t1Name = PokemonData.TypeIndexMap[t1]
    local t2Name = PokemonData.TypeIndexMap[t2]
    if not t1Name then return {}, {} end
    
    local types = { "normal", "fighting", "flying", "poison", "ground", "rock", "bug", "ghost", "steel", "fire", "water", "grass", "electric", "psychic", "ice", "dragon", "dark", "fairy" }
    local x4_weak = {}
    local x2_weak = {}
    
    for _, atkType in ipairs(types) do
        local eff1 = 1
        if MoveData.TypeToEffectiveness[atkType] and MoveData.TypeToEffectiveness[atkType][t1Name] then
            eff1 = MoveData.TypeToEffectiveness[atkType][t1Name]
        end
        local eff2 = 1
        if t2Name and t2Name ~= t1Name and t2Name ~= "unknown" and t2Name ~= "empty" then
            if MoveData.TypeToEffectiveness[atkType] and MoveData.TypeToEffectiveness[atkType][t2Name] then
                eff2 = MoveData.TypeToEffectiveness[atkType][t2Name]
            end
        end
        local totalEff = eff1 * eff2
        if totalEff >= 4 then
            table.insert(x4_weak, atkType)
        elseif totalEff == 2 then
            table.insert(x2_weak, atkType)
        end
    end
    return x4_weak, x2_weak
end

generateTyping = function(scale, isGood)
    local allTypeIds = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 17, 18, 19 }
    local opPool, goodPool, badPool, neutralPool = {}, {}, {}, {}

    if MoveData and MoveData.TypeToEffectiveness then
        -- Compute full defensive stats for a type combination
        local function getStats(typeId1, typeId2)
            local t1 = string.lower(PokemonData.TypeIndexMap[typeId1] or "")
            local t2 = string.lower(PokemonData.TypeIndexMap[typeId2] or "")
            local mono = (typeId1 == typeId2)
            local x0, x025, x05, x2, x4 = 0, 0, 0, 0, 0
            for _, eff in pairs(MoveData.TypeToEffectiveness) do
                local m = (eff[t1] or 1)
                if not mono then m = m * (eff[t2] or 1) end
                if     m == 0  then x0   = x0   + 1
                elseif m < 0.3 then x025 = x025 + 1   -- 0.25
                elseif m < 0.9 then x05  = x05  + 1   -- 0.5
                elseif m > 3.5 then x4   = x4   + 1   -- 4
                elseif m > 1.5 then x2   = x2   + 1   -- 2
                end
            end
            return x0, x025, x05, x2, x4
        end

        -- Iterate all mono (i==j) and dual (i<j) type combinations
        for i = 1, #allTypeIds do
            for j = i, #allTypeIds do
                local t1, t2 = allTypeIds[i], allTypeIds[j]
                local x0, x025, x05, x2, x4 = getStats(t1, t2)
                local pureRes  = x025 + x05        -- x0.5 + x0.25 only
                local totalDef = x0 + x025 + x05   -- all defensive (res + immunity)
                -- Store _x2 and _x4 for sub-pool filtering at selection time
                local entry = { t1, t2, _x2 = x2, _x4 = x4 }

                if x4 >= 1 then
                    -- badPool: at least 1 x4 weakness
                    table.insert(badPool, entry)
                elseif x2 <= 2 and pureRes >= 2 and x0 >= 1 then
                    -- opPool: no x4, max 2 x2, ≥2 resistances (x0.5/x0.25), ≥1 immunity
                    table.insert(opPool, entry)
                elseif x2 <= 3 and totalDef >= 3 then
                    -- goodPool: no x4, max 3 x2, ≥3 combined defensive (res+imm)
                    table.insert(goodPool, entry)
                else
                    -- neutralPool: everything else
                    table.insert(neutralPool, entry)
                end
            end
        end
    else
        -- Fallback: original hardcoded lists (used if MoveData not yet loaded)
        opPool     = { {9,19},{9,3},{12,5},{9,17},{9,8},{8,1},{12,19},{14,3},{9,12},{17,19} }
        goodPool   = { {12,17},{11,17},{12,14},{12,3},{11,9},{14,9},{13,9},{5,9},{8,18},{19,3},{5,3},{14,16} }
        badPool    = { {6,16},{13,16},{13,7},{6,13},{16,7},{15,13},{16,5} }
        neutralPool= { {1,1},{7,7},{16,16},{15,15},{13,13},{6,6},{16,15},{6,12},{6,5},{7,3},{11,6},{1,3},{13,18},{11,7} }
    end

    -- Select from the appropriate pool based on isGood and scale
    local pool = {}
    if isGood then
        if scale >= 50 then
            -- Milestone +50: opPool filtered to x2 <= 1 (the absolute best typings)
            for _, e in ipairs(opPool) do
                if (e._x2 or 0) <= 1 then table.insert(pool, e) end
            end
            if #pool == 0 then pool = opPool end  -- fallback if filter too strict
        elseif scale >= 10 then
            -- Milestone +10 to +49: opPool + goodPool combined
            for _, v in ipairs(opPool)   do table.insert(pool, v) end
            for _, v in ipairs(goodPool) do table.insert(pool, v) end
        else
            -- Milestone +5 to +9: goodPool only
            pool = goodPool
        end
    else
        if scale >= 50 then
            -- Milestone -50: badPool filtered to x4 >= 2 (the absolute worst typings)
            for _, e in ipairs(badPool) do
                if (e._x4 or 0) >= 2 then table.insert(pool, e) end
            end
            if #pool == 0 then pool = badPool end  -- fallback if filter too strict
        elseif scale >= 10 then
            -- Milestone -10 to -49: badPool only
            pool = badPool
        else
            -- Milestone -5 to -9: badPool + neutralPool combined
            for _, v in ipairs(badPool)     do table.insert(pool, v) end
            for _, v in ipairs(neutralPool) do table.insert(pool, v) end
        end
    end

    if #pool == 0 then
        if isGood then return 8, 1 else return 6, 16 end
    end

    local choice = pool[RoguemonStreamer.random(#pool)]
    return choice[1], choice[2]
end

-- NEGATIVE EVENT EXECUTION
function RoguemonStreamer.executeNegativeEvent(eventName, scale)
    RoguemonStreamer.updateItemIds()
    local activeIdx = 1
    local partyAddress = GameSettings.pstats + (activeIdx - 1) * 100
    local inBattle = Battle.inActiveBattle()
    local p = RoguemonStreamer.settings.persistent
    print(string.format("[RogueMon Streamer] Executing Negative Event: '%s' (Scale: %d, Active Party Index: %d)", eventName, scale, activeIdx))

    local battleSlot = RoguemonStreamer.getBattleSlot(activeIdx)
    local battleMonsAddress = nil
    if battleSlot ~= nil then
        battleMonsAddress = GameSettings.gBattleMons + (battleSlot * (GameSettings.sizeofBattlePokemon or 0x58))
    end

    local detail = nil
    if eventName == "Inflict Status" or eventName == "Altera status" or eventName == "Inflict status" then
        -- Inflict Status (4:sleep, 8:poison, 16:burn, 32:freeze, 64:paralysis)
        local statuses = { 4, 8, 16, 32, 64 } -- sleep, poison, burn, freeze, paralysis
        local randomStatus = statuses[RoguemonStreamer.random(#statuses)]
        local statusNames = { [4] = "Sleep", [8] = "Poison", [16] = "Burn", [32] = "Freeze", [64] = "Paralysis" }
        local statusName = statusNames[randomStatus] or "Status"

        local currentStatus = Memory.readdword(partyAddress + 0x50)
        local curHP = Memory.readword(partyAddress + 0x54 + 2)
        local isAnyActive = RoguemonStreamer.isAnyNegativeEventActive()
        if not inBattle or isAnyActive or currentStatus > 0 or curHP <= 0 then
            RoguemonStreamer.settings.persistent.queuedStatuses = RoguemonStreamer.settings.persistent.queuedStatuses or {}
            table.insert(RoguemonStreamer.settings.persistent.queuedStatuses, randomStatus)
            RoguemonStreamer.saveSettings()
            print(string.format("[RogueMon Streamer] - Queued Status %s (active status %d is already present or fainted)", statusName, currentStatus))
            detail = string.format("Inflict status ( %s )", trim(statusName))
        else
            Memory.writedword(partyAddress + 0x50, randomStatus)
            if battleMonsAddress ~= nil then
                Memory.writedword(battleMonsAddress + getBattleStatus1Offset(), randomStatus)
            end
            print(string.format("[RogueMon Streamer] - Inflicted status %s on active Pokemon", statusName))
            detail = string.format("Inflict status ( %s )", trim(statusName))
        end
    elseif eventName == "Disable Move" then
        local turns = 3
        if scale and scale >= 5 and scale <= 9 then
            turns = 5
        elseif scale and scale > 1 then
            turns = math.floor(scale / 2)
            if turns < 1 then turns = 1 end
        end
        if RoguemonStreamer.isChannelPointsExecution then
            turns = 3
        end
        detail = RoguemonStreamer.queueOrActivateMoveEvent("Disable Move", turns)
    elseif eventName == "Stat Debuff (Power)" or eventName == "Power Debuff" then
        local stat = "atk"
        local stats = getPartyMonStats(activeIdx)
        if stats then
            local atkVal = stats.atk or 0
            local spaVal = stats.spa or 0
            if spaVal > atkVal then
                stat = "spa"
            elseif atkVal > spaVal then
                stat = "atk"
            else
                stat = RoguemonStreamer.random(1, 2) == 1 and "atk" or "spa"
            end
        else
            stat = RoguemonStreamer.random(1, 2) == 1 and "atk" or "spa"
        end
        local duration = scale
        if RoguemonStreamer.isChannelPointsExecution then
            duration = 1
        end
        RoguemonStreamer.addStatBuff(stat, -1, duration)
        local statName = STAT_NAMES[stat] or stat
        local btlStr = duration == 1 and "btl" or "btls"
        print(string.format("[RogueMon Streamer] - Applied persistent Power Debuff: %s -1 stage for %d battles", stat, duration))
        detail = string.format("Power Debuff ( %s -1 ) for %d %s", trim(STAT_LABELS[stat] or stat), duration, btlStr)
    elseif eventName == "Stat Debuff (Speed)" or eventName == "Speed Debuff" then
        local stat = "spe"
        local duration = scale
        if RoguemonStreamer.isChannelPointsExecution then
            duration = 1
        end
        RoguemonStreamer.addStatBuff(stat, -1, duration)
        local statName = STAT_NAMES[stat] or stat
        local btlStr = duration == 1 and "btl" or "btls"
        print(string.format("[RogueMon Streamer] - Applied persistent Speed Debuff: %s -1 stage for %d battles", stat, duration))
        detail = string.format("Speed Debuff ( %s -1 ) for %d %s", trim(STAT_LABELS[stat] or stat), duration, btlStr)
    elseif eventName == "PP Cut" then
        local moveName = RoguemonStreamer.cutSingleRandomMovePP(activeIdx, 0.5)
        if moveName then
            print(string.format("[RogueMon Streamer] - Halved PP of move slot: %s", moveName))
            detail = string.format("PP Cut ( %s halved )", trim(moveName))
        else
            print("[RogueMon Streamer] - PP Cut failed: no moves to cut")
            detail = "PP Cut ( Failed )"
        end
    elseif eventName == "Temp Type Change" then
        detail = RoguemonStreamer.queueOrActivateTempTypeChange(scale)
    elseif eventName == "Remove Healing Item" then
        local pool = { ITEMS.POTION, ITEMS.SUPER_POTION, ITEMS.FRESH_WATER, ITEMS.ENERGY_POWDER, ITEMS.SODA_POP, ITEMS.SWEET_HEART, ITEMS.BERRY_JUICE }
        local removedId = RoguemonStreamer.removeRandomItemFromCategory(pool)
        if removedId then
            local removedName = (Resources and Resources.Game and Resources.Game.ItemNames and Resources.Game.ItemNames[removedId]) or "Healing Item"
            print(string.format("[RogueMon Streamer] - Removed healing item: %s (ID %d)", removedName, removedId))
            detail = string.format("Remove Healing Item ( %s )", trim(removedName))
        else
            print("[RogueMon Streamer] - Remove Healing Item failed: none possessed")
            detail = "Remove Healing Item ( None possessed )"
        end
    elseif eventName == "Remove Status Item" then
        local pool = {
            ITEMS.AWAKENING, ITEMS.CHESTO_BERRY, ITEMS.ANTIDOTE, ITEMS.PECHA_BERRY,
            ITEMS.CHERI_BERRY, ITEMS.PARALYZE_HEAL, ITEMS.MENTAL_HERB, ITEMS.ASPEAR_BERRY,
            ITEMS.ICE_HEAL, ITEMS.PERSIM_BERRY, ITEMS.BURN_HEAL, ITEMS.RAWST_BERRY
        }
        local removedId = RoguemonStreamer.removeRandomItemFromCategory(pool)
        if removedId then
            local removedName = (Resources and Resources.Game and Resources.Game.ItemNames and Resources.Game.ItemNames[removedId]) or "Status Item"
            print(string.format("[RogueMon Streamer] - Removed status item: %s (ID %d)", removedName, removedId))
            detail = string.format("Remove Status Item ( %s )", trim(removedName))
        else
            print("[RogueMon Streamer] - Remove Status Item failed: none possessed")
            detail = "Remove Status Item ( None possessed )"
        end
    elseif eventName == "Remove Big Healing Item" then
        if scale >= 50 then
            local pool = { ITEMS.MAX_POTION, ITEMS.FULL_RESTORE }
            print("[RogueMon Streamer] - Removing Max Potion or Full Restore (50+ sub choice)")
            local deficit, removedIds = RoguemonStreamer.removeItemsFromCategoryWithDeficit("big_healing", pool, 1)
            local removedName = "None"
            if removedIds and #removedIds > 0 then
                local itemId = removedIds[1]
                removedName = (Resources and Resources.Game and Resources.Game.ItemNames and Resources.Game.ItemNames[itemId]) or "Big Healing Item"
            end
            if deficit > 0 then
                removedName = removedName .. " - Debt"
            end
            detail = string.format("Remove Big Healing Item ( %s )", trim(removedName))
        elseif scale >= 10 then
            local pool = { ITEMS.LEMONADE, ITEMS.ENERGY_ROOT, ITEMS.MOOMOO_MILK, ITEMS.HYPER_POTION, ITEMS.MAX_POTION, ITEMS.FULL_RESTORE }
            print("[RogueMon Streamer] - Removing big healing item (10+ sub choice)")
            local deficit, removedIds = RoguemonStreamer.removeItemsFromCategoryWithDeficit("big_healing", pool, 1)
            local removedName = "None"
            if removedIds and #removedIds > 0 then
                local itemId = removedIds[1]
                removedName = (Resources and Resources.Game and Resources.Game.ItemNames and Resources.Game.ItemNames[itemId]) or "Big Healing Item"
            end
            if deficit > 0 then
                removedName = removedName .. " - Debt"
            end
            detail = string.format("Remove Big Healing Item ( %s )", trim(removedName))
        else
            -- 5-9 subs: no debt
            local pool = { ITEMS.LEMONADE, ITEMS.ENERGY_ROOT, ITEMS.MOOMOO_MILK, ITEMS.HYPER_POTION }
            local removedId = RoguemonStreamer.removeRandomItemFromCategory(pool)
            if removedId then
                local removedName = (Resources and Resources.Game and Resources.Game.ItemNames and Resources.Game.ItemNames[removedId]) or "Big Healing Item"
                print(string.format("[RogueMon Streamer] - Removed big healing item: %s (ID %d)", removedName, removedId))
                detail = string.format("Remove Big Healing Item ( %s )", trim(removedName))
            else
                -- Try to remove 2 small healing items
                local smallPool = { ITEMS.POTION, ITEMS.SUPER_POTION, ITEMS.ENERGY_POWDER, ITEMS.SODA_POP, ITEMS.SWEET_HEART, ITEMS.BERRY_JUICE, ITEMS.FRESH_WATER }
                local removedIds = {}
                for i = 1, 2 do
                    local id = RoguemonStreamer.removeRandomItemFromCategory(smallPool)
                    if id then table.insert(removedIds, id) end
                end
                if #removedIds > 0 then
                    local names = {}
                    for _, id in ipairs(removedIds) do
                        local name = (Resources and Resources.Game and Resources.Game.ItemNames and Resources.Game.ItemNames[id]) or "Item"
                        table.insert(names, name)
                    end
                    local removedStr = table.concat(names, ", ")
                    print(string.format("[RogueMon Streamer] - Removed small healing items: %s", removedStr))
                    detail = string.format("Remove Big Healing Item ( None possessed -> Removed small: %s )", trim(removedStr))
                else
                    print("[RogueMon Streamer] - Remove Big Healing Item failed: no items possessed")
                    detail = "Remove Big Healing Item ( None possessed )"
                end
            end
        end
    elseif eventName == "Remove Utility Item" or eventName == "Remove Utility Items" then
        if scale >= 50 then
            local pool = { ITEMS.RARE_CANDY, ITEMS.PP_MAX, ITEMS.MAX_ELIXIR }
            print("[RogueMon Streamer] - Removing 2 valuable utility items (50+ sub choice)")
            local deficit, removedIds = RoguemonStreamer.removeItemsFromCategoryWithDeficit("utility_valuable", pool, 2)
            local removedNames = {}
            if removedIds and #removedIds > 0 then
                for _, itemId in ipairs(removedIds) do
                    local name = (Resources and Resources.Game and Resources.Game.ItemNames and Resources.Game.ItemNames[itemId]) or "Item"
                    table.insert(removedNames, name)
                end
            end
            local removedStr = #removedNames > 0 and table.concat(removedNames, ", ") or "None"
            if deficit > 0 then
                removedStr = removedStr .. " - Debt"
            end
            detail = string.format("Remove Utility Items ( %s )", trim(removedStr))
        elseif scale >= 10 then
            local pool = { ITEMS.RARE_CANDY, ITEMS.ETHER, ITEMS.MAX_ETHER, ITEMS.ELIXIR, ITEMS.MAX_ELIXIR, ITEMS.PP_MAX, ITEMS.PP_UP }
            print("[RogueMon Streamer] - Removing 2 valuable utility items (10+ sub choice)")
            local deficit, removedIds = RoguemonStreamer.removeItemsFromCategoryWithDeficit("utility_valuable", pool, 2)
            local removedNames = {}
            if removedIds and #removedIds > 0 then
                for _, itemId in ipairs(removedIds) do
                    local name = (Resources and Resources.Game and Resources.Game.ItemNames and Resources.Game.ItemNames[itemId]) or "Item"
                    table.insert(removedNames, name)
                end
            end
            local removedStr = #removedNames > 0 and table.concat(removedNames, ", ") or "None"
            if deficit > 0 then
                removedStr = removedStr .. " - Debt"
            end
            detail = string.format("Remove Utility Items ( %s )", trim(removedStr))
        else
            -- 5-9 subs: remove 1 item, no debt
            local pool = { ITEMS.RARE_CANDY, ITEMS.ETHER, ITEMS.MAX_ETHER, ITEMS.ELIXIR, ITEMS.MAX_ELIXIR, ITEMS.PP_MAX, ITEMS.PP_UP }
            local removedId = RoguemonStreamer.removeRandomItemFromCategory(pool)
            if removedId then
                local removedName = (Resources and Resources.Game and Resources.Game.ItemNames and Resources.Game.ItemNames[removedId]) or "Utility Item"
                print(string.format("[RogueMon Streamer] - Removed utility item: %s (ID %d)", removedName, removedId))
                detail = string.format("Remove Utility Item ( %s )", trim(removedName))
            else
                print("[RogueMon Streamer] - Remove Utility Item failed: none possessed")
                detail = "Remove Utility Item ( None possessed )"
            end
        end
    elseif eventName == "Stat Debuff" then
        local statKeys = { "atk", "def", "spe", "spa", "spd", "acc", "eva" }
        local stat = statKeys[RoguemonStreamer.random(1, #statKeys)]
        local duration = scale
        if scale and scale >= 5 and scale <= 9 then
            duration = 5
        end
        if RoguemonStreamer.isChannelPointsExecution then
            duration = 1
        end
        RoguemonStreamer.addStatBuff(stat, -1, duration)
        local statName = STAT_NAMES[stat] or stat
        local btlStr = duration == 1 and "btl" or "btls"
        print(string.format("[RogueMon Streamer] - Applied persistent Stat Debuff: %s -1 stage for %d battles", stat, duration))
        detail = string.format("Stat Debuff ( %s -1 ) for %d %s", trim(STAT_LABELS[stat] or stat), duration, btlStr)
    elseif eventName == "PP Deplete" then
        if scale >= 50 then
            print("[RogueMon Streamer] - Completely depleting PP of active Pokemon's moves to 0")
            RoguemonStreamer.cutPP(activeIdx, 0)
            detail = "PP Deplete ( 0 PP )"
        elseif scale >= 10 then
            print("[RogueMon Streamer] - Halving PP of active Pokemon's moves")
            RoguemonStreamer.cutPP(activeIdx, 0.5)
            detail = "PP Deplete ( Half PP )"
        else
            print("[RogueMon Streamer] - Reducing PP of active Pokemon's moves by 20%")
            RoguemonStreamer.cutPP(activeIdx, 0.8)
            detail = "PP Deplete ( -20% PP )"
        end
    elseif eventName == "Permanent Type Change" then
        local leadMon = Battle.getViewedPokemon(true)
        if leadMon and leadMon.personality then
            local personalityHex = string.format("0x%X", leadMon.personality)
            RoguemonStreamer.settings.alteredTypes = RoguemonStreamer.settings.alteredTypes or {}
            local t1, t2 = generateTyping(scale, false)
            RoguemonStreamer.settings.alteredTypes[personalityHex] = { t1, t2 }
            RoguemonStreamer.saveSettings()
            
            if battleSlot ~= nil then
                RoguemonStreamer.writeAlteredTypesToBattle(battleSlot, t1, t2)
            end
            local t1Name = PokemonData.TypeIndexMap[t1] or "Unknown"
            local t2Name = PokemonData.TypeIndexMap[t2] or "Unknown"
            print(string.format("[RogueMon Streamer] - Permanently changed viewed Pokemon (personality: %s) types to %s/%s (IDs: %d/%d)", personalityHex, t1Name, t2Name, t1, t2))
            local typingStr = (t1Name == t2Name) and t1Name or (t1Name .. "/" .. t2Name)
            detail = string.format("Permanent Type Change ( %s )", trim(typingStr))
        else
            print("[RogueMon Streamer] - Permanent Type Change failed: No viewed Pokemon found")
            detail = "Permanent Type Change ( Failed )"
        end
    elseif eventName == "Permanent Nature Change" then
        local targetNature = generateNature(activeIdx, scale, false)
        RoguemonStreamer.changePokemonPersonality(activeIdx, targetNature, nil)
        local natureNames = {
            [0] = "Hardy", [1] = "Lonely", [2] = "Brave", [3] = "Adamant", [4] = "Naughty",
            [5] = "Bold", [6] = "Docile", [7] = "Relaxed", [8] = "Impish", [9] = "Lax",
            [10] = "Timid", [11] = "Hasty", [12] = "Serious", [13] = "Jolly", [14] = "Naive",
            [15] = "Modest", [16] = "Mild", [17] = "Quiet", [18] = "Bashful", [19] = "Rash",
            [20] = "Calm", [21] = "Gentle", [22] = "Sassy", [23] = "Careful", [24] = "Quirky"
        }
        local natureName = natureNames[targetNature] or "Unknown"
        print(string.format("[RogueMon Streamer] - Permanently changed Pokemon nature to %s (ID: %d)", natureName, targetNature))
        detail = string.format("Permanent Nature Change ( %s )", trim(natureName))
    elseif eventName == "Permanent Ability Change" then
        local leadMon = Battle.getViewedPokemon(true)
        if leadMon and leadMon.personality then
            local personalityHex = string.format("0x%X", leadMon.personality)
            local newAbilityId = generateAbility(scale, false)
            RoguemonStreamer.settings.alteredAbilities = RoguemonStreamer.settings.alteredAbilities or {}
            RoguemonStreamer.settings.alteredAbilities[personalityHex] = newAbilityId
            RoguemonStreamer.saveSettings()
            
            if battleMonsAddress ~= nil then
                local abilityOffset = RoguemonStreamer.getBattleAbilityOffset()
                Memory.writeword(battleMonsAddress + abilityOffset, newAbilityId)
            end
            
            local abilityName = (AbilityData.Abilities[newAbilityId] or {}).name or "Unknown"
            print(string.format("[RogueMon Streamer] - Permanently changed Pokemon (personality: %s) ability to %s (ID: %d)", personalityHex, abilityName, newAbilityId))
            detail = string.format("Permanent Ability Change ( %s )", trim(abilityName))
        else
            print("[RogueMon Streamer] - Permanent Ability Change failed: No viewed Pokemon found")
            detail = "Permanent Ability Change ( Failed )"
        end
    elseif eventName == "Remove Big Healing Item" then
        local bigHeals = { ITEMS.HYPER_POTION, ITEMS.MAX_POTION, ITEMS.FULL_RESTORE }
        print("[RogueMon Streamer] - Removing one big healing item from category")
        local deficit, removedIds = RoguemonStreamer.removeItemsFromCategoryWithDeficit("big_healing", bigHeals, 1)
        local removedName = "None"
        if removedIds and #removedIds > 0 then
            local itemId = removedIds[1]
            removedName = (Resources and Resources.Game and Resources.Game.ItemNames and Resources.Game.ItemNames[itemId]) or "Big Healing Item"
        end
        if deficit > 0 then
            removedName = removedName .. " - Debt"
        end
        detail = string.format("Remove Big Healing Item ( %s )", trim(removedName))
    elseif eventName == "Remove Utility Items" then
        local utilityItems = { ITEMS.RARE_CANDY, ITEMS.ETHER, ITEMS.MAX_ETHER, ITEMS.ELIXIR, ITEMS.MAX_ELIXIR }
        print("[RogueMon Streamer] - Removing two utility items from category")
        local deficit, removedIds = RoguemonStreamer.removeItemsFromCategoryWithDeficit("utility_valuable", utilityItems, 2)
        local removedNames = {}
        if removedIds and #removedIds > 0 then
            for _, itemId in ipairs(removedIds) do
                local name = (Resources and Resources.Game and Resources.Game.ItemNames and Resources.Game.ItemNames[itemId]) or "Item"
                table.insert(removedNames, name)
            end
        end        local removedStr = #removedNames > 0 and table.concat(removedNames, ", ") or "None"
        if deficit > 0 then
            removedStr = removedStr .. " - Debt"
        end
        detail = string.format("Remove Utility Items ( %s )", trim(removedStr))
    elseif eventName == "Overwhelmed" then
        local curHPOffset = GameSettings.pokemonCurHPOffset or 0x56
        local maxHPOffset = GameSettings.offsetPokemonStatsMaxHpAtk or 0x58
        local curHP = Memory.readword(partyAddress + curHPOffset)
        
        local dmgPercent = (scale == 1) and 5 or scale
        local hpDeductPercent = math.min(90, dmgPercent) / 100
        local damage = math.floor(curHP * hpDeductPercent)
        local newHP = math.max(1, curHP - damage)
        Memory.writeword(partyAddress + curHPOffset, newHP)
        if battleMonsAddress ~= nil then
            local hpOffset = GameSettings.pokemonBattleHpOffset or 0x28
            Memory.writeword(battleMonsAddress + hpOffset, newHP)
        end

        local duration = 1
        if RoguemonStreamer.isChannelPointsExecution then
            duration = 1
        elseif scale == 1 then
            duration = 1
        elseif scale >= 50 then
            duration = math.floor(scale / 2) -- Milestone 50: 25 battles
        elseif scale >= 20 then
            duration = 10 -- Milestone 20: 10 battles
        elseif scale >= 10 then
            duration = 5 -- Milestone 10: 5 battles
        elseif scale >= 5 then
            duration = 3 -- Milestone 5: 3 battles
        else
            duration = 1
        end

        local isAnyActive = RoguemonStreamer.isAnyNegativeEventActive()
        if not inBattle or isAnyActive then
            p.queuedOverwhelmedCount = (p.queuedOverwhelmedCount or 0) + duration
            RoguemonStreamer.saveSettings()
            print(string.format("[RogueMon Streamer] Queued Overwhelmed: %d battles", duration))
            detail = string.format("Overwhelmed ( -%d%% current HP, PP used +1 for %d battle%s )", dmgPercent, duration, duration == 1 and "" or "s")
        else
            local currentActive = p.overwhelmedActive or 0
            if type(currentActive) ~= "number" then currentActive = currentActive == true and 1 or 0 end
            p.overwhelmedActive = currentActive + duration
            RoguemonStreamer.saveSettings()
            RoguemonStreamer.addAnimation(RoguemonStreamer.createBannerAnimation("OVERWHELMED", "FF0000", true))
            print(string.format("[RogueMon Streamer] Activated Overwhelmed: +1 PP used for %d battles", p.overwhelmedActive))
            detail = string.format("Overwhelmed ( -%d%% current HP, PP used +1 for %d battle%s )", dmgPercent, duration, duration == 1 and "" or "s")
        end
    elseif eventName == "Out of Control" then
        local turns = 3
        if scale >= 50 then
            turns = 20
        elseif scale >= 20 then
            turns = 10
        elseif scale >= 10 then
            turns = 5
        else
            turns = 3
        end
        if RoguemonStreamer.isChannelPointsExecution then
            RoguemonStreamer.settings.persistent.outOfControlCP = true
            RoguemonStreamer.saveSettings()
        end
        detail = RoguemonStreamer.queueOrActivateMoveEvent("Out of Control", turns)
    elseif eventName == "Omnimalus" then
        local inBattle = Battle.inActiveBattle()
        local isAnyActive = RoguemonStreamer.isAnyNegativeEventActive()
        local duration = 1
        if scale and scale >= 50 then
            duration = math.floor(scale / 2)
        elseif scale and scale >= 20 then
            duration = 4 -- Milestone 20: 4 battles
        elseif scale and scale >= 10 then
            duration = 2 -- Milestone 10: 2 battles
        elseif scale and scale >= 5 then
            duration = 2 -- Milestone 5: 2 battles
        else
            duration = 1
        end
        if RoguemonStreamer.isChannelPointsExecution then
            duration = 1
        end
        
        if not inBattle or isAnyActive then
            p.queuedOmnimalusCount = (p.queuedOmnimalusCount or 0) + duration
            RoguemonStreamer.saveSettings()
            print("[RogueMon Streamer] Queued Omnimalus event.")
            detail = string.format("Omnimalus ( -1 to all stats for %d battle%s )", duration, duration == 1 and "" or "s")
        else
            local stats = { "atk", "def", "spe", "spa", "spd", "acc", "eva" }
            for _, stat in ipairs(stats) do
                RoguemonStreamer.addStatBuff(stat, -1, duration)
            end
            p.omnimalusActive = duration
            RoguemonStreamer.saveSettings()
            print("[RogueMon Streamer] Activated Omnimalus immediately in battle.")
            detail = string.format("Omnimalus ( -1 to all stats for %d battle%s )", duration, duration == 1 and "" or "s")
        end
    elseif eventName == "No Guard Minus" then
        detail = RoguemonStreamer.queueOrActivateNoGuardEvent("No Guard Minus", scale)
    elseif eventName == "Mystification" then
        local btlCount = 5
        if scale and scale >= 50 then
            btlCount = math.floor(scale / 2)
        elseif scale and scale >= 20 then
            btlCount = 10
        elseif scale and scale >= 10 then
            btlCount = 5
        elseif scale and scale >= 5 and scale <= 9 then
            btlCount = 3
        end
        if RoguemonStreamer.isChannelPointsExecution then
            btlCount = 1
        end
        RoguemonStreamer.settings.persistent.mystificationActive = (RoguemonStreamer.settings.persistent.mystificationActive or 0) + btlCount
        RoguemonStreamer.settings.persistent.mystificationApplied = false
        RoguemonStreamer.saveSettings()
        detail = string.format("Mystification ( Casts Trick Room for %d btl )", RoguemonStreamer.settings.persistent.mystificationActive)
    elseif eventName == "Let's Dance" then
        print("[RogueMon Streamer] - Triggering Let's Dance choice menu")
        RoguemonStreamer.ActiveLetsDanceRequest = {
            Username = "Twitch",
            IsCP = RoguemonStreamer.isChannelPointsExecution,
            SubCount = scale
        }
        detail = "Let's Dance"
    end
    refreshTracker()
    local displayName = eventName
    if eventName == "Altera status" or eventName == "Inflict status" or eventName == "Inflict Status" then
        displayName = "Inflict status"
    end
    local finalMsg = "Bad Event: " .. (detail or displayName)
    RoguemonStreamer.notifyStreamer(finalMsg, scale)
    return finalMsg
end

-- PP UTILITIES
function RoguemonStreamer.cutPP(partyIndex, multiplier)
    local partyAddress = GameSettings.pstats + (partyIndex - 1) * 100
    local personality = Memory.readdword(partyAddress)
    local otid = Memory.readdword(partyAddress + 4)
    local magicword = Utils.bit_xor(personality, otid)

    local aux = personality % 24 + 1
    local attackoffset = (MiscData.TableData.attack[aux] - 1) * 12
    local attack3 = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + attackoffset + 8), magicword)

    local pps = {
        Utils.getbits(attack3, 0, 8),
        Utils.getbits(attack3, 8, 8),
        Utils.getbits(attack3, 16, 8),
        Utils.getbits(attack3, 24, 8),
    }

    for i = 1, 4 do
        pps[i] = math.floor(pps[i] * multiplier)
    end

    local attack3_dec = pps[1] + Utils.bit_lshift(pps[2], 8) + Utils.bit_lshift(pps[3], 16) + Utils.bit_lshift(pps[4], 24)
    Memory.writedword(partyAddress + 0x20 + attackoffset + 8, Utils.bit_xor(attack3_dec, magicword))

    -- Re-checksum
    local cs = 0
    for offset = 0, 44, 4 do
        local dword = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + offset), magicword)
        cs = cs + Utils.addhalves(dword)
    end
    cs = cs % 65536
    Memory.writeword(partyAddress + 28, cs)

    if Battle.inActiveBattle() then
        local battleSlot = RoguemonStreamer.getBattleSlot(partyIndex)
        if battleSlot ~= nil then
            local battleMonsAddress = GameSettings.gBattleMons + (battleSlot * (GameSettings.sizeofBattlePokemon or 0x58))
            local ppOffset = getBattlePpOffset()
            for i = 1, 4 do
                Memory.writebyte(battleMonsAddress + ppOffset + (i - 1), pps[i])
            end
        end
    end
end

function RoguemonStreamer.cutSingleRandomMovePP(partyIndex, multiplier)
    local partyAddress = GameSettings.pstats + (partyIndex - 1) * 100
    local personality = Memory.readdword(partyAddress)
    local otid = Memory.readdword(partyAddress + 4)
    local magicword = Utils.bit_xor(personality, otid)

    local aux = personality % 24 + 1
    local attackoffset = (MiscData.TableData.attack[aux] - 1) * 12
    local attack1 = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + attackoffset), magicword)
    local attack2 = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + attackoffset + 4), magicword)
    local attack3 = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + attackoffset + 8), magicword)

    local partyMoves = {
        Utils.getbits(attack1, 0, 16),
        Utils.getbits(attack1, 16, 16),
        Utils.getbits(attack2, 0, 16),
        Utils.getbits(attack2, 16, 16),
    }

    local pps = {
        Utils.getbits(attack3, 0, 8),
        Utils.getbits(attack3, 8, 8),
        Utils.getbits(attack3, 16, 8),
        Utils.getbits(attack3, 24, 8),
    }

    -- Find moves that exist and have PP > 0
    local eligible = {}
    for i = 1, 4 do
        if partyMoves[i] and partyMoves[i] > 0 and pps[i] > 0 then
            table.insert(eligible, i)
        end
    end

    if #eligible == 0 then
        -- Fallback if no moves with PP > 0
        for i = 1, 4 do
            if partyMoves[i] and partyMoves[i] > 0 then
                table.insert(eligible, i)
            end
        end
    end

    if #eligible == 0 then
        return nil
    end

    local slot = eligible[RoguemonStreamer.random(1, #eligible)]
    pps[slot] = math.floor(pps[slot] * multiplier)

    local attack3_dec = pps[1] + Utils.bit_lshift(pps[2], 8) + Utils.bit_lshift(pps[3], 16) + Utils.bit_lshift(pps[4], 24)
    Memory.writedword(partyAddress + 0x20 + attackoffset + 8, Utils.bit_xor(attack3_dec, magicword))

    -- Re-checksum
    local cs = 0
    for offset = 0, 44, 4 do
        local dword = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + offset), magicword)
        cs = cs + Utils.addhalves(dword)
    end
    cs = cs % 65536
    Memory.writeword(partyAddress + 28, cs)

    if Battle.inActiveBattle() then
        local battleSlot = RoguemonStreamer.getBattleSlot(partyIndex)
        if battleSlot ~= nil then
            local battleMonsAddress = GameSettings.gBattleMons + (battleSlot * (GameSettings.sizeofBattlePokemon or 0x58))
            local ppOffset = getBattlePpOffset()
            Memory.writebyte(battleMonsAddress + ppOffset + (slot - 1), pps[slot])
        end
    end

    local moveName = MoveData.Moves[partyMoves[slot]].name
    return moveName
end

-- ALTERED TYPES MANAGEMENT
function RoguemonStreamer.getAlteredTypes(personality)
    if not personality or not RoguemonStreamer.settings.alteredTypes then
        return nil
    end
    local personalityHex = string.format("0x%X", personality)
    local entry = RoguemonStreamer.settings.alteredTypes[personalityHex]
    if entry then
        return {
            PokemonData.TypeIndexMap[entry[1]] or "Unknown",
            PokemonData.TypeIndexMap[entry[2]] or "Unknown"
        }
    end
    return nil
end

function RoguemonStreamer.writeAlteredTypesToBattle(battlerIndex, type1, type2)
    if not GameSettings.gBattleMons then return end
    local offset = GameSettings.offsetBattlePokemonTypes or 0x22
    local battleMonsAddress = GameSettings.gBattleMons + (battlerIndex * (GameSettings.sizeofBattlePokemon or 0x58))
    Memory.writebyte(battleMonsAddress + offset, type1)
    Memory.writebyte(battleMonsAddress + offset + 1, type2)
end

local function getPartyMonPPs(partyIndex)
    if not GameSettings.pstats or Memory.readdword(GameSettings.pstats) == 0 then
        return {}
    end
    local partyAddress = GameSettings.pstats + (partyIndex - 1) * 100
    local personality = Memory.readdword(partyAddress)
    local otid = Memory.readdword(partyAddress + 4)
    local magicword = Utils.bit_xor(personality, otid)

    local aux = personality % 24 + 1
    local attackoffset = (MiscData.TableData.attack[aux] - 1) * 12

    local attack3 = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + attackoffset + 8), magicword)

    return {
        Utils.getbits(attack3, 0, 8),
        Utils.getbits(attack3, 8, 8),
        Utils.getbits(attack3, 16, 8),
        Utils.getbits(attack3, 24, 8),
    }
end

local function writePartyMonPPs(partyIndex, pps)
    if not GameSettings.pstats or Memory.readdword(GameSettings.pstats) == 0 then
        return
    end
    local partyAddress = GameSettings.pstats + (partyIndex - 1) * 100
    local personality = Memory.readdword(partyAddress)
    local otid = Memory.readdword(partyAddress + 4)
    local magicword = Utils.bit_xor(personality, otid)

    local aux = personality % 24 + 1
    local attackoffset = (MiscData.TableData.attack[aux] - 1) * 12

    local attack3_dec = pps[1] + Utils.bit_lshift(pps[2], 8) + Utils.bit_lshift(pps[3], 16) + Utils.bit_lshift(pps[4], 24)
    Memory.writedword(partyAddress + 0x20 + attackoffset + 8, Utils.bit_xor(attack3_dec, magicword))

    -- Re-checksum
    local cs = 0
    for offset = 0, 44, 4 do
        local dword = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + offset), magicword)
        cs = cs + Utils.addhalves(dword)
    end
    cs = cs % 65536
    Memory.writeword(partyAddress + 28, cs)
end

getPartyMonMoves = function(partyIndex)
    if not GameSettings.pstats or Memory.readdword(GameSettings.pstats) == 0 then
        return {}
    end
    local partyAddress = GameSettings.pstats + (partyIndex - 1) * 100
    local personality = Memory.readdword(partyAddress)
    local otid = Memory.readdword(partyAddress + 4)
    local magicword = Utils.bit_xor(personality, otid)

    local aux = personality % 24 + 1
    local attackoffset = (MiscData.TableData.attack[aux] - 1) * 12

    local attack1 = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + attackoffset), magicword)
    local attack2 = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + attackoffset + 4), magicword)

    return {
        Utils.getbits(attack1, 0, 16),
        Utils.getbits(attack1, 16, 16),
        Utils.getbits(attack2, 0, 16),
        Utils.getbits(attack2, 16, 16),
    }
end

function RoguemonStreamer.getPartyMonMovesAndPPs(partyIndex)
    if not GameSettings.pstats or Memory.readdword(GameSettings.pstats) == 0 then
        return {}, {}
    end
    local partyAddress = GameSettings.pstats + (partyIndex - 1) * 100
    local personality = Memory.readdword(partyAddress)
    local otid = Memory.readdword(partyAddress + 4)
    local magicword = Utils.bit_xor(personality, otid)

    local aux = personality % 24 + 1
    local attackoffset = (MiscData.TableData.attack[aux] - 1) * 12

    local attack1 = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + attackoffset), magicword)
    local attack2 = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + attackoffset + 4), magicword)
    local attack3 = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + attackoffset + 8), magicword)

    local moves = {
        Utils.getbits(attack1, 0, 16),
        Utils.getbits(attack1, 16, 16),
        Utils.getbits(attack2, 0, 16),
        Utils.getbits(attack2, 16, 16),
    }
    local pps = {
        Utils.getbits(attack3, 0, 8),
        Utils.getbits(attack3, 8, 8),
        Utils.getbits(attack3, 16, 8),
        Utils.getbits(attack3, 24, 8),
    }
    return moves, pps
end

function RoguemonStreamer.applyLetsDanceChange(slot, isRandomOption)
    local activeIdx = 1
    local moves, pps = RoguemonStreamer.getPartyMonMovesAndPPs(activeIdx)
    if #moves == 0 then
        print("[RogueMon Streamer] Let's Dance failed: No moves found on active Pokemon.")
        return
    end

    local targetSlot = slot
    local newMoveId = 0
    local oldMoveId = 0

    if isRandomOption then
        -- Choose a random slot from the active Pokemon's valid moves
        local validSlots = {}
        for i = 1, 4 do
            if moves[i] and moves[i] > 0 then
                table.insert(validSlots, i)
            end
        end
        if #validSlots == 0 then
            print("[RogueMon Streamer] Let's Dance failed: No valid moves to replace.")
            return
        end
        targetSlot = validSlots[RoguemonStreamer.random(#validSlots)]
        oldMoveId = moves[targetSlot]

        -- Get a random damaging move
        local damagingMoves = getDamagingMoveIds()
        -- Filter out currently known moves (this inherently prevents rolling the same move)
        local filteredDamaging = {}
        for _, mid in ipairs(damagingMoves) do
            local alreadyKnown = false
            for idx = 1, 4 do
                if moves[idx] == mid then
                    alreadyKnown = true
                    break
                end
            end
            if not alreadyKnown then
                table.insert(filteredDamaging, mid)
            end
        end
        if #filteredDamaging > 0 then
            newMoveId = filteredDamaging[RoguemonStreamer.random(#filteredDamaging)]
        else
            newMoveId = damagingMoves[RoguemonStreamer.random(#damagingMoves)]
        end
    else
        -- Replace a specific slot chosen by the player
        if not targetSlot or targetSlot < 1 or targetSlot > 4 or not moves[targetSlot] or moves[targetSlot] <= 0 then
            print("[RogueMon Streamer] Let's Dance failed: Invalid target slot chosen.")
            return
        end
        oldMoveId = moves[targetSlot]

        -- Get any random valid move
        local validMoves = getValidMoveIds()
        -- Filter out currently known moves (this inherently prevents rolling the same move)
        local filteredValid = {}
        for _, mid in ipairs(validMoves) do
            local alreadyKnown = false
            for idx = 1, 4 do
                if moves[idx] == mid then
                    alreadyKnown = true
                    break
                end
            end
            if not alreadyKnown then
                table.insert(filteredValid, mid)
            end
        end
        if #filteredValid > 0 then
            newMoveId = filteredValid[RoguemonStreamer.random(#filteredValid)]
        else
            newMoveId = validMoves[RoguemonStreamer.random(#validMoves)]
        end
    end

    if newMoveId > 0 and targetSlot then
        moves[targetSlot] = newMoveId
        local basePP = tonumber(MoveData.Moves[newMoveId].pp) or 20
        pps[targetSlot] = basePP

        -- Permanent write to party structure
        RoguemonStreamer.writeMovesAndPPToParty(activeIdx, moves, pps)

        -- If in active battle, update the active battle structure
        if Battle.inActiveBattle() then
            local battleSlot = RoguemonStreamer.getBattleSlot(activeIdx)
            if battleSlot ~= nil then
                local battleMonsAddress = GameSettings.gBattleMons + (battleSlot * (GameSettings.sizeofBattlePokemon or 0x58))
                Memory.writeword(battleMonsAddress + 0x0C + (targetSlot - 1) * 2, newMoveId)
                local ppOffset = getBattlePpOffset()
                Memory.writebyte(battleMonsAddress + ppOffset + (targetSlot - 1), basePP)
            end
        end

        local oldMoveName = (MoveData.Moves[oldMoveId] or {}).name or ("Move " .. targetSlot)
        local newMoveName = (MoveData.Moves[newMoveId] or {}).name or "Unknown Move"
        local optionStr = isRandomOption and "Random Option" or "Specific Option"
        local notifyMsg = string.format("[Let's Dance] Replaced %s with %s permanently (%s)!", oldMoveName, newMoveName, optionStr)

        local isCP = RoguemonStreamer.ActiveLetsDanceRequest and RoguemonStreamer.ActiveLetsDanceRequest.IsCP
        local subCount = RoguemonStreamer.ActiveLetsDanceRequest and RoguemonStreamer.ActiveLetsDanceRequest.SubCount
        
        local notifyImage = "sub.png"
        if isCP then
            notifyImage = "coin.png"
        elseif type(subCount) == "number" then
            if subCount >= 50 then notifyImage = "sub50.png"
            elseif subCount >= 20 then notifyImage = "sub20.png"
            elseif subCount >= 10 then notifyImage = "sub10.png"
            elseif subCount >= 5 then notifyImage = "sub5.png"
            end
        end

        local oldMoveType = (MoveData.Moves[oldMoveId] or {}).type or "normal"
        local newMoveType = (MoveData.Moves[newMoveId] or {}).type or "normal"
        local oldColor = Constants.MoveTypeColors[oldMoveType] or 0xFFFFFFFF
        local newColor = Constants.MoveTypeColors[newMoveType] or 0xFFFFFFFF

        RoguemonStreamer.temporaryNotifColors = {}
        local function registerMoveColors(name, color)
            if not name then return end
            RoguemonStreamer.temporaryNotifColors[name:lower()] = color
            for word in string.gmatch(name, "%S+") do
                if #word > 2 then
                    RoguemonStreamer.temporaryNotifColors[word:lower()] = color
                end
            end
        end

        registerMoveColors(oldMoveName, oldColor)
        registerMoveColors(newMoveName, newColor)

        RoguemonStreamer.notifyStreamer(notifyMsg, notifyImage)
        print("[RogueMon Streamer] " .. notifyMsg)
        refreshTracker()
    end
end

getDisabledMoveId = function()
    if not RoguemonStreamer.settings or not RoguemonStreamer.settings.persistent then
        return nil
    end
    if not Battle.inActiveBattle() then
        return RoguemonStreamer.settings.persistent.disabledMoveId
    end
    local activeIdx = getActivePartyIndex()
    local battleSlot = nil
    if activeIdx == Battle.Combatants.LeftOwn then
        battleSlot = 0
    elseif Battle.numBattlers == 4 and activeIdx == Battle.Combatants.RightOwn then
        battleSlot = 2
    end
    if battleSlot ~= nil then
        local structSize = GameSettings.disableStructEntrySize
        if GameSettings.gDisableStructs and structSize and GameSettings.disabledMoveOffset and GameSettings.disableTimerOffset then
            local base = GameSettings.gDisableStructs + battleSlot * structSize
            local disableTimer = Memory.readword(base + GameSettings.disableTimerOffset)
            local disabledMove = Memory.readword(base + GameSettings.disabledMoveOffset)
            if disableTimer and disableTimer > 0 and disabledMove and disabledMove > 0 then
                return disabledMove
            end
        end
    end
    return RoguemonStreamer.settings.persistent.disabledMoveId
end

function RoguemonStreamer.getViewedTypes(leadMon)
    if not leadMon or not leadMon.personality then
        return nil
    end

    if Battle.inActiveBattle() then
        local isActiveBattleMon = false
        local battleSlotIndex = nil
        local leftOwnMon = Tracker.getPokemon(Battle.Combatants.LeftOwn, true)
        if leftOwnMon and leftOwnMon.personality == leadMon.personality then
            isActiveBattleMon = true
            battleSlotIndex = 0  -- gBattleMons slot 0 = LeftOwn
        elseif Battle.numBattlers == 4 then
            local rightOwnMon = Tracker.getPokemon(Battle.Combatants.RightOwn, true)
            if rightOwnMon and rightOwnMon.personality == leadMon.personality then
                isActiveBattleMon = true
                battleSlotIndex = 2  -- gBattleMons slot 2 = RightOwn in doubles
            end
        end

        if isActiveBattleMon then
            local firstPartyMon = Tracker.getPokemon(1, true)
            local isMainMon = firstPartyMon and firstPartyMon.personality == leadMon.personality

            -- PRIORITY 1: Event Temp Type (paid event, always wins in battle for main mon)
            if isMainMon then
                local tempTypes = RoguemonStreamer.settings.persistent.tempTypeChange
                if tempTypes and #tempTypes == 2 then
                    return {
                        PokemonData.TypeIndexMap[tempTypes[1]] or "Unknown",
                        PokemonData.TypeIndexMap[tempTypes[2]] or "Unknown"
                    }
                end
            end

            -- PRIORITY 2: Enemy-inflicted type (e.g. Soak, Forest's Curse)
            -- Read actual battle RAM types and compare against what we expect
            if battleSlotIndex ~= nil and GameSettings.gBattleMons then
                local offset = GameSettings.offsetBattlePokemonTypes or 0x22
                local sizeofBP = GameSettings.sizeofBattlePokemon or 0x58
                local battleMonsAddress = GameSettings.gBattleMons + (battleSlotIndex * sizeofBP)
                local ramType1 = Memory.readbyte(battleMonsAddress + offset) or 0
                local ramType2 = Memory.readbyte(battleMonsAddress + offset + 1) or 0

                -- Determine what the "expected" type is (alteredType or base species type)
                local alteredEntry = nil
                if RoguemonStreamer.settings.alteredTypes then
                    local hex = string.format("0x%X", leadMon.personality)
                    alteredEntry = RoguemonStreamer.settings.alteredTypes[hex]
                end
                local expectedT1, expectedT2
                if alteredEntry then
                    expectedT1, expectedT2 = alteredEntry[1], alteredEntry[2]
                else
                    -- Base species types (numeric IDs)
                    local speciesTypes = PokemonData.Pokemon[leadMon.pokemonID] and PokemonData.Pokemon[leadMon.pokemonID].types or {}
                    local function nameToId(name)
                        for id, n in pairs(PokemonData.TypeIndexMap) do
                            if n == name then return id end
                        end
                        return 0
                    end
                    expectedT1 = nameToId(speciesTypes[1] or "")
                    expectedT2 = nameToId(speciesTypes[2] or speciesTypes[1] or "")
                end

                -- If RAM type differs from expected, an enemy changed it → use RAM type
                if (ramType1 ~= expectedT1 or ramType2 ~= expectedT2) then
                    local t1Name = PokemonData.TypeIndexMap[ramType1] or "Unknown"
                    local t2Name = PokemonData.TypeIndexMap[ramType2] or "Unknown"
                    return { t1Name, t2Name }
                end
            end
        end
    end

    -- PRIORITY 3: Permanent event type (alteredTypes) — handled by getAlteredTypes
    -- PRIORITY 4: Base species type — handled by the original getEffectiveness fallback
    return RoguemonStreamer.getAlteredTypes(leadMon.personality)
end

wrapGetPokemonTypes = function()
    if not Program or not Program.getPokemonTypes then
        return
    end
    if Program.getPokemonTypes == RoguemonStreamer.wrappedGetPokemonTypes then
        return
    end
    _G.RoguemonStreamer_Wrappers = _G.RoguemonStreamer_Wrappers or {}
    if _G.RoguemonStreamer_Wrappers[Program.getPokemonTypes] then
        RoguemonStreamer.wrappedGetPokemonTypes = Program.getPokemonTypes
        return
    end
    _G.RoguemonStreamer_Backups = _G.RoguemonStreamer_Backups or {}
    _G.RoguemonStreamer_Backups.getPokemonTypes = Program.getPokemonTypes
    RoguemonStreamer.wrappedGetPokemonTypes = function(isOwn, isLeft)
        if isOwn then
            local leadMon = Battle.getViewedPokemon(true)
            if leadMon and leadMon.personality then
                local altered = RoguemonStreamer.getViewedTypes(leadMon)
                if altered then
                    return altered
                end
            end
        end
        return _G.RoguemonStreamer_Backups.getPokemonTypes(isOwn, isLeft)
    end
    _G.RoguemonStreamer_Wrappers[RoguemonStreamer.wrappedGetPokemonTypes] = true
    Program.getPokemonTypes = RoguemonStreamer.wrappedGetPokemonTypes
    print("[RogueMon Streamer] Wrapped Program.getPokemonTypes (Self-Healed)")
end

wrapBuildTrackerScreenDisplay = function()
    if not DataHelper or not DataHelper.buildTrackerScreenDisplay then
        return
    end
    if DataHelper.buildTrackerScreenDisplay == RoguemonStreamer.wrappedBuildDisplay then
        return
    end
    _G.RoguemonStreamer_Wrappers = _G.RoguemonStreamer_Wrappers or {}
    if _G.RoguemonStreamer_Wrappers[DataHelper.buildTrackerScreenDisplay] then
        RoguemonStreamer.wrappedBuildDisplay = DataHelper.buildTrackerScreenDisplay
        return
    end
    _G.RoguemonStreamer_Backups = _G.RoguemonStreamer_Backups or {}
    _G.RoguemonStreamer_Backups.buildTrackerScreenDisplay = DataHelper.buildTrackerScreenDisplay
    RoguemonStreamer.wrappedBuildDisplay = function(forceView)
        local data = _G.RoguemonStreamer_Backups.buildTrackerScreenDisplay(forceView)
        if data and data.p and data.x and data.x.viewingOwn then
            local leadMon = Battle.getViewedPokemon(true)
            if leadMon and leadMon.personality then
                local altered = RoguemonStreamer.getViewedTypes(leadMon)
                if altered then
                    data.p.types = altered
                end
            end
        end
        return data
    end
    _G.RoguemonStreamer_Wrappers[RoguemonStreamer.wrappedBuildDisplay] = true
    DataHelper.buildTrackerScreenDisplay = RoguemonStreamer.wrappedBuildDisplay
    print("[RogueMon Streamer] Wrapped DataHelper.buildTrackerScreenDisplay (Self-Healed)")
end

wrapDrawMovesArea = function()
    if not TrackerScreen or not TrackerScreen.drawMovesArea then
        return
    end
    if TrackerScreen.drawMovesArea == RoguemonStreamer.wrappedDrawMovesArea then
        return
    end
    _G.RoguemonStreamer_Wrappers = _G.RoguemonStreamer_Wrappers or {}
    if _G.RoguemonStreamer_Wrappers[TrackerScreen.drawMovesArea] then
        RoguemonStreamer.wrappedDrawMovesArea = TrackerScreen.drawMovesArea
        return
    end
    _G.RoguemonStreamer_Backups = _G.RoguemonStreamer_Backups or {}
    _G.RoguemonStreamer_Backups.drawMovesArea = TrackerScreen.drawMovesArea
    RoguemonStreamer.wrappedDrawMovesArea = function(data)
        if not data or not data.m or not data.m.moves then
            _G.RoguemonStreamer_Backups.drawMovesArea(data)
            return
        end

        -- Create a deep copy of data.m to avoid modifying the tracker's shared memory
        local tempMon = {}
        for k, v in pairs(data.m) do
            tempMon[k] = v
        end
        local tempMoves = {}
        for i, move in ipairs(data.m.moves) do
            local tempMove = {}
            for mk, mv in pairs(move) do
                tempMove[mk] = mv
            end
            tempMoves[i] = tempMove
        end
        tempMon.moves = tempMoves

        local drawData = {}
        for k, v in pairs(data) do
            drawData[k] = v
        end
        drawData.m = tempMon

        -- 2. Color STAB moves in green (force move.isstab = true if move type matches Pokémon types)
        if drawData.p and drawData.p.types then
            local pTypes = drawData.p.types
            for _, move in ipairs(tempMoves) do
                if move.type and move.type ~= "???" and move.type ~= "None" then
                    for _, pType in ipairs(pTypes) do
                        if pType and pType ~= "???" and pType == move.type then
                            move.isstab = true
                            break
                        end
                    end
                end
            end
        end

        _G.RoguemonStreamer_Backups.drawMovesArea(drawData)

        -- 3. Draw Disable indicator if active
        local disabledMoveId = getDisabledMoveId()
        if disabledMoveId and disabledMoveId > 0 then
            local moveOffsetY = 94
            local moveNameOffset = 6
            if Options["Show physical special icons"] then
                moveNameOffset = moveNameOffset + 8
            end
            if not Theme.MOVE_TYPES_ENABLED then
                moveNameOffset = moveNameOffset + 5
            end

            for i, move in ipairs(tempMoves) do
                if move.id == disabledMoveId then
                    local y = moveOffsetY + 2
                    local x = Constants.SCREEN.WIDTH + moveNameOffset
                    local moveName = move.name or ""
                    local nameLen = Utils.calcWordPixelLength(moveName)
                    gui.drawLine(x, y + 4, x + nameLen, y + 4, 0xFFFF0000)
                end
                moveOffsetY = moveOffsetY + 10
            end
        end
    end
    _G.RoguemonStreamer_Wrappers[RoguemonStreamer.wrappedDrawMovesArea] = true
    TrackerScreen.drawMovesArea = RoguemonStreamer.wrappedDrawMovesArea
    print("[RogueMon Streamer] Wrapped TrackerScreen.drawMovesArea (Self-Healed)")
end

wrapGetAbilityId = function()
    if not PokemonData or not PokemonData.getAbilityId then
        return
    end
    if PokemonData.getAbilityId == RoguemonStreamer.wrappedGetAbilityId then
        return
    end
    _G.RoguemonStreamer_Wrappers = _G.RoguemonStreamer_Wrappers or {}
    if _G.RoguemonStreamer_Wrappers[PokemonData.getAbilityId] then
        RoguemonStreamer.wrappedGetAbilityId = PokemonData.getAbilityId
        return
    end
    _G.RoguemonStreamer_Backups = _G.RoguemonStreamer_Backups or {}
    _G.RoguemonStreamer_Backups.getAbilityId = PokemonData.getAbilityId
    RoguemonStreamer.wrappedGetAbilityId = function(pokemonID, abilityIndex)
        -- Real-time battle ability override (Skill Swap, Power Swap, Worry Seed, etc.)
        if Battle.inActiveBattle() and GameSettings.gBattleMons then
            local playerSpecies1 = nil
            local playerAddr1 = GameSettings.gBattleMons + (0 * (GameSettings.sizeofBattlePokemon or 0x58))
            if playerAddr1 then playerSpecies1 = Memory.readword(playerAddr1) end
            
            local playerSpecies2 = nil
            if Battle.numBattlers == 4 then
                local playerAddr2 = GameSettings.gBattleMons + (2 * (GameSettings.sizeofBattlePokemon or 0x58))
                if playerAddr2 then playerSpecies2 = Memory.readword(playerAddr2) end
            end
            
            local enemySpecies1 = nil
            local enemyAddr1 = GameSettings.gBattleMons + (1 * (GameSettings.sizeofBattlePokemon or 0x58))
            if enemyAddr1 then enemySpecies1 = Memory.readword(enemyAddr1) end
            
            local enemySpecies2 = nil
            if Battle.numBattlers == 4 then
                local enemyAddr2 = GameSettings.gBattleMons + (3 * (GameSettings.sizeofBattlePokemon or 0x58))
                if enemyAddr2 then enemySpecies2 = Memory.readword(enemyAddr2) end
            end
            
            local matchesPlayer = (pokemonID == playerSpecies1 or pokemonID == playerSpecies2)
            local matchesEnemy = (pokemonID == enemySpecies1 or pokemonID == enemySpecies2)
            
            local targetSlot = nil
            if matchesPlayer and not matchesEnemy then
                targetSlot = (pokemonID == playerSpecies1) and 0 or 2
            elseif matchesEnemy and not matchesPlayer then
                targetSlot = (pokemonID == enemySpecies1) and 1 or 3
            elseif matchesPlayer and matchesEnemy then
                if Battle.isViewingOwn then
                    targetSlot = (pokemonID == playerSpecies1) and 0 or 2
                else
                    targetSlot = (pokemonID == enemySpecies1) and 1 or 3
                end
            end
            
            local shouldReadRAM = true
            if targetSlot == 0 or targetSlot == 2 then
                local partySlot = (targetSlot == 0) and (Battle.Combatants.LeftOwn or 1) or (Battle.Combatants.RightOwn or 2)
                if RoguemonStreamer.appliedBattleAbilities and not RoguemonStreamer.appliedBattleAbilities[partySlot] then
                    shouldReadRAM = false
                end
            end
            
            if targetSlot ~= nil and shouldReadRAM then
                local targetAddr = GameSettings.gBattleMons + (targetSlot * (GameSettings.sizeofBattlePokemon or 0x58))
                local abilityOffset = RoguemonStreamer.getBattleAbilityOffset()
                local currentAbility = Memory.readword(targetAddr + abilityOffset)
                if currentAbility and currentAbility > 0 then
                    return currentAbility
                end
            end
        end

        if RoguemonStreamer.settings and RoguemonStreamer.settings.alteredAbilities then
            -- Check viewed Pokemon
            local viewed = Tracker.getViewedPokemon()
            if viewed and viewed.pokemonID == pokemonID and viewed.personality then
                local phex = string.format("0x%X", viewed.personality)
                local altered = RoguemonStreamer.settings.alteredAbilities[phex]
                if altered then
                    return altered
                end
            end
            -- Check player team
            if Program.GameData and Program.GameData.PlayerTeam then
                for _, mon in ipairs(Program.GameData.PlayerTeam) do
                    if mon and mon.pokemonID == pokemonID and mon.personality then
                        local phex = string.format("0x%X", mon.personality)
                        local altered = RoguemonStreamer.settings.alteredAbilities[phex]
                        if altered then
                            return altered
                        end
                    end
                end
            end
        end
        return _G.RoguemonStreamer_Backups.getAbilityId(pokemonID, abilityIndex)
    end
    _G.RoguemonStreamer_Wrappers[RoguemonStreamer.wrappedGetAbilityId] = true
    PokemonData.getAbilityId = RoguemonStreamer.wrappedGetAbilityId
    print("[RogueMon Streamer] Wrapped PokemonData.getAbilityId (Self-Healed)")
end

wrapGetEffectiveness = function()
    if not PokemonData or not PokemonData.getEffectiveness then
        return
    end
    if PokemonData.getEffectiveness == RoguemonStreamer.wrappedGetEffectiveness then
        return
    end
    _G.RoguemonStreamer_Wrappers = _G.RoguemonStreamer_Wrappers or {}
    if _G.RoguemonStreamer_Wrappers[PokemonData.getEffectiveness] then
        RoguemonStreamer.wrappedGetEffectiveness = PokemonData.getEffectiveness
        return
    end
    _G.RoguemonStreamer_Backups = _G.RoguemonStreamer_Backups or {}
    _G.RoguemonStreamer_Backups.getEffectiveness = PokemonData.getEffectiveness
    RoguemonStreamer.wrappedGetEffectiveness = function(pokemonID)
        local altered = nil
        
        -- In battle: check slot-1 party mon directly (Tracker.getViewedPokemon may return nil after screen change)
        if Battle.inActiveBattle() then
            local firstPartyMon = Tracker.getPokemon(1, true)
            if firstPartyMon and firstPartyMon.pokemonID == pokemonID and firstPartyMon.personality then
                altered = RoguemonStreamer.getViewedTypes(firstPartyMon)
            end
        end
        
        -- 1. Check viewed Pokemon (overworld or fallback)
        if not altered then
            local viewed = Tracker.getViewedPokemon()
            if viewed and viewed.pokemonID == pokemonID and viewed.personality then
                altered = RoguemonStreamer.getViewedTypes(viewed)
            end
        end
        
        -- 2. Check player team if not found
        if not altered and Program.GameData and Program.GameData.PlayerTeam then
            for _, mon in ipairs(Program.GameData.PlayerTeam) do
                if mon and mon.pokemonID == pokemonID and mon.personality then
                    altered = RoguemonStreamer.getViewedTypes(mon)
                    if altered then
                        break
                    end
                end
            end
        end
        
        -- If altered types exist, calculate effectiveness on-the-fly
        if altered and #altered > 0 then
            local effectiveness = {
                [0] = {},
                [0.25] = {},
                [0.5] = {},
                [1] = {},
                [2] = {},
                [4] = {},
            }
            local t1 = string.lower(altered[1])
            local t2 = string.lower(altered[2] or t1)
            if MoveData and MoveData.TypeToEffectiveness then
                for moveType, typeMultiplier in pairs(MoveData.TypeToEffectiveness) do
                    local total = 1
                    if typeMultiplier[t1] ~= nil then
                        total = total * typeMultiplier[t1]
                    end
                    if t2 ~= t1 and typeMultiplier[t2] ~= nil then
                        total = total * typeMultiplier[t2]
                    end
                    if effectiveness[total] ~= nil then
                        table.insert(effectiveness[total], moveType)
                    end
                end
                return effectiveness
            end
        end
        
        return _G.RoguemonStreamer_Backups.getEffectiveness(pokemonID)
    end
    _G.RoguemonStreamer_Wrappers[RoguemonStreamer.wrappedGetEffectiveness] = true
    PokemonData.getEffectiveness = RoguemonStreamer.wrappedGetEffectiveness
    print("[RogueMon Streamer] Wrapped PokemonData.getEffectiveness (Self-Healed)")
end

wrapBuildPokemonInfoDisplay = function()
    if not DataHelper or not DataHelper.buildPokemonInfoDisplay then
        return
    end
    if DataHelper.buildPokemonInfoDisplay == RoguemonStreamer.wrappedBuildPokemonInfoDisplay then
        return
    end
    _G.RoguemonStreamer_Wrappers = _G.RoguemonStreamer_Wrappers or {}
    if _G.RoguemonStreamer_Wrappers[DataHelper.buildPokemonInfoDisplay] then
        RoguemonStreamer.wrappedBuildPokemonInfoDisplay = DataHelper.buildPokemonInfoDisplay
        return
    end
    _G.RoguemonStreamer_Backups = _G.RoguemonStreamer_Backups or {}
    _G.RoguemonStreamer_Backups.buildPokemonInfoDisplay = DataHelper.buildPokemonInfoDisplay
    RoguemonStreamer.wrappedBuildPokemonInfoDisplay = function(pokemonID)
        local data = _G.RoguemonStreamer_Backups.buildPokemonInfoDisplay(pokemonID)
        if data and data.p then
            local altered = nil
            
            -- 1. Check viewed Pokemon
            local viewed = Tracker.getViewedPokemon()
            if viewed and viewed.pokemonID == pokemonID and viewed.personality then
                altered = RoguemonStreamer.getViewedTypes(viewed)
            end
            
            -- 2. Check player team if not found
            if not altered and Program.GameData and Program.GameData.PlayerTeam then
                for _, mon in ipairs(Program.GameData.PlayerTeam) do
                    if mon and mon.pokemonID == pokemonID and mon.personality then
                        altered = RoguemonStreamer.getViewedTypes(mon)
                        if altered then
                            break
                        end
                    end
                end
            end
            
            if altered and #altered > 0 then
                data.p.types = {
                    altered[1] or PokemonData.Types.UNKNOWN,
                    (altered[2] ~= altered[1]) and altered[2] or PokemonData.Types.EMPTY
                }
            end
        end
        return data
    end
    _G.RoguemonStreamer_Wrappers[RoguemonStreamer.wrappedBuildPokemonInfoDisplay] = true
    DataHelper.buildPokemonInfoDisplay = RoguemonStreamer.wrappedBuildPokemonInfoDisplay
    print("[RogueMon Streamer] Wrapped DataHelper.buildPokemonInfoDisplay (Self-Healed)")
end

wrapCheckForGameOver = function()
    if not GameOverScreen or not GameOverScreen.checkForGameOver then
        return
    end
    if GameOverScreen.checkForGameOver == RoguemonStreamer.wrappedCheckForGameOver then
        return
    end
    _G.RoguemonStreamer_Wrappers = _G.RoguemonStreamer_Wrappers or {}
    if _G.RoguemonStreamer_Wrappers[GameOverScreen.checkForGameOver] then
        RoguemonStreamer.wrappedCheckForGameOver = GameOverScreen.checkForGameOver
        return
    end
    _G.RoguemonStreamer_Backups = _G.RoguemonStreamer_Backups or {}
    _G.RoguemonStreamer_Backups.checkForGameOver = GameOverScreen.checkForGameOver
    RoguemonStreamer.wrappedCheckForGameOver = function(lastBattleStatus, lastTrainerId)
        local isGameOver = _G.RoguemonStreamer_Backups.checkForGameOver(lastBattleStatus, lastTrainerId)
        if isGameOver then
            RoguemonStreamer.resetRunState(true)
            print("[RogueMon Streamer] Automatically reset run state via GameOverScreen.checkForGameOver()")
        end
        return isGameOver
    end
    _G.RoguemonStreamer_Wrappers[RoguemonStreamer.wrappedCheckForGameOver] = true
    GameOverScreen.checkForGameOver = RoguemonStreamer.wrappedCheckForGameOver
    print("[RogueMon Streamer] Wrapped GameOverScreen.checkForGameOver (Self-Healed)")
end


function RoguemonStreamer.getOriginalPIDHex(currentPIDHex)
    if not RoguemonStreamer.settings.persistent or not RoguemonStreamer.settings.persistent.pidMappings then
        return currentPIDHex
    end
    local orig = currentPIDHex
    local visited = {}
    while RoguemonStreamer.settings.persistent.pidMappings[orig] do
        if visited[orig] then break end
        visited[orig] = true
        orig = RoguemonStreamer.settings.persistent.pidMappings[orig]
    end
    return orig
end

function RoguemonStreamer.restoreOriginalPID(partyIndex, targetPID)
    local partyAddress = GameSettings.pstats + (partyIndex - 1) * 100
    local oldPID = Memory.readdword(partyAddress)
    local otid = Memory.readdword(partyAddress + 4)
    local oldMagic = Utils.bit_xor(oldPID, otid)

    -- Decrypt the 12 dwords
    local decrypted = {}
    for i = 0, 11 do
        local enc = Memory.readdword(partyAddress + 0x20 + (i * 4))
        decrypted[i + 1] = Utils.bit_xor(enc, oldMagic)
    end

    -- Write target PID
    Memory.writedword(partyAddress, targetPID)

    -- Re-encrypt with new magic word
    local newMagic = Utils.bit_xor(targetPID, otid)
    for i = 0, 11 do
        local enc = Utils.bit_xor(decrypted[i + 1], newMagic)
        Memory.writedword(partyAddress + 0x20 + (i * 4), enc)
    end

    -- Recalculate checksum
    local cs = 0
    for offset = 0, 44, 4 do
        local dword = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + offset), newMagic)
        cs = cs + Utils.addhalves(dword)
    end
    cs = cs % 65536
    Memory.writeword(partyAddress + 28, cs)
    print(string.format("[RogueMon Streamer] - Restored original PID: 0x%X (Checksum: 0x%X)", targetPID, cs))
end

function RoguemonStreamer.registerOriginalMonData(leadMon)
    if not leadMon or not leadMon.personality or not leadMon.pokemonID then return end
    local personalityHex = string.format("0x%X", leadMon.personality)
    local origHex = RoguemonStreamer.getOriginalPIDHex(personalityHex)
    
    RoguemonStreamer.settings.persistent.originalMonData = RoguemonStreamer.settings.persistent.originalMonData or {}
    if not RoguemonStreamer.settings.persistent.originalMonData[origHex] then
        RoguemonStreamer.settings.persistent.originalMonData[origHex] = {
            species = leadMon.pokemonID
        }
        RoguemonStreamer.saveSettings()
    end
end


-- PERSONALITY MODIFIER
function RoguemonStreamer.changePokemonPersonality(partyIndex, targetNature, targetAbilityNum)
    local partyAddress = GameSettings.pstats + (partyIndex - 1) * 100
    local oldPID = Memory.readdword(partyAddress)
    local otid = Memory.readdword(partyAddress + 4)
    local oldMagic = Utils.bit_xor(oldPID, otid)

    -- Decrypt the 12 dwords
    local decrypted = {}
    for i = 0, 11 do
        local enc = Memory.readdword(partyAddress + 0x20 + (i * 4))
        decrypted[i + 1] = Utils.bit_xor(enc, oldMagic)
    end

    local aux = oldPID % 24 + 1
    local species = Utils.getbits(decrypted[1], 0, 16)
    local oldGender = MiscData.getMonGender(species, oldPID)

    local oldPIDHex = string.format("0x%X", oldPID)
    local origHex = RoguemonStreamer.getOriginalPIDHex(oldPIDHex)
    
    RoguemonStreamer.settings.persistent.originalMonData = RoguemonStreamer.settings.persistent.originalMonData or {}
    if not RoguemonStreamer.settings.persistent.originalMonData[origHex] then
        RoguemonStreamer.settings.persistent.originalMonData[origHex] = {
            species = species
        }
        RoguemonStreamer.saveSettings()
    end

    local miscoffset = (MiscData.TableData.misc[aux] - 1) * 12
    local misc3Index = math.floor(miscoffset / 4) + 3

    -- Modify the ability slot in the decrypted Misc3 block if targetAbilityNum is provided
    if targetAbilityNum then
        local currentMisc3 = decrypted[misc3Index]
        -- Clear bits 29 and 30 (mask 0x60000000) by ANDing with 0x9FFFFFFF
        currentMisc3 = Utils.bit_and(currentMisc3, 0x9FFFFFFF)
        -- Set bits 29 and 30 to targetAbilityNum
        local val = Utils.bit_lshift(targetAbilityNum, 29)
        currentMisc3 = Utils.bit_or(currentMisc3, val)
        decrypted[misc3Index] = currentMisc3
        print(string.format("[RogueMon Streamer] - Modified ability slot bits in Misc3 to %d", targetAbilityNum))
    end

    local newPID = oldPID
    if targetNature then
        -- Find a new PID that satisfies:
        -- 1. newPID % 25 == targetNature
        -- 2. newPID % 24 == oldPID % 24 (preserves substructure order)
        -- 3. preserves gender
        local oldPIDMod24 = oldPID % 24
        local found = false
        
        -- Search forwards
        for attempt = 1, 50000 do
            local pidCandidate = oldPID + attempt
            if pidCandidate % 24 == oldPIDMod24 and pidCandidate % 25 == targetNature then
                if MiscData.getMonGender(species, pidCandidate) == oldGender then
                    newPID = pidCandidate
                    found = true
                    break
                end
            end
        end

        -- Search backwards if not found
        if not found then
            for attempt = 1, 50000 do
                local pidCandidate = oldPID - attempt
                if pidCandidate >= 0 and pidCandidate % 24 == oldPIDMod24 and pidCandidate % 25 == targetNature then
                    if MiscData.getMonGender(species, pidCandidate) == oldGender then
                        newPID = pidCandidate
                        found = true
                        break
                    end
                end
            end
        end

        if found then
            print(string.format("[RogueMon Streamer] - Found new PID: 0x%X (Nature: %d, order %d matches old %d)", newPID, targetNature, newPID % 24, oldPIDMod24))
        else
            print("[RogueMon Streamer] - Warning: Could not find new PID matching all criteria. Nature change skipped to prevent corruption.")
        end
    end

    -- Write new PID to RAM
    Memory.writedword(partyAddress, newPID)

    -- Re-encrypt with new magic word (or old magic word if PID didn't change)
    local newMagic = Utils.bit_xor(newPID, otid)
    for i = 0, 11 do
        local enc = Utils.bit_xor(decrypted[i + 1], newMagic)
        Memory.writedword(partyAddress + 0x20 + (i * 4), enc)
    end

    -- Recalculate checksum
    local cs = 0
    for offset = 0, 44, 4 do
        local dword = Utils.bit_xor(Memory.readdword(partyAddress + 0x20 + offset), newMagic)
        cs = cs + Utils.addhalves(dword)
    end
    cs = cs % 65536
    Memory.writeword(partyAddress + 28, cs)
    print(string.format("[RogueMon Streamer] - Personality modification complete. Checksum written: 0x%X", cs))

    if targetNature then
        -- Clear any active Nature Mints (bits 3-7 of language byte at 0x12) to prevent double application
        local langByte = Memory.readbyte(partyAddress + 0x12)
        Memory.writebyte(partyAddress + 0x12, langByte % 8)
    end

    -- Migrate altered types and abilities if personality changed
    if newPID ~= oldPID then
        local oldHex = string.format("0x%X", oldPID)
        local newHex = string.format("0x%X", newPID)
        local changedAny = false

        RoguemonStreamer.settings.persistent.pidMappings = RoguemonStreamer.settings.persistent.pidMappings or {}
        RoguemonStreamer.settings.persistent.pidMappings[newHex] = oldHex
        changedAny = true

        if RoguemonStreamer.settings.alteredTypes and RoguemonStreamer.settings.alteredTypes[oldHex] then
            RoguemonStreamer.settings.alteredTypes[newHex] = RoguemonStreamer.settings.alteredTypes[oldHex]
            RoguemonStreamer.settings.alteredTypes[oldHex] = nil
            print(string.format("[RogueMon Streamer] - Migrated custom types from %s to %s", oldHex, newHex))
        end

        if RoguemonStreamer.settings.alteredAbilities and RoguemonStreamer.settings.alteredAbilities[oldHex] then
            RoguemonStreamer.settings.alteredAbilities[newHex] = RoguemonStreamer.settings.alteredAbilities[oldHex]
            RoguemonStreamer.settings.alteredAbilities[oldHex] = nil
            print(string.format("[RogueMon Streamer] - Migrated custom ability from %s to %s", oldHex, newHex))
        end

        if changedAny then
            RoguemonStreamer.saveSettings()
        end
    end
end

-- MOVESET MANIPULATION HACK (OUT OF CONTROL HACK)
function RoguemonStreamer.applyOutOfControlOverwrite(activeIdx)
    local battleMonsAddress = getBattleMonsAddress(activeIdx)
    if not battleMonsAddress then return end

    -- Read original moves from the party struct (source of truth)
    local partyMoves = getPartyMonMoves(activeIdx)
    if not partyMoves or #partyMoves == 0 then return end

    local partyPPs = getPartyMonPPs(activeIdx)

    -- Cache original moves and starting PP values
    RoguemonStreamer.OriginalMoves = partyMoves
    RoguemonStreamer.OocStartPPs = partyPPs
    RoguemonStreamer.lastOverwrittenIdx = activeIdx

    -- Filter slots that have moves with PP > 0
    local validSlots = {}
    for i = 1, 4 do
        if partyMoves[i] and partyMoves[i] > 0 then
            local currentPP = partyPPs[i] or 0
            if currentPP > 0 then
                table.insert(validSlots, i)
            end
        end
    end

    -- Determine outcome: 80% chance of random move, 20% chance of standing still (or if no PP left)
    local roll = RoguemonStreamer.random(100)
    if #validSlots == 0 or roll <= 20 then
        -- Stand still (Flinch)
        RoguemonStreamer.OocExecutedSlot = nil -- no move executed
        
        -- Set flinch bit (0x00000008) in volatile status (status2)
        local volOffset = GameSettings.battleVolatilesOffset or 0x50
        local status2 = Memory.readdword(battleMonsAddress + volOffset) or 0
        status2 = Utils.bit_or(status2, 0x00000008)
        Memory.writedword(battleMonsAddress + volOffset, status2)
        
        print("[RogueMon Streamer] Out of Control: Pokémon stands still (flinch applied).")
        RoguemonStreamer.OocFlinched = true
    else
        -- Execute a random move
        local chosenSlot = validSlots[RoguemonStreamer.random(#validSlots)]
        local chosenMove = partyMoves[chosenSlot]
        RoguemonStreamer.OocExecutedSlot = chosenSlot

        -- Overwrite gBattleMons moves with the chosen random move in all 4 slots
        for i = 1, 4 do
            Memory.writeword(battleMonsAddress + 0x0C + ((i - 1) * 2), chosenMove)
        end
        RoguemonStreamer.MovesOverwritten = true
        local moveName = (MoveData and MoveData.Moves[chosenMove] or {}).name or "Move"
        print(string.format("[RogueMon Streamer] Out of Control applied. Forced move: %s (slot %d)", moveName, chosenSlot))
    end
end

function RoguemonStreamer.restoreOriginalMoves(activeIdx)
    local idx = activeIdx or RoguemonStreamer.lastOverwrittenIdx or getActivePartyIndex()
    local battleMonsAddress = getBattleMonsAddress(idx)

    -- If we executed a move under Out of Control, adjust PP if needed
    if RoguemonStreamer.OocExecutedSlot and RoguemonStreamer.OocStartPPs then
        local currentPPs = getPartyMonPPs(idx)
        -- Find which slot PP was decremented by the GBA engine
        local decrementedSlot = nil
        for i = 1, 4 do
            if currentPPs[i] == RoguemonStreamer.OocStartPPs[i] - 1 then
                decrementedSlot = i
                break
            end
        end

        -- If the game decremented PP from a slot other than the executed slot, swap them
        if decrementedSlot and decrementedSlot ~= RoguemonStreamer.OocExecutedSlot then
            currentPPs[decrementedSlot] = currentPPs[decrementedSlot] + 1 -- restore the slot the player selected
            currentPPs[RoguemonStreamer.OocExecutedSlot] = currentPPs[RoguemonStreamer.OocExecutedSlot] - 1 -- deduct the slot that actually executed
            writePartyMonPPs(idx, currentPPs)
            print(string.format("[RogueMon Streamer] Out of Control PP Adjusted: Restored slot %d, deducted slot %d", decrementedSlot, RoguemonStreamer.OocExecutedSlot))

            -- Also update battle struct PP array to keep battle state synchronized
            if battleMonsAddress then
                local ppOffset = getBattlePpOffset()
                Memory.writebyte(battleMonsAddress + ppOffset + (decrementedSlot - 1), currentPPs[decrementedSlot])
                Memory.writebyte(battleMonsAddress + ppOffset + (RoguemonStreamer.OocExecutedSlot - 1), currentPPs[RoguemonStreamer.OocExecutedSlot])
            end
        end
    end

    if battleMonsAddress then
        if RoguemonStreamer.OriginalMoves then
            local moves = RoguemonStreamer.OriginalMoves
            for i = 1, 4 do
                Memory.writeword(battleMonsAddress + 0x0C + ((i - 1) * 2), moves[i])
            end
        end
    end

    RoguemonStreamer.OriginalMoves = nil
    RoguemonStreamer.OocStartPPs = nil
    RoguemonStreamer.OocExecutedSlot = nil
    RoguemonStreamer.OocFlinched = nil
    RoguemonStreamer.MovesOverwritten = false
    RoguemonStreamer.lastOverwrittenIdx = nil
    print("[RogueMon Streamer] Original battle moveset restored.")
end

function RoguemonStreamer.isAnyNegativeEventActive()
    local p = RoguemonStreamer.settings.persistent
    if not p then return false end
    
    local oocActive = (p.outOfControlTurns or 0) > 0
    local dmActive = p.disabledMoveId and p.disabledMoveId > 0 and (p.disabledMoveTurns or 0) > 0
    local ohActive = p.overwhelmedActive == true or (type(p.overwhelmedActive) == "number" and p.overwhelmedActive > 0)
    local omActive = p.omnimalusActive == true or (type(p.omnimalusActive) == "number" and p.omnimalusActive > 0)
    
    return oocActive or dmActive or ohActive or omActive
end

RoguemonStreamer.activeAnimations = {}

function RoguemonStreamer.addAnimation(anim)
    if RoguemonStreamer.settings and RoguemonStreamer.settings.enableAnimations == true then
        table.insert(RoguemonStreamer.activeAnimations, anim)
    end
end

function RoguemonStreamer.updateAndDrawAnimations()
    if not Battle.inActiveBattle() then
        RoguemonStreamer.activeAnimations = {}
        return
    end
    local i = 1
    while i <= #RoguemonStreamer.activeAnimations do
        local anim = RoguemonStreamer.activeAnimations[i]
        local keep = anim:updateAndDraw()
        if not keep then
            table.remove(RoguemonStreamer.activeAnimations, i)
        else
            i = i + 1
        end
    end
end

function RoguemonStreamer.createBannerAnimation(eventName, colorHex, isNegative)
    return {
        name = eventName,
        colorHex = colorHex or "FF0000",
        frame = 0,
        maxFrames = 120,
        isNegative = isNegative,
        updateAndDraw = function(self)
            self.frame = self.frame + 1
            if self.frame > self.maxFrames then
                return false
            end
            
            local y = 60
            local opacity = 255
            
            if self.frame <= 15 then
                y = -32 + (self.frame / 15) * 92
                opacity = math.floor((self.frame / 15) * 255)
            elseif self.frame >= 105 then
                local progress = (self.frame - 105) / 15
                y = 60 + progress * 92
                opacity = math.floor((1 - progress) * 255)
            end
            
            local alphaColor = string.format("#%02X%s", opacity, self.colorHex)
            local alphaBlack = string.format("#%02X000000", math.floor(opacity * 0.75))
            local alphaBorder = string.format("#%02XFFFFFF", opacity)
            
            local bx = 10
            local by = math.floor(y)
            local bw = 220
            local bh = 32
            
            gui.drawRectangle(bx, by, bw, bh, alphaBorder, alphaBlack)
            
            local displayText = self.name
            if self.isNegative then
                displayText = "!!! " .. displayText .. " !!!"
            else
                displayText = "+++ " .. displayText .. " +++"
            end
            
            local textX = 120 - (#displayText * 3.5)
            local textY = by + 10
            local alphaShadow = string.format("#%02X000000", opacity)
            gui.drawText(textX + 1, textY + 1, displayText, alphaShadow, nil, 10, "Arial", "bold")
            gui.drawText(textX, textY, displayText, alphaColor, nil, 10, "Arial", "bold")
            
            return true
        end
    }
end

function RoguemonStreamer.createStatArrowsAnimation(isBuff)
    local anim = {
        isBuff = isBuff,
        frame = 0,
        maxFrames = 60,
        arrows = {}
    }
    
    for i = 1, 8 do
        table.insert(anim.arrows, {
            x = 20 + math.random(50),
            y = isBuff and (120 - math.random(20)) or (70 + math.random(20)),
            speed = 1.5 + math.random() * 1.5,
            size = 4 + math.random(4)
        })
    end
    
    function anim:updateAndDraw()
        self.frame = self.frame + 1
        if self.frame > self.maxFrames then
            return false
        end
        
        local opacity = 255
        if self.frame > 45 then
            opacity = math.floor((1 - (self.frame - 45) / 15) * 255)
        end
        
        local colorHex = self.isBuff and "00FF00" or "FF0000"
        local arrowColor = string.format("#%02X%s", opacity, colorHex)
        
        for _, arrow in ipairs(self.arrows) do
            if self.isBuff then
                arrow.y = arrow.y - arrow.speed
            else
                arrow.y = arrow.y + arrow.speed
            end
            
            local ax = math.floor(arrow.x)
            local ay = math.floor(arrow.y)
            local s = arrow.size
            
            if self.isBuff then
                gui.drawLine(ax, ay, ax - s, ay + s, arrowColor)
                gui.drawLine(ax, ay, ax + s, ay + s, arrowColor)
                gui.drawLine(ax, ay + s, ax, ay + s * 2, arrowColor)
            else
                gui.drawLine(ax, ay + s * 2, ax - s, ay + s, arrowColor)
                gui.drawLine(ax, ay + s * 2, ax + s, ay + s, arrowColor)
                gui.drawLine(ax, ay, ax, ay + s, arrowColor)
            end
        end
        
        return true
    end
    
    return anim
end

function RoguemonStreamer.checkAndPopQueuedBattleEvents()
    RoguemonStreamer.lastBattleOutcome = nil
    local p = RoguemonStreamer.settings.persistent
    if not p then return false end

    local activeIdx = getActivePartyIndex()
    if activeIdx ~= 1 then return false end

    -- Initialize fields if they don't exist
    p.queuedOutOfControlTurns = p.queuedOutOfControlTurns or 0
    p.queuedDisableTurns = p.queuedDisableTurns or {}
    p.queuedNoGuards = p.queuedNoGuards or {}
    p.queuedTempTypes = p.queuedTempTypes or {}
    p.queuedDamageAndStatus = p.queuedDamageAndStatus or {}
    p.queuedOmnimalusCount = p.queuedOmnimalusCount or 0

    local activeIdx = getActivePartyIndex()
    local partyAddress = GameSettings.pstats + (activeIdx - 1) * 100
    local currentStatus = Memory.readdword(partyAddress + 0x50)
    local curHP = Memory.readword(partyAddress + 0x54 + 2)

    -- Check if any event is already active (carrying over)
    local oocActive = (p.outOfControlTurns or 0) > 0
    local dmActive = p.disabledMoveId and p.disabledMoveId > 0 and (p.disabledMoveTurns or 0) > 0
    local ohActive = p.overwhelmedActive == true or (type(p.overwhelmedActive) == "number" and p.overwhelmedActive > 0)
    local omActive = p.omnimalusActive == true or (type(p.omnimalusActive) == "number" and p.omnimalusActive > 0)
    
    local anyActive = oocActive or dmActive or ohActive or omActive

    -- 1. Consolidate carrying-over states

    -- 2. Activate move/status negative event based on strict priority
    if anyActive then
        -- An event is already active, do not pop anything new!
        if dmActive then
            p.disabledMoveApplied = false
            print(string.format("[RogueMon Streamer] Preserved carrying-over Disable Move: Move %d (%d turns)", p.disabledMoveId, p.disabledMoveTurns))
        end
    else
        -- No active event! Pop the next one based on priority: Out of Control -> Overwhelmed -> Disabled Move -> Omnimalus
        if p.queuedOutOfControlTurns and p.queuedOutOfControlTurns > 0 then
            p.outOfControlTurns = p.queuedOutOfControlTurns
            p.queuedOutOfControlTurns = 0
            RoguemonStreamer.addAnimation(RoguemonStreamer.createBannerAnimation("OUT OF CONTROL", "FF8000", true))
            print(string.format("[RogueMon Streamer] Priority Pop: Activated Out of Control for %d turns from queue.", p.outOfControlTurns))
        elseif p.queuedOverwhelmedCount and p.queuedOverwhelmedCount > 0 then
            p.overwhelmedActive = p.queuedOverwhelmedCount
            p.queuedOverwhelmedCount = 0
            RoguemonStreamer.saveSettings()
            RoguemonStreamer.addAnimation(RoguemonStreamer.createBannerAnimation("OVERWHELMED", "FF0000", true))
            print(string.format("[RogueMon Streamer] Priority Pop: Activated Overwhelmed (+1 PP) for %d battles from queue.", p.overwhelmedActive))
        elseif #p.queuedDisableTurns > 0 then
            local item = table.remove(p.queuedDisableTurns, 1)
            local partyMoves = getPartyMonMoves(activeIdx)
            local moves = {}
            for _, m in ipairs(partyMoves) do
                if m and m > 0 then
                    table.insert(moves, m)
                end
            end
            if #moves > 0 then
                p.disabledMoveId = moves[RoguemonStreamer.random(#moves)]
                p.disabledMoveTurns = item.turns
                p.disabledMoveApplied = false
                RoguemonStreamer.saveSettings()
                RoguemonStreamer.addAnimation(RoguemonStreamer.createBannerAnimation("DISABLED MOVE", "FF33FF", true))
                print(string.format("[RogueMon Streamer] Priority Pop: Activated Disable Move (ID: %d, %d turns) from queue.", p.disabledMoveId, p.disabledMoveTurns))
            end
        elseif p.queuedOmnimalusCount and p.queuedOmnimalusCount > 0 then
            local duration = p.queuedOmnimalusCount
            p.queuedOmnimalusCount = 0
            local stats = { "atk", "def", "spe", "spa", "spd", "acc", "eva" }
            RoguemonStreamer.suppressStatBuffArrows = true
            for _, stat in ipairs(stats) do
                RoguemonStreamer.addStatBuff(stat, -1, duration)
            end
            RoguemonStreamer.suppressStatBuffArrows = nil
            p.omnimalusActive = duration
            RoguemonStreamer.saveSettings()
            RoguemonStreamer.addAnimation(RoguemonStreamer.createBannerAnimation("OMNIMALUS", "FF0000", true))
            RoguemonStreamer.addAnimation(RoguemonStreamer.createStatArrowsAnimation(false))
            print(string.format("[RogueMon Streamer] Priority Pop: Activated Omnimalus from queue for %d battles.", duration))
        end
    end

    -- 3. Activate accuracy-modifying event from queue (if any)

    -- 4. Activate temp type change from queue (if not already active)
    if not p.tempTypeChange and #p.queuedTempTypes > 0 then
        local nextTemp = table.remove(p.queuedTempTypes, 1)
        p.tempTypeChange = { nextTemp[1], nextTemp[2] }
        p.tempTypeApplied = false
        RoguemonStreamer.addAnimation(RoguemonStreamer.createBannerAnimation("TYPE CHANGED", "00FFFF", false))
        print(string.format("[RogueMon Streamer] Pop: Activated Temp Type Change (%d/%d) from queue.", nextTemp[1], nextTemp[2]))
    end

    RoguemonStreamer.saveSettings()
    refreshTracker()
    return true
end

function RoguemonStreamer.popNextQueuedBattleEvent()
    local p = RoguemonStreamer.settings.persistent
    if not p then return end

    local activeIdx = getActivePartyIndex()
    if activeIdx ~= 1 then return end
    local partyAddress = GameSettings.pstats + (activeIdx - 1) * 100
    local currentStatus = Memory.readdword(partyAddress + 0x50)
    local curHP = Memory.readword(partyAddress + 0x54 + 2)

    -- If another event is already active, do not pop
    if RoguemonStreamer.isAnyNegativeEventActive() then
        return
    end

    -- Pop based on priority: Out of Control -> Overwhelmed (Damage & Status) -> Disable Move
    if p.queuedOutOfControlTurns and p.queuedOutOfControlTurns > 0 then
        p.outOfControlTurns = p.queuedOutOfControlTurns
        p.queuedOutOfControlTurns = 0
        RoguemonStreamer.addAnimation(RoguemonStreamer.createBannerAnimation("OUT OF CONTROL", "FF8000", true))
        print(string.format("[RogueMon Streamer] Priority Pop (Mid-Battle): Activated Out of Control for %d turns.", p.outOfControlTurns))
        RoguemonStreamer.saveSettings()
    elseif p.queuedOverwhelmedCount and p.queuedOverwhelmedCount > 0 then
        p.overwhelmedActive = p.queuedOverwhelmedCount
        p.queuedOverwhelmedCount = 0
        RoguemonStreamer.saveSettings()
        RoguemonStreamer.addAnimation(RoguemonStreamer.createBannerAnimation("OVERWHELMED", "FF0000", true))
        print(string.format("[RogueMon Streamer] Priority Pop (Mid-Battle): Activated Overwhelmed (+1 PP) for %d battles.", p.overwhelmedActive))
    elseif p.queuedDisableTurns and #p.queuedDisableTurns > 0 then
        local item = table.remove(p.queuedDisableTurns, 1)
        local partyMoves = getPartyMonMoves(activeIdx)
        local moves = {}
        for _, m in ipairs(partyMoves) do
            if m and m > 0 then
                table.insert(moves, m)
            end
        end
        if #moves > 0 then
            p.disabledMoveId = moves[RoguemonStreamer.random(#moves)]
            p.disabledMoveTurns = item.turns
            p.disabledMoveApplied = false
            RoguemonStreamer.saveSettings()
            print(string.format("[RogueMon Streamer] Priority Pop (Mid-Battle): Activated Disable Move: Move %d (%d turns).", p.disabledMoveId, p.disabledMoveTurns))
        end
    end
end
-- BATTLE HOOK OPERATIONS
function RoguemonStreamer.afterEachFrame()
    if not RoguemonStreamer.initialized or not RoguemonStreamer.settings.enabled then
        return
    end

    -- Dynamically register the battle outcome watch once the ROM is loaded
    if GameSettings and GameSettings.gBattleOutcome and not RoguemonStreamer.outcomeWatchRegistered then
        pcall(event.unregisterbyname, "RoguemonStreamer_gBattleOutcome")
        event.onmemorywrite(function(addr, value, size)
            if value and value > 0 then
                RoguemonStreamer.lastBattleOutcome = value
                RoguemonStreamer.ActiveStatBuffsAppliedThisBattle = false
                local activeIdx = getActivePartyIndex()
                if RoguemonStreamer.MovesOverwritten then
                    RoguemonStreamer.restoreOriginalMoves(activeIdx)
                end

                -- Decrement final turn for Out of Control if not already done for this turn
                local currentTurn = Battle.turnCount or 0
                if RoguemonStreamer.settings and RoguemonStreamer.settings.persistent then
                    local p = RoguemonStreamer.settings.persistent
                    if p.outOfControlTurns and p.outOfControlTurns > 0 and RoguemonStreamer.battleIntroFinished then
                        -- The in-battle decrement always runs 1 turn LATE (at the action selection of turn N+1).
                        -- So when the battle ends at turn N, the decrement for turn N is always pending.
                        -- We always need exactly 1 more decrement here, regardless of lastOocDecrementTurn.
                        p.outOfControlTurns = p.outOfControlTurns - 1
                        print(string.format("[RogueMon Streamer] Outcome Watch: Decremented Out of Control final turn (remaining: %d).", p.outOfControlTurns))
                    end
                    if p.disabledMoveTurns and p.disabledMoveTurns > 0 and RoguemonStreamer.battleIntroFinished then
                        -- Same logic as Out of Control: decrement for the final turn is always pending.
                        p.disabledMoveTurns = p.disabledMoveTurns - 1
                        print(string.format("[RogueMon Streamer] Outcome Watch: Decremented Disable Move final turn (remaining: %d).", p.disabledMoveTurns))
                    end
                    RoguemonStreamer.saveSettings()
                end

                print(string.format("[RogueMon Streamer] Memory Watch: Captured outcome: %d", value))
            end
        end, GameSettings.gBattleOutcome, "RoguemonStreamer_gBattleOutcome", "System Bus")
        RoguemonStreamer.outcomeWatchRegistered = true
        print("[RogueMon Streamer] Dynamically registered gBattleOutcome memory watch.")
    end

    if Battle.inActiveBattle() and isActionSelectionPhaseActive() then
        if RoguemonStreamer.settings and RoguemonStreamer.settings.persistent then
            RoguemonStreamer.lastActiveOocTurns = RoguemonStreamer.settings.persistent.outOfControlTurns
            RoguemonStreamer.lastActiveDisableTurns = RoguemonStreamer.settings.persistent.disabledMoveTurns
            RoguemonStreamer.lastActiveDisableId = RoguemonStreamer.settings.persistent.disabledMoveId
        end
    end
    -- No Guard Plus / Minus active move accuracy override in ROM table
    local currentMove = 0
    if Battle.inActiveBattle() and GameSettings.gCurrentMove then
        currentMove = Memory.readword(GameSettings.gCurrentMove) or 0
    end
    if currentMove > 0 and currentMove < 1000 then
        if RoguemonStreamer.settings and RoguemonStreamer.settings.persistent then
            local plus = RoguemonStreamer.settings.persistent.noGuardPlusActive
            local minus = RoguemonStreamer.settings.persistent.noGuardMinusActive
            
            if plus or minus then
                local attacker = Memory.readbyte(GameSettings.gBattlerAttacker or 0) % 4
                local isPlayer = (attacker == 0 or attacker == 2)
                
                local shouldOverride = false
                if isPlayer and plus then
                    local partyIdx = getActivePartyIndex()
                    if partyIdx == 1 then
                        shouldOverride = true
                    end
                elseif not isPlayer and minus then
                    shouldOverride = true
                end
                
                if shouldOverride then
                    local sizeofBattleMove = GameSettings.sizeofBattleMove or 12
                    local accuracyOffset = GameSettings.moveInfoAccuracyTargetOffset or 3
                    local accuracyMask = GameSettings.moveInfoAccuracyMask or 0xFF
                    
                    local moveAddr = GameSettings.gBattleMoves + (currentMove * sizeofBattleMove) + accuracyOffset
                    local originalWord = Memory.readword(moveAddr)
                    if originalWord then
                        local originalAccuracy = originalWord & accuracyMask
                        if originalAccuracy and originalAccuracy > 0 then
                            RoguemonStreamer.originalMoveAccuracies = RoguemonStreamer.originalMoveAccuracies or {}
                            if not RoguemonStreamer.originalMoveAccuracies[currentMove] then
                                RoguemonStreamer.originalMoveAccuracies[currentMove] = originalWord
                            end
                            -- Clear the accuracy bits in the ROM word (set accuracy to 0, never miss)
                            local clearedWord = originalWord & (~accuracyMask)
                            Memory.writeword(moveAddr, clearedWord)
                            
                            local checkWord = Memory.readword(moveAddr)
                            local f = io.open("c:\\Users\\nitro\\Desktop\\RogueMON\\Ironmon-Tracker\\debug_noguard.txt", "a")
                            if f then
                                f:write(string.format("ROM write to 0x%X: originalWord=0x%04X (acc=%d), clearedWord=0x%04X, readBack=0x%04X (acc=%d)\n", 
                                    moveAddr, originalWord, originalAccuracy, clearedWord, checkWord or 0, (checkWord or 0) & accuracyMask))
                                f:close()
                            end
                        end
                    end
                end
            end
        end
    else
        -- Restore original accuracies when no move is active (or battle ends)
        if RoguemonStreamer.originalMoveAccuracies then
            local sizeofBattleMove = GameSettings.sizeofBattleMove or 12
            local accuracyOffset = GameSettings.moveInfoAccuracyTargetOffset or 3
            for moveId, originalWord in pairs(RoguemonStreamer.originalMoveAccuracies) do
                local moveAddr = GameSettings.gBattleMoves + (moveId * sizeofBattleMove) + accuracyOffset
                Memory.writeword(moveAddr, originalWord)
            end
            RoguemonStreamer.originalMoveAccuracies = nil
        end
    end

    if not Battle.inActiveBattle() then
        RoguemonStreamer.prevActivePPs = nil
    else
        -- PP monitor for Overwhelmed
        if RoguemonStreamer.settings and RoguemonStreamer.settings.persistent and RoguemonStreamer.settings.persistent.overwhelmedActive then
            local getActiveMonPPs = function()
                local pps = {}
                local slots = { Battle.Combatants.LeftOwn }
                if Battle.numBattlers == 4 then
                    table.insert(slots, Battle.Combatants.RightOwn)
                end
                for _, slotIdx in ipairs(slots) do
                    local bAddr = getBattleMonsAddress(slotIdx)
                    if bAddr then
                        local ppOff = getBattlePpOffset()
                        pps[slotIdx] = {
                            Memory.readbyte(bAddr + ppOff),
                            Memory.readbyte(bAddr + ppOff + 1),
                            Memory.readbyte(bAddr + ppOff + 2),
                            Memory.readbyte(bAddr + ppOff + 3),
                        }
                    end
                end
                return pps
            end

            local currentPPs = getActiveMonPPs()
            if RoguemonStreamer.prevActivePPs then
                for slotIdx, pps in pairs(currentPPs) do
                    if slotIdx == 1 then
                        local prevPPs = RoguemonStreamer.prevActivePPs[slotIdx]
                        if prevPPs then
                        for moveSlot = 1, 4 do
                            local oldPP = prevPPs[moveSlot] or 0
                            local newPP = pps[moveSlot] or 0
                            local diff = oldPP - newPP
                            if diff > 0 and oldPP <= 64 then
                                -- Move used! Find if enemy has Pressure (ability ID 46)
                                local enemyHasPressure = false
                                local enemySlots = { Battle.Combatants.LeftEnemy }
                                if Battle.numBattlers == 4 then
                                    table.insert(enemySlots, Battle.Combatants.RightEnemy)
                                end
                                for _, eSlot in ipairs(enemySlots) do
                                    local eAddr = getBattleMonsAddress(eSlot)
                                    if eAddr then
                                        local abilityOffset = RoguemonStreamer.getBattleAbilityOffset()
                                        local eAbility = Memory.readword(eAddr + abilityOffset)
                                        if eAbility == 46 then
                                            enemyHasPressure = true
                                            break
                                        end
                                    end
                                end

                                local targetDeduct = enemyHasPressure and 3 or 2
                                if diff < targetDeduct then
                                    local extra = targetDeduct - diff
                                    local finalPP = math.max(0, newPP - extra)
                                    local bAddr = getBattleMonsAddress(slotIdx)
                                    local ppOff = getBattlePpOffset()
                                    Memory.writebyte(bAddr + ppOff + (moveSlot - 1), finalPP)

                                    -- party PP
                                    local partyIdx = slotIdx
                                    if partyIdx and partyIdx >= 1 and partyIdx <= 6 then
                                        RoguemonStreamer.deductPartyPP(partyIdx, moveSlot, extra)
                                    end

                                    pps[moveSlot] = finalPP
                                    print(string.format("[RogueMon Streamer] Overwhelmed: Move used. Enemy Pressure=%s. Deducted extra %d PP. New PP: %d", tostring(enemyHasPressure), extra, finalPP))
                                end
                            end
                        end
                    end
                end
            end
            end
            RoguemonStreamer.prevActivePPs = currentPPs
        else
            RoguemonStreamer.prevActivePPs = nil
        end
    end

    if Battle.inActiveBattle() then
        local battleMonsAddress = GameSettings.gBattleMons
        if battleMonsAddress then
            local statStageOffset = GameSettings.offsetBattlePokemonStatStages or 0x18
            local atkStage = Memory.readbyte(battleMonsAddress + statStageOffset + 1)
            local defStage = Memory.readbyte(battleMonsAddress + statStageOffset + 2)
            local speStage = Memory.readbyte(battleMonsAddress + statStageOffset + 3)
            local key = string.format("atk=%d,def=%d,spe=%d", atkStage, defStage, speStage)
            if key ~= RoguemonStreamer.lastLoggedStatsKey then
                RoguemonStreamer.lastLoggedStatsKey = key
                logDebug(string.format("RAM Watch: Stats stages changed to: ATK=%d, DEF=%d, SPE=%d", atkStage, defStage, speStage))
            end
        end
    end

    -- Automatic Reset on Game Over screen display
    if Program and Program.currentScreen == GameOverScreen then
        if not RoguemonStreamer.gameOverResetPerformed then
            print("[RogueMon Streamer] GameOverScreen is displayed. Resetting run state.")
            RoguemonStreamer.resetRunState(true) -- silent reset
            RoguemonStreamer.gameOverResetPerformed = true
        end
    else
        RoguemonStreamer.gameOverResetPerformed = false
    end

    -- Self-heal wrappers
    wrapGetPokemonTypes()
    wrapBuildTrackerScreenDisplay()
    wrapBuildPokemonInfoDisplay()
    wrapDrawMovesArea()
    wrapGetAbilityId()
    wrapGetEffectiveness()
    wrapCheckForGameOver()

    -- Helper to check if the action selection menu is open (excluding FireRed specific hardcoded RAM checks)
    local function isMenuOpen()
        if not Battle.inActiveBattle() then
            return false
        end
        -- Delay check during battle transition to avoid premature frame-1 trigger
        -- when gBattleMainFunc holds the pointer from the previous battle's final frame.
        if (RoguemonStreamer.battleFrameCount or 0) < 60 then
            return false
        end
        if not GameSettings.gBattleMainFunc or not GameSettings.HandleTurnActionSelectionState then
            return false
        end
        local mainFunc = Memory.readdword(GameSettings.gBattleMainFunc)
        local target = GameSettings.HandleTurnActionSelectionState
        return (math.floor(mainFunc / 2) == math.floor(target / 2))
            or (math.floor(mainFunc / 2) == math.floor(0x806D17C / 2))
    end

    -- Apply custom abilities in GBA battle RAM for all active player battlers
    if Battle.inActiveBattle() and (RoguemonStreamer.battleTurnCount or 0) == 0 and RoguemonStreamer.settings and RoguemonStreamer.settings.alteredAbilities then
        RoguemonStreamer.appliedBattleAbilities = RoguemonStreamer.appliedBattleAbilities or {}
        local slots = { Battle.Combatants.LeftOwn }
        if Battle.numBattlers == 4 then
            table.insert(slots, Battle.Combatants.RightOwn)
        end
        for _, slotIdx in ipairs(slots) do
            if slotIdx and slotIdx >= 1 and slotIdx <= 6 then
                local bAddr = getBattleMonsAddress(slotIdx)
                if bAddr then
                    local mon = Tracker.getPokemon(slotIdx, true)
                    if mon and mon.personality then
                        local phex = string.format("0x%X", mon.personality)
                        local altered = RoguemonStreamer.settings.alteredAbilities[phex]
                        if altered then
                            local abilityOffset = RoguemonStreamer.getBattleAbilityOffset()
                            Memory.writeword(bAddr + abilityOffset, altered)
                            if not RoguemonStreamer.appliedBattleAbilities[slotIdx] then
                                logDebug(string.format("[RogueMon Streamer] Applied custom ability in Battle RAM for slot %d: %d", slotIdx, altered))
                                RoguemonStreamer.appliedBattleAbilities[slotIdx] = true
                            end
                        else
                            RoguemonStreamer.appliedBattleAbilities[slotIdx] = true
                        end
                    end
                end
            end
        end
    end

    -- Apply permanent type changes in GBA battle RAM for all active player battlers.
    -- Write only when the action selection menu is open to ensure the GBA engine's
    -- send-out copy operation has finished, preserving priority for mid-battle modifications (e.g. Soak).
    if Battle.inActiveBattle() and (RoguemonStreamer.battleTurnCount or 0) == 0 and RoguemonStreamer.settings and RoguemonStreamer.settings.alteredTypes then
        RoguemonStreamer.appliedAlteredTypes = RoguemonStreamer.appliedAlteredTypes or {}
        local slots = { Battle.Combatants.LeftOwn }
        if Battle.numBattlers == 4 then
            table.insert(slots, Battle.Combatants.RightOwn)
        end
        for _, slotIdx in ipairs(slots) do
            if slotIdx and slotIdx >= 1 and slotIdx <= 6 then
                local bAddr = getBattleMonsAddress(slotIdx)
                if bAddr then
                    local mon = Tracker.getPokemon(slotIdx, true)
                    if mon and mon.personality then
                        local personalityHex = string.format("0x%X", mon.personality)
                        local altered = RoguemonStreamer.settings.alteredTypes[personalityHex]
                        if altered then
                            local t1, t2 = altered[1], altered[2]
                            local battleSlot = RoguemonStreamer.getBattleSlot(slotIdx)
                            if battleSlot ~= nil then
                                RoguemonStreamer.writeAlteredTypesToBattle(battleSlot, t1, t2)
                                if not RoguemonStreamer.appliedAlteredTypes[slotIdx] then
                                    logDebug(string.format("[RogueMon Streamer] Applied permanent altered types in Battle RAM for slot %d: %d/%d", slotIdx, t1, t2))
                                    RoguemonStreamer.appliedAlteredTypes[slotIdx] = true
                                end
                            end
                        else
                            RoguemonStreamer.appliedAlteredTypes[slotIdx] = true
                        end
                    end
                end
            end
        end
    end

    local activeIdx = getActivePartyIndex()
    local partyAddress = GameSettings.pstats + (activeIdx - 1) * 100

    local inBattle = Battle.inActiveBattle()
    if not inBattle then
        RoguemonStreamer.queuedEventAppliedThisBattle = false
        RoguemonStreamer.queuedBattleEventsChecked = false
        RoguemonStreamer.battlePpSyncedThisCombat = false
        RoguemonStreamer.lastDecrementTurn = -1
        RoguemonStreamer.lastOocDecrementTurn = 0
        RoguemonStreamer.appliedBattleAbilities = {}
        RoguemonStreamer.appliedAlteredTypes = {}
        RoguemonStreamer.trickRoomToggledOff = false
        RoguemonStreamer.battleIntroFinished = false
        RoguemonStreamer.battleFrameCount = 0
        RoguemonStreamer.battleTurnCount = 0
        RoguemonStreamer.wasMenuOpen = false
    else
        RoguemonStreamer.battleFrameCount = (RoguemonStreamer.battleFrameCount or 0) + 1
        if isActionSelectionPhaseActive() then
            RoguemonStreamer.battleIntroFinished = true
        end

        local menuOpen = isMenuOpen()
        if RoguemonStreamer.wasMenuOpen and not menuOpen then
            RoguemonStreamer.battleTurnCount = (RoguemonStreamer.battleTurnCount or 0) + 1
        end
        RoguemonStreamer.wasMenuOpen = menuOpen
    end

    if inBattle and Battle.dataReady and not RoguemonStreamer.queuedBattleEventsChecked then
        if RoguemonStreamer.checkAndPopQueuedBattleEvents() then
            RoguemonStreamer.queuedBattleEventsChecked = true
        end
    end

    local isAnyActive = RoguemonStreamer.isAnyNegativeEventActive()
    local canApplyQueued = inBattle and Battle.dataReady and activeIdx == 1 and not RoguemonStreamer.queuedEventAppliedThisBattle and not isAnyActive
    local queuedApplied = false

    if canApplyQueued then
        -- Process queued Statuses (trainer or overworld, as long as status is 0 and Pokemon is alive)
        local queuedStat = RoguemonStreamer.settings.persistent.queuedStatuses or {}
        if #queuedStat > 0 then
            local currentStatus = Memory.readdword(partyAddress + 0x50)
            local curHP = Memory.readword(partyAddress + 0x54 + 2)
            if currentStatus == 0 and curHP > 0 then
                local nextStatus = table.remove(queuedStat, 1)
                RoguemonStreamer.settings.persistent.queuedStatuses = queuedStat
                RoguemonStreamer.saveSettings()
                
                Memory.writedword(partyAddress + 0x50, nextStatus)
                
                if inBattle then
                    local battleSlot = RoguemonStreamer.getBattleSlot(activeIdx)
                    if battleSlot ~= nil then
                        local battleMonsAddress = GameSettings.gBattleMons + (battleSlot * (GameSettings.sizeofBattlePokemon or 0x58))
                        Memory.writedword(battleMonsAddress + getBattleStatus1Offset(), nextStatus)
                    end
                    RoguemonStreamer.queuedEventAppliedThisBattle = true
                end
                local statusNames = { [4] = "Sleep", [8] = "Poison", [16] = "Burn", [32] = "Freeze", [64] = "Paralysis" }
                local statusName = statusNames[nextStatus] or "Status"
                print(string.format("[RogueMon Streamer] Applied queued Status: %s", statusName))
                refreshTracker()
            end
        end
    end

    if Battle.inActiveBattle() then
        -- If the battle has already ended, skip battle updates to prevent state flip-flops during fadeout
        if RoguemonStreamer.lastBattleOutcome and RoguemonStreamer.lastBattleOutcome > 0 then
            return
        end
        -- Track switch-out and restore moves immediately to prevent permanent party overwrite
        if RoguemonStreamer.prevActiveIdx and RoguemonStreamer.prevActiveIdx ~= activeIdx then
            if RoguemonStreamer.MovesOverwritten then
                RoguemonStreamer.restoreOriginalMoves(RoguemonStreamer.prevActiveIdx)
            end
            RoguemonStreamer.settings.persistent.tempTypeApplied = false
            if RoguemonStreamer.appliedBattleAbilities then
                RoguemonStreamer.appliedBattleAbilities[RoguemonStreamer.prevActiveIdx] = nil
            end
            if RoguemonStreamer.appliedAlteredTypes then
                RoguemonStreamer.appliedAlteredTypes[RoguemonStreamer.prevActiveIdx] = nil
            end
            RoguemonStreamer.battleTurnCount = 0
            RoguemonStreamer.wasMenuOpen = false
        end
        RoguemonStreamer.prevActiveIdx = activeIdx

        -- Pop next queued event mid-battle if no event is active
        if not RoguemonStreamer.isAnyNegativeEventActive() then
            RoguemonStreamer.popNextQueuedBattleEvent()
        end

        local mainFunc = Memory.readdword(GameSettings.gBattleMainFunc)
        local battleSlot = RoguemonStreamer.getBattleSlot(activeIdx)
        local battleMonsAddress = nil
        if battleSlot ~= nil then
            battleMonsAddress = GameSettings.gBattleMons + (battleSlot * (GameSettings.sizeofBattlePokemon or 0x58))
        end

        -- Apply queued confusion on battle start (when action selection state is active)
        if RoguemonStreamer.settings.persistent.queuedConfusion then
            if isActionSelectionPhaseActive() then
                if battleSlot ~= nil and GameSettings.battleVolatilesOffset then
                    local volBase = battleMonsAddress + GameSettings.battleVolatilesOffset
                    local vol1 = Memory.readdword(volBase)
                    vol1 = Utils.bit_and(vol1, 0xFFFFFFF8) + 4 -- 4 turns of confusion
                    Memory.writedword(volBase, vol1)
                    
                    RoguemonStreamer.settings.persistent.queuedConfusion = false
                    RoguemonStreamer.saveSettings()
                    print("[RogueMon Streamer] - Applied queued confusion on battle turn action selection start")
                end
            end
        end

        -- Apply active disabled move in GBA battle RAM
        local disabledMoveId = RoguemonStreamer.settings.persistent.disabledMoveId
        local disabledTurns = RoguemonStreamer.settings.persistent.disabledMoveTurns or 0
        if disabledMoveId and disabledMoveId > 0 and disabledTurns > 0 and RoguemonStreamer.battleIntroFinished then
            if activeIdx == 1 then
                if battleSlot ~= nil then
                    local structSize = GameSettings.disableStructEntrySize
                    if GameSettings.gDisableStructs and structSize and GameSettings.disabledMoveOffset and GameSettings.disableTimerOffset then
                        local base = GameSettings.gDisableStructs + battleSlot * structSize
                        local currentDisabledMove = Memory.readword(base + GameSettings.disabledMoveOffset)
                        if currentDisabledMove ~= disabledMoveId then
                            Memory.writeword(base + GameSettings.disabledMoveOffset, disabledMoveId)
                            Memory.writeword(base + GameSettings.disableTimerOffset, disabledTurns)
                            print(string.format("[RogueMon Streamer] Applied Disable Move in Battle RAM: Move %d (%d turns)", disabledMoveId, disabledTurns))
                        end
                    end
                end
                RoguemonStreamer.settings.persistent.disabledMoveApplied = true
            else
                if RoguemonStreamer.settings.persistent.disabledMoveApplied then
                    RoguemonStreamer.settings.persistent.disabledMoveApplied = false
                end
            end
        end

        -- Decrement active disabled move turn count
        if activeIdx == 1 and disabledMoveId and disabledMoveId > 0 and disabledTurns > 0 and RoguemonStreamer.battleIntroFinished then
            RoguemonStreamer.lastDecrementTurn = RoguemonStreamer.lastDecrementTurn or -1
            local currentTurn = Battle.turnCount or 0
            if currentTurn > RoguemonStreamer.lastDecrementTurn then
                RoguemonStreamer.lastDecrementTurn = currentTurn
                RoguemonStreamer.settings.persistent.disabledMoveTurns = RoguemonStreamer.settings.persistent.disabledMoveTurns - 1
                if RoguemonStreamer.settings.persistent.disabledMoveTurns <= 0 then
                    -- Active disabled move expired! Pop the next queued disable only if no higher-priority event is queued
                    local hasHigherQueued = (RoguemonStreamer.settings.persistent.queuedOutOfControlTurns and RoguemonStreamer.settings.persistent.queuedOutOfControlTurns > 0) or (RoguemonStreamer.settings.persistent.queuedOverwhelmedCount and RoguemonStreamer.settings.persistent.queuedOverwhelmedCount > 0)
                    local queued = RoguemonStreamer.settings.persistent.queuedDisableTurns or {}
                    if #queued > 0 and not hasHigherQueued then
                        local nextItem = table.remove(queued, 1)
                        RoguemonStreamer.settings.persistent.queuedDisableTurns = queued
                        
                        -- Pick a new random move
                        local moves = {}
                        if battleMonsAddress ~= nil then
                            for i = 1, 4 do
                                local m = Memory.readword(battleMonsAddress + 0x0C + (i - 1) * 2)
                                if m and m > 0 then
                                    table.insert(moves, m)
                                end
                            end
                        else
                            local partyMoves = getPartyMonMoves(activeIdx)
                            for _, m in ipairs(partyMoves) do
                                if m and m > 0 then
                                    table.insert(moves, m)
                                end
                            end
                        end
                        if #moves > 0 then
                            RoguemonStreamer.settings.persistent.disabledMoveId = moves[RoguemonStreamer.random(#moves)]
                            RoguemonStreamer.settings.persistent.disabledMoveTurns = nextItem.turns
                            RoguemonStreamer.settings.persistent.disabledMoveApplied = false
                            print(string.format("[RogueMon Streamer] Active disable expired. Next queued disable triggered: Move %d for %d turns", RoguemonStreamer.settings.persistent.disabledMoveId, nextItem.turns))
                        else
                            RoguemonStreamer.settings.persistent.disabledMoveId = nil
                            RoguemonStreamer.settings.persistent.disabledMoveTurns = nil
                            RoguemonStreamer.settings.persistent.disabledMoveApplied = nil
                        end
                    else
                        RoguemonStreamer.settings.persistent.disabledMoveId = nil
                        RoguemonStreamer.settings.persistent.disabledMoveTurns = nil
                        RoguemonStreamer.settings.persistent.disabledMoveApplied = nil
                        print("[RogueMon Streamer] Disable Move expired and no queued disables triggered.")
                    end
                end
                RoguemonStreamer.saveSettings()
                refreshTracker()
            end
        end

        -- Apply temp type changes in battle
        local tempTypes = RoguemonStreamer.settings.persistent.tempTypeChange
        if tempTypes and #tempTypes == 2 and isActionSelectionPhaseActive() then
            if activeIdx == 1 then
                if not RoguemonStreamer.settings.persistent.tempTypeApplied then
                    if battleSlot ~= nil then
                        RoguemonStreamer.writeAlteredTypesToBattle(battleSlot, tempTypes[1], tempTypes[2])
                        logDebug(string.format("[RogueMon Streamer] Applied Temp Type Change in Battle: %d/%d", tempTypes[1], tempTypes[2]))
                        RoguemonStreamer.settings.persistent.tempTypeApplied = true
                    end
                end
            else
                if RoguemonStreamer.settings.persistent.tempTypeApplied then
                    RoguemonStreamer.settings.persistent.tempTypeApplied = false
                end
            end
        end

        -- Apply persistent battle stat buffs at the start of combat (cumulatively, capped at -6/+6)
        if isActionSelectionPhaseActive() then
            if activeIdx == 1 then
                if not RoguemonStreamer.ActiveStatBuffsAppliedThisBattle then
                    if battleMonsAddress then
                        RoguemonStreamer.applyStatBuffsToBattle(true)
                        RoguemonStreamer.ActiveStatBuffsAppliedThisBattle = true
                        RoguemonStreamer.ActiveStatBuffsApplied = true
                    end
                end
            else
                if RoguemonStreamer.ActiveStatBuffsAppliedThisBattle then
                    RoguemonStreamer.ActiveStatBuffsAppliedThisBattle = false
                end
            end
        end

        -- Mark No Guard Plus / Minus as applied in battle (for cleanup later)
        if activeIdx == 1 then
            if RoguemonStreamer.settings.persistent.noGuardPlusActive then
                RoguemonStreamer.settings.persistent.noGuardPlusApplied = true
            end
            if RoguemonStreamer.settings.persistent.noGuardMinusActive then
                RoguemonStreamer.settings.persistent.noGuardMinusApplied = true
            end
        end

        -- Apply Game Changer (Focus Energy/Dire Hit flag) in battle
        if RoguemonStreamer.settings.persistent.gameChangerActive and RoguemonStreamer.settings.persistent.gameChangerActive > 0 then
            if activeIdx == 1 and battleMonsAddress ~= nil then
                local volOffset = GameSettings.battleVolatilesOffset or 0x50
                local status3 = Memory.readdword(battleMonsAddress + volOffset + 4) or 0
                if Utils.bit_and(status3, 0x00008000) == 0 then
                    status3 = Utils.bit_or(status3, 0x00008000)
                    Memory.writedword(battleMonsAddress + volOffset + 4, status3)
                    logDebug("[RogueMon Streamer] Applied Game Changer (Focus Energy/Dire Hit flag) in battle RAM.")
                end
                if not RoguemonStreamer.settings.persistent.gameChangerApplied then
                    RoguemonStreamer.addAnimation(RoguemonStreamer.createBannerAnimation("GAME CHANGER", "00FF00", false))
                    RoguemonStreamer.settings.persistent.gameChangerApplied = true
                    RoguemonStreamer.saveSettings()
                end
            end
        end

        -- Apply Try Harder (Mist/Guard Spec flag) in battle
        if RoguemonStreamer.settings.persistent.tryHarderActive and RoguemonStreamer.settings.persistent.tryHarderActive > 0 then
            local gSideS = GameSettings.gSideStatuses
            local gSideT = GameSettings.gSideTimers
            if gSideS and gSideS ~= 0 and gSideT and gSideT ~= 0 then
                local sideStatuses = Memory.readword(gSideS) or 0
                if Utils.bit_and(sideStatuses, 0x0100) == 0 then
                    sideStatuses = Utils.bit_or(sideStatuses, 0x0100)
                    Memory.writeword(gSideS, sideStatuses)
                end
                Memory.writebyte(gSideT + 0x04, 5) -- Set mistTimer to 5 to keep it active
                
                if not RoguemonStreamer.settings.persistent.tryHarderApplied then
                    RoguemonStreamer.addAnimation(RoguemonStreamer.createBannerAnimation("TRY HARDER", "00FF00", false))
                    RoguemonStreamer.settings.persistent.tryHarderApplied = true
                    RoguemonStreamer.saveSettings()
                    print("[RogueMon Streamer] Applied Try Harder (Mist/Guard Spec) in battle RAM.")
                end
            end
        end

        -- Apply Mystification (Trick Room) in battle
        if RoguemonStreamer.settings.persistent.mystificationActive and RoguemonStreamer.settings.persistent.mystificationActive > 0 then
            local fsAddr = GameSettings.fieldStatusesAddr
            local ftAddr = GameSettings.fieldTimersAddr
            local ftOff = GameSettings.fieldTimerTerrainOffset
            if fsAddr and fsAddr ~= 0 and ftAddr and ftAddr ~= 0 and ftOff then
                local fs = Memory.readdword(fsAddr) or 0
                local isTRActive = (Utils.bit_and(fs, 0x02) ~= 0)
                
                if not isTRActive then
                    -- Not yet applied: cast it!
                    fs = Utils.bit_or(fs, 0x02)
                    Memory.writedword(fsAddr, fs)
                    -- Targeted write to Trick Room timer to avoid out-of-bounds corruption
                    if ftOff == 12 then
                        Memory.writeword(ftAddr + 8, 5)
                    elseif ftOff == 6 then
                        Memory.writebyte(ftAddr + 4, 5)
                    else
                        local off16 = ftOff - 4
                        local off8 = ftOff - 2
                        if off16 >= 0 then Memory.writebyte(ftAddr + off16, 5) end
                        if off8 >= 0 then Memory.writebyte(ftAddr + off8, 5) end
                    end
                    if not RoguemonStreamer.settings.persistent.mystificationApplied then
                        RoguemonStreamer.addAnimation(RoguemonStreamer.createBannerAnimation("MYSTIFICATION", "FF0000", true))
                        RoguemonStreamer.settings.persistent.mystificationApplied = true
                        RoguemonStreamer.saveSettings()
                        print("[RogueMon Streamer] Mystification cast Trick Room (flag & timer set).")
                    end
                else
                    -- Keep Trick Room timer at 5 so it lasts all fight (targeted write)
                    if ftOff == 12 then
                        Memory.writeword(ftAddr + 8, 5)
                    elseif ftOff == 6 then
                        Memory.writebyte(ftAddr + 4, 5)
                    else
                        local off16 = ftOff - 4
                        local off8 = ftOff - 2
                        if off16 >= 0 then Memory.writebyte(ftAddr + off16, 5) end
                        if off8 >= 0 then Memory.writebyte(ftAddr + off8, 5) end
                    end
                    if not RoguemonStreamer.settings.persistent.mystificationApplied then
                        RoguemonStreamer.addAnimation(RoguemonStreamer.createBannerAnimation("MYSTIFICATION", "FF0000", true))
                        RoguemonStreamer.settings.persistent.mystificationApplied = true
                        RoguemonStreamer.saveSettings()
                    end
                end
            end
        end



        -- Handle Out of Control move selection overwrite
        local turnsLeft = RoguemonStreamer.settings.persistent.outOfControlTurns or 0
        if turnsLeft > 0 and RoguemonStreamer.battleIntroFinished then
            if isActionSelectionPhaseActive() then
                RoguemonStreamer.OocTurnApplied = false
                if RoguemonStreamer.MovesOverwritten or RoguemonStreamer.OocFlinched then
                    RoguemonStreamer.restoreOriginalMoves(activeIdx)
                end
            else
                if not RoguemonStreamer.OocTurnApplied then
                    RoguemonStreamer.applyOutOfControlOverwrite(activeIdx)
                    RoguemonStreamer.OocTurnApplied = true
                end
            end
        else
            -- Out of Control expired or not active, make sure original moves are restored!
            if RoguemonStreamer.MovesOverwritten or RoguemonStreamer.OocFlinched then
                RoguemonStreamer.restoreOriginalMoves(activeIdx)
            end
        end

        -- Decrement active Out of Control turn count (exactly like Disable Move!)
        if activeIdx == 1 and turnsLeft > 0 and RoguemonStreamer.battleIntroFinished then
            RoguemonStreamer.lastOocDecrementTurn = RoguemonStreamer.lastOocDecrementTurn or 0
            local currentTurn = Battle.turnCount or 0
            if currentTurn > RoguemonStreamer.lastOocDecrementTurn then
                RoguemonStreamer.lastOocDecrementTurn = currentTurn
                RoguemonStreamer.settings.persistent.outOfControlTurns = RoguemonStreamer.settings.persistent.outOfControlTurns - 1
                RoguemonStreamer.saveSettings()
                print(string.format("[RogueMon Streamer] Decremented Out of Control turns (remaining: %d).", RoguemonStreamer.settings.persistent.outOfControlTurns))
            end
        end
    else
        -- Clean up if we exited battle abruptly
        RoguemonStreamer.isTrickRoomActivePrev = false
        RoguemonStreamer.ActiveStatBuffsAppliedThisBattle = false
        if not Battle.inBattleScreen then
            if RoguemonStreamer.MovesOverwritten then
                RoguemonStreamer.restoreOriginalMoves(activeIdx)
            end

            local wasEscape = (RoguemonStreamer.lastBattleOutcome == 3 or RoguemonStreamer.lastBattleOutcome == 4 or RoguemonStreamer.lastBattleOutcome == 5)

            if wasEscape then
                if RoguemonStreamer.lastActiveOocTurns and RoguemonStreamer.lastActiveOocTurns > 0 then
                    RoguemonStreamer.settings.persistent.outOfControlTurns = RoguemonStreamer.lastActiveOocTurns
                    print(string.format("[RogueMon Streamer] Escaped battle. Restored Out of Control turns to %d.", RoguemonStreamer.lastActiveOocTurns))
                end
                if RoguemonStreamer.lastActiveDisableTurns and RoguemonStreamer.lastActiveDisableTurns > 0 then
                    RoguemonStreamer.settings.persistent.disabledMoveTurns = RoguemonStreamer.lastActiveDisableTurns
                    RoguemonStreamer.settings.persistent.disabledMoveId = RoguemonStreamer.lastActiveDisableId
                    RoguemonStreamer.settings.persistent.disabledMoveApplied = false
                    print(string.format("[RogueMon Streamer] Escaped battle. Restored Disable Move to ID %s for %d turns.", tostring(RoguemonStreamer.lastActiveDisableId), RoguemonStreamer.lastActiveDisableTurns))
                end
                RoguemonStreamer.saveSettings()
            end
            
            RoguemonStreamer.lastActiveOocTurns = nil
            RoguemonStreamer.lastActiveDisableTurns = nil
            RoguemonStreamer.lastActiveDisableId = nil

            -- Clean up No Guard Plus / Minus after battle
            if RoguemonStreamer.settings.persistent.noGuardPlusApplied then
                if not wasEscape then
                    local count = RoguemonStreamer.settings.persistent.noGuardPlusActive
                    if type(count) == "number" then
                        local rem = count - 1
                        if rem <= 0 then
                            RoguemonStreamer.settings.persistent.noGuardPlusActive = nil
                        else
                            RoguemonStreamer.settings.persistent.noGuardPlusActive = rem
                        end
                    else
                        RoguemonStreamer.settings.persistent.noGuardPlusActive = nil
                    end
                    print("[RogueMon Streamer] Cleared/decremented No Guard Plus after battle.")
                else
                    print("[RogueMon Streamer] No Guard Plus preserved (escape).")
                end
                RoguemonStreamer.settings.persistent.noGuardPlusApplied = nil
                RoguemonStreamer.saveSettings()
            end
            if RoguemonStreamer.settings.persistent.noGuardMinusApplied then
                if not wasEscape then
                    local count = RoguemonStreamer.settings.persistent.noGuardMinusActive
                    if type(count) == "number" then
                        local rem = count - 1
                        if rem <= 0 then
                            RoguemonStreamer.settings.persistent.noGuardMinusActive = nil
                        else
                            RoguemonStreamer.settings.persistent.noGuardMinusActive = rem
                        end
                    else
                        RoguemonStreamer.settings.persistent.noGuardMinusActive = nil
                    end
                    print("[RogueMon Streamer] Cleared/decremented No Guard Minus after battle.")
                else
                    print("[RogueMon Streamer] No Guard Minus preserved (escape).")
                end
                RoguemonStreamer.settings.persistent.noGuardMinusApplied = nil
                RoguemonStreamer.saveSettings()
            end


            
            -- Clean up/Preserve disabledMove status after battle
            if RoguemonStreamer.settings.persistent.disabledMoveApplied then
                local turnsLeft = RoguemonStreamer.settings.persistent.disabledMoveTurns or 0
                if turnsLeft <= 0 then
                    -- Check if queued disables remain to pop outside of battle
                    local queued = RoguemonStreamer.settings.persistent.queuedDisableTurns or {}
                    if #queued > 0 then
                        local nextItem = table.remove(queued, 1)
                        RoguemonStreamer.settings.persistent.queuedDisableTurns = queued
                        
                        local partyMoves = getPartyMonMoves(activeIdx)
                        local moves = {}
                        for _, m in ipairs(partyMoves) do
                            if m and m > 0 then
                                table.insert(moves, m)
                            end
                        end
                        if #moves > 0 then
                            RoguemonStreamer.settings.persistent.disabledMoveId = moves[RoguemonStreamer.random(#moves)]
                            RoguemonStreamer.settings.persistent.disabledMoveTurns = nextItem.turns
                            RoguemonStreamer.settings.persistent.disabledMoveApplied = false
                        else
                            RoguemonStreamer.settings.persistent.disabledMoveId = nil
                            RoguemonStreamer.settings.persistent.disabledMoveTurns = nil
                            RoguemonStreamer.settings.persistent.disabledMoveApplied = nil
                        end
                    else
                        RoguemonStreamer.settings.persistent.disabledMoveId = nil
                        RoguemonStreamer.settings.persistent.disabledMoveTurns = nil
                        RoguemonStreamer.settings.persistent.disabledMoveApplied = nil
                    end
                    RoguemonStreamer.saveSettings()
                    print("[RogueMon Streamer] Cleared expired disable move after battle.")
                else
                    RoguemonStreamer.settings.persistent.disabledMoveApplied = false
                    RoguemonStreamer.saveSettings()
                end
            end
            
            -- Clean up/Preserve tempType status after battle
            if RoguemonStreamer.settings.persistent.tempTypeApplied then
                if not wasEscape then
                    -- Check if there are queued temp types
                    local queued = RoguemonStreamer.settings.persistent.queuedTempTypes
                    if queued and #queued > 0 then
                        -- Dequeue the next one!
                        local nextTemp = table.remove(queued, 1)
                        RoguemonStreamer.settings.persistent.tempTypeChange = { nextTemp[1], nextTemp[2] }
                        RoguemonStreamer.settings.persistent.tempTypeApplied = false
                        RoguemonStreamer.saveSettings()
                        print(string.format("[RogueMon Streamer] Applied next queued temp type: %d/%d", nextTemp[1], nextTemp[2]))
                    else
                        RoguemonStreamer.settings.persistent.tempTypeChange = nil
                        RoguemonStreamer.settings.persistent.tempTypeApplied = nil
                        RoguemonStreamer.saveSettings()
                        print("[RogueMon Streamer] Cleared applied temp type change after battle.")
                    end
                else
                    RoguemonStreamer.settings.persistent.tempTypeApplied = false
                    RoguemonStreamer.saveSettings()
                    print("[RogueMon Streamer] Temp type change preserved for next battle (escape).")
                end
            end
            
            -- Clean up/Preserve stat buffs after battle
            if RoguemonStreamer.ActiveStatBuffsApplied then
                if not wasEscape then
                    local buffs = RoguemonStreamer.settings.persistent.statBuffs or {}
                    local activeBuffs = {}
                    for _, buff in ipairs(buffs) do
                        buff.remaining = buff.remaining - 1
                        if buff.remaining > 0 then
                            table.insert(activeBuffs, buff)
                        end
                    end
                    RoguemonStreamer.settings.persistent.statBuffs = activeBuffs
                    RoguemonStreamer.saveSettings()
                    print("[RogueMon Streamer] Decremented stat buffs remaining count after battle.")
                else
                    print("[RogueMon Streamer] Stat buffs preserved (escape).")
                end
                RoguemonStreamer.ActiveStatBuffsApplied = false
            end

            -- Clean up active Overwhelmed state after battle
            if RoguemonStreamer.settings.persistent.overwhelmedActive then
                if not wasEscape then
                    if type(RoguemonStreamer.settings.persistent.overwhelmedActive) == "number" then
                        local count = RoguemonStreamer.settings.persistent.overwhelmedActive - 1
                        if count <= 0 then
                            RoguemonStreamer.settings.persistent.overwhelmedActive = nil
                            print("[RogueMon Streamer] Cleared active Overwhelmed state after battle (duration expired).")
                        else
                            RoguemonStreamer.settings.persistent.overwhelmedActive = count
                            print(string.format("[RogueMon Streamer] Decremented active Overwhelmed state (remaining: %d battles).", count))
                        end
                    else
                        RoguemonStreamer.settings.persistent.overwhelmedActive = nil
                        print("[RogueMon Streamer] Cleared active Overwhelmed state after battle.")
                    end
                    RoguemonStreamer.saveSettings()
                else
                    print("[RogueMon Streamer] Active Overwhelmed state preserved (escape).")
                end
            end

            -- Clean up active Omnimalus state after battle
            if RoguemonStreamer.settings.persistent.omnimalusActive then
                if not wasEscape then
                    if type(RoguemonStreamer.settings.persistent.omnimalusActive) == "number" then
                        local count = RoguemonStreamer.settings.persistent.omnimalusActive - 1
                        if count <= 0 then
                            RoguemonStreamer.settings.persistent.omnimalusActive = nil
                            print("[RogueMon Streamer] Cleared active Omnimalus state after battle (duration expired).")
                        else
                            RoguemonStreamer.settings.persistent.omnimalusActive = count
                            print(string.format("[RogueMon Streamer] Decremented active Omnimalus state (remaining: %d battles).", count))
                        end
                    else
                        RoguemonStreamer.settings.persistent.omnimalusActive = nil
                        print("[RogueMon Streamer] Cleared active Omnimalus state after battle.")
                    end
                    RoguemonStreamer.saveSettings()
                else
                    print("[RogueMon Streamer] Active Omnimalus state preserved (escape).")
                end
            end

            -- Clean up Game Changer after battle (decrement battle count)
            if RoguemonStreamer.settings.persistent.gameChangerApplied then
                if not wasEscape then
                    local count = RoguemonStreamer.settings.persistent.gameChangerActive or 0
                    if count < 5000 then
                        local rem = count - 1
                        if rem <= 0 then
                            RoguemonStreamer.settings.persistent.gameChangerActive = nil
                        else
                            RoguemonStreamer.settings.persistent.gameChangerActive = rem
                        end
                        print("[RogueMon Streamer] Game Changer decremented/cleared after battle.")
                    else
                        print("[RogueMon Streamer] Game Changer preserved (always active for run).")
                    end
                else
                    print("[RogueMon Streamer] Game Changer preserved (escape).")
                end
                RoguemonStreamer.settings.persistent.gameChangerApplied = nil
                RoguemonStreamer.saveSettings()
            end

            -- Clean up Try Harder after battle (decrement battle count)
            if RoguemonStreamer.settings.persistent.tryHarderApplied then
                if not wasEscape then
                    local count = RoguemonStreamer.settings.persistent.tryHarderActive or 0
                    if count < 5000 then
                        local rem = count - 1
                        if rem <= 0 then
                            RoguemonStreamer.settings.persistent.tryHarderActive = nil
                        else
                            RoguemonStreamer.settings.persistent.tryHarderActive = rem
                        end
                        print("[RogueMon Streamer] Try Harder decremented/cleared after battle.")
                    else
                        print("[RogueMon Streamer] Try Harder preserved (always active for run).")
                    end
                else
                    print("[RogueMon Streamer] Try Harder preserved (escape).")
                end
                RoguemonStreamer.settings.persistent.tryHarderApplied = nil
                RoguemonStreamer.saveSettings()
            end

            -- Clean up Mystification after battle (decrement battle count)
            if RoguemonStreamer.settings.persistent.mystificationApplied then
                if not wasEscape then
                    local rem = (RoguemonStreamer.settings.persistent.mystificationActive or 0) - 1
                    if rem <= 0 then
                        RoguemonStreamer.settings.persistent.mystificationActive = nil
                    else
                        RoguemonStreamer.settings.persistent.mystificationActive = rem
                    end
                    print("[RogueMon Streamer] Mystification decremented/cleared after battle.")
                else
                    print("[RogueMon Streamer] Mystification preserved (escape).")
                end
                RoguemonStreamer.settings.persistent.mystificationApplied = nil
                RoguemonStreamer.saveSettings()
            end

            -- Clean up Out of Control if it was a Channel Point event (1 battle only)
            if RoguemonStreamer.settings.persistent.outOfControlCP and RoguemonStreamer.lastBattleOutcome and not wasEscape then
                RoguemonStreamer.settings.persistent.outOfControlTurns = 0
                RoguemonStreamer.settings.persistent.queuedOutOfControlTurns = 0
                RoguemonStreamer.settings.persistent.outOfControlCP = nil
                if RoguemonStreamer.MovesOverwritten then
                    RoguemonStreamer.restoreOriginalMoves(activeIdx)
                end
                RoguemonStreamer.saveSettings()
                print("[RogueMon Streamer] Out of Control cleared after 1 battle (Channel Points).")
            end

            RoguemonStreamer.lastBattleOutcome = nil
        end
    end

    -- Process pending cumulative events frame-by-frame when safe and no overlay/notification is active
    if isGamePlaySafe() then
        if RoguemonStreamer.ActiveLetsDanceRequest == nil and RoguemonStreamer.ActiveChoiceRequest == nil then
            local ScreenManager = Roguemon and Roguemon.ScreenManager
            if not ScreenManager or not ScreenManager.isNotificationActive() then
                if RoguemonStreamer.settings and RoguemonStreamer.settings.currentProgress and RoguemonStreamer.settings.cumulativeGoal then
                    if RoguemonStreamer.settings.currentProgress >= RoguemonStreamer.settings.cumulativeGoal then
                        RoguemonStreamer.settings.currentProgress = RoguemonStreamer.settings.currentProgress - RoguemonStreamer.settings.cumulativeGoal
                        
                        local randVal = RoguemonStreamer.random(100)
                        local outcome = (randVal <= RoguemonStreamer.settings.goodChance) and "Good" or "Bad"
                        local eventNameCum
                        if outcome == "Good" then
                            eventNameCum = RoguemonStreamer.pickRandomEvent(POSITIVE_EVENTS_CUMULATIVE)
                            RoguemonStreamer.executePositiveEvent(eventNameCum, 1)
                        else
                            eventNameCum = RoguemonStreamer.pickRandomEvent(NEGATIVE_EVENTS_CUMULATIVE)
                            RoguemonStreamer.executeNegativeEvent(eventNameCum, 1)
                        end
                        RoguemonStreamer.settings.stats.totalEvents = RoguemonStreamer.settings.stats.totalEvents + 1
                        RoguemonStreamer.saveSettings()
                    end
                end
            end
        end
    end

    RoguemonStreamer.updateAndDrawAnimations()
end

function RoguemonStreamer.syncCapModifiers()
    if not RoguemonStreamer.initialized or not RoguemonStreamer.settings.enabled then
        return
    end

    -- 1. Check for a new run
    if Tracker and Tracker.Data and Tracker.Data.trainerID and Tracker.Data.trainerID ~= 0 and not Battle.inActiveBattle() then
        if RoguemonStreamer.settings.persistent.lastTrainerID ~= Tracker.Data.trainerID then
            RoguemonStreamer.trainerIdDiffFrames = (RoguemonStreamer.trainerIdDiffFrames or 0) + 1
            if RoguemonStreamer.trainerIdDiffFrames >= 30 then
                print("[RogueMon Streamer] New run detected (TrainerID changed and stable). Resetting persistent Twitch boosts.")
                RoguemonStreamer.settings.persistent.hpCapBoost = 0
                RoguemonStreamer.settings.persistent.statusCapBoost = 0
                RoguemonStreamer.settings.persistent.lastAppliedHpBoost = 0
                RoguemonStreamer.settings.persistent.lastAppliedStatusBoost = 0
                RoguemonStreamer.settings.persistent.statBuffs = {}
                RoguemonStreamer.settings.persistent.outOfControlTurns = 0
                RoguemonStreamer.settings.persistent.pendingRemovals = {
                    healing = 0,
                    utility_status = 0,
                    big_healing = 0,
                    utility_valuable = 0,
                }
                RoguemonStreamer.settings.alteredTypes = {}
                RoguemonStreamer.settings.alteredAbilities = {}
                RoguemonStreamer.settings.persistent.tempTypeChange = nil
                RoguemonStreamer.settings.persistent.tempTypeApplied = nil
                RoguemonStreamer.settings.persistent.queuedTempTypes = {}
                RoguemonStreamer.settings.persistent.queuedDisableTurns = {}
                RoguemonStreamer.settings.persistent.queuedDamageAndStatus = {}
                RoguemonStreamer.settings.persistent.queuedStatuses = {}
                RoguemonStreamer.settings.persistent.overwhelmedActive = nil
                RoguemonStreamer.settings.persistent.queuedOverwhelmedCount = 0

                RoguemonStreamer.settings.persistent.queuedNoGuards = {}
                RoguemonStreamer.settings.persistent.lastTrainerID = Tracker.Data.trainerID
                RoguemonStreamer.saveSettings()
                RoguemonStreamer.trainerIdDiffFrames = 0
            end
        else
            RoguemonStreamer.trainerIdDiffFrames = 0
        end
    else
        RoguemonStreamer.trainerIdDiffFrames = 0
    end

    local segState = nil
    if Roguemon and Roguemon.SegmentManager and Roguemon.SegmentManager.readSegmentState then
        segState = Roguemon.SegmentManager.readSegmentState()
    end

    if segState then
        local hpBoost = RoguemonStreamer.settings.persistent.hpCapBoost or 0
        local statusBoost = RoguemonStreamer.settings.persistent.statusCapBoost or 0
        local lastAppliedHp = RoguemonStreamer.settings.persistent.lastAppliedHpBoost or 0
        local lastAppliedStatus = RoguemonStreamer.settings.persistent.lastAppliedStatusBoost or 0
        
        local deltaHp = hpBoost - lastAppliedHp
        local deltaStatus = statusBoost - lastAppliedStatus

        local adjustedAny = false
        if deltaHp ~= 0 then
            if Roguemon.SegmentManager and Roguemon.SegmentManager.adjustHpCapModifier then
                print(string.format("[RogueMon Streamer] Cap Sync: Applying delta HP boost of %d (Twitch Target: %d, Last Applied: %d)", deltaHp, hpBoost, lastAppliedHp))
                if Roguemon.SegmentManager.adjustHpCapModifier(deltaHp) then
                    print("[RogueMon Streamer] Cap Sync: HP adjustment SUCCESS")
                    RoguemonStreamer.settings.persistent.lastAppliedHpBoost = hpBoost
                    RoguemonStreamer.saveSettings()
                    adjustedAny = true
                else
                    print("[RogueMon Streamer] Cap Sync: HP adjustment FAILED")
                end
            end
        end
        if deltaStatus ~= 0 then
            if Roguemon.SegmentManager and Roguemon.SegmentManager.adjustStatusCapModifier then
                print(string.format("[RogueMon Streamer] Cap Sync: Applying delta Status boost of %d (Twitch Target: %d, Last Applied: %d)", deltaStatus, statusBoost, lastAppliedStatus))
                if Roguemon.SegmentManager.adjustStatusCapModifier(deltaStatus) then
                    print("[RogueMon Streamer] Cap Sync: Status adjustment SUCCESS")
                    RoguemonStreamer.settings.persistent.lastAppliedStatusBoost = statusBoost
                    RoguemonStreamer.saveSettings()
                    adjustedAny = true
                else
                    print("[RogueMon Streamer] Cap Sync: Status adjustment FAILED")
                end
            end
        end

        if adjustedAny then
            refreshTracker()
        end
    end
end

function RoguemonStreamer.afterProgramDataUpdate()
    RoguemonStreamer.syncCapModifiers()

    RoguemonStreamer.updateDynamicNatures()

    -- Process pending item removals (persistent debt)
    if RoguemonStreamer.settings.persistent.pendingRemovals then
        local categories = {
            healing = { ITEMS.POTION, ITEMS.SUPER_POTION, ITEMS.FRESH_WATER, ITEMS.ENERGY_POWDER },
            utility_status = { ITEMS.ANTIDOTE, ITEMS.BURN_HEAL, ITEMS.ICE_HEAL, ITEMS.AWAKENING, ITEMS.PARALYZE_HEAL, ITEMS.LAVA_COOKIE },
            big_healing = { ITEMS.HYPER_POTION, ITEMS.MAX_POTION, ITEMS.FULL_RESTORE },
            utility_valuable = { ITEMS.RARE_CANDY, ITEMS.ETHER, ITEMS.MAX_ETHER, ITEMS.ELIXIR, ITEMS.MAX_ELIXIR }
        }
        local changed = false
        for catName, list in pairs(categories) do
            local pending = RoguemonStreamer.settings.persistent.pendingRemovals[catName] or 0
            if pending > 0 then
                if isGamePlaySafe() then
                    local removedAny = false
                    for i = 1, pending do
                        if RoguemonStreamer.removeRandomItemFromCategory(list, true) then
                            RoguemonStreamer.settings.persistent.pendingRemovals[catName] = RoguemonStreamer.settings.persistent.pendingRemovals[catName] - 1
                            removedAny = true
                            changed = true
                        else
                            break
                        end
                    end
                    if removedAny then
                        print(string.format("[RogueMon Streamer] - Persistent Debt Check: Removed pending items for category '%s'. Remaining debt: %d", catName, RoguemonStreamer.settings.persistent.pendingRemovals[catName]))
                    end
                end
            end
        end
        if changed then
            RoguemonStreamer.saveSettings()
        end
    end
end

isActionSelectionPhaseActive = function()
    if not Battle.inBattleScreen then
        return false
    end
    if not GameSettings.gBattleMainFunc or not GameSettings.HandleTurnActionSelectionState then
        return false
    end
    local mainFunc = Memory.readdword(GameSettings.gBattleMainFunc)
    local target = GameSettings.HandleTurnActionSelectionState
    return (math.floor(mainFunc / 2) == math.floor(target / 2))
        or (math.floor(mainFunc / 2) == math.floor(0x806D17C / 2))
        or (Memory.readbyte(0x02023E88) == 1)
        or (Memory.readbyte(0x02024280) == 1)
end

function RoguemonStreamer.afterRedraw()
    -- Enforce leaderboard disable if the streamer extension is active and leaderboard got re-enabled/reloaded
    if Roguemon and Roguemon.Leaderboard and not Roguemon.Leaderboard.disabled then
        RoguemonStreamer.originalLeaderboardFuncs = {
            init = Roguemon.Leaderboard.init,
            onRomEvent = Roguemon.Leaderboard.onRomEvent,
            checkForFrameSkip = Roguemon.Leaderboard.checkForFrameSkip,
            confirmLogViewWillEndRun = Roguemon.Leaderboard.confirmLogViewWillEndRun,
            confirmOpenBookWillEndRun = Roguemon.Leaderboard.confirmOpenBookWillEndRun,
            confirmEnableWithOpenBookOff = Roguemon.Leaderboard.confirmEnableWithOpenBookOff,
        }
        if Roguemon.Leaderboard.LeaderboardUtils then
            RoguemonStreamer.originalLeaderboardFuncs.isLeaderboardEnabled = Roguemon.Leaderboard.LeaderboardUtils.isLeaderboardEnabled
            Roguemon.Leaderboard.LeaderboardUtils.isLeaderboardEnabled = function() return false end
        end

        Roguemon.Leaderboard.init = function() end
        Roguemon.Leaderboard.onRomEvent = function() end
        Roguemon.Leaderboard.checkForFrameSkip = function() end
        Roguemon.Leaderboard.confirmLogViewWillEndRun = function() return true end
        Roguemon.Leaderboard.confirmOpenBookWillEndRun = function() return true end
        Roguemon.Leaderboard.confirmEnableWithOpenBookOff = function() return true end

        Roguemon.Leaderboard.disabled = true
        _G.print("[RogueMon Streamer] Leaderboard disabled (re-enforced).")
    end

    -- If choice request overlay is active and we are not on StreamerChoiceScreen, show it
    if RoguemonStreamer.ActiveChoiceRequest and Program.currentScreen ~= StreamerChoiceScreen then
        StreamerChoiceScreen.show(RoguemonStreamer.ActiveChoiceRequest)
    end
    -- If Let's Dance request is active and we are not on LetsDanceScreen, show it
    if RoguemonStreamer.ActiveLetsDanceRequest and Program.currentScreen ~= LetsDanceScreen then
        LetsDanceScreen.show(RoguemonStreamer.ActiveLetsDanceRequest)
    end
end

-- OPTIONS CONFIGURATION
function RoguemonStreamer.openOptionsScreen()
    StreamerOptionsScreen.initialize()
    Program.changeScreenView(StreamerOptionsScreen)
end

function RoguemonStreamer.triggerTestEvent(outcome)
    if not isGamePlaySafe() then
        RoguemonStreamer.notifyStreamer("Testing requires a safe overworld or battle turn state!")
        return
    end

    local eventName
    if outcome == "Good" then
        eventName = RoguemonStreamer.pickRandomEvent(POSITIVE_EVENTS_CUMULATIVE)
        RoguemonStreamer.executePositiveEvent(eventName, 1)
    else
        eventName = RoguemonStreamer.pickRandomEvent(NEGATIVE_EVENTS_CUMULATIVE)
        RoguemonStreamer.executeNegativeEvent(eventName, 1)
    end

    -- RoguemonStreamer.notifyStreamer(string.format("Test: Triggered %s event: %s", outcome, eventName)) -- Commented out to prevent double popups
end

function RoguemonStreamer.triggerSpecificTestEvent(eventName, isPositive)
    local simRequest = { SanitizedInput = eventName }
    if not isGamePlaySafe(simRequest) then
        RoguemonStreamer.notifyStreamer("Testing requires a safe overworld or battle turn state!")
        return
    end

    if isPositive then
        RoguemonStreamer.executePositiveEvent(eventName, 1)
    else
        RoguemonStreamer.executeNegativeEvent(eventName, 1)
    end
end

function RoguemonStreamer.simulateTwitchRedeem(eventNameKey)
    local C = Network and Network.CurrentConnection
    if not C or not C.InboundFile then
        RoguemonStreamer.notifyStreamer("Redeem failed: No active file connection.")
        return
    end

    -- Generate a unique request
    local guid = string.format("sim_%d_%d", os.time(), math.random(1000, 9999))
    local request = {
        GUID = guid,
        EventKey = "TwitchChannelPointsEvent",
        CreatedAt = os.time(),
        Username = "SimulatedViewer",
        Platform = "Twitch",
        Args = {
            RewardId = "simulated_reward_id",
            RewardName = eventNameKey,
            Input = eventNameKey
        }
    }

    -- Read existing requests in the file
    local currentRequests = FileManager.decodeJsonFile(C.InboundFile) or {}
    if type(currentRequests) ~= "table" or currentRequests.EventKey ~= nil then
        -- If it was a single request, wrap it in a list
        if next(currentRequests) ~= nil and currentRequests.GUID then
            currentRequests = { currentRequests }
        else
            currentRequests = {}
        end
    end

    table.insert(currentRequests, request)
    FileManager.encodeToJsonFile(C.InboundFile, currentRequests)
    print("[RogueMon Streamer] Simulated Twitch Channel Points Redeem written to file: " .. eventNameKey)
end

function RoguemonStreamer.simulateSubRedeem(eventName, isPositive, subCount)
    local C = Network and Network.CurrentConnection
    if not C or not C.InboundFile then
        RoguemonStreamer.notifyStreamer("Simulate Sub failed: No active file connection.")
        return
    end

    local guid = string.format("sim_sub_%d_%d", os.time(), math.random(1000, 9999))
    local choice = isPositive and "Good" or "Bad"
    local request = {
        GUID = guid,
        EventKey = "TwitchSubEvent",
        CreatedAt = os.time(),
        Username = "SimulatedSubber",
        Platform = "Twitch",
        Choice = choice,
        SelectedEvent = eventName,
        Args = {
            SubCount = subCount,
            IsGift = true,
            Tier = "Tier 1",
            Choice = choice,
            SelectedEvent = eventName
        }
    }

    local currentRequests = FileManager.decodeJsonFile(C.InboundFile) or {}
    if type(currentRequests) ~= "table" or currentRequests.EventKey ~= nil then
        if next(currentRequests) ~= nil and currentRequests.GUID then
            currentRequests = { currentRequests }
        else
            currentRequests = {}
        end
    end

    table.insert(currentRequests, request)
    FileManager.encodeToJsonFile(C.InboundFile, currentRequests)
    print(string.format("[RogueMon Streamer] Simulated sub event written to Tracker-Requests.json: %s (%d subs)", eventName, subCount))
end

function RoguemonStreamer.executeChoice(request, choice)
    local argsTable = request.Args or {}
    local subCount = tonumber(argsTable.SubCount) or 1
    
    local choiceLower = tostring(choice or ""):lower()
    local eventName = request.SelectedEvent or argsTable.SelectedEvent
    if choiceLower == "good" then
        if not eventName then
            eventName = pickPositiveMilestoneEvent(subCount)
        end
        RoguemonStreamer.executePositiveEvent(eventName, subCount)
    else
        if not eventName then
            eventName = pickNegativeMilestoneEvent(subCount)
        end
        RoguemonStreamer.executeNegativeEvent(eventName, subCount)
    end

    RoguemonStreamer.settings.stats.totalSubs = RoguemonStreamer.settings.stats.totalSubs + subCount
    RoguemonStreamer.settings.stats.totalEvents = RoguemonStreamer.settings.stats.totalEvents + 1

    if request.IsSplitDoubleMilestone == 1 then
        request.IsSplitDoubleMilestone = 2
        request.Choice = nil
        if request.Args then
            request.Args.Choice = nil
        end
        RoguemonStreamer.saveSettings()
        print("[RogueMon Streamer] Completed first of two Milestone 20 events. Transitioned to second.")
    else
        if request.RemainingCumulative and request.RemainingCumulative > 0 then
            RoguemonStreamer.settings.currentProgress = RoguemonStreamer.settings.currentProgress + request.RemainingCumulative
            RoguemonStreamer.settings.stats.totalSubs = RoguemonStreamer.settings.stats.totalSubs + request.RemainingCumulative
        end
        RoguemonStreamer.saveSettings()
        if request.IsSplitDoubleMilestone == 2 then
            print("[RogueMon Streamer] Completed second of two Milestone 20 events. Added cumulative: " .. tostring(request.RemainingCumulative))
            request.IsSplitDoubleMilestone = nil
        end
    end

    local displayName = eventName
    if eventName == "Altera status" or eventName == "Inflict status" or eventName == "Inflict Status" then
        displayName = "Inflict status"
    end
    local msg = string.format("%s Choice Milestone Event triggered: %s ( %d subs )", choice, displayName, subCount)
    -- RoguemonStreamer.notifyStreamer(msg) -- Commented out to prevent double popups
    request.FulfillmentResult = msg
end

function RoguemonStreamer.triggerTestChoice(subs)
    if not isGamePlaySafe() then
        RoguemonStreamer.notifyStreamer("Testing choices requires a safe gameplay state (with at least 1 Pokémon)!")
        return
    end

    -- Mock a choice request
    local req = {
        GUID = Utils.newGUID(),
        EventKey = "TwitchSubEvent",
        CreatedAt = os.time(),
        Username = "TestGifter",
        Platform = "twitch",
        IsTest = true, -- Flag as test event
        Args = { SubCount = subs, IsGift = true, Tier = "Tier 1" }
    }
    
    RoguemonStreamer.ActiveChoiceRequest = req
    StreamerChoiceScreen.show(req)
end

function RoguemonStreamer.getActiveEventMessages()
    local messages = {}

    -- 1. Item notifications (expires after 5 seconds) - Silenced from Carousel per request
    -- if RoguemonStreamer.itemNotification and os.time() - RoguemonStreamer.itemNotification.time < 5 then
    --     table.insert(messages, RoguemonStreamer.itemNotification.text)
    -- end

    -- 2. Disabled Move & Queued Disables
    if RoguemonStreamer.settings and RoguemonStreamer.settings.persistent then
        local dmId = RoguemonStreamer.settings.persistent.disabledMoveId
        local dmTurns = RoguemonStreamer.settings.persistent.disabledMoveTurns
        if dmId and dmId > 0 and dmTurns and dmTurns > 0 then
            local moveName = (MoveData and MoveData.Moves and MoveData.Moves[dmId] and MoveData.Moves[dmId].name) or string.format("Move%d", dmId)
            table.insert(messages, string.format("Disabled Move ( %s ) ( %d turns )", trim(moveName), dmTurns))
        end
        
        local queuedDisables = RoguemonStreamer.settings.persistent.queuedDisableTurns
        if queuedDisables and #queuedDisables > 0 then
            local totalQueued = 0
            for _, qd in ipairs(queuedDisables) do
                totalQueued = totalQueued + qd.turns
            end
            local count = #queuedDisables
            if count > 1 then
                table.insert(messages, string.format("Disabled Move ( %d turns ) ( %d events )", totalQueued, count))
            else
                table.insert(messages, string.format("Disabled Move ( %d turns )", totalQueued))
            end
        end
    end

    -- 3. Temp Type Change & Queued Temp Types
    if RoguemonStreamer.settings and RoguemonStreamer.settings.persistent then
        local tempTypes = RoguemonStreamer.settings.persistent.tempTypeChange
        local queuedTypes = RoguemonStreamer.settings.persistent.queuedTempTypes or {}
        
        if tempTypes and tempTypes[1] and tempTypes[2] then
            local t1 = PokemonData.TypeIndexMap[tempTypes[1]] or "Unknown"
            local t2 = PokemonData.TypeIndexMap[tempTypes[2]] or "Unknown"
            if t1 == t2 then
                table.insert(messages, string.format("Temp Type: %s ( 1 battle )", t1))
            else
                table.insert(messages, string.format("Temp Type: %s/%s ( 1 battle )", t1, t2))
            end
            
            if #queuedTypes > 0 then
                local count = #queuedTypes
                table.insert(messages, string.format("Temp Type Change ( %d queued )", count))
            end
        elseif #queuedTypes > 0 then
            local nextTemp = queuedTypes[1]
            local t1 = PokemonData.TypeIndexMap[nextTemp[1]] or "Unknown"
            local t2 = PokemonData.TypeIndexMap[nextTemp[2]] or "Unknown"
            local typeStr = (t1 == t2) and t1 or (t1 .. "/" .. t2)
            
            if #queuedTypes == 1 then
                table.insert(messages, string.format("Temp Type: %s ( next battle )", typeStr))
            else
                table.insert(messages, string.format("Temp Type: %s ( +%d queued )", typeStr, #queuedTypes - 1))
            end
        end
    end

    -- 4. Stat Buffs / Debuffs (Accumulated)
    if RoguemonStreamer.settings and RoguemonStreamer.settings.persistent then
        local buffs = RoguemonStreamer.settings.persistent.statBuffs or {}
        local statLabels = { atk = "Atk", def = "Def", spe = "Spe", spa = "SpA", spd = "SpD", acc = "Acc", eva = "Eva" }
        
        local grouped = {}
        for _, buff in ipairs(buffs) do
            if buff.remaining and buff.remaining > 0 then
                local stat = buff.stat
                if not grouped[stat] then
                    grouped[stat] = { value = 0, totalRemaining = 0 }
                end
                grouped[stat].value = grouped[stat].value + buff.value
                grouped[stat].totalRemaining = math.max(grouped[stat].totalRemaining, buff.remaining)
            end
        end
        
        local orderedStats = { "atk", "def", "spe", "spa", "spd", "acc", "eva" }
        
        -- Check if all 7 stats are active and have the same sign
        local hasAllStats = true
        local allPositive = true
        local allNegative = true
        for _, stat in ipairs(orderedStats) do
            local data = grouped[stat]
            if not data or data.value == 0 or data.totalRemaining <= 0 then
                hasAllStats = false
                break
            end
            if data.value < 0 then
                allPositive = false
            end
            if data.value > 0 then
                allNegative = false
            end
        end

        local sign = 0
        if hasAllStats then
            if allPositive then
                sign = 1
            elseif allNegative then
                sign = -1
            end
        end

        if sign ~= 0 then
            -- Extract Omni component (common base value and duration)
            local minAbsVal = nil
            local minRemaining = nil
            for _, stat in ipairs(orderedStats) do
                local data = grouped[stat]
                local absVal = math.abs(data.value)
                if minAbsVal == nil or absVal < minAbsVal then
                    minAbsVal = absVal
                end
                if minRemaining == nil or data.totalRemaining < minRemaining then
                    minRemaining = data.totalRemaining
                end
            end

            -- Insert Omni message
            if minAbsVal > 0 and minRemaining > 0 then
                local name = sign > 0 and "Omniboost" or "Omnimalus"
                local btlStr = minRemaining == 1 and "battle" or "battles"
                table.insert(messages, string.format("%s %s%d ( %d %s )", name, sign > 0 and "+" or "-", minAbsVal, minRemaining, btlStr))
            end

            -- Insert leftover individual stats
            for _, stat in ipairs(orderedStats) do
                local data = grouped[stat]
                local leftoverVal = data.value - (sign * minAbsVal)
                local leftoverRem = data.totalRemaining - minRemaining
                if leftoverVal ~= 0 and leftoverRem > 0 then
                    local leftoverSign = leftoverVal >= 0 and "+" or ""
                    local statName = statLabels[stat] or stat
                    local btlStr = leftoverRem == 1 and "battle" or "battles"
                    table.insert(messages, string.format("%s %s%d ( %d %s )", statName, leftoverSign, leftoverVal, leftoverRem, btlStr))
                end
            end
        else
            -- No common Omni component, list all stats individually
            for _, stat in ipairs(orderedStats) do
                local data = grouped[stat]
                if data and data.value ~= 0 then
                    local signStr = data.value >= 0 and "+" or ""
                    local statName = statLabels[stat] or stat
                    local btlStr = data.totalRemaining == 1 and "battle" or "battles"
                    table.insert(messages, string.format("%s %s%d ( %d %s )", statName, signStr, data.value, data.totalRemaining, btlStr))
                end
            end
        end
    end

    -- 4a. No Guard Plus / Minus
    if RoguemonStreamer.settings and RoguemonStreamer.settings.persistent then
        local p = RoguemonStreamer.settings.persistent
        local plusCount = 0
        if type(p.noGuardPlusActive) == "number" then
            plusCount = p.noGuardPlusActive
        elseif p.noGuardPlusActive then
            plusCount = 1
        end

        local minusCount = 0
        if type(p.noGuardMinusActive) == "number" then
            minusCount = p.noGuardMinusActive
        elseif p.noGuardMinusActive then
            minusCount = 1
        end
        
        if plusCount > 0 then
            local btlStr = plusCount == 1 and "battle" or "battles"
            table.insert(messages, string.format("No Guard Plus ( %d %s )", plusCount, btlStr))
        end
        if minusCount > 0 then
            local btlStr = minusCount == 1 and "battle" or "battles"
            table.insert(messages, string.format("No Guard Minus ( %d %s )", minusCount, btlStr))
        end
    end

    -- 5. Out of Control
    if RoguemonStreamer.settings and RoguemonStreamer.settings.persistent then
        local ooc = RoguemonStreamer.settings.persistent.outOfControlTurns or 0
        local qooc = RoguemonStreamer.settings.persistent.queuedOutOfControlTurns or 0
        local totalOoc = ooc + qooc
        if totalOoc > 0 then
            table.insert(messages, string.format("Out of Control ( %d turns )", totalOoc))
        end
    end

    -- 6. Overwhelmed (PP penalty battles)
    if RoguemonStreamer.settings and RoguemonStreamer.settings.persistent then
        local activeCount = RoguemonStreamer.settings.persistent.overwhelmedActive or 0
        if type(activeCount) ~= "number" then activeCount = activeCount == true and 1 or 0 end
        local queuedCount = RoguemonStreamer.settings.persistent.queuedOverwhelmedCount or 0
        local total = activeCount + queuedCount
        if total > 0 then
            local btlStr = total == 1 and "btl" or "btls"
            table.insert(messages, string.format("Overwhelmed ( PP used +1 ) ( %d %s )", total, btlStr))
        end
    end

    -- 7. Persistent Item Debt
    if RoguemonStreamer.settings and RoguemonStreamer.settings.persistent then
        local debt = RoguemonStreamer.settings.persistent.pendingRemovals
        if debt then
            if (debt.healing or 0) > 0 then
                local count = debt.healing
                local itemStr = count == 1 and "item" or "items"
                table.insert(messages, string.format("Debt Healing ( %d %s )", count, itemStr))
            end
            if (debt.big_healing or 0) > 0 then
                local count = debt.big_healing
                local itemStr = count == 1 and "item" or "items"
                table.insert(messages, string.format("Debt Big Healing ( %d %s )", count, itemStr))
            end
            if (debt.utility_status or 0) > 0 then
                local count = debt.utility_status
                local itemStr = count == 1 and "item" or "items"
                table.insert(messages, string.format("Debt Status ( %d %s )", count, itemStr))
            end
            if (debt.utility_valuable or 0) > 0 then
                local count = debt.utility_valuable
                local itemStr = count == 1 and "item" or "items"
                table.insert(messages, string.format("Debt Utility ( %d %s )", count, itemStr))
            end
        end
    end

    -- 8. Queued Statuses
    if RoguemonStreamer.settings and RoguemonStreamer.settings.persistent then
        local queuedStat = RoguemonStreamer.settings.persistent.queuedStatuses
        if queuedStat and #queuedStat > 0 then
            local count = #queuedStat
            local evStr = count == 1 and "event" or "events"
            local statusAbbrs = {
                [4] = "SLP",
                [8] = "PSN",
                [16] = "BRN",
                [32] = "FRZ",
                [64] = "PAR"
            }
            local abbrList = {}
            for _, statVal in ipairs(queuedStat) do
                table.insert(abbrList, statusAbbrs[statVal] or "???")
            end
            local abbrStr = table.concat(abbrList, ", ")
            table.insert(messages, string.format("Inflict status ( %s )", abbrStr))
        end
    end

    -- 9. Omnimalus
    if RoguemonStreamer.settings and RoguemonStreamer.settings.persistent then
        local p = RoguemonStreamer.settings.persistent
        local activeCount = 0
        if type(p.omnimalusActive) == "number" then
            activeCount = p.omnimalusActive
        elseif p.omnimalusActive == true then
            activeCount = 1
        end
        local totalOmni = activeCount + (p.queuedOmnimalusCount or 0)
        if totalOmni > 0 then
            local btlStr = totalOmni == 1 and "battle" or "battles"
            table.insert(messages, string.format("Omnimalus -1 ( %d %s )", totalOmni, btlStr))
        end
    end

    -- 10. Game Changer
    if RoguemonStreamer.settings and RoguemonStreamer.settings.persistent then
        local count = RoguemonStreamer.settings.persistent.gameChangerActive or 0
        if count > 0 then
            if count >= 5000 then
                table.insert(messages, "Game Changer ( Perma )")
            else
                local btlStr = count == 1 and "battle" or "battles"
                table.insert(messages, string.format("Game Changer ( %d %s )", count, btlStr))
            end
        end
    end

    -- 11. Try Harder
    if RoguemonStreamer.settings and RoguemonStreamer.settings.persistent then
        local count = RoguemonStreamer.settings.persistent.tryHarderActive or 0
        if count > 0 then
            if count >= 5000 then
                table.insert(messages, "Try Harder ( Perma )")
            else
                local btlStr = count == 1 and "battle" or "battles"
                table.insert(messages, string.format("Try Harder ( %d %s )", count, btlStr))
            end
        end
    end

    -- 12. Mystification
    if RoguemonStreamer.settings and RoguemonStreamer.settings.persistent then
        local count = RoguemonStreamer.settings.persistent.mystificationActive or 0
        if count > 0 then
            local btlStr = count == 1 and "battle" or "battles"
            table.insert(messages, string.format("Mystification ( %d %s )", count, btlStr))
        end
    end

    return messages
end

function RoguemonStreamer.getNextCarouselMessage(carouselItem)
    local activeFrames = (Program and Program.Frames and Program.Frames.carouselActive) or 0
    
    -- Freeze active event messages list at rotation start to prevent mid-cycle cut-offs
    if activeFrames <= 1 or not RoguemonStreamer.carouselActiveMessages or #RoguemonStreamer.carouselActiveMessages == 0 then
        RoguemonStreamer.carouselActiveMessages = RoguemonStreamer.getActiveEventMessages()
    end
    
    local messages = RoguemonStreamer.carouselActiveMessages
    local numMsg = #messages
    if numMsg == 0 then
        return ""
    end
    
    if carouselItem and type(carouselItem) == "table" then
        carouselItem.framesToShow = numMsg * 240
    end
    
    -- Calculate adjusted message frames
    local baseFrames = 240
    local fpsMultiplier = (Program and Program.clientFpsMultiplier) or 1
    local adjustedMessageFrames = baseFrames * fpsMultiplier
    
    if carouselItem and not carouselItem.lockedSpeed and Options and Options["CarouselSpeed"] ~= "1" and Options.CarouselSpeedMap then
        local speedOption = Options.CarouselSpeedMap[Options["CarouselSpeed"] or "1"]
        local multiplier = speedOption and speedOption.multiplier or 1
        adjustedMessageFrames = adjustedMessageFrames * multiplier
    end
    
    adjustedMessageFrames = math.max(1, adjustedMessageFrames)
    
    local msgIdx = math.floor(activeFrames / adjustedMessageFrames) + 1
    if msgIdx > numMsg then
        if Options and Options["Allow carousel rotation"] then
            msgIdx = numMsg
        else
            msgIdx = ((msgIdx - 1) % numMsg) + 1
        end
    end
    
    return messages[msgIdx] or ""
end

function RoguemonStreamer.skipToNextCarouselMessage()
    local messages = RoguemonStreamer.carouselActiveMessages or RoguemonStreamer.getActiveEventMessages()
    local numMsg = #messages
    if numMsg == 0 then
        return
    end
    
    -- Calculate adjusted message frames
    local baseFrames = 240
    local fpsMultiplier = (Program and Program.clientFpsMultiplier) or 1
    local adjustedMessageFrames = baseFrames * fpsMultiplier
    
    local carouselItem = TrackerScreen and TrackerScreen.CarouselItems and TrackerScreen.CarouselItems[TrackerScreen.carouselIndex]
    if carouselItem and not carouselItem.lockedSpeed and Options and Options["CarouselSpeed"] ~= "1" and Options.CarouselSpeedMap then
        local speedOption = Options.CarouselSpeedMap[Options["CarouselSpeed"] or "1"]
        local multiplier = speedOption and speedOption.multiplier or 1
        adjustedMessageFrames = adjustedMessageFrames * multiplier
    end
    
    adjustedMessageFrames = math.max(1, adjustedMessageFrames)
    
    local activeFrames = (Program and Program.Frames and Program.Frames.carouselActive) or 0
    local msgIdx = math.floor(activeFrames / adjustedMessageFrames) + 1
    
    if Program and Program.Frames then
        Program.Frames.carouselActive = msgIdx * adjustedMessageFrames
        Program.redraw(true)
    end
end

function RoguemonStreamer.updateDynamicNatures()
    if GameSettings and GameSettings.pstats and GameSettings.estats and GameSettings.sizeofPokemon and Program and Program.GameData then
        -- Player Team
        if Program.GameData.PlayerTeam then
            for i = 1, 6 do
                local pokemon = Program.GameData.PlayerTeam[i]
                if pokemon then
                    local address = GameSettings.pstats + (i - 1) * GameSettings.sizeofPokemon
                    local personality = Memory.readdword(address)
                    if personality ~= 0 then
                        pokemon.nature = Utils.bit_xor(personality % 25, Utils.getbits(Memory.readbyte(address + 0x12), 3, 5))
                    end
                end
            end
        end

        -- Enemy Team
        if Program.GameData.EnemyTeam then
            for i = 1, 6 do
                local pokemon = Program.GameData.EnemyTeam[i]
                if pokemon then
                    local address = GameSettings.estats + (i - 1) * GameSettings.sizeofPokemon
                    local personality = Memory.readdword(address)
                    if personality ~= 0 then
                        pokemon.nature = Utils.bit_xor(personality % 25, Utils.getbits(Memory.readbyte(address + 0x12), 3, 5))
                    end
                end
            end
        end
    end
end

function RoguemonStreamer.applyRuntimeHooks()
    if GameSettings then
        if GameSettings.gMoveResultFlags == 0xC000000 or GameSettings.gMoveResultFlags == 0 then
            GameSettings.gMoveResultFlags = 0x202427C
        end
        if GameSettings.gBattleScriptingBattler == 0xC000000 or GameSettings.gBattleScriptingBattler == 0 then
            GameSettings.gBattleScriptingBattler = 0x202448B
        end
        if GameSettings.gBattleOutcome then
            pcall(event.unregisterbyname, "RoguemonStreamer_gBattleOutcome")
            event.onmemorywrite(function(addr, value, size)
                if value and value > 0 then
                    RoguemonStreamer.lastBattleOutcome = value
                    RoguemonStreamer.ActiveStatBuffsAppliedThisBattle = false
                    local activeIdx = getActivePartyIndex()
                    if RoguemonStreamer.MovesOverwritten then
                        RoguemonStreamer.restoreOriginalMoves(activeIdx)
                    end
                    print(string.format("[RogueMon Streamer] Memory Watch: Captured outcome: %d", value))
                end
            end, GameSettings.gBattleOutcome, "RoguemonStreamer_gBattleOutcome", "System Bus")
        end
    end

    logDebug(string.format("GameSettings Addresses Check:\n  gMoveResultFlags: 0x%X\n  gBattleScriptingBattler: 0x%X\n  gSideStatuses: 0x%X\n  gSideTimers: 0x%X\n  fieldStatusesAddr: 0x%X\n  fieldTimersAddr: 0x%X",
        GameSettings.gMoveResultFlags or 0, GameSettings.gBattleScriptingBattler or 0, GameSettings.gSideStatuses or 0, GameSettings.gSideTimers or 0, GameSettings.fieldStatusesAddr or 0, GameSettings.fieldTimersAddr or 0))

    logDebug(string.format("[RogueMon Streamer] Offsets debug: sizeofBattlePokemon=%s, battleAbilitiesOffset=%s, battleMonAbilityOffset=%s, gBattleMons=0x%X",
        tostring(GameSettings.sizeofBattlePokemon),
        tostring(GameSettings.battleAbilitiesOffset),
        tostring(GameSettings.battleMonAbilityOffset),
        GameSettings.gBattleMons or 0))
    -- Hook ROM randomization to perform a silent reset
    if Main and Main.GenerateNextRom then
        local origGenerateNextRom = Main.GenerateNextRom
        Main.GenerateNextRom = function()
            local result = origGenerateNextRom()
            if result ~= nil then
                RoguemonStreamer.resetRunState(true) -- silent reset
                print("[RogueMon Streamer] Automatically reset run state via Main.GenerateNextRom() hook.")
            end
            return result
        end
    end

    -- 1. SaveBlock Addresses nil-checks
    local function wrapSaveBlockGetter(originalFn, ptrName)
        return function()
            if not GameSettings or not GameSettings[ptrName] then return 0 end
            if originalFn then
                return originalFn()
            end
            return Memory.readdword(GameSettings[ptrName])
        end
    end

    if Roguemon and Roguemon.Core and Roguemon.Core.Utils then
        Roguemon.Core.Utils.getSaveBlock1Addr = wrapSaveBlockGetter(Roguemon.Core.Utils.getSaveBlock1Addr, "gSaveBlock1ptr")
        Roguemon.Core.Utils.getSaveBlock2Addr = wrapSaveBlockGetter(Roguemon.Core.Utils.getSaveBlock2Addr, "gSaveBlock2ptr")
        Roguemon.Core.Utils.getSaveBlock3Addr = wrapSaveBlockGetter(Roguemon.Core.Utils.getSaveBlock3Addr, "gSaveBlock3ptr")
    end
    if Utils then
        Utils.getSaveBlock1Addr = wrapSaveBlockGetter(Utils.getSaveBlock1Addr, "gSaveBlock1ptr")
        Utils.getSaveBlock2Addr = wrapSaveBlockGetter(Utils.getSaveBlock2Addr, "gSaveBlock2ptr")
        Utils.getSaveBlock3Addr = wrapSaveBlockGetter(Utils.getSaveBlock3Addr, "gSaveBlock3ptr")
    end

    -- 2. Item Name Trimming
    local function wrapReadItemName(originalFn)
        if not originalFn then return nil end
        return function(buf, itemId)
            local name = originalFn(buf, itemId)
            if name then
                return name:gsub("^%s*(.-)%s*$", "%1")
            end
            return name
        end
    end

    if Roguemon and Roguemon.Core and Roguemon.Core.MiscData then
        Roguemon.Core.MiscData.readItemName = wrapReadItemName(Roguemon.Core.MiscData.readItemName)
    end
    if MiscData then
        MiscData.readItemName = wrapReadItemName(MiscData.readItemName)
    end

    -- 3. Notification Screen wrap and lazy-load patching
    local function patchNotificationScreen(screen)
        if not screen then return end

        local WORD_COLORS = {
            -- Status conditions
            poison = 0xFFB050D0,     -- Purple
            veleno = 0xFFB050D0,
            paralysis = 0xFFD0C000,  -- Yellow
            paralyzed = 0xFFD0C000,
            paralisi = 0xFFD0C000,
            burn = 0xFFF07000,       -- Orange
            burned = 0xFFF07000,
            scottatura = 0xFFF07000,
            bruciatura = 0xFFF07000,
            freeze = 0xFF00B0F0,     -- Cyan
            frozen = 0xFF00B0F0,
            congelamento = 0xFF00B0F0,
            gelo = 0xFF00B0F0,
            sleep = 0xFF8090A0,      -- Gray-Blue
            sleeping = 0xFF8090A0,
            sonno = 0xFF8090A0,
            good = 0xFF00FF00,
            bad = 0xFFFF0000,
            -- Pokemon type colors (override status "poison" with the type shade)
            normal = 0xFFA8A77A,
            fire = 0xFFEE8130,
            water = 0xFF6390F0,
            electric = 0xFFF7D02C,
            grass = 0xFF7AC74C,
            ice = 0xFF96D9D6,
            fighting = 0xFFC22E28,
            ground = 0xFFE2BF65,
            flying = 0xFFA98FF3,
            psychic = 0xFFF95587,
            bug = 0xFFA6B91A,
            rock = 0xFFB6A136,
            ghost = 0xFF735797,
            dragon = 0xFF6F35FC,
            steel = 0xFFB7B7CE,
            dark = 0xFF705746,
            fairy = 0xFFD685AD,
        }

        local IMAGE_SIZE = 50

        local function calcPixelLengthWithSpaces(str)
            local totalLength = 0
            for i = 1, #str do
                local c = string.sub(str, i, i)
                local w = Utils.calcWordPixelLength(c)
                if c == " " then
                    w = 3
                end
                totalLength = totalLength + w + 1
            end
            return totalLength > 0 and (totalLength - 1) or 0
        end

        local function drawColoredLine(startX, startY, line, defaultColor, parenColor, shadowcolor, currentInParen)
            local hasWord = false
            local lineLower = line:lower()
            for word, _ in pairs(WORD_COLORS) do
                local pattern = "%f[%a]" .. word .. "%f[%A]"
                if string.find(lineLower, pattern) then
                    hasWord = true
                    break
                end
            end
            if not hasWord and RoguemonStreamer.temporaryNotifColors then
                for word, _ in pairs(RoguemonStreamer.temporaryNotifColors) do
                    if string.find(lineLower, word, 1, true) then
                        hasWord = true
                        break
                    end
                end
            end

            local hasParen = (parenColor ~= nil) and (string.find(line, "(", 1, true) ~= nil or string.find(line, ")", 1, true) ~= nil)

            if not hasWord and not hasParen and not currentInParen then
                Drawing.drawText(startX, startY, line, defaultColor, shadowcolor)
                return false
            end

            local len = #line
            local charColors = {}
            for i = 1, len do
                charColors[i] = defaultColor
            end

            local inParen = currentInParen or false
            if parenColor then
                for i = 1, len do
                    local c = string.sub(line, i, i)
                    if c == "(" then
                        inParen = true
                        charColors[i] = defaultColor
                    elseif c == ")" then
                        inParen = false
                        charColors[i] = defaultColor
                    elseif inParen then
                        charColors[i] = parenColor
                    end
                end
            end

            for word, color in pairs(WORD_COLORS) do
                local pattern = "%f[%a]" .. word .. "%f[%A]"
                local startPos = 1
                while true do
                    local s, e = string.find(lineLower, pattern, startPos)
                    if not s then break end
                    for i = s, e do
                        charColors[i] = color
                    end
                    startPos = e + 1
                end
            end
            if RoguemonStreamer.temporaryNotifColors then
                for word, color in pairs(RoguemonStreamer.temporaryNotifColors) do
                    local startPos = 1
                    while true do
                        local s, e = string.find(lineLower, word, startPos, true)
                        if not s then break end
                        for i = s, e do
                            charColors[i] = color
                        end
                        startPos = e + 1
                    end
                end
            end

            local curX = startX
            local i = 1
            while i <= len do
                local startIdx = i
                local c = string.sub(line, i, i)
                local isSpace = (c == " ")
                local segColor = charColors[i]

                if isSpace then
                    while i <= len and string.sub(line, i, i) == " " do
                        i = i + 1
                    end
                else
                    while i <= len and string.sub(line, i, i) ~= " " and charColors[i] == segColor do
                        i = i + 1
                    end
                end

                local endIdx = i - 1
                local segmentText = string.sub(line, startIdx, endIdx)
                Drawing.drawText(curX, startY, segmentText, segColor, shadowcolor)
                curX = curX + calcPixelLengthWithSpaces(segmentText)
            end

            return inParen
        end

        screen.drawScreen = function()
            local canvas, suppressButtons = screen.beginDraw()

            if screen.image then
                local imgX = canvas.x + 10
                local imgY = 12
                Drawing.drawImage(screen.image, imgX, imgY, IMAGE_SIZE, IMAGE_SIZE)
            end

            local textX = canvas.x + (screen.image and (IMAGE_SIZE + 16) or 10)
            local textW = canvas.w - (screen.image and (IMAGE_SIZE + 22) or 20)
            local wrapped = screen.wrapPixelsInline(screen.message or "", textW)

            local lines = {}
            local start = 1
            while true do
                local pos = string.find(wrapped, "\n", start, true)
                if not pos then
                    table.insert(lines, string.sub(wrapped, start))
                    break
                end
                table.insert(lines, string.sub(wrapped, start, pos - 1))
                start = pos + 1
            end

            if #lines > 0 then
                local parenColor = Theme.COLORS["Default text"]
                local messageLower = (screen.message or ""):lower()
                if messageLower:find("good") or messageLower:find("give") or messageLower:find("gain") or messageLower:find("add") or messageLower:find("boost") then
                    parenColor = 0xFF00FF00
                elseif messageLower:find("bad") or messageLower:find("remove") or messageLower:find("lost") or messageLower:find("lose") or messageLower:find("debuff") or messageLower:find("cut") or messageLower:find("deplete") or messageLower:find("debt") or messageLower:find("disable") or messageLower:find("out of control") or messageLower:find("damage") then
                    parenColor = 0xFFFF0000
                end

                local currentInParen = false
                for i = 1, #lines do
                    local lineY = 20 + (i - 1) * 11
                    local line = lines[i]
                    currentInParen = drawColoredLine(textX, lineY, line, Theme.COLORS["Default text"], parenColor, canvas.shadow, currentInParen)
                end
            end

            screen.drawButtons(suppressButtons, screen.Buttons)
        end
    end

    if Roguemon and Roguemon.Screens then
        local alreadyLoadedNotif = rawget(Roguemon.Screens, "NotificationScreen")
        if alreadyLoadedNotif then
            patchNotificationScreen(alreadyLoadedNotif)
        end
        local screensMeta = getmetatable(Roguemon.Screens)
        if screensMeta and screensMeta.__index then
            local originalIndex = screensMeta.__index
            screensMeta.__index = function(t, key)
                local mod = originalIndex(t, key)
                if key == "NotificationScreen" and mod then
                    patchNotificationScreen(mod)
                end
                return mod
            end
        end
    end

    -- 4. SegmentUI Streamer Carousel & Spacing & Click Dynamic Patch
    local function patchSegmentUI()
        local streamerBtnKey = "RogueStreamerCarousel"

        local WORD_COLORS = {
            poison = 0xFFB050D0,     -- Purple
            veleno = 0xFFB050D0,
            paralysis = 0xFFD0C000,  -- Yellow
            paralyzed = 0xFFD0C000,
            paralisi = 0xFFD0C000,
            burn = 0xFFF07000,       -- Orange
            burned = 0xFFF07000,
            scottatura = 0xFFF07000,
            bruciatura = 0xFFF07000,
            freeze = 0xFF00B0F0,     -- Cyan
            frozen = 0xFF00B0F0,
            congelamento = 0xFF00B0F0,
            gelo = 0xFF00B0F0,
            sleep = 0xFF8090A0,      -- Gray-Blue
            sleeping = 0xFF8090A0,
            sonno = 0xFF8090A0,
            cured = 0xFF00FF00,      -- Green
            curato = 0xFF00FF00,
            curati = 0xFF00FF00,
            cera = 0xFF00FF00,
            gain = 0xFF00FF00,
            good = 0xFF00FF00,
            boost = 0xFF00FF00,
            negative = 0xFFFF0000,   -- Red
            malus = 0xFFFF0000,
            control = 0xFFFF0000,
            bad = 0xFFFF0000,
            lose = 0xFFFF0000,
            lost = 0xFFFF0000,
            remove = 0xFFFF0000,
            cut = 0xFFFF0000,
            deplete = 0xFFFF0000,
            disable = 0xFFFF0000,
            damage = 0xFFFF0000,
            ["out of control"] = 0xFFFF0000,
            ["no guard plus"] = 0xFF00FF00,
            ["no guard minus"] = 0xFFFF0000,
            ["disabled move"] = 0xFFFF0000,
            ["temp type change"] = 0xFFFF0000,
            ["temp type"] = 0xFFFF0000,
            ["inflict status"] = 0xFFFF0000,
            ["debt healing"] = 0xFFFF0000,
            ["debt status"] = 0xFFFF0000,
            ["debt big healing"] = 0xFFFF0000,
            ["debt utility"] = 0xFFFF0000,
            overwhelmed = 0xFFFF0000,
            psn = 0xFFB050D0,
            brn = 0xFFF07000,
            par = 0xFFD0C000,
            frz = 0xFF00B0F0,
            slp = 0xFF8090A0,
            omnimalus = 0xFFFF0000,
            normal = 0xFFA8A77A,
            fire = 0xFFEE8130,
            water = 0xFF6390F0,
            electric = 0xFFF7D02C,
            grass = 0xFF7AC74C,
            ice = 0xFF96D9D6,
            fighting = 0xFFC22E28,
            poison = 0xFFA33EA1,
            ground = 0xFFE2BF65,
            flying = 0xFFA98FF3,
            psychic = 0xFFF95587,
            bug = 0xFFA6B91A,
            rock = 0xFFB6A136,
            ghost = 0xFF735797,
            dragon = 0xFF6F35FC,
            steel = 0xFFB7B7CE,
            dark = 0xFF705746,
            fairy = 0xFFD685AD,
        }

        local function calcPixelLengthWithSpaces(str)
            local totalLength = 0
            for i = 1, #str do
                local c = string.sub(str, i, i)
                local w = Utils.calcWordPixelLength(c)
                if c == " " then
                    w = 3
                end
                totalLength = totalLength + w + 1
            end
            return totalLength > 0 and (totalLength - 1) or 0
        end

        local function getCharColorsForText(text, defaultColor, parenColor)
            local len = #text
            local charColors = {}
            for i = 1, len do
                charColors[i] = defaultColor
            end

--            local textLower = text:lower()
--            if textLower:sub(1, 4) == "debt" then
--                local colonPos = text:find(":")
--                local endPos = colonPos and (colonPos - 1) or len
--                for i = 1, endPos do
--                    charColors[i] = 0xFFFF0000
--                end
--                return charColors
--            end

            if parenColor then
                local inParen = false
                for i = 1, len do
                    local c = string.sub(text, i, i)
                    if c == "(" then
                        inParen = true
                        charColors[i] = defaultColor
                    elseif c == ")" then
                        inParen = false
                        charColors[i] = defaultColor
                    elseif inParen then
                        charColors[i] = parenColor
                    end
                end
            end

            local textLower = text:lower()
            for word, color in pairs(WORD_COLORS) do
                local pattern = "%f[%a]" .. word .. "%f[%A]"
                local startPos = 1
                while true do
                    local s, e = string.find(textLower, pattern, startPos)
                    if not s then break end
                    for i = s, e do
                        charColors[i] = color
                    end
                    startPos = e + 1
                end
            end
            return charColors
        end

        local function drawColoredLine(startX, startY, line, lineColors, shadowcolor)
            local curX = startX
            local len = #line
            local i = 1
            while i <= len do
                local startIdx = i
                local c = string.sub(line, i, i)
                local isSpace = (c == " ")
                local segColor = lineColors[i] or Theme.COLORS["Lower box text"]

                if isSpace then
                    while i <= len and string.sub(line, i, i) == " " do
                        i = i + 1
                    end
                else
                    while i <= len and string.sub(line, i, i) ~= " " and (lineColors[i] or Theme.COLORS["Lower box text"]) == segColor do
                        i = i + 1
                    end
                end

                local endIdx = i - 1
                local segmentText = string.sub(line, startIdx, endIdx)
                Drawing.drawText(curX, startY, segmentText, segColor, shadowcolor)
                curX = curX + calcPixelLengthWithSpaces(segmentText)
            end
        end

        local function drawCarouselWrappedText(button, shadowcolor, pixelLimit, alternate)
            local btnText = button:getCustomText()
            local wrappedText = (Roguemon.ScreenManager and Roguemon.ScreenManager.wrapPixelsInline(btnText, pixelLimit, 2, alternate)) or ""
            
            local isStreamer = (button == (TrackerScreen and TrackerScreen.Buttons and TrackerScreen.Buttons[streamerBtnKey]))
            local stat, val, paren = nil, nil, nil
            local customColor = nil
            if isStreamer then
                stat, val, paren = wrappedText:match("^([^%s%+%-]+)%s*([%+%-]%d+)%s*(%b())$")
                if not stat then
                    local name, p = wrappedText:match("^([^%(]+)%s*(%b())$")
                    if name and p then
                        name = trim(name)
                        if name == "Game Changer" or name == "Try Harder" then
                            customColor = 0xFF00FF00
                            stat = name
                            val = ""
                            paren = p
                        elseif name == "Mystification" then
                            customColor = 0xFFFF0000
                            stat = name
                            val = ""
                            paren = p
                        end
                    end
                end
            end
            
            if isStreamer and stat and paren then
                local textColor = customColor or (val:find("%+") and 0xFF00FF00 or 0xFFFF0000)
                local part1 = stat .. (val ~= "" and (" " .. val) or "")
                
                local startX = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 1
                local startY = 140
                if string.find(wrappedText, "%\n") then
                    startY = 136
                end
                
                Drawing.drawText(startX, startY, part1, textColor, shadowcolor)
                local shiftX = startX + Utils.calcWordPixelLength(part1) + 4
                Drawing.drawText(shiftX, startY, paren, Theme.COLORS["Lower box text"], shadowcolor)
                
                if string.find(wrappedText, "%\n") then
                    gui.drawLine(Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN, 155, Constants.SCREEN.WIDTH + Constants.SCREEN.RIGHT_GAP - Constants.SCREEN.MARGIN, 155, Theme.COLORS["Lower box border"])
                    gui.drawLine(Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN, 156, Constants.SCREEN.WIDTH + Constants.SCREEN.RIGHT_GAP - Constants.SCREEN.MARGIN, 156, Theme.COLORS["Main background"])
                end
            else
                local textColor = Theme.COLORS["Lower box text"]
                local nl = string.find(wrappedText, "%\n")
                local parenColor = nil
                local allColors = getCharColorsForText(wrappedText, textColor, parenColor)
                if not nl then
                    drawColoredLine(Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 1, 140, wrappedText, allColors, shadowcolor)
                else
                    local line1 = string.sub(wrappedText, 1, nl - 1)
                    local line2 = string.sub(wrappedText, nl + 1)
                    
                    local colors1 = {}
                    for i = 1, #line1 do
                        colors1[i] = allColors[i]
                    end
                    
                    local colors2 = {}
                    for i = 1, #line2 do
                        colors2[i] = allColors[nl + i]
                    end
                    
                    drawColoredLine(Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 1, 136, line1, colors1, shadowcolor)
                    drawColoredLine(Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 1, 145, line2, colors2, shadowcolor)
                    gui.drawLine(Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN, 155, Constants.SCREEN.WIDTH + Constants.SCREEN.RIGHT_GAP - Constants.SCREEN.MARGIN, 155, Theme.COLORS["Lower box border"])
                    gui.drawLine(Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN, 156, Constants.SCREEN.WIDTH + Constants.SCREEN.RIGHT_GAP - Constants.SCREEN.MARGIN, 156, Theme.COLORS["Main background"])
                end
            end
        end

        local function getSegmentCarouselBgColor()
            local manager = Roguemon.SegmentManager
            local state = manager and (manager.State or (manager.readSegmentState and manager.readSegmentState()))
            local seg = state and manager.SegmentsById and manager.SegmentsById[state.currentId]
            local started = state and ((state.flags or 0) & 0x01) ~= 0
            if started and seg and manager.isFullClearSegment and manager.isFullClearSegment(seg) then
                return 0xFF008F00
            end
            if not started and state and state.currentId then
                local cm = Roguemon.CurseManager
                if cm and cm.getCurseForSegment(state.currentId) and not cm.isWardedSegment(state.currentId) then
                    return 0xFF510080
                end
            end
            return Theme.COLORS["Lower box background"]
        end

        local function drawCarouselBackground(bgColor)
            gui.drawRectangle(
                Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN,
                136,
                Constants.SCREEN.RIGHT_GAP - (2 * Constants.SCREEN.MARGIN),
                19,
                Theme.COLORS["Lower box border"],
                bgColor
            )
            gui.drawLine(Constants.SCREEN.WIDTH + 134, 136, Constants.SCREEN.WIDTH + 134, 155, Theme.COLORS["Lower box border"])
        end

        local function drawCarouselItemCount(shadowcolor)
            gui.drawLine(Constants.SCREEN.WIDTH + 122, 136, Constants.SCREEN.WIDTH + 122, 155, Theme.COLORS["Lower box border"])
            local colorList = TrackerScreen.PokeBalls and TrackerScreen.PokeBalls.ColorList
            if colorList and Constants.PixelImages and Constants.PixelImages.POKEBALL_SMALL then
                Drawing.drawImageAsPixels(Constants.PixelImages.POKEBALL_SMALL, Constants.SCREEN.WIDTH + 124, Constants.SCREEN.MARGIN + 132, colorList, _G.PixelFont and false)
            end
            local itemCt = Roguemon.SegmentUI and Roguemon.SegmentUI.getItemsInCurrentSegment and Roguemon.SegmentUI.getItemsInCurrentSegment() or 0
            Drawing.drawText(Constants.SCREEN.WIDTH + 122 + ((itemCt >= 10) and 0 or 3), Constants.SCREEN.MARGIN + 140, itemCt, Theme.COLORS["Lower box text"], shadowcolor)
        end

        if TrackerScreen and TrackerScreen.Buttons then
            local btn = TrackerScreen.Buttons[streamerBtnKey]
            if not btn then
                btn = {
                    type = Constants.ButtonTypes.FULL_BORDER,
                    getCustomText = function(this) return this.updatedText or "" end,
                    textColor = "Lower box text",
                    box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN, 136, 129, 18 },
                    boxColors = { "Default text" },
                }
                TrackerScreen.Buttons[streamerBtnKey] = btn
            end

            btn.isVisible = function()
                return Roguemon.SegmentUI and TrackerScreen.carouselIndex == Roguemon.SegmentUI.STREAMER_CAROUSEL_INDEX
            end
            btn.onClick = function(_)
                if RoguemonStreamer and RoguemonStreamer.skipToNextCarouselMessage then
                    RoguemonStreamer.skipToNextCarouselMessage()
                end
            end
            btn.draw = function(this, shadowcolor)
                local bgColor = Theme.COLORS["Lower box background"]
                gui.drawRectangle(
                    Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN,
                    136,
                    Constants.SCREEN.RIGHT_GAP - (2 * Constants.SCREEN.MARGIN),
                    19,
                    Theme.COLORS["Lower box border"],
                    bgColor
                )
                local panelShadow = Utils.calcShadowColor(bgColor)
                drawCarouselWrappedText(this, panelShadow, 136)
            end

            -- Override draw on RogueSegmentCarousel and RogueCurseCarousel
            local segmentBtn = TrackerScreen.Buttons["RogueSegmentCarousel"]
            if segmentBtn then
                segmentBtn.draw = function(this, shadowcolor)
                    local bgColor = getSegmentCarouselBgColor()
                    drawCarouselBackground(bgColor)
                    local panelShadow = Utils.calcShadowColor(bgColor)
                    drawCarouselItemCount(panelShadow)
                    local btnText = this:getCustomText()
                    drawCarouselWrappedText(this, panelShadow, 113, Utils.replaceText(btnText, "mandatory", "mand."))
                end
            end

            local curseBtn = TrackerScreen.Buttons["RogueCurseCarousel"]
            if curseBtn then
                curseBtn.draw = function(this, shadowcolor)
                    local bgColor = 0xFF510080
                    drawCarouselBackground(bgColor)
                    local panelShadow = Utils.calcShadowColor(bgColor)
                    drawCarouselItemCount(panelShadow)
                    drawCarouselWrappedText(this, panelShadow, 113)
                end
            end
        end

        if Roguemon and Roguemon.SegmentUI and TrackerScreen and TrackerScreen.CarouselItems then
            -- Find if our carousel is already in TrackerScreen.CarouselItems
            local streamerCarouselIndex = nil
            for idx, item in ipairs(TrackerScreen.CarouselItems) do
                if item.type == "RogueStreamerCarousel" then
                    streamerCarouselIndex = idx
                    break
                end
            end
            
            -- If not found, append it to the end of the array to avoid gaps
            if not streamerCarouselIndex then
                streamerCarouselIndex = #TrackerScreen.CarouselItems + 1
            end
            Roguemon.SegmentUI.STREAMER_CAROUSEL_INDEX = streamerCarouselIndex

            TrackerScreen.CarouselItems[streamerCarouselIndex] = {
                type = "RogueStreamerCarousel",
                framesToShow = 240,
                canShow = function(this)
                    if not (RoguemonStreamer and RoguemonStreamer.initialized and RoguemonStreamer.getActiveEventMessages) then
                        return false
                    end
                    local messages = RoguemonStreamer.getActiveEventMessages()
                    local numMsg = #messages
                    if numMsg == 0 then
                        RoguemonStreamer.carouselActiveMessages = nil
                        return false
                    end
                    if TrackerScreen and TrackerScreen.carouselIndex ~= Roguemon.SegmentUI.STREAMER_CAROUSEL_INDEX then
                        RoguemonStreamer.carouselActiveMessages = nil
                    end
                    this.framesToShow = numMsg * 240
                    return true
                end,
                getContentList = function(this)
                    local text = ""
                    if RoguemonStreamer and RoguemonStreamer.getNextCarouselMessage then
                        text = RoguemonStreamer.getNextCarouselMessage(this)
                    end
                    local sBtn = TrackerScreen.Buttons[streamerBtnKey]
                    if sBtn then
                        sBtn.updatedText = text
                        if Main.IsOnBizhawk() then
                            return { sBtn }
                        end
                    end
                    return text
                end,
            }
        end
    end

    if Roguemon and Roguemon.SegmentUI then
        patchSegmentUI()
        if not Roguemon.SegmentUI.hasBeenHookedByStreamer then
            Roguemon.SegmentUI.hasBeenHookedByStreamer = true
            local originalRegister = Roguemon.SegmentUI.register
            if originalRegister then
                Roguemon.SegmentUI.register = function()
                    originalRegister()
                    patchSegmentUI()
                end
            end
            local originalUnregister = Roguemon.SegmentUI.unregister
            if originalUnregister then
                Roguemon.SegmentUI.unregister = function()
                    local streamerBtnKey = "RogueStreamerCarousel"
                    if Roguemon.SegmentUI.STREAMER_CAROUSEL_INDEX then
                        if TrackerScreen and TrackerScreen.CarouselItems then
                            TrackerScreen.CarouselItems[Roguemon.SegmentUI.STREAMER_CAROUSEL_INDEX] = nil
                        end
                        Roguemon.SegmentUI.STREAMER_CAROUSEL_INDEX = nil
                    end
                    if TrackerScreen and TrackerScreen.Buttons then
                        TrackerScreen.Buttons[streamerBtnKey] = nil
                    end
                    originalUnregister()
                end
            end
        end
    end

    -- 5. Stats Area Override (Nature, stages, stage coloring)
    local function setupStatsAreaOverride()
        local function customDrawStatsArea(data)
            local borderColor = Theme.COLORS["Upper box border"]
            local bgColor = Theme.COLORS["Upper box background"]
            local shadowcolor = Utils.calcShadowColor(bgColor)
            local mainBoxWidth = 101
            local statOffsetX = Constants.SCREEN.WIDTH + mainBoxWidth + 1
            local statOffsetY = 7

            local x, y = Constants.SCREEN.WIDTH + mainBoxWidth, 5
            local w, h = Constants.SCREEN.RIGHT_GAP - mainBoxWidth - 5, 75
            gui.drawRectangle(x, y, w, h, borderColor, bgColor)
            if RouteData and RouteData.Locations and RouteData.Locations.CanPCHeal and TrackerAPI and TrackerAPI.getMapId then
                if RouteData.Locations.CanPCHeal[TrackerAPI.getMapId()] then
                    if data.x and data.x.extras then
                        if data.x.extras.upperleft then gui.drawPixel(x + 1, y + 1, borderColor) end
                        if data.x.extras.upperright then gui.drawPixel(x + w - 1, y + 1, borderColor) end
                        if data.x.extras.lowerleft then gui.drawPixel(x + 1, y + h - 1, borderColor) end
                        if data.x.extras.lowerright then gui.drawPixel(x + w - 1, y + h - 1, borderColor) end
                    end
                end
            end

            local statLabels = {
                ["HP"] = Resources.TrackerScreen.StatHP,
                ["ATK"] = Resources.TrackerScreen.StatATK,
                ["DEF"] = Resources.TrackerScreen.StatDEF,
                ["SPA"] = Resources.TrackerScreen.StatSPA,
                ["SPD"] = Resources.TrackerScreen.StatSPD,
                ["SPE"] = Resources.TrackerScreen.StatSPE,
            }

            for _, statKey in ipairs(Constants.OrderedLists.STATSTAGES) do
                local textColor = Theme.COLORS["Default text"]
                local natureSymbol = ""

                if Battle.isViewingOwn then
                    if statKey == data.p.positivestat then
                        textColor = Theme.COLORS["Positive text"]
                        natureSymbol = "+"
                    elseif statKey == data.p.negativestat then
                        textColor = Theme.COLORS["Negative text"]
                        natureSymbol = Constants.BLANKLINE
                    end
                end

                local langOffset = 0
                if Resources.currentLanguage == Resources.Languages.JAPANESE then
                    langOffset = 3
                end

                Drawing.drawText(statOffsetX, statOffsetY, statLabels[statKey:upper()], textColor, shadowcolor)
                Drawing.drawText(statOffsetX + 16 + langOffset, statOffsetY - 1, natureSymbol, textColor, nil, 5, Constants.Font.FAMILY)

                if Battle.inActiveBattle() then
                    local statStageIntensity = data.p.stages[statKey] - 6
                    Drawing.drawChevronsVerticalIntensity(statOffsetX + 20, statOffsetY + 4, statStageIntensity, 3,4,2,1,2)
                end

                local baseStatValue = data.p[statKey] or 0
                local statValueText
                local displayColor = textColor

                local val = tonumber(baseStatValue)
                local baseStat = baseStatValue
                if val and val > 0 then
                    local natureVal = tonumber(data.p.nature) or 0
                    local natureMultiplier = Utils.getNatureMultiplier(statKey, natureVal)
                    baseStat = math.floor(val * natureMultiplier)
                end

                if Battle.inActiveBattle() and statKey ~= "hp" and type(baseStat) == "number" and baseStat > 0 then
                    local stage = data.p.stages[statKey] or 6
                    if stage > 6 then
                        local multiplier = (2 + (stage - 6)) / 2
                        local effectiveValue = math.floor(baseStat * multiplier)
                        statValueText = tostring(effectiveValue)
                        displayColor = Theme.COLORS["Positive text"]
                    elseif stage < 6 then
                        local multiplier = 2 / (2 + (6 - stage))
                        local effectiveValue = math.floor(baseStat * multiplier)
                        statValueText = tostring(effectiveValue)
                        displayColor = Theme.COLORS["Negative text"]
                    else
                        statValueText = tostring(baseStat)
                    end
                else
                    if type(baseStat) == "number" then
                        statValueText = Utils.inlineIf(baseStat == 0, Constants.BLANKLINE, tostring(baseStat))
                    else
                        statValueText = Utils.inlineIf(data.p[statKey] == 0, Constants.BLANKLINE, data.p[statKey])
                    end
                end

                local isStageActive = Battle.inActiveBattle() and statKey ~= "hp" and (data.p.stages[statKey] or 6) ~= 6
                if not isStageActive then
                    if not Battle.isViewingOwn and PokemonData.canShowUnknownStats() then
                        displayColor = Theme.COLORS["Intermediate text"]
                    elseif not Options["Color stat numbers by nature"] then
                        displayColor = Theme.COLORS["Default text"]
                    end
                end

                if not Battle.isViewingOwn and not PokemonData.canShowUnknownStats() then
                    Drawing.drawButton(TrackerScreen.Buttons[statKey], shadowcolor)
                else
                    Drawing.drawNumber(statOffsetX + 25, statOffsetY, statValueText, 3, displayColor, shadowcolor)
                end
                statOffsetY = statOffsetY + 10
            end

            local useAccEvaInstead = Battle.inActiveBattle() and (data.p.stages.acc ~= 6 or data.p.stages.eva ~= 6)
            if useAccEvaInstead then
                Drawing.drawText(statOffsetX - 1, statOffsetY + 1, Resources.TrackerScreen.StatAccuracy, Theme.COLORS["Default text"], shadowcolor)
                Drawing.drawText(statOffsetX + 27, statOffsetY + 1, Resources.TrackerScreen.StatEvasion, Theme.COLORS["Default text"], shadowcolor)
                local accIntensity = data.p.stages.acc - 6
                local evaIntensity = data.p.stages.eva - 6
                Drawing.drawChevronsVerticalIntensity(statOffsetX + 15, statOffsetY + 5, accIntensity, 3,4,2,1,2)
                Drawing.drawChevronsVerticalIntensity(statOffsetX + 22, statOffsetY + 5, evaIntensity, 3,4,2,1,2)
            else
                Drawing.drawText(statOffsetX, statOffsetY, Resources.TrackerScreen.StatBST, Theme.COLORS["Default text"], shadowcolor)
                Drawing.drawNumber(statOffsetX + 25, statOffsetY, data.p.bst, 3, Theme.COLORS["Default text"], shadowcolor)
            end

            Drawing.drawInputOverlay()
        end

        _G.RoguemonStreamer_Backups = _G.RoguemonStreamer_Backups or {}
        if not _G.RoguemonStreamer_Backups.drawStatsArea then
            _G.RoguemonStreamer_Backups.drawStatsArea = TrackerScreen and TrackerScreen.drawStatsArea
        end
        local originalDrawStatsArea = _G.RoguemonStreamer_Backups.drawStatsArea
        if TrackerScreen then
            if Roguemon and Roguemon.tagWrapper then
                TrackerScreen.drawStatsArea = Roguemon.tagWrapper(customDrawStatsArea, "TrackerScreen.drawStatsArea", originalDrawStatsArea)
            else
                TrackerScreen.drawStatsArea = customDrawStatsArea
            end
        end
    end

    setupStatsAreaOverride()

    -- 6. PokemonData.getNatDexCompatible hook (to fix GachaDex/captures showing vanilla types for Gen 4-9 > 411)
    local function patchGetNatDexCompatible()
        if not PokemonData or not PokemonData.getNatDexCompatible then return end
        _G.RoguemonStreamer_Backups = _G.RoguemonStreamer_Backups or {}
        if not _G.RoguemonStreamer_Backups.getNatDexCompatible then
            _G.RoguemonStreamer_Backups.getNatDexCompatible = PokemonData.getNatDexCompatible
        end
        PokemonData.getNatDexCompatible = function(pokemonID)
            local pokemon = _G.RoguemonStreamer_Backups.getNatDexCompatible(pokemonID)
            if pokemon and pokemonID and PokemonData.Pokemon and PokemonData.Pokemon[pokemonID] then
                local romPokemon = PokemonData.Pokemon[pokemonID]
                if romPokemon and romPokemon.types then
                    local shallowCopy = {}
                    for k, v in pairs(pokemon) do
                        shallowCopy[k] = v
                    end
                    setmetatable(shallowCopy, getmetatable(pokemon))
                    shallowCopy.types = romPokemon.types
                    return shallowCopy
                end
            end
            return pokemon
        end
    end

    -- 7. GachaMon IGachaMon getCardDisplayData hook (for streamer-altered types and ROM-randomized fallback)
    local function patchGachaMonDisplay()
        if not GachaMonData or not GachaMonData.IGachaMon or not GachaMonData.IGachaMon.getCardDisplayData then
            return
        end
        _G.RoguemonStreamer_Backups = _G.RoguemonStreamer_Backups or {}
        if not _G.RoguemonStreamer_Backups.getCardDisplayData then
            _G.RoguemonStreamer_Backups.getCardDisplayData = GachaMonData.IGachaMon.getCardDisplayData
        end
        GachaMonData.IGachaMon.getCardDisplayData = function(self)
            local oldType1 = self.Type1
            local oldType2 = self.Type2

            local altered = RoguemonStreamer.getAlteredTypes(self.Personality)
            if altered then
                local t1Name = altered[1]
                local t2Name = altered[2] or t1Name
                self.Type1 = PokemonData.TypeNameToIndexMap[t1Name] or self.Type1
                self.Type2 = PokemonData.TypeNameToIndexMap[t2Name] or self.Type1
            else
                local romPokemon = PokemonData.Pokemon and PokemonData.Pokemon[self.PokemonId]
                if romPokemon and romPokemon.types then
                    self.Type1 = PokemonData.TypeNameToIndexMap[romPokemon.types[1] or PokemonData.Types.UNKNOWN] or self.Type1
                    self.Type2 = PokemonData.TypeNameToIndexMap[romPokemon.types[2] or false] or self.Type1
                end
            end

            self.Temp.Card = nil
            local card = _G.RoguemonStreamer_Backups.getCardDisplayData(self)

            self.Type1 = oldType1
            self.Type2 = oldType2
            return card
        end
    end

    -- 8. GachaMonData.convertPokemonToGachaMon hook (assigns randomized/altered types on creation)
    local function patchConvertPokemonToGachaMon()
        if not GachaMonData or not GachaMonData.convertPokemonToGachaMon then return end
        _G.RoguemonStreamer_Backups = _G.RoguemonStreamer_Backups or {}
        if not _G.RoguemonStreamer_Backups.convertPokemonToGachaMon then
            _G.RoguemonStreamer_Backups.convertPokemonToGachaMon = GachaMonData.convertPokemonToGachaMon
        end
        GachaMonData.convertPokemonToGachaMon = function(pokemonData)
            local gachamon = _G.RoguemonStreamer_Backups.convertPokemonToGachaMon(pokemonData)
            if gachamon then
                local altered = RoguemonStreamer.getAlteredTypes(gachamon.Personality)
                if altered then
                    local t1Name = altered[1]
                    local t2Name = altered[2] or t1Name
                    gachamon.Type1 = PokemonData.TypeNameToIndexMap[t1Name] or gachamon.Type1
                    gachamon.Type2 = PokemonData.TypeNameToIndexMap[t2Name] or gachamon.Type1
                else
                    local romPokemon = PokemonData.Pokemon and PokemonData.Pokemon[gachamon.PokemonId]
                    if romPokemon and romPokemon.types then
                        gachamon.Type1 = PokemonData.TypeNameToIndexMap[romPokemon.types[1] or PokemonData.Types.UNKNOWN] or gachamon.Type1
                        gachamon.Type2 = PokemonData.TypeNameToIndexMap[romPokemon.types[2] or false] or gachamon.Type1
                    end
                end
                gachamon.Temp.Card = nil
            end
            return gachamon
        end
    end

    patchGetNatDexCompatible()
    patchGachaMonDisplay()
    patchConvertPokemonToGachaMon()

end

-- Hook to correct Pokemon abilities, stats, and types using the log file when available
if RandomizerLog and PokemonData then
    _G.__roguemonStreamerOriginals = _G.__roguemonStreamerOriginals or {}
    if _G.__roguemonStreamerOriginals.parseBaseStatsItems == nil then
        _G.__roguemonStreamerOriginals.parseBaseStatsItems = RandomizerLog.parseBaseStatsItems
    end

    local originalParseBaseStatsItems = _G.__roguemonStreamerOriginals.parseBaseStatsItems
    RandomizerLog.parseBaseStatsItems = function(logLines)
        if originalParseBaseStatsItems then
            originalParseBaseStatsItems(logLines)
        end

        if logLines and #logLines > 0 and RandomizerLog.Sectors and RandomizerLog.Sectors.BaseStatsItems and RandomizerLog.Sectors.BaseStatsItems.LineNumber ~= nil then
            local pattern = "^%s*(%d*)|(.-)%s*|(.-)%s*|%s*(%d*)|%s*(%d*)|%s*(%d*)|%s*(%d*)|%s*(%d*)|%s*(%d*)|(.-)%s*|(.-)%s*|(.-)%s*|(.*)"
            local index = RandomizerLog.Sectors.BaseStatsItems.LineNumber + 1
            while index <= #logLines do
                local id, pokemon, types, hp, atk, def, spa, spd, spe, ability1, ability2, ability3, helditems = string.match(logLines[index] or "", pattern)
                id = tonumber(tostring(id)) or 0
                pokemon = RandomizerLog.formatInput(pokemon)
                pokemon = RandomizerLog.alternateNidorans(pokemon)

                if pokemon == nil or spe == nil then
                    break
                end

                local pokemonId = PokemonData.dexMapNationalToInternal(id)
                local pokemonData = RandomizerLog.Data.Pokemon[pokemonId]
                local internalMon = PokemonData.Pokemon[pokemonId]
                
                if pokemonData ~= nil and internalMon ~= nil then
                    ability1 = RandomizerLog.formatInput(ability1) or ""
                    ability2 = RandomizerLog.formatInput(ability2) or ""
                    ability3 = RandomizerLog.formatInput(ability3) or ""
                    
                    local abilities = {
                        RandomizerLog.AbilityNameToIdMap[ability1] or (AbilityData and AbilityData.DefaultAbility and AbilityData.DefaultAbility.id) or 0,
                        RandomizerLog.AbilityNameToIdMap[ability2],
                        RandomizerLog.AbilityNameToIdMap[ability3],
                    }
                    
                    pokemonData.Abilities = abilities
                    internalMon.abilities = abilities
                    
                    local type1, type2 = string.match(types or "", "([^/]+)/?(.*)")
                    local parsedTypes = {
                        PokemonData.Types[string.upper(type1 or "")] or PokemonData.Types.EMPTY,
                        PokemonData.Types[string.upper(type2 or "")] or PokemonData.Types.EMPTY,
                    }
                    pokemonData.Types = parsedTypes
                    internalMon.types = parsedTypes
                    
                    local parsedStats = {
                        hp = tonumber(hp) or 0,
                        atk = tonumber(atk) or 0,
                        def = tonumber(def) or 0,
                        spa = tonumber(spa) or 0,
                        spd = tonumber(spd) or 0,
                        spe = tonumber(spe) or 0,
                    }
                    pokemonData.BaseStats = parsedStats
                    internalMon.baseStats = parsedStats
                end
                index = index + 1
            end
        end
    end
end


