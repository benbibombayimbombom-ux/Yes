-- Full Camlock + PredictionPart + Trail + CornerBox + AutoAir + Smoothness
-- + PopEffect + DamageIndicator + Neverlose Hit Sound + AfterImage
-- + Auto/Manual Ping Prediction (X,Y,Z) + SETTINGS PANEL
-- LocalScript (StarterPlayerScripts)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

-- ============================================================
-- LOADING SCREEN
-- ============================================================
local blur = Instance.new("BlurEffect", Lighting)
blur.Size = 25

local loadingGui = Instance.new("ScreenGui", PlayerGui)
loadingGui.IgnoreGuiInset = true
loadingGui.ResetOnSpawn = false

local loadingText = Instance.new("TextLabel", loadingGui)
loadingText.Size = UDim2.new(0.4, 0, 0.4, 0)
loadingText.AnchorPoint = Vector2.new(0.5, 0.5)
loadingText.Position = UDim2.new(0.5, 0, 0.5, 0)
loadingText.Text = "R"
loadingText.TextScaled = true
loadingText.Font = Enum.Font.GothamBlack
loadingText.TextColor3 = Color3.new(1, 1, 1)
loadingText.BackgroundTransparency = 1

local gradient = Instance.new("UIGradient", loadingText)
gradient.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 100, 255))
}
gradient.Rotation = 45

local fade = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
TweenService:Create(loadingText, fade, {TextTransparency = 0}):Play()

local sound = Instance.new("Sound", workspace)
sound.SoundId = "rbxassetid://15689458836"
sound.Volume = 0.5
sound.Looped = true
sound:Play()

task.wait(3)
TweenService:Create(loadingText, fade, {TextTransparency = 1}):Play()
TweenService:Create(blur, fade, {Size = 0}):Play()
TweenService:Create(sound, TweenInfo.new(2), {Volume = 0}):Play()
task.wait(2)
sound:Destroy()
blur:Destroy()
loadingGui:Destroy()

-- ============================================================
-- SETTINGS CONFIG (tüm özellikler buradan yönetilir)
-- ============================================================
local Config = {
	-- Özellik toggleları
	TrailEnabled        = true,
	HighlightEnabled    = true,
	CornerBoxEnabled    = true,
	DamageIndicatorEnabled = true,
	AfterImageEnabled   = true,
	PopEffectEnabled    = true,
	AutoAirEnabled      = true,

	-- Prediction
	AutoPrediction      = true,   -- true = ping bazlı otomatik, false = manuel değer
	ManualPredictionValue = 0.15, -- manuel modda kullanılan katsayı

	-- Smoothness (0.01 = çok yumuşak, 1 = anlık)
	Smoothness          = 0.15,

	-- Renk presetleri
	AccentColor         = Color3.fromRGB(0, 100, 255),

	-- Hit Sound seçimi
	-- 1 = Neverlose, 2 = Original, 3 = Hollow, 4 = Metal, 5 = Tick
	SelectedSound       = 1,
	HitVolume           = 2,

	-- Pop effect boyutu
	PopSize             = 10,

	-- Damage indicator font
	IndicatorBold       = true,
}

-- Hit Sound tablosu (genişletilebilir)
local HitSounds = {
	{ name = "Neverlose",  id = "rbxassetid://8679627751" },
	{ name = "Original",   id = "rbxassetid://7322736504" },
	{ name = "Hollow",     id = "rbxassetid://6042053626" },
	{ name = "Metal",      id = "rbxassetid://5153644718" },
	{ name = "Tick",       id = "rbxassetid://4612333531" },
}

-- ============================================================
-- UTILITY HELPERS (GUI oluşturma)
-- ============================================================
local function makeCorner(parent, radius)
	local c = Instance.new("UICorner", parent)
	c.CornerRadius = UDim.new(0, radius or 8)
	return c
end

local function makeStroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke", parent)
	s.Color = color or Color3.fromRGB(0, 100, 255)
	s.Thickness = thickness or 1.5
	s.Transparency = transparency or 0.5
	return s
end

local function makeGradient(parent, c0, c1, rot)
	local g = Instance.new("UIGradient", parent)
	g.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, c0 or Color3.fromRGB(20,20,30)),
		ColorSequenceKeypoint.new(1, c1 or Color3.fromRGB(10,10,20))
	}
	g.Rotation = rot or 90
	return g
end

