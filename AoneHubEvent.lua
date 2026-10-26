-- ==================================================================
-- HALLOWEEN 2026 EVENT SCRIPT (Final - Attribute Listener)
-- ==================================================================

local Context = _G.AoneHub_Event_Context
if not Context then return end

local Scroll = Context.Scroll
local createSection = Context.CreateSection
local C = Context.Colors

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local DataService = require(ReplicatedStorage.Modules.DataService)
local TeleportPlayer = require(ReplicatedStorage.Modules.TeleportPlayer)
local GetFarm = require(ReplicatedStorage.Modules.GetFarm)

local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local SellRemote = GameEvents:WaitForChild("Events"):WaitForChild("Halloween2026Event"):WaitForChild("HalloweenSellInventoryRE")

-- Helper UI
local function createBtn(parent, text, yPos, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 28)
    btn.Position = UDim2.new(0, 10, 0, yPos)
    btn.BackgroundColor3 = color or C.accent
    btn.Text = text
    btn.TextColor3 = C.text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 9
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function createStatusLbl(parent, text, yPos, height)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, height or 14)
    lbl.Position = UDim2.new(0, 10, 0, yPos)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = C.textDim
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 8
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextWrapped = true
    lbl.Parent = parent
    return lbl
end

-- ==================================================================
-- SECTION: SMART AUTO SELL
-- ==================================================================
local SellSection = createSection(Scroll, "🎃 Smart Auto-Sell", "eventAutoSell")
SellSection.LayoutOrder = 1
SellSection.Size = UDim2.new(1, -10, 0, 130)

local isEnabled = false            -- Apakah fitur aktif (dari tombol)
local isHalloweenMode = false      -- Apakah pemain sedang di Halloween Garden
local inventoryThread = nil        -- Thread khusus cek inventory
local aoneHubOriginalState = true  -- Simpan status autoSell AoneHub

local statusLbl = createStatusLbl(SellSection, "Status: Idle", 28, 30)

local function getFruitCapacity()
    local data = DataService:GetData()
    if not data or not data.InventoryData then return 0, 0 end
    local count = 0
    for _, item in pairs(data.InventoryData) do
        if item.ItemType == "Holdable" then count = count + 1 end
    end
    local bonus = Player:GetAttribute("BonusBackpackSize") or 0
    return count, 200 + bonus
end

local function getSinisterCFrame()
    local market = workspace:FindFirstChild("Interaction")
    if market then market = market:FindFirstChild("Halloween2026MarketModel") end
    if market then market = market:FindFirstChild("SinisterSteven", true) end
    if market then market = market:FindFirstChild("HumanoidRootPart") end
    if not (market and market:IsA("BasePart")) then return nil end
    
    local v21 = market.Position + market.CFrame.LookVector * 8
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { Player.Character }
    local ray = workspace:Raycast(v21 + Vector3.new(0, 2, 0), Vector3.new(0, -20, 0), params)
    local targetY = ray and (ray.Position.Y + 3) or v21.Y
    return CFrame.lookAt(Vector3.new(v21.X, targetY, v21.Z), Vector3.new(market.Position.X, targetY, market.Position.Z))
end

local function doHalloweenSell()
    statusLbl.Text = "⏳ Teleport ke Steven..."
    statusLbl.TextColor3 = C.warning
    
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local savedCFrame = hrp and hrp.CFrame
    
    local stevenCFrame = getSinisterCFrame()
    if not stevenCFrame then
        statusLbl.Text = "❌ Gagal temukan Steven!"
        statusLbl.TextColor3 = C.danger
        return
    end
    
    pcall(function() TeleportPlayer(Player, stevenCFrame, "Sinister Sales") end)
    task.wait(2.5)
    
    statusLbl.Text = "💰 Menjual..."
    SellRemote:FireServer()
    task.wait(3.5)
    
    statusLbl.Text = "🔙 Kembali..."
    if savedCFrame then
        pcall(function() TeleportPlayer(Player, savedCFrame, "Return") end)
    else
        local ok, farm = pcall(function() return GetFarm(Player) end)
        if ok and farm and farm:FindFirstChild("Spawn_Point") then
            pcall(function() TeleportPlayer(Player, farm.Spawn_Point.CFrame, "Farm") end)
        end
    end
    task.wait(2)
    statusLbl.Text = "✅ Selesai!"
    statusLbl.TextColor3 = C.success
