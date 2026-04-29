local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.network.Remotes)

local HUDController = {}

local player = Players.LocalPlayer
local gui    = player:WaitForChild("PlayerGui")

local waveLabel, waveStatusLabel, baseHPLabel, moneyLabel
local gameEndFrame, titleLabel, subLabel, restartButton
local startWaveButton, endWaveButton
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
				waveStatusLabel.Text = ("Próxima wave em %ds"):format(remaining)
			end
			task.wait(1)
		end
	end)
end

-- ── Game End overlay ───────────────────────────────────────────────────────

local function showGameEnd(wave)
	stopCountdown()
	if not gameEndFrame then return end
	if titleLabel then titleLabel.Text = "DERROTA!" end
	if subLabel   then subLabel.Text   = ("Base destruída na wave %d"):format(wave) end
	gameEndFrame.Visible = true
end

-- ── Eventos de wave ────────────────────────────────────────────────────────

local function onWaveUpdate(data)
	if data.type == "buildphase" then
		if waveLabel      then waveLabel.Text       = "Wave —" end
		if waveStatusLabel then waveStatusLabel.Text = "Fase de Construção" end

	elseif data.type == "combatstart" then
		if waveLabel      then waveLabel.Text       = "Wave —" end
		if waveStatusLabel then waveStatusLabel.Text = "Iniciando combate..." end

	elseif data.type == "started" then
		stopCountdown()
		local boss = data.isBoss and "  [BOSS]" or ""
		if waveLabel      then waveLabel.Text       = ("Wave %d%s"):format(data.wave, boss) end
		if waveStatusLabel then waveStatusLabel.Text = "EM ANDAMENTO" end

	elseif data.type == "ended" then
		if waveLabel then waveLabel.Text = ("Wave %d"):format(data.wave) end
		startCountdown(data.countdown or 5)

	elseif data.type == "gameover" then
		if waveLabel      then waveLabel.Text       = ("Wave %d"):format(data.wave) end
		if waveStatusLabel then waveStatusLabel.Text = "GAME OVER" end
		showGameEnd(data.wave)

	elseif data.type == "waveend" then
		stopCountdown()
		if waveLabel      then waveLabel.Text       = ("Wave %d"):format(data.wave) end
		if waveStatusLabel then waveStatusLabel.Text = "Encerrando..." end
	end
end

-- ── Mudança de fase ────────────────────────────────────────────────────────

local function onPhaseChanged(data)
	if data.phase == "CombatPhase" then
		if startWaveButton then startWaveButton.Visible = false end
		if endWaveButton   then endWaveButton.Visible   = true  end

	elseif data.phase == "BuildPhase" then
		if endWaveButton then endWaveButton.Visible = false end
		local delay = data.immediate and 0 or 3
		task.delay(delay, function()
			if gameEndFrame    then gameEndFrame.Visible    = false end
			if startWaveButton then startWaveButton.Visible = true  end
			if waveStatusLabel then waveStatusLabel.Text    = "Fase de Construção" end
		end)
	end
end

-- ── HP da base do próprio plot ─────────────────────────────────────────────

-- Aguarda o servidor atribuir o plot e então encontra a Base dentro dele.
local function watchPlotBase()
	local assignedPlot = nil

	Remotes.PlotAssigned.OnClientEvent:Connect(function(plot)
		assignedPlot = plot
		local base = plot:FindFirstChild("Base")
		local hp   = base and base:FindFirstChild("HP")

		if hp then
			if baseHPLabel then baseHPLabel.Text = ("Base: %d"):format(hp.Value) end
			hp:GetPropertyChangedSignal("Value"):Connect(function()
				if baseHPLabel then baseHPLabel.Text = ("Base: %d"):format(hp.Value) end
			end)
		else
			if baseHPLabel then baseHPLabel.Text = "Base: --" end
			warn("[HUDController] Base ou Base.HP não encontrado no plot atribuído")
		end
	end)
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

	gameEndFrame = hudUI:WaitForChild("GameEndFrame", 5)
	if gameEndFrame then
		titleLabel    = gameEndFrame:FindFirstChild("TitleLabel")
		subLabel      = gameEndFrame:FindFirstChild("SubLabel")
		restartButton = gameEndFrame:FindFirstChild("RestartButton")
		gameEndFrame.Visible = false

		if restartButton then
			restartButton.MouseButton1Click:Connect(function()
				gameEndFrame.Visible = false
			end)
		end
	else
		warn("[HUDController] GameEndFrame não encontrado no HudUI")
	end

	startWaveButton = hudUI:FindFirstChild("StartWaveButton", true)
	if startWaveButton then
		startWaveButton.Visible = true
		startWaveButton.MouseButton1Click:Connect(function()
			Remotes.RequestWaveStart:FireServer()
			startWaveButton.Visible = false
		end)
	else
		warn("[HUDController] StartWaveButton não encontrado no HudUI")
	end

	endWaveButton = hudUI:FindFirstChild("EndWaveButton", true)
	if endWaveButton then
		endWaveButton.Visible = false
		endWaveButton.MouseButton1Click:Connect(function()
			Remotes.RequestWaveEnd:FireServer()
			endWaveButton.Visible = false
		end)
	else
		warn("[HUDController] EndWaveButton não encontrado no HudUI")
	end

	waveLabel.Text       = "Wave —"
	waveStatusLabel.Text = "Fase de Construção"
	baseHPLabel.Text     = "Base: --"
	moneyLabel.Text      = "$--"

	-- HP da base: aguarda o plot ser atribuído pelo servidor
	watchPlotBase()

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
	Remotes.PhaseChanged.OnClientEvent:Connect(onPhaseChanged)
end

return HUDController
