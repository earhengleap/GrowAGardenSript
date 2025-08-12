--[[
    @author depso (depthso) - fixed & improved by ChatGPT
    @description Grow a Garden auto-farm script (AutoBuy improved)
    https://www.roblox.com/games/126884695634066
]]

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Leaderstats = LocalPlayer:WaitForChild("leaderstats")
local Backpack = LocalPlayer:WaitForChild("Backpack")
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ShecklesCount = Leaderstats:WaitForChild("Sheckles")
local GameInfo = MarketplaceService:GetProductInfo(game.PlaceId)

--// ReGui
local ReGui = loadstring(game:HttpGet('https://raw.githubusercontent.com/depthso/Dear-ReGui/refs/heads/main/ReGui.lua'))()
local PrefabsId = "rbxassetid://" .. ReGui.PrefabsId

--// Folders
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local FarmsFolder = workspace:WaitForChild("Farm")

local Accent = {
    DarkGreen = Color3.fromRGB(45, 95, 25),
    Green = Color3.fromRGB(69, 142, 40),
    Brown = Color3.fromRGB(26, 20, 8),
}

--// ReGui configuration (Ui library)
ReGui:Init({
    Prefabs = InsertService:LoadLocalAsset(PrefabsId)
})
ReGui:DefineTheme("GardenTheme", {
    WindowBg = Accent.Brown,
    TitleBarBg = Accent.DarkGreen,
    TitleBarBgActive = Accent.Green,
    ResizeGrab = Accent.DarkGreen,
    FrameBg = Accent.DarkGreen,
    FrameBgActive = Accent.Green,
    CollapsingHeaderBg = Accent.Green,
    ButtonsBg = Accent.Green,
    CheckMark = Accent.Green,
    SliderGrab = Accent.Green,
})

--// Dicts
local SeedStock = {}
local OwnedSeeds = {}
local HarvestIgnores = {
    Normal = false,
    Gold = false,
    Rainbow = false
}

--// Globals
local SelectedSeed, AutoPlantRandom, AutoPlant, AutoHarvest, AutoBuy, SellThreshold, NoClip, AutoWalkAllowRandom, AutoSell, AutoWalk, AutoWalkMaxWait, AutoWalkStatus, SelectedSeedStock, OnlyShowStock

-- Helper function to wait for character
local function WaitForCharacter()
    if LocalPlayer.Character then return LocalPlayer.Character end
    return LocalPlayer.CharacterAdded:Wait()
end

local function GetFarms()
    return FarmsFolder:GetChildren()
end

local function GetFarmOwner(Farm)
    local Important = Farm:FindFirstChild("Important")
    if not Important then return nil end
    local Data = Important:FindFirstChild("Data")
    if not Data then return nil end
    local Owner = Data:FindFirstChild("Owner")
    if not Owner then return nil end
    return Owner.Value
end

local function GetFarm(playerName)
    for _, farm in ipairs(GetFarms()) do
        if GetFarmOwner(farm) == playerName then
            return farm
        end
    end
    return nil
end

local function EquipCheck(tool)
    local character = LocalPlayer.Character or WaitForCharacter()
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid and tool.Parent == Backpack then
        humanoid:EquipTool(tool)
    end
end

local function Plant(position, seed)
    GameEvents:WaitForChild("Plant_RE"):FireServer(position, seed)
    wait(0.3)
end

local function SellInventory()
    local character = LocalPlayer.Character or WaitForCharacter()
    local prevCF = character:GetPivot()
    local prevSheckles = ShecklesCount.Value
    if SellInventory.IsRunning then return end
    SellInventory.IsRunning = true

    character:PivotTo(CFrame.new(62, 4, -26))
    while wait(0.5) do
        if ShecklesCount.Value ~= prevSheckles then break end
        GameEvents:WaitForChild("Sell_Inventory"):FireServer()
    end
    character:PivotTo(prevCF)
    SellInventory.IsRunning = false
end

local function BuySeed(seed)
    GameEvents:WaitForChild("BuySeedStock"):FireServer(seed)
end

-- FIXED FUNCTION: GetSeedStock
local function GetSeedStock(onlyInStock)
    local SeedShop = PlayerGui:WaitForChild("Seed_Shop")
    local itemsFolder = SeedShop:FindFirstChild("Blueberry", true)
    if not itemsFolder then
        warn("[GetSeedStock] Could not find 'Blueberry' UI element in Seed_Shop")
        return {}
    end
    local Items = itemsFolder.Parent
    local newList = {}
    for _, item in ipairs(Items:GetChildren()) do
        local mainFrame = item:FindFirstChild("Main_Frame")
        if not mainFrame then continue end
        local stockText = mainFrame:FindFirstChild("Stock_Text")
        if not stockText then continue end
        local stockCount = tonumber(stockText.Text:match("%d+")) or 0
        if onlyInStock and stockCount <= 0 then
            -- skip
        else
            newList[item.Name] = stockCount
        end
    end
    SeedStock = newList
    return newList
end

local function BuyAllSelectedSeeds()
    local seedList = GetSeedStock(OnlyShowStock and OnlyShowStock.Value)
    local seed = SelectedSeedStock and SelectedSeedStock.Selected
    if not seed or seed == "" then return end
    local stock = seedList[seed]
    if not stock or stock <= 0 then return end
    for i = 1, stock do
        BuySeed(seed)
        wait(0.2)
    end
end

local function GetSeedInfo(tool)
    local plantName = tool:FindFirstChild("Plant_Name")
    local count = tool:FindFirstChild("Numbers")
    if plantName and count then
        return plantName.Value, count.Value
    end
