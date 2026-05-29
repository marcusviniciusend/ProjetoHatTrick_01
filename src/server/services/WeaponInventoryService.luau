local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes     = require(ReplicatedStorage.Shared.network.Remotes)
local DataService = require(script.Parent.DataService)

local WeaponInventoryService = {}

-- ── Helpers internos ───────────────────────────────────────────────────────

local function getWeapons(player: Player)
	local profile = DataService:GetProfile(player)
	if not profile then return nil end
	return profile.Inventory.Weapons
end

local function hasWeapon(weapons, weaponName: string): boolean
	for _, name in ipairs(weapons.Inventory) do
		if name == weaponName then return true end
	end
	return false
end

-- ── API pública ────────────────────────────────────────────────────────────

function WeaponInventoryService:giveWeapon(player: Player, weaponName: string)
	local weapons = getWeapons(player)
	if not weapons then return end

	table.insert(weapons.Inventory, weaponName)
	print(("[WeaponInventoryService] '%s' recebeu '%s'"):format(player.Name, weaponName))

	Remotes.WeaponInventoryUpdated:FireClient(player, weapons.Inventory)

	-- Auto-equip no MVP
	self:equip(player, weaponName)
end

function WeaponInventoryService:equip(player: Player, weaponName: string)
	local weapons = getWeapons(player)
	if not weapons then return end

	if not hasWeapon(weapons, weaponName) then
		warn(("[WeaponInventoryService] '%s' não possui '%s'"):format(player.Name, weaponName))
		return
	end

	weapons.Equipped = weaponName
	print(("[WeaponInventoryService] '%s' equipou '%s'"):format(player.Name, weaponName))

	Remotes.WeaponEquipped:FireClient(player, weaponName)
end

function WeaponInventoryService:getEquipped(player: Player): string?
	local weapons = getWeapons(player)
	if not weapons then return nil end
	return weapons.Equipped
end

function WeaponInventoryService:getInventory(player: Player): { string }
	local weapons = getWeapons(player)
	if not weapons then return {} end
	return weapons.Inventory
end

-- ── Init ───────────────────────────────────────────────────────────────────

function WeaponInventoryService:init()
	Remotes.GetEquippedWeapon.OnServerInvoke = function(player: Player)
		local ok, result = pcall(function()
			return self:getEquipped(player)
		end)
		if not ok then
			warn(("[WeaponInventoryService] Erro em GetEquippedWeapon: %s"):format(tostring(result)))
			return nil
		end
		return result
	end

	Remotes.GetWeaponInventory.OnServerInvoke = function(player: Player)
		local ok, result = pcall(function()
			return self:getInventory(player)
		end)
		if not ok then
			warn(("[WeaponInventoryService] Erro em GetWeaponInventory: %s"):format(tostring(result)))
			return {}
		end
		return result
	end

	Remotes.WeaponEquip.OnServerInvoke = function(player: Player, weaponName: string)
		local ok, result = pcall(function()
			if type(weaponName) ~= "string" then return false end
			local inventory = self:getInventory(player)
			for _, name in ipairs(inventory) do
				if name == weaponName then
					self:equip(player, weaponName)
					return true
				end
			end
			warn(("[WeaponInventoryService] WeaponEquip: '%s' não possui '%s'"):format(
				player.Name, weaponName))
			return false
		end)
		if not ok then
			warn(("[WeaponInventoryService] Erro em WeaponEquip: %s"):format(tostring(result)))
			return false
		end
		return result
	end

	print("[WeaponInventoryService] Pronto.")
end

return WeaponInventoryService
