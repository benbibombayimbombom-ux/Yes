-- Target Tracker - FULL COMBAT AI (Pathfinding + Skills + Combo)
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- ================================================
-- UI SETUP
-- ================================================
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "SmoothTracker"

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 220, 0, 340)
MainFrame.Position = UDim2.new(0.8, 0, 0.5, -170)
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
local Layout = Instance.new("UIListLayout", Scroll)
Layout.Padding = UDim.new(0, 4)

-- Combat HUD
local HudFrame = Instance.new("Frame", ScreenGui)
HudFrame.Size = UDim2.new(0, 300, 0, 120)
HudFrame.Position = UDim2.new(0.5, -150, 1, -140)
HudFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
HudFrame.BackgroundTransparency = 0.4
HudFrame.Visible = false
Instance.new("UICorner", HudFrame).CornerRadius = UDim.new(0, 8)

local ComboLabel = Instance.new("TextLabel", HudFrame)
ComboLabel.Size = UDim2.new(1, 0, 0, 25)
ComboLabel.Position = UDim2.new(0, 0, 0, 5)
ComboLabel.BackgroundTransparency = 1
ComboLabel.Text = "COMBO: 0"
ComboLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
ComboLabel.Font = Enum.Font.GothamBold
ComboLabel.TextSize = 16

local SkillHud = Instance.new("Frame", HudFrame)
SkillHud.Size = UDim2.new(1, -10, 0, 60)
SkillHud.Position = UDim2.new(0, 5, 0, 35)
SkillHud.BackgroundTransparency = 1
local SkillLayout = Instance.new("UIListLayout", SkillHud)
SkillLayout.FillDirection = Enum.FillDirection.Horizontal
SkillLayout.Padding = UDim.new(0, 6)

local StatusLabel = Instance.new("TextLabel", HudFrame)
StatusLabel.Size = UDim2.new(1, 0, 0, 18)
StatusLabel.Position = UDim2.new(0, 0, 1, -22)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "▶ Pathfinding..."
StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 255)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 12

-- ================================================
-- SKILL TANIMLARI
-- ================================================
local Skills = {
    [1] = {
        Name = "Slash",
        Key = Enum.KeyCode.One,
        Damage = 25,
        Cooldown = 1.2,
        Range = 8,
        LastUsed = 0,
        Color = Color3.fromRGB(255, 100, 100),
        ComboWeight = 3,
    },
    [2] = {
        Name = "Blast",
        Key = Enum.KeyCode.Two,
        Damage = 45,
        Cooldown = 3.0,
        Range = 15,
        LastUsed = 0,
        Color = Color3.fromRGB(100, 150, 255),
        ComboWeight = 2,
    },
    [3] = {
        Name = "Spin",
        Key = Enum.KeyCode.Three,
        Damage = 35,
        Cooldown = 2.0,
        Range = 6,
        LastUsed = 0,
        Color = Color3.fromRGB(255, 200, 50),
        ComboWeight = 2,
    },
    [4] = {
        Name = "Ultimate",
        Key = Enum.KeyCode.Four,
        Damage = 80,
        Cooldown = 8.0,
        Range = 12,
        LastUsed = 0,
        Color = Color3.fromRGB(200, 50, 255),
        ComboWeight = 1,
    },
}

local Punch = {
    Name = "Punch",
    Damage = 12,
    Cooldown = 0.4,
    Range = 5,
    LastUsed = 0,
    ComboWeight = 4,
}

