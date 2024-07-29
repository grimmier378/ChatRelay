--[[ 
    Title: Chat Relay
    Author: Grimmier
    Description: Guild Chat Relay over Actors.
]]

local mq = require('mq')
local ImGui = require 'ImGui'
local actors = require('actors')
local defaults, settings = {}, {}
local script = 'Chat Relay'
local Actor -- preloaded variable outside of the function
local showMain, showConfig = false, false
local winFlags = bit32.bor(ImGuiWindowFlags.None)
local RUNNING, aSize  = false, false
local currZone, lastZone, guildName, ME, configFile, mode
local guildChat = {}
local tellChat = {}
local lastMessages = {}
local RelayGuild, RelayTells = false, false

defaults = {
    Scale = 1,
    AutoSize = false,
    ShowTooltip = true,
    RelayTells = true,
    RelayGuild = true,
    MaxRow = 1,
    AlphaSort = false,
    ShowOnNewMessage = true,
}

---comment Check to see if the file we want to work on exists.
---@param name string -- Full Path to file
---@return boolean -- returns true if the file exists and false otherwise
local function File_Exists(name)
    local f=io.open(name,"r")
    if f~=nil then io.close(f) return true else return false end
end

local function loadSettings()
    -- Check if the dialog data file exists
    local newSetting = false
    if not File_Exists(configFile) then
        settings[script] = defaults
        mq.pickle(configFile, settings)
        loadSettings()
    else
        -- Load settings from the Lua config file
        settings = dofile(configFile)
        if settings[script] == nil then
            settings[script] = {}
            settings[script] = defaults 
            newSetting = true
        end
    end

    for k, v in pairs(defaults) do
        if settings[script][k] == nil then
            settings[script][k] = v
            newSetting = true
        end
    end
    RelayGuild = settings[script].RelayGuild
    RelayTells = settings[script].RelayTells
    if newSetting then mq.pickle(configFile, settings) end
end

local function GenerateContent(sub, message)
    local Subject = sub
    return {
        Subject = Subject,
        Name = ME,
        Guild = guildName,
        Message = message,
        Tell = '',
    }
end

-- Function to append colored text segments
local function appendColoredTimestamp(con, text)

    local timestamp = mq.TLO.Time.Time24()
    local yellowColor = ImVec4(1, 1, 0, 1)
    local whiteColor = ImVec4(1, 1, 1, 1)
    local greenColor = ImVec4(0, 1, 0, 1)
    local tealColor = ImVec4(0, 1, 1, 1)
    con:AppendTextUnformatted(yellowColor, "[")
    con:AppendTextUnformatted(whiteColor, timestamp)
    con:AppendTextUnformatted(yellowColor, "] ")
    con:AppendTextUnformatted(greenColor, text)
    con:AppendText("")
end

--create mailbox for actors to send messages to
local function RegisterActor()
    Actor = actors.register('chat_relay', function(message)
        local MemberEntry = message()
        if MemberEntry.Subject == 'Guild' and settings[script].RelayGuild then
            if lastMessages[MemberEntry.Guild] == nil then
                lastMessages[MemberEntry.Guild] = MemberEntry.Message
            elseif lastMessages[MemberEntry.Guild] == MemberEntry.Message then
                return
            else
                lastMessages[MemberEntry.Guild] = MemberEntry.Message
            end
            if guildChat[MemberEntry.Guild] == nil then
                guildChat[MemberEntry.Guild] = ImGui.ConsoleWidget.new("chat_relay_Console"..MemberEntry.Guild.."##chat_relayConsole")
            end
            appendColoredTimestamp(guildChat[MemberEntry.Guild], MemberEntry.Message)
        elseif MemberEntry.Subject == 'Tell' and settings[script].RelayTells then
            if tellChat[MemberEntry.Name] == nil then
                tellChat[MemberEntry.Name] = ImGui.ConsoleWidget.new("chat_relay_Console"..MemberEntry.Name.."##chat_relayConsole")
            end
            appendColoredTimestamp(tellChat[MemberEntry.Name], MemberEntry.Message)
        elseif MemberEntry.Subject == 'Reply' and MemberEntry.Name == ME and settings[script].RelayTells then
            mq.cmdf("/tell %s %s", MemberEntry.Tell, MemberEntry.Message)
        elseif MemberEntry.Subject == 'Hello' then
            if MemberEntry.Name ~= ME then
                if tellChat[MemberEntry.Name] == nil then
                    tellChat[MemberEntry.Name] = ImGui.ConsoleWidget.new("chat_relay_Console"..MemberEntry.Name.."##chat_relayConsole")
                end
                if guildChat[MemberEntry.Guild] == nil then
                    guildChat[MemberEntry.Guild] = ImGui.ConsoleWidget.new("chat_relay_Console"..MemberEntry.Guild.."##chat_relayConsole")
                end
            end
        else
            return
        end
        if settings[script].ShowOnNewMessage and mode == 'driver' then
            showMain = true
        end
    end)
