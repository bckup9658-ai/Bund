-- BunduAdmin.lua
-- Combined client utility UI
-- Sections: Misc / Gameplay

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
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
	-- Measured from the Star center to the far edge of the standing block.
	ShapeStandingOffset = Vector3.new(-0.306, 0, -11.490),
	CarvePixelStep = 2,
	CarveRowStep = 2,
	CarveYieldEvery = 14,
	CarvePasses = 2,
	CookieLockHeight = 2.25,
	BreakClickInterval = 0.035,
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
	selectedTarget = nil,
	barriersRemoved = false,
	cookieLock = false,
	breakCookie = false,
	breakLoopToken = 0,
}

local connections = {}
local activateBaby
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

	local page
	if name == "Gameplay" then
		page = new("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
			Visible = false, CanvasSize = UDim2.fromOffset(0, 620), ScrollBarThickness = 3,
			ScrollBarImageColor3 = Color3.fromRGB(103, 84, 220), ScrollingDirection = Enum.ScrollingDirection.Y,
		}, pages)
	else
		page = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false}, pages)
	end
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
	if state.autoBaby then
		local baby = Workspace:FindFirstChild(CONFIG.BabyName)
		if baby and activateBaby then task.defer(activateBaby, baby) end
	end
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
local carveCard, renderCarve = makeToggleCard(gameplayPage, 169, "AUTO CARVE", "Continuously trace the local UnionPart mask")

new("Frame", {
	Position = UDim2.fromOffset(0, 239), Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = Color3.fromRGB(54, 59, 79), BackgroundTransparency = 0.35, BorderSizePixel = 0,
}, gameplayPage)
new("TextLabel", {
	Position = UDim2.fromOffset(2, 251), Size = UDim2.new(1, -4, 0, 18), BackgroundTransparency = 1,
	Text = "SABOTAGE", TextColor3 = Color3.fromRGB(237, 117, 151), TextSize = 9,
	Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
}, gameplayPage)

local targetBox = new("TextBox", {
	Position = UDim2.fromOffset(0, 274), Size = UDim2.new(1, 0, 0, 36),
	BackgroundColor3 = Color3.fromRGB(25, 28, 41), BorderSizePixel = 0,
	PlaceholderText = "Search players...", PlaceholderColor3 = Color3.fromRGB(104, 109, 131),
	Text = "", TextColor3 = Color3.fromRGB(228, 231, 243), TextSize = 10,
	Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
}, gameplayPage)
corner(targetBox, 9)
stroke(targetBox, Color3.fromRGB(65, 70, 92), 0.4)
new("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 38)}, targetBox)

local selectedHeadshot = new("ImageLabel", {
	Position = UDim2.new(1, -31, 0, 278), Size = UDim2.fromOffset(27, 27),
	BackgroundColor3 = Color3.fromRGB(41, 44, 59), BorderSizePixel = 0,
	Image = "", ZIndex = 4,
}, gameplayPage)
corner(selectedHeadshot, 20)

local targetResults = new("ScrollingFrame", {
	Position = UDim2.fromOffset(0, 313), Size = UDim2.new(1, 0, 0, 130),
	BackgroundColor3 = Color3.fromRGB(18, 20, 30), BorderSizePixel = 0,
	CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 3, ScrollBarImageColor3 = Color3.fromRGB(112, 89, 235),
	Visible = false, ZIndex = 20,
}, gameplayPage)
corner(targetResults, 10)
stroke(targetResults, Color3.fromRGB(80, 73, 119), 0.25)
local targetLayout = new("UIListLayout", {
	Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
}, targetResults)
new("UIPadding", {
	PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5),
	PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5),
}, targetResults)

local selectedTargetLabel = new("TextLabel", {
	Position = UDim2.fromOffset(2, 316), Size = UDim2.new(1, -4, 0, 20), BackgroundTransparency = 1,
	Text = "NO TARGET SELECTED", TextColor3 = Color3.fromRGB(116, 121, 143), TextSize = 8,
	Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
}, gameplayPage)

