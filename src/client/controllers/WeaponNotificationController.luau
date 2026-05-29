local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes     = require(ReplicatedStorage:WaitForChild("Shared").network.Remotes)
local WeaponStats = require(ReplicatedStorage.Shared.configs.WeaponStats)

local WeaponNotificationController = {}

local player = Players.LocalPlayer
local gui    = player:WaitForChild("PlayerGui")

local notifFrame  = nil  -- WeaponDropNotification frame
local hideThread  = nil  -- thread do task.delay atual (para cancelar se necessário)

-- ── Descoberta lazy ────────────────────────────────────────────────────────

local function resolveFrame(): Instance?
	if notifFrame and notifFrame.Parent then return notifFrame end
	notifFrame = gui:FindFirstChild("WeaponDropNotification", true)
	return notifFrame
end

-- ── show ──────────────────────────────────────────────────────────────────

function WeaponNotificationController:show(data: { weaponName: string, wave: number })
	local frame = resolveFrame()
	if not frame then
		warn("[WeaponNotificationController] WeaponDropNotification não encontrada")
		return
	end

	-- Popula labels — skip silencioso se label não existir
	local nameLbl    = frame:FindFirstChild("WeaponNameLabel")
	local typeLbl    = frame:FindFirstChild("WeaponTypeLabel")
	local flavorLbl  = frame:FindFirstChild("FlavorLabel")

	if nameLbl then
		nameLbl.Text = data.weaponName
	end

	if typeLbl then
		local stats = WeaponStats[data.weaponName]
		typeLbl.Text = stats and stats.Type or ""
	end

	if flavorLbl then
		flavorLbl.Text = ("Arma lendária obtida! (Wave %d)"):format(data.wave)
	end

	-- Cancela hide anterior se a notif ainda estiver visível
	if hideThread then
		task.cancel(hideThread)
		hideThread = nil
	end

	frame.Visible = true

	hideThread = task.delay(4, function()
		frame.Visible = false
		hideThread = nil
	end)
end

-- ── Init ──────────────────────────────────────────────────────────────────

function WeaponNotificationController:init()
	-- Tenta resolver agora; se GUI não existir, show() tentará lazy na chegada do evento
	if not resolveFrame() then
		warn("[WeaponNotificationController] WeaponDropNotification não encontrada — aguardando equipe de UI")
	end

	Remotes.WeaponDropped.OnClientEvent:Connect(function(data)
		self:show(data)
	end)

	print("[WeaponNotificationController] Pronto.")
end

return WeaponNotificationController
