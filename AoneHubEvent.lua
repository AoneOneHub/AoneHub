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
-- BAGIAN 3: TRICK OR TREAT (AUTO KNOCK + TELEPORT)
-- ==================================================================
local TrickSection = createSection(Scroll, "🎃 Trick or Treat (Auto Knock)", "eventTrick")
TrickSection.LayoutOrder = 3
TrickSection.Size = UDim2.new(1, -10, 0, 260) 

local isTrickRunning = false
local trickThread = nil
local maxKnocks = 5 
local currentAction = "Idle"

local statsLbl = createStatusLbl(TrickSection, "Memuat data...", 28, 45)
statsLbl.TextColor3 = C.text

local actionLbl = createStatusLbl(TrickSection, "Status: Idle", 75, 20)
actionLbl.TextColor3 = C.textDim

local TrickRemote = GameEvents:WaitForChild("Events"):WaitForChild("Halloween2026Event"):WaitForChild("TrickOrTreating"):WaitForChild("Knock")

-- Input Max Knocks
local limitLbl = Instance.new("TextLabel")
limitLbl.Size = UDim2.new(0.5, -10, 0, 20)
limitLbl.Position = UDim2.new(0, 10, 0, 105)
limitLbl.BackgroundTransparency = 1
limitLbl.Text = "Max Ketok / Reset:"
limitLbl.TextColor3 = C.textDim
limitLbl.Font = Enum.Font.Gotham
limitLbl.TextSize = 9
limitLbl.TextXAlignment = Enum.TextXAlignment.Left
limitLbl.Parent = TrickSection

local limitInput = Instance.new("TextBox")
limitInput.Size = UDim2.new(0.5, -10, 0, 22)
limitInput.Position = UDim2.new(0.5, 0, 0, 104)
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

-- Fungsi hitung harga
local function calculateCurrentPrice(knocks)
    local basePrice = 10
    local growth = 2
    local roundTo = 5
    local rawPrice = basePrice * (growth ^ knocks) / roundTo + 0.5
    return math.floor(rawPrice) * roundTo
end

local function getTotalCost(targetMax)
    local total = 0
    for i = 0, targetMax - 1 do total = total + calculateCurrentPrice(i) end
    return total
end

local function getRemainingCost(currentKnocks, targetMax)
    local total = 0
    for i = currentKnocks, targetMax - 1 do total = total + calculateCurrentPrice(i) end
    return total
end

local function formatTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if h > 0 then return string.format("%dj %dm %ds", h, m, s)
    elseif m > 0 then return string.format("%dm %ds", m, s)
    else return string.format("%ds", s) end
end

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

-- ⭐ FUNGSI TELEPORT KE PINTU TRICK OR TREAT
local function getTrickDoorCFrame()
    local model = workspace:FindFirstChild("Interaction")
    if model then model = model:FindFirstChild("TrickOrTreatingModel") end
    if not model then return nil end

    local door = model:FindFirstChild("Door", true)
    if not (door and door:IsA("BasePart")) then return nil end

    -- Hitung posisi 5 stud di depan pintu
    local pos = door.Position + door.CFrame.LookVector * 5
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { Player.Character }
    
    -- Cari tanah
    local ray = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -20, 0), params)
    local targetY = ray and (ray.Position.Y + 3) or pos.Y
    local targetPos = Vector3.new(pos.X, targetY, pos.Z)

    return CFrame.lookAt(targetPos, Vector3.new(door.Position.X, targetY, door.Position.Z))
end

-- ⭐ FUNGSI UTAMA KETOK PINTU
local function doTrickOrTreatCycle()
    local td = getTrickData()
    if not td or td.knocks >= maxKnocks then return end
    
    local cc = getCandyCorn()
    if cc < td.price then 
        currentAction = "💤 Saldo kurang!"
        return 
    end
    
    -- 1. Simpan Posisi
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local savedCFrame = hrp and hrp.CFrame

    -- 2. Teleport ke Pintu
    local doorCFrame = getTrickDoorCFrame()
    if not doorCFrame then
        currentAction = "❌ Pintu tidak ditemukan!"
        return
    end
    
    currentAction = "⏳ Teleport ke Pintu..."
    pcall(function() TeleportPlayer(Player, doorCFrame, "TrickOrTreat") end)
    task.wait(2.5) -- Tunggu loading

    -- 3. Loop Ketok (selama masih di bawah max dan uang cukup)
    while isTrickRunning do
        td = getTrickData()
        if not td or td.knocks >= maxKnocks then break end
        cc = getCandyCorn()
        
        if cc < td.price then 
            currentAction = "💤 Saldo kurang!"
            break 
        end

        currentAction = string.format("🚪 Ngetok pintu ke-%d", td.knocks + 1)
        pcall(function()
            TrickRemote:InvokeServer({ExpectedPrice = td.price})
        end)
        task.wait(2) -- Tunggu animasi
    end

    -- 4. Teleport Balik
    currentAction = "🔙 Kembali ke kebun..."
    if savedCFrame then
        pcall(function() TeleportPlayer(Player, savedCFrame, "Return") end)
    else
        local ok, farm = pcall(function() return GetFarm(Player) end)
        if ok and farm and farm:FindFirstChild("Spawn_Point") then
            pcall(function() TeleportPlayer(Player, farm.Spawn_Point.CFrame, "Farm") end)
        end
    end
    task.wait(2)
    
    currentAction = "✅ Selesai."
