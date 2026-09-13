local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BabyAction")

print("AutoBaby started")

local enabled = false


-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "AutoBabyTester"
gui.ResetOnSpawn = false
gui.Parent = game:GetService("CoreGui")


local button = Instance.new("TextButton")
button.Size = UDim2.new(0,220,0,50)
button.Position = UDim2.new(0.5,-110,0.8,0)
button.BackgroundColor3 = Color3.fromRGB(40,40,40)
button.TextColor3 = Color3.fromRGB(255,255,255)
button.Text = "Auto Baby: OFF"
button.Active = true
button.Parent = gui


-- Drag system
local UserInputService = game:GetService("UserInputService")

local dragging = false
local dragStart
local startPos


button.InputBegan:Connect(function(input)

	if input.UserInputType == Enum.UserInputType.MouseButton1 
	or input.UserInputType == Enum.UserInputType.Touch then

		dragging = true
		dragStart = input.Position
		startPos = button.Position
	end

end)


button.InputChanged:Connect(function(input)

	if input.UserInputType == Enum.UserInputType.MouseMovement 
	or input.UserInputType == Enum.UserInputType.Touch then

		input.Changed:Connect(function()

			if dragging then

				local delta = input.Position - dragStart

				button.Position = UDim2.new(
					startPos.X.Scale,
					startPos.X.Offset + delta.X,
					startPos.Y.Scale,
					startPos.Y.Offset + delta.Y
				)

			end

		end)

	end

end)


button.InputEnded:Connect(function(input)

	if input.UserInputType == Enum.UserInputType.MouseButton1 
	or input.UserInputType == Enum.UserInputType.Touch then

		dragging = false

	end

end)



-- Toggle
button.MouseButton1Click:Connect(function()

	enabled = not enabled

	print("AutoBaby:", enabled)

	button.Text = enabled 
		and "Auto Baby: ON"
		or "Auto Baby: OFF"

end)



-- Pickup attempt
local function attemptPickup(baby)

	if not enabled then
		print("Baby found but disabled")
		return
	end


	print("Attempting pickup:", baby.Name)

	task.wait(0.3)


	local trigger = baby:FindFirstChild("Trigger")
	local prompt = trigger and trigger:FindFirstChild("PickupPrompt")


	if not trigger then
		print("No Trigger found")
		return
	end


	if not prompt then
		print("No PickupPrompt found")
		return
	end


	print("PickupPrompt found")


	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:FindFirstChild("HumanoidRootPart")


	if not root then
		print("No HumanoidRootPart")
		return
	end


	-- Move near baby
	root.CFrame = trigger.CFrame + Vector3.new(0,3,0)

	task.wait(0.5)


	print("Sending BabyAction")

	remote:FireServer()

	print("Pickup requested")

end



-- Detect dropped baby
workspace.ChildAdded:Connect(function(obj)

	print("Workspace added:", obj.Name)


	if obj.Name == "BabyPickup" then

		print("Baby detected")

		attemptPickup(obj)

	end

end)
