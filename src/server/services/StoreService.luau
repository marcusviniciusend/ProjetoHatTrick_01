local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local Remotes           = require(ReplicatedStorage.Shared.network.Remotes)
local RarityData        = require(ReplicatedStorage.Shared.configs.RarityData)
local StoreItems        = require(ReplicatedStorage.Shared.configs.StoreItems)
local TowerStats        = require(ReplicatedStorage.Shared.configs.TowerStats)
local CurrencyService   = require(script.Parent.CurrencyService)
local InventoryService  = require(script.Parent.InventoryService)

local StoreService = {}

local SHOP_INTERVAL = 60
local MIN_SLOTS     = 3
local MAX_SLOTS     = 5

export type SlotState = {
	stock:    number,
	maxStock: number,
	rarity:   string,
	price:    number,
}

local currentShopSlots: { [string]: SlotState } = {}
local nextRotationTime = 0

-- ── Pool e seleção ponderada ───────────────────────────────────────────────

local function buildPool(): { { towerName: string, rarity: string, weight: number } }
	local pool = {}
	for rarity, items in pairs(StoreItems) do
		local rarData = RarityData[rarity]
		if not rarData then continue end
		for _, towerName in ipairs(items) do
			if TowerStats[towerName] then
				table.insert(pool, { towerName = towerName, rarity = rarity, weight = rarData.Weight })
			end
		end
	end
	return pool
end

-- Seleciona `count` itens únicos do pool usando amostragem ponderada sem reposição.
local function weightedPick(pool, count: number)
	local remaining = { table.unpack(pool) }
	local picked    = {}
	count = math.min(count, #remaining)

	for _ = 1, count do
		local total = 0
		for _, item in ipairs(remaining) do total += item.weight end
		if total <= 0 then break end

		local roll = math.random() * total
		local acc  = 0
		local idx  = #remaining
		for j, item in ipairs(remaining) do
			acc += item.weight
			if roll <= acc then idx = j; break end
		end
		table.insert(picked, remaining[idx])
		table.remove(remaining, idx)
	end
	return picked
end

-- ── Payload e sync ─────────────────────────────────────────────────────────

local function buildPayload()
	local slots = {}
	for towerName, slot in pairs(currentShopSlots) do
		table.insert(slots, {
			towerName = towerName,
			rarity    = slot.rarity,
			price     = slot.price,
			stock     = slot.stock,
			maxStock  = slot.maxStock,
		})
	end
	return { nextRotation = nextRotationTime, slots = slots }
end

local function syncAll()
	Remotes.ShopUpdated:FireAllClients(buildPayload())
end

-- ── Geração da loja ────────────────────────────────────────────────────────

local function generateNewShop()
	local count  = math.random(MIN_SLOTS, MAX_SLOTS)
	local picked = weightedPick(buildPool(), count)

	currentShopSlots = {}
	for _, item in ipairs(picked) do
		local rarData = RarityData[item.rarity]
		currentShopSlots[item.towerName] = {
			stock    = rarData.MaxStock,
			maxStock = rarData.MaxStock,
			rarity   = item.rarity,
			price    = TowerStats[item.towerName].BasePrice,
		}
	end

	nextRotationTime = os.time() + SHOP_INTERVAL
	syncAll()
	print(("[StoreService] Nova loja gerada: %d slot(s)"):format(#picked))
end

-- ── Compra (validação atômica) ─────────────────────────────────────────────

-- Roblox é single-threaded: sem yields entre a checagem e o decrement,
-- não há race condition real — dois InvokeServer simultâneos são enfileirados.
local function handleBuy(player: Player, towerName: string)
	local slot = currentShopSlots[towerName]
	if not slot then return { ok = false, reason = "Item indisponível"  } end
	if slot.stock <= 0 then return { ok = false, reason = "Esgotado"           } end
	if not CurrencyService:spendMoney(player, slot.price) then
		return { ok = false, reason = "Saldo insuficiente" } end

	slot.stock -= 1
	InventoryService:add(player, towerName)
	syncAll()
	print(("[StoreService] '%s' comprou '%s' — estoque: %d/%d"):format(
		player.Name, towerName, slot.stock, slot.maxStock))
	return { ok = true }
end

-- ── ProximityPrompt da loja (servidor garante visibilidade para todos) ─────

local function setupTowerNPCPrompt()
    local npc = workspace:FindFirstChild("TowerNPC")

    if not npc then
        warn("[StoreService] Modelo 'TowerNPC' não encontrado no Workspace.")
        return
    end

    local prompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)

    if not prompt then
        warn("[StoreService] ProximityPrompt não encontrado dentro do modelo 'TowerNPC'.")
        return
    end

    prompt.Triggered:Connect(function(player)
        Remotes.OpenShop:FireClient(player)
    end)

    print("[StoreService] Sistema de loja conectado ao prompt em:", prompt:GetFullName())
end

-- ── Init ───────────────────────────────────────────────────────────────────

function StoreService:init()
	-- Envia loja atual para jogadores que entram no meio de uma rotação
	Players.PlayerAdded:Connect(function(player)
		task.wait(1)  -- aguarda leaderstats ser criado pelo CurrencyService
		if next(currentShopSlots) then
			Remotes.ShopUpdated:FireClient(player, buildPayload())
		end
	end)

	Remotes.BuyShopItem.OnServerInvoke = handleBuy
	task.spawn(setupTowerNPCPrompt)

	task.spawn(function()
		while true do
			generateNewShop()
			task.wait(SHOP_INTERVAL)
		end
	end)

	print("[StoreService] Pronto.")
end

return StoreService
