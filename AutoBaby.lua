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
button.Parent = gui


button.MouseButton1Click:Connect(function()
	enabled = not enabled

	print("Button clicked")
	print("AutoBaby:", enabled)

	button.Text = enabled 
		and "Auto Baby: ON"
		or "Auto Baby: OFF"
end)


local function attemptPickup(baby)

	if not enabled then
		print("Baby found but AutoBaby is OFF")
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

	-- Same remote used by the original pickup script
	remote:FireServer()

	print("Pickup requested")
end


workspace.ChildAdded:Connect(function(obj)

	print("Workspace object added:", obj.Name)

	if obj.Name == "BabyPickup" then
		print("Baby detected!")
		attemptPickup(obj)
	end

end)
