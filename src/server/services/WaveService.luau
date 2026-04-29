local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local Shared     = ReplicatedStorage:WaitForChild("Shared")
local WaveConfig = require(Shared.configs.WaveData)
local Remotes    = require(Shared.network.Remotes)

local EnemyService     = require(script.Parent.EnemyService)
local CurrencyService  = require(script.Parent.CurrencyService)
local PlacementService = require(script.Parent.PlacementService)
local PlotService      = require(script.Parent.PlotService)

local WaveService = {}

local BETWEEN_WAVES = 5   -- segundos entre waves

-- ── Estado ─────────────────────────────────────────────────────────────────

local currentPhase      = "BuildPhase"
local currentWave       = 0
local currentWaveReward = 0
local totalSpawned      = 0
local totalRemoved      = 0
local waveInProgress    = false
local gameEnded         = false

-- Incrementado no início de cada wave E no shutdown.
-- O spawn loop captura o valor no início; se ele mudar, o loop aborta.
local waveRunId = 0

-- ── Geração procedural de waves ────────────────────────────────────────────

local function generateWave(waveNumber: number)
	local s          = WaveConfig.scaling
	local isBossWave = waveNumber % WaveConfig.bossEvery == 0
	local hpMult     = 1 + (waveNumber - 1) * s.hpGrowth

	local groups = {}

	for _, entry in ipairs(WaveConfig.enemyPool) do
		if waveNumber < entry.unlockWave then continue end

		local wavesActive = waveNumber - entry.unlockWave
		local count       = math.max(1, math.floor(entry.baseCount + wavesActive * s.countGrowth))
		local interval    = math.max(s.intervalMin, entry.interval - wavesActive * s.intervalDecay)
		local hp          = math.floor(entry.baseHP * hpMult)
		local speed       = math.min(entry.speedCap, entry.baseSpeed + wavesActive * s.speedGrowth)

		table.insert(groups, {
			enemy    = entry.name,
			count    = count,
			interval = interval,
			hp       = hp,
			speed    = math.floor(speed),
		})
	end

	if isBossWave then
		local boss      = WaveConfig.boss
		local bossIndex = waveNumber / WaveConfig.bossEvery
		table.insert(groups, {
			enemy    = boss.name,
			count    = 1,
			interval = boss.interval,
			hp       = boss.baseHP + boss.hpPerBoss * (bossIndex - 1),
			speed    = boss.speed,
		})
	end

	local reward = s.rewardBase + s.rewardGrowth * (waveNumber - 1)
	if isBossWave then reward = math.floor(reward * s.bossRewardMult) end

	return { reward = reward, isBossWave = isBossWave, groups = groups }
end

-- ── Helpers ─────────────────────────────────────────────────────────────────

local function broadcast(data)
	Remotes.WaveUpdate:FireAllClients(data)
end

local function broadcastPhase(phase: string, immediate: boolean?)
	Remotes.PhaseChanged:FireAllClients({ phase = phase, immediate = immediate == true })
end

local function rewardAll(amount)
	for _, player in ipairs(Players:GetPlayers()) do
		CurrencyService:addMoney(player, amount)
	end
end

local function resetRoundState()
	currentWave       = 0
	currentWaveReward = 0
	totalSpawned      = 0
	totalRemoved      = 0
	waveInProgress    = false
	gameEnded         = false
end

local function doShutdown(immediate: boolean)
	waveRunId += 1                      -- aborta qualquer spawn loop ativo
	EnemyService:clearAllEnemies()
	PlacementService:restoreSnapshot()
	EnemyService:resetBases()
	currentPhase = "BuildPhase"
	broadcastPhase("BuildPhase", immediate)
	print(("[WaveService] Shutdown completo (immediate=%s). BuildPhase ativa."):format(tostring(immediate)))
end

-- ── Callbacks para EnemyService ────────────────────────────────────────────

