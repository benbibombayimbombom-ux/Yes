-- Target Tracker - TpWalk + Pathfinding (Duvar Geçmez) + Hızlı Skill
local CoreGui          = game:GetService("CoreGui")
local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")
local RunService       = game:GetService("RunService")
local StarterGui       = game:GetService("StarterGui")
local PathfindingService = game:GetService("PathfindingService")
local VIM              = game:GetService("VirtualInputManager")
local LocalPlayer      = Players.LocalPlayer

-- ================================================
-- AYARLAR
-- ================================================
local TP_STEP           = 4      -- Her adımda kaç studs ilerler (düşük = duvar geçmez, yüksek = hızlı)
local TP_INTERVAL       = 0.06   -- Adımlar arası bekleme (s) → hız = TP_STEP / TP_INTERVAL studs/s
local PATH_UPDATE_INT   = 0.5    -- Path yenileme süresi (s)
local ATTACK_RANGE      = 5.5    -- Saldırı menzili
local ACTION_INTERVAL   = 0.1    -- Aksiyonlar arası süre (hızlı skill için düşük)
local COMBO_RESET_TIME  = 2.0

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
Instance.new("UIListLayout", Scroll).Padding = UDim.new(0, 4)

-- ================================================
-- SKİLL TANIMLARI
-- ================================================
local Skills = {
    [1] = { Name = "Slash",    Key = Enum.KeyCode.One,   Cooldown = 1.0,  Range = 8,  LastUsed = 0, ComboWeight = 3, WorksOnRagdoll = true  },
    [2] = { Name = "Blast",    Key = Enum.KeyCode.Two,   Cooldown = 2.5,  Range = 15, LastUsed = 0, ComboWeight = 2, WorksOnRagdoll = true  },
    [3] = { Name = "Spin",     Key = Enum.KeyCode.Three, Cooldown = 1.8,  Range = 6,  LastUsed = 0, ComboWeight = 2, WorksOnRagdoll = true  },
    [4] = { Name = "Ultimate", Key = Enum.KeyCode.Four,  Cooldown = 7.0,  Range = 12, LastUsed = 0, ComboWeight = 1, WorksOnRagdoll = true  },
}

local Punch = {
    Cooldown = 0.22,  -- Hızlı punch
    Range = 5,
    LastUsed = 0,
    ComboWeight = 6,  -- Çok sık kullan
    WorksOnRagdoll = false,
}

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
local stepTimer       = 0

-- Aktif waypoint listesi
local waypoints  = nil
local wpIndex    = 1

-- ================================================
-- RAGDOLL TESPİT
-- ================================================
local function isRagdolled(char)
    if not char then return false end
    local v = char:FindFirstChild("Ragdolled") or char:FindFirstChild("ragdoll") or char:FindFirstChild("RagdollValue")
    if v and v:IsA("BoolValue") and v.Value then return true end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        local s = hum:GetState()
        if s == Enum.HumanoidStateType.Ragdoll
        or s == Enum.HumanoidStateType.FallingDown
        or s == Enum.HumanoidStateType.Physics then return true end
        if hum.PlatformStand then return true end
    end
    return false
end

-- ================================================
-- INPUT
-- ================================================
local function pressKey(kc)
    pcall(function() VIM:SendKeyEvent(true,  kc, false, game) end)
    task.delay(0.05, function()
        pcall(function() VIM:SendKeyEvent(false, kc, false, game) end)
    end)
end

local function pressPunch()
    pcall(function() VIM:SendMouseButtonEvent(0, 0, 0, true,  game, 1) end)
    task.delay(0.05, function()
        pcall(function() VIM:SendMouseButtonEvent(0, 0, 0, false, game, 1) end)
    end)
    pcall(function() VIM:SendMouseClickEvent(0, 0, false, game, 1) end)
end

-- ================================================
-- COOLDOWN
-- ================================================
local function skillReady(s)  return (tick() - s.LastUsed) >= s.Cooldown end
local function punchReady()   return (tick() - Punch.LastUsed) >= Punch.Cooldown end

-- ================================================
-- PREDICTION
-- ================================================
local lastTPos  = nil
local lastTTime = nil
local tVel      = Vector3.zero

local function updatePred(root)
    local now = tick()
    if lastTPos and lastTTime then
        local dt = now - lastTTime
        if dt > 0.01 then
            tVel = tVel:Lerp((root.Position - lastTPos) / dt, 0.35)
        end
    end
    lastTPos  = root.Position
    lastTTime = now
