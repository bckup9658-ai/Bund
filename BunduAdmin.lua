-- BunduAdmin.lua
-- Complete client UI
--
-- Misc:
--   Auto Baby
--   Hitbox Expander
--   Low-Health Escape + Return
--
-- Gameplay:
--   Honeycomb / Auto Carve
--   Sabotage
--   RLGL Auto Walk
--   Glass Vision
--
-- Settings survive closing and re-execution in the same session.
-- Preferred Door remains visual-only.
-- Client actions depend on the game's server behavior.

--==================================================
-- SERVICES / SESSION SETTINGS
--==================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
assert(player, "BunduAdmin must run on the client.")

local playerGui = player:WaitForChild("PlayerGui")
local environment = (typeof(getgenv) == "function" and getgenv()) or shared
local SETTINGS_KEY = "__BunduAdminSettingsV1"

local VIM
pcall(function()
	VIM = game:GetService("VirtualInputManager")
end)

-- Destroying the previous version saves its settings first.
for _, name in ipairs({
	"BunduAdminUI",
	"AutoBabyAdminUI",
	"AutoBabyUI",
}) do
	local previous = playerGui:FindFirstChild(name)
	if previous then
		previous:Destroy()
	end
end

local remembered = environment[SETTINGS_KEY]

local S = {
	closed = false,
	minimized = false,

	baby = false,
	hitboxes = false,
	hitboxSize = 10,

	escape = false,
	threshold = 25,
	armed = false,

	carve = false,
	carving = false,
	carveToken = 0,

	shape = "Circle",
	target = nil,
	barriers = false,
	lock = false,
	breaking = false,

	walk = false,
	glass = false,
}

local CONFIG = {
	CarvePasses = 6,
	ClickDuration = 0.035,
	BreakInterval = 0.15,
	ArrivalDistance = 8,

	GlassQueryInterval = 0.05,
	GlassOverlayTransparency = 0.18,
	BadGlassColor = Color3.fromRGB(255, 15, 35),
	GoodGlassColor = Color3.fromRGB(20, 255, 65),
}

local connections = {}
local healthConnections = {}
local widgets = {}

local detached = {}
local hitboxOriginals = {}
local promptOriginals = {}

local savedReturn
local trackedCharacter
local trackedHumanoid
local walkingHumanoid
local lockSnapshot

local escapeBusy = false
local clickBusy = false
local mouseHeld = false
local inputEpoch = 0
local mouseX, mouseY = 0, 0

local checkHealth
local startCarve
local refreshTargets
local selectTarget

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function disconnectAll(list)
	for _, connection in ipairs(list) do
		connection:Disconnect()
	end
	table.clear(list)
end

local function characterParts()
	local character = player.Character
	if not character then
		return nil, nil, nil
	end

	return character,
		character:FindFirstChildOfClass("Humanoid"),
		character:FindFirstChild("HumanoidRootPart")
end

local function findPath(root, ...)
	for _, name in ipairs({...}) do
		root = root and root:FindFirstChild(name)
	end
	return root
end

local function eligible(other)
	return other ~= nil
		and other ~= player
		and other.Parent == Players
		and other.Team ~= nil
		and other.Team.Name == "Player"
end

local function cookie(other)
	return other and findPath(
		Workspace, "Map", "Honeycomb", "Shapes", other.Name
	)
end

local function targetMain()
	local model = cookie(S.target)
	local main = model and model:FindFirstChild("Main", true)

	if main and main:IsA("BasePart") then
		return main
	end
end

--==================================================
-- UI HELPERS
--==================================================

local C = {
	Background = Color3.fromRGB(16, 18, 27),
	Panel = Color3.fromRGB(25, 28, 41),
	Card = Color3.fromRGB(34, 38, 54),
	Accent = Color3.fromRGB(132, 108, 255),
	Enabled = Color3.fromRGB(35, 101, 77),
	Text = Color3.fromRGB(238, 240, 250),
	Muted = Color3.fromRGB(160, 168, 193),
}

local function make(class, properties, parent)
	local object = Instance.new(class)
	for key, value in pairs(properties) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function round(object, radius)
	make("UICorner", {
		CornerRadius = UDim.new(0, radius or 9),
	}, object)
end

local function text(parent, value, size, color)
	return make("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size or 12,
		TextColor3 = color or C.Text,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
end

local gui = make("ScreenGui", {
	Name = "BunduAdminUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 999,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local overlayFolder = make("Folder", {
	Name = "GlassOverlays",
}, gui)

local window = make("Frame", {
	Size = UDim2.fromOffset(470, 490),
	Position = UDim2.new(0.5, -235, 0.5, -245),
	BackgroundColor3 = C.Background,
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, gui)
round(window, 13)

make("UIStroke", {
	Color = Color3.fromRGB(75, 68, 107),
	Thickness = 1,
}, window)

local accent = make("Frame", {
	Size = UDim2.new(1, 0, 0, 3),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
}, window)

make("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(92, 185, 255)),
		ColorSequenceKeypoint.new(1, C.Accent),
	}),
}, accent)

local header = make("Frame", {
	Size = UDim2.new(1, -80, 0, 52),
	BackgroundTransparency = 1,
	Active = true,
}, window)

local title = text(header, "BUNDU  /  ADMIN", 16)
title.Position = UDim2.fromOffset(15, 10)
title.Size = UDim2.fromOffset(300, 20)
title.Font = Enum.Font.GothamBold

local subtitle = text(header, "MISC  •  GAMEPLAY  •  UTILITIES", 9, C.Muted)
subtitle.Position = UDim2.fromOffset(16, 32)
subtitle.Size = UDim2.fromOffset(320, 14)

local function headerButton(value, x)
	local button = make("TextButton", {
		Position = UDim2.fromOffset(x, 12),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = C.Card,
		BorderSizePixel = 0,
		Text = value,
		TextColor3 = C.Text,
		TextSize = 18,
		Font = Enum.Font.GothamBold,
	}, window)
	round(button, 7)
	return button
end

local minimizeButton = headerButton("−", 399)
local closeButton = headerButton("×", 433)

local body = make("Frame", {
	Position = UDim2.fromOffset(10, 58),
	Size = UDim2.fromOffset(450, 398),
	BackgroundTransparency = 1,
}, window)

local status = text(window, "Ready", 10, C.Muted)
status.Position = UDim2.fromOffset(15, 463)
status.Size = UDim2.fromOffset(440, 19)

local function setStatus(message)
	if not S.closed then
		status.Text = message
	end
end

local pages, tabs = {}, {}

