-- ==================================================================
-- ANUBIS EVENT SCRIPT (AoneHub Style UI) - FULL VERSION
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
local HttpService = game:GetService("HttpService")

local DataService = require(ReplicatedStorage.Modules.DataService)
local TeleportPlayer = require(ReplicatedStorage.Modules.TeleportPlayer)
local GetFarm = require(ReplicatedStorage.Modules.GetFarm)

-- ==================================================================
-- [PATCH] CLEANUP & ANTI-BENTROK
-- ==================================================================
local connections = {}

if _G.AoneHub_Event_Cleanup then
    pcall(_G.AoneHub_Event_Cleanup)
    _G.AoneHub_Event_Cleanup = nil
end

-- ==================================================================
-- KONFIGURASI EVENT TERPISAH
-- ==================================================================
local EVENT_SAVE_DIR = "AoneHub"
local EVENT_SAVE_FILE = EVENT_SAVE_DIR .. "/AoneHub_AnubisEvent.json"

pcall(function() makefolder(EVENT_SAVE_DIR) end)

local EventConfig = {
    anubisAutoSubmit = false,
    anubisAutoSell = false,
    anubisAutoBuy = false,
    anubisAutoRestart = false,
    anubisAutoCharge = false,
    anubisSelectedItems = {}
}

local function loadEventConfig()
    local s, d = pcall(readfile, EVENT_SAVE_FILE)
    if s and d then
        local s2, loaded = pcall(HttpService.JSONDecode, HttpService, d)
        if s2 and type(loaded) == "table" then
            for k, v in pairs(loaded) do
                EventConfig[k] = v
            end
        end
    end
end

local function saveEventConfig()
    local s, json = pcall(HttpService.JSONEncode, HttpService, EventConfig)
    if s then 
        pcall(writefile, EVENT_SAVE_FILE, json) 
    end
end

loadEventConfig()

-- ==================================================================
-- HELPER UI & DATA
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