local barrierCard, renderBarrier = makeToggleCard(gameplayPage, 342, "REMOVE BARRIERS", "Hide the target's Walls and Offlimits")
local lockCard, renderLock = makeToggleCard(gameplayPage, 408, "COOKIE LOCK", "Lay flat and remain locked over Main")
local breakCard, renderBreak = makeToggleCard(gameplayPage, 474, "BREAK COOKIE", "Continuously click the target's Main")

local refreshTargetResults
local setSelectedTarget
local applyBarrierState
local releaseCookieLock
local startBreakLoop
local removedBarriers = {}
local lockedHumanoid = nil
local barrierMutating = false
local suppressTargetRefresh = false

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

local function targetShapeModel(target)
	if not target then return nil end
	local honeycomb = honeycombRoot()
	local shapes = honeycomb and honeycomb:FindFirstChild("Shapes")
	return shapes and shapes:FindFirstChild(target.Name) or nil
end

local function targetMain(target)
	local model = targetShapeModel(target)
	local mainPart = model and model:FindFirstChild("Main", true)
	return mainPart and mainPart:IsA("BasePart") and mainPart or nil
end

local function restoreBarriers()
	barrierMutating = true
	for index = #removedBarriers, 1, -1 do
		local record = removedBarriers[index]
		if record.instance and record.parent and record.parent.Parent then
			record.instance.Parent = record.parent
		end
		table.remove(removedBarriers, index)
	end
	barrierMutating = false
end

applyBarrierState = function()
	restoreBarriers()
	if not state.barriersRemoved or not state.selectedTarget then return end
	local model = targetShapeModel(state.selectedTarget)
	if not model then
		setStatus("SABOTAGE • TARGET COOKIE MISSING", Color3.fromRGB(242, 175, 85))
		return
	end
	for _, name in {"Walls", "Offlimits"} do
		local object = model:FindFirstChild(name, true)
		if object then
			table.insert(removedBarriers, {instance = object, parent = object.Parent})
			object.Parent = nil
		end
	end
	setStatus("SABOTAGE • BARRIERS REMOVED", Color3.fromRGB(237, 117, 151))
end

releaseCookieLock = function()
	if lockedHumanoid and lockedHumanoid.Parent then
		lockedHumanoid.PlatformStand = false
		lockedHumanoid.AutoRotate = true
	end
	lockedHumanoid = nil
end

local function updateCookieLock()
	if not state.cookieLock then return end
	local mainPart = targetMain(state.selectedTarget)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not mainPart or not root or not humanoid then return end
	lockedHumanoid = humanoid
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	local position = mainPart.Position + Vector3.new(0, CONFIG.CookieLockHeight, 0)
	local flatFacing = Vector3.new(mainPart.CFrame.LookVector.X, 0, mainPart.CFrame.LookVector.Z)
	if flatFacing.Magnitude < 0.01 then flatFacing = Vector3.new(0, 0, -1) end
	root.CFrame = CFrame.lookAt(position, position + flatFacing.Unit) * CFrame.Angles(0, 0, math.rad(90))
end

local function findShapeUnder(door, wanted)
	local object = door:FindFirstChild(wanted, true)
	return object
end

local function worldPosition(object)
	if object:IsA("BasePart") then return object.Position end
	if object:IsA("Model") then return object:GetPivot().Position end
	local part = object:FindFirstChildWhichIsA("BasePart", true)
	return part and part.Position or nil
end

local function moveToDoor(door, shapeInstance)
	if shapeInstance == state.lastMovedShapeInstance then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local shapePosition = worldPosition(shapeInstance)
	if not root or not shapePosition then
		setStatus("DOOR FOUND • POSITION UNKNOWN", Color3.fromRGB(242, 175, 85))
		return
	end
	local offset = CONFIG.ShapeStandingOffset
	local destination = Vector3.new(
		shapePosition.X + offset.X,
		root.Position.Y,
		shapePosition.Z + offset.Z
	)
	state.lastMovedShapeInstance = shapeInstance
	root.CFrame = CFrame.lookAt(
		destination,
		Vector3.new(shapePosition.X, destination.Y, shapePosition.Z)
	)
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
	local mask = model and model:FindFirstChild("_path")
	if mask and mask:IsA("UnionOperation") then return model, mask end
	return model, nil
