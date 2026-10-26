-- ==================================================================
-- HALLOWEEN 2026 EVENT SCRIPT (Fixed Scope & Dynamic Shop)
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
local BuyRemote = GameEvents:WaitForChild("BuyEventShopStock")

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
-- BAGIAN 1: SMART AUTO SELL
-- ==================================================================
local SellSection = createSection(Scroll, "🎃 Smart Auto-Sell (Halloween)", "eventAutoSell")
SellSection.LayoutOrder = 1
SellSection.Size = UDim2.new(1, -10, 0, 130)

local isSellEnabled = false            
local isHalloweenMode = false      
local inventoryThread = nil        
local aoneHubOriginalState = true  

local statusSellLbl = createStatusLbl(SellSection, "Status: Idle", 28, 30)

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
    if statusSellLbl and statusSellLbl.Parent then
        statusSellLbl.Text = "⏳ Teleport ke Steven..."
        statusSellLbl.TextColor3 = C.warning
    end
    
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local savedCFrame = hrp and hrp.CFrame
    
    local stevenCFrame = getSinisterCFrame()
    if not stevenCFrame then
        if statusSellLbl and statusSellLbl.Parent then
            statusSellLbl.Text = "❌ Gagal temukan Steven!"
            statusSellLbl.TextColor3 = C.danger
        end
        return
    end
    
    pcall(function() TeleportPlayer(Player, stevenCFrame, "Sinister Sales") end)
    task.wait(2.5)
    
    if statusSellLbl and statusSellLbl.Parent then statusSellLbl.Text = "💰 Menjual..." end
    SellRemote:FireServer()
    task.wait(3.5)
    
    if statusSellLbl and statusSellLbl.Parent then statusSellLbl.Text = "🔙 Kembali..." end
    if savedCFrame then
        pcall(function() TeleportPlayer(Player, savedCFrame, "Return") end)
    else
        local ok, farm = pcall(function() return GetFarm(Player) end)
        if ok and farm and farm:FindFirstChild("Spawn_Point") then
            pcall(function() TeleportPlayer(Player, farm.Spawn_Point.CFrame, "Farm") end)
        end
    end
    task.wait(2)
    
    if statusSellLbl and statusSellLbl.Parent then
        statusSellLbl.Text = "✅ Selesai!"
        statusSellLbl.TextColor3 = C.success
    end
end

local function startInventoryMonitor()
    if inventoryThread then task.cancel(inventoryThread) end
    inventoryThread = task.spawn(function()
        while isSellEnabled and isHalloweenMode do
            if not (statusSellLbl and statusSellLbl.Parent) then break end
            local curr, max = getFruitCapacity()
            statusSellLbl.Text = string.format("🎃 Halloween | 📦 %d/%d", curr, max)
            statusSellLbl.TextColor3 = C.text
            if curr >= max then
                statusSellLbl.Text = "🚨 Penuh! Menjual..."
                statusSellLbl.TextColor3 = C.danger
                doHalloweenSell()
                task.wait(5)
            end
            task.wait(2)
        end
    end)
end

local function stopInventoryMonitor()
    if inventoryThread then task.cancel(inventoryThread); inventoryThread = nil end
end

local function updateMode()
    if not (statusSellLbl and statusSellLbl.Parent) then return end
    local slot = Player:GetAttribute("SelectedSlot")
    local newHalloweenMode = (slot == "HALLOWEEN_2026")
    
    if not isSellEnabled then isHalloweenMode = newHalloweenMode; return end
    if isHalloweenMode == newHalloweenMode then return end
    isHalloweenMode = newHalloweenMode
    
    if isHalloweenMode then
        if _G.AoneHub_SetAutoSellFruit then _G.AoneHub_SetAutoSellFruit(false) end
        statusSellLbl.Text = "🎃 Mode Halloween aktif"
        startInventoryMonitor()
    else
        if _G.AoneHub_SetAutoSellFruit then _G.AoneHub_SetAutoSellFruit(true) end
        stopInventoryMonitor()
        statusSellLbl.Text = "🌱 Mode Normal: Auto-Sell AoneHub aktif"
        statusSellLbl.TextColor3 = C.textDim
    end
end

