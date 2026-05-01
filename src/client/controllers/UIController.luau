local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local Remotes             = require(ReplicatedStorage.Shared.network.Remotes)
local TowerStats          = require(ReplicatedStorage.Shared.configs.TowerStats)
local PlacementController = require(script.Parent.PlacementController)

local UIController = {}

local player       = Players.LocalPlayer
local gui          = player:WaitForChild("PlayerGui")

-- Referências das novas UIs do Studio
local hotbarGui    = nil
local towersGui    = nil
local statsPanel   = nil

local buildBtn     = nil
local deleteBtn    = nil

local STATE = {
    Idle          = "Idle",
    InventoryOpen = "InventoryOpen",
    PlacingTower  = "PlacingTower",
    DeletingTower = "DeletingTower",
}

local currentState = STATE.Idle
local phaseLocked  = false

-- Referências à estrutura do TowersGui (antigo InventarioUI)
local scrollingFrame = nil
local itemCardTemplate = nil

-- Guarda os cards criados dinamicamente: towerName -> card instance
local activeCards = {}
local selectedTowerName = nil

local updateInventoryUI  -- forward declaration

-- ── Shortcut Highlights (Agora usa os botões do Studio) ───────────────

local function updateShortcutHighlights()
    local function apply(btn, active)
        if not btn then return end
        local stroke = btn:FindFirstChildWhichIsA("UIStroke")
        if active then
            btn.BackgroundColor3 = Color3.fromRGB(55, 45, 10)
            if stroke then stroke.Color = Color3.fromRGB(255, 210, 40); stroke.Thickness = 3 end
        else
            -- Cor original do seu botão (ajuste se precisar)
            btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            if stroke then stroke.Color = Color3.fromRGB(80, 80, 80);  stroke.Thickness = 2 end
        end
    end
    
    apply(buildBtn, currentState == STATE.InventoryOpen or currentState == STATE.PlacingTower)
    apply(deleteBtn, currentState == STATE.DeletingTower)
end

-- ── State Machine ────────────────────────────────────────────────────────────

function UIController:setState(newState: string)
    if phaseLocked and newState ~= STATE.Idle then return end
    if newState == currentState then return end
    currentState = newState

    PlacementController:resetAll()

    if newState == STATE.Idle then
        if towersGui then towersGui.Enabled = false end
        selectedTowerName = nil

    elseif newState == STATE.InventoryOpen then
        if towersGui then towersGui.Enabled = true end
        task.spawn(updateInventoryUI)
        
        -- Limpa seleção visual dos cards
        for _, card in pairs(activeCards) do
            local stroke = card:FindFirstChildWhichIsA("UIStroke")
            if stroke then stroke.Color = Color3.fromRGB(0, 0, 0); stroke.Thickness = 1 end
        end
        selectedTowerName = nil

    elseif newState == STATE.PlacingTower then
        if towersGui then towersGui.Enabled = true end

    elseif newState == STATE.DeletingTower then
        if towersGui then towersGui.Enabled = false end
        PlacementController:setDeleteMode(true)
        selectedTowerName = nil
    end

    updateShortcutHighlights()
end

function UIController:getState(): string
    return currentState
end

-- ── Criação dos cards dinâmicos e Hover ──────────────────────────────────────

local function highlightCard(card)
    local stroke = card:FindFirstChildWhichIsA("UIStroke")
    if stroke then stroke.Color = Color3.fromRGB(255, 255, 255); stroke.Thickness = 4 end
end

local function resetCards()
    for _, card in pairs(activeCards) do
        local stroke = card:FindFirstChildWhichIsA("UIStroke")
        if stroke then stroke.Color = Color3.fromRGB(0, 0, 0); stroke.Thickness = 1 end
    end
end

local function createCard(towerName: string, count: number)
    if not itemCardTemplate or not scrollingFrame then return end

    local card = itemCardTemplate:Clone()
    card.Name = towerName
    card.Visible = true

    local nameLabel = card:FindFirstChild("Name")
    local qtdLabel  = card:FindFirstChild("Qtd")
    if nameLabel then nameLabel.Text = towerName end
    if qtdLabel  then qtdLabel.Text  = count .. "x" end

    card.Parent = scrollingFrame
    activeCards[towerName] = card

    local clickTarget = card:IsA("GuiButton") and card or card:FindFirstChildWhichIsA("GuiButton")

    if clickTarget then
        -- Quando CLICAR na torre
        clickTarget.MouseButton1Click:Connect(function()
            resetCards()
            highlightCard(card)
            selectedTowerName = towerName
            UIController:setState(STATE.PlacingTower)
            local stats = TowerStats[towerName]
            PlacementController:selectTower(towerName, stats and stats.Size, stats and stats.Color)
        end)
        
        -- Quando PASSAR O MOUSE (Hover para os Stats)
        clickTarget.MouseEnter:Connect(function()
            local stats = TowerStats[towerName]
            if stats and stats.Levels and statsPanel then
                local lvl1 = stats.Levels[1]
                
                -- Atualiza os textos dos retângulos (Ajuste os nomes conforme seu Studio)
                if statsPanel:FindFirstChild("DmgLabel") then statsPanel.DmgLabel.Text = "Dano: " .. (lvl1.Damage or 0) end
                if statsPanel:FindFirstChild("RangeLabel") then statsPanel.RangeLabel.Text = "Alcance: " .. (lvl1.Range or 0) end
                if statsPanel:FindFirstChild("SpeedLabel") then statsPanel.SpeedLabel.Text = "Veloc.: " .. (lvl1.Cooldown or 0) .. "s" end
                
                statsPanel.Visible = true
            end
        end)
        
        -- Quando TIRAR O MOUSE
        clickTarget.MouseLeave:Connect(function()
            if statsPanel then statsPanel.Visible = false end
        end)
    end

    return card
