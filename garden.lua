--[[ 
    Grow a Garden auto-farm script 
    Author: depso (depthso)
    Updated for stability and KRNL usage
]]

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Backpack = LocalPlayer:WaitForChild("Backpack")
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Use a function to get leaderstats safely in case it refreshes
local function GetShecklesCount()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        local sheckles = leaderstats:FindFirstChild("Sheckles")
        if sheckles then return sheckles end
    end
    return nil
end

local GameInfo = MarketplaceService:GetProductInfo(game.PlaceId)

--// ReGui UI library (make sure URL works and is accessible)
local ReGui = loadstring(game:HttpGet('https://raw.githubusercontent.com/depthso/Dear-ReGui/refs/heads/main/ReGui.lua'))()
local PrefabsId = "rbxassetid://" .. ReGui.PrefabsId

--// Folders and events
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local Farms = workspace:WaitForChild("Farm")

-- Colors for UI
local Accent = {
    DarkGreen = Color3.fromRGB(45, 95, 25),
    Green = Color3.fromRGB(69, 142, 40),
    Brown = Color3.fromRGB(26, 20, 8),
}

--// ReGui initialization
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

--// Globals
local SeedStock = {}
local OwnedSeeds = {}
local HarvestIgnores = {
	Normal = false,
	Gold = false,
	Rainbow = false
}

local SelectedSeed, AutoPlantRandom, AutoPlant, AutoHarvest, AutoBuy, SellThreshold, NoClip, AutoWalkAllowRandom, AutoSell, AutoWalk, AutoWalkMaxWait, AutoWalkStatus, SelectedSeedStock

local IsSelling = false

--// Functions --

local function Plant(Position: Vector3, Seed: string)
	GameEvents:WaitForChild("Plant_RE"):FireServer(Position, Seed)
	wait(0.3)
end

local function GetFarms()
	return Farms:GetChildren()
end

local function GetFarmOwner(Farm: Folder): string
	local Important = Farm:FindFirstChild("Important")
	if not Important then return nil end
	local Data = Important:FindFirstChild("Data")
	if not Data then return nil end
	local Owner = Data:FindFirstChild("Owner")
	if not Owner then return nil end
	return Owner.Value
end

local function GetFarm(PlayerName: string)
	local FarmsList = GetFarms()
	for _, Farm in ipairs(FarmsList) do
		local Owner = GetFarmOwner(Farm)
		if Owner == PlayerName then
			return Farm
		end
	end
	return nil
end

local function SellInventory()
	if IsSelling then return end
	IsSelling = true

	local Character = LocalPlayer.Character
	if not Character then IsSelling = false return end

	local PrevCFrame = Character:GetPivot()
	local ShecklesCount = GetShecklesCount()
	if not ShecklesCount then IsSelling = false return end

	local PrevSheckles = ShecklesCount.Value

	Character:PivotTo(CFrame.new(62, 4, -26))
	while wait(0.1) do
		if ShecklesCount.Value ~= PrevSheckles then break end
		GameEvents:WaitForChild("Sell_Inventory"):FireServer()
	end
	Character:PivotTo(PrevCFrame)
	wait(0.2)
	IsSelling = false
end

local function BuySeed(Seed: string)
	GameEvents:WaitForChild("BuySeedStock"):FireServer(Seed)
end

local function BuyAllSelectedSeeds()
    if not SelectedSeedStock then return end
    local Seed = SelectedSeedStock.Selected
    if not Seed then return end
    local Stock = SeedStock[Seed]

	if not Stock or Stock <= 0 then return end

    for i = 1, Stock do
        BuySeed(Seed)
    end
end

local function GetSeedInfo(Seed: Tool)
	local PlantName = Seed:FindFirstChild("Plant_Name")
	local Count = Seed:FindFirstChild("Numbers")
	if not PlantName or not Count then return nil end
	return PlantName.Value, Count.Value
end

local function CollectSeedsFromParent(Parent, Seeds)
	for _, Tool in ipairs(Parent:GetChildren()) do
		local Name, Count = GetSeedInfo(Tool)
		if not Name then continue end

		Seeds[Name] = {
            Count = Count,
            Tool = Tool
        }
	end
end

local function CollectCropsFromParent(Parent, Crops)
	for _, Tool in ipairs(Parent:GetChildren()) do
		local Name = Tool:FindFirstChild("Item_String")
		if not Name then continue end
		table.insert(Crops, Tool)
	end
end

local function GetOwnedSeeds()
	OwnedSeeds = {} -- reset each time
	local Character = LocalPlayer.Character
	if Character then
		CollectSeedsFromParent(Character, OwnedSeeds)
	end
	CollectSeedsFromParent(Backpack, OwnedSeeds)
	return OwnedSeeds
end

local function GetInvCrops()
	local Crops = {}
	local Character = LocalPlayer.Character
	if Character then
		CollectCropsFromParent(Character, Crops)
	end
	CollectCropsFromParent(Backpack, Crops)
	return Crops