end

local function StringTrim(s)
    return s:gsub("^%s*(.-)%s*$", "%1")
end

local function sortedBoxes(boxes)
    local keys = {}
    for k in pairs(boxes) do
        table.insert(keys, k)
    end
    table.sort(keys, function(a, b)
        return a < b
    end)
    return keys
end

---comments
---@param text string -- the incomming line of text from the command prompt
local function ChannelExecCommand(text, channName, channelID)
    local separator = "|"
    local args = {}
    for arg in string.gmatch(text, "([^"..separator.."]+)") do
        table.insert(args, arg)
    end
    local who = args[1]
    local message = args[2]
    -- todo: implement history
    if string.len(text) > 0 then
        text = StringTrim(text)
        if text == 'clear' then
            channelID:Clear()
        elseif who ~= nil and message ~= nil then
            Actor:send({mailbox = 'chat_relay'}, { Name = channName, Subject = 'Reply', Tell = who, Message = message })
        end
    end
end

local function getGuildChat(line)
    if not settings[script].RelayGuild then return end
    Actor:send({mailbox = 'chat_relay'}, GenerateContent('Guild', line))
end

local function getTellChat(line, who)
    if not settings[script].RelayTells then return end
    local checkNPC = string.format("npc =%s",who)
    local checkPet = string.format("pcpet =%s",who)
    local pet = mq.TLO.Me.Pet.DisplayName() or 'noPet'
    if (mq.TLO.SpawnCount(checkNPC)() ~= 0 or mq.TLO.SpawnCount(checkPet)() ~= 0 or string.find(who, pet)) then return end
    Actor:send({mailbox = 'chat_relay'}, GenerateContent('Tell', line))
end

