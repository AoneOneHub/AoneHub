-- ==================================================================
-- HALLOWEEN 2026 EVENT SCRIPT (Final - Fixed Nil & Cleanup)
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

-- [PATCH] Tabel untuk menyimpan koneksi agar bisa dibersihkan
local connections = {}

-- [PATCH] Bersihkan script lama jika ada (mencegah bentrok)
if _G.AoneHub_Event_Cleanup then
    pcall(_G.AoneHub_Event_Cleanup)
    _G.AoneHub_Event_Cleanup = nil
end

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

local isEnabled = false            
local isHalloweenMode = false      
local inventoryThread = nil        
local aoneHubOriginalState = true  

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
    if statusLbl and statusLbl.Parent then
        statusLbl.Text = "⏳ Teleport ke Steven..."
        statusLbl.TextColor3 = C.warning
    end
    
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local savedCFrame = hrp and hrp.CFrame
    
    local stevenCFrame = getSinisterCFrame()
    if not stevenCFrame then
        if statusLbl and statusLbl.Parent then
            statusLbl.Text = "❌ Gagal temukan Steven!"
            statusLbl.TextColor3 = C.danger
        end
        return
    end
    
    pcall(function() TeleportPlayer(Player, stevenCFrame, "Sinister Sales") end)
    task.wait(2.5)
    
    if statusLbl and statusLbl.Parent then
        statusLbl.Text = "💰 Menjual..."
    end
    SellRemote:FireServer()
    task.wait(3.5)
    
    if statusLbl and statusLbl.Parent then
        statusLbl.Text = "🔙 Kembali..."
    end
    if savedCFrame then
        pcall(function() TeleportPlayer(Player, savedCFrame, "Return") end)
    else
        local ok, farm = pcall(function() return GetFarm(Player) end)
        if ok and farm and farm:FindFirstChild("Spawn_Point") then
            pcall(function() TeleportPlayer(Player, farm.Spawn_Point.CFrame, "Farm") end)
        end
    end
    task.wait(2)
    
    if statusLbl and statusLbl.Parent then
        statusLbl.Text = "✅ Selesai!"
        statusLbl.TextColor3 = C.success
    end
end

local function startInventoryMonitor()
    if inventoryThread then task.cancel(inventoryThread) end
    
    inventoryThread = task.spawn(function()
        while isEnabled and isHalloweenMode do
            -- [PATCH] Pastikan GUI masih ada sebelum update
            if not (statusLbl and statusLbl.Parent) then break end
            
            local curr, max = getFruitCapacity()
            statusLbl.Text = string.format("🎃 Halloween | 📦 %d/%d", curr, max)
            statusLbl.TextColor3 = C.text
            
            if curr >= max then
                statusLbl.Text = "🚨 Penuh! Menjual..."
                statusLbl.TextColor3 = C.danger
                doHalloweenSell()
                task.wait(5)
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

local function updateMode()
    if not (statusLbl and statusLbl.Parent) then return end
    
    local slot = Player:GetAttribute("SelectedSlot")
    local newHalloweenMode = (slot == "HALLOWEEN_2026")
    
    if not isEnabled then
        isHalloweenMode = newHalloweenMode
        return
    end
    
    if isHalloweenMode == newHalloweenMode then return end
    isHalloweenMode = newHalloweenMode
    
    if isHalloweenMode then
        if _G.AoneHub_SetAutoSellFruit then
            _G.AoneHub_SetAutoSellFruit(false)
        end
        statusLbl.Text = "🎃 Mode Halloween aktif"
        startInventoryMonitor()
    else
        if _G.AoneHub_SetAutoSellFruit then
            _G.AoneHub_SetAutoSellFruit(true)
        end
        stopInventoryMonitor()
        statusLbl.Text = "🌱 Mode Normal: Auto-Sell AoneHub aktif"
        statusLbl.TextColor3 = C.textDim
    end
end

-- [PATCH] Simpan koneksi agar bisa diputus saat re-load
local slotConnection = Player:GetAttributeChangedSignal("SelectedSlot"):Connect(function()
    task.wait(0.5)
    updateMode()
end)
table.insert(connections, slotConnection)

-- [PATCH] Deklarasi toggleBtn dulu sebelum di-assign (mencegah error nil)
local toggleBtn
toggleBtn = createBtn(SellSection, "▶️ Aktifkan Smart Auto-Sell", 60, C.success, function()
    isEnabled = not isEnabled
    
    if isEnabled then
        if toggleBtn then
            toggleBtn.Text = "⏹️ Matikan Smart Auto-Sell"
            toggleBtn.BackgroundColor3 = C.danger
        end
        updateMode()
    else
        if toggleBtn then
            toggleBtn.Text = "▶️ Aktifkan Smart Auto-Sell"
            toggleBtn.BackgroundColor3 = C.success
        end
        stopInventoryMonitor()
        if statusLbl and statusLbl.Parent then
            statusLbl.Text = "Status: Idle"
            statusLbl.TextColor3 = C.textDim
        end
        
        if _G.AoneHub_Config and aoneHubOriginalState then
            _G.AoneHub_Config.autoSell = true
            if _G.AoneHub_SaveConfig then _G.AoneHub_SaveConfig() end
        end
    end
end)

-- [PATCH] Fungsi pembersih saat script di-reload atau GUI dihancurkan
_G.AoneHub_Event_Cleanup = function()
    isEnabled = false
    stopInventoryMonitor()
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(connections)
end