-- ⭐ FUNGSI DETEKSI TRAIT (Berdasarkan Path Terbaru)
local function getActiveTrait()
    local interaction = Workspace:FindFirstChild("Interaction")
    local eventModel = interaction and interaction:FindFirstChild("AnubisEventModel")
    local arcModel = eventModel and eventModel:FindFirstChild("AncientArc")
    local important = arcModel and arcModel:FindFirstChild("Important")
    
    if important then
        local bubble = important:FindFirstChild("ThoughtBubblePart")
        if bubble then
            local target = bubble:FindFirstChild("Target")
            local holder = target and target:FindFirstChild("Holder")
            local traitObj = holder and holder:FindFirstChild("Trait")
            if traitObj then
                local text = traitObj.ContentText or traitObj.Text
                if text and type(text) == "string" then
                    local match = string.match(text, "Looking for (.-) plants!")
                    if match then return match end
                end
            end
        end
    end
    
    local TRAIT_OPTIONS = {"Berry", "Fruit", "Flower", "Vegetable", "Tropical", "Prickly", "Woody", "Leafy", "Stalky", "Root", "Sweet", "Sour"}
    local timeSinceEpoch = Workspace:GetServerTimeNow() - (AncientArcConfig.TRAIT_EPOCH or 0)
    local switchCount = math.floor(timeSinceEpoch / (AncientArcConfig.TRAIT_SWITCH_TIMER or 1800))
    local seed = AncientArcConfig.TRAIT_SEED or 104729
    local currentIdx = ((switchCount + seed - 1) % #TRAIT_OPTIONS) + 1
    
    return TRAIT_OPTIONS[currentIdx]
end

-- ==================================================================
-- FITUR 1: TRACKER & DUNESTORM TIMER
-- ==================================================================
local TrackerSection = createSection(Scroll, "📊 Anubis Event Tracker", "anubisTracker")
TrackerSection.LayoutOrder = 1
TrackerSection.Size = UDim2.new(1, -10, 0, 195)

local stormStatusLbl = createStatusLbl(TrackerSection, "🌪️ DuneStorm: Loading...", 28, 14)
stormStatusLbl.TextColor3 = C.warning

local arcStatusLbl = createStatusLbl(TrackerSection, "⛏️ Archaeology: Loading...", 45, 30)
arcStatusLbl.TextColor3 = C.text

local traitStatusLbl = createStatusLbl(TrackerSection, "🎯 Trait: ...", 78, 16)
traitStatusLbl.TextColor3 = C.success
traitStatusLbl.Font = Enum.Font.GothamBold

local rewardStatusLbl = createStatusLbl(TrackerSection, "🎁 Reward: ...", 96, 20)
rewardStatusLbl.TextColor3 = C.accent

local coinStatusLbl = createStatusLbl(TrackerSection, "💰 AnubisCoins: 0", 125, 20)
coinStatusLbl.TextColor3 = C.warning
coinStatusLbl.Font = Enum.Font.GothamBold

task.spawn(function()
    while TrackerSection and TrackerSection.Parent and not _G.AoneHub_IsDestroyed do
        task.wait(1)

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

        local data = DataService:GetData()
        if data and data.SpecialCurrency then
            coinStatusLbl.Text = "💰 AnubisCoins: " .. tostring(data.SpecialCurrency.AnubisCoins or 0)
        end

        local currentTrait = getActiveTrait()
        traitStatusLbl.Text = string.format("🎯 Trait: %s", tostring(currentTrait or "?"))

        if AncientArcController then
            local ok, prog = pcall(function() return AncientArcController:GetProgress() end)
            if ok and prog then
                local stageStr = string.format("Stage %d/%d", prog.Stage or 1, prog.Max or 20)
                local objStr = tostring(prog.ObjectDisplay or "?")
                local chaseStr = prog.Chase and " ⚠️ CHASE!" or ""
                
                if prog.Done then
                    arcStatusLbl.Text = string.format("⛏️ Archaeology: %s | ✅ SELESAI", tostring(stageStr))
                    arcStatusLbl.TextColor3 = C.success
                    rewardStatusLbl.Text = "🎁 Reward: Klik NPC untuk Restart"
                elseif prog.Ready then
                    arcStatusLbl.Text = string.format("⛏️ Archaeology: %s | ✅ READY", tostring(stageStr))
                    arcStatusLbl.TextColor3 = C.success
                else
                    local weightStr = string.format("%.2f / %d kg", prog.Weight or 0, prog.Required or 0)
                    arcStatusLbl.Text = string.format("⛏️ Archaeology: %s\n🎯 %s%s | ⚖️ %s", tostring(stageStr), objStr, chaseStr, weightStr)
                    arcStatusLbl.TextColor3 = C.text
                end

                if prog.Reward then
                    rewardStatusLbl.Text = string.format("🎁 Reward: %s x%d", tostring(prog.Reward.Value or "?"), prog.Reward.Quantity or 1)
                end
            end
        end
    end
end)

-- ==================================================================
-- FITUR 2: AUTO SUBMIT (Teleport & Cek Jarak 10x)
-- ==================================================================
local SubmitSection = createSection(Scroll, "⛏️ Auto Submit Archaeology", "anubisSubmit")
SubmitSection.LayoutOrder = 2
SubmitSection.Size = UDim2.new(1, -10, 0, 90)

local isAutoSubmitRunning = false
local submitStatus = createStatusLbl(SubmitSection, "Status: Idle", 28, 14)

_G.AoneHub_AnubisSeq = _G.AoneHub_AnubisSeq or 0
local savedSubmitCFrame = nil

local function getArchieCFrame()
    local interaction = Workspace:FindFirstChild("Interaction")
    local eventModel = interaction and interaction:FindFirstChild("AnubisEventModel")
    local arcModel = eventModel and eventModel:FindFirstChild("AncientArc")
    local important = arcModel and arcModel:FindFirstChild("Important")
    local npc = important and important:FindFirstChild("NPC")
    local hrp = npc and npc:FindFirstChild("HumanoidRootPart")
    if not (hrp and hrp:IsA("BasePart")) then return nil end
    
    local pos = hrp.Position + hrp.CFrame.LookVector * 5
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { Player.Character }
    
    local ray = Workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -20, 0), params)
    local targetY = ray and (ray.Position.Y + 3) or pos.Y
    return CFrame.lookAt(Vector3.new(pos.X, targetY, pos.Z), Vector3.new(hrp.Position.X, targetY, hrp.Position.Z))
end

