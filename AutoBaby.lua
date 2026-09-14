-- AutoBabyAdmin.lua
-- Lightweight client-side admin utility for an owned Roblox experience.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GUI_NAME = "AutoBabyAdminUI"
local BABY_NAME = "BabyPickup"
local PROMPT_NAME = "PickupPrompt"
local REMOTE_DISTANCE = 100000
local RETRY_DELAY = 0.12

local previous = playerGui:FindFirstChild(GUI_NAME)
if previous then
	previous:Destroy()
end

local enabled = false
local minimized = false
local destroyed = false
local busy = false
local connections = {}

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function tween(object, properties, duration)
	TweenService:Create(
		object,
		TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		properties
	):Play()
end

local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999
gui.Parent = playerGui

local shadow = Instance.new("Frame")
shadow.Name = "Shadow"
shadow.AnchorPoint = Vector2.new(0.5, 0.5)
shadow.Position = UDim2.fromScale(0.5, 0.5)
shadow.Size = UDim2.fromOffset(238, 132)
shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shadow.BackgroundTransparency = 0.55
shadow.BorderSizePixel = 0
shadow.Parent = gui

local shadowCorner = Instance.new("UICorner")
shadowCorner.CornerRadius = UDim.new(0, 16)
shadowCorner.Parent = shadow

local main = Instance.new("Frame")
main.Name = "Window"
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.fromScale(0.5, 0.5)
main.Size = UDim2.fromOffset(230, 124)
main.BackgroundColor3 = Color3.fromRGB(14, 16, 24)
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(76, 88, 130)
mainStroke.Transparency = 0.25
mainStroke.Thickness = 1
mainStroke.Parent = main

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 29, 45)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 14, 21)),
})
gradient.Rotation = 115
gradient.Parent = main

local accent = Instance.new("Frame")
accent.Size = UDim2.new(1, 0, 0, 3)
accent.BackgroundColor3 = Color3.fromRGB(109, 92, 255)
accent.BorderSizePixel = 0
accent.Parent = main

local accentGradient = Instance.new("UIGradient")
accentGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(71, 210, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(126, 91, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 88, 191)),
})
accentGradient.Parent = accent

local header = Instance.new("Frame")
header.Name = "Header"
header.Active = true
header.Size = UDim2.new(1, 0, 0, 43)
header.BackgroundTransparency = 1
header.Parent = main

local icon = Instance.new("TextLabel")
icon.Position = UDim2.fromOffset(12, 9)
icon.Size = UDim2.fromOffset(25, 25)
icon.BackgroundColor3 = Color3.fromRGB(105, 86, 255)
icon.BorderSizePixel = 0
icon.Text = "B"
icon.TextColor3 = Color3.new(1, 1, 1)
icon.TextSize = 13
icon.Font = Enum.Font.GothamBold
icon.Parent = header

local iconCorner = Instance.new("UICorner")
iconCorner.CornerRadius = UDim.new(0, 7)
iconCorner.Parent = icon

local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(45, 6)
title.Size = UDim2.new(1, -112, 0, 19)
title.BackgroundTransparency = 1
title.Text = "AUTO BABY"
title.TextColor3 = Color3.fromRGB(244, 246, 255)
title.TextSize = 13
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.Position = UDim2.fromOffset(45, 22)
subtitle.Size = UDim2.new(1, -112, 0, 14)
subtitle.BackgroundTransparency = 1
subtitle.Text = "ADMIN UTILITY"
subtitle.TextColor3 = Color3.fromRGB(119, 124, 148)
subtitle.TextSize = 8
subtitle.Font = Enum.Font.GothamBold
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = header

local function makeHeaderButton(text, xOffset)
	local button = Instance.new("TextButton")
	button.Position = UDim2.new(1, xOffset, 0, 8)
	button.Size = UDim2.fromOffset(27, 27)
	button.BackgroundColor3 = Color3.fromRGB(31, 34, 48)
	button.BackgroundTransparency = 0.25
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = text
	button.TextColor3 = Color3.fromRGB(169, 174, 196)
	button.TextSize = 15
	button.Font = Enum.Font.GothamBold
	button.Parent = header

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 8)
	buttonCorner.Parent = button
	return button
end

local minimizeButton = makeHeaderButton("−", -66)
local closeButton = makeHeaderButton("×", -35)

