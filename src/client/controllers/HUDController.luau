local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService   = game:GetService("TeleportService")
local Workspace         = game:GetService("Workspace")

local Remotes  = require(ReplicatedStorage.Shared.network.Remotes)
local WaveData = require(ReplicatedStorage.Shared.configs.WaveData)

local HUDController = {}

local player = Players.LocalPlayer
local gui    = player:WaitForChild("PlayerGui")

local TOTAL_WAVES = 0
for _ in pairs(WaveData) do TOTAL_WAVES += 1 end

local waveLabel, waveStatusLabel, baseHPLabel, moneyLabel
local gameEndFrame, titleLabel, subLabel, restartButton
local countdownThread = nil

-- ── Countdown ──────────────────────────────────────────────────────────────

local function stopCountdown()
	if countdownThread then
		task.cancel(countdownThread)
		countdownThread = nil
	end
end

local function startCountdown(seconds)
	stopCountdown()
	countdownThread = task.spawn(function()
		for remaining = seconds, 1, -1 do
			if waveStatusLabel then
				waveStatusLabel.Text = ("Proxima wave em %ds"):format(remaining)
			end
			task.wait(1)
		end
	end)
end

-- ── Game End overlay ───────────────────────────────────────────────────────

local function showGameEnd(isVictory, wave)
	stopCountdown()
	if not gameEndFrame then
		warn("[HUDController] GameEndFrame é nil — verifique se existe no HudUI")
		return
	end

	-- Nil-safe: seta texto só se o label existe
	if titleLabel then
		titleLabel.Text = isVictory and "VITORIA!" or "DERROTA!"
	end
	if subLabel then
		subLabel.Text = isVictory
			and ("Voce resistiu a todas as %d waves!"):format(TOTAL_WAVES)
			or  ("Sua base foi destruida na wave %d / %d"):format(wave, TOTAL_WAVES)
	end

	gameEndFrame.Visible = true  -- sempre exibe, mesmo se labels falharem
end

-- ── Eventos de wave ────────────────────────────────────────────────────────

local function onWaveUpdate(data)
	if not waveLabel then return end

	if data.type == "waiting" then
		waveLabel.Text = ("Wave - / %d"):format(data.total)
		startCountdown(data.countdown)

	elseif data.type == "started" then
		stopCountdown()
		waveLabel.Text       = ("Wave %d / %d"):format(data.wave, data.total)
		waveStatusLabel.Text = "EM ANDAMENTO"

	elseif data.type == "ended" then
		waveLabel.Text = ("Wave %d / %d"):format(data.wave, data.total)
		startCountdown(data.countdown)

	elseif data.type == "victory" then
		waveLabel.Text       = ("Wave %d / %d"):format(data.wave, data.total)
		waveStatusLabel.Text = "VITORIA!"
		showGameEnd(true, data.wave)

	elseif data.type == "gameover" then
		waveLabel.Text       = ("Wave %d / %d"):format(data.wave, data.total)
		waveStatusLabel.Text = "GAME OVER"
		showGameEnd(false, data.wave)
	end
end

-- ── Init ───────────────────────────────────────────────────────────────────

function HUDController:init()
	local hudUI = gui:WaitForChild("HudUI", 10)
	if not hudUI then
		warn("[HUDController] HudUI não encontrado")
		return
	end

	local frame = hudUI:WaitForChild("Frame", 5)
	if not frame then
		warn("[HUDController] Frame não encontrado no HudUI")
		return
	end

	waveLabel       = frame:WaitForChild("WaveLabel",       5)
	waveStatusLabel = frame:WaitForChild("WaveStatusLabel", 5)
	baseHPLabel     = frame:WaitForChild("BaseHPLabel",     5)
	moneyLabel      = frame:WaitForChild("MoneyLabel",      5)

	if not (waveLabel and waveStatusLabel and baseHPLabel and moneyLabel) then
		warn("[HUDController] Label(s) não encontrado(s) no Frame")
		return
	end

	-- GameEndFrame: busca e configura filhos com FindFirstChild (já existem no Studio)
	gameEndFrame = hudUI:WaitForChild("GameEndFrame", 5)
	if gameEndFrame then
		titleLabel    = gameEndFrame:FindFirstChild("TitleLabel")
		subLabel      = gameEndFrame:FindFirstChild("SubLabel")
		restartButton = gameEndFrame:FindFirstChild("RestartButton")
		gameEndFrame.Visible = false

		if restartButton then
			restartButton.MouseButton1Click:Connect(function()
				local ok, err = pcall(function()
					TeleportService:Teleport(game.PlaceId, player)
				end)
				if not ok then
					warn("[HUDController] Teleport indisponível no Studio: " .. tostring(err))
				end
			end)
		end
	else
		warn("[HUDController] GameEndFrame não encontrado no HudUI")
	end

	-- Textos iniciais
	waveLabel.Text       = ("Wave - / %d"):format(TOTAL_WAVES)
	waveStatusLabel.Text = "Aguardando..."
	baseHPLabel.Text     = "Base: --"
	moneyLabel.Text      = "$--"

	-- Base HP: Workspace.Map.Base
	task.spawn(function()
		local map  = Workspace:WaitForChild("Map",  15)
		local base = map  and map:WaitForChild("Base", 10)
		local hp   = base and base:FindFirstChild("HP")

		if hp then
			baseHPLabel.Text = ("Base: %d"):format(hp.Value)
			hp:GetPropertyChangedSignal("Value"):Connect(function()
				baseHPLabel.Text = ("Base: %d"):format(hp.Value)
			end)
		else
			warn("[HUDController] Base ou Base.HP não encontrado em Workspace")
		end
	end)

	-- Dinheiro via leaderstats
	task.spawn(function()
		local leaderstats = player:WaitForChild("leaderstats", 10)
		local money       = leaderstats and leaderstats:WaitForChild("Money", 5)
		if money then
			moneyLabel.Text = ("$%d"):format(money.Value)
			money:GetPropertyChangedSignal("Value"):Connect(function()
				moneyLabel.Text = ("$%d"):format(money.Value)
			end)
		end
	end)

	Remotes.WaveUpdate.OnClientEvent:Connect(onWaveUpdate)
end

return HUDController
