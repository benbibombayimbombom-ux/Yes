-- TargetTracker - Auto Farm Script
-- Oyunun kendi skill tuşlarını (1/2/3/4) ve leftclick punch'ı otomatik kullanır
-- Pathfinding ile hedefe gider, ragdoll tespiti yapar

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local VIM = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

-- ================================================
-- AYARLAR (buradan düzenle)
-- ================================================
local CFG = {
    TweenSpeed       = 32,    -- Hareket hızı (studs/s)
    PathUpdateInt    = 0.45,  -- Path yenileme süresi (s)
    AttackRange      = 5.5,   -- Bu mesafede saldırıya başla
    ActionInterval   = 0.2,   -- Aksiyonlar arası bekleme (s)
    ComboResetTime   = 2.2,   -- Bu kadar süre aksiyon yoksa combo sıfırla

    -- Tuş cooldown'ları (oyunun içindeki gerçek cooldown'lara göre ayarla)
    -- Ne kadar bekleyeceğini bilmek için kullanılır
    Key1Cooldown = 1.2,
    Key2Cooldown = 3.0,
    Key3Cooldown = 2.0,
    Key4Cooldown = 8.0,
    PunchCooldown = 0.35,

    -- Punch ragdolled hedefe atılmasın mı?
    PunchIgnoreRagdoll = true,
}

-- ================================================
-- UI
-- ================================================
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "TargetTracker"
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 220, 0, 320)
MainFrame.Position = UDim2.new(0.8, 0, 0.5, -160)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BackgroundTransparency = 0.3
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, 0, 0, 25)
Title.BackgroundTransparency = 1
Title.Text = "🎯 Target Tracker"
Title.TextColor3 = Color3.fromRGB(75, 255, 75)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13

local Scroll = Instance.new("ScrollingFrame", MainFrame)
Scroll.Size = UDim2.new(0.95, 0, 1, -30)
Scroll.Position = UDim2.new(0.025, 0, 0, 28)
Scroll.BackgroundTransparency = 1
Scroll.ScrollBarThickness = 2
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
local Layout = Instance.new("UIListLayout", Scroll)
Layout.Padding = UDim.new(0, 4)

-- ================================================
-- TUŞLAR (oyunun gerçek tuşları)
-- ================================================
-- LastUsed: son ne zaman basıldı (cooldown takibi için)
local Keys = {
    [1] = { KeyCode = Enum.KeyCode.One,   LastUsed = 0, Cooldown = CFG.Key1Cooldown, ComboWeight = 3 },
    [2] = { KeyCode = Enum.KeyCode.Two,   LastUsed = 0, Cooldown = CFG.Key2Cooldown, ComboWeight = 2 },
    [3] = { KeyCode = Enum.KeyCode.Three, LastUsed = 0, Cooldown = CFG.Key3Cooldown, ComboWeight = 2 },
    [4] = { KeyCode = Enum.KeyCode.Four,  LastUsed = 0, Cooldown = CFG.Key4Cooldown, ComboWeight = 1 },
}
local PunchState = { LastUsed = 0, ComboWeight = 5 }

-- ================================================
-- STATE
-- ================================================
local SelectedTarget  = nil
local isTracking      = false
local trackConn       = nil
local combatConn      = nil
local comboCount      = 0
local comboResetTimer = 0
local lastAction      = 0
local pathUpdateTimer = 0

-- ================================================
-- RAGDOLL TESPİT
-- ================================================
local function isRagdolled(char)
    if not char then return false end

    -- BoolValue kontrolü (Ragdolled, ragdoll, RagdollValue vb.)
    for _, name in ipairs({"Ragdolled","ragdoll","RagdollValue","IsRagdolled"}) do
        local v = char:FindFirstChild(name)
        if v and v:IsA("BoolValue") and v.Value then return true end
    end

    -- Humanoid state kontrolü
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        local s = hum:GetState()
        if s == Enum.HumanoidStateType.Ragdoll
        or s == Enum.HumanoidStateType.FallingDown
        or s == Enum.HumanoidStateType.Physics then
            return true
        end
        if hum.PlatformStand then return true end
    end

    return false
end

-- ================================================
-- INPUT
-- ================================================
local function pressKey(keyCode)
    -- Önce UserInputService dene, olmadı VIM kullan
    local ok = pcall(function()
        VIM:SendKeyEvent(true, keyCode, false, game)
    end)
    task.delay(0.06, function()
        pcall(function() VIM:SendKeyEvent(false, keyCode, false, game) end)
    end)
end