-- Skill HUD butonları oluştur
local SkillButtons = {}
for i = 1, 4 do
    local s = Skills[i]
    local btn = Instance.new("Frame", SkillHud)
    btn.Size = UDim2.new(0, 60, 0, 55)
    btn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local nameL = Instance.new("TextLabel", btn)
    nameL.Size = UDim2.new(1, 0, 0, 18)
    nameL.Position = UDim2.new(0, 0, 0, 2)
    nameL.BackgroundTransparency = 1
    nameL.Text = s.Name
    nameL.TextColor3 = s.Color
    nameL.Font = Enum.Font.GothamBold
    nameL.TextSize = 10

    local keyL = Instance.new("TextLabel", btn)
    keyL.Size = UDim2.new(1, 0, 0, 15)
    keyL.Position = UDim2.new(0, 0, 0, 20)
    keyL.BackgroundTransparency = 1
    keyL.Text = "[" .. i .. "]"
    keyL.TextColor3 = Color3.fromRGB(180, 180, 180)
    keyL.Font = Enum.Font.Gotham
    keyL.TextSize = 11

    local cdL = Instance.new("TextLabel", btn)
    cdL.Name = "CD"
    cdL.Size = UDim2.new(1, 0, 0, 15)
    cdL.Position = UDim2.new(0, 0, 0, 37)
    cdL.BackgroundTransparency = 1
    cdL.Text = "READY"
    cdL.TextColor3 = Color3.fromRGB(75, 255, 75)
    cdL.Font = Enum.Font.Gotham
    cdL.TextSize = 10

    SkillButtons[i] = btn
end

-- ================================================
-- STATE
-- ================================================
local SelectedTarget = nil
local isTracking = false
local trackConn = nil
local combatActive = false
local comboCount = 0
local comboResetTimer = 0
local lastAction = 0
local pathUpdateTimer = 0
local PATH_UPDATE_INTERVAL = 0.5

-- ================================================
-- YARDIMCI FONKSİYONLAR
-- ================================================
local function notify(name, userId)
    local thumb = (userId == 0) and "rbxassetid://1" or Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
    StarterGui:SetCore("SendNotification", {
        Title = "Hedeflendi",
        Text = name,
        Icon = thumb,
        Duration = 2
    })
end

local function setLayPose(character, enable)
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end
    if enable then
        humanoid.PlatformStand = true
        hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(math.rad(90), 0, 0)
    else
        hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, 0, 0)
        humanoid.PlatformStand = false
    end
end

local function pressKey(keyCode)
    local success = pcall(function()
        UserInputService:FireKeyboardEvent(keyCode, false)
    end)
    if not success then
        pcall(function()
            game:GetService("VirtualInputManager"):SendKeyEvent(true, keyCode, false, game)
            task.delay(0.05, function()
                game:GetService("VirtualInputManager"):SendKeyEvent(false, keyCode, false, game)
            end)
        end)
    end
end

local function pressMouseClick()
    pcall(function()
        game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, true, game, 1)
        task.delay(0.05, function()
            game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, false, game, 1)
        end)
    end)
end

local function getSkillCooldownLeft(skill)
    return math.max(0, skill.Cooldown - (tick() - skill.LastUsed))
end

local function isSkillReady(skill)
    return (tick() - skill.LastUsed) >= skill.Cooldown
end

local function isPunchReady()
    return (tick() - Punch.LastUsed) >= Punch.Cooldown
end

-- ================================================
-- PREDICTION
-- ================================================
local lastTargetPos = nil
local lastTargetTime = nil
local targetVelocity = Vector3.zero

local function updateTargetPrediction(targetRoot)
    local now = tick()
    if lastTargetPos and lastTargetTime then
        local dt = now - lastTargetTime
        if dt > 0 then
            targetVelocity = (targetRoot.Position - lastTargetPos) / dt
        end
    end
    lastTargetPos = targetRoot.Position
    lastTargetTime = now
end

local function getPredictedPosition(targetRoot, travelTime)
    return targetRoot.Position + targetVelocity * travelTime
end

-- ================================================
-- PATHFINDING
-- ================================================
local function computePath(fromPos, toPos)
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = true,
        WaypointSpacing = 4,
    })
    local success = pcall(function()
        path:ComputeAsync(fromPos, toPos)
    end)
    if success and path.Status == Enum.PathStatus.Success then
        return path:GetWaypoints()
    end
    return nil
end