end

-- LOOP UI STATISTIK (Hanya mengupdate statsLbl)
task.spawn(function()
    while true do
        task.wait(1)
        if statsLbl and statsLbl.Parent then
            local td = getTrickData()
            if td then
                local cc = getCandyCorn()
                local totalCost = getTotalCost(maxKnocks)
                local remainCost = getRemainingCost(td.knocks, maxKnocks)
                
                statsLbl.Text = string.format(
                    "🚪 Knocks: %d/%d | 💵 Max: %d CC\n💰 Saldo: %d CC | 💸 Sisa: %d CC\n🔄 Reset: %s",
                    td.knocks, maxKnocks, totalCost, cc, remainCost, formatTime(td.timeLeft)
                )
                
                if td.knocks >= maxKnocks then
                    statsLbl.TextColor3 = C.warning
                elseif cc < remainCost then
                    statsLbl.TextColor3 = C.danger
                else
                    statsLbl.TextColor3 = C.text
                end
            end
        else
            break
        end
    end
end)

-- LOOP UI AKSI
task.spawn(function()
    while true do
        task.wait(0.2)
        if actionLbl and actionLbl.Parent then
            actionLbl.Text = "Status: " .. currentAction
            if currentAction:find("Ngetok") then
                actionLbl.TextColor3 = C.success
            elseif currentAction:find("kurang") or currentAction:find("❌") then
                actionLbl.TextColor3 = C.danger
            elseif currentAction:find("Teleport") or currentAction:find("Kembali") then
                actionLbl.TextColor3 = C.warning
            else
                actionLbl.TextColor3 = C.textDim
            end
        end
    end
end)

-- TOMBOL TOGGLE
local trickToggleBtn
trickToggleBtn = createBtn(TrickSection, "▶️ Mulai Auto Knock", 135, C.success, function()
    isTrickRunning = not isTrickRunning
    
    if isTrickRunning then
        if trickToggleBtn then
            trickToggleBtn.Text = "⏹️ Stop Auto Knock"
            trickToggleBtn.BackgroundColor3 = C.danger
        end
        
        trickThread = task.spawn(function()
            while isTrickRunning do
                local td = getTrickData()
                if td then
                    if td.knocks >= maxKnocks then
                        currentAction = "⏳ Menunggu Reset..."
                        task.wait(2)
                    else
                        doTrickOrTreatCycle()
                        task.wait(3) -- Jeda sebelum siklus berikutnya
                    end
                else
                    task.wait(2)
                end
            end
        end)
    else
        if trickToggleBtn then
            trickToggleBtn.Text = "▶️ Mulai Auto Knock"
            trickToggleBtn.BackgroundColor3 = C.success
        end
        if trickThread then task.cancel(trickThread) end
        currentAction = "Stopped."
    end
end)

-- ==================================================================
-- BAGIAN 4: BLACK CAT AUTO HARVESTER (SMART INVENTORY & GARDEN)
-- ==================================================================
local CatSection = createSection(Scroll, "🐈‍⬛ Black Cat Auto Harvester", "eventCat")
CatSection.LayoutOrder = 4
CatSection.Size = UDim2.new(1, -10, 0, 210)

local isCatRunning = false
local catThread = nil
local catAction = "Idle"

local catStatsLbl = createStatusLbl(CatSection, "Memuat request...", 28, 45)
catStatsLbl.TextColor3 = C.text

local catStatusLbl = createStatusLbl(CatSection, "Status: Idle", 75, 20)
catStatusLbl.TextColor3 = C.textDim

local warnLbl = createStatusLbl(CatSection, "⚠️ Matikan Auto Collect di Tab Farm!", 100, 14)
warnLbl.TextColor3 = C.warning

-- Services & Modules
local CollectionService = game:GetService("CollectionService")
local HungryController = nil
pcall(function()
    HungryController = require(ReplicatedStorage.Modules.Events.Halloween2026Event.HalloweenHungryController)
end)

