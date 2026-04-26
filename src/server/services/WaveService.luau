local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")

local Shared            = ReplicatedStorage:WaitForChild("Shared")
local WaveData          = require(Shared.configs.WaveData)
local Remotes           = require(Shared.network.Remotes)

local EnemyService     = require(script.Parent.EnemyService)
local CurrencyService  = require(script.Parent.CurrencyService)
local PlacementService = require(script.Parent.PlacementService)

local WaveService = {}

local BETWEEN_WAVES = 20  -- segundos entre waves durante CombatPhase

local TOTAL_WAVES = 0
for _ in pairs(WaveData) do TOTAL_WAVES += 1 end

-- ── Estado ─────────────────────────────────────────────────────────────────

local currentPhase   = "BuildPhase"
local currentWave    = 0
local totalSpawned   = 0
local totalRemoved   = 0
local waveInProgress = false
local gameEnded      = false

-- Token de cancelamento: incrementado sempre que o combate é encerrado.
-- Cada spawn loop captura o valor no início e verifica antes de cada spawn.
local waveRunId = 0

local baseHPRef     = nil
local initialBaseHP = 100

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
	currentWave    = 0
	totalSpawned   = 0
	totalRemoved   = 0
	waveInProgress = false
	gameEnded      = false
end

-- Encerramento unificado: cancela spawns, limpa inimigos, restaura mapa.
-- immediate=true pula o delay no client (desistência manual).
-- immediate=false mostra o GameEndFrame por 3s (derrota / vitória).
local function doShutdown(immediate: boolean)
	waveRunId     += 1                       -- invalida todos os spawn loops ativos
	EnemyService:clearAllEnemies()           -- limpa inimigos instantaneamente
	PlacementService:restoreSnapshot()       -- restaura torres
	if baseHPRef then baseHPRef.Value = initialBaseHP end
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
	local wave = WaveData[currentWave]
	if wave then
		print(("[WaveService] Wave %d concluída! +$%d"):format(currentWave, wave.reward))
		rewardAll(wave.reward)
	end

	if WaveData[currentWave + 1] then
		broadcast({ type = "ended", wave = currentWave, total = TOTAL_WAVES, countdown = BETWEEN_WAVES })
		local capturedRunId = waveRunId
		task.delay(BETWEEN_WAVES, function()
			if waveRunId ~= capturedRunId then return end  -- combate foi encerrado no intervalo
			if not gameEnded then
				WaveService:startWave(currentWave + 1)
			end
		end)
	else
		gameEnded = true
		broadcast({ type = "victory", wave = currentWave, total = TOTAL_WAVES })
		print("[WaveService] VITÓRIA! Todas as waves concluídas.")
		task.delay(1, function()
			resetRoundState()
			doShutdown(false)
		end)
	end
end

local function onGameOver()
	if gameEnded then return end
	gameEnded      = true
	waveInProgress = false
	broadcast({ type = "gameover", wave = currentWave, total = TOTAL_WAVES })
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

	local waveData = WaveData[waveNumber]
	if not waveData then
		warn(("[WaveService] Wave %d não definida"):format(waveNumber))
		return
	end

	local totalToSpawn = 0
	for _, group in ipairs(waveData.groups) do
		totalToSpawn += group.count
	end

	currentWave    = waveNumber
	totalSpawned   = totalToSpawn
	totalRemoved   = 0
	waveInProgress = true

	broadcast({ type = "started", wave = currentWave, total = TOTAL_WAVES })
	print(("[WaveService] === Wave %d iniciada! ==="):format(currentWave))

	local myRunId = waveRunId  -- token capturado: invalida se doShutdown() for chamado
	task.spawn(function()
		for _, group in ipairs(waveData.groups) do
			for _ = 1, group.count do
				if waveRunId ~= myRunId then return end  -- combate encerrado
				local enemy = EnemyService:spawn(group.enemy, { hp = group.hp, speed = group.speed })
				if not enemy then totalSpawned -= 1 end
				if group.interval > 0 then task.wait(group.interval) end
			end
		end
	end)
end

function WaveService:init()
	local map = Workspace:FindFirstChild("Map")
	local base = map and map:FindFirstChild("Base")
	baseHPRef     = base and base:FindFirstChild("HP")
	initialBaseHP = baseHPRef and baseHPRef.Value or 100

	EnemyService:init(onEnemyRemoved, onGameOver)
	PlacementService:setPhaseProvider(function() return currentPhase end)

	broadcastPhase("BuildPhase", true)
	broadcast({ type = "buildphase", total = TOTAL_WAVES })
	print("[WaveService] BuildPhase inicial. Aguardando RequestWaveStart...")

	-- Inicia o combate
	Remotes.RequestWaveStart.OnServerEvent:Connect(function(_player)
		if currentPhase ~= "BuildPhase" then return end

		PlacementService:saveSnapshot()
		EnemyService:reset()  -- garante gameStopped = false para o novo round
		currentPhase = "CombatPhase"
		resetRoundState()

		broadcastPhase("CombatPhase")
		broadcast({ type = "combatstart", total = TOTAL_WAVES })
		print("[WaveService] CombatPhase iniciada. Wave 1 em 3s...")

		local myRunId = waveRunId
		task.delay(3, function()
			if waveRunId ~= myRunId then return end
			WaveService:startWave(1)
		end)
	end)

	-- Desistência manual: encerra o combate sem tela de derrota
	Remotes.RequestWaveEnd.OnServerEvent:Connect(function(_player)
		if currentPhase ~= "CombatPhase" then return end

		gameEnded      = true
		waveInProgress = false
		broadcast({ type = "waveend", wave = currentWave, total = TOTAL_WAVES })
		print("[WaveService] Desistência manual. Encerrando combate...")
		resetRoundState()
		doShutdown(true)  -- immediate: sem tela de derrota, volta direto pra construção
	end)
end

return WaveService