end

-- ── updateInventoryUI ────────────────────────────────────────────────────────

updateInventoryUI = function(placedTowerName: string?)
    if not scrollingFrame or not itemCardTemplate then return end

    local towers = Remotes.GetInventory:InvokeServer()
    local counts = {}
    for _, name in ipairs(towers) do
        counts[name] = (counts[name] or 0) + 1
    end

    for towerName, card in pairs(activeCards) do
        if not counts[towerName] or counts[towerName] == 0 then
            card:Destroy()
            activeCards[towerName] = nil
        end
    end

    for towerName, count in pairs(counts) do
        local existing = activeCards[towerName]
        if existing then
            local qtdLabel = existing:FindFirstChild("Qtd")
            if qtdLabel then qtdLabel.Text = count .. "x" end
        else
            createCard(towerName, count)
        end
    end

    if selectedTowerName and activeCards[selectedTowerName] then
        highlightCard(activeCards[selectedTowerName])
    end

    if placedTowerName and (counts[placedTowerName] or 0) == 0 then
        UIController:setState(STATE.InventoryOpen)
    end
end

-- ── Tower Info Panel (Upgrade/Sell) ─────────────────────────────────────────
-- (MANTIDO EXATAMENTE COMO ESTAVA)

local towerInfoPanel = nil
local nameLabel      = nil
local statsLabel     = nil
local nextStatsLabel = nil
local upgradeButton  = nil
local sellButton     = nil
local closeButton    = nil
local currentTower   = nil

function UIController:refreshTowerInfo()
    if not currentTower or not towerInfoPanel then return end

    local nameVal   = currentTower:FindFirstChild("TowerName")
    local lvlVal    = currentTower:FindFirstChild("Level")
    local towerName = nameVal and nameVal.Value or currentTower.Name
    local level     = lvlVal  and lvlVal.Value  or 1

    local data = TowerStats[towerName]
    if not data then return end

    local curStats = data.Levels[level]
    local nxtStats = data.Levels[level + 1]

    if nameLabel then nameLabel.Text = ("%s  —  Lv.%d"):format(towerName, level) end

    if statsLabel then
        local danoAtual  = curStats and curStats.Damage   or 0
        local rangeAtual = curStats and curStats.Range    or 0
        local cdAtual    = curStats and curStats.Cooldown or 0
        local danoProx   = nxtStats and nxtStats.Damage   or danoAtual
        local rangeProx  = nxtStats and nxtStats.Range    or rangeAtual
        local cdProx     = nxtStats and nxtStats.Cooldown or cdAtual

        local lines = {}
        if danoAtual  > 0 then table.insert(lines, ("Dano: %d > %d"):format(danoAtual, danoProx))      end
        if rangeAtual > 0 then table.insert(lines, ("Alcance: %d > %d"):format(rangeAtual, rangeProx)) end
        if cdAtual    > 0 then table.insert(lines, ("CD: %.2fs > %.2fs"):format(cdAtual, cdProx))      end
        statsLabel.Text = #lines > 0 and table.concat(lines, "\n") or "Passiva"
    end

    if nextStatsLabel then
        nextStatsLabel.Text = nxtStats and "" or "Nível máximo"
    end

    if upgradeButton then
        local cost = nxtStats and nxtStats.UpgradeCost
        if cost and cost > 0 then
            upgradeButton.Visible = true
            upgradeButton.Text    = ("Upgrade  $%d"):format(cost)
            local money     = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Money")
            local canAfford = money and money.Value >= cost
            upgradeButton.AutoButtonColor  = canAfford == true
            upgradeButton.TextTransparency = canAfford and 0 or 0.4
        else
            upgradeButton.Visible = false
        end
    end

    if sellButton then
        local refund = data.BasePrice and math.floor(data.BasePrice * 0.5) or 0
        sellButton.Text = ("Vender  +$%d"):format(refund)
    end
end

function UIController:showTowerInfo(tower: Model)
    currentTower = tower
    if towerInfoPanel then towerInfoPanel.Visible = true end
    self:refreshTowerInfo()

    local lvlVal = tower:FindFirstChild("Level")
    if lvlVal then
        lvlVal:GetPropertyChangedSignal("Value"):Connect(function()
            if currentTower == tower then self:refreshTowerInfo() end
        end)
    end
end

function UIController:hideTowerInfo()
    currentTower = nil
    if towerInfoPanel then towerInfoPanel.Visible = false end