-- ============================================================
-- MAIN GUI
-- ============================================================
local mainGui = Instance.new("ScreenGui", PlayerGui)
mainGui.IgnoreGuiInset = true
mainGui.ResetOnSpawn = false
mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- ============================================================
-- TOGGLE BUTTON (Ortada, sürüklenebilir)
-- ============================================================
local toggle = Instance.new("TextButton", mainGui)
toggle.Size = UDim2.new(0, 110, 0, 110)
toggle.Position = UDim2.new(0.5, 0, 0.5, 0)
toggle.AnchorPoint = Vector2.new(0.5, 0.5)
toggle.Text = "R"
toggle.Font = Enum.Font.GothamBlack
toggle.TextScaled = true
toggle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
toggle.BackgroundTransparency = 0.5
toggle.TextColor3 = Color3.new(1, 1, 1)
toggle.Active = true
toggle.AutoButtonColor = true
toggle.Draggable = true
toggle.ClipsDescendants = true
toggle.ZIndex = 5
makeCorner(toggle, 15)

local tg = Instance.new("UIGradient", toggle)
tg.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 100, 255))
}
tg.Rotation = 45

local ts = Instance.new("UIStroke", toggle)
ts.Thickness = 3
ts.Color = Color3.fromRGB(0, 0, 255)
ts.Transparency = 0.5
TweenService:Create(ts, TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true), {Color = Color3.fromRGB(0, 0, 0)}):Play()

-- ============================================================
-- SETTINGS BUTTON (Sağ üst köşe)
-- ============================================================
local settingsBtn = Instance.new("TextButton", mainGui)
settingsBtn.Size = UDim2.new(0, 40, 0, 40)
settingsBtn.Position = UDim2.new(1, -55, 0, 15)
settingsBtn.AnchorPoint = Vector2.new(0, 0)
settingsBtn.Text = "⚙"
settingsBtn.Font = Enum.Font.GothamBold
settingsBtn.TextSize = 22
settingsBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
settingsBtn.BackgroundTransparency = 0.2
settingsBtn.TextColor3 = Color3.fromRGB(0, 120, 255)
settingsBtn.Active = true
settingsBtn.AutoButtonColor = false
settingsBtn.ZIndex = 10
makeCorner(settingsBtn, 10)
makeStroke(settingsBtn, Color3.fromRGB(0, 100, 255), 1.5, 0.4)

-- Gear animasyonu
TweenService:Create(settingsBtn, TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Rotation = 360}):Play()

-- ============================================================
-- SETTINGS PANEL
-- ============================================================
local PANEL_W, PANEL_H = 340, 520
local panelOpen = false

local panel = Instance.new("Frame", mainGui)
panel.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
panel.Position = UDim2.new(1, 10, 0, 0)   -- başlangıçta ekran dışı
panel.BackgroundColor3 = Color3.fromRGB(10, 12, 22)
panel.BackgroundTransparency = 0.05
panel.ClipsDescendants = true
panel.ZIndex = 20
panel.BorderSizePixel = 0
makeCorner(panel, 14)
makeStroke(panel, Color3.fromRGB(0, 100, 255), 1.5, 0.35)

-- Panel header
local header = Instance.new("Frame", panel)
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundColor3 = Color3.fromRGB(0, 60, 160)
header.BackgroundTransparency = 0.55
header.BorderSizePixel = 0
header.ZIndex = 21
makeCorner(header, 14)

local headerLabel = Instance.new("TextLabel", header)
headerLabel.Size = UDim2.new(1, -10, 1, 0)
headerLabel.Position = UDim2.new(0, 12, 0, 0)
headerLabel.BackgroundTransparency = 1
headerLabel.Text = "⚙  SETTINGS"
headerLabel.Font = Enum.Font.GothamBlack
headerLabel.TextSize = 16
headerLabel.TextColor3 = Color3.fromRGB(180, 210, 255)
headerLabel.TextXAlignment = Enum.TextXAlignment.Left
headerLabel.ZIndex = 22

-- Kapatma butonu
local closeBtn = Instance.new("TextButton", header)
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -34, 0.5, -14)
closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
closeBtn.BackgroundTransparency = 0.5
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.AutoButtonColor = true
closeBtn.ZIndex = 23
makeCorner(closeBtn, 6)

-- Scrollable content area
local scroll = Instance.new("ScrollingFrame", panel)
scroll.Size = UDim2.new(1, 0, 1, -44)
scroll.Position = UDim2.new(0, 0, 0, 44)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 100, 255)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)  -- otomatik hesaplanacak
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ZIndex = 21

