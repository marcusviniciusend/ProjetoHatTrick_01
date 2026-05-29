local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local Remotes                = require(ReplicatedStorage.Shared.network.Remotes)
local WeaponStats            = require(ReplicatedStorage.Shared.configs.WeaponStats)
local CurrencyService        = require(script.Parent.CurrencyService)
local WeaponInventoryService = require(script.Parent.WeaponInventoryService)

local WeaponShopService = {}

-- ── Compra ─────────────────────────────────────────────────────────────────

local function handleBuy(player: Player, weaponName: string): boolean
	if type(weaponName) ~= "string" then
		warn(("[WeaponShopService] weaponName inválido de '%s'"):format(player.Name))
		return false
	end

	local stats = WeaponStats[weaponName]
	if not stats then
		warn(("[WeaponShopService] '%s' não existe em WeaponStats"):format(weaponName))
		return false
	end

	if stats.IsSpecial then
		warn(("[WeaponShopService] '%s' é especial e não pode ser comprada"):format(weaponName))
		return false
	end

	local inventory = WeaponInventoryService:getInventory(player)
	for _, owned in ipairs(inventory) do
		if owned == weaponName then
			warn(("[WeaponShopService] '%s' já possui '%s'"):format(player.Name, weaponName))
			return false
		end
	end

	if not CurrencyService:spendMoney(player, stats.BasePrice) then
		return false
	end

	WeaponInventoryService:giveWeapon(player, weaponName)
	print(("[WeaponShopService] '%s' comprou '%s' por $%d"):format(player.Name, weaponName, stats.BasePrice))
	return true
end

-- ── ProximityPrompt do WeaponNPC ──────────────────────────────────────────

local function setupWeaponNPCPrompt()
	local map = Workspace:WaitForChild("Map", 10)
	if not map then
		warn("[WeaponShopService] Workspace.Map não encontrado — ProximityPrompt não criado")
		return
	end

	local npc = map:FindFirstChild("WeaponNPC", true)
	if not npc then
		warn("[WeaponShopService] NPC 'WeaponNPC' não encontrado em Map — ProximityPrompt não criado")
		return
	end

	local adornee = npc:IsA("Model") and npc.PrimaryPart
		or (npc:IsA("BasePart") and npc)
	if not adornee then
		warn("[WeaponShopService] WeaponNPC não tem PrimaryPart definida — ProximityPrompt não criado")
		return
	end

	local prompt = adornee:FindFirstChildWhichIsA("ProximityPrompt")
	if not prompt then
		prompt                      = Instance.new("ProximityPrompt")
		prompt.ActionText           = "Comprar Armas"
		prompt.KeyboardKeyCode      = Enum.KeyCode.E
		prompt.MaxActivationDistance = 8
		prompt.Parent               = adornee
	end

	prompt.Triggered:Connect(function(player: Player)
		Remotes.OpenWeaponShop:FireClient(player)
	end)

	print(("[WeaponShopService] ProximityPrompt conectado em: %s"):format(adornee:GetFullName()))
end

-- ── Init ───────────────────────────────────────────────────────────────────

function WeaponShopService:init()
	Remotes.BuyWeapon.OnServerInvoke = function(player: Player, weaponName: string)
		local ok, result = pcall(handleBuy, player, weaponName)
		if not ok then
			warn(("[WeaponShopService] Erro interno em BuyWeapon: %s"):format(tostring(result)))
			return false
		end
		return result
	end

	task.spawn(setupWeaponNPCPrompt)

	print("[WeaponShopService] Pronto.")
end

return WeaponShopService
