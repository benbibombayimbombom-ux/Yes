-- Target Tracker - FULL COMBAT AI v3
-- Fixes: kendimiz listede yok, punch fix, ragdoll detection, tween düzeltildi

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

-- ================================================
-- AYARLAR
-- ================================================
local TWEEN_SPEED       = 32    -- studs/s sabit hız
local PATH_UPDATE_INT   = 0.45  -- pathfinding yenileme süresi
local ATTACK_RANGE      = 5.5   -- saldırı menzili
local COMBO_RESET_TIME  = 2.2   -- combo sıfırlama süresi (s)
local ACTION_INTERVAL   = 0.18  -- aksiyonlar arası minimum süre

-- ================================================
-- UI
-- ================================================
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "SmoothTracker"
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
-- SKİLL TANIMLARI
-- ================================================
local Skills = {
    [1] = { Name = "Slash",    Key = Enum.KeyCode.One,   Cooldown = 1.2,  Range = 8,  LastUsed = 0, ComboWeight = 3, WorksOnRagdoll = true  },
    [2] = { Name = "Blast",    Key = Enum.KeyCode.Two,   Cooldown = 3.0,  Range = 15, LastUsed = 0, ComboWeight = 2, WorksOnRagdoll = true  },
    [3] = { Name = "Spin",     Key = Enum.KeyCode.Three, Cooldown = 2.0,  Range = 6,  LastUsed = 0, ComboWeight = 2, WorksOnRagdoll = true  },
    [4] = { Name = "Ultimate", Key = Enum.KeyCode.Four,  Cooldown = 8.0,  Range = 12, LastUsed = 0, ComboWeight = 1, WorksOnRagdoll = true  },
}

local Punch = {
    Name = "Punch", Cooldown = 0.38, Range = 5, LastUsed = 0,
    ComboWeight = 5,   -- Yüksek ağırlık - aktif kullan
    WorksOnRagdoll = false,
}

-- ================================================
-- STATE
-- ================================================
local SelectedTarget   = nil
local isTracking       = false
local trackConn        = nil
local combatConn       = nil
local comboCount       = 0
local comboResetTimer  = 0
local lastAction       = 0
local pathUpdateTimer  = 0

-- ================================================
-- RAGDOLL TESPİT
-- ================================================
local function isTargetRagdolled(targetChar)
    if not targetChar then return false end

    -- Yöntem 1: "Ragdolled" / "ragdoll" adlı değer
    local ragVal = targetChar:FindFirstChild("Ragdolled") or targetChar:FindFirstChild("ragdoll") or targetChar:FindFirstChild("RagdollValue")
    if ragVal and ragVal:IsA("BoolValue") and ragVal.Value == true then
        return true
    end

    -- Yöntem 2: Humanoid state
    local hum = targetChar:FindFirstChildOfClass("Humanoid")
    if hum then
        local state = hum:GetState()
        if state == Enum.HumanoidStateType.Ragdoll
        or state == Enum.HumanoidStateType.FallingDown
        or state == Enum.HumanoidStateType.Physics then
            return true
        end
    end

    -- Yöntem 3: PlatformStand aktifse (bazı ragdoll sistemleri bunu kullanır)
    if hum and hum.PlatformStand == true then
        return true
    end

    return false
end

-- ================================================
-- INPUT YARDIMCILARI
-- ================================================
local function fireKey(keyCode, down)
    pcall(function() VIM:SendKeyEvent(down, keyCode, false, game) end)
end

local function pressKey(keyCode)
    fireKey(keyCode, true)
    task.delay(0.06, function() fireKey(keyCode, false) end)
end

-- Punch: mouse click + mouse event ikisi birden (uyumluluk için)
local function pressPunch()
    -- Yöntem 1: Mouse button event
    pcall(function()
        VIM:SendMouseButtonEvent(0, 0, 0, true, game, 1)
        task.delay(0.06, function()
            VIM:SendMouseButtonEvent(0, 0, 0, false, game, 1)
        end)
    end)
    -- Yöntem 2: Mouse click event (bazı oyunlar bunu dinler)
    pcall(function()
        VIM:SendMouseClickEvent(0, 0, false, game, 1)
    end)
end

-- ================================================
-- COOLDOWN KONTROL
-- ================================================
local function isSkillReady(skill)
    return (tick() - skill.LastUsed) >= skill.Cooldown
end

local function isPunchReady()
    return (tick() - Punch.LastUsed) >= Punch.Cooldown
end

-- ================================================
-- PREDICTION (hedef hareket tahmini)
-- ================================================
local lastTargetPos  = nil
local lastTargetTime = nil
local targetVelocity = Vector3.zero

