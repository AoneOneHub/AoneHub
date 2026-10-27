-- ==================================================================
-- HALLOWEEN 2026 EVENT SCRIPT (AoneHub Style UI)
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

-- Helper UI Dasar
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
-- BAGIAN 2: SMART AUTO BUY EVENT SHOP (AoneHub Style)
-- ==================================================================
local ShopSection = createSection(Scroll, "🛒 Auto-Buy Halloween Shop", "eventShop")
ShopSection.LayoutOrder = 2
ShopSection.Size = UDim2.new(1, -10, 0, 420) -- Diperbesar untuk menampung UI baru

local isAutoBuying = false
local buyThread = nil
local selectedItems = {} -- Format: ["Nama Item"] = Table Data Item

local statusBuyLbl = createStatusLbl(ShopSection, "Pilih item di bawah, lalu klik Start.", 28, 20)

-- ⭐ FUNGSI DINAMIS: Mengambil Item Langsung dari Game
local function fetchShopItems()
    local items = {}
    local success, shopData = pcall(function()
        return require(ReplicatedStorage.Data.Events.Halloween2026Event.Halloween2026EventShopData)
    end)
    
    if not success or not shopData then return items end

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
                        rarity = itemConfig.SeedRarity or "Common",
                        layoutOrder = itemConfig.LayoutOrder or 999
                    })
                end
            end
        end
    end
    return items
end

local SHOP_ITEMS = fetchShopItems()

-- =====================================================
-- SUB-TABS SYSTEM
-- =====================================================
local currentTab = "Scary Seeds"
local subTabs = {
    {"Scary Seeds", "🌱 Seeds"},
    {"Frightening Fauna", "🐾 Pets"},
    {"Demonic Decor", "🎨 Decor"}
}
local subTabBtns = {}

local subTabBar = Instance.new("Frame")
subTabBar.Size = UDim2.new(1, -20, 0, 22)
subTabBar.Position = UDim2.new(0, 10, 0, 52)
subTabBar.BackgroundTransparency = 1
subTabBar.Parent = ShopSection

local subTabLayout = Instance.new("UIListLayout")
subTabLayout.FillDirection = Enum.FillDirection.Horizontal
subTabLayout.Padding = UDim.new(0, 3)
subTabLayout.Parent = subTabBar

-- Search Bar
local searchBar = Instance.new("TextBox")
searchBar.Size = UDim2.new(1, -20, 0, 22)
searchBar.Position = UDim2.new(0, 10, 0, 78)
searchBar.BackgroundColor3 = C.input
searchBar.BorderSizePixel = 0
searchBar.Font = Enum.Font.Gotham
searchBar.PlaceholderText = "🔍 Cari item..."
searchBar.Text = ""
searchBar.TextColor3 = C.text
searchBar.TextSize = 9
searchBar.ClearTextOnFocus = false
searchBar.Parent = ShopSection
Instance.new("UICorner", searchBar).CornerRadius = UDim.new(0, 4)

-- Buttons All / Clear
local btnAll = Instance.new("TextButton")
btnAll.Size = UDim2.new(0.5, -15, 0, 22)
btnAll.Position = UDim2.new(0, 10, 0, 105)
btnAll.BackgroundColor3 = C.accent
btnAll.BorderSizePixel = 0
btnAll.Font = Enum.Font.GothamBold
btnAll.Text = "✓ Pilih Semua (Tab Ini)"
btnAll.TextColor3 = C.text
btnAll.TextSize = 8
btnAll.Parent = ShopSection
Instance.new("UICorner", btnAll).CornerRadius = UDim.new(0, 3)

local btnClear = Instance.new("TextButton")
btnClear.Size = UDim2.new(0.5, -15, 0, 22)
btnClear.Position = UDim2.new(0.5, 5, 0, 105)
btnClear.BackgroundColor3 = C.danger
btnClear.BorderSizePixel = 0
btnClear.Font = Enum.Font.GothamBold
btnClear.Text = "✕ Clear Semua"
btnClear.TextColor3 = C.text
btnClear.TextSize = 8
btnClear.Parent = ShopSection
Instance.new("UICorner", btnClear).CornerRadius = UDim.new(0, 3)

-- List Scroll
local itemScroll = Instance.new("ScrollingFrame")
itemScroll.Size = UDim2.new(1, -20, 0, 150)
itemScroll.Position = UDim2.new(0, 10, 0, 132)
itemScroll.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
itemScroll.BorderSizePixel = 0
itemScroll.ScrollBarThickness = 4
itemScroll.ScrollBarImageColor3 = C.accent
itemScroll.Parent = ShopSection
Instance.new("UICorner", itemScroll).CornerRadius = UDim.new(0, 4)

local itemLayout = Instance.new("UIListLayout")
itemLayout.Padding = UDim.new(0, 2)
itemLayout.Parent = itemScroll

