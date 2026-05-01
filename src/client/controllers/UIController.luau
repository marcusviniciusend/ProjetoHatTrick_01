local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local Remotes             = require(ReplicatedStorage.Shared.network.Remotes)
local TowerStats          = require(ReplicatedStorage.Shared.configs.TowerStats)
local PlacementController = require(script.Parent.PlacementController)

local UIController = {}

local PREFIX = "[UIController Debug] " -- Prefixo para acharmos os prints facilmente no Output

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

-- Referências à estrutura do TowersGui
local scrollingFrame = nil
local itemCardTemplate = nil

local activeCards = {}
local selectedTowerName = nil

local updateInventoryUI  -- forward declaration

-- ── Shortcut Highlights ───────────────

local function updateShortcutHighlights()
    local function apply(btn, active)
        if not btn then return end
        local stroke = btn:FindFirstChildWhichIsA("UIStroke")
        if active then
            btn.BackgroundColor3 = Color3.fromRGB(55, 45, 10)
            if stroke then stroke.Color = Color3.fromRGB(255, 210, 40); stroke.Thickness = 3 end
        else
            btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            if stroke then stroke.Color = Color3.fromRGB(80, 80, 80);  stroke.Thickness = 2 end
        end
    end
    
    apply(buildBtn, currentState == STATE.InventoryOpen or currentState == STATE.PlacingTower)
    apply(deleteBtn, currentState == STATE.DeletingTower)
end

-- ── State Machine ────────────────────────────────────────────────────────────

