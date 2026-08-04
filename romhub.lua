-- ===================== ROMASHKA HUB (DEFAULT / KEY) =====================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local AUTH_FILE = "RomashkaHub_Auth.json"
local KeyPassed = false
local CurrentAuth = nil

local function SaveAuth(key, expires)
    CurrentAuth = { key = key, expires = expires or 0 }
    pcall(function() writefile(AUTH_FILE, HttpService:JSONEncode(CurrentAuth)) end)
end

local function LoadAuth()
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(AUTH_FILE)) end)
    if ok and data and data.key then
        if data.expires == 0 or data.expires > os.time() then
            CurrentAuth = data
            return true
        end
        pcall(function() writefile(AUTH_FILE, "{}") end)
    end
    return false
end

local function IsValidKeyFormat(key)
    if not key or key == "" then return false end
    key = key:upper():gsub("%s+", "")
    return key:match("^ROM%-[A-Z0-9]+%-[A-Z0-9]+%-[A-Z0-9]+%-[A-Z0-9]+$") ~= nil
end

local function GetTimeLeft()
    if not CurrentAuth then return "нет" end
    if CurrentAuth.expires == 0 then return "Навсегда" end
    local left = CurrentAuth.expires - os.time()
    if left <= 0 then return "ИСТЁК" end
    return string.format("%dч %dм", math.floor(left / 3600), math.floor((left % 3600) / 60))
end

if LoadAuth() then KeyPassed = true end

local MaxDistance, RainbowSpeed = 3000, 0.5
local ESPColor = Color3.fromRGB(0, 255, 180)
local UseRainbow, TeamCheck = true, false
local Whitelist = {}
local AimEnabled, AimFOV, ShowFOV = true, 90, true
local AimSensitivity, FOVColor = 0.35, Color3.fromRGB(255, 140, 50)
local AimPartMode, ESPEnabled = "Head", true
local HitboxEnabled, HitboxSize = false, 2.5
local HitboxParts = { Head = true, Torso = false, Arms = false, Legs = false }
local OriginalSizes = {}
local ConfigName = "default"

local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5
FOVCircle.NumSides = 64
FOVCircle.Radius = AimFOV
FOVCircle.Filled = false
FOVCircle.Transparency = 1
FOVCircle.Color = FOVColor
FOVCircle.Visible = false

local function GetPlayerTeam(player)
    if not player then return nil end
    if player.Team then return player.Team end
    if player.TeamColor then return player.TeamColor end
    return nil
end

local function IsTeammate(character)
    if not TeamCheck then return false end
    local other = Players:GetPlayerFromCharacter(character)
    if not other or other == LocalPlayer then return other == LocalPlayer end
    local myTeam, theirTeam = GetPlayerTeam(LocalPlayer), GetPlayerTeam(other)
    if myTeam == nil or theirTeam == nil then return false end
    return myTeam == theirTeam
end

local function IsWhitelisted(character)
    local p = Players:GetPlayerFromCharacter(character)
    return table.find(Whitelist, p and p.Name or character.Name) ~= nil
end

local function IsEnemy(character)
    if IsWhitelisted(character) or IsTeammate(character) then return false end
    return true
end

local function GetESPColor()
    if UseRainbow then return Color3.fromHSV((tick() * RainbowSpeed) % 1, 1, 1) end
    return ESPColor
end

local function IsValidCharacter(model)
    if not model or model == LocalPlayer.Character then return false end
    local head, hum, hrp = model:FindFirstChild("Head"), model:FindFirstChild("Humanoid"), model:FindFirstChild("HumanoidRootPart")
    return head and hum and hrp and hum.Health > 0 and IsEnemy(model)
end