end

local function GetArea(Base: BasePart)
	local Center = Base:GetPivot()
	local Size = Base.Size

	local X1 = math.ceil(Center.X - (Size.X / 2))
	local Z1 = math.ceil(Center.Z - (Size.Z / 2))

	local X2 = math.floor(Center.X + (Size.X / 2))
	local Z2 = math.floor(Center.Z + (Size.Z / 2))

	return X1, Z1, X2, Z2
end

local function EquipCheck(Tool)
    local Character = LocalPlayer.Character
	if not Character then return end
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then return end

    if Tool.Parent ~= Backpack then
		return
	end
    Humanoid:EquipTool(Tool)
end

local MyFarm = GetFarm(LocalPlayer.Name)
if not MyFarm then
	warn("Could not find your farm!")
	return
end

local MyImportant = MyFarm:FindFirstChild("Important")
if not MyImportant then
	warn("Could not find Important folder inside your farm!")
	return
end

local PlantLocations = MyImportant:FindFirstChild("Plant_Locations")
local PlantsPhysical = MyImportant:FindFirstChild("Plants_Physical")

if not PlantLocations or not PlantsPhysical then
	warn("Could not find Plant_Locations or Plants_Physical")
	return
end

local Dirt = PlantLocations:FindFirstChildOfClass("Part")
if not Dirt then
	warn("Could not find any Part inside Plant_Locations")
	return
end

local X1, Z1, X2, Z2 = GetArea(Dirt)

