local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.network.Remotes)

local PlacementController = {}

local GRID_SIZE   = 4
local ALTURA_CHAO = 2

local player  = Players.LocalPlayer
local mouse   = player:GetMouse()

local blocoFantasma
local modoConstrucaoAtivo = false
local modoDeletarAtivo    = false
local torreSelecionada    = nil

local function snapToGrid(pos)
	return Vector3.new(
		math.round(pos.X / GRID_SIZE) * GRID_SIZE,
		ALTURA_CHAO,
		math.round(pos.Z / GRID_SIZE) * GRID_SIZE
	)
end

function PlacementController:init()
	blocoFantasma = Instance.new("Part")
	blocoFantasma.Name         = "GhostPreview"
	blocoFantasma.Anchored     = true
	blocoFantasma.CanCollide   = false
	blocoFantasma.CanQuery     = false
	blocoFantasma.CastShadow   = false
	blocoFantasma.Material     = Enum.Material.Neon
	blocoFantasma.Transparency = 1
	blocoFantasma.Parent       = workspace

	RunService.RenderStepped:Connect(function()
		if (modoConstrucaoAtivo or modoDeletarAtivo) and mouse.Hit then
			blocoFantasma.Position = snapToGrid(mouse.Hit.Position)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.Q then
			self:toggleBuildMode()
		elseif input.KeyCode == Enum.KeyCode.X then
			self:toggleDeleteMode()
		end
	end)

	mouse.Button1Down:Connect(function()
		if modoConstrucaoAtivo and torreSelecionada then
			Remotes.PlaceTower:FireServer(torreSelecionada, blocoFantasma.Position)
		end
	end)
end

function PlacementController:selectTower(towerName, size, color)
	torreSelecionada      = towerName
	modoConstrucaoAtivo   = true
	modoDeletarAtivo      = false
	blocoFantasma.Size    = size  or Vector3.new(4, 4, 4)
	blocoFantasma.Color   = color or Color3.fromRGB(0, 255, 0)
	blocoFantasma.Transparency = 0.5
end

function PlacementController:toggleBuildMode()
	modoDeletarAtivo    = false
	modoConstrucaoAtivo = not modoConstrucaoAtivo
	blocoFantasma.Color = Color3.fromRGB(0, 255, 0)
	blocoFantasma.Transparency = modoConstrucaoAtivo and 0.8 or 1
end

function PlacementController:toggleDeleteMode()
	modoConstrucaoAtivo = false
	modoDeletarAtivo    = not modoDeletarAtivo
	blocoFantasma.Color = Color3.fromRGB(255, 0, 0)
	blocoFantasma.Transparency = modoDeletarAtivo and 0.8 or 1
end

return PlacementController
