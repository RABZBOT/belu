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
-- ─── TAB "test1" (Auto‐Farm + Auto‐Quest Level 1–20) ─────────────────────────
local Test1Tab = Window:CreateTab("test1", nil)
Test1Tab:CreateSection("Auto‐Farm + Auto‐Quest (Lv 1–20)")

-- Services
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player   = Players.LocalPlayer
local char     = player.Character or player.CharacterAdded:Wait()
local hrp      = char:WaitForChild("HumanoidRootPart")
local autoFarmEnabled = false

-- 1) Konfigurasi Quest (Bandit Quest)
local questNPCName   = "BanditQuestNPC"         -- ⬅️ Ganti jika di server Anda NPC quest memiliki nama lain
local questMobName   = "Bandit"                 -- ⬅️ Ganti jika mobs quest memiliki nama lain (biasanya "Bandit [Lv. X]")
local questType      = "Bandit"                 -- nama quest yang dikirim ke remote (sesuai string di server)
local questNPCModel  = workspace:FindFirstChild(questNPCName)    -- lokasi Quest NPC
local startQuestRemote  = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StartQuest")   -- ⬅️ Sesuaikan jika path/namanya berbeda
local finishQuestRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FinishQuest")  -- ⬅️ Sesuaikan jika path/namanya berbeda

-- 2) Konfigurasi Musuh (Folder dan Remote Attack)
local EnemiesFolder = workspace:FindFirstChild("Enemies") or workspace:FindFirstChild("EnemyModels")  -- ⬅️ Sesuaikan jika folder berbeda
local attackRemote  = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")                -- ⬅️ Remote untuk attack biasa (MeleeHit)

-- 3) Anti‐AFK
player.Idled:Connect(function()
    local vu = game:GetService("VirtualUser")
    vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    wait(1)
    vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

-- 4) Utility: Ambil level dan status quest pemain
local function getPlayerLevel()
    if player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Level") then
        return player.leaderstats.Level.Value
    end
    return 0
end

-- Periksa apakah pemain sedang punya quest aktif (rise BoolValue “InQuest” atau “Quest” di player)
-- Ini hanya contoh; sesuaikan kalau di server Anda berbeda
local function isQuestActive()
    -- Misal: ada Folder “Quests” di Player yang menyimpan nama quest dan progress
    if player:FindFirstChild("Quests") and player.Quests:FindFirstChild("CurrentQuest") then
        local cq = player.Quests.CurrentQuest
        if cq.Value ~= "" then
            return true
        end
    end
    return false
end

local function getQuestProgress()
    -- Ambil progress dan goal (misal di player.Quests.Progress & player.Quests.Goal)
    if player:FindFirstChild("Quests") then
        local qFolder = player.Quests
        if qFolder:FindFirstChild("Progress") and qFolder:FindFirstChild("Goal") then
            return qFolder.Progress.Value, qFolder.Goal.Value
        end
    end
    return 0, 0
end

-- 5) Menerima Quest (warp ke NPC + Invoke Remote)
local function acceptQuest()
    if not questNPCModel then return false end
    -- Warp ke dekat Quest NPC (±3 stud dari HumanoidRootPart NPC)
    local npcHRP = questNPCModel:FindFirstChild("HumanoidRootPart")
    if npcHRP then
        local dest = npcHRP.CFrame * CFrame.new(0, 0, 3)
        TweenService:Create(hrp, TweenInfo.new(0.4), {CFrame = dest}):Play()
        wait(0.45)
        -- Panggil remote untuk StartQuest
        pcall(function()
            startQuestRemote:InvokeServer(questType)
        end)
        wait(0.5)  -- beri waktu server memproses
        return true
    end
    return false
end

-- 6) Menyerahkan Quest (warp ke NPC + Invoke Remote Finish)
local function finishQuest()
    if not questNPCModel then return false end
    local npcHRP = questNPCModel:FindFirstChild("HumanoidRootPart")
    if npcHRP then
        local dest = npcHRP.CFrame * CFrame.new(0, 0, 3)
        TweenService:Create(hrp, TweenInfo.new(0.4), {CFrame = dest}):Play()
        wait(0.45)
        pcall(function()
            finishQuestRemote:InvokeServer(questType)
        end)
        wait(0.5)
        return true
    end
    return false
end

-- 7) Cari musuh quest (yang level ≤20 dan cocok nama “Bandit”)
local function getNearestQuestMob()
    if not EnemiesFolder then return nil end
    local nearest = nil
    local minDist = math.huge

    for _, enemy in ipairs(EnemiesFolder:GetChildren()) do
        if enemy:FindFirstChild("Humanoid") 
           and enemy:FindFirstChild("HumanoidRootPart") 
           and string.find(enemy.Name, questMobName) then
            local hum = enemy.Humanoid
            if hum.Health > 0 then
                -- Cek level musuh dari nama (mis: “Bandit [Lv. 3]”)
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

