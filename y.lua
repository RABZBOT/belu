-- Lengkapi dan perbaiki kode Rayfield: Infinite Jump otomatis di tab “test1”

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

-- ─── TAB "test1" (Auto-Farm Level 1–20) ────────────────────────────────────
local Test1Tab = Window:CreateTab("test1", nil)
Test1Tab:CreateSection("Auto-Farm Level 1–20")

-- Services yang dibutuhkan
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player   = Players.LocalPlayer
local char     = player.Character or player.CharacterAdded:Wait()
local hrp      = char:WaitForChild("HumanoidRootPart")
local autoFarmEnabled = false

-- Folder musuh di workspace (umumnya bernama "Enemies" atau "EnemyModels")
local EnemiesFolder = workspace:FindFirstChild("Enemies") or workspace:FindFirstChild("EnemyModels")

-- Remote untuk menyerang musuh (nama dan path bisa berbeda-beda versi)
local CommF_ = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")

-- Fungsi Anti-AFK
player.Idled:Connect(function()
    local vu = game:GetService("VirtualUser")
    vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    wait(1)
    vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

-- Utility: Ambil level pemain (asumsi ada leaderstats.Level)
local function getPlayerLevel()
    if player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Level") then
        return player.leaderstats.Level.Value
    end
    return 0
end

-- Cari musuh terdekat yang masih hidup (Humanoid > 0) dan level musuh ≤ 20
local function getNearestEnemy()
    if not EnemiesFolder then return nil end
    local nearest = nil
    local minDist = math.huge
    for _, enemy in ipairs(EnemiesFolder:GetChildren()) do
        if enemy:FindFirstChild("Humanoid") and enemy:FindFirstChild("HumanoidRootPart") then
            local hum = enemy.Humanoid
            if hum.Health > 0 then
                -- Cek level musuh dari nama (misal "Bandit [Lv. 3]")
                local lvl = 0
                local num = string.match(enemy.Name, "%[(?:Lv%.?%s?)(%d+)%]")
                if num then lvl = tonumber(num) end

                if lvl <= 20 then
                    local dist = (hrp.Position - enemy.HumanoidRootPart.Position).Magnitude
                    if dist < minDist then
                        minDist = dist
                        nearest = enemy
                    end
                end
            end
        end
    end
    return nearest
end

-- Fungsi warp dengan Tween (smooth)
local function warpToCFrame(destCFrame)
    TweenService:Create(hrp, TweenInfo.new(0.3), {CFrame = destCFrame}):Play()
    wait(0.35)
end

-- Fungsi untuk memperbesar hitbox (HumanoidRootPart) dan menyerang musuh hingga mati
local function farmEnemy(enemyModel)
    if not enemyModel or not enemyModel:FindFirstChild("HumanoidRootPart") then return end
    local targetHRP = enemyModel.HumanoidRootPart

    -- Simpan ukuran asli hitbox supaya nanti bisa dikembalikan
    local originalSize
    local hitboxScaled = false
    if targetHRP and targetHRP:IsA("BasePart") then
        originalSize = targetHRP.Size
        -- Coba perbesar ukuran HRP (hitbox) sebanyak 5x lipat
        pcall(function()
            targetHRP.Size = originalSize * 5
            hitboxScaled = true
        end)
    end

    -- Warp ke posisi sekitar 10 stud di belakang target (agar di luar jangkauan serangan musuh)
    if targetHRP then
        local behindCFrame = targetHRP.CFrame * CFrame.new(0, 0, 10)
        warpToCFrame(behindCFrame)
    end

    -- Loop menyerang sampai HP musuh habis atau autoFarm dimatikan
    while enemyModel 
          and enemyModel:FindFirstChild("Humanoid") 
          and enemyModel.Humanoid.Health > 0 
          and autoFarmEnabled do

        -- Jika masih ada HRP, panggil remote serang dari jauh
        if targetHRP then
            -- Mengirim permintaan serang: "MeleeHit" + model + CFrame + part
            pcall(function()
                CommF_:InvokeServer("MeleeHit", enemyModel, targetHRP.CFrame, targetHRP)
            end)
        end
        wait(0.15)
    end

    -- Setelah musuh mati (atau loop berhenti), kembalikan ukuran hitbox semula
    if hitboxScaled and targetHRP and originalSize then
        pcall(function()
            targetHRP.Size = originalSize
        end)
    end

    -- Tunggu sedikit agar server memproses XP/loot
    wait(0.5)
end

-- Loop utama Auto-Farm (dijalankan di ‘spawn’ agar tidak blocking UI)
spawn(function()
    while true do
        wait(0.5)
        if autoFarmEnabled then
            local lvl = getPlayerLevel()
            -- Jika level sudah ≥ 20, berhenti
            if lvl >= 20 then
                autoFarmEnabled = false
                Test1Tab.Flags.AutoFarmToggle = false
                Test1Tab:CreateNotification({
                    Title   = "Auto-Farm",
                    Content = "Level sudah mencapai 20, Auto-Farm dihentikan.",
                    Duration= 4
                })
                break
            end

            -- Cari musuh terdekat
            local target = getNearestEnemy()
            if target then
                farmEnemy(target)
            else
                -- Jika tak ada musuh, warp ke spawn agar muncul musuh baru
                local spawnCFrame = workspace:FindFirstChild("SpawnPoint") and workspace.SpawnPoint.CFrame
                if spawnCFrame then
                    warpToCFrame(spawnCFrame * CFrame.new(0, 5, 0))
                end
                wait(2)
            end
        end
    end
end)

-- Toggle di Rayfield untuk Enable/Disable Auto-Farm
Test1Tab:CreateToggle({
    Name     = "Enable Auto-Farm (Lv 1–20)",
    Flag     = "AutoFarmToggle",
    Value    = false,
    Callback = function(value)
        autoFarmEnabled = value
        if autoFarmEnabled then
            Test1Tab:CreateNotification({
                Title   = "Auto-Farm Dimulai",
                Content = "Memperbesar hitbox musuh dan menyerang dari jarak aman.",
                Duration= 3
            })
        else
            Test1Tab:CreateNotification({
                Title   = "Auto-Farm Dihentikan",
                Content = "Script berhenti membunuh musuh.",
                Duration= 3
            })
        end
    end
})


-- ─── TAB "test2" ───────────────────────────────────────────────────────────
local Test2Tab = Window:CreateTab("test2", nil)
Test2Tab:CreateSection("Teleport Ketinggian")

-- Tombol Teleport +1000Y
Test2Tab:CreateButton({
    Name = "Teleport +1000Y",
    Callback = function()
        local player = game:GetService("Players").LocalPlayer
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local root = player.Character.HumanoidRootPart
            local pos = root.Position
            root.CFrame = CFrame.new(pos.X, pos.Y + 1000, pos.Z)
        end
    end
})

-- Tombol Teleport +5000Y
Test2Tab:CreateButton({
    Name = "Teleport +5000Y",
    Callback = function()
        local player = game:GetService("Players").LocalPlayer
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local root = player.Character.HumanoidRootPart
            local pos = root.Position
            root.CFrame = CFrame.new(pos.X, pos.Y + 5000, pos.Z)
        end
    end
})

-- Tombol Teleport +10000Y
Test2Tab:CreateButton({
    Name = "Teleport +10000Y",
    Callback = function()
        local player = game:GetService("Players").LocalPlayer
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local root = player.Character.HumanoidRootPart
            local pos = root.Position
            root.CFrame = CFrame.new(pos.X, pos.Y + 10000, pos.Z)
        end
    end
})

-- Tombol Teleport +1000Z
Test2Tab:CreateButton({
    Name = "Teleport +1000Z",
    Callback = function()
        local player = game:GetService("Players").LocalPlayer
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local root = player.Character.HumanoidRootPart
            local pos = root.Position
            root.CFrame = CFrame.new(pos.X, pos.Y, pos.Z + 1000)
        end
    end
})

-- Tambahkan di bawah pembuatan tab “test2” untuk membuat tab “NoClip”

-- ─── TAB "NoClip" ────────────────────────────────────────────────────────────
local NoClipTab = Window:CreateTab("NoClip", nil)
NoClipTab:CreateSection("NoClip Controls")

-- State untuk NoClip
local noclipEnabled = false

-- Toggle untuk mengaktifkan atau menonaktifkan NoClip
NoClipTab:CreateToggle({
    Name     = "Enable NoClip",
    Flag     = "NoClipToggle",
    Value    = false,
    Callback = function(value)
        noclipEnabled = value
        if not noclipEnabled then
            -- Saat dinonaktifkan, kembalikan CanCollide ke true untuk semua bagian karakter
            local player = game:GetService("Players").LocalPlayer
            if player.Character then
                for _, part in ipairs(player.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = true
                    end
                end
            end
        end
    end
})

-- Loop NoClip: setiap frame, jika diaktifkan, matikan CanCollide semua bagian karakter
do
    local RunService = game:GetService("RunService")
    local Players    = game:GetService("Players")
    local player     = Players.LocalPlayer

    RunService.Stepped:Connect(function()
        if not noclipEnabled then return end
        if player.Character then
            for _, part in ipairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end)
end

local Test3Tab = Window:CreateTab("test3", nil)
Test3Tab:CreateSection("Farm")

