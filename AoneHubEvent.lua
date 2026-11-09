-- ==================================================================
-- ANUBIS EVENT SCRIPT (AoneHub Style UI) - PHASE 1
-- ==================================================================

local Context = _G.AoneHub_Event_Context
if not Context then return end

local Scroll = Context.Scroll
local createSection = Context.CreateSection
local C = Context.Colors

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local Workspace = game:GetService("Workspace")

local DataService = require(ReplicatedStorage.Modules.DataService)

-- ==================================================================
-- [PATCH] CLEANUP & ANTI-BENTROK
-- ==================================================================
local connections = {}

if _G.AoneHub_Event_Cleanup then
    pcall(_G.AoneHub_Event_Cleanup)
    _G.AoneHub_Event_Cleanup = nil
end

-- ==================================================================
-- HELPER UI
-- ==================================================================
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

local function formatTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if h > 0 then return string.format("%02d:%02d:%02d", h, m, s)
    else return string.format("%02d:%02d", m, s) end
end

-- ==================================================================
-- DEPENDENCIES & REMOTES
-- ==================================================================
local AncientArcConfig = require(ReplicatedStorage.Data.Events.AnubisEvent.AncientArcConfig)
local AnubisShopData = require(ReplicatedStorage.Data.Events.AnubisEvent.AnubisEventShopData).AnubisCoinShop

local AncientArcController = nil
pcall(function()
    AncientArcController = require(ReplicatedStorage.Modules.Events.AnubisEvent.AncientArcController)
end)

local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local AnubisSellRemote = GameEvents:WaitForChild("Events"):WaitForChild("AnubisEvent"):WaitForChild("AnubisCoinsSell"):WaitForChild("Sell")
local BuyShopRemote = GameEvents:WaitForChild("BuyEventShopStock")

-- ==================================================================
-- FITUR 1: TRACKER & DUNESTORM TIMER
-- ==================================================================
local TrackerSection = createSection(Scroll, "📊 Anubis Event Tracker", "anubisTracker")
TrackerSection.LayoutOrder = 1
TrackerSection.Size = UDim2.new(1, -10, 0, 180)

local stormStatusLbl = createStatusLbl(TrackerSection, "🌪️ DuneStorm: Loading...", 28, 14)
stormStatusLbl.TextColor3 = C.warning

local arcStatusLbl = createStatusLbl(TrackerSection, "⛏️ Archaeology: Loading...", 45, 30)
arcStatusLbl.TextColor3 = C.text

local rewardStatusLbl = createStatusLbl(TrackerSection, "🎁 Reward: ...", 80, 20)
rewardStatusLbl.TextColor3 = C.accent

local coinStatusLbl = createStatusLbl(TrackerSection, "🪙 AnubisCoins: 0", 105, 20)
coinStatusLbl.TextColor3 = C.success
coinStatusLbl.Font = Enum.Font.GothamBold

