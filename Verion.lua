--[[
Congrats on deobfuscating this shit! I hope your day ruined.
]]

local Verion = {}
Verion.__index = Verion

local VerionState = {
    Enabled = true,
    ScriptContent = "",
    BanAttempts = 0,
    KickAttempts = 0,
    DebugMode = true,
    ProtectedServices = {},
    HookedFunctions = {},
    OriginalMetatables = {},
    UserId = game.Players.LocalPlayer.UserId,
    SandboxEnv = nil,
}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local ScriptContext = game:GetService("ScriptContext")

-- starter
print("Functions name are shortened into 1 character.")
print("loaded functions : l,g,v,s,h,c,n,b,r,f")
print()
print()
print("to prevent people from editing VerionNot: verion is programmed by sxc_qq1, in yxgg server")

local function LogMessage(message)
    if VerionState.DebugMode then
        print("" .. message)
    end
end

local function GenerateUUID()
    return HttpService:GenerateGUID(false)
end

function Verion.new()
    local self = setmetatable({}, Verion)
    self.InstanceId = GenerateUUID()
    self.Protected = false
    LogMessage("[Verion] New Verion instance created with ID: " .. self.InstanceId)
    
    return self
end

local function SetupAdvancedMetatableHooks()
    local mt = getrawmetatable(game)
    VerionState.OriginalMetatables["game"] = {
        __namecall = mt.__namecall,
        __index = mt.__index,
        __newindex = mt.__newindex
    }
    setreadonly(mt, false)

    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if method == "BanAsync" then
            VerionState.BanAttempts = VerionState.BanAttempts + 1
            for _, arg in pairs(args) do
                if type(arg) == "table" and arg.UserIds and table.find(arg.UserIds, VerionState.UserId) then
                    LogMessage("[Verion] blocked BanAsync targeting UserId " .. VerionState.UserId)
                    return nil
                end
            end
            LogMessage("[Verion] BanAsync attempt #" .. VerionState.BanAttempts)
            return nil

        elseif method == "Kick" then
            VerionState.KickAttempts = VerionState.KickAttempts + 1
            if self == LocalPlayer then
                LogMessage("[Verion] blocked kick attempt on LocalPlayer")
                return false
            end
            
            LogMessage("[Verion] generic Kick attempt #" .. VerionState.KickAttempts)
            return false

        elseif method == "Destroy" then
            if self == LocalPlayer or (LocalPlayer.Character and self:IsDescendantOf(LocalPlayer.Character)) then
                LogMessage("[Verion] blocked Destroy attempt on local player's object")
                return nil
            end

        elseif method == "SetNetworkOwner" then
            if LocalPlayer.Character and self:IsDescendantOf(LocalPlayer.Character) then
                LogMessage("[Verion] blocked SetNetworkOwner attempt on local player's object")
                return nil
            end
        end

        return VerionState.OriginalMetatables["game"].__namecall(self, ...)
    end)

    mt.__index = newcclosure(function(self, key)
        if (self == LocalPlayer or (LocalPlayer.Character and self:IsDescendantOf(LocalPlayer.Character))) and 
           (key == "BanAsync" or key == "Kick" or key == "Destroy" or key == "SetNetworkOwner") then
            LogMessage("[Verion] Blocked access to " .. key .. " via __index")
            return function(...) return nil end
        end
        
        return VerionState.OriginalMetatables["game"].__index(self, key)
    end)

    mt.__newindex = newcclosure(function(self, key, value)
        if (self == LocalPlayer or (LocalPlayer.Character and self:IsDescendantOf(LocalPlayer.Character))) and 
           (key == "BanAsync" or key == "Kick" or key == "Destroy" or key == "SetNetworkOwner") then
            LogMessage("[Verion] Prevented modification of " .. key .. " via __newindex")
            return
        end
        
        VerionState.OriginalMetatables["game"].__newindex(self, key, value)
    end)

    setreadonly(mt, true)
    LogMessage("[Verion] metatable hooks applied")
end

local function HookPlayersService()
    local playersMt = getrawmetatable(Players)
    VerionState.OriginalMetatables["Players"] = {
        __namecall = playersMt.__namecall,
        __index = playersMt.__index
    }
    setreadonly(playersMt, false)

    playersMt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if method == "GetPlayerByUserId" and args[1] == VerionState.UserId then
            LogMessage("[Verion] blocked GetPlayerByUserId for UserId " .. VerionState.UserId)
            return nil
        end

        return VerionState.OriginalMetatables["Players"].__namecall(self, ...)
    end)

    setreadonly(playersMt, true)
    LogMessage("[Verion] players service hooked for UserId protection")
end