local CropsCollectRE = GameEvents:WaitForChild("Crops"):WaitForChild("Collect")
local CatSubmitRE = GameEvents:WaitForChild("Events"):WaitForChild("Halloween2026Event"):WaitForChild("HalloweenHungry"):WaitForChild("Submit")

-- ⭐ AMBIL SUMBER DATA YANG SAMA DENGAN AONEHUB
local KNOWN_FRUITS = {}
local KNOWN_MUTATIONS = {}

-- Load Fruits dari PlantTraitsData
pcall(function()
    local fruitData = require(ReplicatedStorage.Modules.PlantTraitsData.Fruit)
    if fruitData and fruitData.Plants then
        for _, name in ipairs(fruitData.Plants) do
            KNOWN_FRUITS[name:lower()] = name
        end
    end
end)

-- Load Mutations dari MutationHandler
pcall(function()
    local MutationHandler = require(ReplicatedStorage.Modules.MutationHandler)
    if MutationHandler then
        local success, mutations = pcall(function()
            return MutationHandler:GetMutations()
        end)
        if success and mutations then
            for name, _ in pairs(mutations) do
                KNOWN_MUTATIONS[name] = true
            end
        end
    end
end)

-- =====================================================
-- FUNGSI HELPER (Sesuai Kode Kamu)
-- =====================================================
local function IsMyFruit(fruit)
    local ancestor = fruit:FindFirstAncestor("Important")
    if not ancestor then return false end
    local data = ancestor:FindFirstChild("Data")
    if not data then return false end
    local owner = data:FindFirstChild("Owner")
    if not owner or not owner.Value then return false end
    return owner.Value == Player.Name
end

local function isFruitReady(fruit)
    if not fruit:HasTag("Harvestable") then return false end
    local grow = fruit:FindFirstChild("Grow")
    if not grow then return false end
    local ageValue = grow:FindFirstChild("Age")
    local maxAge = fruit:GetAttribute("MaxAge")
    if not ageValue or not maxAge then return false end
    return ageValue.Value >= maxAge
end

local ignoredFruits = setmetatable({}, {__mode = "k"})
local IGNORE_TIME = 60

-- ⭐ FUNGSI GET FRUIT INFO (Filter Mutasi pakai KNOWN_MUTATIONS)
local function getFruitInfo(fruit)
    if not fruit then return nil end
    local name = fruit.Name
    local weight = tonumber(fruit:GetAttribute("Weight")) or tonumber(fruit:GetAttribute("BaseWeight")) or 0
    
    -- [PERBAIKAN] Hanya anggap mutasi jika namanya ada di KNOWN_MUTATIONS
    local mutationList = {}
    for attrName, attrValue in pairs(fruit:GetAttributes()) do
        if attrValue == true and KNOWN_MUTATIONS[attrName] then
            table.insert(mutationList, attrName)
        end
    end
    table.sort(mutationList)

    return {
        instance = fruit,
        name = name,
        weight = weight,
        mutationList = mutationList,
    }
end

-- ⭐ FUNGSI CEK INVENTORY: Apakah buah ini sudah ada di tas?
local function hasItemInInventory(req)
    local data = DataService:GetData()
    if not data or not data.InventoryData then return false end
    
    local reqName = req.PLANT_NAME:lower()
    local reqWeight = req.WEIGHT
    local reqMut = req.MUTATION and req.MUTATION:lower() or nil
    
    for _, item in pairs(data.InventoryData) do
        if item.ItemType == "Holdable" then
            local itemName = (item.ItemName or item.Name or item.PlantName or "?"):lower()
            
            if itemName:find(reqName, 1, true) then
                local w = item.BaseWeight or item.Weight or 0
                if w >= reqWeight then
                    if reqMut then
                        local itemMut = item.MutationType or (item.ItemData and item.ItemData.MutationType) or "m"
                        if itemMut:lower() == reqMut then
                            return true
                        end
                    else
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- ⭐ MATCHER: Pencocokan Mutasi yang sudah diperbaiki
local function isRequestedByCat(info, requests)
    for _, req in ipairs(requests) do
        local reqName = req.PLANT_NAME:lower()
        local nameMatch = info.name:lower() == reqName
        if not nameMatch then
            nameMatch = info.name:lower():find(reqName, 1, true) ~= nil
        end
        
        local weightMatch = info.weight >= req.WEIGHT
        
        local mutMatch = true
        if req.MUTATION then
            mutMatch = false
            for _, m in ipairs(info.mutationList) do
                if m:lower() == req.MUTATION:lower() then
                    mutMatch = true
                    break
                end
            end
        end

        if nameMatch and weightMatch and mutMatch then
            return true
        end
    end
    return false
end