local listLayout = Instance.new("UIListLayout", scroll)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 6)

local scrollPad = Instance.new("UIPadding", scroll)
scrollPad.PaddingLeft   = UDim.new(0, 12)
scrollPad.PaddingRight  = UDim.new(0, 12)
scrollPad.PaddingTop    = UDim.new(0, 8)
scrollPad.PaddingBottom = UDim.new(0, 8)

-- ============================================================
-- PANEL ANIM (aç / kapat)
-- ============================================================
local panelTweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local function openPanel()
	panelOpen = true
	local targetX = 1 - (PANEL_W / mainGui.AbsoluteSize.X) - (55 / mainGui.AbsoluteSize.X)
	TweenService:Create(panel, panelTweenInfo, {
		Position = UDim2.new(1, -(PANEL_W + 55), 0, 60)
	}):Play()
end

local function closePanel()
	panelOpen = false
	TweenService:Create(panel, panelTweenInfo, {
		Position = UDim2.new(1, 10, 0, 60)
	}):Play()
end

settingsBtn.MouseButton1Click:Connect(function()
	if panelOpen then closePanel() else openPanel() end
end)

closeBtn.MouseButton1Click:Connect(function()
	closePanel()
end)

-- ============================================================
-- SECTION / TOGGLE / SLIDER / DROPDOWN BUILDERS
-- ============================================================

-- Section başlığı
local function addSection(text, order)
	local sec = Instance.new("TextLabel", scroll)
	sec.Size = UDim2.new(1, 0, 0, 26)
	sec.BackgroundTransparency = 1
	sec.Text = "  " .. string.upper(text)
	sec.Font = Enum.Font.GothamBlack
	sec.TextSize = 11
	sec.TextColor3 = Color3.fromRGB(0, 140, 255)
	sec.TextXAlignment = Enum.TextXAlignment.Left
	sec.LayoutOrder = order
	sec.ZIndex = 22
	return sec
end

-- Toggle satırı (sol label + sağ switch)
local function addToggle(label, configKey, order, onChange)
	local row = Instance.new("Frame", scroll)
	row.Size = UDim2.new(1, 0, 0, 36)
	row.BackgroundColor3 = Color3.fromRGB(18, 22, 40)
	row.BackgroundTransparency = 0.3
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.ZIndex = 22
	makeCorner(row, 8)

	local lbl = Instance.new("TextLabel", row)
	lbl.Size = UDim2.new(0.7, 0, 1, 0)
	lbl.Position = UDim2.new(0, 10, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = label
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 13
	lbl.TextColor3 = Color3.fromRGB(200, 210, 230)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.ZIndex = 23

	-- Switch kapsayıcısı
	local switchBg = Instance.new("TextButton", row)
	switchBg.Size = UDim2.new(0, 46, 0, 24)
	switchBg.Position = UDim2.new(1, -56, 0.5, -12)
	switchBg.AutoButtonColor = false
	switchBg.Text = ""
	switchBg.ZIndex = 23
	makeCorner(switchBg, 12)

	local knob = Instance.new("Frame", switchBg)
	knob.Size = UDim2.new(0, 18, 0, 18)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	knob.ZIndex = 24
	makeCorner(knob, 9)

	local function refresh()
		local on = Config[configKey]
		local tweenT = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		if on then
			switchBg.BackgroundColor3 = Color3.fromRGB(0, 100, 255)
			TweenService:Create(knob, tweenT, {Position = UDim2.new(0, 34, 0.5, 0)}):Play()
		else
			switchBg.BackgroundColor3 = Color3.fromRGB(50, 55, 70)
			TweenService:Create(knob, tweenT, {Position = UDim2.new(0, 14, 0.5, 0)}):Play()
		end
	end

	refresh()

	switchBg.MouseButton1Click:Connect(function()
		Config[configKey] = not Config[configKey]
		refresh()
		if onChange then onChange(Config[configKey]) end
	end)

	return row
end

-- Slider satırı
local function addSlider(label, configKey, minVal, maxVal, order, fmt, onChange)
	local row = Instance.new("Frame", scroll)
	row.Size = UDim2.new(1, 0, 0, 52)
	row.BackgroundColor3 = Color3.fromRGB(18, 22, 40)
	row.BackgroundTransparency = 0.3
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.ZIndex = 22
	makeCorner(row, 8)

	local lbl = Instance.new("TextLabel", row)
	lbl.Size = UDim2.new(0.6, 0, 0, 22)
	lbl.Position = UDim2.new(0, 10, 0, 4)
	lbl.BackgroundTransparency = 1
	lbl.Text = label
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 13
	lbl.TextColor3 = Color3.fromRGB(200, 210, 230)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.ZIndex = 23

	local valLabel = Instance.new("TextLabel", row)
	valLabel.Size = UDim2.new(0.35, 0, 0, 22)
	valLabel.Position = UDim2.new(0.62, 0, 0, 4)
	valLabel.BackgroundTransparency = 1
	valLabel.Font = Enum.Font.GothamBold
	valLabel.TextSize = 13
	valLabel.TextColor3 = Color3.fromRGB(0, 160, 255)
	valLabel.TextXAlignment = Enum.TextXAlignment.Right
	valLabel.ZIndex = 23

	local track = Instance.new("Frame", row)
	track.Size = UDim2.new(1, -20, 0, 6)
	track.Position = UDim2.new(0, 10, 0, 34)
	track.BackgroundColor3 = Color3.fromRGB(40, 45, 65)
	track.BorderSizePixel = 0
	track.ZIndex = 23
	makeCorner(track, 3)

	local fill = Instance.new("Frame", track)
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(0, 100, 255)
	fill.BorderSizePixel = 0
	fill.ZIndex = 24
	makeCorner(fill, 3)

	local function updateSlider(val)
		val = math.clamp(val, minVal, maxVal)
		Config[configKey] = val
		local ratio = (val - minVal) / (maxVal - minVal)
		fill.Size = UDim2.new(ratio, 0, 1, 0)
		if fmt then
			valLabel.Text = string.format(fmt, val)
		else
			valLabel.Text = tostring(math.floor(val * 1000) / 1000)
		end
		if onChange then onChange(val) end
	end

	updateSlider(Config[configKey])

	local dragging = false
	track.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end)
	track.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(inp)
		if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
			local absPos = track.AbsolutePosition.X
			local absSize = track.AbsoluteSize.X
			local ratio = math.clamp((inp.Position.X - absPos) / absSize, 0, 1)
			updateSlider(minVal + ratio * (maxVal - minVal))
		end
	end)

	return row
