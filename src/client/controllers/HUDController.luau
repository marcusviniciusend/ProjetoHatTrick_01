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

-- Plot atribuído ao jogador local (preenchido pelo PlotAssigned event)
local myPlot = nil

-- ── Helpers de teleporte ───────────────────────────────────────────────────

-- Espelha getPlotSpawnCFrame do servidor para encontrar o ponto exato de spawn do plot
local function getPlotSpawnCFrame(plot): CFrame
	local spawnPart = plot:FindFirstChild("SpawnPoint", true)
	if spawnPart and spawnPart:IsA("BasePart") then
		return spawnPart.CFrame
	end
	if plot:IsA("Model") then
		local cf = plot:GetBoundingBox()
		return cf
	end
	if plot:IsA("BasePart") then
		return plot.CFrame
	end
	return CFrame.new(0, 0, 0)
end

local function teleportCharacter(targetCF: CFrame, yOffset: number)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	hrp.CFrame = targetCF + Vector3.new(0, yOffset, 0)
end

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

local function applyPlotHp(plot)
	myPlot = plot
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
end

-- initialPlot: se fornecido, aplica o watcher imediatamente (resolve race condition
-- em que PlotAssigned já disparou antes do cliente terminar de carregar).
-- Idempotente: múltiplos calls reaproveitam o mesmo listener do evento.
local plotListenerUp = false
local function watchPlotBase(initialPlot)
	if not plotListenerUp then
		plotListenerUp = true
		Remotes.PlotAssigned.OnClientEvent:Connect(applyPlotHp)
	end
	if initialPlot then
		applyPlotHp(initialPlot)
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

	-- ── Botão de teleporte para o plot ────────────────────────────────────────
	local plotButton = frame:WaitForChild("PlotButton", 5)
	if plotButton then
		plotButton.MouseButton1Click:Connect(function()
			if not myPlot then
				warn("[HUDController] PlotButton clicado mas plot ainda não atribuído")
				return
			end
			teleportCharacter(getPlotSpawnCFrame(myPlot), 5)
		end)
	else
		warn("[HUDController] PlotButton não encontrado no Frame")
	end

	-- ── Botão de teleporte para a loja ────────────────────────────────────────
	local storeButton = frame:WaitForChild("StoreButton", 5)
	if storeButton then
		storeButton.MouseButton1Click:Connect(function()
			local storeTp = Workspace:FindFirstChild("StoreTp", true)
			if not storeTp then
				warn("[HUDController] StoreTp não encontrado no Workspace")
				return
			end
			local targetCF = storeTp:IsA("BasePart") and storeTp.CFrame
				or (storeTp:IsA("Model") and storeTp:GetPivot())
			if targetCF then
				teleportCharacter(targetCF, 3)
			end
		end)
	else
		warn("[HUDController] StoreButton não encontrado no Frame")
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

	-- Configura listener imediatamente (antes de qualquer yield) para não perder PlotAssigned
	watchPlotBase()

	-- Busca o estado atual em background; se PlotAssigned já disparou antes do cliente
	-- carregar, watchPlotBase(plot) aplica applyPlotHp diretamente sem esperar o evento
	task.spawn(function()
		local plot = Remotes.GetMyPlot:InvokeServer()
		if plot and not myPlot then
			watchPlotBase(plot)
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
	Remotes.PhaseChanged.OnClientEvent:Connect(onPhaseChanged)
	Remotes.PlayerDefeated.OnClientEvent:Connect(function(data)
		showGameEnd(data and data.wave or 0)
	end)
end

return HUDController