local function GetAimParts(character)
    local parts = {}
    local function add(n) local p = character:FindFirstChild(n) if p then table.insert(parts, p) end end
    if AimPartMode == "Head" or AimPartMode == "HeadTorso" or AimPartMode == "All" then add("Head") end
    if AimPartMode == "Torso" or AimPartMode == "HeadTorso" or AimPartMode == "All" then
        local t = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
        if t then table.insert(parts, t) end
    end
    if AimPartMode == "Arms" or AimPartMode == "All" then
        for _, n in ipairs({"LeftArm","RightArm","LeftUpperArm","RightUpperArm","LeftLowerArm","RightLowerArm","LeftHand","RightHand"}) do add(n) end
    end
    if AimPartMode == "Legs" or AimPartMode == "All" then
        for _, n in ipairs({"LeftLeg","RightLeg","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg","LeftFoot","RightFoot"}) do add(n) end
    end
    if #parts == 0 then add("Head") end
    return parts
end

local function ClearAllESP()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") then
            local mark = obj:FindFirstChild("RobloxESP_Mark")
            local hl = obj:FindFirstChild("RobloxHighlight")
            local bb = obj:FindFirstChild("RobloxESP", true)
            if mark then mark:Destroy() end
            if hl then hl:Destroy() end
            if bb then bb:Destroy() end
        end
    end
end

local function RestoreHitboxes()
    for part, data in pairs(OriginalSizes) do
        pcall(function()
            if part and part.Parent then
                part.Size = data.Size
                part.Transparency = data.Transparency
                part.CanCollide = data.CanCollide
                part.Massless = data.Massless
            end
        end)
    end
    OriginalSizes = {}
end

local function ApplyHitbox(character)
    if not HitboxEnabled or not IsValidCharacter(character) then return end
    local function expand(part)
        if not part or not part:IsA("BasePart") then return end
        if not OriginalSizes[part] then
            OriginalSizes[part] = {
                Size = part.Size,
                Transparency = part.Transparency,
                CanCollide = part.CanCollide,
                Massless = part.Massless
            }
        end
        part.Size = OriginalSizes[part].Size * HitboxSize
        part.Transparency = 0.55
        part.CanCollide = false
        part.Massless = true
    end
    if HitboxParts.Head then expand(character:FindFirstChild("Head")) end
    if HitboxParts.Torso then expand(character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")) end
    if HitboxParts.Arms then
        for _, n in ipairs({"LeftArm","RightArm","LeftUpperArm","RightUpperArm","LeftLowerArm","RightLowerArm"}) do expand(character:FindFirstChild(n)) end
    end
    if HitboxParts.Legs then
        for _, n in ipairs({"LeftLeg","RightLeg","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}) do expand(character:FindFirstChild(n)) end
    end
end

local function UpdateAllHitboxes()
    RestoreHitboxes()
    if not HitboxEnabled then return end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then ApplyHitbox(player.Character) end
    end
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and IsValidCharacter(obj) then ApplyHitbox(obj) end
    end
end

-- FIX: при смене хитбоксов обновляем ESP
local function RefreshHitboxAndESP()
    UpdateAllHitboxes()
    ClearAllESP()
    task.defer(function()
        task.wait(0.15)
        if ESPEnabled and KeyPassed then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character and IsValidCharacter(player.Character) then
                    -- ApplyESP below
                end
            end
        end
    end)
end

local function ApplyESP(character)
    if not ESPEnabled or not KeyPassed then return end
    if character:FindFirstChild("RobloxESP_Mark") then return end
    if not IsValidCharacter(character) then return end
    local head = character:FindFirstChild("Head")
    local humanoid = character:FindFirstChild("Humanoid")
    if not head or not humanoid then return end

    local mark = Instance.new("BoolValue")
    mark.Name = "RobloxESP_Mark"
    mark.Parent = character

    local highlight = Instance.new("Highlight")
    highlight.Name = "RobloxHighlight"
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = character

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "RobloxESP"
    billboard.Adornee = head
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.AlwaysOnTop = true
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.Parent = head

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextSize = 14
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.TextStrokeTransparency = 0
    textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    textLabel.Parent = billboard

    local name = character.Name
    local player = Players:GetPlayerFromCharacter(character)
    if player then name = player.Name end

    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not ESPEnabled or not KeyPassed or not character.Parent or not head.Parent or not humanoid.Parent or humanoid.Health <= 0 or not IsEnemy(character) then
            pcall(function() billboard:Destroy() end)
            pcall(function() highlight:Destroy() end)
            pcall(function() if mark then mark:Destroy() end end)
            connection:Disconnect()
            return
        end
        -- если head заменили/сменили размер — обновим Adornee
        if billboard.Adornee ~= head and head.Parent then
            billboard.Adornee = head
        end
        local lc = LocalPlayer.Character
        if lc and lc:FindFirstChild("HumanoidRootPart") and character:FindFirstChild("HumanoidRootPart") then
            local distance = (lc.HumanoidRootPart.Position - character.HumanoidRootPart.Position).Magnitude
            if distance <= MaxDistance then
                billboard.Enabled = true
                highlight.Enabled = true
                local color = GetESPColor()
                textLabel.TextColor3 = color
                highlight.FillColor = color
                highlight.OutlineColor = color
                textLabel.Text = string.format("%s\nHP: %d | Dist: %d", name, math.floor(humanoid.Health), math.floor(distance))
            else
                billboard.Enabled = false
                highlight.Enabled = false
            end
        else
            billboard.Enabled = false
            highlight.Enabled = false
        end
    end)
end

local function ScanWorkspace()
    if not ESPEnabled or not KeyPassed then return end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and IsValidCharacter(player.Character) then
            ApplyESP(player.Character)
        end
    end
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and IsValidCharacter(obj) then ApplyESP(obj) end
    end
end

local function OnHitboxToggle(enabled)
    HitboxEnabled = enabled
    if enabled then
        UpdateAllHitboxes()
    else
        RestoreHitboxes()
    end
    -- FIX ESP
    ClearAllESP()
    task.delay(0.2, function()
        if KeyPassed and ESPEnabled then ScanWorkspace() end
    end)
end

Workspace.ChildAdded:Connect(function(child)
    if child:IsA("Model") then
        task.wait(0.4)
        if KeyPassed and IsValidCharacter(child) then
            ApplyESP(child)
            if HitboxEnabled then ApplyHitbox(child) end
        end
    end
end)

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        if KeyPassed and IsValidCharacter(char) then
            ApplyESP(char)
            if HitboxEnabled then ApplyHitbox(char) end
        end
    end)
end)