for index, name in ipairs({"Misc", "Gameplay"}) do
	local tab = make("TextButton", {
		Position = UDim2.fromOffset(0, (index - 1) * 43),
		Size = UDim2.fromOffset(101, 36),
		BackgroundColor3 = C.Card,
		BorderSizePixel = 0,
		Text = name,
		TextSize = 12,
		TextColor3 = C.Text,
		Font = Enum.Font.GothamBold,
	}, body)
	round(tab, 8)
	tabs[name] = tab

	local page = make("ScrollingFrame", {
		Name = name,
		Position = UDim2.fromOffset(112, 0),
		Size = UDim2.fromOffset(338, 398),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.Accent,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = index == 1,
	}, body)

	make("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, page)

	make("UIPadding", {
		PaddingBottom = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 8),
	}, page)

	pages[name] = page
end

local function switchPage(name)
	for key, page in pairs(pages) do
		page.Visible = key == name
		tabs[key].BackgroundColor3 = key == name and C.Accent or C.Card
	end
end

for name, tab in pairs(tabs) do
	connect(tab.Activated, function()
		switchPage(name)
	end)
end

local order = 0

local function row(parent, height, color)
	order += 1

	local frame = make("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = color or C.Card,
		BorderSizePixel = 0,
		LayoutOrder = order,
	}, parent)

	round(frame, 9)
	return frame
end

local function section(parent, value)
	local frame = row(parent, 27, C.Background)
	local label = text(frame, value, 12, C.Accent)
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
end

local function note(parent, value)
	local frame = row(parent, 32, C.Background)
	local label = text(frame, value, 10, C.Muted)
	label.Size = UDim2.fromScale(1, 1)
	label.TextWrapped = true
	return label
end

local function addButton(parent, value, callback)
	order += 1

	local button = make("TextButton", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = C.Card,
		BorderSizePixel = 0,
		Text = value,
		TextColor3 = C.Text,
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		LayoutOrder = order,
	}, parent)

	round(button, 8)
	connect(button.Activated, callback)
	return button
end

local function addToggle(parent, headingText, description, callback)
	local frame = row(parent, 59)

	local button = make("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
	}, frame)

	local heading = text(frame, headingText, 11)
	heading.Position = UDim2.fromOffset(12, 8)
	heading.Size = UDim2.new(1, -65, 0, 20)
	heading.Font = Enum.Font.GothamBold

	local detail = text(frame, description, 9, C.Muted)
	detail.Position = UDim2.fromOffset(12, 32)
	detail.Size = UDim2.new(1, -20, 0, 16)

	local indicator = text(frame, "OFF", 10)
	indicator.Position = UDim2.new(1, -43, 0, 10)
	indicator.Size = UDim2.fromOffset(36, 20)

	local value = false
	local api = {}

	function api.Set(enabled)
		value = enabled
		frame.BackgroundColor3 = enabled and C.Enabled or C.Card
		indicator.Text = enabled and "ON" or "OFF"
	end

	connect(button.Activated, function()
		local requested = not value
		local result = callback(requested)

		if typeof(result) == "boolean" then
			api.Set(result)
		else
			api.Set(requested)
		end
	end)

	return api
end

