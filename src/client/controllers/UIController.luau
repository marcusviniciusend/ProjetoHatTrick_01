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
local inventarioUI = nil

local TAMANHO_NORMAL      = UDim2.new(0.114, 0, 0.67, 0)
local TAMANHO_SELECIONADO = UDim2.new(0.125, 0, 0.73, 0)

local BOTAO_MAP = {
	BtnToalete = "Toalete Basico",
	BtnGerador = "Gerador de Brainrot",
	BtnMuro    = "Parede Neon",
}

local registeredButtons = {}

-- ── State Machine ───────────────────────────────────────────────────────────

local STATE = {
	Idle          = "Idle",
	InventoryOpen = "InventoryOpen",
	PlacingTower  = "PlacingTower",
	DeletingTower = "DeletingTower",
}

local currentState = STATE.Idle
local phaseLocked  = false  -- true durante CombatPhase: bloqueia toda transição

local shortcutBtn1 = nil
local shortcutBtn2 = nil

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
	apply(shortcutBtn1, currentState == STATE.InventoryOpen or currentState == STATE.PlacingTower)
	apply(shortcutBtn2, currentState == STATE.DeletingTower)
end

function UIController:setState(newState: string)
	if phaseLocked and newState ~= STATE.Idle then return end
	if newState == currentState then return end
	currentState = newState

	-- Reseta PlacementController para base conhecida antes de qualquer transição
	PlacementController:resetAll()

	if newState == STATE.Idle then
		if inventarioUI then inventarioUI.Enabled = false end

	elseif newState == STATE.InventoryOpen then
		if inventarioUI then inventarioUI.Enabled = true end
		task.spawn(updateInventoryUI)
		-- Limpa seleção visual dos botões de torre
		for btn in pairs(registeredButtons) do
			local stroke = btn:FindFirstChildWhichIsA("UIStroke")
			if stroke then stroke.Color = Color3.fromRGB(0, 0, 0); stroke.Thickness = 1 end
			TweenService:Create(btn, TweenInfo.new(0.1), { Size = TAMANHO_NORMAL }):Play()
		end

	elseif newState == STATE.PlacingTower then
		if inventarioUI then inventarioUI.Enabled = true end
		-- PlacementController:selectTower() é chamado pelo registerButton logo em seguida

	elseif newState == STATE.DeletingTower then
		if inventarioUI then inventarioUI.Enabled = false end
		PlacementController:toggleDeleteMode()
	end

	updateShortcutHighlights()
end

function UIController:getState(): string
	return currentState
end

-- ── Shortcut Bar (criada em código) ────────────────────────────────────────

local function makeShortcutButton(parent, number: string, label: string)
	local btn = Instance.new("TextButton")
	btn.Name                   = "Shortcut" .. number
	btn.Size                   = UDim2.new(0, 64, 0, 64)
	btn.BackgroundColor3       = Color3.fromRGB(30, 30, 30)
	btn.BackgroundTransparency = 0.25
	btn.Text                   = ""
	btn.AutoButtonColor        = false
	btn.Parent                 = parent

	local corner         = Instance.new("UICorner")
	corner.CornerRadius  = UDim.new(0, 8)
	corner.Parent        = btn

	local stroke         = Instance.new("UIStroke")
	stroke.Thickness     = 2
	stroke.Color         = Color3.fromRGB(80, 80, 80)
	stroke.Parent        = btn

	local numLbl                   = Instance.new("TextLabel")
	numLbl.Size                    = UDim2.new(1, 0, 0.42, 0)
	numLbl.Position                = UDim2.new(0, 0, 0.02, 0)
	numLbl.BackgroundTransparency  = 1
	numLbl.Text                    = "[" .. number .. "]"
	numLbl.TextColor3              = Color3.fromRGB(210, 210, 210)
	numLbl.TextScaled              = true
	numLbl.Font                    = Enum.Font.GothamBold
	numLbl.Parent                  = btn

	local lbl                      = Instance.new("TextLabel")
	lbl.Size                       = UDim2.new(1, -4, 0.48, 0)
	lbl.Position                   = UDim2.new(0, 2, 0.50, 0)
	lbl.BackgroundTransparency     = 1
	lbl.Text                       = label
	lbl.TextColor3                 = Color3.fromRGB(180, 180, 180)
	lbl.TextScaled                 = true
	lbl.Font                       = Enum.Font.Gotham
	lbl.Parent                     = btn

	return btn
end

local function createShortcutBar()
	local screen              = Instance.new("ScreenGui")
	screen.Name               = "ShortcutBar"
	screen.ResetOnSpawn       = false
	screen.ZIndexBehavior     = Enum.ZIndexBehavior.Sibling
	screen.Parent             = gui

	local frame                      = Instance.new("Frame")
	frame.Name                       = "Bar"
	frame.Size                       = UDim2.new(0, 148, 0, 72)
	frame.Position                   = UDim2.new(0.5, -74, 1, -84)
	frame.BackgroundTransparency     = 1
	frame.Parent                     = screen

	local layout                     = Instance.new("UIListLayout")
	layout.FillDirection             = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment       = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment         = Enum.VerticalAlignment.Center
	layout.Padding                   = UDim.new(0, 8)
	layout.Parent                    = frame

	shortcutBtn1 = makeShortcutButton(frame, "1", "Construir")
	shortcutBtn2 = makeShortcutButton(frame, "2", "Deletar")

	shortcutBtn1.MouseButton1Click:Connect(function()
		if currentState == STATE.InventoryOpen or currentState == STATE.PlacingTower then
			UIController:setState(STATE.Idle)
		else
			UIController:setState(STATE.InventoryOpen)
		end
	end)

	shortcutBtn2.MouseButton1Click:Connect(function()
		if currentState == STATE.DeletingTower then
			UIController:setState(STATE.Idle)
		else
			UIController:setState(STATE.DeletingTower)
		end
	end)