local function CreateSandboxEnvironment()
    local realGame = game
    local in_loadstring = false

    local function createProxy(obj)
        return setmetatable({}, {
            __index = function(_, key)
                if key == "BanAsync" or key == "Kick" or key == "Destroy" then
                    return function(...) return nil end
                end             

                if in_loadstring and obj == realGame then
                    return realGame[key]
                end

                local value = obj[key]

                if type(value) == "function" then
                    return function(self, ...)
                        if self == _ then
                            return value(obj, ...)
                        end
                        return value(self, ...)
                    end
                end

                if type(value) == "table" or type(value) == "userdata" then
                    return createProxy(value)
                end

                return value
            end,
            __newindex = function() end
        })
    end

    local function secureLoadstring(code)
        local func = loadstring(code)
        if typeof(func) == "function" then
            setfenv(func, setmetatable({
                game = createProxy(realGame),
                print = print,
                loadstring = secureLoadstring,
            }, { __index = _G }))
        end

        return function(...)
            in_loadstring = true
            local ok, result = pcall(func, ...)
            in_loadstring = false
            if not ok then error(result) end

            return result
        end
    end

    local sandbox = setmetatable({
        print = print,
        game = createProxy(game),
        loadstring = secureLoadstring,
    }, { __index = _G })

    VerionState.SandboxEnv = sandbox
    LogMessage("☄️ sandbox environment created")
end

