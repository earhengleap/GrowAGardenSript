--[[
    @title Complete Garden Bot Suite
    @author Your Name (improved from depso's work)
    @description All-in-one Grow a Garden bot with stock tracking and auto-farming
    @game https://www.roblox.com/games/126884695634066
    
    Features:
    - Real-time stock display
    - Auto planting with seed selection
    - Auto harvesting with variant filtering
    - Auto selling with threshold control
    - Auto buying seeds when needed
    - Anti-AFK protection
    - Weather event notifications
    - Clean, simple UI
]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

-- Player references
local LocalPlayer = Players.LocalPlayer
local Backpack = LocalPlayer.Backpack
local PlayerGui = LocalPlayer.PlayerGui

-- Game references
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local DataStream = GameEvents:WaitForChild("DataStream")
local WeatherEventStarted = GameEvents:FindFirstChild("WeatherEventStarted")

-- Prevent multiple instances
if _G.GardenBotRunning then return end
_G.GardenBotRunning = true

-- Configuration
local Config = {
    AutoPlant = false,
    AutoHarvest = false,
    AutoSell = false,
    AutoBuy = false,
    AntiAFK = true,
    SellThreshold = 15,
    SelectedSeed = "Blueberry",
    PlantRandom = false,
    HarvestIgnores = {
        Normal = false,
        Gold = false,
        Rainbow = false
    },
    ShowStockDisplay = true
}

-- Data storage
local StockData = {}
local OwnedSeeds = {}
local IsProcessing = false

-- UI Creation
local function CreateUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "GardenBotUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = PlayerGui
    
    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 350, 0, 500)
    mainFrame.Position = UDim2.new(0, 20, 0, 20)
    mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    
    -- Draggable
    local dragFrame = Instance.new("Frame")
    dragFrame.Size = UDim2.new(1, 0, 0, 30)
    dragFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    dragFrame.BorderSizePixel = 0
    dragFrame.Parent = mainFrame
    
    local dragCorner = Instance.new("UICorner")
    dragCorner.CornerRadius = UDim.new(0, 8)
    dragCorner.Parent = dragFrame
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -10, 1, 0)
    titleLabel.Position = UDim2.new(0, 10, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Garden Bot v2.0"
    titleLabel.TextColor3 = Color3.new(1, 1, 1)
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.Parent = dragFrame
    
    -- Content Frame
    local contentFrame = Instance.new("ScrollingFrame")
    contentFrame.Size = UDim2.new(1, -20, 1, -40)
    contentFrame.Position = UDim2.new(0, 10, 0, 35)
    contentFrame.BackgroundTransparency = 1
    contentFrame.ScrollBarThickness = 6
    contentFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    contentFrame.Parent = mainFrame
    
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 5)
    layout.Parent = contentFrame
    
    return screenGui, contentFrame
end

-- UI Helper Functions
local function CreateSection(parent, title, layoutOrder)
    local section = Instance.new("Frame")
    section.Size = UDim2.new(1, 0, 0, 30)
    section.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    section.BorderSizePixel = 0
    section.LayoutOrder = layoutOrder
    section.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = section
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = title
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextScaled = true
    label.Font = Enum.Font.SourceSansBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = section
    
    return section
end

local function CreateToggle(parent, text, configKey, layoutOrder)
    local toggle = Instance.new("Frame")
    toggle.Size = UDim2.new(1, 0, 0, 25)
    toggle.BackgroundTransparency = 1
    toggle.LayoutOrder = layoutOrder
    toggle.Parent = parent
    
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 50, 0, 20)
    button.Position = UDim2.new(1, -55, 0, 2.5)
    button.BackgroundColor3 = Config[configKey] and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
    button.BorderSizePixel = 0
    button.Text = Config[configKey] and "ON" or "OFF"
    button.TextColor3 = Color3.new(1, 1, 1)
    button.TextScaled = true
    button.Font = Enum.Font.SourceSansBold
    button.Parent = toggle
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 4)
    buttonCorner.Parent = button
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextScaled = true
    label.Font = Enum.Font.SourceSans
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = toggle
    
    button.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        button.BackgroundColor3 = Config[configKey] and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
        button.Text = Config[configKey] and "ON" or "OFF"
    end)
    
    return toggle
end

local function CreateStockDisplay(parent, layoutOrder)
    local display = Instance.new("Frame")
    display.Size = UDim2.new(1, 0, 0, 200)
    display.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    display.BorderSizePixel = 0
    display.LayoutOrder = layoutOrder
    display.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = display
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 1, -10)
    label.Position = UDim2.new(0, 5, 0, 5)
    label.BackgroundTransparency = 1
    label.Text = "Waiting for stock data..."
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextWrapped = true
    label.Font = Enum.Font.SourceSans
    label.TextSize = 14
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = display
    
    return label