local content = Instance.new("Frame")
content.Position = UDim2.fromOffset(10, 45)
content.Size = UDim2.new(1, -20, 0, 69)
content.BackgroundTransparency = 1
content.Parent = main

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.new(1, 0, 0, 48)
toggle.BackgroundColor3 = Color3.fromRGB(29, 32, 45)
toggle.BorderSizePixel = 0
toggle.AutoButtonColor = false
toggle.Text = ""
toggle.Parent = content

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 11)
toggleCorner.Parent = toggle

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Color = Color3.fromRGB(61, 66, 88)
toggleStroke.Transparency = 0.45
toggleStroke.Parent = toggle

local statusDot = Instance.new("Frame")
statusDot.Position = UDim2.fromOffset(13, 17)
statusDot.Size = UDim2.fromOffset(14, 14)
statusDot.BackgroundColor3 = Color3.fromRGB(104, 109, 130)
statusDot.BorderSizePixel = 0
statusDot.Parent = toggle

local statusDotCorner = Instance.new("UICorner")
statusDotCorner.CornerRadius = UDim.new(1, 0)
statusDotCorner.Parent = statusDot

local statusDotStroke = Instance.new("UIStroke")
statusDotStroke.Color = Color3.fromRGB(187, 191, 210)
statusDotStroke.Transparency = 0.55
statusDotStroke.Parent = statusDot

local statusTitle = Instance.new("TextLabel")
statusTitle.Position = UDim2.fromOffset(37, 7)
statusTitle.Size = UDim2.new(1, -88, 0, 18)
statusTitle.BackgroundTransparency = 1
statusTitle.Text = "AUTOMATION OFF"
statusTitle.TextColor3 = Color3.fromRGB(194, 198, 216)
statusTitle.TextSize = 11
statusTitle.Font = Enum.Font.GothamBold
statusTitle.TextXAlignment = Enum.TextXAlignment.Left
statusTitle.Parent = toggle

local statusDetail = Instance.new("TextLabel")
statusDetail.Position = UDim2.fromOffset(37, 24)
statusDetail.Size = UDim2.new(1, -88, 0, 15)
statusDetail.BackgroundTransparency = 1
statusDetail.Text = "Click to activate"
statusDetail.TextColor3 = Color3.fromRGB(116, 121, 143)
statusDetail.TextSize = 9
statusDetail.Font = Enum.Font.Gotham
statusDetail.TextXAlignment = Enum.TextXAlignment.Left
statusDetail.Parent = toggle

local switchTrack = Instance.new("Frame")
switchTrack.Position = UDim2.new(1, -53, 0.5, -11)
switchTrack.Size = UDim2.fromOffset(40, 22)
switchTrack.BackgroundColor3 = Color3.fromRGB(54, 58, 75)
switchTrack.BorderSizePixel = 0
switchTrack.Parent = toggle

local switchCorner = Instance.new("UICorner")
switchCorner.CornerRadius = UDim.new(1, 0)
switchCorner.Parent = switchTrack

local switchKnob = Instance.new("Frame")
switchKnob.Position = UDim2.fromOffset(3, 3)
switchKnob.Size = UDim2.fromOffset(16, 16)
switchKnob.BackgroundColor3 = Color3.fromRGB(214, 217, 231)
switchKnob.BorderSizePixel = 0
switchKnob.Parent = switchTrack

local switchKnobCorner = Instance.new("UICorner")
switchKnobCorner.CornerRadius = UDim.new(1, 0)
switchKnobCorner.Parent = switchKnob

local footer = Instance.new("TextLabel")
footer.Position = UDim2.fromOffset(3, 52)
footer.Size = UDim2.new(1, -6, 0, 13)
footer.BackgroundTransparency = 1
footer.Text = "READY  •  WAITING FOR BABY"
footer.TextColor3 = Color3.fromRGB(89, 94, 116)
footer.TextSize = 8
footer.Font = Enum.Font.GothamBold
footer.TextXAlignment = Enum.TextXAlignment.Left
footer.Parent = content

local function setFooter(text, color)
	if destroyed then return end
	footer.Text = text
	footer.TextColor3 = color or Color3.fromRGB(89, 94, 116)
end

