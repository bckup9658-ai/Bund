-- BunduAdmin.lua
-- Combined client utility UI
-- Sections: Misc / Gameplay

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CONFIG = {
	BabyName = "BabyPickup",
	BabyPromptName = "PickupPrompt",
	PromptDistance = 100000,
	HoneycombPath = {"Map", "Honeycomb"},
	-- Temporary fallback until the exact standing marker inside each door is known.
	DoorOffset = CFrame.new(0, 3, 6),
	ClickDelay = 0.008,
	CarveRetries = 2,
}

local SHAPES = {"Circle", "Triangle", "Square", "Star", "Umbrella"}
local SHAPE_SET = {}
for _, shape in SHAPES do SHAPE_SET[shape] = true end

local old = playerGui:FindFirstChild("BunduAdminUI")
if old then old:Destroy() end

local state = {
	destroyed = false,
	minimized = false,
	tab = "Misc",
	autoBaby = false,
	honeycombEnabled = false,
	autoCarve = false,
	selectedShape = "Circle",
	lastMovedShapeInstance = nil,
	lastCarvedModel = nil,
	scanQueued = false,
	carving = false,
}

local connections = {}
local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function tween(object, properties, duration)
	TweenService:Create(object, TweenInfo.new(duration or 0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), properties):Play()
end

local function new(className, properties, parent)
	local object = Instance.new(className)
	for property, value in properties do object[property] = value end
	object.Parent = parent
	return object
end

local function corner(parent, radius)
	return new("UICorner", {CornerRadius = UDim.new(0, radius or 9)}, parent)
end

local function stroke(parent, color, transparency)
	return new("UIStroke", {
		Color = color or Color3.fromRGB(67, 72, 94),
		Transparency = transparency or 0.35,
		Thickness = 1,
	}, parent)
end

-- UI -------------------------------------------------------------------------

local gui = new("ScreenGui", {
	Name = "BunduAdminUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 999,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local shadow = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(474, 324),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.55,
	BorderSizePixel = 0,
}, gui)
corner(shadow, 17)

local main = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(464, 314),
	BackgroundColor3 = Color3.fromRGB(13, 15, 23),
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, gui)
corner(main, 15)
stroke(main, Color3.fromRGB(86, 91, 127), 0.3)
new("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(23, 26, 40), Color3.fromRGB(11, 13, 20)),
	Rotation = 120,
}, main)

local accent = new("Frame", {
	Size = UDim2.new(1, 0, 0, 3),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
}, main)
new("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(52, 211, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(126, 88, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 75, 184)),
	}),
}, accent)

local header = new("Frame", {
	Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, Active = true,
}, main)

local logo = new("TextLabel", {
	Position = UDim2.fromOffset(13, 11), Size = UDim2.fromOffset(27, 27),
	BackgroundColor3 = Color3.fromRGB(111, 87, 255), BorderSizePixel = 0,
	Text = "B", TextColor3 = Color3.new(1, 1, 1), TextSize = 14, Font = Enum.Font.GothamBold,
}, header)
corner(logo, 8)

new("TextLabel", {
	Position = UDim2.fromOffset(49, 7), Size = UDim2.fromOffset(220, 20),
	BackgroundTransparency = 1, Text = "BUNDU ADMIN", TextColor3 = Color3.fromRGB(244, 246, 255),
	TextSize = 14, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
}, header)
new("TextLabel", {
	Position = UDim2.fromOffset(49, 25), Size = UDim2.fromOffset(220, 14),
	BackgroundTransparency = 1, Text = "CLIENT CONTROL CENTER", TextColor3 = Color3.fromRGB(112, 117, 142),
	TextSize = 8, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
}, header)

local function headerButton(text, offset)
	local button = new("TextButton", {
		Position = UDim2.new(1, offset, 0, 10), Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = Color3.fromRGB(31, 34, 48), BorderSizePixel = 0, AutoButtonColor = false,
		Text = text, TextColor3 = Color3.fromRGB(174, 179, 200), TextSize = 16, Font = Enum.Font.GothamBold,
	}, header)
	corner(button, 8)
	return button