end

local function predictPos(root, travelTime)
    if (root.Position - (LocalPlayer.Character and LocalPlayer.Character.HumanoidRootPart and LocalPlayer.Character.HumanoidRootPart.Position or root.Position)).Magnitude < 20 then
        return root.Position
    end
    return root.Position + tVel * math.min(travelTime, 1.2)
end

-- ================================================
-- PATHFINDING
-- ================================================
local function buildPath(from, to)
    local path = PathfindingService:CreatePath({
        AgentRadius   = 2,
        AgentHeight   = 5,
        AgentCanJump  = true,
        AgentCanClimb = true,
        WaypointSpacing = 3,
        Costs = { Water = 20 },
    })
    local ok = pcall(function() path:ComputeAsync(from, to) end)
    if ok and path.Status == Enum.PathStatus.Success then
        return path:GetWaypoints()
    end
    return nil
end

-- ================================================
-- COMBAT
-- ================================================
local function bestAction(root, char)
    local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil end

    local dist  = (myHrp.Position - root.Position).Magnitude
    local rag   = isRagdolled(char)
    local speed = tVel.Magnitude

    -- Ultimate her 8 comboda
    if comboCount > 0 and comboCount % 8 == 0
    and skillReady(Skills[4]) and dist <= Skills[4].Range then
        return {T="Skill", S=Skills[4]}
    end

    -- Ragdolled → sadece skill
    if rag then
        for _, s in pairs(Skills) do
            if skillReady(s) and dist <= s.Range then
                return {T="Skill", S=s}
            end
        end
        return nil
    end

    -- Kaçıyorsa Blast önce
    if speed > 12 and skillReady(Skills[2]) and dist <= Skills[2].Range then
        return {T="Skill", S=Skills[2]}
    end

    -- Ağırlıklı havuz
    local pool = {}
    for _, s in pairs(Skills) do
        if skillReady(s) and dist <= s.Range then
            for _ = 1, s.ComboWeight do table.insert(pool, {T="Skill", S=s}) end
        end
    end
    if punchReady() and dist <= Punch.Range then
        for _ = 1, Punch.ComboWeight do table.insert(pool, {T="Punch"}) end
    end

    if #pool == 0 then return nil end
    return pool[math.random(1, #pool)]
end

local function doAction(a)
    if not a then return end
    if a.T == "Punch" then
        Punch.LastUsed = tick()
        pressPunch()
    else
        a.S.LastUsed = tick()
        pressKey(a.S.Key)
    end
    comboCount      = comboCount + 1
    comboResetTimer = tick()
    lastAction      = tick()
end

-- ================================================
-- COMBAT LOOP
-- ================================================
local function startCombat(root, char)
    if combatConn then combatConn:Disconnect() end
    combatConn = RunService.Heartbeat:Connect(function()
        local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not myHrp or not root or not root.Parent then
            combatConn:Disconnect(); combatConn = nil
            return
        end
        updatePred(root)
        if comboResetTimer > 0 and (tick() - comboResetTimer) > COMBO_RESET_TIME then
            comboCount = 0; comboResetTimer = 0
        end
        local dist = (myHrp.Position - root.Position).Magnitude
        if dist <= ATTACK_RANGE and (tick() - lastAction) >= ACTION_INTERVAL then
            doAction(bestAction(root, char))
        end
    end)
end

local function stopCombat()
    if combatConn then combatConn:Disconnect(); combatConn = nil end
    comboCount = 0; comboResetTimer = 0
end

-- ================================================
-- TPWALK (Tween yok, saf TP adımları)
-- ================================================
local function stopTracking()
    if trackConn then trackConn:Disconnect(); trackConn = nil end
    stopCombat()
    isTracking    = false
    lastTPos      = nil
    lastTTime     = nil
    tVel          = Vector3.zero
    waypoints     = nil
    wpIndex       = 1
    pathUpdateTimer = 0
    stepTimer       = 0
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
end

local function startTracking(root, char)
    stopTracking()
    local myChar = LocalPlayer.Character
    local hrp    = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not hrp or not root then return end

    isTracking = true
    startCombat(root, char)

    trackConn = RunService.Heartbeat:Connect(function(dt)
        local mc   = LocalPlayer.Character
        local myHrp = mc and mc:FindFirstChild("HumanoidRootPart")
        if not myHrp or not root or not root.Parent then stopTracking(); return end

        -- Fling fix
        myHrp.AssemblyLinearVelocity  = Vector3.zero
        myHrp.AssemblyAngularVelocity = Vector3.zero

        local myPos  = myHrp.Position
        local tPos   = root.Position
        local dist   = (myPos - tPos).Magnitude

        -- Hedefe bak (yalnızca yaw)
        local look = (tPos - myPos) * Vector3.new(1, 0, 1)
        if look.Magnitude > 0.5 then
            local angle = math.atan2(-look.Z, look.X) - math.pi / 2
            myHrp.CFrame = CFrame.new(myPos) * CFrame.Angles(0, angle, 0)
        end

        -- Menzildeyse dur
        if dist <= ATTACK_RANGE then
            waypoints = nil
            return
        end

        -- Path yenile
        pathUpdateTimer = pathUpdateTimer + dt
        if pathUpdateTimer >= PATH_UPDATE_INT then
            pathUpdateTimer = 0
            local pred = predictPos(root, dist / (TP_STEP / TP_INTERVAL))
            local newWP = buildPath(myPos, pred)
            if newWP and #newWP > 1 then
                waypoints = newWP
                wpIndex   = 2
            else
                -- Pathfinding başarısız → direkt hedef yönü
                waypoints = nil
            end
        end

        -- Adım zamanı geldi mi?
        stepTimer = stepTimer + dt
        if stepTimer < TP_INTERVAL then return end
        stepTimer = 0

        -- TP adımı
        if waypoints and wpIndex <= #waypoints then
            local wp     = waypoints[wpIndex]
            local wpPos  = wp.Position
            local wpDist = (myPos - wpPos).Magnitude

            -- Waypointe ulaştıysak sonrakine geç
            if wpDist < 2.5 then
                wpIndex = wpIndex + 1
                return
            end

            -- Jump waypoint
            if wp.Action == Enum.PathWaypointAction.Jump then
                local hum = mc:FindFirstChildOfClass("Humanoid")
                if hum then hum.Jump = true end
            end

            -- Waypoint yönünde TP_STEP kadar ilerle
            local dir     = (wpPos - myPos).Unit
            local step    = math.min(TP_STEP, wpDist)
            local newPos  = myPos + dir * step

            -- Yüzü hedefe döndür
            local faceLook = (tPos - newPos) * Vector3.new(1, 0, 1)
            local newCF
            if faceLook.Magnitude > 0.5 then
                newCF = CFrame.new(newPos, newPos + faceLook)
            else
                newCF = CFrame.new(newPos)
            end
            myHrp.CFrame = newCF

        else
            -- Direkt TP (path yok)
            local approachPos = tPos + (myPos - tPos).Unit * (ATTACK_RANGE - 0.5)
            local dir         = (approachPos - myPos)
            local moveDist    = dir.Magnitude

            if moveDist < 0.1 then return end

            local step   = math.min(TP_STEP, moveDist)
            local newPos = myPos + dir.Unit * step
            local faceLook = (tPos - newPos) * Vector3.new(1, 0, 1)
            if faceLook.Magnitude > 0.5 then
                myHrp.CFrame = CFrame.new(newPos, newPos + faceLook)
            else
                myHrp.CFrame = CFrame.new(newPos)
            end
        end
    end)
end

-- ================================================
-- NOTIFY
-- ================================================
local function notify(name, userId)
    local thumb = (userId == 0) and "rbxassetid://1"
        or Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Hedeflendi", Text = name, Icon = thumb, Duration = 2
        })
    end)
