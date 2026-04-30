local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local TweenService      = game:GetService("TweenService") -- Adicionado para o Hover!

local Remotes    = require(ReplicatedStorage.Shared.network.Remotes)
local RarityData = require(ReplicatedStorage.Shared.configs.RarityData)
local StoreItems = require(ReplicatedStorage.Shared.configs.StoreItems)
local TowerStats = require(ReplicatedStorage.Shared.configs.TowerStats)

local StoreController = {}

local player = Players.LocalPlayer
local towers = ReplicatedStorage:WaitForChild("towers", 10)

local MAX_PEDESTAL_COUNT = 5

-- ── Estado ─────────────────────────────────────────────────────────────────
StoreController.isOpen = false
StoreController.isProcessing = false -- Ainda usamos para abrir/fechar a loja, mas não para os botões!

local hotspot         = nil
local pedestals       = {}
local pedDisplays     = {}
local countdownThread = nil
local currentSlots    = {}

-- ── Referências da UI Manual ───────────────────────────────────────────────
local shopUI
local mainFrame
local closeButton
local refreshButton
local itemsScroll
local cardTemplate
local clockLabel = nil 

-- ── Helpers de instância ───────────────────────────────
local function corner(parent, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = parent
end

local function label(parent, props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    for k, v in pairs(props) do (l :: any)[k] = v end
    l.Parent = parent
    return l
end

local function getAnchor(pedestal)
    if pedestal:IsA("BasePart") then return pedestal end
    if pedestal:IsA("Model") then
        return pedestal.PrimaryPart or pedestal:FindFirstChildWhichIsA("BasePart")
    end
    return nil
end

local function topCenter(pedestal)
    local a = getAnchor(pedestal)
    if not a then return Vector3.zero end
    return Vector3.new(a.Position.X, a.Position.Y + a.Size.Y / 2, a.Position.Z)
end

-- ── Lógica da Interface 2D ─────────────────────────────────────────────────
local function populateShopUI()
    if not itemsScroll or not cardTemplate then return end

    for _, child in ipairs(itemsScroll:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "ItemCard_Template" then
            child:Destroy()
        end
    end

    for towerName, slotData in pairs(currentSlots) do
        local newCard = cardTemplate:Clone()
        newCard.Name = "Card_" .. towerName
        newCard.Visible = true
        newCard.Parent = itemsScroll

        local nameLbl   = newCard:FindFirstChild("TowerName")
        local priceLbl  = newCard:FindFirstChild("PriceText")
        local rarityLbl = newCard:FindFirstChild("Rarity")
        local stockLbl  = newCard:FindFirstChild("StockCount")
        local buyBtn    = newCard:FindFirstChild("BuyButton")

        if nameLbl then nameLbl.Text = towerName end
        if priceLbl then priceLbl.Text = "$" .. tostring(slotData.price) end

        -- Lógica de Estoque
        local outOfStock = slotData.stock <= 0
        if stockLbl then
            if outOfStock then
                stockLbl.Text = "Esgotado"
                stockLbl.TextColor3 = Color3.fromRGB(220, 60, 60)
            else
                stockLbl.Text = "x" .. tostring(slotData.stock) .. " left"
                stockLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
        end

        -- Lógica de Raridade
        local foundRarity = "Comum"
        for rName, itemsArray in pairs(StoreItems) do
            if table.find(itemsArray, towerName) then
                foundRarity = rName; break
            end
        end

        if rarityLbl then
            rarityLbl.Text = foundRarity
            if RarityData[foundRarity] and RarityData[foundRarity].Color then
                rarityLbl.TextColor3 = RarityData[foundRarity].Color
            end
        end

        -- Configuração do Botão de Compra
        if buyBtn then
            -- 👉 AJUSTE AQUI: Como o seu jogo verifica o dinheiro?
            local function hasEnoughMoney()
                local leaderstats = player:FindFirstChild("leaderstats")
                -- Substitua "Coins" pelo nome da sua moeda no jogo!
                if leaderstats and leaderstats:FindFirstChild("Coins") then
                    return leaderstats.Coins.Value >= slotData.price
                end
                return true -- Retorna true por padrão pra não bugar caso não ache
            end

            local canAfford = hasEnoughMoney()

            -- Define a cor base do botão
            local baseColor
            if outOfStock then
                baseColor = Color3.fromRGB(100, 100, 100) -- Esgotado = Cinza
            elseif canAfford then
                baseColor = Color3.fromRGB(60, 210, 60) -- Tem dinheiro = Verde
            else
                baseColor = Color3.fromRGB(255, 255, 255) -- Sem dinheiro = Branco
            end
            
            buyBtn.ImageColor3 = baseColor

            -- Efeito Hover Suave
            buyBtn.MouseEnter:Connect(function()
                if not outOfStock then
                    -- Escurece a cor atual ligeiramente no hover
                    local hoverColor = Color3.new(
                        math.max(0, baseColor.R - 0.15),
                        math.max(0, baseColor.G - 0.15),
                        math.max(0, baseColor.B - 0.15)
                    )
                    TweenService:Create(buyBtn, TweenInfo.new(0.15), {ImageColor3 = hoverColor}):Play()
                end
            end)

            buyBtn.MouseLeave:Connect(function()
                TweenService:Create(buyBtn, TweenInfo.new(0.15), {ImageColor3 = baseColor}):Play()
            end)

            -- Clique (Sem Debounce e Sem Texto de Erro)
            buyBtn.Activated:Connect(function()
                if outOfStock then return end
                
                -- Feedback rápido pro botão (animação de clique segura)
                local uiScale = buyBtn:FindFirstChildWhichIsA("UIScale")
                if uiScale then
                    TweenService:Create(uiScale, TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, true), {Scale = 0.9}):Play()
                end

                -- Invoca o servidor. Não paramos o jogador de clicar de novo.
                task.spawn(function()
                    Remotes.BuyShopItem:InvokeServer(towerName)
                    -- Se a compra for feita, o servidor vai emitir o 'ShopUpdated' 
                    -- e a UI vai atualizar o card (estoque e dinheiro) automaticamente!
                end)
            end)
        end
    end
end

function StoreController:OpenShop()
    if self.isOpen or self.isProcessing then return end
    self.isProcessing = true
    
    if mainFrame then
        populateShopUI()
        mainFrame.Visible = true 
    end
    self.isOpen = true
    self.isProcessing = false
end

function StoreController:CloseShop()
    if mainFrame then mainFrame.Visible = false end
    self.isOpen = false
end

-- ── Countdown ──────────────────────────────────────────────────────────────
local function startCountdown(nextRotation)
    if countdownThread then task.cancel(countdownThread) end
    countdownThread = task.spawn(function()
        while true do
            local rem = math.max(0, nextRotation - os.time())
            local txt  = ("%d:%02d"):format(math.floor(rem / 60), rem % 60)
            
            if clockLabel then clockLabel.Text = txt end
            if rem <= 0 then break end
            task.wait(1)
        end
        if clockLabel then clockLabel.Text = "..." end
    end)
end

-- ── Billboard de relógio no hotspot ───────────────────────
local function buildClockGui(anchor)
    local existing = anchor:FindFirstChild("ShopClock")
    if existing then existing:Destroy() end

    local bb             = Instance.new("BillboardGui")
    bb.Name              = "ShopClock"
    bb.Size              = UDim2.new(0, 180, 0, 70)
    bb.StudsOffset       = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop       = false
    bb.Parent            = anchor

    local bg             = Instance.new("Frame")
    bg.Size              = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3  = Color3.fromRGB(10, 10, 20)
    bg.BackgroundTransparency = 0.15
    bg.Parent            = bb
    corner(bg, 10)

    clockLabel = label(bg, {
        Name = "Time",
        Size = UDim2.new(1, 0, 0.58, 0),
        Position = UDim2.new(0, 0, 0.06, 0),
        TextColor3 = Color3.fromRGB(255, 220, 60),
        TextScaled = true, Font = Enum.Font.GothamBold,
        Text = "--:--",
    })
    label(bg, {
        Name = "Sub",
        Size = UDim2.new(1, 0, 0.32, 0),
        Position = UDim2.new(0, 0, 0.65, 0),
        TextColor3 = Color3.fromRGB(150, 150, 150),
        TextScaled = true, Font = Enum.Font.Gotham,
        Text = "Próxima rotação",
    })
end

-- ── Vitrine dos pedestais (3D) ────────────────────────────────────────────
local function clearPedestalDisplay(idx)
    local d = pedDisplays[idx]
    if not d then return end
    if d.towerModel and d.towerModel.Parent then d.towerModel:Destroy() end
    pedDisplays[idx] = nil
end

local function setupPedestalVitrine(idx, slot)
    local pedestal = pedestals[idx]
    if not pedestal or not towers then return end
    clearPedestalDisplay(idx)

    local template = towers:FindFirstChild(slot.towerName)
    if not template then return end

    local towerModel = template:Clone()
    local top        = topCenter(pedestal)
    local bCF, bSize = towerModel:GetBoundingBox()
    local pivotY     = towerModel:GetPivot().Position.Y
    local bottomOff  = pivotY - (bCF.Position.Y - bSize.Y / 2)
    towerModel:PivotTo(CFrame.new(top.X, top.Y + bottomOff + 0.3, top.Z))
    towerModel.Parent = Workspace

    for _, desc in ipairs(towerModel:GetDescendants()) do
        if desc:IsA("BasePart") then
            desc.Anchored   = true
            desc.CanCollide = false
            desc.CanQuery   = false
        end
    end

    pedDisplays[idx] = { towerModel = towerModel }
end

-- ── Descoberta do Hotspot ──────────────────────────────────────────────────
local function hidePedestals()
    for _, ped in pairs(pedestals) do
        if ped:IsA("BasePart") then
            ped.Transparency = 1
        else
            for _, p in ipairs(ped:GetDescendants()) do
                if p:IsA("BasePart") then p.Transparency = 1 end
            end
        end
    end
end

local function discoverHotspot()
    if hotspot then return true end

    hotspot = Workspace:FindFirstChild("Hotspot")
    if not hotspot then return false end
    
    for i = 1, MAX_PEDESTAL_COUNT do
        local ped = hotspot:FindFirstChild("Pedestal" .. i)
        if ped then pedestals[i] = ped end
    end
    hidePedestals()

    task.spawn(function()
        local anchor = hotspot.PrimaryPart or hotspot:FindFirstChild("Head") or hotspot:FindFirstChildWhichIsA("BasePart", true)
        if anchor then pcall(buildClockGui, anchor) end
    end)

    return true
end

-- ── Atualização da loja ────────────────────────────────────────────────────
local function onShopUpdated(data)
    currentSlots = {}
    for _, slot in ipairs(data.slots) do
        currentSlots[slot.towerName] = slot
    end

    if not discoverHotspot() then return end

    for i in pairs(pedDisplays) do clearPedestalDisplay(i) end
    pedDisplays = {}
    for i, slot in ipairs(data.slots) do
        setupPedestalVitrine(i, slot)
    end

    startCountdown(data.nextRotation)

    if StoreController.isOpen then
        populateShopUI()
    end
end

-- ── Init ───────────────────────────────────────────────────────────────────
function StoreController:init()
    local gui = player:WaitForChild("PlayerGui")
    
    shopUI       = gui:WaitForChild("ShopGui") 
    mainFrame    = shopUI:WaitForChild("MainFrame")
    closeButton  = mainFrame:WaitForChild("CloseButton")
    
    local bgFrame = mainFrame:WaitForChild("Background")
    itemsScroll   = bgFrame:WaitForChild("ScrollingFrame")
    cardTemplate  = itemsScroll:WaitForChild("ItemCard_Template")
    
    cardTemplate.Visible = false

    closeButton.Activated:Connect(function()
        self:CloseShop()
    end)

    Remotes.ShopUpdated.OnClientEvent:Connect(onShopUpdated)
    Remotes.OpenShop.OnClientEvent:Connect(function()
        self:OpenShop()
    end)

    task.spawn(function() discoverHotspot() end)
end

return StoreController