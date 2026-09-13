local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "AutoBabyUI"
gui.ResetOnSpawn = false
gui.Parent = player.PlayerGui


local main = Instance.new("Frame")
main.Size = UDim2.new(0,320,0,180)
main.Position = UDim2.new(0.5,-160,0.5,-90)
main.BackgroundColor3 = Color3.fromRGB(25,25,25)
main.Active = true
main.Parent = gui


local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0,15)
corner.Parent = main


local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,-20,0,40)
title.Position = UDim2.new(0,10,0,5)
title.BackgroundTransparency = 1
title.Text = "👶 Auto Baby"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main


local status = Instance.new("TextLabel")
status.Size = UDim2.new(1,-20,0,30)
status.Position = UDim2.new(0,10,0,55)
status.BackgroundTransparency = 1
status.Text = "Status: OFF"
status.TextColor3 = Color3.fromRGB(200,200,200)
status.Font = Enum.Font.Gotham
status.TextSize = 15
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = main


local toggle = Instance.new("TextButton")
toggle.Size = UDim2.new(0,220,0,45)
toggle.Position = UDim2.new(0.5,-110,0,100)
toggle.BackgroundColor3 = Color3.fromRGB(180,50,50)
toggle.Text = "OFF"
toggle.TextColor3 = Color3.fromRGB(255,255,255)
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 18
toggle.Parent = main


local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0,10)
toggleCorner.Parent = toggle


local enabled = false

toggle.MouseButton1Click:Connect(function()

	enabled = not enabled

	if enabled then
		toggle.Text = "ON"
		toggle.BackgroundColor3 = Color3.fromRGB(50,180,80)
		status.Text = "Status: Active"
	else
		toggle.Text = "OFF"
		toggle.BackgroundColor3 = Color3.fromRGB(180,50,50)
		status.Text = "Status: Disabled"
	end

end)


-- Dragging
local dragging = false
local dragStart
local startPos

main.InputBegan:Connect(function(input)

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = main.Position
	end

end)


UserInputService.InputChanged:Connect(function(input)

	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then

		local delta = input.Position - dragStart

		main.Position = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)

	end

end)


UserInputService.InputEnded:Connect(function(input)

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end

end)


print("UI loaded")
