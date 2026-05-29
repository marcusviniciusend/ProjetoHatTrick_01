local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes     = require(ReplicatedStorage:WaitForChild("Shared").network.Remotes)
local WeaponStats = require(ReplicatedStorage.Shared.configs.WeaponStats)

local WeaponShopController = {}

local player = Players.LocalPlayer
local gui    = player:WaitForChild("PlayerGui")

local mainFrame    = nil
local scrollFrame  = nil
local cardTemplate = nil
local setupDone    = false  -- garante CloseButton conectado apenas uma vez

-- ── Descoberta de referências ──────────────────────────────────────────────
-- Retorna true se mainFrame está pronto para uso. Idempotente: chamadas
-- repetidas são no-op após o primeiro sucesso.

local function resolveRefs(): boolean
	if setupDone then return mainFrame ~= nil end

	local shopGui = gui:FindFirstChild("WeaponShopGui")
	if not shopGui then return false end

	mainFrame = shopGui:FindFirstChild("MainFrame")
	if not mainFrame then return false end

	scrollFrame  = mainFrame:FindFirstChild("ScrollingFrame")
	cardTemplate = scrollFrame and scrollFrame:FindFirstChild("WeaponCard_Template")

	mainFrame.Visible = false
	if cardTemplate then cardTemplate.Visible = false end

	local closeButton = mainFrame:FindFirstChild("CloseButton")
	if closeButton then
		closeButton.MouseButton1Click:Connect(function()
			mainFrame.Visible = false
		end)
	end

	setupDone = true
	return true
end

-- ── Populate card ──────────────────────────────────────────────────────────

local function setupCard(card: Frame, weaponName: string, stats)
	local nameLbl    = card:FindFirstChild("WeaponName")
	local typeLbl    = card:FindFirstChild("WeaponType")
	local priceLbl   = card:FindFirstChild("PriceText")
	local damageLbl  = card:FindFirstChild("DamageText")
	local passiveLbl = card:FindFirstChild("PassiveText")
	local buyBtn     = card:FindFirstChild("BuyButton")

	if nameLbl  then nameLbl.Text  = weaponName end
	if typeLbl  then typeLbl.Text  = stats.Type end
	if priceLbl then priceLbl.Text = "$" .. stats.BasePrice end
	if damageLbl then damageLbl.Text = "Dano: " .. stats.Damage end

	if passiveLbl then
		if stats.Passive then
			passiveLbl.Text    = stats.Passive
			passiveLbl.Visible = true
		else
			passiveLbl.Visible = false
		end
	end

	if not buyBtn then return end

	local buying = false  -- debounce por card — previne duplo clique
	buyBtn.MouseButton1Click:Connect(function()
		if buying then return end
		buying = true

		local originalText = buyBtn.Text
		buyBtn.Text = "..."

		task.spawn(function()
			local ok = Remotes.BuyWeapon:InvokeServer(weaponName)
			if ok then
				buyBtn.Text = "Comprado!"
				-- Não restaura: arma comprada, botão permanece desativado visualmente
			else
				buyBtn.Text = "Sem saldo!"
				task.wait(2)
				buyBtn.Text = originalText
				buying = false  -- permite nova tentativa após feedback
			end
		end)
	end)
end

-- ── openShop ───────────────────────────────────────────────────────────────

function WeaponShopController:openShop()
	if not mainFrame then return end
	if not scrollFrame or not cardTemplate then return end

	-- Limpa cards antigos (preserva o template)
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child ~= cardTemplate then
			child:Destroy()
		end
	end

	-- Gera um card por arma não-especial
	for weaponName, stats in pairs(WeaponStats) do
		if stats.IsSpecial then continue end

		local card   = cardTemplate:Clone()
		card.Name    = "Card_" .. weaponName
		card.Visible = true
		setupCard(card, weaponName, stats)
		card.Parent  = scrollFrame
	end

	mainFrame.Visible = true
end

-- ── Init ───────────────────────────────────────────────────────────────────

function WeaponShopController:init()
	-- Conecta o evento ANTES da descoberta para não perder disparos precoces
	Remotes.OpenWeaponShop.OnClientEvent:Connect(function()
		resolveRefs()      -- no-op se já resolvido; tenta se GUI ainda não existia
		self:openShop()
	end)

	-- Tenta descobrir a GUI agora (pode não existir ainda)
	if not resolveRefs() then
		warn("[WeaponShopController] WeaponShopGui não encontrada — aguardando equipe de UI")
	end

	print("[WeaponShopController] Pronto.")
end

return WeaponShopController