end

-- Dropdown satırı
local function addDropdown(label, options, configKey, order, onChange)
	local totalH = 36 + #options * 30
	local collapsed = true

	local container = Instance.new("Frame", scroll)
	container.Size = UDim2.new(1, 0, 0, 36)
	container.BackgroundColor3 = Color3.fromRGB(18, 22, 40)
	container.BackgroundTransparency = 0.3
	container.BorderSizePixel = 0
	container.LayoutOrder = order
	container.ClipsDescendants = true
	container.ZIndex = 22
	makeCorner(container, 8)

	local headerBtn = Instance.new("TextButton", container)
	headerBtn.Size = UDim2.new(1, 0, 0, 36)
	headerBtn.BackgroundTransparency = 1
	headerBtn.Text = ""
	headerBtn.ZIndex = 23

	local headerLbl = Instance.new("TextLabel", headerBtn)
	headerLbl.Size = UDim2.new(0.75, 0, 1, 0)
	headerLbl.Position = UDim2.new(0, 10, 0, 0)
	headerLbl.BackgroundTransparency = 1
	headerLbl.Text = label .. ":  " .. options[Config[configKey]].name
	headerLbl.Font = Enum.Font.Gotham
	headerLbl.TextSize = 13
	headerLbl.TextColor3 = Color3.fromRGB(200, 210, 230)
	headerLbl.TextXAlignment = Enum.TextXAlignment.Left
	headerLbl.ZIndex = 24

	local arrow = Instance.new("TextLabel", headerBtn)
	arrow.Size = UDim2.new(0, 24, 1, 0)
	arrow.Position = UDim2.new(1, -30, 0, 0)
	arrow.BackgroundTransparency = 1
	arrow.Text = "▼"
	arrow.Font = Enum.Font.GothamBold
	arrow.TextSize = 12
	arrow.TextColor3 = Color3.fromRGB(0, 120, 255)
	arrow.ZIndex = 24

	-- Option satırları
	for i, opt in ipairs(options) do
		local optBtn = Instance.new("TextButton", container)
		optBtn.Size = UDim2.new(1, -20, 0, 28)
		optBtn.Position = UDim2.new(0, 10, 0, 36 + (i - 1) * 30 + 2)
		optBtn.BackgroundColor3 = (Config[configKey] == i) and Color3.fromRGB(0, 80, 200) or Color3.fromRGB(25, 30, 50)
		optBtn.BackgroundTransparency = 0.3
		optBtn.Text = "  " .. opt.name
		optBtn.Font = Enum.Font.Gotham
		optBtn.TextSize = 12
		optBtn.TextColor3 = Color3.fromRGB(200, 215, 240)
		optBtn.TextXAlignment = Enum.TextXAlignment.Left
		optBtn.ZIndex = 24
		optBtn.AutoButtonColor = false
		makeCorner(optBtn, 6)

		optBtn.MouseButton1Click:Connect(function()
			Config[configKey] = i
			headerLbl.Text = label .. ":  " .. opt.name
			-- Seçili rengi güncelle
			for _, ch in ipairs(container:GetChildren()) do
				if ch:IsA("TextButton") and ch ~= headerBtn then
					ch.BackgroundColor3 = Color3.fromRGB(25, 30, 50)
				end
			end
			optBtn.BackgroundColor3 = Color3.fromRGB(0, 80, 200)
			if onChange then onChange(i) end
			-- kapat
			collapsed = true
			arrow.Text = "▼"
			TweenService:Create(container, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Size = UDim2.new(1, 0, 0, 36)}):Play()
		end)
	end

	headerBtn.MouseButton1Click:Connect(function()
		collapsed = not collapsed
		arrow.Text = collapsed and "▼" or "▲"
		local targetH = collapsed and 36 or totalH
		TweenService:Create(container, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Size = UDim2.new(1, 0, 0, targetH)}):Play()
	end)

	return container