task.spawn(function()
    while true do
        if KeyPassed then
            if CurrentAuth and CurrentAuth.expires ~= 0 and CurrentAuth.expires <= os.time() then
                KeyPassed = false
                CurrentAuth = nil
                pcall(function() writefile(AUTH_FILE, "{}") end)
                ClearAllESP()
                RestoreHitboxes()
                FOVCircle.Visible = false
            else
                ScanWorkspace()
                if HitboxEnabled then UpdateAllHitboxes() end
            end
        end
        task.wait(2.5)
    end
end)

local CurrentTarget = nil
local function IsTargetValid(target)
    if not target or not target.Parent then return false end
    local hum = target.Parent:FindFirstChild("Humanoid")
    return hum and hum.Health > 0 and IsEnemy(target.Parent)
end

local function GetClosestTarget()
    local closest, shortest = nil, math.huge
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local function check(model)
        if not IsValidCharacter(model) then return end
        for _, part in ipairs(GetAimParts(model)) do
            local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen and sp.Z > 0 then
                local dist = (Vector2.new(sp.X, sp.Y) - screenCenter).Magnitude
                if dist < AimFOV and dist < shortest then shortest = dist closest = part end
            end
        end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then check(plr.Character) end
    end
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") then check(obj) end
    end
    return closest
end

local aiming = false
UserInputService.InputBegan:Connect(function(i, g) if not g and i.UserInputType == Enum.UserInputType.MouseButton2 then aiming = true end end)
UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton2 then aiming = false CurrentTarget = nil end end)