local function doAutoSubmitCycle()
    if not AncientArcController then return end
    
    local okProg, prog = pcall(function() return AncientArcController:GetProgress() end)
    if not okProg or not prog or prog.Ready or prog.Done then return end

    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if not savedSubmitCFrame then
        savedSubmitCFrame = hrp.CFrame
    end

    submitStatus.Text = "Status: ⏳ Memulai 10x Submit..."
    submitStatus.TextColor3 = C.warning
    
    local npcCFrame = getArchieCFrame()
    if not npcCFrame then
        submitStatus.Text = "Status: ❌ NPC Archie tidak ditemukan!"
        submitStatus.TextColor3 = C.danger
        return
    end

    for i = 1, 10 do
        if not isAutoSubmitRunning then break end

        local okP, currentProg = pcall(function() return AncientArcController:GetProgress() end)
        if okP and (currentProg.Ready or currentProg.Done) then break end

        local myPos = hrp.Position
        local npcPos = npcCFrame.Position
        local distance = (myPos - npcPos).Magnitude

        -- Cek Jarak Sebelum Submit
        if distance > 40 then
            submitStatus.Text = string.format("Status: 🏃 Teleport (%d/10)...", i)
            submitStatus.TextColor3 = C.accent
            
            pcall(function() TeleportPlayer(Player, npcCFrame, "Archie") end)
            task.wait(1.5)
            
            myPos = hrp.Position
            distance = (myPos - npcPos).Magnitude
            
            if distance > 40 then
                submitStatus.Text = "Status: ⚠️ Teleport gagal/nyangkut, menyerah."
                submitStatus.TextColor3 = C.danger
                break
            end
        end

        -- Jarak Aman, Tembak Submit
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
                    break
                else
                    submitStatus.Text = string.format("Status: ✅ Submit %d/10 (+%.2f kg)", i, res.Added or 0)
                    submitStatus.TextColor3 = C.success
                end
            else
                if res.Reason == "NoneFound" or res.Reason == "NoPlant" then
                    submitStatus.Text = "Status: ⏳ Buah trait habis."
                    submitStatus.TextColor3 = C.warning
                    _G.AoneHub_AnubisSeq = _G.AoneHub_AnubisSeq - 1
                    break
                else
                    submitStatus.Text = "Status: ❌ " .. tostring(res.Reason)
                    submitStatus.TextColor3 = C.danger
                    break
                end
            end
        else
            break
        end
        task.wait(1)
    end

    -- Kembali ke posisi awal
    if savedSubmitCFrame and isAutoSubmitRunning then
        submitStatus.Text = "Status: 🔙 Kembali ke kebun..."
        pcall(function() TeleportPlayer(Player, savedSubmitCFrame, "Return") end)
        task.wait(1.5)
    end
end

local submitBtn
local function toggleAutoSubmit()
    isAutoSubmitRunning = not isAutoSubmitRunning
    EventConfig.anubisAutoSubmit = isAutoSubmitRunning
    saveEventConfig()
    
    if isAutoSubmitRunning then
        submitBtn.Text = "⏹️ Stop Auto Submit"
        submitBtn.BackgroundColor3 = C.danger
        savedSubmitCFrame = nil
        task.spawn(function()
            while isAutoSubmitRunning and not _G.AoneHub_IsDestroyed do
                doAutoSubmitCycle()
                task.wait(10) 
            end
            submitStatus.Text = "Status: Stopped"
            submitStatus.TextColor3 = C.textDim
        end)
    else
        submitBtn.Text = "▶️ Mulai Auto Submit"
        submitBtn.BackgroundColor3 = C.success
        if savedSubmitCFrame then
            pcall(function() TeleportPlayer(Player, savedSubmitCFrame, "Return") end)
            savedSubmitCFrame = nil
        end
    end
end

submitBtn = createBtn(SubmitSection, "▶️ Mulai Auto Submit", 50, C.success, toggleAutoSubmit)

-- ==================================================================
-- FITUR 3: SMART AUTO SELL (Trader Tina)
-- ==================================================================
local SellSection = createSection(Scroll, "🌾 Smart Auto Sell (Anubis)", "anubisSell")
SellSection.LayoutOrder = 3
SellSection.Size = UDim2.new(1, -10, 0, 130)

local isSellEnabled = false
local inventoryThread = nil
local statusSellLbl = createStatusLbl(SellSection, "Status: Idle", 28, 30)