local function addSlider(parent, heading, minimum, maximum, initial, callback)
	local frame = row(parent, 63)

	local caption = text(frame, "", 11)
	caption.Position = UDim2.fromOffset(12, 6)
	caption.Size = UDim2.new(1, -24, 0, 20)

	local track = make("TextButton", {
		Position = UDim2.fromOffset(12, 35),
		Size = UDim2.new(1, -24, 0, 17),
		BackgroundColor3 = Color3.fromRGB(53, 58, 80),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
	}, frame)
	round(track, 9)

	local fill = make("Frame", {
		BackgroundColor3 = C.Accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, track)
	round(fill, 9)

	local value = initial
	local dragging = false
	local touch
	local api = {}

	local function paint()
		local span = maximum - minimum
		fill.Size = UDim2.fromScale(
			span > 0 and (value - minimum) / span or 0, 1
		)
		caption.Text = heading .. "  •  " .. value
	end

	function api.SetValue(newValue)
		value = math.clamp(
			math.floor((tonumber(newValue) or minimum) + 0.5),
			minimum,
			maximum
		)
		paint()
		return value
	end

	function api.SetMaximum(newMaximum)
		maximum = math.max(minimum, math.floor(newMaximum))
		return api.SetValue(value)
	end

	local function move(x)
		if track.AbsoluteSize.X <= 0 then return end

		local fraction = math.clamp(
			(x - track.AbsolutePosition.X) / track.AbsoluteSize.X,
			0,
			1
		)

		api.SetValue(minimum + fraction * (maximum - minimum))
		callback(value)
	end

	connect(track.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then

			dragging = true
			touch = input.UserInputType == Enum.UserInputType.Touch and input or nil
			move(input.Position.X)
		end
	end)

	connect(UIS.InputChanged, function(input)
		if dragging and (
			(touch and input == touch)
			or (not touch and input.UserInputType == Enum.UserInputType.MouseMovement)
		) then
			move(input.Position.X)
		end
	end)

	connect(UIS.InputEnded, function(input)
		if input == touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then

			dragging = false
			touch = nil
		end
	end)

	paint()
	return api
end

--==================================================
-- CLICK INPUT
--==================================================

local function releaseMouse()
	if not mouseHeld then return end
	mouseHeld = false

	if VIM then
		pcall(function()
			VIM:SendMouseButtonEvent(mouseX, mouseY, 0, false, game, 0)
		end)
	end
end

local function cancelInput()
	inputEpoch += 1
	releaseMouse()
end

local function projectedTarget(part)
	local camera = Workspace.CurrentCamera

	if not camera or not part:IsDescendantOf(Workspace) then
		return nil
	end

	local point, visible = camera:WorldToViewportPoint(part.Position)
	if not visible or point.Z <= 0 then return nil end

	local x, y = math.floor(point.X), math.floor(point.Y)

	for _, object in ipairs(playerGui:GetGuiObjectsAtPosition(x, y)) do
		if object:IsDescendantOf(gui) then
			return nil
		end
	end

	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances =
		player.Character and {player.Character} or {}

	local ray = camera:ViewportPointToRay(x, y)
	local hit = Workspace:Raycast(
		ray.Origin,
		ray.Direction * (point.Z + 100),
		parameters
	)

	if not hit or hit.Instance ~= part then
		return nil
	end

	return x, y
end

local function clickPart(part, active)
	if clickBusy or not active() or not part.Parent then
		return false
	end

	clickBusy = true
	local epoch = inputEpoch

	local function valid()
		return not S.closed
			and epoch == inputEpoch
			and part.Parent ~= nil
			and active()
	end

	local ok, result = pcall(function()
		local detector = part:FindFirstChildWhichIsA("ClickDetector", true)

		if detector and typeof(fireclickdetector) == "function" then
			if not valid() then return false end
			fireclickdetector(detector)
			task.wait(CONFIG.ClickDuration)
			return true
		end

		if not VIM then return false end

		local x, y = projectedTarget(part)
		if not x then return false end

		VIM:SendMouseMoveEvent(x, y, game)
		RunService.RenderStepped:Wait()

		if not valid() then return false end

		local newX, newY = projectedTarget(part)
		if not newX
			or math.abs(newX - x) > 1
			or math.abs(newY - y) > 1 then
			return false
		end

		mouseX, mouseY = newX, newY
		mouseHeld = true
		VIM:SendMouseButtonEvent(mouseX, mouseY, 0, true, game, 0)

		task.wait(CONFIG.ClickDuration)
		releaseMouse()
		return true
	end)

	releaseMouse()
	clickBusy = false

	if not ok then
		setStatus("Click input failed: " .. tostring(result))
		return false
	end

	return result == true
end

--==================================================
-- RESTORABLE LOCAL CHANGES
--==================================================

local function restorePrompts()
	for prompt, original in pairs(promptOriginals) do
		pcall(function()
			prompt.MaxActivationDistance = original.Distance
			prompt.HoldDuration = original.Hold
			prompt.RequiresLineOfSight = original.Sight
		end)
	end
	table.clear(promptOriginals)
end

local function restoreHitbox(part)
	local original = hitboxOriginals[part]
	if not original then return end

	pcall(function()
		part.Size = original.Size
		part.Transparency = original.Transparency
		part.CanCollide = original.CanCollide
		part.Massless = original.Massless
	end)

	hitboxOriginals[part] = nil
end

local function restoreHitboxes()
	local parts = {}
	for part in pairs(hitboxOriginals) do
		table.insert(parts, part)
	end
	for _, part in ipairs(parts) do
		restoreHitbox(part)
	end
end

local function restoreBarriers()
	for object, parent in pairs(detached) do
		pcall(function()
			if object.Parent == nil and parent.Parent then
				object.Parent = parent
			end
		end)
	end
	table.clear(detached)
end

local function applyBarriers()
	if not S.barriers or not eligible(S.target) then return end

	local model = cookie(S.target)
	if not model then return end

	for _, name in ipairs({"Walls", "Offlimits"}) do
		local object = model:FindFirstChild(name, true)

		if object and not detached[object] then
			detached[object] = object.Parent
			object.Parent = nil
		end
	end
end

local function releaseLock()
	local snapshot = lockSnapshot
	lockSnapshot = nil

	if not snapshot then return end

	pcall(function()
		if snapshot.Humanoid.Parent then
			snapshot.Humanoid.PlatformStand = snapshot.PlatformStand
			snapshot.Humanoid.AutoRotate = snapshot.AutoRotate
		end

		if snapshot.Root.Parent then
			local root = snapshot.Root
			root.CFrame = CFrame.lookAt(
				root.Position,
				root.Position + snapshot.Facing
			)
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end

local function stopSabotage()
	S.lock = false
	S.breaking = false

	if widgets.lock then widgets.lock.Set(false) end
	if widgets.breaking then widgets.breaking.Set(false) end

	releaseLock()
	cancelInput()
end

local WALK_BINDING = "BunduAdmin_RLGL_AutoWalk"

local function stopWalk(message)
	S.walk = false
	RunService:UnbindFromRenderStep(WALK_BINDING)

	if walkingHumanoid and walkingHumanoid.Parent then
		walkingHumanoid:Move(Vector3.zero, false)
	end

	walkingHumanoid = nil

	if widgets.walk then widgets.walk.Set(false) end
	if message then setStatus(message) end
end

local function pauseActions()
	stopWalk()

	S.carve = false
	S.carveToken += 1
	if widgets.carve then widgets.carve.Set(false) end

	stopSabotage()

	local _, humanoid = characterParts()
	if humanoid then
		humanoid:Move(Vector3.zero, false)
	end
end

--==================================================
-- MISC: AUTO BABY
--==================================================

local lastBabyFire = 0

local function tryBaby()
	if S.closed or not S.baby or player:GetAttribute("IsGuard") then
		return
	end

	local baby = Workspace:FindFirstChild("BabyPickup")
	local prompt = baby and baby:FindFirstChild("PickupPrompt", true)

	if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then
		return
	end

	if typeof(fireproximityprompt) ~= "function" then
		setStatus("Auto Baby: fireproximityprompt unavailable")
		return
	end

	if os.clock() - lastBabyFire < 0.2 then return end
	lastBabyFire = os.clock()

	if not promptOriginals[prompt] then
		promptOriginals[prompt] = {
			Distance = prompt.MaxActivationDistance,
			Hold = prompt.HoldDuration,
			Sight = prompt.RequiresLineOfSight,
		}
	end

	local ok, err = pcall(function()
		prompt.MaxActivationDistance = 100000
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
		fireproximityprompt(prompt)
	end)

	if not ok then
		setStatus("Auto Baby: " .. tostring(err))
	end
end

section(pages.Misc, "MISC")

widgets.baby = addToggle(
	pages.Misc,
	"AUTO BABY",
	"Attempts pickup when BabyPickup appears",
	function(enabled)
		S.baby = enabled

		if enabled then
			task.defer(tryBaby)
		else
			restorePrompts()
		end

		return enabled
	end
)

--==================================================
-- MISC: HITBOXES
--==================================================

local function updateHitboxes()
	if not S.hitboxes then return end

	local current = {}

	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local character = other.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")

			if humanoid and humanoid.Health > 0
				and root and root:IsA("BasePart") then

				current[root] = true

				if not hitboxOriginals[root] then
					hitboxOriginals[root] = {
						Size = root.Size,
						Transparency = root.Transparency,
						CanCollide = root.CanCollide,
						Massless = root.Massless,
					}
				end

				root.Size = Vector3.new(
					S.hitboxSize,
					S.hitboxSize,
					S.hitboxSize
				)
				root.Transparency = 0.85
				root.CanCollide = false
				root.Massless = true
			end
		end
	end

	local stale = {}
	for part in pairs(hitboxOriginals) do
		if not current[part] then
			table.insert(stale, part)
		end
	end

	for _, part in ipairs(stale) do
		restoreHitbox(part)
	end
end

widgets.hitboxes = addToggle(
	pages.Misc,
	"HITBOX EXPANDER",
	"Local root size • restores original properties on OFF",
	function(enabled)
		S.hitboxes = enabled

		if enabled then
			updateHitboxes()
		else
			restoreHitboxes()
		end

		return enabled
	end
)

local hitboxSlider = addSlider(
	pages.Misc,
	"Hitbox size / studs",
	1,
	100,
	S.hitboxSize,
	function(value)
		S.hitboxSize = value
		updateHitboxes()
	end
)

--==================================================
-- MISC: LOW-HEALTH ESCAPE / RETURN
--==================================================

section(pages.Misc, "SAFE TELEPORT")

local escapeInfo
local returnButton
local thresholdSlider

local function refreshReturn()
	local valid = savedReturn and savedReturn.Character == player.Character

	returnButton.Text = valid
		and "RETURN TO SAVED POSITION"
		or "RETURN • NO SAVED POSITION"

	returnButton.TextTransparency = valid and 0 or 0.5
end

local function safeDestination(character, humanoid, root, platform)
	local cf, size = platform.CFrame, platform.Size

	local top = (
		math.abs(cf.RightVector.Y) * size.X
		+ math.abs(cf.UpVector.Y) * size.Y
		+ math.abs(cf.LookVector.Y) * size.Z
	) / 2

	local clearance = humanoid.HipHeight + root.Size.Y / 2 + 0.75

	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		local leg = character:FindFirstChild("Left Leg")
		clearance += leg and leg.Size.Y or 2
	end

	local position = platform.Position + Vector3.new(0, top + clearance, 0)
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)

	if flat.Magnitude < 0.001 then
		flat = Vector3.new(0, 0, -1)
	end

	local destinationRoot = CFrame.lookAt(position, position + flat.Unit)
	return destinationRoot * root.CFrame:ToObjectSpace(character:GetPivot())
end

checkHealth = function()
	if S.closed or not S.escape or escapeBusy then return end

	local character, humanoid, root = characterParts()
	if not humanoid or not root then return end

	if humanoid.Health <= 0 then
		escapeInfo.Text = "Cannot escape after death"
		return
	end

	if humanoid.Health > S.threshold then
		S.armed = true
		escapeInfo.Text = "Armed • escape at " .. S.threshold .. " HP"
		return
	end

	if not S.armed then
		escapeInfo.Text = "Paused • heal above threshold or toggle off/on"
		return
	end

	local platform = findPath(
		Workspace, "Data", "CharacterEditor", "Platform"
	)

	if not platform or not platform:IsA("BasePart") then
		escapeInfo.Text = "Waiting for safe platform"
		return
	end

	escapeBusy = true
	local previous = character:GetPivot()

	local ok, err = pcall(function()
		pauseActions()

		character:PivotTo(
			safeDestination(character, humanoid, root, platform)
		)

		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end)

	if ok then
		savedReturn = {
			Character = character,
			Pivot = previous,
		}

		S.armed = false
		escapeInfo.Text = "Teleported • Return position saved"
		refreshReturn()
	else
		escapeInfo.Text = "Escape failed"
		warn("[BunduAdmin] Escape:", err)
	end

	escapeBusy = false
end

widgets.escape = addToggle(
	pages.Misc,
	"LOW-HEALTH ESCAPE",
	"Saves your position before moving to the platform",
	function(enabled)
		S.escape = enabled
		S.armed = enabled

		if enabled then
			checkHealth()
		else
			escapeInfo.Text = "Escape OFF"
		end

		return enabled
	end
)

thresholdSlider = addSlider(
	pages.Misc,
	"Escape threshold / HP",
	1,
	100,
	S.threshold,
	function(value)
		S.threshold = value
		checkHealth()
	end
)

returnButton = addButton(
	pages.Misc,
	"RETURN • NO SAVED POSITION",
	function()
		if escapeBusy or not savedReturn then return end

		local character, humanoid, root = characterParts()

		if character ~= savedReturn.Character
			or not humanoid
			or not root
			or humanoid.Health <= 0 then

			setStatus("Return unavailable for this character")
			return
		end

		escapeBusy = true

		local ok, err = pcall(function()
			pauseActions()
			character:PivotTo(savedReturn.Pivot)
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end)

		if ok then
			S.armed = S.escape and humanoid.Health > S.threshold
			escapeInfo.Text = S.armed
				and "Returned • escape armed"
				or "Returned • escape waits for healing or off/on"
		else
			escapeInfo.Text = "Return failed"
			warn("[BunduAdmin] Return:", err)
		end

		escapeBusy = false
	end
)

escapeInfo = note(pages.Misc, "Escape OFF")
refreshReturn()

--==================================================
-- GAMEPLAY: HONEYCOMB
--==================================================

section(pages.Gameplay, "HONEYCOMB")

local shapeButtons = {}
local shapeRow = row(pages.Gameplay, 35, C.Background)

make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 4),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, shapeRow)