RunService.RenderStepped:Connect(function()
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    FOVCircle.Radius = AimFOV
    FOVCircle.Color = FOVColor
    FOVCircle.Visible = ShowFOV and KeyPassed
    if not KeyPassed or not AimEnabled or not aiming then CurrentTarget = nil return end
    local function MoveTo(t)
        local sp = Camera:WorldToViewportPoint(t.Position)
        local mp = UserInputService:GetMouseLocation()
        local dx, dy = (sp.X - mp.X) * AimSensitivity, (sp.Y - mp.Y) * AimSensitivity
        if math.abs(dx) > 0.8 or math.abs(dy) > 0.8 then mousemoverel(dx, dy) end
    end
    if CurrentTarget and IsTargetValid(CurrentTarget) then MoveTo(CurrentTarget) return end
    local nt = GetClosestTarget()
    if nt then CurrentTarget = nt MoveTo(nt) else CurrentTarget = nil end
end)

local function GetConfigPath()
    local n = (ConfigName or "default"):gsub("[^%w%-_]", "")
    return "RomashkaHub_" .. (n ~= "" and n or "default") .. ".json"
end

local ThemeTable = {
    TextColor = Color3.fromRGB(240, 240, 255), Background = Color3.fromRGB(18, 18, 32),
    Topbar = Color3.fromRGB(28, 22, 48), Shadow = Color3.fromRGB(12, 12, 24),
    NotificationBackground = Color3.fromRGB(22, 22, 40), NotificationActionsBackground = Color3.fromRGB(40, 30, 70),
    TabBackground = Color3.fromRGB(26, 22, 48), TabStroke = Color3.fromRGB(120, 70, 220),
    TabBackgroundSelected = Color3.fromRGB(255, 130, 50), TabTextColor = Color3.fromRGB(180, 170, 220),
    SelectedTabTextColor = Color3.fromRGB(255, 255, 255), ElementBackground = Color3.fromRGB(30, 26, 55),
    ElementBackgroundHover = Color3.fromRGB(45, 35, 80), SecondaryElementBackground = Color3.fromRGB(25, 22, 45),
    ElementStroke = Color3.fromRGB(140, 80, 255), SecondaryElementStroke = Color3.fromRGB(100, 60, 200),
    SliderBackground = Color3.fromRGB(35, 30, 60), SliderProgress = Color3.fromRGB(255, 140, 50),
    SliderStroke = Color3.fromRGB(160, 90, 255), ToggleBackground = Color3.fromRGB(35, 30, 60),
    ToggleEnabled = Color3.fromRGB(255, 140, 50), ToggleDisabled = Color3.fromRGB(50, 45, 80),
    ToggleEnabledStroke = Color3.fromRGB(255, 160, 70), ToggleDisabledStroke = Color3.fromRGB(70, 60, 110),
    ToggleEnabledOuterStroke = Color3.fromRGB(200, 100, 40), ToggleDisabledOuterStroke = Color3.fromRGB(40, 35, 70),
    DropdownSelected = Color3.fromRGB(50, 40, 90), DropdownUnselected = Color3.fromRGB(30, 26, 55),
    InputBackground = Color3.fromRGB(30, 26, 55), InputStroke = Color3.fromRGB(140, 80, 255),
    PlaceholderColor = Color3.fromRGB(140, 130, 180)
}