function UIController:setState(newState: string)
    print(PREFIX .. "Tentando mudar de estado: " .. tostring(currentState) .. " -> " .. tostring(newState))
    
    if phaseLocked and newState ~= STATE.Idle then 
        warn(PREFIX .. "Bloqueado! Fase de combate ativa.")
        return 
    end
    if newState == currentState then return end
    
    currentState = newState
    print(PREFIX .. "Estado atualizado com sucesso para: " .. currentState)

    PlacementController:resetAll()

    if newState == STATE.Idle then
        if towersGui then 
            towersGui.Enabled = false 
            print(PREFIX .. "Fechando TowersGui")
        end
        selectedTowerName = nil

    elseif newState == STATE.InventoryOpen then
        if towersGui then 
            towersGui.Enabled = true 
            print(PREFIX .. "Abrindo TowersGui")
        end
        task.spawn(updateInventoryUI)
        
        for _, card in pairs(activeCards) do
            local stroke = card:FindFirstChildWhichIsA("UIStroke")
            if stroke then stroke.Color = Color3.fromRGB(0, 0, 0); stroke.Thickness = 1 end
        end
        selectedTowerName = nil

    elseif newState == STATE.PlacingTower then
        if towersGui then towersGui.Enabled = true end
        print(PREFIX .. "Modo de colocação ativado para: " .. tostring(selectedTowerName))

    elseif newState == STATE.DeletingTower then
        if towersGui then towersGui.Enabled = false end
        print(PREFIX .. "Modo de deletar ativado")
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

    print(PREFIX .. "Criando card para torre: " .. towerName)

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
        clickTarget.MouseButton1Click:Connect(function()
            print(PREFIX .. "Clicou no card da torre: " .. towerName)
            resetCards()
            highlightCard(card)
            selectedTowerName = towerName
            UIController:setState(STATE.PlacingTower)
            local stats = TowerStats[towerName]
            PlacementController:selectTower(towerName, stats and stats.Size, stats and stats.Color)
        end)
        
        clickTarget.MouseEnter:Connect(function()
            local stats = TowerStats[towerName]
            if stats and stats.Levels and statsPanel then
                local lvl1 = stats.Levels[1]
                if statsPanel:FindFirstChild("DmgLabel") then statsPanel.DmgLabel.Text = "Dano: " .. (lvl1.Damage or 0) end
                if statsPanel:FindFirstChild("RangeLabel") then statsPanel.RangeLabel.Text = "Alcance: " .. (lvl1.Range or 0) end
                if statsPanel:FindFirstChild("SpeedLabel") then statsPanel.SpeedLabel.Text = "Veloc.: " .. (lvl1.Cooldown or 0) .. "s" end
                statsPanel.Visible = true
            else
                warn(PREFIX .. "StatsPanel ou TowerStats não encontrados no Hover para: " .. towerName)
            end
        end)
        
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
    print(PREFIX .. "Iniciando...")
    
    -- 1. Referências das GUIs no Studio
    hotbarGui = gui:WaitForChild("HotbarGui", 5)
    towersGui = gui:WaitForChild("TowersGui", 5)
    
    if hotbarGui then
        print(PREFIX .. "HotbarGui encontrada!")
        local hotbarMain = hotbarGui:WaitForChild("MainFrame")
        buildBtn = hotbarMain:WaitForChild("Build_btn")
        deleteBtn = hotbarMain:WaitForChild("Delete_btn")
        
        buildBtn.MouseButton1Click:Connect(function()
            print(PREFIX .. "Botão Build_btn clicado na UI")
            if currentState == STATE.InventoryOpen or currentState == STATE.PlacingTower then
                self:setState(STATE.Idle)
            else
                self:setState(STATE.InventoryOpen)
            end
        end)

        deleteBtn.MouseButton1Click:Connect(function()
            print(PREFIX .. "Botão Delete_btn clicado na UI")
            if currentState == STATE.DeletingTower then
                self:setState(STATE.Idle)
            else
                self:setState(STATE.DeletingTower)
            end
        end)
    else
        warn(PREFIX .. "HotbarGui NÃO encontrada!")
    end

    if towersGui then
        print(PREFIX .. "TowersGui encontrada!")
        towersGui.Enabled = false
        statsPanel = towersGui:WaitForChild("StatsPanel", 5)
        if statsPanel then statsPanel.Visible = false end
        
        local mainFrame = towersGui:WaitForChild("MainFrame")
        scrollingFrame = mainFrame:FindFirstChild("ScrollingFrame") or mainFrame
        
        local templates = towersGui:FindFirstChild("Templates")
        if templates then
            itemCardTemplate = templates:FindFirstChild("hbItem") or templates:FindFirstChild("ItemCard")
            print(PREFIX .. "Procurando template na pasta Templates...")
        else
            itemCardTemplate = scrollingFrame:FindFirstChild("ItemCard") or scrollingFrame:FindFirstChild("hbItem")
            print(PREFIX .. "Procurando template direto no ScrollingFrame...")
        end
        
        if itemCardTemplate then
            print(PREFIX .. "Template do Card encontrado com sucesso!")
            itemCardTemplate.Parent = nil
        else
            warn(PREFIX .. "Template do Card NÃO encontrado!")
        end
    else
        warn(PREFIX .. "TowersGui NÃO encontrada! Verifique o nome no Explorer.")
    end

    PlacementController:onTowerPlaced(function(towerName)
        task.spawn(updateInventoryUI, towerName)
    end)

    -- Dinheiro
    local leaderstats = player:WaitForChild("leaderstats", 5)
    if leaderstats then
        local money = leaderstats:WaitForChild("Money")
        money:GetPropertyChangedSignal("Value"):Connect(function()
            if currentTower then self:refreshTowerInfo() end
        end)
    end

    -- Tower Info Panel
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
                if not ok then warn(PREFIX .. "Upgrade negado") end
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
    else
        warn(PREFIX .. "TowerInfoPanel não encontrado (Ignorar se ainda não criou)")
    end

    -- Inputs (Teclado)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.One then
            print(PREFIX .. "Tecla '1' pressionada. Estado atual: " .. currentState)
            if currentState == STATE.InventoryOpen or currentState == STATE.PlacingTower then
                self:setState(STATE.Idle)
            else
                self:setState(STATE.InventoryOpen)
            end
        elseif input.KeyCode == Enum.KeyCode.Two then
            print(PREFIX .. "Tecla '2' pressionada. Estado atual: " .. currentState)
            if currentState == STATE.DeletingTower then
                self:setState(STATE.Idle)
            else
                self:setState(STATE.DeletingTower)
            end
        elseif input.KeyCode == Enum.KeyCode.Escape then
            print(PREFIX .. "Tecla 'Esc' pressionada.")
            if currentState == STATE.PlacingTower then
                self:setState(STATE.InventoryOpen)
            else
                self:setState(STATE.Idle)
            end
        end
    end)

    -- Fases
    Remotes.PhaseChanged.OnClientEvent:Connect(function(data)
        print(PREFIX .. "Fase alterada para: " .. tostring(data.phase))
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
    
    print(PREFIX .. "Inicialização concluída!")
end

return UIController