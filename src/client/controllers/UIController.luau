local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TowerStats          = require(ReplicatedStorage.Shared.configs.TowerStats)
local PlacementController = require(script.Parent.PlacementController)

local UIController = {}

local player = Players.LocalPlayer
local gui    = player:WaitForChild("PlayerGui")

local TAMANHO_NORMAL      = UDim2.new(0.114, 0, 0.67,  0)
local TAMANHO_SELECIONADO = UDim2.new(0.125, 0, 0.73,  0)

-- Mapeamento botão → nome da torre (adicione novos botões aqui)
local BOTAO_MAP = {
	BtnToalete = "Toalete Basico",
	BtnGerador = "Gerador de Brainrot",
	BtnMuro    = "Parede Neon",
}

local registeredButtons = {}  -- { [btn] = towerName }

-- ── Helpers visuais ────────────────────────────────────────────────────────

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

-- ── Estado dos botões baseado no saldo ────────────────────────────────────

local function updateButtonStates(money)
	for btn, towerName in pairs(registeredButtons) do
		local stats  = TowerStats[towerName]
		local canBuy = stats and money >= stats.Price

		btn.AutoButtonColor = canBuy
		btn.ImageTransparency = canBuy and 0 or 0.5

		local priceLabel = btn:FindFirstChild("Price")
		if priceLabel then
			priceLabel.TextColor3 = canBuy
				and Color3.fromRGB(255, 255, 255)
				or  Color3.fromRGB(180, 60, 60)
		end
	end
end

-- ── Registro de botões ─────────────────────────────────────────────────────

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
	local inventarioUI = gui:WaitForChild("InventarioUI", 10)
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
			warn(("[UIController] Botão '%s' não encontrado no Painel"):format(nomeBotao))
		end
	end

	-- Ouvir mudanças de saldo em tempo real via leaderstats
	local leaderstats = player:WaitForChild("leaderstats", 10)
	if leaderstats then
		local money = leaderstats:WaitForChild("Money")
		updateButtonStates(money.Value)
		money:GetPropertyChangedSignal("Value"):Connect(function()
			updateButtonStates(money.Value)
		end)
	end
end

return UIController