-- ⭐ FUNGSI SCAN FRUITS
local function scanFruits(requests)
    local matched, allFound = {}, {}
    local currentTime = tick()

    for _, fruit in ipairs(CollectionService:GetTagged("Harvestable")) do
        if fruit:IsA("Model") and IsMyFruit(fruit) then
            local cachedData = ignoredFruits[fruit]
            if cachedData and (currentTime - cachedData.time) < IGNORE_TIME then
                table.insert(allFound, cachedData.info)
                continue
            end
        
            local info = getFruitInfo(fruit)
            if info and info.name ~= "" then
                table.insert(allFound, info)
            
                if isFruitReady(fruit) and isRequestedByCat(info, requests) then
                    table.insert(matched, info)
                    ignoredFruits[fruit] = nil
                else
                    ignoredFruits[fruit] = { time = currentTime, info = info } 
                end
            end
        end
    end
    return matched, allFound
end

-- =====================================================
-- LOGIKA UTAMA
-- =====================================================
local function getCatRequests()
    if not HungryController then return {} end
    local success, progress = pcall(function()
        return HungryController:GetProgress()
    end)
    if success and progress and progress.Remaining then
        return progress.Remaining
    end
    return {}
end

local function updateCatStats()
    if not (catStatsLbl and catStatsLbl.Parent) then return end
    local requests = getCatRequests()
    
    if #requests == 0 then
        catStatsLbl.Text = "✅ Semua request terpenuhi! Kucing kenyang."
        catStatsLbl.TextColor3 = C.success
        return
    end
    
    local text = "🎯 Request Kucing:\n"
    for i, req in ipairs(requests) do
        local mut = req.MUTATION and ("["..req.MUTATION.."] ") or ""
        text = text .. string.format("%d. %s%s (%.2fkg+)\n", i, mut, req.PLANT_NAME, req.WEIGHT)
    end
    catStatsLbl.Text = text
    catStatsLbl.TextColor3 = C.text
end

task.spawn(function()
    while true do
        task.wait(2)
        if catStatsLbl and catStatsLbl.Parent then
            updateCatStats()
        else
            break
        end
    end
end)

-- Tombol Toggle
local catToggleBtn
catToggleBtn = createBtn(CatSection, "▶️ Mulai Collect untuk Kucing", 125, C.success, function()
    isCatRunning = not isCatRunning
    
    if isCatRunning then
        if catToggleBtn then
            catToggleBtn.Text = "⏹️ Stop Auto Harvester"
            catToggleBtn.BackgroundColor3 = C.danger
        end
        
        catThread = task.spawn(function()
            while isCatRunning do
                local requests = getCatRequests()
                if #requests == 0 then
                    catAction = "⏳ Menunggu kucing lapar..."
                    task.wait(5)
                    continue
                end
                
                -- 1. Cek inventory, filter request yang belum ada
                local missingRequests = {}
                for _, req in ipairs(requests) do
                    if not hasItemInInventory(req) then
                        table.insert(missingRequests, req)
                    end
                end
                
                local harvestedSomething = false
                
                -- 2. Scan & panen hanya yang kurang
                if #missingRequests > 0 then
                    local matched, _ = scanFruits(missingRequests)
                    if #matched > 0 then
                        catAction = string.format("🔄 Memanen %d buah...", #matched)
                        
                        local instances = {}
                        for _, info in ipairs(matched) do
                            table.insert(instances, info.instance)
                        end
                        
                        pcall(function()
                            CropsCollectRE:FireServer(instances)
                        end)
                        task.wait(2)
                        harvestedSomething = true
                    end
                end
                
                -- 3. Submit
                if harvestedSomething or #missingRequests == 0 then
                    catAction = "🐾 Submit ke Kucing..."
                    local token = math.random(100000, 999999)
                    pcall(function()
                        CatSubmitRE:FireServer({Token = token, Mode = "All"})
                    end)
                    task.wait(3)
                else
                    catAction = "⏳ Menunggu buah di kebun matang..."
                    task.wait(3)
                end
            end
        end)
    else
        if catToggleBtn then
            catToggleBtn.Text = "▶️ Mulai Collect untuk Kucing"
            catToggleBtn.BackgroundColor3 = C.success
        end
        if catThread then task.cancel(catThread) end
        catAction = "Stopped."
    end
end)

-- Loop UI Aksi
task.spawn(function()
    while true do
        task.wait(0.2)
        if catStatusLbl and catStatusLbl.Parent then
            catStatusLbl.Text = "Status: " .. catAction
            if catAction:find("Memotong") or catAction:find("Panen") or catAction:find("Submit") then
                catStatusLbl.TextColor3 = C.success
            elseif catAction:find("⏳") then
                catStatusLbl.TextColor3 = C.warning
            else
                catStatusLbl.TextColor3 = C.textDim
            end
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