task.spawn(function()
    while TrackerSection and TrackerSection.Parent and not _G.AoneHub_IsDestroyed do
        task.wait(1)

        -- 1. DuneStorm
        local isStorm = Workspace:GetAttribute("DuneStorm")
        local stormEnd = Workspace:GetAttribute("DuneStormTimer")
        local stormNext = Workspace:GetAttribute("DuneStormNextAt")
        local now = Workspace:GetServerTimeNow()

        if isStorm and type(stormEnd) == "number" then
            stormStatusLbl.Text = string.format("🌪️ DuneStorm: AKTIF (%s)", formatTime(math.max(0, stormEnd - now)))
            stormStatusLbl.TextColor3 = C.danger
        elseif type(stormNext) == "number" and now < stormNext then
            stormStatusLbl.Text = string.format("🌪️ DuneStorm: %s", formatTime(stormNext - now))
            stormStatusLbl.TextColor3 = C.warning
        else
            stormStatusLbl.Text = "🌪️ DuneStorm: Menunggu jadwal..."
            stormStatusLbl.TextColor3 = C.textDim
        end

        -- 2. AnubisCoins
        local data = DataService:GetData()
        if data and data.SpecialCurrency then
            coinStatusLbl.Text = "🪙 AnubisCoins: " .. tostring(data.SpecialCurrency.AnubisCoins or 0)
        end

        -- 3. Archaeology Progress
        if AncientArcController then
            local ok, prog = pcall(function() return AncientArcController:GetProgress() end)
            if ok and prog then
                local stageStr = string.format("Stage %d/%d", prog.Stage or 1, prog.Max or 20)
                local objStr = prog.ObjectDisplay or "?"
                local chaseStr = prog.Chase and " ⚠️ CHASE!" or ""
                
                if prog.Done then
                    arcStatusLbl.Text = string.format("⛏️ Archaeology: %s | ✅ SELESAI", stageStr)
                    arcStatusLbl.TextColor3 = C.success
                    rewardStatusLbl.Text = "🎁 Reward: Klik NPC untuk Restart"
                elseif prog.Ready then
                    arcStatusLbl.Text = string.format("⛏️ Archaeology: %s | ✅ READY", stageStr)
                    arcStatusLbl.TextColor3 = C.success
                else
                    local weightStr = string.format("%.2f / %d kg", prog.Weight or 0, prog.Required or 0)
                    arcStatusLbl.Text = string.format("⛏️ Archaeology: %s\n🎯 %s%s | ⚖️ %s", stageStr, objStr, chaseStr, weightStr)
                    arcStatusLbl.TextColor3 = C.text
                end

                if prog.Reward then
                    rewardStatusLbl.Text = string.format("🎁 Reward: %s x%d", prog.Reward.Value or "?", prog.Reward.Quantity or 1)
                end
            else
                arcStatusLbl.Text = "⛏️ Archaeology: Error read progress"
            end
        end
    end
end)

-- ==================================================================
-- FITUR 2: AUTO SUBMIT ARCHAEOLOGY
-- ==================================================================
local SubmitSection = createSection(Scroll, "⛏️ Auto Submit Archaeology", "anubisSubmit")
SubmitSection.LayoutOrder = 2
SubmitSection.Size = UDim2.new(1, -10, 0, 90)

local isAutoSubmitRunning = false
local submitStatus = createStatusLbl(SubmitSection, "Status: Idle", 28, 14)

-- ⭐ SANGAT PENTING: Counter sequence manual
_G.AoneHub_AnubisSeq = _G.AoneHub_AnubisSeq or 0

local function doAutoSubmit()
    if not AncientArcController then return end
    
    local okProg, prog = pcall(function() return AncientArcController:GetProgress() end)
    if not okProg or not prog then return end
    
    -- Jangan submit kalau sudah Ready / Done
    if prog.Ready or prog.Done then return end

    -- Increment counter
    _G.AoneHub_AnubisSeq = _G.AoneHub_AnubisSeq + 1
    local currentSeq = _G.AoneHub_AnubisSeq

    local ok, res = pcall(function()
        return AncientArcController:Submit("All", currentSeq)
    end)

    if ok and res then
        if res.Success then
            if res.Reason == "Uncovered" then
                submitStatus.Text = "Status: 🎉 Uncovered object!"
                submitStatus.TextColor3 = C.success
            else
                submitStatus.Text = string.format("Status: ✅ +%.2f kg (Seq: %d)", res.Added or 0, currentSeq)
                submitStatus.TextColor3 = C.success
            end
        else
            -- Kalau gagal (misal: NoneFound / InvalidSeq)
            if res.Reason == "NoneFound" then
                submitStatus.Text = "Status: ⏳ Nunggu tanaman trait..."
                submitStatus.TextColor3 = C.warning
                _G.AoneHub_AnubisSeq = _G.AoneHub_AnubisSeq - 1 -- Rollback seq karena tidak ada yg disubmit
            else
                submitStatus.Text = "Status: ❌ " .. tostring(res.Reason)
                submitStatus.TextColor3 = C.danger
            end
        end
    else
        submitStatus.Text = "Status: ❌ Gagal (API Error)"
        submitStatus.TextColor3 = C.danger
    end
end

local submitBtn
submitBtn = createBtn(SubmitSection, "▶️ Mulai Auto Submit", 50, C.success, function()
    isAutoSubmitRunning = not isAutoSubmitRunning
    if isAutoSubmitRunning then
        submitBtn.Text = "⏹️ Stop Auto Submit"
        submitBtn.BackgroundColor3 = C.danger
        
        task.spawn(function()
            while isAutoSubmitRunning and not _G.AoneHub_IsDestroyed do
                doAutoSubmit()
                task.wait(1.2) -- Cooldown aman (min 0.75s)
            end
            submitStatus.Text = "Status: Stopped"
            submitStatus.TextColor3 = C.textDim
        end)
    else
        submitBtn.Text = "▶️ Mulai Auto Submit"
        submitBtn.BackgroundColor3 = C.success
    end
end)