end

local minimizeButton = headerButton("−", -69)
local closeButton = headerButton("×", -36)

local sidebar = new("Frame", {
	Position = UDim2.fromOffset(10, 50), Size = UDim2.fromOffset(110, 254),
	BackgroundColor3 = Color3.fromRGB(18, 20, 31), BackgroundTransparency = 0.12, BorderSizePixel = 0,
}, main)
corner(sidebar, 11)
stroke(sidebar, Color3.fromRGB(59, 64, 85), 0.5)

local pages = new("Frame", {
	Position = UDim2.fromOffset(128, 50), Size = UDim2.fromOffset(326, 254), BackgroundTransparency = 1,
}, main)

local tabButtons = {}
local pageFrames = {}

local function makeTab(name, iconText, y)
	local button = new("TextButton", {
		Position = UDim2.fromOffset(7, y), Size = UDim2.new(1, -14, 0, 40),
		BackgroundColor3 = Color3.fromRGB(29, 32, 47), BackgroundTransparency = 1,
		BorderSizePixel = 0, AutoButtonColor = false, Text = iconText .. "   " .. name,
		TextColor3 = Color3.fromRGB(128, 133, 156), TextSize = 10, Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, sidebar)
	new("UIPadding", {PaddingLeft = UDim.new(0, 12)}, button)
	corner(button, 9)
	tabButtons[name] = button

	local page = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false}, pages)
	pageFrames[name] = page
end

makeTab("Misc", "●", 8)
makeTab("Gameplay", "◆", 54)

local globalStatus = new("TextLabel", {
	Position = UDim2.new(0, 10, 1, -42), Size = UDim2.new(1, -20, 0, 30),
	BackgroundTransparency = 1, Text = "SYSTEM READY", TextColor3 = Color3.fromRGB(88, 199, 150),
	TextSize = 8, Font = Enum.Font.GothamBold, TextWrapped = true,
}, sidebar)

local function setStatus(text, color)
	if state.destroyed then return end
	globalStatus.Text = text
	globalStatus.TextColor3 = color or Color3.fromRGB(88, 199, 150)
end

local function switchTab(name)
	state.tab = name
	for tabName, button in tabButtons do
		local active = tabName == name
		pageFrames[tabName].Visible = active
		tween(button, {
			BackgroundTransparency = active and 0 or 1,
			BackgroundColor3 = active and Color3.fromRGB(48, 43, 80) or Color3.fromRGB(29, 32, 47),
			TextColor3 = active and Color3.fromRGB(234, 231, 255) or Color3.fromRGB(128, 133, 156),
		})
	end
end

for name, button in tabButtons do
	connect(button.MouseButton1Click, function() switchTab(name) end)
end

local function pageTitle(page, titleText, subText)
	new("TextLabel", {
		Position = UDim2.fromOffset(2, 0), Size = UDim2.new(1, -4, 0, 21), BackgroundTransparency = 1,
		Text = titleText, TextColor3 = Color3.fromRGB(240, 242, 251), TextSize = 14,
		Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
	}, page)
	new("TextLabel", {
		Position = UDim2.fromOffset(2, 21), Size = UDim2.new(1, -4, 0, 16), BackgroundTransparency = 1,
		Text = subText, TextColor3 = Color3.fromRGB(110, 115, 138), TextSize = 9,
		Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
	}, page)
end

