local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local Shared     = ReplicatedStorage:WaitForChild("Shared")
local WaveConfig = require(Shared.configs.WaveData)
local Remotes    = require(Shared.network.Remotes)

local EnemyService        = require(script.Parent.EnemyService)
local CurrencyService     = require(script.Parent.CurrencyService)
local PlacementService    = require(script.Parent.PlacementService)
local PlotService         = require(script.Parent.PlotService)
local LeaderboardService  = require(script.Parent.LeaderboardService)

local WaveService = {}

local BETWEEN_WAVES = 5

-- ── Estado por plot ─────────────────────────────────────────────────────────
-- plotStates[plot] = {
--   phase: "BuildPhase" | "CombatPhase",
--   wave, reward, spawned, removed: number,
--   inProgress, ended: boolean,
--   runId: number,
-- }
local plotStates: { [any]: any } = {}

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

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function getPlayer(plot)
	local uid = PlotService:getOwnerUserId(plot)
	return uid and Players:GetPlayerByUserId(uid)
end

local function sendTo(plot, data)
	local player = getPlayer(plot)
	if player then Remotes.WaveUpdate:FireClient(player, data) end
end

local function sendPhaseTo(plot, phase: string, immediate: boolean?)
	local player = getPlayer(plot)
	if player then
		Remotes.PhaseChanged:FireClient(player, { phase = phase, immediate = immediate == true })
	end
end

local function newState()
	return {
		phase      = "BuildPhase",
		wave       = 0,
		reward     = 0,
		spawned    = 0,
		removed    = 0,
		inProgress = false,
		ended      = false,
		runId      = 0,
	}
end

local function ensureState(plot)
	if not plotStates[plot] then
		plotStates[plot] = newState()
	end
	return plotStates[plot]
end

-- ── Derrota de plot ──────────────────────────────────────────────────────────

local function onPlotDefeated(plot)
	local state = plotStates[plot]
	if not state or state.ended then return end
	state.ended      = true
	state.inProgress = false

	local player = getPlayer(plot)
	if player then
		PlacementService:destroyTowersForPlayer(player.UserId)
		Remotes.PlayerDefeated:FireClient(player, { wave = state.wave })
		LeaderboardService:recordWave(player, state.wave)
		print(("[WaveService] '%s' derrotado na wave %d"):format(player.Name, state.wave))
	end
end

-- ── Inimigo removido ─────────────────────────────────────────────────────────

local function onEnemyRemoved(plot)
	local state = plotStates[plot]
	if not state or state.ended then return end
	state.removed += 1
	if not state.inProgress then return end
	if state.removed < state.spawned then return end

	state.inProgress = false
	local player = getPlayer(plot)
	print(("[WaveService] Plot '%s' Wave %d concluída! +$%d"):format(
		plot.Name, state.wave, state.reward))

	if player then
		CurrencyService:addMoney(player, state.reward)
		LeaderboardService:recordWave(player, state.wave)
	end

	sendTo(plot, { type = "ended", wave = state.wave, countdown = BETWEEN_WAVES })

	local capturedRunId = state.runId
	task.delay(BETWEEN_WAVES, function()
		if state.runId ~= capturedRunId or state.ended then return end
		WaveService:startWaveForPlot(plot, state.wave + 1)
	end)
end

-- ── Shutdown por plot ────────────────────────────────────────────────────────

local function shutdownPlot(plot, immediate: boolean?)
	local state = plotStates[plot]
	if not state then return end
	state.runId     += 1
	state.inProgress = false
	state.ended      = false
	state.wave       = 0
	state.spawned    = 0
	state.removed    = 0
	EnemyService:resetForPlot(plot)
	local player = getPlayer(plot)
	if player then PlacementService:restoreSnapshot(player.UserId) end
	state.phase = "BuildPhase"
	sendPhaseTo(plot, "BuildPhase", immediate)
	print(("[WaveService] Plot '%s' BuildPhase restaurada."):format(plot.Name))
