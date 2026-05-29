local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes                = require(ReplicatedStorage:WaitForChild("Shared").network.Remotes)
local WeaponStats            = require(ReplicatedStorage.Shared.configs.WeaponStats)
local WeaponInventoryService = require(script.Parent.WeaponInventoryService)
local EnemyService           = require(script.Parent.EnemyService)
local PlotService            = require(script.Parent.PlotService)
local CurrencyService        = require(script.Parent.CurrencyService)

local WeaponService = {}

local cooldowns = {} -- { [userId]: number }

-- ── Helpers de hit-detection ───────────────────────────────────────────────

local function angleFromLook(hrp: BasePart, targetPos: Vector3): number
	local dir  = (targetPos - hrp.Position)
	if dir.Magnitude < 0.001 then return 180 end
	local dot  = hrp.CFrame.LookVector:Dot(dir.Unit)
	return math.deg(math.acos(math.clamp(dot, -1, 1)))
end

local function getMeleeHits(hrp: BasePart, enemies, range: number, halfAngle: number)
	local hits = {}
	for model, enemyObj in pairs(enemies) do
		if enemyObj._dead then continue end
		local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
		if not root then continue end
		if (root.Position - hrp.Position).Magnitude > range then continue end
		if angleFromLook(hrp, root.Position) > halfAngle then continue end
		table.insert(hits, enemyObj)
	end
	return hits
end

-- ── Handlers por tipo ──────────────────────────────────────────────────────

local function handleMelee(player: Player, hrp: BasePart, stats, plot)
	local isCleave  = stats.CleaveAngle ~= nil and stats.CleaveRange ~= nil
	local range     = isCleave and stats.CleaveRange     or (stats.FrontRange or 6)
	local halfAngle = isCleave and (stats.CleaveAngle / 2) or 60

	local enemies = EnemyService:getActiveForPlot(plot)
	local hits    = getMeleeHits(hrp, enemies, range, halfAngle)

	for _, enemyObj in ipairs(hits) do
		enemyObj:takeDamage(stats.Damage)
		if stats.Passive == "CoinOnHit" then
			CurrencyService:addMoney(player, 1)
		end
	end
end

local function handleRangedHoming(player: Player, payload, stats, plot)
	local target = payload.target
	if typeof(target) ~= "Instance" or not target:IsA("Model") then
		warn(("[WeaponService] RangedHoming: payload.target inválido para '%s'"):format(player.Name))
		return
	end

	local enemies  = EnemyService:getActiveForPlot(plot)
	local enemyObj = enemies[target]
	if not enemyObj then
		warn(("[WeaponService] RangedHoming: inimigo fora do plot de '%s'"):format(player.Name))
		return
	end
	if enemyObj._dead then return end

	enemyObj:takeDamage(stats.Damage)
end

local function handleRangedSplash(player: Player, payload, stats, plot)
	local pos = payload.position
	if typeof(pos) ~= "Vector3" then
		warn(("[WeaponService] Splash: payload.position inválido para '%s'"):format(player.Name))
		return
	end

	if not PlotService:isInsidePlot(player, pos) then
		warn(("[WeaponService] Splash: posição fora do plot de '%s'"):format(player.Name))
		return
	end

	local splash  = stats.SplashRadius
	local enemies = EnemyService:getActiveForPlot(plot)

	for model, enemyObj in pairs(enemies) do
		if enemyObj._dead then continue end
		local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
		if not root then continue end
		if (root.Position - pos).Magnitude <= splash then
			enemyObj:takeDamage(stats.Damage)
		end
	end
end

-- ── Init ───────────────────────────────────────────────────────────────────

function WeaponService:init()
	Remotes.WeaponFire.OnServerEvent:Connect(function(player: Player, payload)
		-- ── Sanity checks ──────────────────────────────────────────────────
		if type(payload) ~= "table" then return end

		local character = player.Character
		local hrp       = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		local weaponName = WeaponInventoryService:getEquipped(player)
		if not weaponName then return end

		local stats = WeaponStats[weaponName]
		if not stats then
			warn(("[WeaponService] WeaponStats não encontrado para '%s'"):format(tostring(weaponName)))
			return
		end

		local now    = tick()
		local userId = player.UserId
		if cooldowns[userId] and (now - cooldowns[userId]) < stats.Cooldown then return end
		cooldowns[userId] = now

		local plot = PlotService:getPlot(player)
		if not plot then return end

		-- ── Dispatch ───────────────────────────────────────────────────────
		local ok, err = pcall(function()
			if stats.SplashRadius then
				handleRangedSplash(player, payload, stats, plot)
			elseif stats.Type == "Ranged" then
				handleRangedHoming(player, payload, stats, plot)
			else
				handleMelee(player, hrp, stats, plot)
			end
		end)
		if not ok then
			warn(("[WeaponService] Erro interno para '%s': %s"):format(player.Name, tostring(err)))
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player.UserId] = nil
	end)

	print("[WeaponService] Pronto.")
end

return WeaponService