local function onEnemyRemoved()
	if gameEnded then return end
	totalRemoved += 1
	if not waveInProgress then return end
	if totalRemoved < totalSpawned then return end

	waveInProgress = false
	print(("[WaveService] Wave %d concluída! +$%d"):format(currentWave, currentWaveReward))
	rewardAll(currentWaveReward)

	-- Waves são infinitas: sempre avança para a próxima após o intervalo
	broadcast({ type = "ended", wave = currentWave, countdown = BETWEEN_WAVES })
	local capturedId = waveRunId
	task.delay(BETWEEN_WAVES, function()
		if waveRunId ~= capturedId then return end
		if not gameEnded then
			WaveService:startWave(currentWave + 1)
		end
	end)
end

local function onGameOver()
	if gameEnded then return end
	gameEnded      = true
	waveInProgress = false
	broadcast({ type = "gameover", wave = currentWave })
	print("[WaveService] GAME OVER! Base destruída.")
	task.delay(0.5, function()
		resetRoundState()
		doShutdown(false)
	end)
end

-- ── API pública ────────────────────────────────────────────────────────────

function WaveService:getPhase()
	return currentPhase
end

function WaveService:startWave(waveNumber: number)
	if gameEnded then return end

	-- Invalida o spawn loop da wave anterior antes de qualquer yield
	waveRunId += 1
	local myRunId = waveRunId

	local waveData = generateWave(waveNumber)
	local plots    = PlotService:getActivePlots()
	local numPlots = math.max(1, #plots)

	local totalToSpawn = 0
	for _, group in ipairs(waveData.groups) do
		totalToSpawn += group.count * numPlots
	end

	currentWave       = waveNumber
	currentWaveReward = waveData.reward
	totalSpawned      = totalToSpawn
	totalRemoved      = 0
	waveInProgress    = true

	local label = waveData.isBossWave and " [BOSS]" or ""
	broadcast({ type = "started", wave = currentWave, isBoss = waveData.isBossWave })
	print(("[WaveService] === Wave %d%s | %d plot(s) | reward $%d ==="):format(
		currentWave, label, numPlots, currentWaveReward))

	task.spawn(function()
		for _, group in ipairs(waveData.groups) do
			for _ = 1, group.count do
				if waveRunId ~= myRunId then return end
				for _, plot in ipairs(plots) do
					local enemy = EnemyService:spawn(group.enemy, plot, { hp = group.hp, speed = group.speed })
					if not enemy then totalSpawned -= 1 end
				end
				if group.interval > 0 then task.wait(group.interval) end
			end
		end
	end)
end

function WaveService:init()
	EnemyService:init(onEnemyRemoved, onGameOver)
	PlacementService:setPhaseProvider(function() return currentPhase end)

	broadcastPhase("BuildPhase", true)
	broadcast({ type = "buildphase" })
	print("[WaveService] BuildPhase inicial. Aguardando RequestWaveStart...")

	Remotes.RequestWaveStart.OnServerEvent:Connect(function(_player)
		if currentPhase ~= "BuildPhase" then return end

		PlacementService:saveSnapshot()
		EnemyService:reset()
		currentPhase = "CombatPhase"
		resetRoundState()

		broadcastPhase("CombatPhase")
		broadcast({ type = "combatstart" })
		print("[WaveService] CombatPhase iniciada. Wave 1 em 3s...")

		local capturedId = waveRunId
		task.delay(3, function()
			if waveRunId ~= capturedId then return end
			WaveService:startWave(1)
		end)
	end)

	Remotes.RequestWaveEnd.OnServerEvent:Connect(function(_player)
		if currentPhase ~= "CombatPhase" then return end

		gameEnded      = true
		waveInProgress = false
		broadcast({ type = "waveend", wave = currentWave })
		print("[WaveService] Desistência manual. Encerrando combate...")
		resetRoundState()
		doShutdown(true)
	end)
end

return WaveService
