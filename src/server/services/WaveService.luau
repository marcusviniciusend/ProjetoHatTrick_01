local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local Shared          = ReplicatedStorage:WaitForChild("Shared")
local WaveData        = require(Shared.configs.WaveData)
local EnemyService    = require(script.Parent.EnemyService)
local CurrencyService = require(script.Parent.CurrencyService)
local Remotes         = require(Shared.network.Remotes)

local WaveService = {}

local WAVE_START_DELAY = 15
local BETWEEN_WAVES    = 20

local TOTAL_WAVES = 0
for _ in pairs(WaveData) do TOTAL_WAVES += 1 end

local currentWave    = 0
local totalSpawned   = 0
local totalRemoved   = 0
local waveInProgress = false
local gameEnded      = false

-- ── Helpers ────────────────────────────────────────────────────────────────

local function broadcast(data)
	Remotes.WaveUpdate:FireAllClients(data)
end

local function rewardAll(amount)
	for _, player in ipairs(Players:GetPlayers()) do
		CurrencyService:addMoney(player, amount)
	end
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
		task.delay(BETWEEN_WAVES, function()
			if not gameEnded then
				WaveService:startWave(currentWave + 1)
			end
		end)
	else
		gameEnded = true
		broadcast({ type = "victory", wave = currentWave, total = TOTAL_WAVES })
		print("[WaveService] VITORIA! Todas as waves concluídas.")
	end
end

local function onGameOver()
	if gameEnded then return end
	gameEnded      = true
	waveInProgress = false
	broadcast({ type = "gameover", wave = currentWave, total = TOTAL_WAVES })
	print("[WaveService] GAME OVER! Base destruída.")
end

-- ── API pública ────────────────────────────────────────────────────────────

function WaveService:startWave(waveNumber)
	if gameEnded then return end

	local waveData = WaveData[waveNumber]
	if not waveData then
		warn(("[WaveService] Wave %d não definida"):format(waveNumber))
		return
	end

	currentWave    = waveNumber
	totalSpawned   = 0
	totalRemoved   = 0
	waveInProgress = true

	broadcast({ type = "started", wave = currentWave, total = TOTAL_WAVES })
	print(("[WaveService] === Wave %d iniciada! ==="):format(currentWave))

	task.spawn(function()
		for _, group in ipairs(waveData.groups) do
			for _ = 1, group.count do
				if gameEnded then return end
				local enemy = EnemyService:spawn(group.enemy, { hp = group.hp, speed = group.speed })
				if enemy then totalSpawned += 1 end
				if group.interval > 0 then task.wait(group.interval) end
			end
		end
	end)
end

function WaveService:init()
	EnemyService:init(onEnemyRemoved, onGameOver)

	broadcast({ type = "waiting", wave = 0, total = TOTAL_WAVES, countdown = WAVE_START_DELAY })
	print(("[WaveService] Wave 1 começa em %ds..."):format(WAVE_START_DELAY))

	task.delay(WAVE_START_DELAY, function()
		if not gameEnded then self:startWave(1) end
	end)
end

return WaveService