-- ==================================================================
-- FITUR 3: AUTO SELL HIERO FRUITS
-- ==================================================================
local SellSection = createSection(Scroll, "🌾 Auto Sell Hiero Fruits", "anubisSell")
SellSection.LayoutOrder = 3
SellSection.Size = UDim2.new(1, -10, 0, 90)

local isAutoSellRunning = false
local sellStatus = createStatusLbl(SellSection, "Status: Idle", 28, 14)

local sellBtn
sellBtn = createBtn(SellSection, "▶️ Mulai Auto Sell", 50, C.success, function()
    isAutoSellRunning = not isAutoSellRunning
    if isAutoSellRunning then
        sellBtn.Text = "⏹️ Stop Auto Sell"
        sellBtn.BackgroundColor3 = C.danger
        
        task.spawn(function()
            while isAutoSellRunning and not _G.AoneHub_IsDestroyed do
                -- Fire remote SellAll
                pcall(function()
                    AnubisSellRemote:FireServer("SellAll")
                end)
                sellStatus.Text = "Status: 🪙 Menjual buah hieroglyphic..."
                sellStatus.TextColor3 = C.success
                
                task.wait(3) -- Jeda 3 detik antar jual
            end
            sellStatus.Text = "Status: Stopped"
            sellStatus.TextColor3 = C.textDim
        end)
    else
        sellBtn.Text = "▶️ Mulai Auto Sell"
        sellBtn.BackgroundColor3 = C.success
    end
end)

-- ==================================================================
-- FITUR 4: AUTO BUY ANUBIS SHOP
-- ==================================================================
local BuySection = createSection(Scroll, "🛒 Auto Buy Anubis Shop", "anubisBuy")
BuySection.LayoutOrder = 4
BuySection.Size = UDim2.new(1, -10, 0, 320)

local isAutoBuyRunning = false
local buyStatus = createStatusLbl(BuySection, "Status: Idle", 28, 14)

-- Config penyimpanan item yang dipilih
if _G.AoneHub_Config then
    _G.AoneHub_Config.anubisSelectedItems = _G.AoneHub_Config.anubisSelectedItems or {}
end
local selectedItems = _G.AoneHub_Config and _G.AoneHub_Config.anubisSelectedItems or {}

-- Scroll List Item
local itemScroll = Instance.new("ScrollingFrame")
itemScroll.Size = UDim2.new(1, -20, 0, 180)
itemScroll.Position = UDim2.new(0, 10, 0, 50)
itemScroll.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
itemScroll.BorderSizePixel = 0
itemScroll.ScrollBarThickness = 4
itemScroll.ScrollBarImageColor3 = C.accent
itemScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
itemScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
itemScroll.Parent = BuySection
Instance.new("UICorner", itemScroll).CornerRadius = UDim.new(0, 4)

local itemLayout = Instance.new("UIListLayout")
itemLayout.Padding = UDim.new(0, 2)
itemLayout.SortOrder = Enum.SortOrder.LayoutOrder
itemLayout.Parent = itemScroll