local function makeToggleCard(page, y, titleText, detailText)
	local card = new("TextButton", {
		Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 57),
		BackgroundColor3 = Color3.fromRGB(25, 28, 41), BorderSizePixel = 0,
		AutoButtonColor = false, Text = "",
	}, page)
	corner(card, 11)
	local cardStroke = stroke(card, Color3.fromRGB(60, 65, 86), 0.45)
	local dot = new("Frame", {
		Position = UDim2.fromOffset(13, 21), Size = UDim2.fromOffset(13, 13),
		BackgroundColor3 = Color3.fromRGB(99, 104, 124), BorderSizePixel = 0,
	}, card)
	corner(dot, 20)
	local titleLabel = new("TextLabel", {
		Position = UDim2.fromOffset(37, 10), Size = UDim2.new(1, -94, 0, 19), BackgroundTransparency = 1,
		Text = titleText, TextColor3 = Color3.fromRGB(214, 217, 231), TextSize = 11,
		Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
	}, card)
	new("TextLabel", {
		Position = UDim2.fromOffset(37, 29), Size = UDim2.new(1, -94, 0, 16), BackgroundTransparency = 1,
		Text = detailText, TextColor3 = Color3.fromRGB(111, 116, 139), TextSize = 8,
		Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
	}, card)
	local track = new("Frame", {
		Position = UDim2.new(1, -51, 0.5, -10), Size = UDim2.fromOffset(38, 20),
		BackgroundColor3 = Color3.fromRGB(52, 56, 73), BorderSizePixel = 0,
	}, card)
	corner(track, 20)
	local knob = new("Frame", {
		Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Color3.fromRGB(217, 220, 233), BorderSizePixel = 0,
	}, track)
	corner(knob, 20)

	local function render(on)
		tween(card, {BackgroundColor3 = on and Color3.fromRGB(26, 45, 43) or Color3.fromRGB(25, 28, 41)})
		tween(cardStroke, {Color = on and Color3.fromRGB(66, 220, 155) or Color3.fromRGB(60, 65, 86)})
		tween(dot, {BackgroundColor3 = on and Color3.fromRGB(70, 239, 157) or Color3.fromRGB(99, 104, 124)})
		tween(track, {BackgroundColor3 = on and Color3.fromRGB(73, 202, 141) or Color3.fromRGB(52, 56, 73)})
		tween(knob, {Position = on and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3)})
		titleLabel.TextColor3 = on and Color3.fromRGB(235, 255, 246) or Color3.fromRGB(214, 217, 231)
	end

	return card, render
end

-- Misc page ------------------------------------------------------------------

local miscPage = pageFrames.Misc
pageTitle(miscPage, "Miscellaneous", "Lightweight quality-of-life automation")
local babyCard, renderBaby = makeToggleCard(miscPage, 48, "AUTO BABY", "Instantly activates the pickup prompt")

connect(babyCard.MouseButton1Click, function()
	state.autoBaby = not state.autoBaby
	renderBaby(state.autoBaby)
	setStatus(state.autoBaby and "AUTO BABY ARMED" or "AUTO BABY DISABLED")
end)

-- Gameplay page --------------------------------------------------------------

local gameplayPage = pageFrames.Gameplay
pageTitle(gameplayPage, "Gameplay", "Honeycomb selection and completion")

new("TextLabel", {
	Position = UDim2.fromOffset(2, 43), Size = UDim2.new(1, -4, 0, 15), BackgroundTransparency = 1,
	Text = "PREFERRED SHAPE", TextColor3 = Color3.fromRGB(131, 136, 160), TextSize = 8,
	Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
}, gameplayPage)

local shapeHolder = new("Frame", {
	Position = UDim2.fromOffset(0, 61), Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1,
}, gameplayPage)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5),
	HorizontalAlignment = Enum.HorizontalAlignment.Left,
}, shapeHolder)

local shapeButtons = {}
local function renderShapes()
	for name, button in shapeButtons do
		local active = name == state.selectedShape
		tween(button, {
			BackgroundColor3 = active and Color3.fromRGB(102, 79, 230) or Color3.fromRGB(28, 31, 45),
			TextColor3 = active and Color3.new(1, 1, 1) or Color3.fromRGB(145, 150, 172),
		})
	end
end

for _, shape in SHAPES do
	local button = new("TextButton", {
		Size = UDim2.fromOffset(60, 30), BackgroundColor3 = Color3.fromRGB(28, 31, 45),
		BorderSizePixel = 0, AutoButtonColor = false, Text = shape:sub(1, 3):upper(),
		TextColor3 = Color3.fromRGB(145, 150, 172), TextSize = 8, Font = Enum.Font.GothamBold,
	}, shapeHolder)
	corner(button, 8)
	shapeButtons[shape] = button
	connect(button.MouseButton1Click, function()
		state.selectedShape = shape
		state.lastMovedShapeInstance = nil
		renderShapes()
		setStatus("TARGET: " .. shape:upper())
	end)
