local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BabyAction")

print("AutoBaby Loaded")

local enabled = false


--------------------------------------------------
-- UI
--------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "AutoBabyUI"
gui.ResetOnSpawn = false
gui.Parent = game:GetService("CoreGui")


local main = Instance.new("Frame")
main.Size = UDim2.new(0,300,0,170)
main.Position = UDim2.new(0.5,-150,0.5,-85)
main.BackgroundColor3 = Color3.fromRGB(25,25,25)
main.BorderSizePixel = 0
main.Parent = gui


local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0,12)
corner.Parent = main


local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,-20,0,35)
title.Position = UDim2.new(0,10,0,5)
title.BackgroundTransparency = 1
title.Text = "👶 Auto Baby"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main


local status = Instance.new("TextLabel")
status.Size = UDim2.new(1,-20,0,30)
status.Position = UDim2.new(0,10,0,45)
status.BackgroundTransparency = 1
status.Text = "Status: Disabled"
status.TextColor3 = Color3.fromRGB(180,180,180)
status.Font = Enum.Font.Gotham
status.TextSize = 14
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = main



local toggle = Instance.new("TextButton")
toggle.Size = UDim2.new(0,200,0,45)
toggle.Position = UDim2.new(0.5,-100,0,90)
toggle.BackgroundColor3 = Color3.fromRGB(170,50,50)
toggle.Text = "OFF"
toggle.TextColor3 = Color3.fromRGB(255,255,255)
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 16
toggle.Parent = main


local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0,10)
toggleCorner.Parent = toggle



local close = Instance.new("TextButton")
close.Size = UDim2.new(0,30,0,30)
close.Position = UDim2.new(1,-35,0,5)
close.BackgroundTransparency = 1
close.Text = "✕"
close.TextColor3 = Color3.fromRGB(255,100,100)
close.Font = Enum.Font.GothamBold
close.TextSize = 18
close.Parent = main



local minimize = Instance.new("TextButton")
minimize.Size = UDim2.new(0,30,0,30)
minimize.Position = UDim2.new(1,-70,0,5)
minimize.BackgroundTransparency = 1
minimize.Text = "—"
minimize.TextColor3 = Color3.fromRGB(255,255,255)
minimize.Font = Enum.Font.GothamBold
minimize.TextSize = 18
minimize.Parent = main



--------------------------------------------------
-- Dragging
--------------------------------------------------

local dragging = false
local dragStart
local startPosition


main.InputBegan:Connect(function(input)

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



--------------------------------------------------
-- Controls
--------------------------------------------------

toggle.MouseButton1Click:Connect(function()

	enabled = not enabled


	if enabled then

		toggle.Text = "ON"
		toggle.BackgroundColor3 = Color3.fromRGB(50,170,80)
		status.Text = "Status: Waiting..."

	else

		toggle.Text = "OFF"
		toggle.BackgroundColor3 = Color3.fromRGB(170,50,50)
		status.Text = "Status: Disabled"

	end

end)



close.MouseButton1Click:Connect(function()
	gui:Destroy()
end)



local minimized = false

minimize.MouseButton1Click:Connect(function()

	minimized = not minimized

	if minimized then

		main.Size = UDim2.new(0,300,0,45)
		status.Visible = false
		toggle.Visible = false

	else

		main.Size = UDim2.new(0,300,0,170)
		status.Visible = true
		toggle.Visible = true

	end

end)



--------------------------------------------------
-- Baby Pickup
--------------------------------------------------

local function pickupBaby(baby)

	if not enabled then
		return
	end


	status.Text = "Status: Baby found"


	local trigger = baby:FindFirstChild("Trigger")
	local prompt = trigger and trigger:FindFirstChild("PickupPrompt")


	if prompt then

		status.Text = "Status: Picking up..."


		-- Instant prompt trigger
		pcall(function()
			fireproximityprompt(prompt,0)
		end)


		-- Retry request
		for i = 1,5 do

			remote:FireServer()

			task.wait(0.15)

		end


		status.Text = "Status: Pickup sent ✓"

	else

		status.Text = "Status: No prompt found"

	end

end



--------------------------------------------------
-- Detection
--------------------------------------------------

workspace.ChildAdded:Connect(function(obj)

	if obj.Name == "BabyPickup" then

		print("Baby detected")

		task.wait(0.05)

		pickupBaby(obj)

	end

end)