-- 8) Fungsi warp (reuse dari sebelumnya)
local function warpToCFrame(destCFrame)
    TweenService:Create(hrp, TweenInfo.new(0.3), {CFrame = destCFrame}):Play()
    wait(0.35)
end

-- 9) Fungsi menyerang satu mob quest hingga mati (dengan memperbesar hitbox & jarak aman)
local function farmQuestMob(enemyModel)
    if not enemyModel or not enemyModel:FindFirstChild("HumanoidRootPart") then return end
    local targetHRP = enemyModel.HumanoidRootPart

    -- Simpan ukuran asli dan coba perbesar hitbox
    local originalSize = nil
    local hitboxScaled = false
    if targetHRP:IsA("BasePart") then
        originalSize = targetHRP.Size
        pcall(function()
            targetHRP.Size = originalSize * 5
            hitboxScaled = true
        end)
    end

    -- Warp ke posisi 10 stud di belakang target (agar aman)
    local behindCFrame = targetHRP.CFrame * CFrame.new(0, 0, 10)
    warpToCFrame(behindCFrame)

    -- Loop serang sampai mati atau autoFarm dimatikan
    while enemyModel 
          and enemyModel:FindFirstChild("Humanoid") 
          and enemyModel.Humanoid.Health > 0 
          and autoFarmEnabled 
          and isQuestActive() do

        if targetHRP then
            pcall(function()
                attackRemote:InvokeServer("MeleeHit", enemyModel, targetHRP.CFrame, targetHRP)
            end)
        end
        wait(0.15)
    end

    -- Kembalikan ukuran hitbox semula
    if hitboxScaled and originalSize and targetHRP then
        pcall(function()
            targetHRP.Size = originalSize
        end)
    end

    wait(0.5)  -- beri waktu server memproses kenaikan progress & XP
end

-- 10) Loop utama Auto‐Farm + Auto‐Quest
spawn(function()
    while true do
        wait(0.5)

        if autoFarmEnabled then
            local lvl = getPlayerLevel()

            -- 10.a) Jika level sudah ≥20 → matikan Auto‐Farm
            if lvl >= 20 then
                autoFarmEnabled = false
                Test1Tab.Flags.AutoFarmToggle = false
                Test1Tab:CreateNotification({
                    Title   = "Auto‐Farm",
                    Content = "Level Anda telah mencapai 20. Proses Auto‐Farm dihentikan.",
                    Duration= 4
                })
                break
            end

            -- 10.b) Jika belum ada quest aktif → ambil quest
            if not isQuestActive() then
                -- Coba accept quest, jika gagal (NPC tidak ada), tunggu dan ulang
                local success = acceptQuest()
                if not success then
                    -- Misal jika NPC belum spawn / nama beda, tunggu 2 detik lalu ulang
                    wait(2)
                    continue
                else
                    -- Sukses menerima quest → tunggu 1 detik agar stat quest terbaca di player
                    wait(1)
                end
            end

            -- 10.c) Jika ada quest aktif → cek progress
            local progress, goal = getQuestProgress()
            -- Jika progress sudah ≥ goal → selesaikan quest
            if progress >= goal then
                finishQuest()
                -- Setelah selesai quest, tunggu 1 detik sebelum ambil quest ulang
                wait(1)
                continue
            end

            -- 10.d) Jika quest aktif & belum terpenuhi → cari & farm mob quest
            if isQuestActive() then
                local target = getNearestQuestMob()
                if target then
                    farmQuestMob(target)
                else
                    -- Jika mob belum muncul / belum ada di area → warp ke spawn area mob
                    -- Contoh: Bandit spawn area di “Bandit Island”. Sesuaikan CFrame ini jika perlu
                    local banditSpawnPoint = workspace:FindFirstChild("BanditIslandSpawn")  -- ⬅️ Ganti jika ada folder CFrame spawn mob
                    if banditSpawnPoint and banditSpawnPoint:IsA("BasePart") then
                        warpToCFrame(banditSpawnPoint.CFrame * CFrame.new(0, 5, 0))
                    end
                    wait(2)
                end
            end
        end
    end
end)

-- 11) Toggle di Rayfield untuk Enable/Disable Auto‐Farm + Auto‐Quest
Test1Tab:CreateToggle({
    Name     = "Enable Auto‐Farm+Quest (Lv 1–20)",
    Flag     = "AutoFarmToggle",
    Value    = false,
    Callback = function(value)
        autoFarmEnabled = value
        if autoFarmEnabled then
            Test1Tab:CreateNotification({
                Title   = "Auto‐Farm+Quest Dimulai",
                Content = "Mengambil dan menyelesaikan quest Bandit, membunuh musuh Lv ≤ 20 hingga level 20.",
                Duration= 3
            })
        else
            Test1Tab:CreateNotification({
                Title   = "Auto‐Farm+Quest Dihentikan",
                Content = "Script berhenti menjalankan quest/membunuh musuh.",
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