local function BuildFullUI(win)
    local AimTab = win:CreateTab("Aim", 4483362458)
    local ESPTab = win:CreateTab("ESP", 4483362458)
    local HitboxTab = win:CreateTab("Hitbox", 4483362458)
    local MiscTab = win:CreateTab("Misc", 4483362458)
    local MainTab = win:CreateTab("Main", 4483362458)

    AimTab:CreateToggle({Name = "Enable Aimbot", CurrentValue = true, Flag = "AimEnabled", Callback = function(v) AimEnabled = v if not v then CurrentTarget = nil end end})
    AimTab:CreateToggle({Name = "Team Check", CurrentValue = false, Flag = "TeamCheck", Callback = function(v)
        TeamCheck = v CurrentTarget = nil ClearAllESP() task.delay(0.15, ScanWorkspace)
    end})
    AimTab:CreateToggle({Name = "Show FOV Circle", CurrentValue = true, Flag = "ShowFOV", Callback = function(v) ShowFOV = v FOVCircle.Visible = v and KeyPassed end})
    AimTab:CreateDropdown({Name = "Aim Target", Options = {"Head","Torso","Arms","Legs","Head + Torso","All Parts"}, CurrentOption = {"Head"}, MultipleOptions = false, Flag = "AimPartMode", Callback = function(O)
        local o = O[1] or O
        AimPartMode = (o == "Head + Torso" and "HeadTorso") or (o == "All Parts" and "All") or o
        CurrentTarget = nil
    end})
    AimTab:CreateSlider({Name = "Aim FOV", Range = {30, 300}, Increment = 5, CurrentValue = 90, Flag = "AimFOV", Callback = function(v) AimFOV = v FOVCircle.Radius = v end})
    AimTab:CreateSlider({Name = "Sensitivity", Range = {0.05, 1}, Increment = 0.05, CurrentValue = 0.35, Flag = "AimSensitivity", Callback = function(v) AimSensitivity = v end})
    AimTab:CreateColorPicker({Name = "FOV Color", Color = Color3.fromRGB(255, 140, 50), Flag = "FOVColor", Callback = function(v) FOVColor = v FOVCircle.Color = v end})

    ESPTab:CreateToggle({Name = "Enable ESP", CurrentValue = true, Flag = "ESPEnabled", Callback = function(v) ESPEnabled = v if not v then ClearAllESP() else ScanWorkspace() end end})
    ESPTab:CreateToggle({Name = "Rainbow Mode", CurrentValue = true, Flag = "UseRainbow", Callback = function(v) UseRainbow = v end})
    ESPTab:CreateColorPicker({Name = "ESP Color", Color = Color3.fromRGB(0, 255, 180), Flag = "ESPColor", Callback = function(v) ESPColor = v end})
    ESPTab:CreateSlider({Name = "Max Distance", Range = {500, 5000}, Increment = 100, CurrentValue = 3000, Flag = "MaxDistance", Callback = function(v) MaxDistance = v end})
    ESPTab:CreateSlider({Name = "Rainbow Speed", Range = {0.1, 2}, Increment = 0.1, CurrentValue = 0.5, Flag = "RainbowSpeed", Callback = function(v) RainbowSpeed = v end})

    -- HITBOX с фиксом ESP
    HitboxTab:CreateToggle({Name = "Enable Hitbox Expander", CurrentValue = false, Flag = "HitboxEnabled", Callback = function(v) OnHitboxToggle(v) end})
    HitboxTab:CreateSlider({Name = "Hitbox Multiplier", Range = {1.2, 20}, Increment = 0.1, CurrentValue = 2.5, Flag = "HitboxSize", Callback = function(v)
        HitboxSize = v
        if HitboxEnabled then OnHitboxToggle(true) end
    end})
    HitboxTab:CreateToggle({Name = "Expand Head", CurrentValue = true, Flag = "HitboxHead", Callback = function(v) HitboxParts.Head = v if HitboxEnabled then OnHitboxToggle(true) end end})
    HitboxTab:CreateToggle({Name = "Expand Torso", CurrentValue = false, Flag = "HitboxTorso", Callback = function(v) HitboxParts.Torso = v if HitboxEnabled then OnHitboxToggle(true) end end})
    HitboxTab:CreateToggle({Name = "Expand Arms", CurrentValue = false, Flag = "HitboxArms", Callback = function(v) HitboxParts.Arms = v if HitboxEnabled then OnHitboxToggle(true) end end})
    HitboxTab:CreateToggle({Name = "Expand Legs", CurrentValue = false, Flag = "HitboxLegs", Callback = function(v) HitboxParts.Legs = v if HitboxEnabled then OnHitboxToggle(true) end end})

    MiscTab:CreateButton({Name = "Infinite Yield", Callback = function()
        task.spawn(function() pcall(function() loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))() end)
        Rayfield:Notify({Title = "Misc", Content = "Infinite Yield заинжекчен", Duration = 3}) end)
    end})
    MiscTab:CreateButton({Name = "Fast AP", Callback = function()
        pcall(function() game:GetService("ProximityPromptService").PromptButtonHoldBegan:Connect(function(p) p.HoldDuration = 0 end) end)
        Rayfield:Notify({Title = "Misc", Content = "Fast AP заинжекчен", Duration = 3})
    end})
    MiscTab:CreateButton({Name = "San Diego", Callback = function()
        task.spawn(function() pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/caruno-git/sandiego/refs/heads/main/sandiegocheat.lua"))() end)
        Rayfield:Notify({Title = "Misc", Content = "San Diego заинжекчен", Duration = 3}) end)
    end})

    MainTab:CreateParagraph({Title = "Статус ключа", Content = "Осталось: " .. GetTimeLeft()})
    MainTab:CreateInput({Name = "Название конфига", PlaceholderText = "default", RemoveTextAfterFocusLost = false, Callback = function(t) ConfigName = t ~= "" and t or "default" end})
    MainTab:CreateButton({Name = "Сохранить Config", Callback = function()
        local c = {MaxDistance=MaxDistance,RainbowSpeed=RainbowSpeed,ESPColor={ESPColor.R,ESPColor.G,ESPColor.B},UseRainbow=UseRainbow,TeamCheck=TeamCheck,Whitelist=Whitelist,AimEnabled=AimEnabled,AimFOV=AimFOV,ShowFOV=ShowFOV,AimSensitivity=AimSensitivity,FOVColor={FOVColor.R,FOVColor.G,FOVColor.B},AimPartMode=AimPartMode,ESPEnabled=ESPEnabled,HitboxEnabled=HitboxEnabled,HitboxSize=HitboxSize,HitboxParts=HitboxParts}
        pcall(function() writefile(GetConfigPath(), HttpService:JSONEncode(c)) end)
        Rayfield:Notify({Title = "Config", Content = "Сохранено", Duration = 2})
    end})
    MainTab:CreateButton({Name = "Загрузить Config", Callback = function()
        local ok, d = pcall(function() return HttpService:JSONDecode(readfile(GetConfigPath())) end)
        if ok and d then
            MaxDistance = d.MaxDistance or MaxDistance; RainbowSpeed = d.RainbowSpeed or RainbowSpeed
            if d.ESPColor then ESPColor = Color3.new(d.ESPColor[1], d.ESPColor[2], d.ESPColor[3]) end
            UseRainbow = d.UseRainbow; TeamCheck = d.TeamCheck; Whitelist = d.Whitelist or {}
            AimEnabled = d.AimEnabled; AimFOV = d.AimFOV or AimFOV; ShowFOV = d.ShowFOV
            AimSensitivity = d.AimSensitivity or AimSensitivity
            if d.FOVColor then FOVColor = Color3.new(d.FOVColor[1], d.FOVColor[2], d.FOVColor[3]) end
            AimPartMode = d.AimPartMode or "Head"; ESPEnabled = d.ESPEnabled
            HitboxSize = d.HitboxSize or 2.5; if d.HitboxParts then HitboxParts = d.HitboxParts end
            FOVCircle.Radius = AimFOV; FOVCircle.Color = FOVColor
            OnHitboxToggle(d.HitboxEnabled and true or false)
            Rayfield:Notify({Title = "Config", Content = "Загружено", Duration = 2})
        end
    end})
    local WInput = ""
    MainTab:CreateInput({Name = "Ник Whitelist", PlaceholderText = "Ник", RemoveTextAfterFocusLost = false, Callback = function(t) WInput = t end})
    MainTab:CreateButton({Name = "Добавить Whitelist", Callback = function()
        if WInput ~= "" and not table.find(Whitelist, WInput) then table.insert(Whitelist, WInput) ClearAllESP() ScanWorkspace() end
    end})
    MainTab:CreateButton({Name = "Сбросить ключ", Callback = function()
        KeyPassed = false; CurrentAuth = nil; pcall(function() writefile(AUTH_FILE, "{}") end)
        ClearAllESP(); RestoreHitboxes(); FOVCircle.Visible = false
        Rayfield:Notify({Title = "Ключ", Content = "Сброшен. Перезапусти скрипт.", Duration = 4})
    end})
    MainTab:CreateButton({Name = "Unload", Callback = function()
        KeyPassed = false; AimEnabled = false; ESPEnabled = false; HitboxEnabled = false
        FOVCircle.Visible = false; pcall(function() FOVCircle:Remove() end)
        RestoreHitboxes(); ClearAllESP(); pcall(function() Rayfield:Destroy() end)
    end})