end

-- ================================================
-- TARGET LİSTESİ UI
-- ================================================
RunService.Heartbeat:Connect(function()
    local targets = {}
    local myRoot  = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    -- Oyuncular (kendimiz hariç)
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(targets, {
                Name = p.Name, Root = p.Character.HumanoidRootPart,
                Char = p.Character, Id = p.UserId,
            })
        end
    end

    -- Workspace altındaki tüm modelleri tara (NPC/Dummy vs.)
    for _, obj in pairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and obj:FindFirstChild("HumanoidRootPart") and obj:FindFirstChildOfClass("Humanoid") then
            -- Oyuncu karakteri mi? Atla
            local isPlayer = false
            for _, p in pairs(Players:GetPlayers()) do
                if p.Character == obj then isPlayer = true break end
            end
            if not isPlayer then
                local uid = obj.Name .. "_" .. obj:GetDebugId()
                table.insert(targets, {
                    Name = uid, DisplayName = obj.Name,
                    Root = obj.HumanoidRootPart, Char = obj, Id = 0,
                })
            end
        end
    end

    -- Ayrıca "Characters" klasörü varsa onu da tara
    local cf = Workspace:FindFirstChild("Characters")
    if cf then
        for _, obj in pairs(cf:GetChildren()) do
            if obj:IsA("Model") and obj:FindFirstChild("HumanoidRootPart") then
                local isPlayer = false
                for _, p in pairs(Players:GetPlayers()) do
                    if p.Character == obj then isPlayer = true break end
                end
                if not isPlayer then
                    local uid = obj.Name .. "_" .. obj:GetDebugId()
                    -- Zaten ekledik mi?
                    local dup = false
                    for _, t in pairs(targets) do if t.Name == uid then dup = true break end end
                    if not dup then
                        table.insert(targets, {
                            Name = uid, DisplayName = obj.Name,
                            Root = obj.HumanoidRootPart, Char = obj, Id = 0,
                        })
                    end
                end
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

    -- UI güncelle
    local seen = {}
    for _, data in pairs(targets) do
        seen[data.Name] = true
        local dn   = data.DisplayName or data.Name
        local item = Scroll:FindFirstChild(data.Name)

        if not item then
            item = Instance.new("TextButton", Scroll)
            item.Name             = data.Name
            item.Size             = UDim2.new(1, 0, 0, 35)
            item.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            item.Text             = ""
            Instance.new("UICorner", item).CornerRadius = UDim.new(0, 4)

            local icon = Instance.new("ImageLabel", item)
            icon.Name  = "Icon"
            icon.Size  = UDim2.new(0, 25, 0, 25)
            icon.Position = UDim2.new(0, 5, 0, 5)
            icon.BackgroundTransparency = 1
            Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)

            local lbl = Instance.new("TextLabel", item)
            lbl.Name  = "Label"
            lbl.Size  = UDim2.new(0, 115, 1, 0)
            lbl.Position = UDim2.new(0, 40, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.TextColor3  = Color3.new(1, 1, 1)
            lbl.Font        = Enum.Font.Gotham
            lbl.TextSize    = 12
            lbl.TextXAlignment = Enum.TextXAlignment.Left

            local sb = Instance.new("TextButton", item)
            sb.Name   = "StopBtn"
            sb.Size   = UDim2.new(0, 22, 0, 22)
            sb.Position = UDim2.new(1, -26, 0, 6)
            sb.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
            sb.Text   = "✕"
            sb.TextColor3 = Color3.new(1,1,1)
            sb.TextSize   = 11
            sb.Font   = Enum.Font.GothamBold
            sb.Visible = false
            Instance.new("UICorner", sb).CornerRadius = UDim.new(0, 4)

            local cap = data
            sb.MouseButton1Click:Connect(function()
                SelectedTarget = nil; stopTracking()
            end)
            item.MouseButton1Click:Connect(function()
                if SelectedTarget == cap.Name and isTracking then
                    SelectedTarget = nil; stopTracking(); return
                end
                SelectedTarget = cap.Name
                notify(dn, cap.Id)
                startTracking(cap.Root, cap.Char)
            end)
        end

        local d   = myRoot and math.floor((data.Root.Position - myRoot.Position).Magnitude) or 0
        local rag = isRagdolled(data.Char)
        local act = (SelectedTarget == data.Name)

        local icon = item:FindFirstChild("Icon")
        local lbl  = item:FindFirstChild("Label")
        local sb   = item:FindFirstChild("StopBtn")

        if icon then
            icon.Image = (data.Id == 0) and "rbxassetid://1"
                or Players:GetUserThumbnailAsync(data.Id, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
        end
        if lbl then
            lbl.Text       = dn .. " [" .. d .. "m]" .. (rag and " 💤" or "")
            lbl.TextColor3 = act and Color3.fromRGB(75,255,75) or Color3.fromRGB(200,200,200)
        end
        if sb then sb.Visible = (act and isTracking) end
        item.BackgroundColor3 = act and Color3.fromRGB(20,50,20) or Color3.fromRGB(30,30,30)
    end

    -- Silinen hedefleri temizle
    for _, child in pairs(Scroll:GetChildren()) do
        if child:IsA("TextButton") and not seen[child.Name] then
            if child.Name == SelectedTarget then
                SelectedTarget = nil; stopTracking()
            end
            child:Destroy()
        end
    end
end)