local function RenderGUI()

    if showMain then
        ImGui.PushStyleColor(ImGuiCol.TabActive, ImVec4(0.848, 0.449, 0.115, 1.000))
        ImGui.SetNextWindowSize(185, 480, ImGuiCond.FirstUseEver)
        if aSize then
            winFlags = bit32.bor(ImGuiWindowFlags.AlwaysAutoResize)
        else
            winFlags = bit32.bor(ImGuiWindowFlags.None)
        end
        local winLbl = string.format("%s##%s_%s", script, script, ME)
        local openGUI, showGUI = ImGui.Begin(winLbl, true, winFlags)
        if not openGUI then
            showMain = false
        end
        if showGUI then
            if ImGui.Button("Config") then
                showConfig = not showConfig
            end
            ImGui.SameLine()
            if ImGui.BeginTabBar("Chat Relay##ChatRelay", ImGuiTabBarFlags.None) then
                if RelayGuild then
                    if ImGui.BeginTabItem("Guild Chat") then
                        if ImGui.BeginTabBar("Guild Chat##GuildChat", ImGuiTabBarFlags.None) then
                            local sortedKeys = {}
                            sortedKeys = sortedBoxes(guildChat)
                            for key in pairs(sortedKeys) do
                                local gName = sortedKeys[key]
                                local gConsole = guildChat[gName]
                                local contentSizeX, contentSizeY = ImGui.GetContentRegionAvail()
                                contentSizeY = contentSizeY - 10
                                if ImGui.BeginTabItem(gName) then
                                    gConsole:Render(ImVec2(contentSizeX, contentSizeY))
                                    ImGui.EndTabItem()
                                end
                            end
                            ImGui.EndTabBar()
                        end
                        ImGui.EndTabItem()
                    end
                end
                if RelayTells then
                    if ImGui.BeginTabItem("Tell Chat") then
                        if ImGui.BeginTabBar("Tell Chat##TellChat", ImGuiTabBarFlags.None) then
                            local sortedKeys = {}
                            sortedKeys = sortedBoxes(tellChat)
                            for key in pairs(sortedKeys) do
                                local tName = sortedKeys[key]
                                local tConsole = tellChat[tName]
                                local contentSizeX, contentSizeY = ImGui.GetContentRegionAvail()
                                contentSizeY = contentSizeY - 30
                                if ImGui.BeginTabItem(tName) then
                                    tConsole:Render(ImVec2(contentSizeX, contentSizeY))
                                    --Command Line
                                    ImGui.Separator()
                                    local textFlags = bit32.bor(0,
                                        ImGuiInputTextFlags.EnterReturnsTrue
                                        -- not implemented yet
                                        -- ImGuiInputTextFlags.CallbackCompletion,
                                        -- ImGuiInputTextFlags.CallbackHistory
                                    )
                                    -- local contentSizeX, _ = ImGui.GetContentRegionAvail()
                                    ImGui.SetCursorPosX(ImGui.GetCursorPosX() + 2)
                                    ImGui.SetCursorPosY(ImGui.GetCursorPosY() + 2)
                                    local accept = false
                                    local cmdBuffer = ''
                                    cmdBuffer, accept = ImGui.InputTextWithHint('##Input##'..tName, "who|message",cmdBuffer, textFlags)
                                    if accept then
                                        ChannelExecCommand(cmdBuffer,tName, tConsole)
                                        cmdBuffer = ''
                                    end
                                    ImGui.EndTabItem()
                                end
                            end
                            ImGui.EndTabBar()
                        end
                        ImGui.EndTabItem()
                    end
                end
                ImGui.EndTabBar()
            end
        end
        ImGui.PopStyleColor()
        ImGui.End()
    end

    if showConfig then
        local openConfGui, showConfGui = ImGui.Begin("Chat Relay Config", true, ImGuiWindowFlags.None)
        if not openConfGui then
            showConfig = false
        end
        if showConfGui then
            ImGui.Text("Chat Relay Configuration")
            ImGui.Separator()
            ImGui.Text("Chat Relay Settings")
            RelayTells = ImGui.Checkbox("Relay Tells", RelayTells)
            RelayGuild = ImGui.Checkbox("Relay Guild", RelayGuild)
            ImGui.Separator()
            settings[script].ShowOnNewMessage = ImGui.Checkbox("Show on New Message", settings[script].ShowOnNewMessage)
            ImGui.Separator()
            if ImGui.Button("Save") then
                settings[script].RelayTells = RelayTells
                settings[script].RelayGuild = RelayGuild
                mq.pickle(configFile, settings)
                showConfig = false
            end
            ImGui.End()
        end
    end
end

local args = {...}
local function checkArgs(args)
    if #args > 0 then
        if args[1] == 'driver' then
            showMain = true
            mode = 'driver'
            print('\ayChat Relay:\ao Setting \atDriver\ax Mode. UI will be displayed.')
            print('\ayChat Relay:\ao Type \at/chatrelay show\ax. to Toggle the UI')
        elseif args[1] == 'client' then
            showMain = false
            mode = 'client'
            print('\ayChat Relay:\ao Setting \atClient\ax Mode. UI will not be displayed.')
            print('\ayChat Relay:\ao Type \at/chatrelay show\ax. to Toggle the UI')
        end
    else
        showMain = true
        mode = 'driver'
        print('\ayChat Relay: \aoNo arguments passed, defaulting to \atDriver\ax Mode. UI will be displayed.')
        print('\ayChat Relay: \aoUse \at/lua run chatrelay client\ax To start with the UI Off.')
        print('\ayChat Relay:\ao Type \at/chatrelay show\ax. to Toggle the UI')
    end