end

-- Game Functions
local function GetFarm(playerName)
    local farms = workspace.Farm:GetChildren()
    for _, farm in pairs(farms) do
        local owner = farm.Important.Data.Owner.Value
        if owner == playerName then
            return farm
        end
    end
    return nil
end

local function GetSeedInfo(tool)
    local plantName = tool:FindFirstChild("Plant_Name")
    local count = tool:FindFirstChild("Numbers")
    if plantName and count then
        return plantName.Value, count.Value
    end
    return nil, nil
end

local function UpdateOwnedSeeds()
    OwnedSeeds = {}
    local character = LocalPlayer.Character
    
    -- Check backpack
    for _, tool in pairs(Backpack:GetChildren()) do
        local name, count = GetSeedInfo(tool)
        if name then
            OwnedSeeds[name] = {Count = count, Tool = tool}
        end
    end
    
    -- Check character
    if character then
        for _, tool in pairs(character:GetChildren()) do
            local name, count = GetSeedInfo(tool)
            if name then
                OwnedSeeds[name] = {Count = count, Tool = tool}
            end
        end
    end
end

local function Plant(position, seed)
    GameEvents.Plant_RE:FireServer(position, seed)
    wait(0.3)
end

local function GetRandomFarmPoint(farm)
    local plantLocations = farm.Important.Plant_Locations:GetChildren()
    if #plantLocations == 0 then return nil end
    
    local farmLand = plantLocations[math.random(1, #plantLocations)]
    local center = farmLand:GetPivot()
    local size = farmLand.Size
    
    local x = math.random(center.X - size.X/2, center.X + size.X/2)
    local z = math.random(center.Z - size.Z/2, center.Z + size.Z/2)
    
    return Vector3.new(x, 4, z)
end

local function AutoPlantLoop()
    if IsProcessing then return end
    IsProcessing = true
    
    UpdateOwnedSeeds()
    local seedData = OwnedSeeds[Config.SelectedSeed]
    if not seedData or seedData.Count <= 0 then
        IsProcessing = false
        return
    end
    
    local farm = GetFarm(LocalPlayer.Name)
    if not farm then
        IsProcessing = false
        return
    end
    
    -- Equip tool if needed
    if seedData.Tool.Parent == Backpack then
        LocalPlayer.Character.Humanoid:EquipTool(seedData.Tool)
    end
    
    -- Plant seeds
    for i = 1, seedData.Count do
        local point = GetRandomFarmPoint(farm)
        if point then
            Plant(point, Config.SelectedSeed)
        end
    end
    
    IsProcessing = false
end

local function HarvestPlant(plant)
    local prompt = plant:FindFirstChildOfClass("ProximityPrompt", true)
    if prompt and prompt.Enabled then
        fireproximityprompt(prompt)
    end
end

local function AutoHarvestLoop()
    local farm = GetFarm(LocalPlayer.Name)
    if not farm then return end
    
    local plantsPhysical = farm.Important.Plants_Physical
    local character = LocalPlayer.Character
    if not character then return end
    
    local playerPos = character:GetPivot().Position
    
    for _, plant in pairs(plantsPhysical:GetDescendants()) do
        if plant:IsA("Model") and plant:FindFirstChildOfClass("ProximityPrompt", true) then
            local variant = plant:FindFirstChild("Variant")
            if variant and Config.HarvestIgnores[variant.Value] then
                continue
            end
            
            local distance = (plant:GetPivot().Position - playerPos).Magnitude
            if distance <= 50 then
                HarvestPlant(plant)
            end
        end
    end
end

local function SellInventory()
    local character = LocalPlayer.Character
    if not character then return end
    
    local previousPos = character:GetPivot()
    local previousSheckles = LocalPlayer.leaderstats.Sheckles.Value
    
    -- Teleport to sell location
    character:PivotTo(CFrame.new(62, 4, -26))
    
    -- Sell until money changes
    local attempts = 0
    while LocalPlayer.leaderstats.Sheckles.Value == previousSheckles and attempts < 10 do
        GameEvents.Sell_Inventory:FireServer()
        wait(0.5)
        attempts = attempts + 1
    end
    
    -- Return to previous position
    character:PivotTo(previousPos)
end

local function GetCropCount()
    local count = 0
    local character = LocalPlayer.Character
    
    for _, tool in pairs(Backpack:GetChildren()) do
        if tool:FindFirstChild("Item_String") then
            count = count + 1
        end
    end
    
    if character then
        for _, tool in pairs(character:GetChildren()) do
            if tool:FindFirstChild("Item_String") then
                count = count + 1
            end
        end
    end
    
    return count
end

local function AutoSellCheck()
    if Config.AutoSell and GetCropCount() >= Config.SellThreshold then
        SellInventory()
    end
end

local function BuySeed(seed)
    GameEvents.BuySeedStock:FireServer(seed)
end

local function AutoBuyLoop()
    UpdateOwnedSeeds()
    local seedData = OwnedSeeds[Config.SelectedSeed]
    
    if not seedData or seedData.Count > 0 then return end
    
    local stock = StockData["ROOT/SeedStock/Stocks"]
    if stock and stock[Config.SelectedSeed] and stock[Config.SelectedSeed].Stock > 0 then
        BuySeed(Config.SelectedSeed)
    end
end

-- Stock Display Functions
local function GetDataPacket(data, target)
    for _, packet in pairs(data) do
        if packet[1] == target then
            return packet[2]
        end
    end
    return nil
end

local function FormatStockString(stock)
    local str = ""
    for name, data in pairs(stock) do
        local amount = data.Stock or 0
        local eggName = data.EggName
        name = eggName or name
        str = str .. string.format("%s: %d\n", name, amount)
    end
    return str
end

local function UpdateStockDisplay(stockLabel, data)
    local displayText = ""
    local layouts = {
        ["ROOT/SeedStock/Stocks"] = "🌱 Seeds",
        ["ROOT/GearStock/Stocks"] = "⚙️ Gear",
        ["ROOT/EventShopStock/Stocks"] = "🎉 Event Items",
        ["ROOT/PetEggStock/Stocks"] = "🥚 Pet Eggs",
        ["ROOT/CosmeticStock/ItemStocks"] = "👕 Cosmetics",
    }

    for packetPath, title in pairs(layouts) do
        local stockData = GetDataPacket(data, packetPath)
        if stockData then
            StockData[packetPath] = stockData
            displayText = displayText .. title .. ":\n"
            displayText = displayText .. FormatStockString(stockData)
            displayText = displayText .. "\n"
        end
    end

    if displayText == "" then
        displayText = "No stock data available."
    end

    stockLabel.Text = displayText
end

-- Main execution
local function StartBot()
    local screenGui, contentFrame = CreateUI()
    
    -- Create UI sections
    CreateSection(contentFrame, "📊 Stock Display", 1)
    local stockLabel = CreateStockDisplay(contentFrame, 2)
    
    CreateSection(contentFrame, "🌱 Auto Plant", 3)
    CreateToggle(contentFrame, "Auto Plant", "AutoPlant", 4)
    CreateToggle(contentFrame, "Plant Random", "PlantRandom", 5)
    
    CreateSection(contentFrame, "🚜 Auto Harvest", 6)
    CreateToggle(contentFrame, "Auto Harvest", "AutoHarvest", 7)
    
    CreateSection(contentFrame, "💰 Auto Sell", 8)
    CreateToggle(contentFrame, "Auto Sell", "AutoSell", 9)
    
    CreateSection(contentFrame, "🛒 Auto Buy", 10)
    CreateToggle(contentFrame, "Auto Buy", "AutoBuy", 11)
    
    CreateSection(contentFrame, "⚙️ Settings", 12)
    CreateToggle(contentFrame, "Anti-AFK", "AntiAFK", 13)
    
    -- Update content frame size
    local function updateContentSize()
        local totalHeight = 0
        for _, child in pairs(contentFrame:GetChildren()) do
            if child:IsA("GuiObject") then
                totalHeight = totalHeight + child.AbsoluteSize.Y + 5
            end
        end
        contentFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
    end
    
    contentFrame.ChildAdded:Connect(updateContentSize)
    contentFrame.ChildRemoved:Connect(updateContentSize)
    updateContentSize()
    
    -- Connect events
    DataStream.OnClientEvent:Connect(function(type, profile, data)
        if type == "UpdateData" then
            UpdateStockDisplay(stockLabel, data)
        end
    end)
    
    if WeatherEventStarted then
        WeatherEventStarted.OnClientEvent:Connect(function(event, length)
            print("Weather Event:", event, "Duration:", length, "seconds")
        end)
    end
    
    -- Anti-AFK
    LocalPlayer.Idled:Connect(function()
        if Config.AntiAFK then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end)
    
    -- Main loops
    spawn(function()
        while wait(1) do
            if Config.AutoPlant then
                AutoPlantLoop()
            end
        end
    end)
    
    spawn(function()
        while wait(0.5) do
            if Config.AutoHarvest then
                AutoHarvestLoop()
            end
        end
    end)
    
    spawn(function()
        while wait(2) do
            if Config.AutoBuy then
                AutoBuyLoop()
            end
        end
    end)
    
    spawn(function()
        while wait(1) do
            AutoSellCheck()
        end
    end)
    
    print("Garden Bot v2.0 Started Successfully!")
end

-- Start the bot
StartBot()