local function MonitorRemoteEvents()
    local remoteEvents = {}
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            table.insert(remoteEvents, obj)
        end
    end

    for _, remote in pairs(remoteEvents) do
        local oldFire = remote.OnClientEvent
        VerionState.HookedFunctions[remote] = oldFire
        remote.OnClientEvent:Connect(function(...)
            local args = {...}
            for _, arg in pairs(args) do
                if type(arg) == "string" and (arg:lower():find("ban") or arg:lower():find("kick")) then
                    LogMessage("[Verion] blocked suspicious remote event: " .. remote.Name)
                    return
                
                elseif type(arg) == "number" and arg == VerionState.UserId then
                    LogMessage("[Verion] blocked remote event targeting UserId " .. VerionState.UserId)
                    return
                end
            end
            
            oldFire(...)
        end)
    end
    LogMessage("[Verion] monitoring " .. #remoteEvents .. " remote events")
end

local function NeutralizeScripts()
    local function CheckScript(scriptObj)
        if scriptObj:IsA("Script") or scriptObj:IsA("LocalScript") then
            local source = scriptObj.Source
            local lowerSource = source:lower()

            if lowerSource:find("banasync") or lowerSource:find("banned") or lowerSource:find("moderation") or lowerSource:find("banned") or lowerSource:find("anticheat") or lowerSource:find("kick") or source:find(tostring(VerionState.UserId)) then
                LogMessage("[Verion] neutralizing script: " .. scriptObj.Name)
                scriptObj:Destroy()
            end
        end
    end

    for _, obj in pairs(game:GetDescendants()) do
        CheckScript(obj)
    end

    game.DescendantAdded:Connect(function(obj)
        if VerionState.Enabled then
            CheckScript(obj)
        end
    end)
end

local function SimulateServerSide(callbacks)
    local heartbeatConnection

    heartbeatConnection = RunService.Heartbeat:Connect(function()
        if not VerionState.Enabled then
            heartbeatConnection:Disconnect()
            return
        end

        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

        if callbacks and type(callbacks) == "table" then
            for _, func in ipairs(callbacks) do
                if typeof(func) == "function" then
                    task.spawn(func, character, humanoid)
                end
            end
        end
    end)
end

function Verion:script_load()
    if not self.Protected then
        LogMessage("[Verion] protection not initialized. Call Protect() first.")
        return
    end

    if VerionState.ScriptContent == "" then
        LogMessage("[Verion] no script content provided")
        return
    end

    local success, err = pcall(function()
        local func = loadstring(VerionState.ScriptContent)
        if func then
            setfenv(func, VerionState.SandboxEnv)
            func()
            LogMessage("[Verion] script executed in sandbox")
        else
            LogMessage("[Verion] failed to compile exploit script")
        end
    end)

    if not success then
        LogMessage("Error executing script: " .. tostring(err))
    end
end

function Verion:SetScript(scriptContent)
    VerionState.ScriptContent = scriptContent
    LogMessage("[Verion] script content set")
end

function Verion:Protect()
    if self.Protected then
        LogMessage("[Verion] protection already active for instance " .. self.InstanceId)
        return
    end

    SetupAdvancedMetatableHooks()
    HookPlayersService()
    CreateSandboxEnvironment()
    MonitorRemoteEvents()
    NeutralizeScripts()
    SimulateServerSide()

    self.Protected = true
    LogMessage("[Verion] protection activated for instance " .. self.InstanceId)
end

function Verion:Disable()
    VerionState.Enabled = false
    self.Protected = false
    if VerionState.HookedFunctions["ScriptContext_Error"] then
        VerionState.HookedFunctions["ScriptContext_Error"]:Disconnect()
        VerionState.HookedFunctions["ScriptContext_Error"] = nil
        LogMessage("[Verion] ScriptContext error hook disconnected")
    end
    LogMessage("[Verion] protection disabled for instance " .. self.InstanceId)
end

function Verion:ToggleDebug(mode)
    VerionState.DebugMode = mode
    LogMessage("[Verion] debug mode set to " .. tostring(mode))
end

function Verion:GetStats()
    return {
        BanAttempts = VerionState.BanAttempts,
        KickAttempts = VerionState.KickAttempts,
        InstanceId = self.InstanceId,
        Enabled = VerionState.Enabled,
        Protected = self.Protected,
        UserId = VerionState.UserId
    }
end

local function SpoofServerResponse()
    local spoofedResponses = {
        ["BanCheck"] = false,
        ["KickCheck"] = nil,
        ["AdminStatus"] = false,
        ["UserIdCheck"] = nil
    }

    for _, obj in pairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
        if obj:IsA("RemoteFunction") then
            local oldInvoke = obj.InvokeServer
            VerionState.HookedFunctions[obj] = oldInvoke
            obj.InvokeServer = function(self, key, ...)
                if spoofedResponses[key] ~= nil then
                    LogMessage("[Verion] spoofed server response for " .. key .. " on " .. obj.Name)
                    return spoofedResponses[key]
                end
                return oldInvoke(self, key, ...)
            end
            LogMessage("[Verion] hooked InvokeServer for RemoteFunction: " .. obj.Name)
        end
    end
    LogMessage("[Verion] server response spoofing enabled for RemoteFunctions")
end

local function CleanupSuspiciousInstances()
    local suspiciousClasses = {"Script", "LocalScript", "ModuleScript"}
    local cleaned = 0

    for _, obj in pairs(game:GetDescendants()) do
        if table.find(suspiciousClasses, obj.ClassName) then
            local name = obj.Name:lower()
            if name:find("ban") or name:find("kick") or name:find("anticheat") or name:find(tostring(VerionState.UserId)) then
                obj:Destroy()
                cleaned = cleaned + 1
                LogMessage("[Verion] cleaned suspicious instance: " .. obj.Name)
            end
        end
    end

    LogMessage("[Verion] cleaned " .. cleaned .. " suspicious instances")
end

local function BlockAdminCommands()
    local chatService = game:GetService("TextChatService")
    if not chatService then return end

    local playerName = LocalPlayer.Name:lower()
    local displayName = LocalPlayer.DisplayName:lower()
    local userId = tostring(VerionState.UserId)

    local function normalize(str)
        return str:lower():gsub("[^a-z0-9]", "")
    end

    local normalizedName = normalize(playerName)
    local normalizedDisplay = normalize(displayName)
    local normalizedId = normalize(userId)

    local suspiciousCommands = {
        "ban", "kick", "punish", "crash", "kill", "timeout", "jail", "perma", "crashclient"
    }

    local function isSuspiciousCommand(text)
        local normalizedText = normalize(text)

        for _, command in ipairs(suspiciousCommands) do
            local pattern = normalize(command)
            if normalizedText:find(pattern .. normalizedName)
            or normalizedText:find(pattern .. normalizedDisplay)
            or normalizedText:find(pattern .. normalizedId) then
                return true
            end
        end

        return false
    end

    local function connectChannel(channel)
        if not channel:IsA("TextChannel") then return end
        channel.MessageReceived:Connect(function(message)
            if isSuspiciousCommand(message.Text) then
                LogMessage("[Verion] blocked potential cmd: " .. message.Text)
                message.Text = "[Verion] cmd neutralized"
            end
        end)
    end

    for _, channel in ipairs(chatService.TextChannels:GetChildren()) do
        connectChannel(channel)
    end

    chatService.TextChannels.ChildAdded:Connect(connectChannel)
end

local function HookScriptContext()
    local connection = ScriptContext.Error:Connect(function(message, stackTrace, script)
        if message:lower():find("kick") or message:lower():find("ban") then
            LogMessage("[Verion] detected and potentially blocked error-based kick/ban: " .. message)
        else
            LogMessage("[Verion] non-suspicious error detected: " .. message)
        end
    end)
    VerionState.HookedFunctions["ScriptContext_Error"] = connection
    LogMessage("ScriptContext error event hooking enabled")
end

function Verion:Initialize()
    SpoofServerResponse()
    CleanupSuspiciousInstances()
    BlockAdminCommands()
    HookScriptContext()
    
    LogMessage("☄️ verion library fully initialized")
end

local function CreateVerionInstance()
    local verion = Verion.new()
    verion:Initialize()
    verion:Protect()
    
    return verion
end

return function()
    local verionInstance = CreateVerionInstance()
    return {
        script = function(content)
            verionInstance:SetScript(content)
        end,
        
        script_load = function()
            verionInstance:script_load()
        end,
        
        protect = function()
            verionInstance:Protect()
        end,
        
        disable = function()
            verionInstance:Disable()
        end,
        
        toggle_debug = function(mode)
            verionInstance:ToggleDebug(mode)
        end,
        
        get_stats = function()
            return verionInstance:GetStats()
        end
    }
end