end

-- ── Init ─────────────────────────────────────────────────────────────────────

function UIController:init()
    
    -- 1. Referências das GUIs no Studio
    hotbarGui = gui:WaitForChild("HotbarGui", 10)
    towersGui = gui:WaitForChild("TowersGui", 10)
    
    if hotbarGui then
        local hotbarMain = hotbarGui:WaitForChild("MainFrame")
        buildBtn = hotbarMain:WaitForChild("Build_btn")
        deleteBtn = hotbarMain:WaitForChild("Delete_btn")
        
        -- Conecta os botões da Hotbar
        buildBtn.MouseButton1Click:Connect(function()
            if currentState == STATE.InventoryOpen or currentState == STATE.PlacingTower then
                self:setState(STATE.Idle)
            else
                self:setState(STATE.InventoryOpen)
            end
        end)

        deleteBtn.MouseButton1Click:Connect(function()
            if currentState == STATE.DeletingTower then
                self:setState(STATE.Idle)
            else
                self:setState(STATE.DeletingTower)
            end
        end)
    end

    if towersGui then
        towersGui.Enabled = false
        statsPanel = towersGui:WaitForChild("StatsPanel", 5)
        if statsPanel then statsPanel.Visible = false end
        
        local mainFrame = towersGui:WaitForChild("MainFrame")
        -- Pode ser o direto no MainFrame ou dentro de um BackGround (ajuste conforme seu studio)
        scrollingFrame = mainFrame:FindFirstChild("ScrollingFrame") or mainFrame
        
        -- Procura o Template nas pastas (Templates ou direto no Frame)
        local templates = towersGui:FindFirstChild("Templates")
        if templates then
            itemCardTemplate = templates:FindFirstChild("hbItem") or templates:FindFirstChild("ItemCard")
        else
            itemCardTemplate = scrollingFrame:FindFirstChild("ItemCard") or scrollingFrame:FindFirstChild("hbItem")
        end
        
        if itemCardTemplate then
            itemCardTemplate.Parent = nil -- Esconde o original
        end
    end

    PlacementController:onTowerPlaced(function(towerName)
        task.spawn(updateInventoryUI, towerName)
    end)

    -- Dinheiro
    local leaderstats = player:WaitForChild("leaderstats", 10)
    if leaderstats then
        local money = leaderstats:WaitForChild("Money")
        money:GetPropertyChangedSignal("Value"):Connect(function()
            if currentTower then self:refreshTowerInfo() end
        end)
    end

    -- Tower Info Panel (Upgrade/Sell)
    towerInfoPanel = gui:FindFirstChild("TowerInfoPanel", true)
    if towerInfoPanel then
        towerInfoPanel.Visible = false
        nameLabel      = towerInfoPanel:FindFirstChild("NameLabel",      true)
        statsLabel     = towerInfoPanel:FindFirstChild("StatsLabel",     true)
        nextStatsLabel = towerInfoPanel:FindFirstChild("NextStatsLabel", true)
        upgradeButton  = towerInfoPanel:FindFirstChild("UpgradeButton",  true)
        sellButton     = towerInfoPanel:FindFirstChild("SellButton",     true)
        closeButton    = towerInfoPanel:FindFirstChild("CloseButton",    true)

        if upgradeButton then
            upgradeButton.MouseButton1Click:Connect(function()
                if not currentTower then return end
                local ok = Remotes.RequestTowerAction:InvokeServer(currentTower, "Upgrade")
                if not ok then warn("[UIController] Upgrade negado") end
            end)
        end
        if sellButton then
            sellButton.MouseButton1Click:Connect(function()
                if not currentTower then return end
                local ok = Remotes.RequestTowerAction:InvokeServer(currentTower, "Sell")
                if ok then self:hideTowerInfo() end
            end)
        end
        if closeButton then
            closeButton.MouseButton1Click:Connect(function()
                self:hideTowerInfo()
                require(script.Parent.TowerController):hideRange()
            end)
        end
    end

    -- Inputs (Teclado)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.One then
            if currentState == STATE.InventoryOpen or currentState == STATE.PlacingTower then
                self:setState(STATE.Idle)
            else
                self:setState(STATE.InventoryOpen)
            end
        elseif input.KeyCode == Enum.KeyCode.Two then
            if currentState == STATE.DeletingTower then
                self:setState(STATE.Idle)
            else
                self:setState(STATE.DeletingTower)
            end
        elseif input.KeyCode == Enum.KeyCode.Escape then
            if currentState == STATE.PlacingTower then
                self:setState(STATE.InventoryOpen)
            else
                self:setState(STATE.Idle)
            end
        end
    end)

    -- Fases
    Remotes.PhaseChanged.OnClientEvent:Connect(function(data)
        if data.phase == "CombatPhase" then
            phaseLocked = true
            self:setState(STATE.Idle)
            self:hideTowerInfo()
        elseif data.phase == "BuildPhase" then
            phaseLocked = false
            local delay = data.immediate and 0 or 3
            task.delay(delay, function()
                self:setState(STATE.InventoryOpen)
            end)
        end
    end)
end

return UIController