local function getTraderTinaCFrame()
    local interaction = Workspace:FindFirstChild("Interaction")
    local eventModel = interaction and interaction:FindFirstChild("AnubisEventModel")
    local tina = eventModel and eventModel:FindFirstChild("Trader Tina")
    local hrp = tina and tina:FindFirstChild("HumanoidRootPart")
    if not (hrp and hrp:IsA("BasePart")) then return nil end
    
    local pos = hrp.Position + hrp.CFrame.LookVector * 5
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { Player.Character }
    
    local ray = Workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -20, 0), params)
    local targetY = ray and (ray.Position.Y + 3) or pos.Y
    return CFrame.lookAt(Vector3.new(pos.X, targetY, pos.Z), Vector3.new(hrp.Position.X, targetY, hrp.Position.Z))
end

local function doAnubisSell()
    if not statusSellLbl or not statusSellLbl.Parent then return end
    if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then return end
    
    statusSellLbl.Text = "⏳ Teleport ke Trader Tina..."
    statusSellLbl.TextColor3 = C.warning
    
    local hrp = Player.Character.HumanoidRootPart
    local savedCFrame = hrp.CFrame
    
    local tinaCFrame = getTraderTinaCFrame()
    if not tinaCFrame then
        statusSellLbl.Text = "❌ Gagal temukan Trader Tina!"
        statusSellLbl.TextColor3 = C.danger
        return
    end
    
    pcall(function() TeleportPlayer(Player, tinaCFrame, "Anubis Trader") end)
    task.wait(2.5)
    
    if statusSellLbl and statusSellLbl.Parent then 
        statusSellLbl.Text = "💰 Menjual buah..." 
        statusSellLbl.TextColor3 = C.success
    end
    pcall(function() AnubisSellRemote:FireServer("SellAll") end)
    task.wait(3.5)
    
    if statusSellLbl and statusSellLbl.Parent then 
        statusSellLbl.Text = "🔙 Kembali ke kebun..." 
        statusSellLbl.TextColor3 = C.warning
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
    
    if statusSellLbl and statusSellLbl.Parent then
        statusSellLbl.Text = "✅ Selesai!"
        statusSellLbl.TextColor3 = C.success
    end
end

local sellToggleBtn
local function toggleAutoSell()
    isSellEnabled = not isSellEnabled
    EventConfig.anubisAutoSell = isSellEnabled
    saveEventConfig()
    
    if isSellEnabled then
        if sellToggleBtn then 
            sellToggleBtn.Text = "⏹️ Matikan Smart Auto-Sell"
            sellToggleBtn.BackgroundColor3 = C.danger 
        end
        
        if _G.AoneHub_SetAutoSellFruit then _G.AoneHub_SetAutoSellFruit(false) end
        
        statusSellLbl.Text = "🏺 Mode Anubis aktif (Trader Tina)"
        statusSellLbl.TextColor3 = C.text
        
        if inventoryThread then task.cancel(inventoryThread) end
        inventoryThread = task.spawn(function()
            while isSellEnabled and not _G.AoneHub_IsDestroyed do
                if not (statusSellLbl and statusSellLbl.Parent) then break end
                local curr, max = getFruitCapacity()
                statusSellLbl.Text = string.format("🏺 Anubis | 📦 %d/%d", curr, max)
                statusSellLbl.TextColor3 = C.text
                
                if curr >= max then
                    statusSellLbl.Text = "🚨 Penuh! Menjual..."
                    statusSellLbl.TextColor3 = C.danger
                    doAnubisSell()
                    task.wait(5)
                end
                task.wait(2)
            end
        end)
    else
        if sellToggleBtn then 
            sellToggleBtn.Text = "▶️ Aktifkan Smart Auto-Sell"
            sellToggleBtn.BackgroundColor3 = C.success 
        end
        if inventoryThread then 
            task.cancel(inventoryThread)
            inventoryThread = nil 
        end
        if _G.AoneHub_SetAutoSellFruit then _G.AoneHub_SetAutoSellFruit(true) end
        if statusSellLbl and statusSellLbl.Parent then 
            statusSellLbl.Text = "Status: Idle (Auto Sell Utama menyala)"
            statusSellLbl.TextColor3 = C.textDim 
        end
    end
end