end

local function mouseMove(x, y)
	VirtualInputManager:SendMouseMoveEvent(x, y, game)
end

local function mouseButton(x, y, down)
	VirtualInputManager:SendMouseButtonEvent(x, y, 0, down, game, 0)
end

local function projectedBounds(part, camera)
	local half = part.Size * 0.5
	local minimum = Vector2.new(math.huge, math.huge)
	local maximum = Vector2.new(-math.huge, -math.huge)
	local anyVisible = false

	for _, x in {-half.X, half.X} do
		for _, y in {-half.Y, half.Y} do
			for _, z in {-half.Z, half.Z} do
				local world = part.CFrame:PointToWorldSpace(Vector3.new(x, y, z))
				local screen, visible = camera:WorldToViewportPoint(world)
				if screen.Z > 0 then
					anyVisible = anyVisible or visible
					minimum = Vector2.new(math.min(minimum.X, screen.X), math.min(minimum.Y, screen.Y))
					maximum = Vector2.new(math.max(maximum.X, screen.X), math.max(maximum.Y, screen.Y))
				end
			end
		end
	end

	if not anyVisible then return nil end
	local viewport = camera.ViewportSize
	return Vector2.new(
		math.clamp(math.floor(minimum.X) - 2, 0, viewport.X),
		math.clamp(math.floor(minimum.Y) - 2, 0, viewport.Y)
	), Vector2.new(
		math.clamp(math.ceil(maximum.X) + 2, 0, viewport.X),
		math.clamp(math.ceil(maximum.Y) + 2, 0, viewport.Y)
	)
end

local function screenHitsMask(camera, mask, x, y, raycastParams)
	local ray = camera:ViewportPointToRay(x, y)
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 2048, raycastParams)
	return result and result.Instance == mask
end

local function buildMaskRuns(mask, camera)
	local minimum, maximum = projectedBounds(mask, camera)
	if not minimum then return {} end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {mask}
	params.IgnoreWater = true

	local runs = {}
	local reverse = false
	for y = minimum.Y, maximum.Y, CONFIG.CarveRowStep do
		local row = {}
		for x = minimum.X, maximum.X, CONFIG.CarvePixelStep do
			if screenHitsMask(camera, mask, x, y, params) then
				table.insert(row, Vector2.new(x, y))
			elseif #row > 0 then
				if reverse then
					local reversed = {}
					for index = #row, 1, -1 do table.insert(reversed, row[index]) end
					row = reversed
				end
				table.insert(runs, row)
				reverse = not reverse
				row = {}
			end
		end
		if #row > 0 then
			if reverse then
				local reversed = {}
				for index = #row, 1, -1 do table.insert(reversed, row[index]) end
				row = reversed
			end
			table.insert(runs, row)
			reverse = not reverse
		end
	end
	return runs
end

