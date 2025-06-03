-- Memuat library Rayfield dan membuat jendela utama
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "HXEL",
    LoadingTitle = "HXEL Menyala",
    LoadingSubtitle = "Delta Executor"
})

-- ─── TAB "Stats" ────────────────────────────────────────────────────────────
local StatsTab = Window:CreateTab("Stats", nil)
StatsTab:CreateSection("User Stats")

-- Buat tiga label: Koordinat, Money, dan Touch Player
local coordLabel = StatsTab:CreateLabel("Koordinat: Memuat...")
local moneyLabel = StatsTab:CreateLabel("Money: Memuat...")
local touchLabel = StatsTab:CreateLabel("Touch Player: Belum ada")

-- 1) Pembaruan real‐time Koordinat (setiap frame)
do
    local RunService = game:GetService("RunService")
    local Players    = game:GetService("Players")
    local player     = Players.LocalPlayer

    RunService.RenderStepped:Connect(function()
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local pos = char.HumanoidRootPart.Position
            local x, y, z = math.floor(pos.X), math.floor(pos.Y), math.floor(pos.Z)
            coordLabel:Set(string.format("Koordinat: %d, %d, %d", x, y, z))
        else
            coordLabel:Set("Koordinat: (Tidak tersedia)")
        end
    end)
end

-- 2) Pembaruan Money via event Changed
do
    local Players = game:GetService("Players")
    local player  = Players.LocalPlayer

    local function bindMoneyStat(stat)
        moneyLabel:Set("Money: " .. tostring(stat.Value))
        stat.Changed:Connect(function(newVal)
            moneyLabel:Set("Money: " .. tostring(newVal))
        end)
    end

    if player:FindFirstChild("leaderstats") then
        local ls = player.leaderstats
        if ls:FindFirstChild("Money") then
            bindMoneyStat(ls.Money)
        end
    end
    player.ChildAdded:Connect(function(child)
        if child.Name == "leaderstats" then
            wait(0.1)
            local ls = player.leaderstats
            if ls:FindFirstChild("Money") then
                bindMoneyStat(ls.Money)
            end
        end
    end)
end

-- 3) Deteksi “Touch Player” pada HumanoidRootPart
do
    local Players = game:GetService("Players")
    local player  = Players.LocalPlayer

    local function connectTouch(rootPart)
        touchLabel:Set("Touch Player: Belum ada")
        rootPart.Touched:Connect(function(hit)
            local otherChar = hit.Parent
            if otherChar and otherChar ~= player.Character then
                local otherPlayer = Players:GetPlayerFromCharacter(otherChar)
                if otherPlayer then
                    touchLabel:Set("Touch Player: " .. otherPlayer.Name)
                end
            end
        end)
    end

    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        connectTouch(player.Character.HumanoidRootPart)
    end
    player.CharacterAdded:Connect(function(char)
        char:WaitForChild("HumanoidRootPart")
        connectTouch(char.HumanoidRootPart)
    end)
end

-- ─── TAB "Farm" (Auto Farm) ───────────────────────────────────────────
local Test1Tab = Window:CreateTab("Farm", nil)
Test1Tab:CreateSection("Farming Tab")