sellToggleBtn = createBtn(SellSection, "▶️ Aktifkan Smart Auto-Sell", 60, C.success, toggleAutoSell)

-- ==================================================================
-- FITUR 4: AUTO BUY ANUBIS SHOP (Opsi A: Gembok)
-- ==================================================================
local BuySection = createSection(Scroll, "🛒 Auto Buy Anubis Shop", "anubisBuy")
BuySection.LayoutOrder = 4
BuySection.Size = UDim2.new(1, -10, 0, 320)

local isAutoBuyRunning = false
local buyStatus = createStatusLbl(BuySection, "Status: Idle", 28, 14)
local selectedItems = EventConfig.anubisSelectedItems or {}

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
    
    table.sort(items, function(a, b)
        return (a.Config.LayoutOrder or 999) < (b.Config.LayoutOrder or 999)
    end)

    local data = DataService:GetData()
    local shopStock = data and data.EventShopStock and data.EventShopStock["Anubis Coin Shop"]
    
    local unlockedDict = {}
    if data and data.UnlockedEventShopItems then
        for _, itemName in ipairs(data.UnlockedEventShopItems) do
            unlockedDict[itemName] = true
        end
    end
    
    for i, item in ipairs(items) do
        local name = item.Name
        local cfg = item.Config
        local price = cfg.Price or 0
        
        local stock = 0
        if shopStock and shopStock.Stocks and shopStock.Stocks[name] then
            stock = shopStock.Stocks[name].Stock or 0
        end
        
        local isLocked = cfg.LockedInShop and not unlockedDict[name]
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
            if isLocked then
                buyStatus.Text = "⚠️ " .. name .. " masih terkunci!"
                buyStatus.TextColor3 = C.danger
                task.delay(3, function()
                    if buyStatus and buyStatus.Parent then buyStatus.Text = "Status: Idle" end
                end)
                return
            end

            if selectedItems[name] then
                selectedItems[name] = nil
            else
                selectedItems[name] = true
            end
            
            EventConfig.anubisSelectedItems = selectedItems
            saveEventConfig()
            renderShopItems()
        end)
    end
end

renderShopItems()
task.spawn(function()
    while BuySection and BuySection.Parent and not _G.AoneHub_IsDestroyed do
        task.wait(5)
        renderShopItems()
    end
end)

local buyBtn
local function toggleAutoBuy()
    isAutoBuyRunning = not isAutoBuyRunning
    EventConfig.anubisAutoBuy = isAutoBuyRunning
    saveEventConfig()
    
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
                        pcall(function() BuyShopRemote:FireServer(name, "Anubis Coin Shop") end)
                        buyStatus.Text = string.format("Status: 🛒 Beli %s...", name)
                        buyStatus.TextColor3 = C.success
                        bought = true
                        task.wait(1.5)
                        break 
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
end

buyBtn = createBtn(BuySection, "▶️ Mulai Auto Buy", 240, C.success, toggleAutoBuy)

-- ==================================================================
-- FITUR 5: AUTO RESTART ARCHAEOLOGY
-- ==================================================================
local RestartSection = createSection(Scroll, "🔄 Auto Restart Archaeology", "anubisRestart")
RestartSection.LayoutOrder = 5
RestartSection.Size = UDim2.new(1, -10, 0, 90)

local isAutoRestartRunning = false
local restartStatus = createStatusLbl(RestartSection, "Status: Idle", 28, 14)