end

-- ── Tower Info Panel ────────────────────────────────────────────────────────

local towerInfoPanel = nil
local nameLabel      = nil
local statsLabel     = nil
local nextStatsLabel = nil
local upgradeButton  = nil
local sellButton     = nil
local closeButton    = nil
local currentTower   = nil

local function formatStats(s)
	if not s then return "—" end
	local parts = {}
	if s.Damage   and s.Damage   > 0 then table.insert(parts, ("DMG: %d"):format(s.Damage))   end
	if s.Range    and s.Range    > 0 then table.insert(parts, ("Range: %d"):format(s.Range))   end
	if s.Cooldown and s.Cooldown > 0 then table.insert(parts, ("CD: %.2fs"):format(s.Cooldown)) end
	return #parts > 0 and table.concat(parts, "  |  ") or "Passiva"
end

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
		if danoAtual  > 0 then table.insert(lines, ("Dano: %d > %d"):format(danoAtual, danoProx))       end
		if rangeAtual > 0 then table.insert(lines, ("Alcance: %d > %d"):format(rangeAtual, rangeProx))  end
		if cdAtual    > 0 then table.insert(lines, ("CD: %.2fs > %.2fs"):format(cdAtual, cdProx))       end
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

-- ── Helpers visuais dos botões de inventário ────────────────────────────────

local function setStroke(btn, color, thickness)
	local stroke = btn:FindFirstChildWhichIsA("UIStroke")
	if stroke then stroke.Color = color; stroke.Thickness = thickness end
end

local function resetButtons()
	for btn in pairs(registeredButtons) do
		setStroke(btn, Color3.fromRGB(0, 0, 0), 1)
		TweenService:Create(btn, TweenInfo.new(0.1), { Size = TAMANHO_NORMAL }):Play()
	end
end

local function highlightButton(btn)
	setStroke(btn, Color3.fromRGB(255, 255, 255), 4)
	TweenService:Create(
		btn,
		TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = TAMANHO_SELECIONADO }
	):Play()
end

local function updateInventoryUI()
	local towers = Remotes.GetInventory:InvokeServer()
	local counts = {}
	for _, name in ipairs(towers) do
		counts[name] = (counts[name] or 0) + 1
	end
	for btn, towerName in pairs(registeredButtons) do
		local count  = counts[towerName] or 0
		btn.Visible  = count > 0
		local lbl    = btn:FindFirstChild("labelQtd")
		if lbl then lbl.Text = count .. "x" end
	end
end

local function registerButton(btn, towerName)
	registeredButtons[btn] = towerName

	btn.MouseButton1Click:Connect(function()
		resetButtons()
		highlightButton(btn)
		-- Transiciona para PlacingTower ANTES de selectTower para que resetAll()
		-- limpe qualquer ghost anterior; selectTower cria o novo ghost logo após.
		UIController:setState(STATE.PlacingTower)
		local stats = TowerStats[towerName]
		PlacementController:selectTower(towerName, stats and stats.Size, stats and stats.Color)
	end)
end

-- ── Init ────────────────────────────────────────────────────────────────────

function UIController:init()
	createShortcutBar()

	inventarioUI = gui:WaitForChild("InventarioUI", 10)
	if not inventarioUI then
		warn("[UIController] InventarioUI não encontrado no PlayerGui")
		return
	end
	inventarioUI.Enabled = false  -- estado inicial: Idle

	local painel = inventarioUI:WaitForChild("Painel", 10)
	if not painel then
		warn("[UIController] Painel não encontrado no InventarioUI")
		return
	end

	for nomeBotao, nomeTorre in pairs(BOTAO_MAP) do
		local btn = painel:FindFirstChild(nomeBotao)
		if btn then
			registerButton(btn, nomeTorre)
		else
			warn(("[UIController] Botão '%s' não encontrado"):format(nomeBotao))
		end
	end

	-- Atualiza custo de upgrade quando o saldo muda
	local leaderstats = player:WaitForChild("leaderstats", 10)
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
				if not ok then warn("[UIController] Upgrade negado pelo servidor") end
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
		warn("[UIController] TowerInfoPanel não encontrado — crie-o no Studio dentro do PlayerGui")
	end

	-- Input: teclas 1, 2 e Escape controlam a máquina de estados
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
				self:setState(STATE.InventoryOpen)  -- volta ao inventário, não fecha tudo
			else
				self:setState(STATE.Idle)
			end
		end
	end)

	-- Fase de jogo
	Remotes.PhaseChanged.OnClientEvent:Connect(function(data)
		if data.phase == "CombatPhase" then
			phaseLocked = true
			self:setState(STATE.Idle)
			self:hideTowerInfo()

		elseif data.phase == "BuildPhase" then
			phaseLocked = false
			local delay = data.immediate and 0 or 3
			task.delay(delay, function()
				self:setState(STATE.InventoryOpen)  -- abre inventário automaticamente
			end)
		end
	end)
end

return UIController