end

-- Manuel değer girişi (TextBox ile)
local function addNumberInput(label, configKey, order, onChange)
	local row = Instance.new("Frame", scroll)
	row.Size = UDim2.new(1, 0, 0, 36)
	row.BackgroundColor3 = Color3.fromRGB(18, 22, 40)
	row.BackgroundTransparency = 0.3
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.ZIndex = 22
	makeCorner(row, 8)

	local lbl = Instance.new("TextLabel", row)
	lbl.Size = UDim2.new(0.55, 0, 1, 0)
	lbl.Position = UDim2.new(0, 10, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = label
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 13
	lbl.TextColor3 = Color3.fromRGB(200, 210, 230)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.ZIndex = 23

	local box = Instance.new("TextBox", row)
	box.Size = UDim2.new(0, 100, 0, 24)
	box.Position = UDim2.new(1, -110, 0.5, -12)
	box.BackgroundColor3 = Color3.fromRGB(8, 10, 20)
	box.Text = tostring(Config[configKey])
	box.Font = Enum.Font.GothamBold
	box.TextSize = 13
	box.TextColor3 = Color3.fromRGB(0, 160, 255)
	box.ClearTextOnFocus = false
	box.ZIndex = 23
	makeCorner(box, 6)
	makeStroke(box, Color3.fromRGB(0, 80, 200), 1.2, 0.5)

	box.FocusLost:Connect(function()
		local num = tonumber(box.Text)
		if num then
			Config[configKey] = num
			if onChange then onChange(num) end
		else
			box.Text = tostring(Config[configKey])
		end
	end)

	return row
end

-- ============================================================
-- PANEL İÇERİĞİNİ DOLDUR
-- ============================================================

-- 1. FEATURES bölümü
addSection("Features", 1)

addToggle("Trail",             "TrailEnabled",            2, function(v)
	-- Mevcut trail'leri yeniden oluştur/kaldır (toggle aktifleşince hedef seçilmiş olmalı)
end)

addToggle("Highlight / ESP",   "HighlightEnabled",        3, function(v)
	if not v and highlight then highlight.Enabled = false
	elseif v and highlight then highlight.Enabled = true end
end)

addToggle("Corner Box",        "CornerBoxEnabled",        4, function(v)
	if cornerBox then cornerBox.Enabled = v end
end)

addToggle("Damage Indicator",  "DamageIndicatorEnabled",  5)
addToggle("After Image",       "AfterImageEnabled",       6)
addToggle("Pop Effect",        "PopEffectEnabled",        7)
addToggle("Auto Air (Jitter)", "AutoAirEnabled",          8)

-- 2. PREDICTION bölümü
addSection("Prediction", 9)

addToggle("Auto Ping Prediction", "AutoPrediction", 10, function(v)
	-- Manuel mod label'ı göster/gizle gerekebilir; burada sadece config güncellenir
end)

addNumberInput("Manual Prediction Value", "ManualPredictionValue", 11)
addSlider("Smoothness", "Smoothness", 0.01, 1, 12, "%.2f")

-- 3. HIT SOUND bölümü
addSection("Hit Sound", 13)

addDropdown("Sound", HitSounds, "SelectedSound", 14, function(idx)
	-- Seçilen ses Config.SelectedSound olarak güncellendi
end)

addSlider("Volume", "HitVolume", 0, 5, 15, "%.1f")

-- 4. VISUAL bölümü
addSection("Visual", 16)

addSlider("Pop Effect Size", "PopSize", 3, 25, 17, "%.0f")

-- ============================================================
-- VARIABLES (Script Mantığı)
-- ============================================================
local toggled       = false
local targetPlayer  = nil
local highlight     = nil
local cornerBox     = nil
local trailParts    = {}
local autoAirActive = false

-- ============================================================
-- PREDICTION PART
-- ============================================================
local PredictionPart = Instance.new("Part")
PredictionPart.Anchored    = true
PredictionPart.CanCollide  = false
PredictionPart.Size        = Vector3.new(0.8, 0.8, 0.8)
PredictionPart.Material    = Enum.Material.Neon
PredictionPart.Transparency = 0.3
PredictionPart.Color       = Color3.fromRGB(0, 100, 255)
PredictionPart.Parent      = workspace

-- ============================================================
-- FUNCTIONS
-- ============================================================

local function getAutoPrediction()
	local ping = LocalPlayer:GetNetworkPing() * 1000
	if ping < 30  then return 0.12588
	elseif ping < 50  then return 0.13054
	elseif ping < 80  then return 0.13934
	elseif ping < 110 then return 0.14834
	elseif ping < 140 then return 0.15734
	elseif ping < 170 then return 0.18471
	else return 0.19671
	end
end

local function getPrediction()
	if Config.AutoPrediction then
		return getAutoPrediction()
	else
		return Config.ManualPredictionValue
	end
end

local function addTrail(character)
	if not Config.TrailEnabled then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local att1 = Instance.new("Attachment", hrp); att1.Position = Vector3.new(0.5, 0, 0)
	local att2 = Instance.new("Attachment", hrp); att2.Position = Vector3.new(-0.5, 0, 0)
	local trail = Instance.new("Trail", hrp)
	trail.Attachment0 = att1; trail.Attachment1 = att2
	trail.Lifetime    = 0.6; trail.FaceCamera = true
	trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1)})
	trail.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 255))
	}
	table.insert(trailParts, trail)