for index, name in ipairs({
	"Circle", "Star", "Umbrella", "Square", "Triangle",
}) do
	local button = make("TextButton", {
		Size = UDim2.new(0.2, -4, 1, 0),
		BackgroundColor3 = name == S.shape and C.Accent or C.Card,
		BorderSizePixel = 0,
		Text = name,
		TextSize = 9,
		TextColor3 = C.Text,
		Font = Enum.Font.GothamBold,
		LayoutOrder = index,
	}, shapeRow)

	round(button, 7)
	shapeButtons[name] = button

	connect(button.Activated, function()
		S.shape = name

		for shape, control in pairs(shapeButtons) do
			control.BackgroundColor3 =
				shape == name and C.Accent or C.Card
		end

		setStatus("Preferred shape: " .. name .. " • functionality paused")
	end)
end

note(
	pages.Gameplay,
	"Preferred Door is paused. Shape selection does not teleport."
)

local carveInfo
local carveQueued = false
local carvePending = false

local function carvePath()
	local model = cookie(player)
	return model, model and model:FindFirstChild("Path")
end

local function queueCarve()
	if S.closed or not S.carve then return end

	if S.carving then
		carvePending = true
		return
	end

	if carveQueued then return end
	carveQueued = true

	task.delay(0.25, function()
		carveQueued = false

		if not S.closed and S.carve then
			startCarve()
		end
	end)
end

