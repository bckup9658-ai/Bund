```lua
-- AutoBaby.lua
-- Automatically attempts to pick up BabyPickup
-- Intended for your own Roblox test environment.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Enabled = false

--==================================================
-- GUI
--==================================================

local playerGui = player:WaitForChild("PlayerGui")

local oldGui = playerGui:FindFirstChild("AutoBabyGUI")
if oldGui then
    oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "AutoBabyGUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(220, 110)
main.Position = UDim2.new(0.5, -110, 0.5, -55)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 27)
main.BorderSizePixel = 0
main.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(70, 70, 85)
stroke.Thickness = 1
stroke.Parent = main

--==================================================
-- TITLE
--==================================================

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 0, 35)
title.Position = UDim2.fromOffset(15, 5)
title.BackgroundTransparency = 1
title.Text = "AUTO BABY"
title.TextColor3 = Color3.fromRGB(240, 240, 245)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

--==================================================
-- CLOSE
--==================================================

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(30, 30)
close.Position = UDim2.new(1, -35, 0, 7)
close.BackgroundTransparency = 1
close.Text = "×"
close.TextColor3 = Color3.fromRGB(180, 180, 190)
close.TextSize = 22
close.Font = Enum.Font.GothamBold
close.Parent = main

--==================================================
-- TOGGLE
--==================================================

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.new(1, -30, 0, 45)
toggle.Position = UDim2.fromOffset(15, 50)
toggle.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
toggle.BorderSizePixel = 0
toggle.Text = "AUTO BABY  •  OFF"
toggle.TextColor3 = Color3.fromRGB(190, 190, 200)
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 14
toggle.Parent = main

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 9)
toggleCorner.Parent = toggle

local function updateToggle()
    if Enabled then
        toggle.BackgroundColor3 = Color3.fromRGB(35, 125, 75)
        toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
        toggle.Text = "AUTO BABY  •  ON"
    else
        toggle.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
        toggle.TextColor3 = Color3.fromRGB(190, 190, 200)
        toggle.Text = "AUTO BABY  •  OFF"
    end
end

toggle.MouseButton1Click:Connect(function()
    Enabled = not Enabled
    updateToggle()

    print("[AutoBaby] " .. (Enabled and "Enabled" or "Disabled"))
end)

close.MouseButton1Click:Connect(function()
    Enabled = false
    gui:Destroy()
end)

--==================================================
-- DRAGGING
--==================================================

local dragging = false
local dragStart
local startPosition

title.InputBegan:Connect(function(input)
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
-- FIND BABY PROMPT
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
-- AUTO PICKUP LOOP
--==================================================

task.spawn(function()
    local lastPrompt = nil
    local lastAttempt = 0

    while gui.Parent do
        if Enabled then
            local prompt = findBabyPrompt()

            if prompt then
                if prompt ~= lastPrompt then
                    print("[AutoBaby] BabyPickup detected")
                    print("[AutoBaby] Prompt found:", prompt:GetFullName())

                    lastPrompt = prompt
                end

                if prompt.Enabled then
                    local now = os.clock()

                    -- Prevent firing the same prompt hundreds of times/sec.
                    if now - lastAttempt >= 0.15 then
                        lastAttempt = now

                        if typeof(fireproximityprompt) == "function" then
                            print("[AutoBaby] Firing PickupPrompt")
                            fireproximityprompt(prompt)
                        else
                            warn(
                                "[AutoBaby] fireproximityprompt is unavailable in this executor"
                            )
                            task.wait(1)
                        end
                    end
                end
            else
                lastPrompt = nil
            end
        end

        task.wait(0.05)
    end
end)

updateToggle()

print("[AutoBaby] Loaded successfully")
```
