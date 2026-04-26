local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.network.Remotes)

local PlacementController = {}

local GRID_SIZE   = 4
local ALTURA_CHAO = 2

local player      = Players.LocalPlayer
local mouse       = player:GetMouse()
local workspace   = game:GetService("Workspace")

-- Pasta de torres em ReplicatedStorage (mesma usada pelo servidor)
local towersFolder = ReplicatedStorage:FindFirstChild("towers")

local blocoFantasma     = nil  -- Part genérico (modo delete / fallback)
local ghostModel        = nil  -- Modelo 3D real da torre selecionada
local modoConstrucaoAtivo = false
local modoDeletarAtivo    = false
local torreSelecionada    = nil

-- ── Helpers ────────────────────────────────────────────────────────────────

local function snapToGrid(pos)
	return Vector3.new(
		math.round(pos.X / GRID_SIZE) * GRID_SIZE,
		ALTURA_CHAO,
		math.round(pos.Z / GRID_SIZE) * GRID_SIZE
	)
end

-- Verifica se o mouse está sobre um plot válido (parte do Map.Plots)
local function isMouseOnPlot(): boolean
	local target = mouse.Target
	if not target then return false end
	local map   = workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	if not plots then return true end  -- sem plots configurados: assume válido
	return target:IsDescendantOf(plots)
end

local function destroyGhost()
	if ghostModel then
		ghostModel:Destroy()
		ghostModel = nil
	end
end

local function makeGhostFor(towerName: string)
	destroyGhost()
	if not towersFolder then return end

	local template = towersFolder:FindFirstChild(towerName)
	if not template then return end

	ghostModel = template:Clone()

	for _, part in ipairs(ghostModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored     = true
			part.CanCollide   = false
			part.CanQuery     = false
			part.CastShadow   = false
			part.Transparency = 0.5
		end
	end
	if ghostModel.PrimaryPart then
		ghostModel.PrimaryPart.Anchored     = true
		ghostModel.PrimaryPart.CanCollide   = false
		ghostModel.PrimaryPart.CanQuery     = false
		ghostModel.PrimaryPart.CastShadow   = false
		ghostModel.PrimaryPart.Transparency = 0.5
	end

	ghostModel.Parent = workspace
end

local function setGhostColor(valid: boolean)
	if not ghostModel then return end
	local color = valid and Color3.fromRGB(0, 255, 80) or Color3.fromRGB(220, 40, 40)
	for _, part in ipairs(ghostModel:GetDescendants()) do
		if part:IsA("BasePart") then part.Color = color end
	end
	if ghostModel.PrimaryPart then ghostModel.PrimaryPart.Color = color end
end

local function hideAll()
	blocoFantasma.Transparency = 1
	destroyGhost()
end

-- ── Init ───────────────────────────────────────────────────────────────────

function PlacementController:init()
	-- Bloco genérico: usado no modo delete e como fallback se ghostModel não existe
	blocoFantasma              = Instance.new("Part")
	blocoFantasma.Name         = "GhostPreview"
	blocoFantasma.Anchored     = true
	blocoFantasma.CanCollide   = false
	blocoFantasma.CanQuery     = false
	blocoFantasma.CastShadow   = false
	blocoFantasma.Material     = Enum.Material.Neon
	blocoFantasma.Transparency = 1
	blocoFantasma.Parent       = workspace

	RunService.RenderStepped:Connect(function()
		if not mouse.Hit then return end
		local snapped = snapToGrid(mouse.Hit.Position)

		if modoConstrucaoAtivo then
			if ghostModel and ghostModel.PrimaryPart then
				ghostModel:PivotTo(CFrame.new(snapped))
				setGhostColor(isMouseOnPlot())
			else
				blocoFantasma.Position = snapped
			end

		elseif modoDeletarAtivo then
			blocoFantasma.Position = snapped
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.Q then
			self:toggleBuildMode()
		elseif input.KeyCode == Enum.KeyCode.X then
			self:toggleDeleteMode()
		elseif input.KeyCode == Enum.KeyCode.Escape then
			self:cancelPlacement()
		end
	end)

	mouse.Button1Down:Connect(function()
		if modoConstrucaoAtivo and torreSelecionada then
			local pos = ghostModel and ghostModel.PrimaryPart
				and ghostModel.PrimaryPart.Position
				or blocoFantasma.Position
			Remotes.PlaceTower:FireServer(torreSelecionada, pos)
		end
	end)
end

-- ── API pública ────────────────────────────────────────────────────────────

function PlacementController:selectTower(towerName: string, size: Vector3?, color: Color3?)
	torreSelecionada    = towerName
	modoConstrucaoAtivo = true
	modoDeletarAtivo    = false

	makeGhostFor(towerName)

	-- Fallback: bloco genérico se não há modelo 3D
	if not ghostModel then
		blocoFantasma.Size         = size  or Vector3.new(4, 4, 4)
		blocoFantasma.Color        = color or Color3.fromRGB(0, 255, 0)
		blocoFantasma.Transparency = 0.5
	else
		blocoFantasma.Transparency = 1
	end
end

function PlacementController:cancelPlacement()
	modoConstrucaoAtivo = false
	torreSelecionada    = nil
	hideAll()
end

function PlacementController:toggleBuildMode()
	modoDeletarAtivo    = false
	modoConstrucaoAtivo = not modoConstrucaoAtivo
	if not modoConstrucaoAtivo then
		destroyGhost()
		torreSelecionada = nil
	end
	blocoFantasma.Color        = Color3.fromRGB(0, 255, 0)
	blocoFantasma.Transparency = (modoConstrucaoAtivo and not ghostModel) and 0.8 or 1
end

function PlacementController:toggleDeleteMode()
	modoConstrucaoAtivo = false
	destroyGhost()
	torreSelecionada  = nil
	modoDeletarAtivo  = not modoDeletarAtivo
	blocoFantasma.Color        = Color3.fromRGB(255, 0, 0)
	blocoFantasma.Transparency = modoDeletarAtivo and 0.8 or 1
end

function PlacementController:setLocked(locked: boolean)
	if locked then
		modoConstrucaoAtivo = false
		modoDeletarAtivo    = false
		torreSelecionada    = nil
		hideAll()
	end
end

function PlacementController:isBuildModeActive(): boolean
	return modoConstrucaoAtivo or modoDeletarAtivo
end

return PlacementController