local function GetRandomFarmPoint()
    local FarmLands = PlantLocations:GetChildren()
    local FarmLand = FarmLands[math.random(1, #FarmLands)]
    local X1, Z1, X2, Z2 = GetArea(FarmLand)
    local X = math.random(X1, X2)
    local Z = math.random(Z1, Z2)
    return Vector3.new(X, 4, Z)
end

local function AutoPlantLoop()
	if not SelectedSeed or not SelectedSeed.Selected then return end
	local Seed = SelectedSeed.Selected

	local SeedData = OwnedSeeds[Seed]
	if not SeedData then return end

    local Count = SeedData.Count
    local Tool = SeedData.Tool

	if Count <= 0 then return end

	local Planted = 0
	local Step = 1

	EquipCheck(Tool)

	if AutoPlantRandom and AutoPlantRandom.Value then
		for i = 1, Count do
			local Point = GetRandomFarmPoint()
			Plant(Point, Seed)
		end
	end

	for X = X1, X2, Step do
		for Z = Z1, Z2, Step do
			if Planted > Count then break end
			local Point = Vector3.new(X, 0.13, Z)

			Planted += 1
			Plant(Point, Seed)
		end
	end
end

local function HarvestPlant(Plant: Model)
	local Prompt = Plant:FindFirstChildOfClass("ProximityPrompt")
	if not Prompt then return end
	fireproximityprompt(Prompt)
end

local function CanHarvest(Plant)
	local Prompt = Plant:FindFirstChildOfClass("ProximityPrompt")
	if not Prompt or not Prompt.Enabled then return false end
	return true
end

local function CollectHarvestable(Parent, Plants, IgnoreDistance)
	local Character = LocalPlayer.Character
	if not Character then return Plants end
	local PlayerPosition = Character:GetPivot().Position

	for _, Plant in ipairs(Parent:GetChildren()) do
		local Fruits = Plant:FindFirstChild("Fruits")
		if Fruits then
			CollectHarvestable(Fruits, Plants, IgnoreDistance)
		end

		local PlantPosition = Plant:GetPivot().Position
		local Distance = (PlayerPosition - PlantPosition).Magnitude
		if not IgnoreDistance and Distance > 15 then continue end

		local Variant = Plant:FindFirstChild("Variant")
		if Variant and HarvestIgnores[Variant.Value] then continue end

		if CanHarvest(Plant) then
			table.insert(Plants, Plant)
		end
	end
	return Plants
end

local function GetHarvestablePlants(IgnoreDistance)
	local Plants = {}
	return CollectHarvestable(PlantsPhysical, Plants, IgnoreDistance)
end

local function HarvestPlants()
	local Plants = GetHarvestablePlants()
	for _, Plant in ipairs(Plants) do
		HarvestPlant(Plant)
	end
end

local function AutoSellCheck()
	if not AutoSell or not AutoSell.Value then return end
	local CropCount = #GetInvCrops()
	if CropCount < (SellThreshold and SellThreshold.Value or 15) then return end
	SellInventory()
end

local function AutoWalkLoop()
	if IsSelling then return end
	local Character = LocalPlayer.Character
	if not Character then return end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then return end

	local Plants = GetHarvestablePlants(true)
	local RandomAllowed = AutoWalkAllowRandom and AutoWalkAllowRandom.Value
	local DoRandom = #Plants == 0 or math.random(1, 3) == 2

	if RandomAllowed and DoRandom then
		local Position = GetRandomFarmPoint()
		Humanoid:MoveTo(Position)
		if AutoWalkStatus then
			AutoWalkStatus.Text = "Random point"
		end
		return
	end

	for _, Plant in ipairs(Plants) do
		local Position = Plant:GetPivot().Position
		Humanoid:MoveTo(Position)
		if AutoWalkStatus then
			AutoWalkStatus.Text = Plant.Name
		end
	end
end

local function NoclipLoop()
	if not NoClip or not NoClip.Value then return end
	local Character = LocalPlayer.Character
	if not Character then return end

	for _, Part in ipairs(Character:GetDescendants()) do
		if Part:IsA("BasePart") then
			Part.CanCollide = false
		end
	end
end

local function MakeLoop(Toggle, Func)
	coroutine.wrap(function()
		while wait(0.01) do
			if not Toggle or not Toggle.Value then continue end
			Func()
		end
	end)()
end

local function StartServices()
	MakeLoop(AutoWalk, function()
		local MaxWait = AutoWalkMaxWait and AutoWalkMaxWait.Value or 10
		AutoWalkLoop()
		wait(math.random(1, MaxWait))
	end)

	MakeLoop(AutoHarvest, HarvestPlants)
	MakeLoop(AutoBuy, BuyAllSelectedSeeds)
	MakeLoop(AutoPlant, AutoPlantLoop)

	-- Stock update loop
	coroutine.wrap(function()
		while wait(0.1) do
			GetSeedStock()
			GetOwnedSeeds()
		end
	end)()
end

local function CreateCheckboxes(Parent, Dict)
	for Key, Value in pairs(Dict) do
		Parent:Checkbox({
			Value = Value,
			Label = Key,
			Callback = function(_, Val)
				Dict[Key] = Val
			end
		})
	end
end

--// Window
local Window = ReGui:Window({
	Title = string.format("%s | Depso", GameInfo.Name),
	Theme = "GardenTheme",
	Size = UDim2.fromOffset(300, 200)
})

--// Auto-Plant UI
local PlantNode = Window:TreeNode({Title = "Auto-Plant 🥕"})
SelectedSeed = PlantNode:Combo({
	Label = "Seed",
	Selected = "",
	GetItems = GetSeedStock,
})
AutoPlant = PlantNode:Checkbox({
	Value = false,
	Label = "Enabled"
})
AutoPlantRandom = PlantNode:Checkbox({
	Value = false,
	Label = "Plant at random points"
})
PlantNode:Button({
	Text = "Plant all",
	Callback = AutoPlantLoop,
})

--// Auto-Harvest UI
local HarvestNode = Window:TreeNode({Title = "Auto-Harvest 🚜"})
AutoHarvest = HarvestNode:Checkbox({
	Value = false,
	Label = "Enabled"
})
HarvestNode:Separator({Text = "Ignores:"})
CreateCheckboxes(HarvestNode, HarvestIgnores)

--// Auto-Buy UI
local BuyNode = Window:TreeNode({Title = "Auto-Buy 🥕"})
SelectedSeedStock = BuyNode:Combo({
	Label = "Seed",
	Selected = "",
	GetItems = function()
		local OnlyStock = OnlyShowStock and OnlyShowStock.Value
		return GetSeedStock(OnlyStock)
	end,
})
AutoBuy = BuyNode:Checkbox({
	Value = false,
	Label = "Enabled"
})

local OnlyShowStock
OnlyShowStock = BuyNode:Checkbox({
	Value = false,
	Label = "Only list stock"
})

BuyNode:Button({
	Text = "Buy all",
	Callback = BuyAllSelectedSeeds,
})

--// Auto-Sell UI
local SellNode = Window:TreeNode({Title = "Auto-Sell 💰"})
SellNode:Button({
	Text = "Sell inventory",
	Callback = SellInventory,
})
AutoSell = SellNode:Checkbox({
	Value = false,
	Label = "Enabled"
})
SellThreshold = SellNode:SliderInt({
	Label = "Crops threshold",
	Value = 15,
	Minimum = 1,
	Maximum = 199,
})

--// Auto-Walk UI
local WalkNode = Window:TreeNode({Title = "Auto-Walk 🚶"})
AutoWalkStatus = WalkNode:Label({
	Text = "None"
})
AutoWalk = WalkNode:Checkbox({
	Value = false,
	Label = "Enabled"
})
AutoWalkAllowRandom = WalkNode:Checkbox({
	Value = true,
	Label = "Allow random points"
})
NoClip = WalkNode:Checkbox({
	Value = false,
	Label = "NoClip"
})
AutoWalkMaxWait = WalkNode:SliderInt({
	Label = "Max delay",
	Value = 10,
	Minimum = 1,
	Maximum = 120,
})

--// Connections
RunService.Stepped:Connect(NoclipLoop)
Backpack.ChildAdded:Connect(AutoSellCheck)

--// Start all loops and services
StartServices()