local itemButtons = {}

-- Fungsi Cek Stok & Uang
local function getShopStock(shopName, itemName)
    local data = DataService:GetData()
    if not data or not data.EventShopStock or not data.EventShopStock[shopName] then return 0 end
    local shopData = data.EventShopStock[shopName]
    if not shopData.Stocks or not shopData.Stocks[itemName] then return 0 end
    return shopData.Stocks[itemName].Stock or 0
end

local function getCandyCorn()
    local data = DataService:GetData()
    if data and data.SpecialCurrency then
        return data.SpecialCurrency.CandyCorn or 0
    end
    return 0
end

-- =====================================================
-- RENDER LIST ITEM (Desain Mirip AoneHub)
-- =====================================================
local function renderList()
    for _, btn in ipairs(itemButtons) do btn:Destroy() end
    table.clear(itemButtons)
    
    local searchTxt = searchBar.Text:lower()
    
    -- Filter Item berdasarkan Tab & Search
    local filtered = {}
    for _, item in ipairs(SHOP_ITEMS) do
        if item.cat == currentTab then
            if searchTxt == "" or item.name:lower():find(searchTxt, 1, true) then
                table.insert(filtered, item)
            end
        end
    end
    
    -- Urutkan berdasarkan LayoutOrder (seperti di game)
    table.sort(filtered, function(a, b)
        return a.layoutOrder < b.layoutOrder
    end)

    for i, item in ipairs(filtered) do
        local isSel = selectedItems[item.name] ~= nil
        local stock = getShopStock(item.cat, item.name)
        
        -- Frame Background
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -8, 0, 26)
        btn.BackgroundColor3 = isSel and Color3.fromRGB(60, 130, 220) or Color3.fromRGB(45, 45, 58)
        btn.BorderSizePixel = 0
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.LayoutOrder = i
        btn.Parent = itemScroll
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
        
        -- 1. Icon / Centang
        local iconLbl = Instance.new("TextLabel")
        iconLbl.Size = UDim2.new(0, 20, 1, 0)
        iconLbl.BackgroundTransparency = 1
        iconLbl.Text = isSel and "✓" or "○"
        iconLbl.TextColor3 = isSel and C.text or C.textDim
        iconLbl.Font = Enum.Font.GothamBold
        iconLbl.TextSize = 10
        iconLbl.Parent = btn
        
        -- 2. Nama Item
        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(0.45, 0, 1, 0)
        nameLbl.Position = UDim2.new(0, 20, 0, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = item.name
        nameLbl.TextColor3 = C.text
        nameLbl.Font = Enum.Font.GothamSemibold
        nameLbl.TextSize = 8
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
        nameLbl.Parent = btn
        
        -- 3. Stok
        local stockLbl = Instance.new("TextLabel")
        stockLbl.Size = UDim2.new(0.2, 0, 1, 0)
        stockLbl.Position = UDim2.new(0.65, 0, 0, 0)
        stockLbl.BackgroundTransparency = 1
        stockLbl.Text = stock > 0 and ("📦 "..stock) or "❌ 0"
        stockLbl.TextColor3 = stock > 0 and C.success or C.danger
        stockLbl.Font = Enum.Font.Gotham
        stockLbl.TextSize = 8
        stockLbl.TextXAlignment = Enum.TextXAlignment.Right
        stockLbl.Parent = btn
        
        -- 4. Harga
        local priceLbl = Instance.new("TextLabel")
        priceLbl.Size = UDim2.new(0.15, 0, 1, 0)
        priceLbl.Position = UDim2.new(0.85, 0, 0, 0)
        priceLbl.BackgroundTransparency = 1
        priceLbl.Text = tostring(item.price)
        priceLbl.TextColor3 = Color3.fromRGB(255, 200, 0) -- Kuning Emas
        priceLbl.Font = Enum.Font.GothamBold
        priceLbl.TextSize = 8
        priceLbl.TextXAlignment = Enum.TextXAlignment.Right
        priceLbl.Parent = btn
        
        -- Padding Kanan
        local padR = Instance.new("UIPadding")
        padR.PaddingRight = UDim.new(0, 6)
        padR.Parent = btn

        -- Click Listener
        btn.MouseButton1Click:Connect(function()
            if selectedItems[item.name] then
                selectedItems[item.name] = nil
            else
                selectedItems[item.name] = item
            end
            renderList()
        end)
        
        table.insert(itemButtons, btn)
    end
    
    itemScroll.CanvasSize = UDim2.new(0, 0, 0, #filtered * 28 + 8)
end

-- Inisialisasi Sub-Tab Buttons
for i, tabData in ipairs(subTabs) do
    local tabName, tabLabel = tabData[1], tabData[2]
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.33, -2, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
    btn.Text = tabLabel
    btn.TextColor3 = C.textDim
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 8
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = subTabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
    
    btn.MouseButton1Click:Connect(function()
        currentTab = tabName
        for n, b in pairs(subTabBtns) do
            if n == tabName then
                b.BackgroundColor3 = C.accent
                b.TextColor3 = C.text
            else
                b.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
                b.TextColor3 = C.textDim
            end
        end
        renderList()
    end)
    
    subTabBtns[tabName] = btn
    if tabName == currentTab then
        btn.BackgroundColor3 = C.accent
        btn.TextColor3 = C.text
    end
end

-- Event Listener UI
searchBar:GetPropertyChangedSignal("Text"):Connect(renderList)

btnAll.MouseButton1Click:Connect(function()
    for _, item in ipairs(SHOP_ITEMS) do
        if item.cat == currentTab then
            selectedItems[item.name] = item
        end
    end
    renderList()
end)

btnClear.MouseButton1Click:Connect(function()
    for _, item in ipairs(SHOP_ITEMS) do
        if item.cat == currentTab then
            selectedItems[item.name] = nil
        end
    end
    renderList()
end)

-- Render pertama kali
renderList()

-- =====================================================
-- LOOP AUTO BUY
-- =====================================================
local buyToggleBtn
buyToggleBtn = createBtn(ShopSection, "▶️ Mulai Smart Auto-Buy", 290, C.success, function()
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
                
                -- Cari item yang dipilih DAN stoknya > 0 DAN uang cukup
                for itemName, itemData in pairs(selectedItems) do
                    local stock = getShopStock(itemData.cat, itemName)
                    if stock > 0 and candyCorn >= itemData.price then
                        itemToBuy = itemData
                        break 
                    end
                end
                
                if itemToBuy then
                    if statusBuyLbl and statusBuyLbl.Parent then
                        statusBuyLbl.Text = string.format("🛒 Membeli %s (CC: %d)", itemToBuy.name, candyCorn)
                        statusBuyLbl.TextColor3 = C.success
                    end
                    
                    pcall(function()
                        BuyRemote:FireServer(itemToBuy.name, itemToBuy.cat)
                    end)
                    
                    -- [PATCH] Update stok di UI setelah beli
                    task.wait(0.5)
                    renderList()
                else
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

-- ==================================================================
-- BAGIAN 3: TRICK OR TREAT (AUTO KNOCK with TOTAL PRICE)
-- ==================================================================
local TrickSection = createSection(Scroll, "🎃 Trick or Treat (Auto Knock)", "eventTrick")
TrickSection.LayoutOrder = 3
TrickSection.Size = UDim2.new(1, -10, 0, 200)

local isTrickRunning = false
local trickThread = nil
local maxKnocks = 5 

local statusTrickLbl = createStatusLbl(TrickSection, "Status: Idle", 28, 45)
statusTrickLbl.TextColor3 = C.text

local TrickRemote = GameEvents:WaitForChild("Events"):WaitForChild("Halloween2026Event"):WaitForChild("TrickOrTreating"):WaitForChild("Knock")

-- Input Max Knocks
local limitLbl = Instance.new("TextLabel")
limitLbl.Size = UDim2.new(0.5, -10, 0, 20)
limitLbl.Position = UDim2.new(0, 10, 0, 80)
limitLbl.BackgroundTransparency = 1
limitLbl.Text = "Max Ketok / Reset:"
limitLbl.TextColor3 = C.textDim
limitLbl.Font = Enum.Font.Gotham
limitLbl.TextSize = 9
limitLbl.TextXAlignment = Enum.TextXAlignment.Left
limitLbl.Parent = TrickSection

local limitInput = Instance.new("TextBox")
limitInput.Size = UDim2.new(0.5, -10, 0, 22)
limitInput.Position = UDim2.new(0.5, 0, 0, 79)
limitInput.BackgroundColor3 = C.input
limitInput.BorderSizePixel = 0
limitInput.Font = Enum.Font.GothamBold
limitInput.Text = tostring(maxKnocks)
limitInput.TextColor3 = C.text
limitInput.TextSize = 9
limitInput.Parent = TrickSection
Instance.new("UICorner", limitInput).CornerRadius = UDim.new(0, 3)

limitInput.FocusLost:Connect(function()
    local n = tonumber(limitInput.Text)
    if n and n >= 1 and n <= 50 then
        maxKnocks = math.floor(n)
    end
    limitInput.Text = tostring(maxKnocks)
end)

-- Fungsi hitung harga 1x ketok
local function calculateCurrentPrice(knocks)
    local basePrice = 10
    local growth = 2
    local roundTo = 5
    local rawPrice = basePrice * (growth ^ knocks) / roundTo + 0.5
    return math.floor(rawPrice) * roundTo
end

-- Fungsi hitung total harga dari 0 sampai maxKnocks
local function getTotalCost(targetMax)
    local total = 0
    for i = 0, targetMax - 1 do
        total = total + calculateCurrentPrice(i)
    end
    return total
end

-- Fungsi hitung sisa harga dari ketokan saat ini sampai maxKnocks
local function getRemainingCost(currentKnocks, targetMax)
    local total = 0
    for i = currentKnocks, targetMax - 1 do
        total = total + calculateCurrentPrice(i)
    end
    return total
end

-- Fungsi format waktu
local function formatTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if h > 0 then return string.format("%dj %dm %ds", h, m, s)
    elseif m > 0 then return string.format("%dm %ds", m, s)
    else return string.format("%ds", s) end
end

-- Fungsi ambil data Trick or Treat
local function getTrickData()
    local data = DataService:GetData()
    if data and data.TrickOrTreatingData then
        local td = data.TrickOrTreatingData
        local now = workspace:GetServerTimeNow()
        local resetAt = td.ResetAt or 0
        local knocks = td.Knocks or 0
        
        if now >= resetAt then knocks = 0 end
        
        return {
            knocks = knocks,
            price = calculateCurrentPrice(knocks),
            timeLeft = math.max(0, resetAt - now)
        }
    end
    return nil
end

-- Fungsi update UI
local function updateTrickUI()
    if not (statusTrickLbl and statusTrickLbl.Parent) then return end
    
    local td = getTrickData()
    if not td then
        statusTrickLbl.Text = "❌ Gagal membaca data."
        return
    end
    
    local cc = getCandyCorn()
    local totalCost = getTotalCost(maxKnocks)
    local remainCost = getRemainingCost(td.knocks, maxKnocks)
    
    if td.knocks >= maxKnocks then
        -- Mode Menunggu Reset
        statusTrickLbl.Text = string.format(
            "⏳ Batas Tercapai (%d/%d) | 💰 Saldo: %d CC\n🔄 Menunggu Reset dalam: %s",
            td.knocks, maxKnocks, cc, formatTime(td.timeLeft)
        )
        statusTrickLbl.TextColor3 = C.warning
    elseif td.knocks == 0 and td.timeLeft > 0 then
        -- Mode Baru Saja Reset (Server sudah kasih ResetAt baru, knocks jadi 0)
        statusTrickLbl.Text = string.format(
            "🟢 Waktu Reset! Memulai putaran baru...\n💵 Butuh Total: %d CC | 💰 Saldo: %d CC",
            totalCost, cc
        )
        statusTrickLbl.TextColor3 = C.success
    else
        -- Mode Sedang Ngetok
        statusTrickLbl.Text = string.format(
            "🚪 Knocks: %d/%d | 💵 Total Max: %d CC | 💰 Saldo: %d CC\n💸 Sisa Biaya: %d CC | 🔄 Reset: %s",
            td.knocks, maxKnocks, totalCost, cc, remainCost, formatTime(td.timeLeft)
        )
        
        if cc < remainCost then
            statusTrickLbl.TextColor3 = C.danger 
        else
            statusTrickLbl.TextColor3 = C.text 
        end
    end
end

-- Tombol Toggle (Bagian Thread Loop)
local trickToggleBtn
trickToggleBtn = createBtn(TrickSection, "▶️ Mulai Auto Knock", 110, C.success, function()
    isTrickRunning = not isTrickRunning
    
    if isTrickRunning then
        if trickToggleBtn then
            trickToggleBtn.Text = "⏹️ Stop Auto Knock"
            trickToggleBtn.BackgroundColor3 = C.danger
        end
        
        trickThread = task.spawn(function()
            while isTrickRunning do
                local td = getTrickData()
                if not td then task.wait(2) continue end
                
                if td.knocks >= maxKnocks then
                    -- Diam menunggu reset
                    task.wait(5) 
                else
                    local cc = getCandyCorn()
                    
                    -- Cek apakah uang cukup untuk ketokan berikutnya
                    if cc >= td.price then
                        -- Tembak remote
                        pcall(function()
                            TrickRemote:InvokeServer({ExpectedPrice = td.price})
                        end)
                        
                        -- Tunggu animasi selesai sebelum cek lagi
                        task.wait(3.5) 
                    else
                        -- Jika uang tidak cukup, tunggu sampai user punya uang
                        task.wait(5)
                    end
                end
            end
        end)
    else
        if trickToggleBtn then
            trickToggleBtn.Text = "▶️ Mulai Auto Knock"
            trickToggleBtn.BackgroundColor3 = C.success
        end
        if trickThread then task.cancel(trickThread) end
        if statusTrickLbl and statusTrickLbl.Parent then
            statusTrickLbl.Text = "Status: Stopped."
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