-- ================================================
-- COMBO SİSTEMİ
-- ================================================
local function getBestAction(targetRoot)
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil end

    local dist = (myHrp.Position - targetRoot.Position).Magnitude
    local targetSpeed = targetVelocity.Magnitude

    -- Ultimate fırsatı (her 8 comboda bir)
    if comboCount > 0 and comboCount % 8 == 0 and isSkillReady(Skills[4]) and dist <= Skills[4].Range then
        return {Type = "Skill", Skill = Skills[4], Index = 4}
    end

    -- Düşman kaçıyorsa range skill öncelikli
    if targetSpeed > 10 then
        if isSkillReady(Skills[2]) and dist <= Skills[2].Range then
            return {Type = "Skill", Skill = Skills[2], Index = 2}
        end
    end

    -- Ağırlıklı seçim
    local available = {}
    for i, skill in pairs(Skills) do
        if isSkillReady(skill) and dist <= skill.Range then
            for _ = 1, skill.ComboWeight do
                table.insert(available, {Type = "Skill", Skill = skill, Index = i})
            end
        end
    end

    if isPunchReady() and dist <= Punch.Range then
        for _ = 1, Punch.ComboWeight do
            table.insert(available, {Type = "Punch"})
        end
    end

    if #available == 0 then return nil end
    return available[math.random(1, #available)]
end

local function executeAction(action)
    if not action then return end
    local now = tick()

    if action.Type == "Punch" then
        Punch.LastUsed = now
        pressMouseClick()
        comboCount = comboCount + 1
        comboResetTimer = now
        StatusLabel.Text = "👊 Punch! Combo: " .. comboCount
    elseif action.Type == "Skill" then
        local skill = action.Skill
        skill.LastUsed = now
        pressKey(skill.Key)
        comboCount = comboCount + 1
        comboResetTimer = now
        StatusLabel.Text = "⚡ " .. skill.Name .. "! Combo: " .. comboCount .. " (DMG: " .. skill.Damage .. ")"
    end

    ComboLabel.Text = "COMBO: " .. comboCount
    lastAction = now
end

-- ================================================
-- COMBAT LOOP
-- ================================================
local combatConn = nil

local function startCombat(targetRoot)
    if combatConn then combatConn:Disconnect() end
    combatActive = true
    HudFrame.Visible = true

    combatConn = RunService.Heartbeat:Connect(function(dt)
        local char = LocalPlayer.Character
        local myHrp = char and char:FindFirstChild("HumanoidRootPart")
        if not myHrp or not targetRoot or not targetRoot.Parent then
            combatActive = false
            HudFrame.Visible = false
            combatConn:Disconnect()
            return
        end

        updateTargetPrediction(targetRoot)

        local dist = (myHrp.Position - targetRoot.Position).Magnitude

        -- Skill CD HUD güncelle
        for i, skill in pairs(Skills) do
            local cdLeft = getSkillCooldownLeft(skill)
            local cdLabel = SkillButtons[i]:FindFirstChild("CD")
            if cdLabel then
                if cdLeft <= 0 then
                    cdLabel.Text = "READY"
                    cdLabel.TextColor3 = Color3.fromRGB(75, 255, 75)
                    SkillButtons[i].BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                else
                    cdLabel.Text = string.format("%.1fs", cdLeft)
                    cdLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                    SkillButtons[i].BackgroundColor3 = Color3.fromRGB(40, 20, 20)
                end
            end
        end

        -- Combo reset (2 saniye aksiyon yoksa)
        if comboResetTimer > 0 and (tick() - comboResetTimer) > 2.0 then
            comboCount = 0
            comboResetTimer = 0
            ComboLabel.Text = "COMBO: 0"
        end

        -- Saldırı menzilinde combat
        if dist <= 6 then
            local action = getBestAction(targetRoot)
            if action and (tick() - lastAction) >= 0.15 then
                executeAction(action)
            end
        end
    end)
end

local function stopCombat()
    combatActive = false
    HudFrame.Visible = false
    if combatConn then
        combatConn:Disconnect()
        combatConn = nil
    end
    comboCount = 0
    ComboLabel.Text = "COMBO: 0"
end

-- ================================================
-- PATHFINDING + TAKİP LOOP
-- ================================================
local function stopTracking()
    if trackConn then trackConn:Disconnect(); trackConn = nil end
    stopCombat()
    isTracking = false
    lastTargetPos = nil
    lastTargetTime = nil
    targetVelocity = Vector3.zero
    local character = LocalPlayer.Character
    if character then
        setLayPose(character, false)
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end
    StatusLabel.Text = "⏹ Durduruldu"
end

local function startTracking(targetRoot)
    stopTracking()

    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp or not targetRoot then return end

    isTracking = true
    setLayPose(character, true)
    startCombat(targetRoot)

    local waypoints = nil
    local wpIndex = 1
    local currentTween = nil

    trackConn = RunService.Heartbeat:Connect(function(dt)
        local char = LocalPlayer.Character
        local myHrp = char and char:FindFirstChild("HumanoidRootPart")
        if not myHrp or not targetRoot or not targetRoot.Parent then
            stopTracking()
            return
        end

        -- Fling fix
        myHrp.AssemblyLinearVelocity = Vector3.zero
        myHrp.AssemblyAngularVelocity = Vector3.zero

        local dist = (myHrp.Position - targetRoot.Position).Magnitude

        -- Hedefe bak (yatık halde)
        local lookDir = (targetRoot.Position - myHrp.Position) * Vector3.new(1, 0, 1)
        if lookDir.Magnitude > 0.1 then
            myHrp.CFrame = CFrame.new(myHrp.Position, myHrp.Position + lookDir) * CFrame.Angles(math.rad(90), 0, 0)
        end

        -- Saldırı menzilindeyse dur
        if dist <= 5 then
            StatusLabel.Text = "⚔️ Combat menzilinde!"
            if currentTween then currentTween:Cancel() end
            return
        end

        -- Path güncelleme
        pathUpdateTimer = pathUpdateTimer + dt
        if pathUpdateTimer >= PATH_UPDATE_INTERVAL then
            pathUpdateTimer = 0
            local travelTime = dist / 60
            local predictedPos = getPredictedPosition(targetRoot, travelTime)
            local newWaypoints = computePath(myHrp.Position, predictedPos)
            if newWaypoints and #newWaypoints > 1 then
                waypoints = newWaypoints
                wpIndex = 2
                StatusLabel.Text = "🗺️ Pathfinding (" .. #waypoints .. " wp)"
            else
                waypoints = nil
                StatusLabel.Text = "➡️ Direkt hareket"
            end
        end

        -- Waypoint takibi
        if waypoints and wpIndex <= #waypoints then
            local wp = waypoints[wpIndex]
            local wpDist = (myHrp.Position - wp.Position).Magnitude

            if wpDist < 3 then
                wpIndex = wpIndex + 1
            else
                if currentTween then currentTween:Cancel() end
                local tweenDur = math.clamp(wpDist / 60, 0.05, 0.2)
                local targetCF = CFrame.new(wp.Position, Vector3.new(targetRoot.Position.X, wp.Position.Y, targetRoot.Position.Z))
                    * CFrame.Angles(math.rad(90), 0, 0)
                currentTween = TweenService:Create(myHrp, TweenInfo.new(tweenDur, Enum.EasingStyle.Linear), {CFrame = targetCF})
                currentTween:Play()

                if wp.Action == Enum.PathWaypointAction.Jump then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then hum.Jump = true end
                end
            end
        else
            if currentTween then currentTween:Cancel() end
            local tweenDur = math.clamp(dist / 80, 0.05, 0.15)
            local approachPos = targetRoot.Position + (myHrp.Position - targetRoot.Position).Unit * 3
            local targetCF = CFrame.new(approachPos, targetRoot.Position) * CFrame.Angles(math.rad(90), 0, 0)
            currentTween = TweenService:Create(myHrp, TweenInfo.new(tweenDur, Enum.EasingStyle.Linear), {CFrame = targetCF})
            currentTween:Play()
        end
    end)
end

-- ================================================
-- TARGET LİSTESİ UI
-- ================================================
RunService.Heartbeat:Connect(function()
    local targets = {}
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(targets, {Name = p.Name, Root = p.Character.HumanoidRootPart, Id = p.UserId})
        end
    end

    local charFolder = Workspace:FindFirstChild("Characters")
    if charFolder then
        for _, d in pairs(charFolder:GetChildren()) do
            if d:FindFirstChild("HumanoidRootPart") then
                local uniqueName = d.Name .. "_" .. d:GetDebugId()
                table.insert(targets, {Name = uniqueName, DisplayName = d.Name, Root = d.HumanoidRootPart, Id = 0})
            end
        end
    end

    if myRoot then
        table.sort(targets, function(a, b)
            return (a.Root.Position - myRoot.Position).Magnitude < (b.Root.Position - myRoot.Position).Magnitude
        end)
    end

    for _, data in pairs(targets) do
        local displayName = data.DisplayName or data.Name
        local item = Scroll:FindFirstChild(data.Name)
        if not item then
            item = Instance.new("TextButton", Scroll)
            item.Name = data.Name
            item.Size = UDim2.new(1, 0, 0, 35)
            item.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            item.Text = ""
            Instance.new("UICorner", item).CornerRadius = UDim.new(0, 4)

            local icon = Instance.new("ImageLabel", item)
            icon.Name = "Icon"
            icon.Size = UDim2.new(0, 25, 0, 25)
            icon.Position = UDim2.new(0, 5, 0, 5)
            icon.BackgroundTransparency = 1
            Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)

            local txt = Instance.new("TextLabel", item)
            txt.Name = "Label"
            txt.Size = UDim2.new(0, 115, 1, 0)
            txt.Position = UDim2.new(0, 40, 0, 0)
            txt.BackgroundTransparency = 1
            txt.TextColor3 = Color3.new(1, 1, 1)
            txt.Font = Enum.Font.Gotham
            txt.TextSize = 12

            local stopBtn = Instance.new("TextButton", item)
            stopBtn.Name = "StopBtn"
            stopBtn.Size = UDim2.new(0, 22, 0, 22)
            stopBtn.Position = UDim2.new(1, -26, 0, 6)
            stopBtn.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
            stopBtn.Text = "✕"
            stopBtn.TextColor3 = Color3.new(1, 1, 1)
            stopBtn.TextSize = 11
            stopBtn.Font = Enum.Font.GothamBold
            stopBtn.Visible = false
            Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 4)

            local capturedData = data
            stopBtn.MouseButton1Click:Connect(function()
                SelectedTarget = nil
                stopTracking()
            end)

            item.MouseButton1Click:Connect(function()
                if SelectedTarget == capturedData.Name and isTracking then
                    SelectedTarget = nil
                    stopTracking()
                    return
                end
                SelectedTarget = capturedData.Name
                notify(displayName, capturedData.Id)
                startTracking(capturedData.Root)
            end)
        end

        local dist = myRoot and math.floor((data.Root.Position - myRoot.Position).Magnitude) or 0
        local icon = item:FindFirstChild("Icon")
        local label = item:FindFirstChild("Label")
        local stopBtn = item:FindFirstChild("StopBtn")

        if icon then
            icon.Image = (data.Id == 0) and "rbxassetid://1" or Players:GetUserThumbnailAsync(data.Id, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
        end
        if label then
            label.Text = displayName .. " [" .. dist .. "m]"
            label.TextColor3 = (SelectedTarget == data.Name) and Color3.fromRGB(75, 255, 75) or Color3.fromRGB(200, 200, 200)
        end
        if stopBtn then
            stopBtn.Visible = (SelectedTarget == data.Name and isTracking)
        end

        item.BackgroundColor3 = (SelectedTarget == data.Name) and Color3.fromRGB(20, 50, 20) or Color3.fromRGB(30, 30, 30)
    end

    for _, child in pairs(Scroll:GetChildren()) do
        if child:IsA("TextButton") then
            local found = false
            for _, t in pairs(targets) do
                if t.Name == child.Name then found = true break end
            end
            if not found then
                if child.Name == SelectedTarget then
                    SelectedTarget = nil
                    stopTracking()
                end
                child:Destroy()
            end
        end
    end
end)