local function renderShopItems()
    for _, c in ipairs(itemScroll:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end

    local items = {}
    for name, config in pairs(AnubisShopData) do
        table.insert(items, {Name = name, Config = config})
    end
    
    -- Urutkan berdasarkan LayoutOrder
    table.sort(items, function(a, b)
        return (a.Config.LayoutOrder or 999) < (b.Config.LayoutOrder or 999)
    end)

    local data = DataService:GetData()
    local shopStock = data and data.EventShopStock and data.EventShopStock["Anubis Coin Shop"]
    
    for i, item in ipairs(items) do
        local name = item.Name
        local cfg = item.Config
        local price = cfg.Price or 0
        
        -- Cek stok
        local stock = 0
        if shopStock and shopStock.Stocks and shopStock.Stocks[name] then
            stock = shopStock.Stocks[name].Stock or 0
        end
        
        -- Cek unlock (pura-pura unlock biar user tetap bisa pilih)
        local isLocked = cfg.LockedInShop 

        local isSel = selectedItems[name] == true
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -8, 0, 24)
        btn.BackgroundColor3 = isSel and Color3.fromRGB(60, 130, 220) or Color3.fromRGB(45, 45, 58)
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.LayoutOrder = i
        btn.Parent = itemScroll
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)

        local icon = Instance.new("TextLabel")
        icon.Size = UDim2.new(0, 20, 1, 0)
        icon.BackgroundTransparency = 1
        icon.Text = isSel and "✓" or (isLocked and "🔒" or "○")
        icon.TextColor3 = isSel and C.text or (isLocked and C.danger or C.textDim)
        icon.Font = Enum.Font.GothamBold
        icon.TextSize = 10
        icon.Parent = btn

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(0.55, 0, 1, 0)
        nameLbl.Position = UDim2.new(0, 20, 0, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = string.format("%s (%d AC)", name, price)
        nameLbl.TextColor3 = isLocked and C.textDim or C.text
        nameLbl.Font = Enum.Font.Gotham
        nameLbl.TextSize = 8
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.Parent = btn

        local stockLbl = Instance.new("TextLabel")
        stockLbl.Size = UDim2.new(0.2, 0, 1, 0)
        stockLbl.Position = UDim2.new(0.8, 0, 0, 0)
        stockLbl.BackgroundTransparency = 1
        stockLbl.Text = stock > 0 and ("📦 "..stock) or "❌ 0"
        stockLbl.TextColor3 = stock > 0 and C.success or C.danger
        stockLbl.Font = Enum.Font.GothamBold
        stockLbl.TextSize = 8
        stockLbl.TextXAlignment = Enum.TextXAlignment.Right
        stockLbl.Parent = btn
        
        local pad = Instance.new("UIPadding")
        pad.PaddingRight = UDim.new(0, 5)
        pad.Parent = stockLbl

        btn.MouseButton1Click:Connect(function()
            if selectedItems[name] then
                selectedItems[name] = nil
            else
                selectedItems[name] = true
            end
            if _G.AoneHub_Config then
                _G.AoneHub_Config.anubisSelectedItems = selectedItems
                if _G.AoneHub_SaveConfig then _G.AoneHub_SaveConfig() end
            end
            renderShopItems()
        end)
    end
end

renderShopItems()
-- Refresh UI tiap 5 detik buat update stok
task.spawn(function()
    while BuySection and BuySection.Parent and not _G.AoneHub_IsDestroyed do
        task.wait(5)
        renderShopItems()
    end
end)

local buyBtn
buyBtn = createBtn(BuySection, "▶️ Mulai Auto Buy", 240, C.success, function()
    isAutoBuyRunning = not isAutoBuyRunning
    if isAutoBuyRunning then
        buyBtn.Text = "⏹️ Stop Auto Buy"
        buyBtn.BackgroundColor3 = C.danger
        
        task.spawn(function()
            while isAutoBuyRunning and not _G.AoneHub_IsDestroyed do
                local data = DataService:GetData()
                local coins = data and data.SpecialCurrency and data.SpecialCurrency.AnubisCoins or 0
                
                local bought = false
                for name, _ in pairs(selectedItems) do
                    local cfg = AnubisShopData[name]
                    if cfg and coins >= (cfg.Price or 0) then
                        -- Fire Remote
                        pcall(function()
                            BuyShopRemote:FireServer(name, "Anubis Coin Shop")
                        end)
                        buyStatus.Text = string.format("Status: 🛒 Beli %s...", name)
                        buyStatus.TextColor3 = C.success
                        bought = true
                        task.wait(1.5) -- Jeda antar beli
                        break -- Ulangi loop untuk cek coins terbaru
                    end
                end
                
                if not bought then
                    buyStatus.Text = "Status: ⏳ Nunggu stok / koin cukup..."
                    buyStatus.TextColor3 = C.warning
                    task.wait(3)
                end
            end
            buyStatus.Text = "Status: Stopped"
            buyStatus.TextColor3 = C.textDim
        end)
    else
        buyBtn.Text = "▶️ Mulai Auto Buy"
        buyBtn.BackgroundColor3 = C.success
    end
end)

-- ==================================================================
-- CLEANUP
-- ==================================================================
_G.AoneHub_Event_Cleanup = function()
    isAutoSubmitRunning = false
    isAutoSellRunning = false
    isAutoBuyRunning = false
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(connections)
end