local function traceRuns(runs)
	local moved = 0
	for _, run in runs do
		if not state.autoCarve or state.destroyed then break end
		local first = run[1]
		mouseMove(first.X, first.Y)
		mouseButton(first.X, first.Y, true)
		for _, point in run do
			mouseMove(point.X, point.Y)
			moved += 1
			if moved % CONFIG.CarveYieldEvery == 0 then task.wait() end
		end
		local last = run[#run]
		mouseButton(last.X, last.Y, false)
	end
	return moved
end

local function carveLocalPath()
	if state.destroyed or not state.autoCarve or state.carving then return end
	local model, mask = findLocalPath()
	if not model or not mask or model == state.lastCarvedModel then return end

	state.carving = true
	setStatus("AUTO CARVE • READING MASK", Color3.fromRGB(116, 168, 255))

	local ok, movedOrError = pcall(function()
		local totalMoved = 0
		-- Give the carving camera/UI a moment to settle after the mask replicates.
		task.wait(0.2)
		mask.CanQuery = true
		for _ = 1, CONFIG.CarvePasses do
			if not state.autoCarve or not model.Parent or not mask.Parent then break end
			local camera = Workspace.CurrentCamera
			local runs = camera and buildMaskRuns(mask, camera) or {}
			if #runs == 0 then
				task.wait(0.15)
			else
				totalMoved += traceRuns(runs)
				task.wait(0.08)
			end
		end
		return totalMoved
	end)

	state.carving = false
	if ok and movedOrError > 0 then
		state.lastCarvedModel = model
		setStatus("AUTO CARVE • TRACE COMPLETE", Color3.fromRGB(74, 231, 157))
	else
		setStatus("AUTO CARVE • TRACE FAILED", Color3.fromRGB(255, 99, 119))
		if not ok then warn("[BunduAdmin] Auto Carve:", movedOrError) end
	end
end

local function queueCarve()
	if not state.autoCarve then return end
	task.delay(0.1, carveLocalPath)
end

local function targetMatchesFilter(candidate, filter)
	if candidate == player or not candidate.Team or candidate.Team.Name ~= "Player" then return false end
	filter = string.lower(filter or "")
	if filter == "" then return true end
	return string.find(string.lower(candidate.Name), filter, 1, true) ~= nil
		or string.find(string.lower(candidate.DisplayName), filter, 1, true) ~= nil
end

setSelectedTarget = function(target)
	restoreBarriers()
	releaseCookieLock()
	state.breakLoopToken += 1
	state.selectedTarget = target
	targetResults.Visible = false
	suppressTargetRefresh = true
	if not target then
		targetBox.Text = ""
		selectedTargetLabel.Text = "NO TARGET SELECTED"
		selectedHeadshot.Image = ""
		suppressTargetRefresh = false
		return
	end
	targetBox.Text = target.Name
	suppressTargetRefresh = false
	selectedTargetLabel.Text = "TARGET  •  " .. target.DisplayName .. "  (@" .. target.Name .. ")"
	setStatus("TARGET SELECTED • " .. target.Name:upper(), Color3.fromRGB(237, 117, 151))
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(target.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and state.selectedTarget == target then selectedHeadshot.Image = image end
	end)
	if state.barriersRemoved then task.defer(applyBarrierState) end
	if state.breakCookie then task.defer(startBreakLoop) end
end

refreshTargetResults = function()
	for _, child in targetResults:GetChildren() do
		if child:IsA("GuiButton") then child:Destroy() end
	end
	local candidates = {}
	for _, candidate in Players:GetPlayers() do
		if targetMatchesFilter(candidate, targetBox.Text) then table.insert(candidates, candidate) end
	end
	table.sort(candidates, function(a, b) return string.lower(a.Name) < string.lower(b.Name) end)

	for order, candidate in candidates do
		local row = new("TextButton", {
			Size = UDim2.new(1, -10, 0, 39), BackgroundColor3 = Color3.fromRGB(28, 31, 44),
			BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = order, ZIndex = 21,
		}, targetResults)
		corner(row, 8)
		local avatar = new("ImageLabel", {
			Position = UDim2.fromOffset(5, 4), Size = UDim2.fromOffset(31, 31),
			BackgroundColor3 = Color3.fromRGB(43, 46, 61), BorderSizePixel = 0, Image = "", ZIndex = 22,
		}, row)
		corner(avatar, 20)
		new("TextLabel", {
			Position = UDim2.fromOffset(44, 4), Size = UDim2.new(1, -49, 0, 16), BackgroundTransparency = 1,
			Text = candidate.DisplayName, TextColor3 = Color3.fromRGB(231, 233, 243), TextSize = 10,
			Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22,
		}, row)
		new("TextLabel", {
			Position = UDim2.fromOffset(44, 20), Size = UDim2.new(1, -49, 0, 14), BackgroundTransparency = 1,
			Text = "@" .. candidate.Name, TextColor3 = Color3.fromRGB(113, 118, 141), TextSize = 8,
			Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22,
		}, row)
		connect(row.MouseButton1Click, function() setSelectedTarget(candidate) end)
		task.spawn(function()
			local ok, image = pcall(function()
				return Players:GetUserThumbnailAsync(candidate.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
			end)
			if ok and avatar.Parent then avatar.Image = image end
		end)
	end
	targetResults.Visible = true
end

startBreakLoop = function()
	state.breakLoopToken += 1
	local token = state.breakLoopToken
	task.spawn(function()
		while not state.destroyed and state.breakCookie and token == state.breakLoopToken do
			local target = state.selectedTarget
			local mainPart = targetMain(target)
			if not target or not target.Parent then
				state.breakCookie = false
				renderBreak(false)
				setStatus("BREAK COOKIE • TARGET LEFT", Color3.fromRGB(242, 175, 85))
				break
			elseif mainPart then
				local detector = mainPart:FindFirstChildWhichIsA("ClickDetector", true)
				if detector and typeof(fireclickdetector) == "function" then
					pcall(fireclickdetector, detector)
				else
					local camera = Workspace.CurrentCamera
					local screen, visible = camera:WorldToViewportPoint(mainPart.Position)
					if visible and screen.Z > 0 then
						local x, y = math.floor(screen.X), math.floor(screen.Y)
						pcall(function()
							mouseMove(x, y)
							mouseButton(x, y, true)
							mouseButton(x, y, false)
						end)
					end
				end
			end
			task.wait(CONFIG.BreakClickInterval)
		end
	end)
end

connect(targetBox.Focused, refreshTargetResults)
connect(targetBox:GetPropertyChangedSignal("Text"), function()
	if not suppressTargetRefresh and targetBox:IsFocused() then refreshTargetResults() end
end)

connect(barrierCard.MouseButton1Click, function()
	if not state.selectedTarget then setStatus("SELECT A SABOTAGE TARGET", Color3.fromRGB(242, 175, 85)); return end
	state.barriersRemoved = not state.barriersRemoved
	renderBarrier(state.barriersRemoved)
	applyBarrierState()
	if not state.barriersRemoved then setStatus("SABOTAGE • BARRIERS RESTORED") end
end)

connect(lockCard.MouseButton1Click, function()
	if not state.selectedTarget then setStatus("SELECT A SABOTAGE TARGET", Color3.fromRGB(242, 175, 85)); return end
	state.cookieLock = not state.cookieLock
	renderLock(state.cookieLock)
	if state.cookieLock then
		setStatus("COOKIE LOCK • " .. state.selectedTarget.Name:upper(), Color3.fromRGB(237, 117, 151))
	else
		releaseCookieLock()
		setStatus("COOKIE LOCK RELEASED")
	end
end)

connect(breakCard.MouseButton1Click, function()
	if not state.selectedTarget then setStatus("SELECT A SABOTAGE TARGET", Color3.fromRGB(242, 175, 85)); return end
	state.breakCookie = not state.breakCookie
	renderBreak(state.breakCookie)
	state.breakLoopToken += 1
	if state.breakCookie then
		setStatus("BREAK COOKIE • ACTIVE", Color3.fromRGB(237, 117, 151))
		startBreakLoop()
	else
		setStatus("BREAK COOKIE • STOPPED")
	end
end)

connect(RunService.RenderStepped, updateCookieLock)
connect(Players.PlayerAdded, function()
	if targetResults.Visible then refreshTargetResults() end
end)
connect(Players.PlayerRemoving, function(leaving)
	if state.selectedTarget == leaving then
		state.barriersRemoved = false
		state.cookieLock = false
		state.breakCookie = false
		renderBarrier(false)
		renderLock(false)
		renderBreak(false)
		setSelectedTarget(nil)
	elseif targetResults.Visible then
		refreshTargetResults()
	end
end)

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
activateBaby = function(baby)
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
	if state.autoCarve and (object.Name == player.Name or object.Name == "_path") then queueCarve() end
	if state.barriersRemoved and not barrierMutating and (object.Name == "Walls" or object.Name == "Offlimits") then
		task.defer(applyBarrierState)
	end
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
	state.breakCookie = false
	state.cookieLock = false
	restoreBarriers()
	releaseCookieLock()
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	gui:Destroy()
end)

renderBaby(false)
renderMove(false)
renderCarve(false)
renderBarrier(false)
renderLock(false)
renderBreak(false)
renderShapes()
switchTab("Misc")
print("[BunduAdmin] Loaded")