end

if KeyPassed then
    local Window = Rayfield:CreateWindow({Name = "ROMASHKA HUB", LoadingTitle = "ROMASHKA HUB", LoadingSubtitle = "Ключ: " .. GetTimeLeft(), Theme = ThemeTable, DisableRayfieldPrompts = true, ConfigurationSaving = {Enabled = true, FolderName = "RomashkaHub", FileName = "Config"}, KeySystem = false})
    FOVCircle.Visible = ShowFOV
    BuildFullUI(Window)
    Rayfield:Notify({Title = "ROMASHKA HUB", Content = "Ключ активен (" .. GetTimeLeft() .. ")", Duration = 4})
else
    local Window = Rayfield:CreateWindow({Name = "ROMASHKA HUB", LoadingTitle = "ROMASHKA HUB", LoadingSubtitle = "Введи ключ", Theme = ThemeTable, DisableRayfieldPrompts = true, ConfigurationSaving = {Enabled = false}, KeySystem = false})
    local KeyTab = Window:CreateTab("Key", 4483362458)
    KeyTab:CreateParagraph({Title = "ROMASHKA HUB", Content = "Введи ключ. После активации вкладка Key исчезнет.\nКлюч сохранится до конца срока."})
    local KeyInput, KeyHours = "", 24
    KeyTab:CreateInput({Name = "Ключ", PlaceholderText = "ROM-XXXX-XXXX-XXXX-XXXX", RemoveTextAfterFocusLost = false, Callback = function(t) KeyInput = t end})
    KeyTab:CreateDropdown({Name = "Срок ключа", Options = {"1 час","3 часа","6 часов","12 часов","24 часа","Навсегда"}, CurrentOption = {"24 часа"}, MultipleOptions = false, Flag = "KH", Callback = function(O)
        local o = O[1] or O
        KeyHours = ({["1 час"]=1,["3 часа"]=3,["6 часов"]=6,["12 часов"]=12,["24 часа"]=24,["Навсегда"]=0})[o] or 24
    end})
    KeyTab:CreateButton({Name = "Активировать ключ", Callback = function()
        if not IsValidKeyFormat(KeyInput) then
            Rayfield:Notify({Title = "Ошибка", Content = "Неверный ключ", Duration = 3}) return
        end
        local exp = KeyHours > 0 and (os.time() + KeyHours * 3600) or 0
        SaveAuth(KeyInput:upper(), exp)
        KeyPassed = true
        FOVCircle.Visible = ShowFOV
        pcall(function() Rayfield:Destroy() end)
        task.wait(0.35)
        local NR = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
        Rayfield = NR
        local NW = Rayfield:CreateWindow({Name = "ROMASHKA HUB", LoadingTitle = "ROMASHKA HUB", LoadingSubtitle = "Ключ активен", Theme = ThemeTable, DisableRayfieldPrompts = true, ConfigurationSaving = {Enabled = true, FolderName = "RomashkaHub", FileName = "Config"}, KeySystem = false})
        BuildFullUI(NW)
        Rayfield:Notify({Title = "Успех", Content = "Ключ активирован", Duration = 4})
    end})
    Rayfield:Notify({Title = "ROMASHKA HUB", Content = "Введи ключ", Duration = 4})
end

print("[ROMASHKA HUB] DEFAULT — hitbox+ESP fix")