local restartBtn
local function toggleAutoRestart()
    isAutoRestartRunning = not isAutoRestartRunning
    EventConfig.anubisAutoRestart = isAutoRestartRunning
    saveEventConfig()
    
    if isAutoRestartRunning then
        restartBtn.Text = "⏹️ Stop Auto Restart"
        restartBtn.BackgroundColor3 = C.danger
        
        task.spawn(function()
            while isAutoRestartRunning and not _G.AoneHub_IsDestroyed do
                if not AncientArcController then task.wait(2) continue end
                
                local ok, prog = pcall(function() return AncientArcController:GetProgress() end)
                if ok and prog and prog.Done then
                    restartStatus.Text = "Status: 🔄 Mencoba restart..."
                    restartStatus.TextColor3 = C.warning
                    
                    local success, res = pcall(function()
                        return AncientArcController:RestartWithSheckles()
                    end)
                    
                    if success and res and res.Success then
                        restartStatus.Text = "Status: ✅ Restart Sukses!"
                        restartStatus.TextColor3 = C.success
                        _G.AoneHub_AnubisSeq = 0
                        task.wait(5)
                    else
                        local reason = (res and res.Reason) or "Error"
                        restartStatus.Text = "Status: ❌ Gagal (" .. tostring(reason) .. ")"
                        restartStatus.TextColor3 = C.danger
                        task.wait(10) 
                    end
                else
                    restartStatus.Text = "Status: ⏳ Menunggu stage selesai..."
                    restartStatus.TextColor3 = C.textDim
                    task.wait(3)
                end
                task.wait(2)
            end
            restartStatus.Text = "Status: Stopped"
            restartStatus.TextColor3 = C.textDim
        end)
    else
        restartBtn.Text = "▶️ Mulai Auto Restart"
        restartBtn.BackgroundColor3 = C.success
    end
end

restartBtn = createBtn(RestartSection, "▶️ Mulai Auto Restart", 50, C.success, toggleAutoRestart)

-- ==================================================================
-- FITUR 6: AUTO CHARGE OBELISK
-- ==================================================================
local ChargeSection = createSection(Scroll, "⚡ Auto Charge Obelisk", "anubisCharge")
ChargeSection.LayoutOrder = 6
ChargeSection.Size = UDim2.new(1, -10, 0, 90)

local isAutoChargeRunning = false
local chargeStatus = createStatusLbl(ChargeSection, "Status: Idle", 28, 14)
local savedChargeCFrame = nil
local chargeThread = nil

local function getObeliskFolder()
    return Workspace:FindFirstChild("EmpoweredAnubisObelisks")
end