end

local function addCornerBox(character)
	if not Config.CornerBoxEnabled then return end
	local torso = character:FindFirstChild("UpperTorso")
	if not torso then return end
	if cornerBox then cornerBox:Destroy() end
	local box = Instance.new("BillboardGui", torso)
	box.Adornee = torso; box.Size = UDim2.new(6, 0, 9, 0); box.AlwaysOnTop = true
	cornerBox = box
	local function createCorner(ax, ay, px, py)
		local f = Instance.new("Frame", box)
		f.Size = UDim2.new(0.25, 0, 0.25, 0); f.AnchorPoint = Vector2.new(ax, ay)
		f.Position = UDim2.new(px, 0, py, 0); f.BackgroundTransparency = 1
		for _, axis in pairs({"vert", "horiz"}) do
			local line = Instance.new("Frame", f)
			line.Size = (axis=="vert") and UDim2.new(0.1,0,1,0) or UDim2.new(1,0,0.1,0)
			line.Position = (axis=="vert") and UDim2.new(ax==0 and 0 or 0.9,0,0,0) or UDim2.new(0,0,ay==0 and 0 or 0.9,0)
			line.BackgroundColor3 = Color3.fromRGB(0, 100, 255)
			local grad = Instance.new("UIGradient", line)
			grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(0,0,0)),ColorSequenceKeypoint.new(1,Color3.fromRGB(0,100,255))}
			grad.Rotation = 45
		end
	end
	createCorner(0,0,0,0) createCorner(1,0,1,0) createCorner(0,1,0,1) createCorner(1,1,1,1)
end

