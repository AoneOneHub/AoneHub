-- ==================================================================
-- HALLOWEEN 2026 EVENT SCRIPT (GitHub Module)
-- Fitur: Smart Auto-Sell (Teleport Sinister Steven)
-- ==================================================================

local Context = _G.AoneHub_Event_Context
if not Context then return end

local Scroll = Context.Scroll
local createSection = Context.CreateSection
local C = Context.Colors

-- Services & Modules
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local DataService = require(ReplicatedStorage.Modules.DataService)
local TeleportPlayer = require(ReplicatedStorage.Modules.TeleportPlayer)
local GetFarm = require(ReplicatedStorage.Modules.GetFarm)

-- Remotes
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local TeleportRemote = GameEvents:WaitForChild("PlayerTeleportTriggered")
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
-- SECTION: SMART AUTO SELL HALLOWEEN
-- ==================================================================
local SellSection = createSection(Scroll, "🎃 Halloween Smart Auto-Sell", "eventAutoSell")
SellSection.LayoutOrder = 1
SellSection.Size = UDim2.new(1, -10, 0, 120)

local isAutoSellActive = false
local autoSellThread = nil
local aoneHubOriginalSellState = true -- Menyimpan status asli Auto Sell AoneHub

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

local function doHalloweenSell()
    statusLbl.Text = "⏳ Teleport ke Sinister Steven..."
    statusLbl.TextColor3 = C.warning
    
    -- 1. Simpan posisi
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local savedCFrame = hrp and hrp.CFrame
    
    -- 2. Teleport ke Steven
    TeleportRemote:FireServer("Sinister Sales")
    task.wait(3.5) -- Tunggu loading teleport
    
    -- 3. Jual
    statusLbl.Text = "💰 Menjual semua Halloween Plants..."
    SellRemote:FireServer()
    task.wait(4) -- Tunggu animasi jual selesai
    
    -- 4. Teleport Balik
    statusLbl.Text = "🔙 Kembali ke kebun..."
    if TeleportPlayer and savedCFrame then
        pcall(function() TeleportPlayer(Player, savedCFrame, "Return") end)
    elseif TeleportPlayer and GetFarm then
        local ok, farm = pcall(function() return GetFarm(Player) end)
        if ok and farm then
            local sp = farm:FindFirstChild("Spawn_Point")
            if sp then pcall(function() TeleportPlayer(Player, sp.CFrame, "Farm") end) end
        end
    end
    task.wait(2)
    statusLbl.Text = "✅ Selesai menjual."
    statusLbl.TextColor3 = C.success
end

local toggleBtn = createBtn(SellSection, "▶️ Aktifkan Smart Auto-Sell", 60, C.success, function()
    isAutoSellActive = not isAutoSellActive
    
    if isAutoSellActive then
        toggleBtn.Text = "⏹️ Matikan Smart Auto-Sell"
        toggleBtn.BackgroundColor3 = C.danger
        
        autoSellThread = task.spawn(function()
            while isAutoSellActive do
                local isHalloween = Player:GetAttribute("SelectedSlot") == "HALLOWEEN_2026"
                
                if isHalloween then
                    -- PINTAR: Matikan Auto Sell bawaan AoneHub agar tidak bentrok
                    if _G.AoneHub_Config and _G.AoneHub_Config.autoSell then
                        aoneHubOriginalSellState = true
                        _G.AoneHub_Config.autoSell = false
                        if _G.AoneHub_SaveConfig then _G.AoneHub_SaveConfig() end
                    end
                    
                    local current, max = getFruitCapacity()
                    local percent = math.floor((current / max) * 100)
                    statusLbl.Text = string.format("🌱 Halloween Garden | 📦 %d/%d (%d%%)", current, max, percent)
                    statusLbl.TextColor3 = C.text
                    
                    if current >= max then
                        statusLbl.Text = "🚨 Inventory Penuh! Menjual..."
                        statusLbl.TextColor3 = C.danger
                        
                        local sellSuccess, err = pcall(doHalloweenSell)
                        if not sellSuccess then
                            warn("[Event Script] Sell Error:", err)
                        end
                    end
                else
                    -- Di Normal Garden, kembalikan status Auto Sell AoneHub seperti semula
                    if _G.AoneHub_Config and aoneHubOriginalSellState and not _G.AoneHub_Config.autoSell then
                        _G.AoneHub_Config.autoSell = true
                        if _G.AoneHub_SaveConfig then _G.AoneHub_SaveConfig() end
                    end
                    
                    statusLbl.Text = "💤 Menunggu pindah ke Halloween Garden..."
                    statusLbl.TextColor3 = C.textDim
                end
                
                task.wait(2) -- Cek setiap 2 detik
            end
        end)
    else
        toggleBtn.Text = "▶️ Aktifkan Smart Auto-Sell"
        toggleBtn.BackgroundColor3 = C.success
        if autoSellThread then task.cancel(autoSellThread) end
        statusLbl.Text = "Status: Idle"
        statusLbl.TextColor3 = C.textDim
        
        -- Kembalikan status Auto Sell AoneHub saat dimatikan
        if _G.AoneHub_Config and aoneHubOriginalSellState then
            _G.AoneHub_Config.autoSell = true
            if _G.AoneHub_SaveConfig then _G.AoneHub_SaveConfig() end
        end
    end
end)

-- Tombol Manual Sell (tanpa nunggu penuh)
createBtn(SellSection, "📍 Sell Sekarang (Manual)", 88, C.accent, function()
    task.spawn(doHalloweenSell)
end)
