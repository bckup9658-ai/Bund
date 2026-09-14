-- AutoBaby.lua
-- Client-side Auto Baby pickup
-- For use in your own Roblox test environment.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

--==================================================
-- SETTINGS
--==================================================

local Enabled = false
local GUI_NAME = "AutoBabyGUI"

--==================================================
-- GUI
--==================================================

local oldGui = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild(GUI_NAME)
if oldGui then
    oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = LocalPlayer.PlayerGui

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(220, 115)
main.Position = UDim2.new(0.5, -110, 0.5, -58)
main.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
main.BorderSizePixel = 0
main.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(65, 65, 80)
stroke.Thickness = 1
stroke.Parent = main

--==================================================
-- TITLE
--==================================================

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -45, 0, 35)
title.Position = UDim2.fromOffset(15, 5)
title.BackgroundTransparency = 1
title.Text = "AUTO BABY"
title.TextColor3 = Color3.fromRGB(235, 235, 240)
title.TextSize = 16
title.Font = Enum.Font.GothamBold
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

close.MouseButton1Click:Connect(function()
    Enabled = false
    gui:Destroy()
end)

--==================================================
-- TOGGLE
--==================================================

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.new(1, -30, 0, 48)
toggle.Position = UDim2.fromOffset(15, 48)
toggle.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
toggle.BorderSizePixel = 0
toggle.Text = "AUTO BABY  •  OFF"
toggle.TextColor3 = Color3.fromRGB(190, 190, 200)
toggle.TextSize = 14
toggle.Font = Enum.Font.GothamBold
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
end)

--==================================================
-- DRAGGING
--==================================================

local UserInputService = game:GetService("UserInputService")

local dragging = false
local dragStart
local startPosition

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPosition = main.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
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

--==================================================
-- BABY PICKUP
--==================================================

local function getPickupPrompt()
    local baby = Workspace:FindFirstChild("BabyPickup")

    if not baby then
        return nil
    end

    return baby:FindFirstChild("PickupPrompt", true)
end

local function tryPickup()
    if not Enabled then
        return
    end

    local prompt = getPickupPrompt()

    if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled then
        -- Uses the game's normal interaction path.
        prompt:InputHoldBegin()

        task.wait(prompt.HoldDuration)

        prompt:InputHoldEnd()
    end
end

--==================================================
-- WATCH FOR BABY
--==================================================

Workspace.ChildAdded:Connect(function(child)
    if child.Name == "BabyPickup" then
        task.wait(0.1)
        tryPickup()
    end
end)

-- Also check periodically in case BabyPickup
-- already existed when the script started.

task.spawn(function()
    while gui.Parent do
        if Enabled then
            tryPickup()
        end

        task.wait(0.25)
    end
end)

updateToggle()