startCarve = function()
	if S.closed or not S.carve then return end

	if S.carving then
		carvePending = true
		return
	end

	local model, path = carvePath()

	if not path then
		carveInfo.Text = "Waiting for your cookie's Path"
		return
	end

	S.carving = true
	S.carveToken += 1
	carvePending = false

	local token = S.carveToken

	stopSabotage()
	stopWalk()

	local function active()
		return not S.closed
			and S.carve
			and token == S.carveToken
			and cookie(player) == model
			and path:IsDescendantOf(Workspace)
	end

	task.spawn(function()
		local attempts, skipped = 0, 0

		local ok, err = pcall(function()
			for pass = 1, CONFIG.CarvePasses do
				if not active() then break end

				local parts = {}

				if path:IsA("BasePart") then
					table.insert(parts, path)
				end

				for _, object in ipairs(path:GetDescendants()) do
					if object:IsA("BasePart") then
						table.insert(parts, object)
					end
				end

				if #parts == 0 then break end

				for _, part in ipairs(parts) do
					if not active() then break end

					if part == path or part:IsDescendantOf(path) then
						if clickPart(part, active) then
							attempts += 1
						else
							skipped += 1
						end
					end

					RunService.Heartbeat:Wait()
				end

				if not S.closed then
					carveInfo.Text = string.format(
						"Pass %d/%d • %d attempts • %d skipped",
						pass,
						CONFIG.CarvePasses,
						attempts,
						skipped
					)
				end

				task.wait(0.08)
			end
		end)

		releaseMouse()
		S.carving = false

		if S.closed then return end

		if not ok then
			carveInfo.Text = "Carve error • see Output"
			warn("[BunduAdmin] Carve:", err)
		elseif active() then
			carveInfo.Text = string.format(
				"%d attempts • %d skipped • Retry if needed",
				attempts,
				skipped
			)
		end

		if carvePending and S.carve then
			carvePending = false
			queueCarve()
		end
	end)
end

widgets.carve = addToggle(
	pages.Gameplay,
	"AUTO CARVE",
	"Clicks Path parts • no character or camera movement",
	function(enabled)
		S.carve = enabled
		S.carveToken += 1

		if enabled then
			queueCarve()
		else
			carvePending = false
			cancelInput()
			carveInfo.Text = "Auto Carve OFF"
		end

		return enabled
	end
)

addButton(pages.Gameplay, "RETRY CURRENT PATH", function()
	if S.carving then
		setStatus("A carving pass is already running")
		return
	end

	S.carve = true
	widgets.carve.Set(true)
	queueCarve()
end)

carveInfo = note(
	pages.Gameplay,
	"Idle • obscured or off-screen parts may be skipped"
)

--==================================================
-- GAMEPLAY: SABOTAGE
--==================================================

section(pages.Gameplay, "SABOTAGE")

local picker = row(pages.Gameplay, 38)

local search = make("TextBox", {
	Position = UDim2.fromOffset(10, 3),
	Size = UDim2.new(1, -20, 1, -6),
	BackgroundTransparency = 1,
	Text = "",
	PlaceholderText = "Search Player team...",
	PlaceholderColor3 = C.Muted,
	TextColor3 = C.Text,
	TextSize = 11,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
	ClearTextOnFocus = false,
}, picker)

local results = row(pages.Gameplay, 145, C.Panel)
results.Visible = false