end

local moveCard, renderMove = makeToggleCard(gameplayPage, 103, "PREFERRED DOOR", "Scan and move to the selected shape")
local carveCard, renderCarve = makeToggleCard(gameplayPage, 169, "AUTO CARVE", "Rapidly click every local path part")

-- World helpers --------------------------------------------------------------

local function follow(root, names)
	local current = root
	for _, name in names do
		current = current and current:FindFirstChild(name)
	end
	return current
end

local function honeycombRoot()
	return follow(Workspace, CONFIG.HoneycombPath)
end

local function findShapeUnder(door, wanted)
	local object = door:FindFirstChild(wanted, true)
	return object
end

local function findDoorTarget(door)
	local preferredNames = {"PlayerPosition", "Teleport", "Stand", "Spawn", "Position", "Floor", "Zone", "Trigger"}
	for _, name in preferredNames do
		local target = door:FindFirstChild(name, true)
		if target and target:IsA("BasePart") then return target.CFrame end
	end
	if door:IsA("Model") then return door:GetPivot() * CONFIG.DoorOffset end
	local part = door:FindFirstChildWhichIsA("BasePart", true)
	return part and (part.CFrame * CONFIG.DoorOffset) or nil
end

local function moveToDoor(door, shapeInstance)
	if shapeInstance == state.lastMovedShapeInstance then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local destination = findDoorTarget(door)
	if not root or not destination then
		setStatus("DOOR FOUND • POSITION UNKNOWN", Color3.fromRGB(242, 175, 85))
		return
	end
	state.lastMovedShapeInstance = shapeInstance
	root.CFrame = destination
	setStatus(state.selectedShape:upper() .. " • " .. door.Name:upper(), Color3.fromRGB(74, 231, 157))
end

local function scanPreferredDoor()
	if state.destroyed or not state.honeycombEnabled then return end
	local honeycomb = honeycombRoot()
	local doors = honeycomb and honeycomb:FindFirstChild("Doors")
	if not doors then
		setStatus("HONEYCOMB SCANNER WAITING", Color3.fromRGB(235, 177, 89))
		return
	end
	for _, door in doors:GetChildren() do
		local shapeInstance = findShapeUnder(door, state.selectedShape)
		if shapeInstance then
			moveToDoor(door, shapeInstance)
			return
		end
	end
	setStatus("SCANNING FOR " .. state.selectedShape:upper(), Color3.fromRGB(116, 168, 255))
end

local function queueScan()
	if state.scanQueued or state.destroyed then return end
	state.scanQueued = true
	task.defer(function()
		state.scanQueued = false
		scanPreferredDoor()
	end)
end

local function findLocalPath()
	local honeycomb = honeycombRoot()
	local shapes = honeycomb and honeycomb:FindFirstChild("Shapes")
	local model = shapes and shapes:FindFirstChild(player.Name)
	local path = model and model:FindFirstChild("Path")
	return model, path
end

local function clickScreen(x, y)
	local ok = pcall(function()
		VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
		task.wait(CONFIG.ClickDelay)
		VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
	end)
	return ok
end

