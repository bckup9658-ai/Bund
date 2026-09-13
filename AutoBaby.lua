local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remote = ReplicatedStorage.Remotes.BabyAction

local enabled = false


-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "AutoBabyTester"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")


local button = Instance.new("TextButton")
button.Size = UDim2.new(0,220,0,50)
button.Position = UDim2.new(0.5,-110,0.8,0)
button.BackgroundColor3 = Color3.fromRGB(40,40,40)
button.TextColor3 = Color3.fromRGB(255,255,255)
button.Text = "Auto Baby: OFF"
button.Parent = gui


button.MouseButton1Click:Connect(function()
	enabled = not enabled

	button.Text = enabled
		and "Auto Baby: ON"
		or "Auto Baby: OFF"
end)


local function attemptPickup(baby)
	if not enabled then return end

	print("Baby detected:", baby)

	task.wait(0.2)

	local trigger = baby:FindFirstChild("Trigger")
	local prompt = trigger and trigger:FindFirstChild("PickupPrompt")

	if prompt then
		print("Pickup prompt found")

		local character = player.Character or player.CharacterAdded:Wait()
		local root = character:FindFirstChild("HumanoidRootPart")

		if root and trigger then
			root.CFrame = trigger.CFrame + Vector3.new(0,3,0)

			task.wait(0.5)

			remote:FireServer()

			print("Pickup requested")
		end
	end
end


workspace.ChildAdded:Connect(function(obj)
	if obj.Name == "BabyPickup" then
		attemptPickup(obj)
	end
end)
