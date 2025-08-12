-- Grow a Garden ESP + Reroll - Made by Lae Scripts
-- ✅ Updated with Bee Eggs, Anti-Bee Eggs, and Visual Reroll

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local character = player.Character or player:WaitForChild("CharacterAdded"):Wait()

-- ✅ OFFICIAL EGG & PET DATA (Jandel's Grow a Garden)
local eggData = {
    -- Common Eggs
    ["Common Egg"] = {
        color = Color3.fromRGB(100, 255, 100), -- Bright Green
        pets = {"Golden Lab", "Dog", "Bunny"},
        rarity = "Common"
    },
    ["Common Summer Egg"] = {
        color = Color3.fromRGB(0, 200, 255), -- Light Blue
        pets = {"Starfish", "Seagull", "Crab"},
        rarity = "Common"
    },

    -- Uncommon Eggs
    ["Uncommon Egg"] = {
        color = Color3.fromRGB(170, 0, 255), -- Purple
        pets = {"Black Bunny", "Chicken", "Cat", "Deer"},
        rarity = "Uncommon"
    },

    -- Rare Eggs
    ["Rare Egg"] = {
        color = Color3.fromRGB(255, 170, 0), -- Orange
        pets = {"Orange Tabby", "Spotted Deer", "Pig", "Rooster", "Monkey"},
        rarity = "Rare"
    },
    ["Rare Summer Egg"] = {
        color = Color3.fromRGB(255, 0, 170), -- Pink
        pets = {"Flamingo", "Toucan", "Sea Turtle", "Orangutan", "Seal"},
        rarity = "Rare"
    },

    -- Legendary Eggs
    ["Legendary Egg"] = {
        color = Color3.fromRGB(255, 215, 0), -- Gold
        pets = {"Cow", "Silver Monkey", "Sea Otter", "Turtle", "Polar Bear"},
        rarity = "Legendary"
    },

    -- Mythical Eggs
    ["Mythical Egg"] = {
        color = Color3.fromRGB(255, 0, 0), -- Red
        pets = {"Grey Mouse", "Brown Mouse", "Squirrel", "Red Giant Ant", "Red Fox"},
        rarity = "Mythical"
    },

    -- Divine/Event Eggs
    ["Bug Egg"] = {
        color = Color3.fromRGB(100, 0, 100), -- Dark Purple
        pets = {"Snail", "Giant Ant", "Caterpillar", "Praying Mantis", "Dragonfly"},
        rarity = "Divine"
    },
    ["Paradise Egg"] = {
        color = Color3.fromRGB(0, 255, 255), -- Cyan
        pets = {"Ostrich", "Peacock", "Capybara", "Scarlet Macaw", "Mimic Octopus"},
        rarity = "Divine"
    },
    ["Dinosaur Egg"] = {
        color = Color3.fromRGB(150, 75, 0), -- Brown
        pets = {"Raptor", "Triceratops", "Stegosaurus", "Pterodactyl", "Brontosaurus", "T-Rex"},
        rarity = "Divine"
    },
    ["Night Egg"] = {
        color = Color3.fromRGB(0, 0, 100), -- Dark Blue
        pets = {"Hedgehog", "Mole", "Frog", "Echo Frog", "Night Owl", "Raccoon"},
        rarity = "Divine"
    },
    ["Bee Egg"] = {
        color = Color3.fromRGB(255, 255, 0), -- Yellow
        pets = {"Bee", "Honey Bee", "Bear Bee", "Petal Bee", "Queen Bee"},
        rarity = "Event"
    },
    ["Anti-Bee Egg"] = {
        color = Color3.fromRGB(255, 0, 255), -- Magenta
        pets = {"Wasp", "Tarantula Hawk", "Moth", "Butterfly", "Disco Bee"},
        rarity = "Robux"
    }
}

-- Egg ESP for ready-to-hatch eggs
local function createEggESP()
    local eggsFolder = Workspace:WaitForChild("Eggs")
    
    local function addESP(egg)
        if not egg:FindFirstChild("Ready") or not egg.Ready.Value then
            return -- Only show ESP for ready-to-hatch eggs
        end
        
        -- Remove existing ESP if it exists
        if egg:FindFirstChild("LaeESP_Highlight") then
            egg.LaeESP_Highlight:Destroy()
        end
        if egg:FindFirstChild("LaeESP_Billboard") then
            egg.LaeESP_Billboard:Destroy()
        end
        
        local highlight = Instance.new("Highlight")
        highlight.Name = "LaeESP_Highlight"
        highlight.Parent = egg
        highlight.Adornee = egg
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        
        -- Find matching egg data
        local eggName = egg.Name
        local foundData = nil
        
        for eggType, data in pairs(eggData) do
            if eggName:find(eggType) then
                foundData = data
                break
            end
        end
        
        -- Set color based on egg rarity
        if foundData then
            highlight.FillColor = foundData.color
            highlight.OutlineColor = foundData.color:Lerp(Color3.new(0,0,0), 0.5)
            
            -- Create billboard with possible pets
            local billboard = Instance.new("BillboardGui")
            billboard.Name = "LaeESP_Billboard"
            billboard.Parent = egg
            billboard.Adornee = egg.PrimaryPart or egg:FindFirstChild("HumanoidRootPart") or egg:WaitForChild("Head")
            billboard.Size = UDim2.new(6, 0, 2.5, 0)
            billboard.StudsOffset = Vector3.new(0, 3, 0)
            billboard.AlwaysOnTop = true
            
            local textLabel = Instance.new("TextLabel")
            textLabel.Parent = billboard
            textLabel.Size = UDim2.new(1, 0, 1, 0)
            textLabel.BackgroundTransparency = 1
            textLabel.TextColor3 = Color3.new(1, 1, 1)
            textLabel.TextStrokeTransparency = 0
            textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
            textLabel.Text = "🔄 "..eggName.."\n🎲 "..foundData.rarity.."\n🐾 Pets: "..table.concat(foundData.pets, ", ")
            textLabel.Font = Enum.Font.SourceSansBold
            textLabel.TextScaled = true
        else
            -- Default color for unknown eggs
            highlight.FillColor = Color3.fromRGB(255, 255, 255)
            highlight.OutlineColor = Color3.fromRGB(150, 150, 150)
        end
    end
    
    -- Add ESP to existing ready eggs
    for _, egg in pairs(eggsFolder:GetChildren()) do
        if egg:IsA("Model") then
            addESP(egg)
        end
    end
    
    -- Listen for new eggs
    eggsFolder.ChildAdded:Connect(function(egg)
        if egg:IsA("Model") then
            -- Check when egg becomes ready
            local readyValue = egg:WaitForChild("Ready", 10)
            if readyValue then
                readyValue:GetPropertyChangedSignal("Value"):Connect(function()
                    if readyValue.Value then
                        addESP(egg)
                    end
                end)
                
                -- Check initial value
                if readyValue.Value then
                    addESP(egg)
                end
            end
        end
    end)
end

-- Visual Pet Reroll (Forces rarest pet)
local function rerollPets()
    local petsFolder = player:WaitForChild("Pets")
    local remotePath = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RerollPet")
    
    -- Get pet rarity order (rarest first)
    local rarityOrder = {
        "Divine", "Robux", "Event", "Mythical", 
        "Legendary", "Rare", "Uncommon", "Common"
    }
    
    local function getPetRarity(pet)
        for eggType, data in pairs(eggData) do
            if table.find(data.pets, pet.Name) then
                return data.rarity
            end
        end
        return "Common"
    end
    
    local function rerollToRarest()
        for _, pet in pairs(petsFolder:GetChildren()) do
            local currentRarity = getPetRarity(pet)
            local currentIndex = table.find(rarityOrder, currentRarity) or #rarityOrder
            
            -- Only reroll if not already rarest possible
            if currentIndex > 1 then
                remotePath:FireServer(pet)
                
                -- Visual effect
                local highlight = Instance.new("Highlight")
                highlight.Parent = pet
                highlight.FillColor = Color3.fromRGB(0, 255, 0)
                highlight.OutlineColor = Color3.fromRGB(0, 200, 0)
                game:GetService("Debris"):AddItem(highlight, 1)
                
                print("Rerolled "..pet.Name.." (was "..currentRarity..")")
            end
        end
    end
    
    return rerollToRarest
end

-- Minimal GUI
local function createGUI()
    local ScreenGui = Instance.new("ScreenGui")
    local Frame = Instance.new("Frame")
    local Title = Instance.new("TextLabel")
    local ESPToggle = Instance.new("TextButton")
    local RerollToggle = Instance.new("TextButton")
    local Credit = Instance.new("TextLabel")
    
    ScreenGui.Parent = player:WaitForChild("PlayerGui")
    ScreenGui.Name = "GardenESP"
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    Frame.Parent = ScreenGui
    Frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Frame.BackgroundTransparency = 0.3
    Frame.Position = UDim2.new(0.8, 0, 0.7, 0)
    Frame.Size = UDim2.new(0, 200, 0, 120)
    Frame.Active = true
    Frame.Draggable = true
    
    Title.Parent = Frame
    Title.Text = "Grow a Garden ESP"
    Title.BackgroundTransparency = 1
    Title.Size = UDim2.new(1, 0, 0, 25)
    Title.TextColor3 = Color3.new(1, 1, 1)
    Title.Font = Enum.Font.SourceSansBold
    
    ESPToggle.Parent = Frame
    ESPToggle.Text = "TOGGLE EGG ESP"
    ESPToggle.Position = UDim2.new(0.1, 0, 0.25, 0)
    ESPToggle.Size = UDim2.new(0.8, 0, 0.25, 0)
    ESPToggle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    ESPToggle.TextColor3 = Color3.new(1, 1, 1)
    ESPToggle.MouseButton1Click:Connect(createEggESP)
    
    RerollToggle.Parent = Frame
    RerollToggle.Text = "REROLL TO RAREST"
    RerollToggle.Position = UDim2.new(0.1, 0, 0.55, 0)
    RerollToggle.Size = UDim2.new(0.8, 0, 0.25, 0)
    RerollToggle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    RerollToggle.TextColor3 = Color3.new(1, 1, 1)
    RerollToggle.MouseButton1Click:Connect(rerollPets())
    
    Credit.Parent = Frame
    Credit.Text = "Made by Lae Scripts"
    Credit.BackgroundTransparency = 1
    Credit.Position = UDim2.new(0, 0, 0.85, 0)
    Credit.Size = UDim2.new(1, 0, 0.15, 0)
    Credit.TextColor3 = Color3.new(1, 1, 1)
    Credit.Font = Enum.Font.SourceSans
    Credit.TextSize = 14
end

-- Initialize
createGUI()
print("Grow a Garden ESP + Reroll loaded! - Made by Lae Scripts")