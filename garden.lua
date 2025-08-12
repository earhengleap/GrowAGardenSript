-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local DataStream = ReplicatedStorage.GameEvents.DataStream -- RemoteEvent

-- UI Setup
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StockDisplayGui"
screenGui.Parent = playerGui

local textLabel = Instance.new("TextLabel")
textLabel.Size = UDim2.new(0, 400, 0, 300)
textLabel.Position = UDim2.new(0, 20, 0, 20)
textLabel.BackgroundColor3 = Color3.new(0, 0, 0)
textLabel.BackgroundTransparency = 0.5
textLabel.TextColor3 = Color3.new(1, 1, 1)
textLabel.TextWrapped = true
textLabel.Font = Enum.Font.SourceSans
textLabel.TextSize = 18
textLabel.Parent = screenGui
textLabel.Text = "Waiting for stock data..."

-- Helper: Format stock info string
local function MakeStockString(Stock)
    local str = ""
    for name, data in pairs(Stock) do
        local amount = data.Stock or 0
        local eggName = data.EggName
        name = eggName or name
        str ..= string.format("%s x%d\n", name, amount)
    end
    return str
end

local function GetDataPacket(data, target)
    for _, packet in pairs(data) do
        local name = packet[1]
        local content = packet[2]
        if name == target then
            return content
        end
    end
end

local function UpdateStockUI(data)
    local displayText = ""
    local layouts = {
        ["ROOT/SeedStock/Stocks"] = "Seeds Stock",
        ["ROOT/GearStock/Stocks"] = "Gear Stock",
        ["ROOT/EventShopStock/Stocks"] = "Event Stock",
        ["ROOT/PetEggStock/Stocks"] = "Egg Stock",
        ["ROOT/CosmeticStock/ItemStocks"] = "Cosmetic Items Stock",
    }

    for packetPath, title in pairs(layouts) do
        local stockData = GetDataPacket(data, packetPath)
        if stockData then
            displayText ..= title .. ":\n"
            displayText ..= MakeStockString(stockData)
            displayText ..= "\n"
        end
    end

    if displayText == "" then
        displayText = "No stock data available."
    end

    textLabel.Text = displayText
end

DataStream.OnClientEvent:Connect(function(Type, Profile, Data)
    if Type ~= "UpdateData" then return end
    if not Profile:find(LocalPlayer.Name) then return end

    UpdateStockUI(Data)
end)

-- Anti-AFK and Auto-Reconnect can remain unchanged from your original script,
-- but I'm leaving them out here to focus on the UI stock display.