end

-- ── API pública ────────────────────────────────────────────────────────────

function WaveService:getPhase(player: Player?)
	if not player then return "BuildPhase" end
	local plot = PlotService:getPlot(player)
	if not plot then return "BuildPhase" end
	local state = plotStates[plot]
	return state and state.phase or "BuildPhase"
end

function WaveService:startWaveForPlot(plot, waveNumber: number)
	local state = plotStates[plot]
	if not state or state.ended then return end

	state.runId += 1
	local myRunId = state.runId

	local waveData     = generateWave(waveNumber)
	local totalToSpawn = 0
	for _, group in ipairs(waveData.groups) do
		totalToSpawn += group.count
	end

	state.wave       = waveNumber
	state.reward     = waveData.reward
	state.spawned    = totalToSpawn
	state.removed    = 0
	state.inProgress = true

	local label = waveData.isBossWave and " [BOSS]" or ""
	sendTo(plot, { type = "started", wave = waveNumber, isBoss = waveData.isBossWave })
	print(("[WaveService] Plot '%s' === Wave %d%s | reward $%d ==="):format(
		plot.Name, waveNumber, label, waveData.reward))

	task.spawn(function()
		for _, group in ipairs(waveData.groups) do
			for _ = 1, group.count do
				if state.runId ~= myRunId then return end
				if state.ended then return end
				local enemy = EnemyService:spawn(group.enemy, plot, { hp = group.hp, speed = group.speed })
				if not enemy then state.spawned -= 1 end
				if group.interval > 0 then task.wait(group.interval) end
			end
		end
	end)
end

function WaveService:init()
	EnemyService:init(onEnemyRemoved)
	EnemyService:setPlotDefeatedCallback(onPlotDefeated)
	PlacementService:setPhaseProvider(function(player) return WaveService:getPhase(player) end)

	-- Inicializa estado para jogadores já conectados (teste Studio)
	for _, player in ipairs(Players:GetPlayers()) do
		local plot = PlotService:getPlot(player)
		if plot then
			local state = ensureState(plot)
			sendPhaseTo(plot, state.phase, true)
		end
	end

	-- Inicializa estado para jogadores que entrarem depois
	Players.PlayerAdded:Connect(function(player)
		local plot = PlotService:getPlot(player)
		if plot then
			local state = ensureState(plot)
			sendPhaseTo(plot, state.phase, true)
		end
	end)

	Remotes.RequestWaveStart.OnServerEvent:Connect(function(player)
		local plot = PlotService:getPlot(player)
		if not plot then return end

		local state = ensureState(plot)
		if state.phase ~= "BuildPhase" then return end

		PlacementService:saveSnapshot(player.UserId)
		EnemyService:resetForPlot(plot)
		state.phase      = "CombatPhase"
		state.ended      = false
		state.wave       = 0
		state.runId     += 1

		sendPhaseTo(plot, "CombatPhase")
		sendTo(plot, { type = "combatstart" })
		print(("[WaveService] Plot '%s' CombatPhase por '%s'. Wave 1 em 3s..."):format(
			plot.Name, player.Name))

		local capturedRunId = state.runId
		task.delay(3, function()
			if state.runId ~= capturedRunId then return end
			WaveService:startWaveForPlot(plot, 1)
		end)
	end)

	Remotes.RequestWaveEnd.OnServerEvent:Connect(function(player)
		local plot = PlotService:getPlot(player)
		if not plot then return end

		local state = plotStates[plot]
		if not state or state.phase ~= "CombatPhase" then return end

		state.inProgress = false
		sendTo(plot, { type = "waveend", wave = state.wave })
		print(("[WaveService] Plot '%s' desistência manual por '%s'."):format(
			plot.Name, player.Name))
		shutdownPlot(plot, true)
	end)

	print("[WaveService] Iniciado. Aguardando RequestWaveStart por plot...")
end

return WaveService