local resultList = make("ScrollingFrame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, results)

make("UIListLayout", {
	Padding = UDim.new(0, 4),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, resultList)

local selectedLabel = note(pages.Gameplay, "No player selected")
local thumbnailCache = {}
local resultGeneration = 0

selectTarget = function(other)
	stopSabotage()
	restoreBarriers()

	S.target = eligible(other) and other or nil

	selectedLabel.Text = S.target
		and (S.target.DisplayName .. "  @" .. S.target.Name)
		or "No player selected"

	if S.barriers then applyBarriers() end

	results.Visible = false
	search:ReleaseFocus()
end

refreshTargets = function()
	if S.closed or not results.Visible then return end

	resultGeneration += 1
	local generation = resultGeneration

	for _, object in ipairs(resultList:GetChildren()) do
		if object:IsA("GuiObject") then
			object:Destroy()
		end
	end

	local query = string.lower(search.Text)
	local matches = {}

	for _, other in ipairs(Players:GetPlayers()) do
		if eligible(other) and (
			query == ""
			or string.find(string.lower(other.Name), query, 1, true)
			or string.find(string.lower(other.DisplayName), query, 1, true)
		) then
			table.insert(matches, other)
		end
	end

	table.sort(matches, function(a, b)
		return string.lower(a.Name) < string.lower(b.Name)
	end)

	for index, other in ipairs(matches) do
		local button = make("TextButton", {
			Size = UDim2.new(1, -5, 0, 42),
			BackgroundColor3 = C.Card,
			BorderSizePixel = 0,
			Text = "",
			LayoutOrder = index,
		}, resultList)
		round(button, 7)

		local avatar = make("ImageLabel", {
			Position = UDim2.fromOffset(4, 3),
			Size = UDim2.fromOffset(36, 36),
			BackgroundTransparency = 1,
			Image = thumbnailCache[other.UserId] or "",
		}, button)
		round(avatar, 18)

		local nameLabel = text(
			button,
			other.DisplayName .. "  @" .. other.Name,
			10
		)
		nameLabel.Position = UDim2.fromOffset(48, 0)
		nameLabel.Size = UDim2.new(1, -52, 1, 0)

		button.Activated:Connect(function()
			selectTarget(other)
		end)

		if not thumbnailCache[other.UserId] then
			task.spawn(function()
				local ok, image = pcall(function()
					return Players:GetUserThumbnailAsync(
						other.UserId,
						Enum.ThumbnailType.HeadShot,
						Enum.ThumbnailSize.Size100x100
					)
				end)

				if ok then
					thumbnailCache[other.UserId] = image

					if not S.closed
						and generation == resultGeneration
						and avatar.Parent then
						avatar.Image = image
					end
				end
			end)
		end
	end
end

connect(search.Focused, function()
	results.Visible = true
	refreshTargets()
end)

connect(search:GetPropertyChangedSignal("Text"), refreshTargets)

connect(search.FocusLost, function()
	task.delay(0.2, function()
		if not S.closed and not search:IsFocused() then
			results.Visible = false
		end
	end)
end)

widgets.barriers = addToggle(
	pages.Gameplay,
	"REMOVE WALLS / LIMITS",
	"Local removal • restores on OFF or target change",
	function(enabled)
		if enabled and not eligible(S.target) then
			setStatus("Select a player first")
			return false
		end

		S.barriers = enabled

		if enabled then
			applyBarriers()
		else
			restoreBarriers()
		end

		return enabled
	end
)

widgets.lock = addToggle(
	pages.Gameplay,
	"LOCK OVER COOKIE",
	"Lies over selected Main • OFF releases you",
	function(enabled)
		if enabled and (not eligible(S.target) or not targetMain()) then
			setStatus("Selected cookie is unavailable")
			return false
		end

		if enabled and (S.carve or S.carving) then
			setStatus("Turn Auto Carve off first")
			return false
		end

		S.lock = enabled

		if enabled then
			stopWalk()
		else
			releaseLock()
		end

		return enabled
	end
)

widgets.breaking = addToggle(
	pages.Gameplay,
	"CLICK SELECTED COOKIE",
	"Repeated Main clicks • game decides the result",
	function(enabled)
		if enabled and (not eligible(S.target) or not targetMain()) then
			setStatus("Selected cookie is unavailable")
			return false
		end

		if enabled and (S.carve or S.carving) then
			setStatus("Turn Auto Carve off first")
			return false
		end

		S.breaking = enabled

		if not enabled then
			cancelInput()
		end

		return enabled
	end
)

--==================================================
-- GAMEPLAY: RLGL
--==================================================

section(pages.Gameplay, "RED LIGHT GREEN LIGHT")

local walkInfo
local GREEN = Color3.fromRGB(85, 255, 0)

local function greenLight(light)
	if not light or not light:IsA("PointLight") or not light.Enabled then
		return false
	end

	local color = light.Color
	local tolerance = 0.5 / 255

	return math.abs(color.R - GREEN.R) <= tolerance
		and math.abs(color.G - GREEN.G) <= tolerance
		and math.abs(color.B - GREEN.B) <= tolerance
end

local function objectPosition(object)
	if not object then return nil end

	if object:IsA("BasePart") then
		return object.Position
	elseif object:IsA("Model") then
		return object:GetPivot().Position
	end

	local part = object:FindFirstChildWhichIsA("BasePart", true)
	return part and part.Position
end

local function updateWalk()
	if S.closed or not S.walk then return end

	local _, humanoid, root = characterParts()

	if not humanoid or not root or humanoid.Health <= 0 then
		stopWalk()
		walkInfo.Text = "Stopped • character unavailable"
		return
	end

	if walkingHumanoid and walkingHumanoid ~= humanoid
		and walkingHumanoid.Parent then
		walkingHumanoid:Move(Vector3.zero, false)
	end

	walkingHumanoid = humanoid

	local function pause(message)
		humanoid:Move(Vector3.zero, false)

		if walkInfo.Text ~= message then
			walkInfo.Text = message
		end
	end

	if S.lock or S.carving then
		pause("Paused • another action is active")
		return
	end

	local arena = findPath(
		Workspace, "Map", "RedLightGreenLight", "Map"
	)

	local destination = objectPosition(
		arena and arena:FindFirstChild("Girl")
	)

	local light = findPath(arena, "PointLight", "PointLight")

	if not destination then
		pause("Waiting for RLGL map")
		return
	end

	local delta = destination - root.Position
	local horizontal = Vector3.new(delta.X, 0, delta.Z)

	if horizontal.Magnitude <= CONFIG.ArrivalDistance then
		stopWalk()
		walkInfo.Text = "Arrived • Auto Walk OFF"
		return
	end

	if not greenLight(light) then
		pause("Stopped • light is not green")
		return
	end

	if player:GetAttribute("DISABLE_MOVEMENT")
		or player:GetAttribute("CarryStatus") then

		pause("Paused • movement unavailable")
		return
	end

	humanoid:Move(horizontal.Unit, false)
	walkInfo.Text = "Green • walking"
end

widgets.walk = addToggle(
	pages.Gameplay,
	"RLGL AUTO WALK",
	"Green only • automatically turns off near Girl",
	function(enabled)
		if enabled then
			S.walk = true

			RunService:BindToRenderStep(
				WALK_BINDING,
				Enum.RenderPriority.Character.Value + 2,
				updateWalk
			)
		else
			stopWalk()
			walkInfo.Text = "Auto Walk OFF"
		end

		return enabled
	end
)

walkInfo = note(
	pages.Gameplay,
	"Idle • follows the light visible on your client"
)

--==================================================
-- GAMEPLAY: GLASS VISION
--==================================================

section(pages.Gameplay, "GLASS BRIDGE")

local glassInfo
local glassContainer
local glassEpoch = 0
local glassBusy = false

-- Instance keys, not pane names, distinguish replacement panes.
local glassResults = {}
local glassOverlays = {}

local function clearGlassOverlays()
	for _, overlay in pairs(glassOverlays) do
		overlay:Destroy()
	end

	table.clear(glassOverlays)
	table.clear(glassResults)
end

local function resetGlass()
	glassEpoch += 1
	glassContainer = nil
	clearGlassOverlays()
end

local function findGlasses()
	local map = Workspace:FindFirstChild("Map")
	if not map then return nil end

	-- The supplied module uses p9.map.Glasses.
	-- Find the replicated Glasses container without assuming
	-- the gamemode's outer folder name.
	return map:FindFirstChild("Glasses", true)
end

local function paintGlass(part, bad)
	local overlay = glassOverlays[part]

	if not overlay or not overlay.Parent then
		overlay = make("BoxHandleAdornment", {
			Name = "BunduGlassOverlay",
			Adornee = part,
			AlwaysOnTop = true,
			ZIndex = 5,
			CFrame = CFrame.new(),
			Size = part.Size + Vector3.new(0.035, 0.035, 0.035),
			Transparency = CONFIG.GlassOverlayTransparency,
			Color3 = bad and CONFIG.BadGlassColor or CONFIG.GoodGlassColor,
			Visible = true,
		}, overlayFolder)

		glassOverlays[part] = overlay
	else
		overlay.Color3 = bad and CONFIG.BadGlassColor or CONFIG.GoodGlassColor
		overlay.Size = part.Size + Vector3.new(0.035, 0.035, 0.035)
	end
end

local function updateGlassSummary()
	if S.closed or not S.glass then return end

	local bad, good, unknown = 0, 0, 0

	for part, result in pairs(glassResults) do
		if part.Parent == glassContainer then
			if result == true then
				bad += 1
			elseif result == false then
				good += 1
			else
				unknown += 1
			end
		end
	end

	glassInfo.Text = string.format(
		"Red: %d • Green: %d • Unknown: %d%s",
		bad,
		good,
		unknown,
		glassBusy and " • scanning" or ""
	)
end

local function scanGlass()
	if S.closed or not S.glass then return end

	local container = findGlasses()

	if container ~= glassContainer then
		resetGlass()
		glassContainer = container
	end

	if not container then
		glassInfo.Text = "Waiting for the Glasses container"
		return
	end

	-- Remove overlays for broken/replaced panes.
	local stale = {}

	for part, overlay in pairs(glassOverlays) do
		if part.Parent ~= container then
			table.insert(stale, part)
		elseif overlay.Parent then
			overlay.Size = part.Size + Vector3.new(0.035, 0.035, 0.035)
		end
	end

	for _, part in ipairs(stale) do
		glassOverlays[part]:Destroy()
		glassOverlays[part] = nil
		glassResults[part] = nil
	end

	for part in pairs(glassResults) do
		if part.Parent ~= container then
			glassResults[part] = nil
		end
	end

	-- Never run multiple scans concurrently.
	if glassBusy then return end

	local remote = findPath(ReplicatedStorage, "Remotes", "GlassPass")

	if not remote or not remote:IsA("RemoteFunction") then
		glassInfo.Text = "Waiting for Remotes.GlassPass"
		return
	end

	local pending = {}

	for _, pane in ipairs(container:GetChildren()) do
		if pane:IsA("BasePart") and glassResults[pane] == nil then
			table.insert(pending, pane)
		end
	end

	if #pending == 0 then
		updateGlassSummary()
		return
	end

	table.sort(pending, function(a, b)
		return a.Name < b.Name
	end)

	glassBusy = true
	local epoch = glassEpoch

	local function active()
		return not S.closed
			and S.glass
			and epoch == glassEpoch
			and container == glassContainer
			and container:IsDescendantOf(Workspace)
	end

	updateGlassSummary()

	task.spawn(function()
		local workerOK, workerError = pcall(function()
			for _, pane in ipairs(pending) do
				if not active() then break end

				if pane.Parent == container then
					local requestedName = pane.Name

					local ok, result = pcall(function()
						return remote:InvokeServer(requestedName)
					end)

					-- A response from an old scan cannot recreate overlays.
					if not active() then break end

					if pane.Parent == container and pane.Name == requestedName then
						if ok and typeof(result) == "boolean" then
							glassResults[pane] = result
							paintGlass(pane, result)
						else
							-- No default green on errors/nil/non-boolean responses.
							glassResults[pane] = "unknown"
						end
					end

					updateGlassSummary()
					task.wait(CONFIG.GlassQueryInterval)
				end
			end
		end)

		glassBusy = false

		if S.closed then return end

		if not workerOK then
			setStatus("Glass Vision error • see Output")
			warn("[BunduAdmin] Glass Vision:", workerError)
		end

		if active() then
			updateGlassSummary()
		end
	end)
end

widgets.glass = addToggle(
	pages.Gameplay,
	"GLASS VISION",
	"Bright red / green overlays • visible through objects",
	function(enabled)
		S.glass = enabled
		resetGlass()

		if enabled then
			scanGlass()
		else
			glassInfo.Text = "Glass Vision OFF"
		end

		return enabled
	end
)

addButton(pages.Gameplay, "REFRESH GLASS RESULTS", function()
	S.glass = true
	widgets.glass.Set(true)

	resetGlass()
	scanGlass()
end)

glassInfo = note(pages.Gameplay, "Glass Vision OFF")

note(
	pages.Gameplay,
	"Red = flagged bad. Green = false response. Unknown panes stay unmarked."
)

--==================================================
-- CHARACTER / WORLD MAINTENANCE
--==================================================

local function trackCharacter()
	local character, humanoid = characterParts()

	if character ~= trackedCharacter then
		trackedCharacter = character
		savedReturn = nil
		refreshReturn()

		S.armed = S.escape
		stopWalk()
		stopSabotage()

		S.carveToken += 1

		if S.carve then
			carvePending = true
		end
	end

	if humanoid == trackedHumanoid then return end

	disconnectAll(healthConnections)
	trackedHumanoid = humanoid

	if not humanoid then return end

	local function updateMaximum()
		S.threshold = thresholdSlider.SetMaximum(humanoid.MaxHealth)
		checkHealth()
	end

	table.insert(
		healthConnections,
		humanoid.HealthChanged:Connect(checkHealth)
	)

	table.insert(
		healthConnections,
		humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(updateMaximum)
	)

	updateMaximum()
end

local lastPath
local maintenanceTime = 0
local nextBreak = 0

connect(RunService.Heartbeat, function(dt)
	if S.closed then return end

	if S.lock then
		local main = targetMain()
		local _, humanoid, root = characterParts()

		if not eligible(S.target)
			or not main
			or not humanoid
			or humanoid.Health <= 0
			or not root then

			stopSabotage()
		else
			if not lockSnapshot or lockSnapshot.Root ~= root then
				releaseLock()

				local look = root.CFrame.LookVector
				local facing = Vector3.new(look.X, 0, look.Z)

				if facing.Magnitude < 0.001 then
					facing = Vector3.new(0, 0, -1)
				end

				lockSnapshot = {
					Root = root,
					Humanoid = humanoid,
					PlatformStand = humanoid.PlatformStand,
					AutoRotate = humanoid.AutoRotate,
					Facing = facing.Unit,
				}
			end

			local cf, size = main.CFrame, main.Size

			local halfHeight = (
				math.abs(cf.RightVector.Y) * size.X
				+ math.abs(cf.UpVector.Y) * size.Y
				+ math.abs(cf.LookVector.Y) * size.Z
			) / 2

			humanoid.PlatformStand = true
			humanoid.AutoRotate = false

			local position = main.Position + Vector3.new(
				0,
				halfHeight + root.Size.Z / 2 + 0.45,
				0
			)

			root.CFrame = CFrame.new(position)
				* CFrame.Angles(math.rad(90), 0, 0)

			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end

	if S.breaking
		and not clickBusy
		and not S.carving
		and os.clock() >= nextBreak then

		nextBreak = os.clock() + CONFIG.BreakInterval

		local selected = S.target
		local main = targetMain()

		if not eligible(selected) or not main then
			S.breaking = false
			widgets.breaking.Set(false)
		else
			task.spawn(function()
				clickPart(main, function()
					return not S.closed
						and S.breaking
						and S.target == selected
						and not S.carving
				end)
			end)
		end
	end

	maintenanceTime += dt
	if maintenanceTime < 0.2 then return end
	maintenanceTime = 0

	trackCharacter()
	tryBaby()
	updateHitboxes()
	checkHealth()

	if S.target and not eligible(S.target) then
		selectTarget(nil)
	end

	if S.barriers then
		applyBarriers()
	end

	if S.glass then
		scanGlass()
	end

	if S.carve then
		local _, path = carvePath()

		if path ~= lastPath then
			lastPath = path
			if path then queueCarve() end
		elseif carvePending and not S.carving then
			carvePending = false
			queueCarve()
		end
	else
		lastPath = nil
	end

	for prompt in pairs(promptOriginals) do
		if not prompt:IsDescendantOf(Workspace) then
			promptOriginals[prompt] = nil
		end
	end
end)

connect(Workspace.DescendantAdded, function(object)
	if S.baby and (
		object.Name == "BabyPickup"
		or object.Name == "PickupPrompt"
	) then
		task.defer(tryBaby)
	end

	if S.carve and (
		object.Name == "Path"
		or object:IsA("BasePart")
	) then
		local _, path = carvePath()

		if path and (object == path or object:IsDescendantOf(path)) then
			queueCarve()
		end
	end
end)

local function watchPlayer(other)
	connect(other:GetPropertyChangedSignal("Team"), function()
		if S.target == other and not eligible(other) then
			selectTarget(nil)
		end
		refreshTargets()
	end)
end

for _, other in ipairs(Players:GetPlayers()) do
	watchPlayer(other)
end

connect(Players.PlayerAdded, function(other)
	watchPlayer(other)
	refreshTargets()
end)

connect(Players.PlayerRemoving, function(other)
	if S.target == other then
		selectTarget(nil)
	end
	task.defer(refreshTargets)
end)

--==================================================
-- WINDOW CONTROLS
--==================================================

local function applyMinimized()
	body.Visible = not S.minimized
	status.Visible = not S.minimized
	subtitle.Visible = not S.minimized

	window.Size = UDim2.fromOffset(470, S.minimized and 48 or 490)
	minimizeButton.Text = S.minimized and "+" or "−"
end

connect(minimizeButton.Activated, function()
	S.minimized = not S.minimized
	applyMinimized()
end)

local dragging = false
local dragTouch
local dragStart
local windowStart

connect(header.InputBegan, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then

		dragging = true
		dragTouch = input.UserInputType == Enum.UserInputType.Touch and input or nil
		dragStart = input.Position
		windowStart = window.Position
	end
end)

connect(UIS.InputChanged, function(input)
	if not dragging then return end

	if (dragTouch and input == dragTouch)
		or (not dragTouch and input.UserInputType == Enum.UserInputType.MouseMovement) then

		local delta = input.Position - dragStart

		window.Position = UDim2.new(
			windowStart.X.Scale,
			windowStart.X.Offset + delta.X,
			windowStart.Y.Scale,
			windowStart.Y.Offset + delta.Y
		)
	end
end)

connect(UIS.InputEnded, function(input)
	if input == dragTouch
		or input.UserInputType == Enum.UserInputType.MouseButton1 then

		dragging = false
		dragTouch = nil
	end
end)

--==================================================
-- SAVE / CLEANUP
--==================================================

local function saveSettings()
	environment[SETTINGS_KEY] = {
		baby = S.baby,
		hitboxes = S.hitboxes,
		hitboxSize = S.hitboxSize,

		escape = S.escape,
		threshold = S.threshold,
		armed = S.armed,

		carve = S.carve,
		shape = S.shape,

		targetUserId = S.target and S.target.UserId or nil,
		barriers = S.barriers,
		lock = S.lock,
		breaking = S.breaking,

		walk = S.walk,
		glass = S.glass,
		minimized = S.minimized,

		windowPosition = window.Position,
		page = pages.Gameplay.Visible and "Gameplay" or "Misc",

		character = player.Character,
		returnPosition = savedReturn,
	}
end

local function cleanup()
	if S.closed then return end

	-- Snapshot enabled settings BEFORE stopping features.
	saveSettings()

	S.closed = true
	S.carve = false
	S.carveToken += 1
	S.breaking = false
	S.lock = false
	S.escape = false
	S.hitboxes = false
	S.baby = false
	S.glass = false

	carvePending = false

	stopWalk()
	cancelInput()
	releaseLock()

	restoreBarriers()
	restoreHitboxes()
	restorePrompts()
	resetGlass()

	disconnectAll(healthConnections)
	disconnectAll(connections)

	savedReturn = nil
end

connect(gui.Destroying, cleanup)

connect(closeButton.Activated, function()
	cleanup()
	gui:Destroy()
end)

--==================================================
-- RESTORE PREVIOUS SETTINGS
--==================================================

switchPage("Misc")
trackCharacter()

if typeof(remembered) == "table" then
	S.hitboxSize = hitboxSlider.SetValue(remembered.hitboxSize or 10)
	S.threshold = thresholdSlider.SetValue(remembered.threshold or 25)

	if typeof(remembered.shape) == "string" and shapeButtons[remembered.shape] then
		S.shape = remembered.shape
	end

	for shape, button in pairs(shapeButtons) do
		button.BackgroundColor3 =
			shape == S.shape and C.Accent or C.Card
	end

	local target

	if typeof(remembered.targetUserId) == "number" then
		target = Players:GetPlayerByUserId(remembered.targetUserId)
	end

	selectTarget(eligible(target) and target or nil)

	S.baby = remembered.baby == true
	S.hitboxes = remembered.hitboxes == true
	S.escape = remembered.escape == true
	S.carve = remembered.carve == true
	S.glass = remembered.glass == true

	S.barriers = remembered.barriers == true and S.target ~= nil

	S.lock = remembered.lock == true
		and S.target ~= nil
		and not S.carve

	S.breaking = remembered.breaking == true
		and S.target ~= nil
		and not S.carve

	S.walk = remembered.walk == true
		and not S.carve
		and not S.lock

	if remembered.character == player.Character then
		S.armed = S.escape and remembered.armed == true

		local previousReturn = remembered.returnPosition

		if typeof(previousReturn) == "table"
			and previousReturn.Character == player.Character
			and typeof(previousReturn.Pivot) == "CFrame" then
			savedReturn = previousReturn
		end
	else
		S.armed = S.escape
	end

	refreshReturn()

	for _, name in ipairs({
		"baby",
		"hitboxes",
		"escape",
		"carve",
		"barriers",
		"lock",
		"breaking",
		"walk",
		"glass",
	}) do
		widgets[name].Set(S[name])
	end

	if typeof(remembered.windowPosition) == "UDim2" then
		window.Position = remembered.windowPosition
	end

	if typeof(remembered.page) == "string" and pages[remembered.page] then
		switchPage(remembered.page)
	end

	S.minimized = remembered.minimized == true
	applyMinimized()

	if S.hitboxes then updateHitboxes() end
	if S.barriers then applyBarriers() end

	if S.walk then
		RunService:BindToRenderStep(
			WALK_BINDING,
			Enum.RenderPriority.Character.Value + 2,
			updateWalk
		)
	end

	-- Escape can cancel conflicting restored actions.
	checkHealth()

	if S.baby then task.defer(tryBaby) end
	if S.carve then queueCarve() end
	if S.glass then task.defer(scanGlass) end

	setStatus("Settings restored • Glass Vision available")
else
	setStatus("Ready • Glass Vision available")
end

print("[BunduAdmin] Loaded")