local function pressPunch()
    -- Mouse sol tuş - iki yöntemle dene
    pcall(function()
        VIM:SendMouseButtonEvent(0, 0, 0, true, game, 1)
        task.delay(0.06, function()
            pcall(function() VIM:SendMouseButtonEvent(0, 0, 0, false, game, 1) end)
        end)
    end)
    pcall(function()
        VIM:SendMouseClickEvent(0, 0, false, game, 1)
    end)
end

-- ================================================
-- COOLDOWN
-- ================================================
local function keyReady(k)
    return (tick() - k.LastUsed) >= k.Cooldown
end

local function punchReady()
    return (tick() - PunchState.LastUsed) >= CFG.PunchCooldown
end

-- ================================================
-- PREDICTION
-- ================================================
local lastTPos  = nil
local lastTTime = nil
local tVelocity = Vector3.zero

local function updatePrediction(root)
    local now = tick()
    if lastTPos and lastTTime then
        local dt = now - lastTTime
        if dt > 0.01 then
            tVelocity = tVelocity:Lerp((root.Position - lastTPos) / dt, 0.35)
        end
    end
    lastTPos  = root.Position
    lastTTime = now
end

local function predictedPos(root, travelTime)
    if (root.Position - (LocalPlayer.Character and LocalPlayer.Character.HumanoidRootPart and LocalPlayer.Character.HumanoidRootPart.Position or root.Position)).Magnitude < 20 then
        return root.Position  -- Yakında prediction kapalı
    end
    return root.Position + tVelocity * math.min(travelTime, 1.5)
end

-- ================================================
-- PATHFINDING
-- ================================================
local function computePath(from, to)
    local path = PathfindingService:CreatePath({
        AgentRadius   = 2,
        AgentHeight   = 5,
        AgentCanJump  = true,
        AgentCanClimb = true,
        WaypointSpacing = 4,
    })
    local ok = pcall(function() path:ComputeAsync(from, to) end)
    if ok and path.Status == Enum.PathStatus.Success then
        return path:GetWaypoints()
    end
    return nil
end

