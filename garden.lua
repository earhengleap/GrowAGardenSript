--[[
    @author depso (depthso) - fixed by Claude
    @description Grow a Garden auto-farm script (improved auto-buy functionality)
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

--// Globals (toggles will be initialized after UI creation)
local SelectedSeed, AutoPlantRandom, AutoPlant, AutoHarvest, AutoBuy, SellThreshold, NoClip, AutoWalkAllowRandom, AutoSell, AutoWalk, AutoWalkMaxWait, AutoWalkStatus, SelectedSeedStock, BuyAmount, AutoBuyDelay, OnlyShowStock

-- Helper function to wait for character and return it
local function WaitForCharacter()
    if LocalPlayer.Character then return LocalPlayer.Character end
    return LocalPlayer.CharacterAdded:Wait()
end

-- Get all farms
local function GetFarms()
    return FarmsFolder:GetChildren()
end

-- Get farm owner name
local function GetFarmOwner(Farm)
    local Important = Farm:FindFirstChild("Important")
    if not Important then return nil end
    local Data = Important:FindFirstChild("Data")
    if not Data then return nil end
    local Owner = Data:FindFirstChild("Owner")
    if not Owner then return nil end
    return Owner.Value
end

-- Get the player's own farm
local function GetFarm(playerName)
    local farms = GetFarms()
    for _, farm in ipairs(farms) do
        local owner = GetFarmOwner(farm)
        if owner == playerName then
            return farm
        end
    end
    return nil
end

local function EquipCheck(tool)
    local character = LocalPlayer.Character or WaitForCharacter()
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    if tool.Parent ~= Backpack then return end
    humanoid:EquipTool(tool)
end

local function Plant(position, seed)
    print("[Plant] Planting seed:", seed, "at", position)
    GameEvents:WaitForChild("Plant_RE"):FireServer(position, seed)
    wait(0.3)
end

local function SellInventory()
    local character = LocalPlayer.Character or WaitForCharacter()
    local previousCFrame = character:GetPivot()
    local previousSheckles = ShecklesCount.Value

    if SellInventory.IsRunning then return end
    SellInventory.IsRunning = true

    print("[SellInventory] Moving to sell position...")
    character:PivotTo(CFrame.new(62, 4, -26))

    while wait(0.5) do
        if ShecklesCount.Value ~= previousSheckles then
            print("[SellInventory] Sell complete.")
            break
        end
        GameEvents:WaitForChild("Sell_Inventory"):FireServer()
    end

    character:PivotTo(previousCFrame)
    SellInventory.IsRunning = false
end

local function BuySeed(seed)
    print("[BuySeed] Buying seed:", seed)
    GameEvents:WaitForChild("BuySeedStock"):FireServer(seed)
end

-- Improved BuyAllSelectedSeeds function
local function BuyAllSelectedSeeds()
    local seed = SelectedSeedStock and SelectedSeedStock.Selected
    if not seed or seed == "" then
        print("[BuyAllSelectedSeeds] No seed selected.")
        return
    end
    
    -- Refresh stock before buying
    GetSeedStock()
    local stock = SeedStock[seed]
    if not stock or stock <= 0 then
        print("[BuyAllSelectedSeeds] No stock available for", seed)
        return
    end
    
    local amount = BuyAmount and BuyAmount.Value or stock
    local buyCount = math.min(amount, stock) -- Don't try to buy more than available
    local delay = (AutoBuyDelay and AutoBuyDelay.Value or 500) / 1000 -- Convert ms to seconds
    
    print(string.format("[BuyAllSelectedSeeds] Buying %d of %s (Stock: %d)", buyCount, seed, stock))
    
    for i = 1, buyCount do
        BuySeed(seed)
        if i < buyCount then -- Don't wait after the last purchase
            wait(delay)
        end
    end
    
    print(string.format("[BuyAllSelectedSeeds] Finished buying %d seeds", buyCount))
end

-- Auto-buy loop function
local function AutoBuyLoop()
    if not AutoBuy or not AutoBuy.Value then return end
    
    local seed = SelectedSeedStock and SelectedSeedStock.Selected
    if not seed or seed == "" then return end
    
    -- Check if we need seeds (optional: only buy if we have less than a certain amount)
    GetOwnedSeeds()
    local ownedCount = OwnedSeeds[seed] and OwnedSeeds[seed].Count or 0
    
    -- Only buy if we have less than 10 seeds (configurable threshold)
    if ownedCount < 10 then
        GetSeedStock()
        local stock = SeedStock[seed]
        if stock and stock > 0 then
            local buyCount = math.min(BuyAmount and BuyAmount.Value or 1, stock)
            for i = 1, buyCount do
                BuySeed(seed)
                wait((AutoBuyDelay and AutoBuyDelay.Value or 500) / 1000)
            end
        end
    end
end

local function GetSeedInfo(tool)
    local plantName = tool:FindFirstChild("Plant_Name")
    local count = tool:FindFirstChild("Numbers")
    if not plantName or not count then return end
    return plantName.Value, count.Value
end

local function CollectSeedsFromParent(parent, seeds)
    for _, tool in ipairs(parent:GetChildren()) do
        local name, count = GetSeedInfo(tool)
        if not name then continue end
        seeds[name] = {
            Count = count,
            Tool = tool
        }
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

local function AutoPlantLoop()
    print("[AutoPlantLoop] Running...")
    local seed = SelectedSeed and SelectedSeed.Selected
    if not seed or seed == "" then
        print("[AutoPlantLoop] No seed selected!")
        return
    end

    GetOwnedSeeds() -- Refresh owned seeds
    local seedData = OwnedSeeds[seed]
    if not seedData then
        print("[AutoPlantLoop] Seed not owned:", seed)
        return
    end

    local count = seedData.Count
    local tool = seedData.Tool

    if count <= 0 then
        print("[AutoPlantLoop] No seeds left to plant.")
        return
    end

    EquipCheck(tool)

    local planted = 0
    local step = 1

    -- Plant at random points if enabled
    if AutoPlantRandom and AutoPlantRandom.Value then
        for i = 1, count do
            local point = GetRandomFarmPoint()
            Plant(point, seed)
            planted = planted + 1
        end
    end

    -- Plant in farm area
    for x = X1, X2, step do
        for z = Z1, Z2, step do
            if planted >= count then break end
            local point = Vector3.new(x, 0.13, z)
            Plant(point, seed)
            planted = planted + 1
        end
        if planted >= count then break end
    end
end

local function HarvestPlant(plant)
    local prompt = plant:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then return end

    local character = LocalPlayer.Character or WaitForCharacter()
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = plant:GetPivot() * CFrame.new(0, 3, 0)
        wait(0.1)
    end

    fireproximityprompt(prompt)
end

local function CanHarvest(plant)
    local prompt = plant:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then return false end
    if not prompt.Enabled then return false end
    return true
end

local function CollectHarvestable(parent, plants, ignoreDistance)
    local character = LocalPlayer.Character or WaitForCharacter()
    local playerPos = character:GetPivot().Position

    for _, plant in ipairs(parent:GetChildren()) do
        local fruits = plant:FindFirstChild("Fruits")
        if fruits then
            CollectHarvestable(fruits, plants, ignoreDistance)
        end

        local plantPos = plant:GetPivot().Position
        local distance = (playerPos - plantPos).Magnitude
        if not ignoreDistance and distance > 15 then continue end

        local variant = plant:FindFirstChild("Variant")
        if variant and HarvestIgnores[variant.Value] then continue end

        if CanHarvest(plant) then
            table.insert(plants, plant)
        end
    end
    return plants
end

local function GetHarvestablePlants(ignoreDistance)
    local plants = {}
    CollectHarvestable(PlantsPhysical, plants, ignoreDistance)
    return plants
end

local function HarvestPlants()
    local plants = GetHarvestablePlants()
    for _, plant in ipairs(plants) do
        HarvestPlant(plant)
        wait(0.1)
    end
end

local function AutoSellCheck()
    local crops = GetInvCrops()
    if not AutoSell or not AutoSell.Value then return end
    if #crops < SellThreshold.Value then return end
    SellInventory()
end

local function AutoWalkLoop()
    if SellInventory.IsRunning then return end

    local character = LocalPlayer.Character or WaitForCharacter()
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local plants = GetHarvestablePlants(true)
    local randomAllowed = AutoWalkAllowRandom and AutoWalkAllowRandom.Value
    local doRandom = (#plants == 0) or (math.random(1, 3) == 2)

    if randomAllowed and doRandom then
        local pos = GetRandomFarmPoint()
        humanoid:MoveTo(pos)
        if AutoWalkStatus then AutoWalkStatus.Text = "Random point" end
        return
    end

    for _, plant in ipairs(plants) do
        local pos = plant:GetPivot().Position
        humanoid:MoveTo(pos)
        if AutoWalkStatus then AutoWalkStatus.Text = plant.Name end
    end
end

local function NoclipLoop()
    local character = LocalPlayer.Character or WaitForCharacter()
    if not NoClip or not NoClip.Value then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

local function MakeLoop(toggle, func)
    coroutine.wrap(function()
        while true do
            wait(0.1)
            if toggle and toggle.Value then
                func()
            end
        end
    end)()
end

-- Wait for your farm to exist before continuing
print("[Init] Waiting for your farm to load...")
local MyFarm = nil
repeat
    MyFarm = GetFarm(LocalPlayer.Name)
    wait(1)
until MyFarm

print("[Init] Found your farm:", MyFarm.Name)

local MyImportant = MyFarm:WaitForChild("Important")
local PlantLocations = MyImportant:WaitForChild("Plant_Locations")
PlantsPhysical = MyImportant:WaitForChild("Plants_Physical")

local Dirt = PlantLocations:FindFirstChildOfClass("Part")
X1, Z1, X2, Z2 = GetArea(Dirt)

local function GetRandomFarmPoint()
    local farmLands = PlantLocations:GetChildren()
    local farmLand = farmLands[math.random(1, #farmLands)]
    local x1, z1, x2, z2 = GetArea(farmLand)
    local x = math.random(x1, x2)
    local z = math.random(z1, z2)
    return Vector3.new(x, 4, z)
end

local function GetInvCrops()
    local character = LocalPlayer.Character or WaitForCharacter()
    local crops = {}
    local function collectCropsFromParent(parent)
        for _, tool in ipairs(parent:GetChildren()) do
            local itemString = tool:FindFirstChild("Item_String")
            if itemString then
                table.insert(crops, tool)
            end
        end
    end
    collectCropsFromParent(Backpack)
    collectCropsFromParent(character)
    return crops
end

local function GetSeedStock(ignoreNoStock)
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
        if ignoreNoStock then
            if stockCount <= 0 then continue end
            newList[item.Name] = stockCount
        else
            SeedStock[item.Name] = stockCount
        end
    end

    return ignoreNoStock and newList or SeedStock
end

-- UI Setup
local Window = ReGui:Window({
    Title = string.format("%s | Depso", GameInfo.Name),
    Theme = "GardenTheme",
    Size = UDim2.fromOffset(350, 250)
})

-- Auto-Plant
local PlantNode = Window:TreeNode({ Title = "Auto-Plant 🥕" })
SelectedSeed = PlantNode:Combo({
    Label = "Seed",
    Selected = "",
    GetItems = function() GetOwnedSeeds(); local items = {}; for k,v in pairs(OwnedSeeds) do items[k] = v.Count end; return items end,
})
AutoPlant = PlantNode:Checkbox({ Value = true, Label = "Enabled" })
AutoPlantRandom = PlantNode:Checkbox({ Value = false, Label = "Plant at random points" })
PlantNode:Button({ Text = "Plant all", Callback = AutoPlantLoop })

-- Auto-Harvest
local HarvestNode = Window:TreeNode({ Title = "Auto-Harvest 🚜" })
AutoHarvest = HarvestNode:Checkbox({ Value = true, Label = "Enabled" })
HarvestNode:Separator({ Text = "Ignores:" })
for k, v in pairs(HarvestIgnores) do
    HarvestNode:Checkbox({
        Value = v,
        Label = k,
        Callback = function(_, val) HarvestIgnores[k] = val end,
    })
end

-- Auto-Buy (Improved)
local BuyNode = Window:TreeNode({ Title = "Auto-Buy 🥕" })
SelectedSeedStock = BuyNode:Combo({
    Label = "Seed",
    Selected = "",
    GetItems = function()
        local onlyStock = OnlyShowStock and OnlyShowStock.Value
        return GetSeedStock(onlyStock)
    end,
})

AutoBuy = BuyNode:Checkbox({ Value = false, Label = "Auto-buy enabled" })
OnlyShowStock = BuyNode:Checkbox({ Value = true, Label = "Only show seeds with stock" })

-- New controls for better buying
BuyAmount = BuyNode:SliderInt({
    Label = "Buy amount",
    Value = 10,
    Minimum = 1,
    Maximum = 100,
})

AutoBuyDelay = BuyNode:SliderInt({
    Label = "Buy delay (ms)",
    Value = 500,
    Minimum = 100,
    Maximum = 2000,
})

BuyNode:Button({ Text = "Buy selected amount", Callback = BuyAllSelectedSeeds })
BuyNode:Button({ 
    Text = "Buy ALL stock", 
    Callback = function()
        local seed = SelectedSeedStock and SelectedSeedStock.Selected
        if not seed or seed == "" then return end
        GetSeedStock()
        local stock = SeedStock[seed] or 0
        if stock > 0 then
            local oldValue = BuyAmount.Value
            BuyAmount.Value = stock
            BuyAllSelectedSeeds()
            BuyAmount.Value = oldValue
        end
    end 
})

-- Auto-Sell
local SellNode = Window:TreeNode({ Title = "Auto-Sell 💰" })
SellNode:Button({ Text = "Sell inventory", Callback = SellInventory })
AutoSell = SellNode:Checkbox({ Value = true, Label = "Enabled" })
SellThreshold = SellNode:SliderInt({
    Label = "Crops threshold",
    Value = 15,
    Minimum = 1,
    Maximum = 199,
})

-- Auto-Walk
local WalkNode = Window:TreeNode({ Title = "Auto-Walk 🚶" })
AutoWalkStatus = WalkNode:Label({ Text = "None" })
AutoWalk = WalkNode:Checkbox({ Value = true, Label = "Enabled" })
AutoWalkAllowRandom = WalkNode:Checkbox({ Value = true, Label = "Allow random points" })
NoClip = WalkNode:Checkbox({ Value = false, Label = "NoClip" })
AutoWalkMaxWait = WalkNode:SliderInt({
    Label = "Max delay",
    Value = 10,
    Minimum = 1,
    Maximum = 120,
})

-- Connect events
RunService.Stepped:Connect(NoclipLoop)
Backpack.ChildAdded:Connect(AutoSellCheck)

-- Start loops
MakeLoop(AutoWalk, function()
    local maxWait = AutoWalkMaxWait and AutoWalkMaxWait.Value or 10
    AutoWalkLoop()
    wait(math.random(1, maxWait))
end)

MakeLoop(AutoHarvest, HarvestPlants)
MakeLoop(AutoBuy, AutoBuyLoop) -- Now uses the improved auto-buy loop
MakeLoop(AutoPlant, AutoPlantLoop)

print("[Script] Auto-farm script loaded and running with improved auto-buy functionality.")

--[[ 
IMPROVEMENTS MADE TO AUTO-BUY:
1. Added BuyAmount slider to control how many seeds to buy
2. Added AutoBuyDelay slider to control delay between purchases
3. Improved BuyAllSelectedSeeds() function with better error handling
4. Added "Buy ALL stock" button to buy entire available stock
5. Auto-buy now only triggers when you have less than 10 seeds
6. Better stock checking and validation
7. Improved UI layout and controls
]]