local function updatePrediction(targetRoot)
    local now = tick()
    if lastTargetPos and lastTargetTime then
        local dt = now - lastTargetTime
        if dt > 0.01 then
            -- Smooth velocity (ani değişimleri azalt)
            local rawVel = (targetRoot.Position - lastTargetPos) / dt
            targetVelocity = targetVelocity:Lerp(rawVel, 0.4)
        end
    end
    lastTargetPos  = targetRoot.Position
    lastTargetTime = now
end

local function getPredictedPos(targetRoot, travelTime)
    -- Max 1.5s ileriye tahmin et
    local clampedTime = math.min(travelTime, 1.5)
    return targetRoot.Position + targetVelocity * clampedTime
end

-- ================================================
-- PATHFINDING
-- ================================================
local function computePath(fromPos, toPos)
    local path = PathfindingService:CreatePath({
        AgentRadius   = 2,
        AgentHeight   = 5,
        AgentCanJump  = true,
        AgentCanClimb = true,
        WaypointSpacing = 4,
        Costs = { Water = 20 },
    })
    local ok = pcall(function() path:ComputeAsync(fromPos, toPos) end)
    if ok and path.Status == Enum.PathStatus.Success then
        return path:GetWaypoints()
    end
    return nil
end

-- ================================================
-- COMBAT - AKSİYON SEÇİCİ
-- ================================================
local function getBestAction(targetRoot, targetChar)
    local myChar = LocalPlayer.Character
    local myHrp  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil end

    local dist        = (myHrp.Position - targetRoot.Position).Magnitude
    local ragdolled   = isTargetRagdolled(targetChar)
    local targetSpeed = targetVelocity.Magnitude

    -- Ultimate fırsatı (her 8 comboda)
    if comboCount > 0 and comboCount % 8 == 0
    and isSkillReady(Skills[4]) and dist <= Skills[4].Range then
        return { Type = "Skill", Skill = Skills[4] }
    end

    -- Target ragdolled → sadece skill kullan, punch işe yaramaz
    if ragdolled then
        local best = nil
        local bestWeight = -1
        for _, skill in pairs(Skills) do
            if isSkillReady(skill) and dist <= skill.Range and skill.ComboWeight > bestWeight then
                best = { Type = "Skill", Skill = skill }
                bestWeight = skill.ComboWeight
            end
        end
        return best  -- nil olabilir (hiç skill hazır değilse bekle)
    end

    -- Kaçan düşmana Blast önce
    if targetSpeed > 12 and isSkillReady(Skills[2]) and dist <= Skills[2].Range then
        return { Type = "Skill", Skill = Skills[2] }
    end

    -- Ağırlıklı seçim: hazır skill + punch havuzu
    local pool = {}

    for _, skill in pairs(Skills) do
        if isSkillReady(skill) and dist <= skill.Range then
            for _ = 1, skill.ComboWeight do
                table.insert(pool, { Type = "Skill", Skill = skill })
            end
        end
    end

    -- Punch: ragdolled değilse ve menzildeyse havuza ekle (yüksek ağırlık)
    if isPunchReady() and dist <= Punch.Range then
        for _ = 1, Punch.ComboWeight do
            table.insert(pool, { Type = "Punch" })
        end
    end

    if #pool == 0 then return nil end
    return pool[math.random(1, #pool)]
end

local function executeAction(action)
    if not action then return end
    local now = tick()

    if action.Type == "Punch" then
        Punch.LastUsed = now
        pressPunch()
    elseif action.Type == "Skill" then
        action.Skill.LastUsed = now
        pressKey(action.Skill.Key)
    end

    comboCount       = comboCount + 1
    comboResetTimer  = now
    lastAction       = now
end

-- ================================================
-- COMBAT LOOP
-- ================================================
local function startCombat(targetRoot, targetChar)
    if combatConn then combatConn:Disconnect() end

    combatConn = RunService.Heartbeat:Connect(function()
        local char  = LocalPlayer.Character
        local myHrp = char and char:FindFirstChild("HumanoidRootPart")
        if not myHrp or not targetRoot or not targetRoot.Parent then
            if combatConn then combatConn:Disconnect(); combatConn = nil end
            return
        end

        updatePrediction(targetRoot)

        -- Combo reset
        if comboResetTimer > 0 and (tick() - comboResetTimer) > COMBO_RESET_TIME then
            comboCount      = 0
            comboResetTimer = 0
        end

        local dist = (myHrp.Position - targetRoot.Position).Magnitude
        if dist <= ATTACK_RANGE then
            if (tick() - lastAction) >= ACTION_INTERVAL then
                local action = getBestAction(targetRoot, targetChar)
                executeAction(action)
            end
        end
    end)
end

local function stopCombat()
    if combatConn then combatConn:Disconnect(); combatConn = nil end
    comboCount      = 0
    comboResetTimer = 0
end

-- ================================================
-- TRACKING LOOP (Pathfinding + Tween)
-- ================================================
local function stopTracking()
    if trackConn then trackConn:Disconnect(); trackConn = nil end
    stopCombat()
    isTracking      = false
    lastTargetPos   = nil
    lastTargetTime  = nil
    targetVelocity  = Vector3.zero
    pathUpdateTimer = 0

    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
end

local function startTracking(targetRoot, targetChar)
    stopTracking()

    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not targetRoot then return end

    isTracking = true
    startCombat(targetRoot, targetChar)

    local waypoints    = nil
    local wpIndex      = 1
    local currentTween = nil
    local tweenActive  = false

    trackConn = RunService.Heartbeat:Connect(function(dt)
        local myChar = LocalPlayer.Character
        local myHrp  = myChar and myChar:FindFirstChild("HumanoidRootPart")

        if not myHrp or not targetRoot or not targetRoot.Parent then
            stopTracking()
            return
        end

        -- Fling fix (sürekli)
        myHrp.AssemblyLinearVelocity  = Vector3.zero
        myHrp.AssemblyAngularVelocity = Vector3.zero

        local myPos     = myHrp.Position
        local targetPos = targetRoot.Position
        local dist      = (myPos - targetPos).Magnitude

        -- Her zaman hedefe bak (sadece Y ekseni etkilenmesin)
        local lookDir = (targetPos - myPos) * Vector3.new(1, 0, 1)
        if lookDir.Magnitude > 0.5 then
            local lookCF = CFrame.new(myPos, myPos + lookDir)
            -- Sadece yaw (Y rotasyonu), pitch/roll dokunma
            myHrp.CFrame = CFrame.new(myPos)
                * CFrame.Angles(0, math.atan2(-lookCF.RightVector.Z, lookCF.RightVector.X), 0)
        end

        -- Saldırı menzilindeyse tween durdur, sadece bak
        if dist <= ATTACK_RANGE then
            if currentTween then
                currentTween:Cancel()
                currentTween = nil
                tweenActive  = false
            end
            return
        end

        -- Path yenileme zamanı
        pathUpdateTimer = pathUpdateTimer + dt
        if pathUpdateTimer >= PATH_UPDATE_INT then
            pathUpdateTimer = 0

            local travelEst    = dist / TWEEN_SPEED
            local predictedPos = getPredictedPos(targetRoot, travelEst)

            -- Hedef çok yakınsa prediction fazla saptırabilir, kapat
            if dist < 20 then predictedPos = targetPos end

            local newWP = computePath(myPos, predictedPos)
            if newWP and #newWP > 1 then
                waypoints = newWP
                wpIndex   = 2
            else
                waypoints = nil
            end
        end

        -- Tween aktifse bitene kadar bekle (boşa iptal etme)
        if tweenActive then return end

        -- Waypoint hareketi
        local targetCF
        local tweenDist

        if waypoints and wpIndex <= #waypoints then
            local wp     = waypoints[wpIndex]
            local wpDist = (myPos - wp.Position).Magnitude

            if wpDist < 2.5 then
                -- Waypointe ulaştık, sonrakine geç
                wpIndex = wpIndex + 1
                return
            end

            -- Jump waypoint
            if wp.Action == Enum.PathWaypointAction.Jump then
                local hum = myChar:FindFirstChildOfClass("Humanoid")
                if hum then hum.Jump = true end
            end

            -- Waypointe git, ama yüzü hedefe dönsün
            local wpPos   = wp.Position
            local faceCF  = CFrame.new(wpPos, Vector3.new(targetPos.X, wpPos.Y, targetPos.Z))
            targetCF      = faceCF
            tweenDist     = wpDist

        else
            -- Pathfinding yok → direkt yaklaş
            local approachPos = targetPos + (myPos - targetPos).Unit * (ATTACK_RANGE - 0.5)
            targetCF          = CFrame.new(approachPos, targetPos)
            tweenDist         = (myPos - approachPos).Magnitude
        end

        if tweenDist < 0.5 then return end

        -- Sabit hız: süre = mesafe / hız
        local dur = tweenDist / TWEEN_SPEED

        currentTween = TweenService:Create(
            myHrp,
            TweenInfo.new(dur, Enum.EasingStyle.Linear, Enum.EasingDirection.In),
            { CFrame = targetCF }
        )

        tweenActive = true
        currentTween:Play()

        currentTween.Completed:Connect(function(state)
            tweenActive  = false
            currentTween = nil
        end)
    end)
end

-- ================================================
-- NOTIFY
-- ================================================
local function notify(name, userId)
    local thumb = (userId == 0) and "rbxassetid://1"
        or Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
    StarterGui:SetCore("SendNotification", {
        Title    = "Hedeflendi",
        Text     = name,
        Icon     = thumb,
        Duration = 2
    })
end

-- ================================================
-- TARGET LİSTESİ UI (Heartbeat)
-- ================================================
RunService.Heartbeat:Connect(function()
    local targets = {}
    local myRoot  = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    -- Oyuncular (KENDİMİZİ ATLA)
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer   -- ← kendimizi filtrele
        and p.Character
        and p.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(targets, {
                Name  = p.Name,
                Root  = p.Character.HumanoidRootPart,
                Char  = p.Character,
                Id    = p.UserId,
            })
        end
    end

    -- NPC / Dummy'ler
    local charFolder = Workspace:FindFirstChild("Characters")
    if charFolder then
        for _, d in pairs(charFolder:GetChildren()) do
            -- Oyuncu karakteri değilse ekle
            local isPlayer = false
            for _, p in pairs(Players:GetPlayers()) do
                if p.Character == d then isPlayer = true break end
            end
            if not isPlayer and d:FindFirstChild("HumanoidRootPart") then
                local uid = d.Name .. "_" .. d:GetDebugId()
                table.insert(targets, {
                    Name        = uid,
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

    -- UI öğelerini güncelle
    local seen = {}
    for _, data in pairs(targets) do
        seen[data.Name] = true
        local displayName = data.DisplayName or data.Name
        local item = Scroll:FindFirstChild(data.Name)

        if not item then
            item = Instance.new("TextButton", Scroll)
            item.Name            = data.Name
            item.Size            = UDim2.new(1, 0, 0, 35)
            item.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            item.Text            = ""
            Instance.new("UICorner", item).CornerRadius = UDim.new(0, 4)

            local icon = Instance.new("ImageLabel", item)
            icon.Name                = "Icon"
            icon.Size                = UDim2.new(0, 25, 0, 25)
            icon.Position            = UDim2.new(0, 5, 0, 5)
            icon.BackgroundTransparency = 1
            Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)

            local lbl = Instance.new("TextLabel", item)
            lbl.Name               = "Label"
            lbl.Size               = UDim2.new(0, 115, 1, 0)
            lbl.Position           = UDim2.new(0, 40, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.TextColor3         = Color3.new(1, 1, 1)
            lbl.Font               = Enum.Font.Gotham
            lbl.TextSize           = 12
            lbl.TextXAlignment     = Enum.TextXAlignment.Left

            local stopBtn = Instance.new("TextButton", item)
            stopBtn.Name            = "StopBtn"
            stopBtn.Size            = UDim2.new(0, 22, 0, 22)
            stopBtn.Position        = UDim2.new(1, -26, 0, 6)
            stopBtn.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
            stopBtn.Text            = "✕"
            stopBtn.TextColor3      = Color3.new(1, 1, 1)
            stopBtn.TextSize        = 11
            stopBtn.Font            = Enum.Font.GothamBold
            stopBtn.Visible         = false
            Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 4)

            local cap = data
            stopBtn.MouseButton1Click:Connect(function()
                SelectedTarget = nil
                stopTracking()
            end)

            item.MouseButton1Click:Connect(function()
                if SelectedTarget == cap.Name and isTracking then
                    SelectedTarget = nil
                    stopTracking()
                    return
                end
                SelectedTarget = cap.Name
                notify(displayName, cap.Id)
                startTracking(cap.Root, cap.Char)
            end)
        end

        -- Değerleri güncelle
        local dist    = myRoot and math.floor((data.Root.Position - myRoot.Position).Magnitude) or 0
        local isRag   = isTargetRagdolled(data.Char)
        local active  = (SelectedTarget == data.Name)

        local icon    = item:FindFirstChild("Icon")
        local lbl     = item:FindFirstChild("Label")
        local stopBtn = item:FindFirstChild("StopBtn")

        if icon then
            icon.Image = (data.Id == 0) and "rbxassetid://1"
                or Players:GetUserThumbnailAsync(data.Id, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
        end
        if lbl then
            lbl.Text = displayName .. " [" .. dist .. "m]" .. (isRag and " 💤" or "")
            lbl.TextColor3 = active and Color3.fromRGB(75, 255, 75) or Color3.fromRGB(200, 200, 200)
        end
        if stopBtn then
            stopBtn.Visible = (active and isTracking)
        end

        item.BackgroundColor3 = active and Color3.fromRGB(20, 50, 20) or Color3.fromRGB(30, 30, 30)
    end

    -- Listeden çıkan hedefleri sil
    for _, child in pairs(Scroll:GetChildren()) do
        if child:IsA("TextButton") and not seen[child.Name] then
            if child.Name == SelectedTarget then
                SelectedTarget = nil
                stopTracking()
            end
            child:Destroy()
        end
    end
end)