-- ================================================
-- COMBAT - AKSIYON SEÇİCİ
-- ================================================
local function pickAction(targetChar)
    local ragdolled = isRagdolled(targetChar)

    -- Ragdolled hedef → sadece skill, punch yok
    if ragdolled and CFG.PunchIgnoreRagdoll then
        -- En yüksek ağırlıklı hazır skili seç
        local best, bestW = nil, -1
        for _, k in pairs(Keys) do
            if keyReady(k) and k.ComboWeight > bestW then
                best, bestW = k, k.ComboWeight
            end
        end
        return best and { Type = "Key", Key = best } or nil
    end

    -- Ağırlıklı havuz: hazır tuşlar + punch
    local pool = {}

    -- Her 8 comboda bir 4. tuş (ultimate fırsatı)
    if comboCount > 0 and comboCount % 8 == 0 and keyReady(Keys[4]) then
        return { Type = "Key", Key = Keys[4] }
    end

    -- Hızlı kaçan hedefe 2. tuş önce
    if tVelocity.Magnitude > 12 and keyReady(Keys[2]) then
        return { Type = "Key", Key = Keys[2] }
    end

    for _, k in pairs(Keys) do
        if keyReady(k) then
            for _ = 1, k.ComboWeight do
                table.insert(pool, { Type = "Key", Key = k })
            end
        end
    end

    if punchReady() then
        for _ = 1, PunchState.ComboWeight do
            table.insert(pool, { Type = "Punch" })
        end
    end

    if #pool == 0 then return nil end
    return pool[math.random(1, #pool)]
end

local function doAction(action)
    if not action then return end
    local now = tick()
    if action.Type == "Punch" then
        PunchState.LastUsed = now
        pressPunch()
    elseif action.Type == "Key" then
        action.Key.LastUsed = now
        pressKey(action.Key.KeyCode)
    end
    comboCount      = comboCount + 1
    comboResetTimer = now
    lastAction      = now
end

-- ================================================
-- COMBAT LOOP
-- ================================================
local function startCombat(targetRoot, targetChar)
    if combatConn then combatConn:Disconnect() end
    combatConn = RunService.Heartbeat:Connect(function()
        local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not myHrp or not targetRoot or not targetRoot.Parent then
            if combatConn then combatConn:Disconnect(); combatConn = nil end
            return
        end

        updatePrediction(targetRoot)

        if comboResetTimer > 0 and (tick() - comboResetTimer) > CFG.ComboResetTime then
            comboCount = 0; comboResetTimer = 0
        end

        if (myHrp.Position - targetRoot.Position).Magnitude <= CFG.AttackRange then
            if (tick() - lastAction) >= CFG.ActionInterval then
                doAction(pickAction(targetChar))
            end
        end
    end)
end

local function stopCombat()
    if combatConn then combatConn:Disconnect(); combatConn = nil end
    comboCount = 0; comboResetTimer = 0
end

-- ================================================
-- TRACKING LOOP
-- ================================================
local function stopTracking()
    if trackConn then trackConn:Disconnect(); trackConn = nil end
    stopCombat()
    isTracking = false; lastTPos = nil; lastTTime = nil
    tVelocity = Vector3.zero; pathUpdateTimer = 0
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
end

local function startTracking(targetRoot, targetChar)
    stopTracking()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp or not targetRoot then return end

    isTracking = true
    startCombat(targetRoot, targetChar)

    local waypoints   = nil
    local wpIndex     = 1
    local curTween    = nil
    local tweenActive = false

    trackConn = RunService.Heartbeat:Connect(function(dt)
        local myChar = LocalPlayer.Character
        local myHrp  = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myHrp or not targetRoot or not targetRoot.Parent then
            stopTracking(); return
        end

        -- Fling engeli
        myHrp.AssemblyLinearVelocity  = Vector3.zero
        myHrp.AssemblyAngularVelocity = Vector3.zero

        local myPos  = myHrp.Position
        local tPos   = targetRoot.Position
        local dist   = (myPos - tPos).Magnitude

        -- Hedefe bak (sadece yatay)
        local lookDir = (tPos - myPos) * Vector3.new(1, 0, 1)
        if lookDir.Magnitude > 0.5 then
            local lCF = CFrame.new(myPos, myPos + lookDir)
            myHrp.CFrame = CFrame.new(myPos)
                * CFrame.Angles(0, math.atan2(-lCF.RightVector.Z, lCF.RightVector.X), 0)
        end

        -- Menzildeyse tween iptal, dur
        if dist <= CFG.AttackRange then
            if curTween then curTween:Cancel(); curTween = nil; tweenActive = false end
            return
        end

        -- Path yenile
        pathUpdateTimer = pathUpdateTimer + dt
        if pathUpdateTimer >= CFG.PathUpdateInt then
            pathUpdateTimer = 0
            local newWP = computePath(myPos, predictedPos(targetRoot, dist / CFG.TweenSpeed))
            if newWP and #newWP > 1 then
                waypoints = newWP; wpIndex = 2
            else
                waypoints = nil
            end
        end

        -- Tween aktifse bitir
        if tweenActive then return end

        -- Gidilecek hedef CFrame ve mesafe
        local goalCF, goalDist

        if waypoints and wpIndex <= #waypoints then
            local wp = waypoints[wpIndex]
            local wpDist = (myPos - wp.Position).Magnitude

            if wpDist < 2.5 then
                wpIndex = wpIndex + 1; return
            end

            if wp.Action == Enum.PathWaypointAction.Jump then
                local hum = myChar:FindFirstChildOfClass("Humanoid")
                if hum then hum.Jump = true end
            end

            goalCF   = CFrame.new(wp.Position, Vector3.new(tPos.X, wp.Position.Y, tPos.Z))
            goalDist = wpDist
        else
            -- Direkt yaklaş
            local approach = tPos + (myPos - tPos).Unit * (CFG.AttackRange - 0.5)
            goalCF   = CFrame.new(approach, tPos)
            goalDist = (myPos - approach).Magnitude
        end

        if goalDist < 0.5 then return end

        -- Sabit hız tween
        curTween = TweenService:Create(
            myHrp,
            TweenInfo.new(goalDist / CFG.TweenSpeed, Enum.EasingStyle.Linear),
            { CFrame = goalCF }
        )
        tweenActive = true
        curTween:Play()
        curTween.Completed:Connect(function()
            tweenActive = false; curTween = nil
        end)
    end)
end

-- ================================================
-- NOTIFY
-- ================================================
local function notify(name, userId)
    local ok, thumb = pcall(function()
        return (userId == 0) and "rbxassetid://1"
            or Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
    end)
    StarterGui:SetCore("SendNotification", {
        Title = "Hedeflendi", Text = name,
        Icon = ok and thumb or "rbxassetid://1", Duration = 2
    })
end

-- ================================================
-- TARGET LİSTESİ UI
-- ================================================
RunService.Heartbeat:Connect(function()
    local targets = {}
    local myRoot  = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    -- Oyuncular (kendimizi atla)
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(targets, {
                Name = p.Name,
                Root = p.Character.HumanoidRootPart,
                Char = p.Character,
                Id   = p.UserId,
            })
        end
    end

    -- NPC / Dummy
    local charFolder = Workspace:FindFirstChild("Characters")
    if charFolder then
        for _, d in pairs(charFolder:GetChildren()) do
            local isPlayer = false
            for _, p in pairs(Players:GetPlayers()) do
                if p.Character == d then isPlayer = true; break end
            end
            if not isPlayer and d:FindFirstChild("HumanoidRootPart") then
                table.insert(targets, {
                    Name        = d.Name .. "_" .. d:GetDebugId(),
                    DisplayName = d.Name,
                    Root        = d.HumanoidRootPart,
                    Char        = d,
                    Id          = 0,
                })
            end
        end
    end

    -- Mesafeye göre sırala
    if myRoot then
        table.sort(targets, function(a, b)
            return (a.Root.Position - myRoot.Position).Magnitude
                 < (b.Root.Position - myRoot.Position).Magnitude
        end)
    end

    local seen = {}
    for _, data in pairs(targets) do
        seen[data.Name] = true
        local dName = data.DisplayName or data.Name
        local item  = Scroll:FindFirstChild(data.Name)

        if not item then
            item = Instance.new("TextButton", Scroll)
            item.Name             = data.Name
            item.Size             = UDim2.new(1, 0, 0, 35)
            item.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            item.Text             = ""
            Instance.new("UICorner", item).CornerRadius = UDim.new(0, 4)

            local icon = Instance.new("ImageLabel", item)
            icon.Name                   = "Icon"
            icon.Size                   = UDim2.new(0, 25, 0, 25)
            icon.Position               = UDim2.new(0, 5, 0, 5)
            icon.BackgroundTransparency = 1
            Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)

            local lbl = Instance.new("TextLabel", item)
            lbl.Name                   = "Label"
            lbl.Size                   = UDim2.new(0, 115, 1, 0)
            lbl.Position               = UDim2.new(0, 40, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.TextColor3             = Color3.new(1, 1, 1)
            lbl.Font                   = Enum.Font.Gotham
            lbl.TextSize               = 12
            lbl.TextXAlignment         = Enum.TextXAlignment.Left

            local stopBtn = Instance.new("TextButton", item)
            stopBtn.Name             = "StopBtn"
            stopBtn.Size             = UDim2.new(0, 22, 0, 22)
            stopBtn.Position         = UDim2.new(1, -26, 0, 6)
            stopBtn.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
            stopBtn.Text             = "✕"
            stopBtn.TextColor3       = Color3.new(1, 1, 1)
            stopBtn.TextSize         = 11
            stopBtn.Font             = Enum.Font.GothamBold
            stopBtn.Visible          = false
            Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 4)

            local cap = data
            stopBtn.MouseButton1Click:Connect(function()
                SelectedTarget = nil; stopTracking()
            end)

            item.MouseButton1Click:Connect(function()
                if SelectedTarget == cap.Name and isTracking then
                    SelectedTarget = nil; stopTracking(); return
                end
                SelectedTarget = cap.Name
                notify(dName, cap.Id)
                startTracking(cap.Root, cap.Char)
            end)
        end

        local dist   = myRoot and math.floor((data.Root.Position - myRoot.Position).Magnitude) or 0
        local rag    = isRagdolled(data.Char)
        local active = (SelectedTarget == data.Name)

        local icon    = item:FindFirstChild("Icon")
        local lbl     = item:FindFirstChild("Label")
        local stopBtn = item:FindFirstChild("StopBtn")

        if icon then
            icon.Image = (data.Id == 0) and "rbxassetid://1"
                or Players:GetUserThumbnailAsync(data.Id, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
        end
        if lbl then
            lbl.Text       = dName .. " [" .. dist .. "m]" .. (rag and " 💤" or "")
            lbl.TextColor3 = active and Color3.fromRGB(75, 255, 75) or Color3.fromRGB(200, 200, 200)
        end
        if stopBtn then stopBtn.Visible = (active and isTracking) end
        item.BackgroundColor3 = active and Color3.fromRGB(20, 50, 20) or Color3.fromRGB(30, 30, 30)
    end

    for _, child in pairs(Scroll:GetChildren()) do
        if child:IsA("TextButton") and not seen[child.Name] then
            if child.Name == SelectedTarget then SelectedTarget = nil; stopTracking() end
            child:Destroy()
        end
    end
end)
