local Players = game:GetService("Players")
local player = Players.LocalPlayer

print("AutoBaby loading...")


local gui = Instance.new("ScreenGui")
gui.Name = "AutoBabyUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")


local main = Instance.new("Frame")
main.Size = UDim2.new(0,300,0,150)
main.Position = UDim2.new(0.5,-150,0.5,-75)
main.BackgroundColor3 = Color3.fromRGB(30,30,30)
main.Active = true
main.Parent = gui


local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0,12)
corner.Parent = main


local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,40)
title.BackgroundTransparency = 1
title.Text = "👶 Auto Baby"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.Parent = main


local status = Instance.new("TextLabel")
status.Position = UDim2.new(0,0,0,45)
status.Size = UDim2.new(1,0,0,30)
status.BackgroundTransparency = 1
status.Text = "Status: OFF"
status.TextColor3 = Color3.fromRGB(200,200,200)
status.Font = Enum.Font.Gotham
status.TextSize = 15
status.Parent = main


local button = Instance.new("TextButton")
button.Size = UDim2.new(0,200,0,45)
button.Position = UDim2.new(0.5,-100,0,90)
button.BackgroundColor3 = Color3.fromRGB(170,50,50)
button.Text = "OFF"
button.TextColor3 = Color3.fromRGB(255,255,255)
button.Font = Enum.Font.GothamBold
button.TextSize = 18
button.Parent = main


local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0,10)
buttonCorner.Parent = button


local enabled = false


button.MouseButton1Click:Connect(function()

	enabled = not enabled

	if enabled then
		button.Text = "ON"
		button.BackgroundColor3 = Color3.fromRGB(50,170,80)
		status.Text = "Status: Enabled"
	else
		button.Text = "OFF"
		button.BackgroundColor3 = Color3.fromRGB(170,50,50)
		status.Text = "Status: Disabled"
	end

	print("AutoBaby:", enabled)

end)


-- Dragging
local UIS = game:GetService("UserInputService")

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


UIS.InputChanged:Connect(function(input)

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


UIS.InputEnded:Connect(function(input)

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end

end)


print("AutoBaby loaded successfully")