local slotConnection = Player:GetAttributeChangedSignal("SelectedSlot"):Connect(function()
    task.wait(0.5)
    updateMode()
end)
table.insert(connections, slotConnection)

local sellToggleBtn
sellToggleBtn = createBtn(SellSection, "▶️ Aktifkan Smart Auto-Sell", 60, C.success, function()
    isSellEnabled = not isSellEnabled
    if isSellEnabled then
        if sellToggleBtn then sellToggleBtn.Text = "⏹️ Matikan Smart Auto-Sell"; sellToggleBtn.BackgroundColor3 = C.danger end
        updateMode()
    else
        if sellToggleBtn then sellToggleBtn.Text = "▶️ Aktifkan Smart Auto-Sell"; sellToggleBtn.BackgroundColor3 = C.success end
        stopInventoryMonitor()
        if statusSellLbl and statusSellLbl.Parent then statusSellLbl.Text = "Status: Idle"; statusSellLbl.TextColor3 = C.textDim end
        if _G.AoneHub_Config and aoneHubOriginalState then
            _G.AoneHub_Config.autoSell = true
            if _G.AoneHub_SaveConfig then _G.AoneHub_SaveConfig() end
        end
    end
end)


-- ==================================================================
-- BAGIAN 2: SMART AUTO BUY EVENT SHOP
-- ==================================================================
local ShopSection = createSection(Scroll, "🛒 Smart Auto-Buy Halloween Shop", "eventShop")
ShopSection.LayoutOrder = 2
ShopSection.Size = UDim2.new(1, -10, 0, 280)

local isAutoBuying = false
local buyThread = nil
local selectedItems = {} 

local statusBuyLbl = createStatusLbl(ShopSection, "Pilih item di bawah, lalu klik Start.", 28, 30)

-- ⭐ FUNGSI DINAMIS: Mengambil Item Langsung dari Game
local function fetchShopItems()
    local items = {}
    
    local success, shopData = pcall(function()
        return require(ReplicatedStorage.Data.Events.Halloween2026Event.Halloween2026EventShopData)
    end)
    
    if not success or not shopData then
        warn("[Auto-Buy] Gagal load Halloween2026EventShopData!")
        return items
    end

    local categoryMap = {
        SeedShop = "Scary Seeds",
        PetShop = "Frightening Fauna",
        CosmeticShop = "Demonic Decor"
    }

    for dataKey, categoryName in pairs(categoryMap) do
        local categoryData = shopData[dataKey]
        
        if categoryData then
            for itemName, itemConfig in pairs(categoryData) do
                if itemConfig.DisplayInShop then
                    table.insert(items, {
                        name = itemName,
                        cat = categoryName,
                        price = itemConfig.Price or 0,
                        rarity = itemConfig.SeedRarity or "Common"
                    })
                end
            end
        end
    end
    
    table.sort(items, function(a, b)
        return a.price < b.price
    end)
    
    return items
end

local SHOP_ITEMS = fetchShopItems()

-- List Scroll untuk Item
local itemScroll = Instance.new("ScrollingFrame")
itemScroll.Size = UDim2.new(1, -20, 0, 140)
itemScroll.Position = UDim2.new(0, 10, 0, 60)
itemScroll.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
itemScroll.BorderSizePixel = 0
itemScroll.ScrollBarThickness = 3
itemScroll.Parent = ShopSection
Instance.new("UICorner", itemScroll).CornerRadius = UDim.new(0, 4)

local itemLayout = Instance.new("UIListLayout")
itemLayout.Padding = UDim.new(0, 2)
itemLayout.Parent = itemScroll

local itemButtons = {}