end

local function CollectSeedsFromParent(parent, seeds)
    for _, tool in ipairs(parent:GetChildren()) do
        local name, count = GetSeedInfo(tool)
        if name then
            seeds[name] = { Count = count, Tool = tool }
        end
    end
end

local function GetOwnedSeeds()
    OwnedSeeds = {}
    local character = LocalPlayer.Character or WaitForCharacter()
    CollectSeedsFromParent(Backpack, OwnedSeeds)
    CollectSeedsFromParent(character, OwnedSeeds)
    return OwnedSeeds
end

local function GetArea(basePart)
    local center = basePart:GetPivot().Position
    local size = basePart.Size
    local x1 = math.ceil(center.X - (size.X / 2))
    local z1 = math.ceil(center.Z - (size.Z / 2))
    local x2 = math.floor(center.X + (size.X / 2))
    local z2 = math.floor(center.Z + (size.Z / 2))
    return x1, z1, x2, z2
end

local function GetRandomFarmPoint()
    local farmLands = PlantLocations:GetChildren()
    local farmLand = farmLands[math.random(1, #farmLands)]
    local x1, z1, x2, z2 = GetArea(farmLand)
    return Vector3.new(math.random(x1, x2), 4, math.random(z1, z2))
end

local function AutoPlantLoop()
    local seed = SelectedSeed and SelectedSeed.Selected
    if not seed or seed == "" then return end
    local seedData = OwnedSeeds[seed]
    if not seedData or seedData.Count <= 0 then return end
    EquipCheck(seedData.Tool)
    local planted = 0
    for x = X1, X2, 1 do
        for z = Z1, Z2, 1 do
            if planted >= seedData.Count then break end
            Plant(Vector3.new(x, 0.13, z), seed)
            planted += 1
        end
        if planted >= seedData.Count then break end
    end
end

-- Waiting for farm
local MyFarm
repeat
    MyFarm = GetFarm(LocalPlayer.Name)
    wait(1)
until MyFarm

local MyImportant = MyFarm:WaitForChild("Important")
local PlantLocations = MyImportant:WaitForChild("Plant_Locations")
PlantsPhysical = MyImportant:WaitForChild("Plants_Physical")
local Dirt = PlantLocations:FindFirstChildOfClass("Part")
X1, Z1, X2, Z2 = GetArea(Dirt)

-- UI
local Window = ReGui:Window({
    Title = string.format("%s | Depso", GameInfo.Name),
    Theme = "GardenTheme",
    Size = UDim2.fromOffset(300, 200)
})

-- Auto-Plant
local PlantNode = Window:TreeNode({ Title = "Auto-Plant 🥕" })
SelectedSeed = PlantNode:Combo({
    Label = "Seed",
    Selected = "",
    GetItems = GetSeedStock,
})
AutoPlant = PlantNode:Checkbox({ Value = true, Label = "Enabled" })
AutoPlantRandom = PlantNode:Checkbox({ Value = false, Label = "Plant at random points" })
PlantNode:Button({ Text = "Plant all", Callback = AutoPlantLoop })

-- Auto-Buy (Fixed)
local BuyNode = Window:TreeNode({ Title = "Auto-Buy 🥕" })
OnlyShowStock = BuyNode:Checkbox({ Value = false, Label = "Only list stock" })
SelectedSeedStock = BuyNode:Combo({
    Label = "Seed",
    Selected = "",
    GetItems = function()
        return GetSeedStock(OnlyShowStock and OnlyShowStock.Value)
    end,
})
AutoBuy = BuyNode:Checkbox({ Value = true, Label = "Enabled" })
BuyNode:Button({ Text = "Buy all", Callback = BuyAllSelectedSeeds })

-- Auto-Sell
local SellNode = Window:TreeNode({ Title = "Auto-Sell 💰" })
SellNode:Button({ Text = "Sell inventory", Callback = SellInventory })
AutoSell = SellNode:Checkbox({ Value = true, Label = "Enabled" })
SellThreshold = SellNode:SliderInt({ Label = "Crops threshold", Value = 15, Minimum = 1, Maximum = 199 })

-- Auto-Walk
local WalkNode = Window:TreeNode({ Title = "Auto-Walk 🚶" })
AutoWalkStatus = WalkNode:Label({ Text = "None" })
AutoWalk = WalkNode:Checkbox({ Value = true, Label = "Enabled" })
AutoWalkAllowRandom = WalkNode:Checkbox({ Value = true, Label = "Allow random points" })
NoClip = WalkNode:Checkbox({ Value = false, Label = "NoClip" })
AutoWalkMaxWait = WalkNode:SliderInt({ Label = "Max delay", Value = 10, Minimum = 1, Maximum = 120 })

-- Loops
RunService.Stepped:Connect(function()
    if NoClip and NoClip.Value then
        local character = LocalPlayer.Character or WaitForCharacter()
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

Backpack.ChildAdded:Connect(function()
    if AutoSell and AutoSell.Value then
        local crops = GetOwnedSeeds()
        if #crops >= SellThreshold.Value then
            SellInventory()
        end
    end
end)

-- Main loops
coroutine.wrap(function()
    while true do
        wait(0.1)
        if AutoBuy and AutoBuy.Value then
            BuyAllSelectedSeeds()
        end
    end
end)()

coroutine.wrap(function()
    while true do
        wait(0.1)
        if AutoPlant and AutoPlant.Value then
            AutoPlantLoop()
        end
    end
end)()