local function doAutoChargeCycle()
    if not isAutoChargeRunning then return end
    
    if not Workspace:GetAttribute("DuneStorm") then
        chargeStatus.Text = "Status: ⏳ Menunggu DuneStorm..."
        chargeStatus.TextColor3 = C.warning
        return
    end
    
    local folder = getObeliskFolder()
    if not folder then
        chargeStatus.Text = "Status: ⏳ Obelisk belum muncul..."
        chargeStatus.TextColor3 = C.warning
        return
    end
    
    local unpowered = {}
    for _, obj in ipairs(folder:GetChildren()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            if not obj:GetAttribute("Powered") then
                table.insert(unpowered, obj)
            end
        end
    end
    
    if #unpowered == 0 then
        chargeStatus.Text = "Status: ✅ Semua Obelisk Penuh!"
        chargeStatus.TextColor3 = C.success
        if savedChargeCFrame then
            pcall(function() TeleportPlayer(Player, savedChargeCFrame, "Return") end)
            savedChargeCFrame = nil
        end
        isAutoChargeRunning = false
        chargeBtn.Text = "▶️ Mulai Auto Charge"
        chargeBtn.BackgroundColor3 = C.success
        EventConfig.anubisAutoCharge = false
        saveEventConfig()
        return
    end
    
    local target = unpowered[1]
    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    if not savedChargeCFrame then
        savedChargeCFrame = hrp.CFrame
    end
    
    local targetPos = target:GetPivot().Position
    local lookDir = (targetPos - hrp.Position).Unit
    local flatLook = Vector3.new(lookDir.X, 0, lookDir.Z).Unit
    local teleportPos = targetPos - (flatLook * 6) + Vector3.new(0, 3, 0)
    local targetCFrame = CFrame.lookAt(teleportPos, targetPos)
    
    chargeStatus.Text = string.format("Status: ⚡ Mendekati Obelisk (%d tersisa)...", #unpowered)
    chargeStatus.TextColor3 = C.accent
    pcall(function() TeleportPlayer(Player, targetCFrame, "Obelisk") end)
    task.wait(1.5)
    
    local prompt = target:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        chargeStatus.Text = "Status: 🔨 Menekan tombol (10x)..."
        chargeStatus.TextColor3 = C.success
        
        for i = 1, 10 do
            if not isAutoChargeRunning then break end
            if target:GetAttribute("Powered") then break end
            
            if fireproximityprompt then
                pcall(fireproximityprompt, prompt)
            else
                pcall(function()
                    prompt:InputHoldBegin()
                    task.wait(0.6)
                    prompt:InputHoldEnd()
                end)
            end
            task.wait(0.6)
        end
        
        local timeout = 10
        local timer = 0
        while not target:GetAttribute("Powered") and timer < timeout do
            task.wait(1)
            timer = timer + 1
        end
        
        if target:GetAttribute("Powered") then
            chargeStatus.Text = "Status: ✅ Obelisk Penuh! Jeda 5 detik..."
            chargeStatus.TextColor3 = C.success
        else
            chargeStatus.Text = "Status: ⚠️ Gagal charge, pindah..."
            chargeStatus.TextColor3 = C.danger
        end
    else
        chargeStatus.Text = "Status: ⚠️ ProximityPrompt tidak ditemukan!"
        chargeStatus.TextColor3 = C.danger
    end
    
    task.wait(5)
end

local chargeBtn
local function toggleAutoCharge()
    isAutoChargeRunning = not isAutoChargeRunning
    EventConfig.anubisAutoCharge = isAutoChargeRunning
    saveEventConfig()
    
    if isAutoChargeRunning then
        if not Workspace:GetAttribute("DuneStorm") then
            chargeStatus.Text = "Status: ❌ DuneStorm tidak aktif!"
            chargeStatus.TextColor3 = C.danger
            isAutoChargeRunning = false
            EventConfig.anubisAutoCharge = false
            saveEventConfig()
            return
        end
        
        chargeBtn.Text = "⏹️ Stop Auto Charge"
        chargeBtn.BackgroundColor3 = C.danger
        
        if chargeThread then task.cancel(chargeThread) end
        chargeThread = task.spawn(function()
            while isAutoChargeRunning and not _G.AoneHub_IsDestroyed do
                doAutoChargeCycle()
                task.wait(1)
            end
            
            chargeStatus.Text = "Status: Stopped"
            chargeStatus.TextColor3 = C.textDim
            if savedChargeCFrame then
                pcall(function() TeleportPlayer(Player, savedChargeCFrame, "Return") end)
                savedChargeCFrame = nil
            end
        end)
    else
        chargeBtn.Text = "▶️ Mulai Auto Charge"
        chargeBtn.BackgroundColor3 = C.success
    end
end

chargeBtn = createBtn(ChargeSection, "▶️ Mulai Auto Charge", 50, C.success, toggleAutoCharge)

-- ==================================================================
-- AUTO-START CONFIG LOADER
-- ==================================================================
task.delay(3, function()
    if EventConfig.anubisAutoSubmit and not isAutoSubmitRunning then
        print("[AoneHub] Auto-starting Anubis Submit...")
        toggleAutoSubmit() 
    end
    if EventConfig.anubisAutoSell and not isSellEnabled then
        print("[AoneHub] Auto-starting Anubis Sell...")
        toggleAutoSell()
    end
    if EventConfig.anubisAutoBuy and not isAutoBuyRunning then
        print("[AoneHub] Auto-starting Anubis Buy...")
        toggleAutoBuy()
    end
    if EventConfig.anubisAutoRestart and not isAutoRestartRunning then
        print("[AoneHub] Auto-starting Anubis Restart...")
        toggleAutoRestart()
    end
    if EventConfig.anubisAutoCharge and not isAutoChargeRunning then
        print("[AoneHub] Auto-starting Anubis Charge...")
        toggleAutoCharge()
    end
end)

-- ==================================================================
-- CLEANUP (Dipanggil saat GUI ditutup)
-- ==================================================================
_G.AoneHub_Event_Cleanup = function()
    isAutoSubmitRunning = false
    isSellEnabled = false
    isAutoBuyRunning = false
    isAutoRestartRunning = false
    isAutoChargeRunning = false
    
    if inventoryThread then task.cancel(inventoryThread) end
    if chargeThread then task.cancel(chargeThread) end
    
    if savedSubmitCFrame then
        pcall(function() TeleportPlayer(Player, savedSubmitCFrame, "Return") end)
        savedSubmitCFrame = nil
    end
    if savedChargeCFrame then
        pcall(function() TeleportPlayer(Player, savedChargeCFrame, "Return") end)
        savedChargeCFrame = nil
    end
    
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(connections)
    
    if _G.AoneHub_SetAutoSellFruit then 
        _G.AoneHub_SetAutoSellFruit(true) 
    end
end
