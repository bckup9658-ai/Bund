```lua
-- AutoBaby.lua
-- Compact / draggable / minimizable Auto Baby UI

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remove previous version
local old = playerGui:FindFirstChild("AutoBabyUI")
if old then
	old:Destroy()
end

local enabled = false
local minimized = false
local destroyed = false

--==================================================
-- GUI
--==================================================

local gui = Instance.new("ScreenGui")
gui.Name = "AutoBabyUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(190, 92)
main.Position = UDim2.new(0.5, -95, 0.5, -46)
main.BackgroundColor3 = Color3.fromRGB(17, 18, 24)
main.BorderSizePixel = 0
main.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(55, 57, 68)
stroke.Thickness = 1
stroke.Parent = main

--==================================================
-- HEADER
--==================================================

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 34)
header.BackgroundTransparency = 1
header.Parent = main

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(12, 0)
title.Size = UDim2.new(1, -78, 1, 0)
title.Text = "AUTO BABY"
title.TextColor3 = Color3.fromRGB(240, 240, 245)
title.TextSize = 13
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

--==================================================
-- MINIMIZE
--==================================================

local minimize = Instance.new("TextButton")
minimize.BackgroundTransparency = 1
minimize.Position = UDim2.new(1, -57, 0, 2)
minimize.Size = UDim2.fromOffset(25, 28)
minimize.Text = "−"
minimize.TextColor3 = Color3.fromRGB(160, 162, 173)
minimize.TextSize = 18
minimize.Font = Enum.Font.GothamBold
minimize.Parent = header

--==================================================
-- CLOSE
--==================================================

local close = Instance.new("TextButton")
close.BackgroundTransparency = 1
close.Position = UDim2.new(1, -31, 0, 2)
close.Size = UDim2.fromOffset(25, 28)
close.Text = "×"
close.TextColor3 = Color3.fromRGB(160, 162, 173)
close.TextSize = 18
close.Font = Enum.Font.GothamBold
close.Parent = header

--==================================================
-- CONTENT
--==================================================

local content = Instance.new("Frame")
content.BackgroundTransparency = 1
content.Position = UDim2.fromOffset(10, 34)
content.Size = UDim2.new(1, -20, 0, 48)
content.Parent = main

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.new(1, 0, 1, 0)
toggle.BackgroundColor3 = Color3.fromRGB(38, 40, 49)
toggle.BorderSizePixel = 0
toggle.Text = ""
toggle.AutoButtonColor = false
toggle.Parent = content

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 8)
toggleCorner.Parent = toggle

local dot = Instance.new("Frame")
dot.Size = UDim2.fromOffset(7, 7)
dot.Position = UDim2.new(0, 12, 0.5, -3)
dot.BackgroundColor3 = Color3.fromRGB(115, 117, 128)
dot.BorderSizePixel = 0
dot.Parent = toggle

local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = dot

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Position = UDim2.fromOffset(28, 0)
status.Size = UDim2.new(1, -38, 1, 0)
status.Text = "AUTO BABY  •  OFF"
status.TextColor3 = Color3.fromRGB(185, 187, 198)
status.TextSize = 11
status.Font = Enum.Font.GothamBold
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = toggle

--==================================================
-- TOGGLE
--==================================================

local function updateUI()
	if enabled then
		toggle.BackgroundColor3 = Color3.fromRGB(30, 105, 65)
		status.TextColor3 = Color3.fromRGB(255, 255, 255)
		status.Text = "AUTO BABY  •  ON"
		dot.BackgroundColor3 = Color3.fromRGB(100, 255, 150)
	else
		toggle.BackgroundColor3 = Color3.fromRGB(38, 40, 49)
		status.TextColor3 = Color3.fromRGB(185, 187, 198)
		status.Text = "AUTO BABY  •  OFF"
		dot.BackgroundColor3 = Color3.fromRGB(115, 117, 128)
	end
end

toggle.MouseButton1Click:Connect(function()
	enabled = not enabled
	updateUI()
end)

--==================================================
-- MINIMIZE
--==================================================

minimize.MouseButton1Click:Connect(function()
	minimized = not minimized

	if minimized then
		content.Visible = false
		main.Size = UDim2.fromOffset(190, 34)
		minimize.Text = "+"
	else
		content.Visible = true
		main.Size = UDim2.fromOffset(190, 92)
		minimize.Text = "−"
	end
end)

--==================================================
-- CLOSE
--==================================================

close.MouseButton1Click:Connect(function()
	destroyed = true
	enabled = false
	gui:Destroy()
end)

--==================================================
-- DRAGGING
--==================================================

local dragging = false
local dragStart
local startPosition

header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPosition = main.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart

		main.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)

--==================================================
-- FIND BABY
--==================================================

local function findBabyPrompt()
	local baby = Workspace:FindFirstChild("BabyPickup")

	if not baby then
		return nil
	end

	local prompt = baby:FindFirstChild("PickupPrompt", true)

	if prompt and prompt:IsA("ProximityPrompt") then
		return prompt
	end

	return nil
end

--==================================================
-- AUTO PICKUP
--==================================================

task.spawn(function()
	local lastPrompt
	local lastFire = 0

	while not destroyed do
		if enabled then
			local prompt = findBabyPrompt()

			if prompt then
				if prompt ~= lastPrompt then
					lastPrompt = prompt
					print("[AutoBaby] Baby detected")
				end

				if prompt.Enabled and typeof(fireproximityprompt) == "function" then
					local now = os.clock()

					if now - lastFire >= 0.2 then
						lastFire = now
						fireproximityprompt(prompt)
					end
				end
			else
				lastPrompt = nil
			end
		end

		task.wait(0.05)
	end
end)

updateUI()

print("[AutoBaby] Loaded")
```
