local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local Shared          = ReplicatedStorage:WaitForChild("Shared")
local WaveData        = require(Shared.configs.WaveData)
local EnemyService    = require(script.Parent.EnemyService)
local CurrencyService = require(script.Parent.CurrencyService)

local WaveService = {}

local WAVE_START_DELAY = 15  -- segundos antes da wave 1
local BETWEEN_WAVES    = 20  -- segundos entre waves

local currentWave    = 0
local totalSpawned   = 0
local totalRemoved   = 0
local waveInProgress = false

-- ── Callbacks ──────────────────────────────────────────────────────────────

local function rewardAll(amount)
	for _, player in ipairs(Players:GetPlayers()) do
		CurrencyService:addMoney(player, amount)
	end
end

local function onEnemyRemoved()
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
		print(("[WaveService] Próxima wave em %ds..."):format(BETWEEN_WAVES))
		task.delay(BETWEEN_WAVES, function()
			WaveService:startWave(currentWave + 1)
		end)
	else
		print("[WaveService] Todas as waves concluídas!")
	end
end

-- ── API pública ────────────────────────────────────────────────────────────

function WaveService:startWave(waveNumber)
	local waveData = WaveData[waveNumber]
	if not waveData then
		warn(("[WaveService] Wave %d não definida"):format(waveNumber))
		return
	end

	currentWave    = waveNumber
	totalSpawned   = 0
	totalRemoved   = 0
	waveInProgress = true

	print(("[WaveService] === Wave %d iniciada! ==="):format(currentWave))

	task.spawn(function()
		for _, group in ipairs(waveData.groups) do
			for _ = 1, group.count do
				local enemy = EnemyService:spawn(group.enemy, {
					hp    = group.hp,
					speed = group.speed,
				})
				if enemy then
					totalSpawned += 1
				end
				if group.interval > 0 then
					task.wait(group.interval)
				end
			end
		end
	end)
end

function WaveService:init()
	-- WaveService é dono do callback do EnemyService
	EnemyService:init(onEnemyRemoved)

	print(("[WaveService] Wave 1 começa em %ds..."):format(WAVE_START_DELAY))
	task.delay(WAVE_START_DELAY, function()
		self:startWave(1)
	end)
end

return WaveService