end

local function processCommand(...)
    local args = {...}
    if #args > 0 then
        if args[1] == 'gui' or args[1] == 'show' or args[1] == 'open' then
            showMain = not showMain
            if showMain then
                print('\ayChat Relay:\ao Toggling GUI \atOpen\ax.')
            else
                print('\ayChat Relay:\ao Toggling GUI \atClosed\ax.')
            end
        elseif args[1] == 'exit' or args[1] == 'quit'  then
            print('\ayChat Relay:\ao Exiting.')
            RUNNING = false
        elseif args[1] == 'tells' then
            settings[script].RelayTells = not settings[script].RelayTells
            RelayTells = settings[script].RelayTells
            mq.pickle(configFile, settings)
        elseif args[1] == 'guild' then
            settings[script].RelayGuild = not settings[script].RelayGuild
            RelayGuild = settings[script].RelayGuild
            mq.pickle(configFile, settings)
        elseif args[1] == 'autoshow' then
            settings[script].ShowOnNewMessage = not settings[script].ShowOnNewMessage
            mq.pickle(configFile, settings)
        else
            print('\ayChat Relay:\ao Invalid command given.')
        end
    else
        print('\ayChat Relay:\ao No command given.')
        print('\ayChat Relay:\ag /chatrelay gui \ao- Toggles the GUI on and off.')
        print('\ayChat Relay:\ag /chatrelay tells \ao- Toggles the Relay of Tells.')
        print('\ayChat Relay:\ag /chatrelay guild \ao- Toggles the Relay of Guild Chat.')
        print('\ayChat Relay:\ag /chatrelay autoshow \ao- Toggles the Show on New Message.')
        print('\ayChat Relay:\ag /chatrelay exit \ao- Exits the plugin.')
    end
end

local function firstRun()
    Actor:send({mailbox = 'chat_relay'}, GenerateContent('Hello','Hello'))
end

local function init()
    ME = mq.TLO.Me.DisplayName()
    guildName = mq.TLO.Me.Guild()
    configFile = string.format("%s/MyUI/ChatRelay/%s/%s.lua", mq.configDir, mq.TLO.EverQuest.Server(), ME)
    currZone = mq.TLO.Zone.ID()
    lastZone = currZone
    checkArgs(args)
    mq.bind('/chatrelay', processCommand)
    loadSettings()
    RegisterActor()
    mq.delay(250)
    mq.event('guild_chat_relay', '#*# tells the guild, #*#', getGuildChat)
    mq.event('tell_chat_relay', "#1# tells you, '#*#", getTellChat)
    mq.event('out_chat_relay', "You told #1#, '#*#", getTellChat)
    RUNNING = true
    guildChat[guildName] = ImGui.ConsoleWidget.new("chat_relay_Console"..guildName.."##chat_relayConsole")
    guildChat[guildName]:AppendText("Welcome to Chat Relay")
    tellChat[ME] = ImGui.ConsoleWidget.new("chat_relay_Console"..ME.."##chat_relayConsole")
    firstRun()
    mq.imgui.init('Chat_Relay', RenderGUI)
end

local function mainLoop()
    while RUNNING do
        if  mq.TLO.EverQuest.GameState() ~= "INGAME" then print("\aw[\atChat Relay\ax] \arNot in game, \aoSaying \ayGoodbye\ax and Shutting Down...") mq.exit() end
        currZone = mq.TLO.Zone.ID()
        if currZone ~= lastZone then
            mq.delay(1000)
            lastZone = currZone
        end
        mq.doevents()
        mq.delay(50)
    end
    mq.exit()
end

if mq.TLO.EverQuest.GameState() ~= "INGAME" then print("\aw[\atChat Relay\ax] \arNot in game, \ayTry again later...") mq.exit() end
init()
mainLoop()