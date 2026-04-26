local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes             = require(ReplicatedStorage.Shared.network.Remotes)
local TowerStats          = require(ReplicatedStorage.Shared.configs.TowerStats)
local PlacementController = require(script.Parent.PlacementController)

local UIController = {}

local player     = Players.LocalPlayer
local gui        = player:WaitForChild("PlayerGui")
local inventarioUI = nil

local TAMANHO_NORMAL      = UDim2.new(0.114, 0, 0.67,  0)
local TAMANHO_SELECIONADO = UDim2.new(0.125, 0, 0.73,  0)

local BOTAO_MAP = {
	BtnToalete = "Toalete Basico",
	BtnGerador = "Gerador de Brainrot",
	BtnMuro    = "Parede Neon",
}

local registeredButtons = {}

-- ── Tower Info Panel ───────────────────────────────────────────────────────
-- Elementos esperados no TowerInfoPanel (crie no Studio dentro do PlayerGui):
--   NameLabel (TextLabel), StatsLabel (TextLabel), NextStatsLabel (TextLabel)
--   UpgradeButton (TextButton), SellButton (TextButton), CloseButton (TextButton)

local towerInfoPanel  = nil
local nameLabel       = nil
local statsLabel      = nil
local nextStatsLabel  = nil
local upgradeButton   = nil
local sellButton      = nil
local closeButton     = nil
local currentTower    = nil  -- Model selecionada atualmente

local function formatStats(s)
	if not s then return "—" end
	local parts = {}
	if s.Damage  and s.Damage  > 0 then table.insert(parts, ("DMG: %d"):format(s.Damage))  end
	if s.Range   and s.Range   > 0 then table.insert(parts, ("Range: %d"):format(s.Range))  end
	if s.Cooldown and s.Cooldown > 0 then table.insert(parts, ("CD: %.2fs"):format(s.Cooldown)) end
	return #parts > 0 and table.concat(parts, "  |  ") or "Passiva"
end

function UIController:refreshTowerInfo()
	if not currentTower or not towerInfoPanel then return end

	local nameVal  = currentTower:FindFirstChild("TowerName")
	local lvlVal   = currentTower:FindFirstChild("Level")
	local towerName = nameVal and nameVal.Value or currentTower.Name
	local level     = lvlVal  and lvlVal.Value  or 1

	local data      = TowerStats[towerName]
	if not data then return end

	local curStats  = data.Levels[level]
	local nxtStats  = data.Levels[level + 1]

	if nameLabel     then nameLabel.Text     = ("%s  —  Lv.%d"):format(towerName, level) end
	if statsLabel    then statsLabel.Text    = formatStats(curStats) end
	if nextStatsLabel then
		nextStatsLabel.Text = nxtStats
			and ("Próx: " .. formatStats(nxtStats))
			or  "Nível máximo"
	end

	-- Botão Upgrade
	if upgradeButton then
		local cost = nxtStats and nxtStats.UpgradeCost
		if cost and cost > 0 then
			upgradeButton.Visible = true
			upgradeButton.Text    = ("Upgrade  $%d"):format(cost)

			local money = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Money")
			local canAfford = money and money.Value >= cost
			upgradeButton.AutoButtonColor = canAfford == true
			upgradeButton.TextTransparency = canAfford and 0 or 0.4
		else
			upgradeButton.Visible = false
		end
	end

	-- Botão Sell
	if sellButton then
		local refund = data.BasePrice and math.floor(data.BasePrice * 0.5) or 0
		sellButton.Text = ("Vender  +$%d"):format(refund)
	end
end

function UIController:showTowerInfo(tower: Model)
	currentTower = tower
	if towerInfoPanel then
		towerInfoPanel.Visible = true
	end
	self:refreshTowerInfo()

	-- Atualiza painel quando o nível muda (após upgrade)
	local lvlVal = tower:FindFirstChild("Level")
	if lvlVal then
		lvlVal:GetPropertyChangedSignal("Value"):Connect(function()
			if currentTower == tower then
				self:refreshTowerInfo()
			end
		end)
	end
end

function UIController:hideTowerInfo()
	currentTower = nil
	if towerInfoPanel then
		towerInfoPanel.Visible = false
	end
end

-- ── Helpers visuais do inventário ─────────────────────────────────────────

local function setStroke(btn, color, thickness)
	local stroke = btn:FindFirstChildWhichIsA("UIStroke")
	if stroke then
		stroke.Color     = color
		stroke.Thickness = thickness
	end
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

local function updateButtonStates(money)
	for btn, towerName in pairs(registeredButtons) do
		local stats  = TowerStats[towerName]
		local canBuy = stats and money >= stats.BasePrice

		btn.AutoButtonColor   = canBuy
		btn.ImageTransparency = canBuy and 0 or 0.5

		local priceLabel = btn:FindFirstChild("Price")
		if priceLabel then
			priceLabel.TextColor3 = canBuy
				and Color3.fromRGB(255, 255, 255)
				or  Color3.fromRGB(180, 60, 60)
		end
	end
end

local function registerButton(btn, towerName)
	registeredButtons[btn] = towerName

	btn.MouseButton1Click:Connect(function()
		resetButtons()
		highlightButton(btn)
		local stats = TowerStats[towerName]
		PlacementController:selectTower(towerName, stats and stats.Size, stats and stats.Color)
	end)
end

-- ── Init ───────────────────────────────────────────────────────────────────

function UIController:init()
	inventarioUI = gui:WaitForChild("InventarioUI", 10)
	if not inventarioUI then
		warn("[UIController] InventarioUI não encontrado no PlayerGui")
		return
	end

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

	-- Ouvir mudanças de saldo
	local leaderstats = player:WaitForChild("leaderstats", 10)
	if leaderstats then
		local money = leaderstats:WaitForChild("Money")
		updateButtonStates(money.Value)
		money:GetPropertyChangedSignal("Value"):Connect(function()
			updateButtonStates(money.Value)
			-- Atualiza botão de upgrade se painel estiver aberto
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
				-- refreshTowerInfo é chamado automaticamente quando Level muda via IntValue
				if not ok then
					warn("[UIController] Upgrade negado pelo servidor")
				end
			end)
		end

		if sellButton then
			sellButton.MouseButton1Click:Connect(function()
				if not currentTower then return end
				local ok = Remotes.RequestTowerAction:InvokeServer(currentTower, "Sell")
				if ok then
					self:hideTowerInfo()
				end
			end)
		end

		if closeButton then
			closeButton.MouseButton1Click:Connect(function()
				self:hideTowerInfo()
			end)
		end
	else
		warn("[UIController] TowerInfoPanel não encontrado — crie-o no Studio dentro do PlayerGui")
	end

	-- Esconde/mostra inventário com base na fase
	Remotes.PhaseChanged.OnClientEvent:Connect(function(data)
		if data.phase == "CombatPhase" then
			inventarioUI.Visible = false
			PlacementController:setLocked(true)
			self:hideTowerInfo()
		elseif data.phase == "BuildPhase" then
			local delay = data.immediate and 0 or 3
			task.delay(delay, function()
				inventarioUI.Visible = true
			end)
		end
	end)
end

return UIController
