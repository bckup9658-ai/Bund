print("HELLO FROM GITHUB")

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "TestGUI"
gui.Parent = player.PlayerGui

local button = Instance.new("TextButton")
button.Size = UDim2.new(0,300,0,100)
button.Position = UDim2.new(0.5,-150,0.5,-50)
button.Text = "IT WORKS"
button.BackgroundColor3 = Color3.fromRGB(0,255,0)
button.Parent = gui

print("GUI CREATED")