local function getClosestPlayer()
	local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
	local closest, dist = nil, math.huge
	for _, p in pairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("UpperTorso") then
			local pos, onScreen = Camera:WorldToViewportPoint(p.Character.UpperTorso.Position)
			if onScreen then
				local mag = (Vector2.new(pos.X, pos.Y) - center).Magnitude
				if mag < dist then dist = mag; closest = p end
			end
		end
	end
	return closest
end

local function autoAirLoop(hum)
	task.wait(0.09)
	while Config.AutoAirEnabled and (hum:GetState()==Enum.HumanoidStateType.Freefall or hum:GetState()==Enum.HumanoidStateType.Jumping) do
		local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
		if tool then tool:Activate() end
		task.wait(0)
	end
	autoAirActive = false
end

-- ============================================================
-- AFTER IMAGE
-- ============================================================
local GHOST_COLOR = Color3.fromRGB(0, 40, 120)

local function cleanClone(clone)
	if clone:IsA("MeshPart") then clone.TextureID = "" end
	local sm = clone:FindFirstChildOfClass("SpecialMesh")
	if sm then sm.TextureId = "" end
	for _, child in ipairs(clone:GetChildren()) do
		if child:IsA("Decal") or child:IsA("Texture") or child:IsA("SurfaceAppearance")
			or child:IsA("JointInstance") or child:IsA("Motor6D") or child:IsA("Motor")
			or child:IsA("Weld") or child:IsA("WeldConstraint") or child:IsA("BillboardGui")
			or child:IsA("SurfaceGui") or child:IsA("Highlight") or child:IsA("SelectionBox") then
			child:Destroy()
		end
	end
end

local function createAfterImage(character)
	if not Config.AfterImageEnabled then return end
	local ghostFolder = Instance.new("Folder", workspace)
	ghostFolder.Name = "AfterImageGhost"
	local clonedParts = {}
	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("BasePart") then
			local ok, clone = pcall(function() return desc:Clone() end)
			if ok and clone then
				clone.Anchored = true; clone.CanCollide = false
				clone.Material = Enum.Material.Neon; clone.Color = GHOST_COLOR
				clone.Transparency = 0.55; clone.CastShadow = false
				clone.CFrame = desc.CFrame; clone.Parent = ghostFolder
				cleanClone(clone); table.insert(clonedParts, clone)
			end
		end
	end
	task.delay(1.5, function()
		for _, part in ipairs(clonedParts) do
			if part and part.Parent then
				TweenService:Create(part, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Transparency = 1}):Play()
			end
		end
		task.delay(0.55, function()
			if ghostFolder and ghostFolder.Parent then ghostFolder:Destroy() end
		end)
	end)
end

-- ============================================================
-- TOGGLE BUTTON CLICK
-- ============================================================
toggle.MouseButton1Click:Connect(function()
	toggled = not toggled
	if toggled then
		targetPlayer = getClosestPlayer()
		if targetPlayer and targetPlayer.Character then
			addTrail(targetPlayer.Character)
			addCornerBox(targetPlayer.Character)
			if Config.HighlightEnabled then
				highlight = Instance.new("Highlight", targetPlayer.Character)
				highlight.Adornee = targetPlayer.Character
				highlight.FillColor = Color3.fromRGB(0, 100, 255)
				highlight.OutlineColor = Color3.fromRGB(0, 0, 0)
				PredictionPart.Color = highlight.FillColor
			end
		end
	else
		if highlight then highlight:Destroy(); highlight = nil end
		if cornerBox then cornerBox:Destroy(); cornerBox = nil end
		for _, v in pairs(trailParts) do v:Destroy() end
		trailParts = {}
		targetPlayer = nil
	end
end)