end

-- ⭐ Thread yang HANYA berjalan saat di Halloween Garden
local function startInventoryMonitor()
    if inventoryThread then task.cancel(inventoryThread) end
    
    inventoryThread = task.spawn(function()
        while isEnabled and isHalloweenMode do
            local curr, max = getFruitCapacity()
            statusLbl.Text = string.format("🎃 Halloween | 📦 %d/%d", curr, max)
            statusLbl.TextColor3 = C.text
            
            if curr >= max then
                statusLbl.Text = "🚨 Penuh! Menjual..."
                statusLbl.TextColor3 = C.danger
                doHalloweenSell()
                task.wait(5) -- Jeda setelah jual
            end
            
            task.wait(2)
        end
    end)
end

local function stopInventoryMonitor()
    if inventoryThread then 
        task.cancel(inventoryThread)
        inventoryThread = nil
    end
end

-- ⭐ Fungsi Swap Mode (Dipanggil saat garden berubah)
local function updateMode()
    local slot = Player:GetAttribute("SelectedSlot")
    local newHalloweenMode = (slot == "HALLOWEEN_2026")
    
    if not isEnabled then
        isHalloweenMode = newHalloweenMode
        return
    end
    
    -- Jika mode TIDAK berubah, tidak perlu apa-apa
    if isHalloweenMode == newHalloweenMode then return end
    isHalloweenMode = newHalloweenMode
    
    if isHalloweenMode then
        -- 🎃 Masuk Halloween Mode
        if _G.AoneHub_SetAutoSellFruit then
            _G.AoneHub_SetAutoSellFruit(false) -- Matikan saat di Halloween
        end
        statusLbl.Text = "🎃 Mode Halloween aktif"
        startInventoryMonitor()
    else
        -- 🌱 Masuk Normal Mode
        if _G.AoneHub_SetAutoSellFruit then
            _G.AoneHub_SetAutoSellFruit(true) -- Nyalakan saat di Normal
        end
        stopInventoryMonitor()
        statusLbl.Text = "🌱 Mode Normal: Auto-Sell AoneHub aktif"
        statusLbl.TextColor3 = C.textDim
    end
end

-- ⭐ LISTENER UTAMA: Pantau perubahan garden secara real-time
Player:GetAttributeChangedSignal("SelectedSlot"):Connect(function()
    task.wait(0.5) -- Jeda agar map selesai load
    updateMode()
end)

-- ⭐ Tombol Toggle
local toggleBtn = createBtn(SellSection, "▶️ Aktifkan Smart Auto-Sell", 60, C.success, function()
    isEnabled = not isEnabled
    
    if isEnabled then
        toggleBtn.Text = "⏹️ Matikan Smart Auto-Sell"
        toggleBtn.BackgroundColor3 = C.danger
        
        -- Panggil updateMode untuk set state awal
        updateMode()
    else
        toggleBtn.Text = "▶️ Aktifkan Smart Auto-Sell"
        toggleBtn.BackgroundColor3 = C.success
        stopInventoryMonitor()
        statusLbl.Text = "Status: Idle"
        statusLbl.TextColor3 = C.textDim
        
        -- Kembalikan autoSell AoneHub
        if _G.AoneHub_Config and aoneHubOriginalState then
            _G.AoneHub_Config.autoSell = true
            if _G.AoneHub_SaveConfig then _G.AoneHub_SaveConfig() end
        end
    end
end)