local function updateUI()
	if enabled then
		statusTitle.Text = "AUTOMATION ON"
		statusDetail.Text = "Instant pickup armed"
		tween(toggle, { BackgroundColor3 = Color3.fromRGB(29, 49, 47) })
		tween(toggleStroke, { Color = Color3.fromRGB(66, 224, 157), Transparency = 0.25 })
		tween(statusDot, { BackgroundColor3 = Color3.fromRGB(72, 242, 159) })
		tween(switchTrack, { BackgroundColor3 = Color3.fromRGB(82, 209, 148) })
		tween(switchKnob, { Position = UDim2.fromOffset(21, 3) })
		statusTitle.TextColor3 = Color3.fromRGB(235, 255, 247)
		setFooter("ARMED  •  WATCHING WORKSPACE", Color3.fromRGB(84, 213, 157))
	else
		statusTitle.Text = "AUTOMATION OFF"
		statusDetail.Text = "Click to activate"
		tween(toggle, { BackgroundColor3 = Color3.fromRGB(29, 32, 45) })
		tween(toggleStroke, { Color = Color3.fromRGB(61, 66, 88), Transparency = 0.45 })
		tween(statusDot, { BackgroundColor3 = Color3.fromRGB(104, 109, 130) })
		tween(switchTrack, { BackgroundColor3 = Color3.fromRGB(54, 58, 75) })
		tween(switchKnob, { Position = UDim2.fromOffset(3, 3) })
		statusTitle.TextColor3 = Color3.fromRGB(194, 198, 216)
		setFooter("READY  •  WAITING FOR BABY")
	end
end

local function findPrompt(baby)
	if not baby or baby.Name ~= BABY_NAME then
		return nil
	end
	local prompt = baby:FindFirstChild(PROMPT_NAME, true)
	return prompt and prompt:IsA("ProximityPrompt") and prompt or nil
end

local function activateBaby(baby)
	if destroyed or not enabled or busy then return end

	local prompt = findPrompt(baby)
	if not prompt or not prompt.Enabled then
		setFooter("WAITING  •  PROMPT NOT READY", Color3.fromRGB(238, 181, 89))
		return
	end

	if typeof(fireproximityprompt) ~= "function" then
		setFooter("ERROR  •  PROMPT FIRE UNAVAILABLE", Color3.fromRGB(255, 103, 120))
		warn("[AutoBaby] fireproximityprompt is unavailable")
		return
	end

	busy = true
	prompt.MaxActivationDistance = REMOTE_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0

	setFooter("FOUND  •  PICKING UP...", Color3.fromRGB(120, 177, 255))

	local success, message = pcall(function()
		fireproximityprompt(prompt)
	end)

	if success then
		setFooter("SUCCESS  •  PROMPT ACTIVATED", Color3.fromRGB(84, 232, 157))
	else
		setFooter("ERROR  •  ACTIVATION FAILED", Color3.fromRGB(255, 103, 120))
		warn("[AutoBaby] " .. tostring(message))
	end

	task.delay(RETRY_DELAY, function()
		busy = false
	end)
end

local function scanForBaby()
	local baby = Workspace:FindFirstChild(BABY_NAME)
	if baby then
		activateBaby(baby)
	end
end

connect(toggle.MouseButton1Click, function()
	enabled = not enabled
	updateUI()
	if enabled then
		task.defer(scanForBaby)
	end
end)

connect(Workspace.ChildAdded, function(child)
	if enabled and child.Name == BABY_NAME then
		task.defer(activateBaby, child)
	end
end)

connect(minimizeButton.MouseButton1Click, function()
	minimized = not minimized
	content.Visible = not minimized
	minimizeButton.Text = minimized and "+" or "−"
	local targetSize = minimized and UDim2.fromOffset(230, 43) or UDim2.fromOffset(230, 124)
	local shadowSize = minimized and UDim2.fromOffset(238, 51) or UDim2.fromOffset(238, 132)
	tween(main, { Size = targetSize })
	tween(shadow, { Size = shadowSize })
end)

local dragging = false
local dragInput
local dragStart
local startPosition

connect(header.InputBegan, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPosition = main.Position

		local endedConnection
		endedConnection = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				endedConnection:Disconnect()
			end
		end)
	end
end)

connect(header.InputChanged, function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

connect(UserInputService.InputChanged, function(input)
	if dragging and input == dragInput then
		local delta = input.Position - dragStart
		local newPosition = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
		main.Position = newPosition
		shadow.Position = newPosition
	end
end)

connect(closeButton.MouseButton1Click, function()
	destroyed = true
	enabled = false
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	gui:Destroy()
end)

updateUI()
print("[AutoBaby] Admin utility loaded")