local function carveLocalPath()
	if state.destroyed or not state.autoCarve or state.carving then return end
	local model, path = findLocalPath()
	if not model or not path or model == state.lastCarvedModel then return end

	state.carving = true
	local parts = {}
	for _, object in path:GetDescendants() do
		if object:IsA("BasePart") then table.insert(parts, object) end
	end

	if #parts == 0 then
		state.carving = false
		setStatus("AUTO CARVE • PATH EMPTY", Color3.fromRGB(242, 175, 85))
		return
	end

	setStatus("AUTO CARVE • " .. #parts .. " PARTS", Color3.fromRGB(116, 168, 255))
	local clicked = 0
	for _ = 1, CONFIG.CarveRetries do
		if not state.autoCarve or not model.Parent then break end
		local camera = Workspace.CurrentCamera
		for _, part in parts do
			if part.Parent and camera then
				local point, visible = camera:WorldToViewportPoint(part.Position)
				if visible and point.Z > 0 and clickScreen(math.floor(point.X), math.floor(point.Y)) then
					clicked += 1
				end
			end
		end
	end
	state.lastCarvedModel = model
	state.carving = false
	setStatus("AUTO CARVE • " .. clicked .. " CLICKS", Color3.fromRGB(74, 231, 157))
end

local function queueCarve()
	if not state.autoCarve then return end
	task.delay(0.1, carveLocalPath)
end

connect(moveCard.MouseButton1Click, function()
	state.honeycombEnabled = not state.honeycombEnabled
	state.lastMovedShapeInstance = nil
	renderMove(state.honeycombEnabled)
	if state.honeycombEnabled then queueScan() else setStatus("PREFERRED DOOR DISABLED") end
end)

connect(carveCard.MouseButton1Click, function()
	state.autoCarve = not state.autoCarve
	state.lastCarvedModel = nil
	renderCarve(state.autoCarve)
	if state.autoCarve then queueCarve() else setStatus("AUTO CARVE DISABLED") end
end)

-- Auto Baby ------------------------------------------------------------------

local babyBusy = false
local function activateBaby(baby)
	if state.destroyed or not state.autoBaby or babyBusy or baby.Name ~= CONFIG.BabyName then return end
	local prompt = baby:FindFirstChild(CONFIG.BabyPromptName, true)
	if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then return end
	if typeof(fireproximityprompt) ~= "function" then
		setStatus("AUTO BABY • FIRE UNAVAILABLE", Color3.fromRGB(255, 99, 119))
		return
	end
	babyBusy = true
	prompt.MaxActivationDistance = CONFIG.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	local ok = pcall(fireproximityprompt, prompt)
	setStatus(ok and "AUTO BABY • PICKED UP" or "AUTO BABY • FAILED", ok and Color3.fromRGB(74, 231, 157) or Color3.fromRGB(255, 99, 119))
	task.delay(0.25, function() babyBusy = false end)
end

-- Event-driven watchers: no permanent fast loop.
connect(Workspace.ChildAdded, function(child)
	if child.Name == CONFIG.BabyName then task.defer(activateBaby, child) end
end)

connect(Workspace.DescendantAdded, function(object)
	if state.honeycombEnabled and (SHAPE_SET[object.Name] or object.Name == "Doors") then queueScan() end
	if state.autoCarve and (object.Name == player.Name or object.Name == "Path" or object:IsA("BasePart")) then queueCarve() end
end)

connect(Workspace.DescendantRemoving, function(object)
	if object == state.lastMovedShapeInstance then state.lastMovedShapeInstance = nil end
	if object == state.lastCarvedModel then state.lastCarvedModel = nil end
end)

-- Window controls ------------------------------------------------------------

connect(minimizeButton.MouseButton1Click, function()
	state.minimized = not state.minimized
	local size = state.minimized and UDim2.fromOffset(464, 48) or UDim2.fromOffset(464, 314)
	local shadowSize = state.minimized and UDim2.fromOffset(474, 58) or UDim2.fromOffset(474, 324)
	minimizeButton.Text = state.minimized and "+" or "−"
	sidebar.Visible = not state.minimized
	pages.Visible = not state.minimized
	tween(main, {Size = size})
	tween(shadow, {Size = shadowSize})
end)

local dragging, dragInput, dragStart, startPosition = false, nil, nil, nil
connect(header.InputBegan, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging, dragStart, startPosition = true, input.Position, main.Position
		local ended
		ended = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				ended:Disconnect()
			end
		end)
	end
end)
connect(header.InputChanged, function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
end)
connect(UserInputService.InputChanged, function(input)
	if dragging and input == dragInput then
		local delta = input.Position - dragStart
		local position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
		main.Position, shadow.Position = position, position
	end
end)

connect(closeButton.MouseButton1Click, function()
	state.destroyed = true
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	gui:Destroy()
end)

renderBaby(false)
renderMove(false)
renderCarve(false)
renderShapes()
switchTab("Misc")
print("[BunduAdmin] Loaded")