local function renderItems()
    for _, btn in ipairs(itemButtons) do btn:Destroy() end
    table.clear(itemButtons)

    for i, item in ipairs(SHOP_ITEMS) do
        local isSelected = selectedItems[item.name] ~= nil
        
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -6, 0, 24)
        btn.BackgroundColor3 = isSelected and C.success or Color3.fromRGB(45, 45, 58)
        btn.Text = string.format("[%s] %s (%s) - %d CC", isSelected and "✓" or " ", item.name, item.cat, item.price)
        btn.TextColor3 = C.text
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 8
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.LayoutOrder = i
        btn.Parent = itemScroll
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
        
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 6)
        pad.Parent = btn

        btn.MouseButton1Click:Connect(function()
            if selectedItems[item.name] then
                selectedItems[item.name] = nil
            else
                selectedItems[item.name] = item 
            end
            renderItems()
        end)
        
        table.insert(itemButtons, btn)
    end
    itemScroll.CanvasSize = UDim2.new(0, 0, 0, #SHOP_ITEMS * 26 + 10)
end

renderItems()

-- Fungsi Cek Stok dari DataService
local function getShopStock(shopName, itemName)
    local data = DataService:GetData()
    if not data or not data.EventShopStock or not data.EventShopStock[shopName] then return 0 end
    local shopData = data.EventShopStock[shopName]
    if not shopData.Stocks or not shopData.Stocks[itemName] then return 0 end
    return shopData.Stocks[itemName].Stock or 0
end

-- Fungsi Cek Saldo Candy Corn
local function getCandyCorn()
    local data = DataService:GetData()
    if data and data.SpecialCurrency then
        return data.SpecialCurrency.CandyCorn or 0
    end
    return 0
end

-- [PATCH FIX] Deklarasi buyToggleBtn dipisah agar tidak error nil di dalam closure
local buyToggleBtn
buyToggleBtn = createBtn(ShopSection, "▶️ Mulai Smart Auto-Buy", 210, C.success, function()
    isAutoBuying = not isAutoBuying
    
    if isAutoBuying then
        local count = 0
        for _ in pairs(selectedItems) do count = count + 1 end
        if count == 0 then
            if statusBuyLbl and statusBuyLbl.Parent then
                statusBuyLbl.Text = "⚠️ Pilih minimal 1 item!"
                statusBuyLbl.TextColor3 = C.danger
            end
            isAutoBuying = false
            return
        end
        
        if buyToggleBtn then 
            buyToggleBtn.Text = "⏹️ Stop Smart Auto-Buy"
            buyToggleBtn.BackgroundColor3 = C.danger
        end
        
        buyThread = task.spawn(function()
            while isAutoBuying do
                local candyCorn = getCandyCorn()
                local itemToBuy = nil
                
                -- 1. Cari item yang dipilih DAN stoknya > 0 DAN uang cukup
                for itemName, itemData in pairs(selectedItems) do
                    local stock = getShopStock(itemData.cat, itemName)
                    if stock > 0 and candyCorn >= itemData.price then
                        itemToBuy = itemData
                        break 
                    end
                end
                
                -- 2. Eksekusi Pembelian
                if itemToBuy then
                    if statusBuyLbl and statusBuyLbl.Parent then
                        statusBuyLbl.Text = string.format("🛒 Membeli %s (Sisa CC: %d)", itemToBuy.name, candyCorn)
                        statusBuyLbl.TextColor3 = C.success
                    end
                    
                    pcall(function()
                        BuyRemote:FireServer(itemToBuy.name, itemToBuy.cat)
                    end)
                    
                    task.wait(0.5)
                else
                    -- 3. Jika tidak ada yang bisa dibeli (stok habis / miskin)
                    if statusBuyLbl and statusBuyLbl.Parent then
                        statusBuyLbl.Text = string.format("💤 Menunggu Stok/Restock... (CC: %d)", candyCorn)
                        statusBuyLbl.TextColor3 = C.textDim
                    end
                    task.wait(2)
                end
            end
        end)
    else
        if buyToggleBtn then
            buyToggleBtn.Text = "▶️ Mulai Smart Auto-Buy"
            buyToggleBtn.BackgroundColor3 = C.success
        end
        if buyThread then task.cancel(buyThread) end
        if statusBuyLbl and statusBuyLbl.Parent then
            statusBuyLbl.Text = "Status: Stopped."
            statusBuyLbl.TextColor3 = C.textDim
        end
    end
end)


-- [PATCH] Fungsi pembersih saat script di-reload atau GUI dihancurkan
_G.AoneHub_Event_Cleanup = function()
    isSellEnabled = false
    isAutoBuying = false
    stopInventoryMonitor()
    if buyThread then pcall(task.cancel, buyThread) end
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(connections)
end