-- ============================================================
-- MAIN LOOP (X, Y, Z PREDICTION)
-- ============================================================
RunService.RenderStepped:Connect(function()
	if toggled and targetPlayer and targetPlayer.Character then
		local char  = targetPlayer.Character
		local torso = char:FindFirstChild("UpperTorso")
		local hum   = char:FindFirstChildOfClass("Humanoid")
		if torso then
			local vel  = torso.AssemblyLinearVelocity
			local pred = getPrediction()

			local predX = torso.Position.X + (vel.X * pred)
			local predY = torso.Position.Y + (vel.Y * pred)
			local predZ = torso.Position.Z + (vel.Z * pred)

			if hum and (hum:GetState()==Enum.HumanoidStateType.Freefall or hum:GetState()==Enum.HumanoidStateType.Jumping) then
				predY = torso.Position.Y + (vel.Y * (pred * 0.5))
			end

			local predictedPos = Vector3.new(predX, predY, predZ)
			PredictionPart.Position = predictedPos

			local camPos      = Camera.CFrame.Position
			local currentLook = Camera.CFrame.LookVector
			local desiredLook = (predictedPos - camPos).Unit
			local smoothedLook = currentLook:Lerp(desiredLook, Config.Smoothness)
			Camera.CFrame = CFrame.new(camPos, camPos + smoothedLook)

			if Config.AutoAirEnabled and hum and (hum:GetState()==Enum.HumanoidStateType.Freefall or hum:GetState()==Enum.HumanoidStateType.Jumping) then
				if not autoAirActive then
					autoAirActive = true
					task.spawn(function() autoAirLoop(hum) end)
				end
			end
		end
	end
end)

-- ============================================================
-- DAMAGE INDICATOR & POP EFFECT
-- ============================================================
local lastHealth     = nil
local activeIndicators = {}

local function createDamageIndicator(position, damage)
	if not Config.DamageIndicatorEnabled then return end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 120, 0, 30); gui.AlwaysOnTop = true; gui.Parent = workspace
	local offsetY = 3 + (#activeIndicators * 1.2)
	gui.StudsOffset = Vector3.new(math.random(-2, 2), offsetY, 0)
	table.insert(activeIndicators, gui)
	local label = Instance.new("TextLabel", gui)
	label.Size = UDim2.new(1, 0, 1, 0); label.BackgroundTransparency = 1
	label.Text = "-" .. tostring(math.floor(damage))
	label.Font = Config.IndicatorBold and Enum.Font.GothamBold or Enum.Font.Gotham
	label.TextScaled = true; label.TextColor3 = Color3.new(1, 1, 1)
	local grad = Instance.new("UIGradient", label)
	grad.Color = (damage >= 70)
		and ColorSequence.new(Color3.fromRGB(255, 0, 0), Color3.fromRGB(255, 180, 180))
		or  ColorSequence.new(Color3.fromRGB(0, 0, 0), Color3.fromRGB(0, 100, 255))
	gui.Adornee = PredictionPart
	TweenService:Create(gui, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {StudsOffset = gui.StudsOffset + Vector3.new(0, 2.5, 0)}):Play()
	TweenService:Create(label, TweenInfo.new(0.9), {TextTransparency = 1}):Play()
	task.delay(1.1, function()
		gui:Destroy()
		for i, v in ipairs(activeIndicators) do if v == gui then table.remove(activeIndicators, i); break end end
	end)
end

local function createPopEffect(position, isCritical)
	if not Config.PopEffectEnabled then return end
	local part = Instance.new("Part", workspace)
	part.Anchored = true; part.CanCollide = false; part.Material = Enum.Material.Neon
	part.Shape = Enum.PartType.Ball; part.Size = Vector3.new(1.5, 1.5, 1.5)
	part.CFrame = CFrame.new(position); part.Transparency = 0.3
	part.Color = isCritical and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 100, 255)
	local popSound = Instance.new("Sound", part)
	popSound.SoundId  = HitSounds[Config.SelectedSound].id
	popSound.Volume   = isCritical and Config.HitVolume * 1.3 or Config.HitVolume
	popSound:Play()
	local targetSize = Config.PopSize
	TweenService:Create(part, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = Vector3.new(targetSize, targetSize, targetSize), Transparency = 1}):Play()
	task.delay(0.6, function() part:Destroy() end)
end

RunService.Heartbeat:Connect(function()
	if toggled and targetPlayer and targetPlayer.Character then
		local hum   = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
		local torso = targetPlayer.Character:FindFirstChild("UpperTorso")
		if hum and torso then
			if lastHealth and hum.Health < lastHealth then
				local damage = lastHealth - hum.Health
				createDamageIndicator(torso.Position, damage)
				createPopEffect(torso.Position, (damage >= hum.MaxHealth / 2))
				task.spawn(function() createAfterImage(targetPlayer.Character) end)
			end
			if hum.Health <= 0 and lastHealth and lastHealth > 0 then
				createPopEffect(torso.Position, true)
				task.spawn(function() createAfterImage(targetPlayer.Character) end)
			end
			lastHealth = hum.Health
		end
	end
end)
