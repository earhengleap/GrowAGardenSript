-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GardenGui"
screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

-- Create Button
local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 150, 0, 50)
button.Position = UDim2.new(0, 20, 0, 20)
button.Text = "Grow Garden"
button.Parent = screenGui

-- Growth function
local function growSeed()
    local seed = Instance.new("Part")
    seed.Size = Vector3.new(1, 0.2, 1)
    seed.Position = Vector3.new(0, 5, 0)
    seed.Anchored = true
    seed.BrickColor = BrickColor.new("Brown")
    seed.Name = "Seed"
    seed.Parent = workspace

    local growTime = 10
    local startSize = seed.Size
    local endSize = Vector3.new(3, 5, 3)
    local startColor = Color3.fromRGB(139, 69, 19)
    local endColor = Color3.fromRGB(34, 139, 34)
    local startTick = tick()

    local function lerp(a, b, t)
        return a + (b - a) * t
    end

    while true do
        local elapsed = tick() - startTick
        local t = math.min(elapsed / growTime, 1)

        seed.Size = Vector3.new(
            lerp(startSize.X, endSize.X, t),
            lerp(startSize.Y, endSize.Y, t),
            lerp(startSize.Z, endSize.Z, t)
        )
        seed.BrickColor = BrickColor.new(startColor:lerp(endColor, t))

        if t >= 1 then
            print("Plant fully grown!")
            break
        end
        wait(0.1)
    end
end

-- Connect button click to growSeed
button.MouseButton1Click:Connect(growSeed)
