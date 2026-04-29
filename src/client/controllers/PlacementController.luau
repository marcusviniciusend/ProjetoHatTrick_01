local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.network.Remotes)

local PlacementController = {}

local GRID_SIZE = 6  -- cada slot tem 6x6 studs

local player    = Players.LocalPlayer
local mouse       = player:GetMouse()
local workspace   = game:GetService("Workspace")

-- Pasta de torres em ReplicatedStorage (mesma usada pelo servidor)
local towersFolder = ReplicatedStorage:FindFirstChild("towers")

local blocoFantasma       = nil   -- Part genérico (modo delete / fallback)
local ghostModel          = nil   -- Modelo 3D real da torre selecionada
local ghostHeightOffset   = 0     -- distância do pivot até a base do ghost (recalculada por modelo)
local assignedPlot        = nil   -- Model do plot atribuído a este player (recebido do servidor)
local modoConstrucaoAtivo = false
local modoDeletarAtivo    = false
local torreSelecionada    = nil

-- ── Helpers ────────────────────────────────────────────────────────────────

-- Retorna o plotQuad sob o cursor SOMENTE se ele pertencer ao plot atribuído a este player.
-- Isso previne que o ghost apareça verde no plot de um vizinho.
local function getHoveredQuad(): BasePart?
	if not assignedPlot then return nil end
	local target = mouse.Target
	if target and target.Name == "plotQuad" and target:IsDescendantOf(assignedPlot) then
		return target :: BasePart
	end
	return nil
end

-- Snap ao centro do plotQuad do player; fallback para grade se não houver
local function getSnapPosition(): Vector3
	local quad = getHoveredQuad()
	if quad then
		local topY = quad.Position.Y + quad.Size.Y / 2
		return Vector3.new(quad.Position.X, topY + ghostHeightOffset, quad.Position.Z)
	end
	local pos = mouse.Hit.Position
	return Vector3.new(
		math.round(pos.X / GRID_SIZE) * GRID_SIZE,
		pos.Y + ghostHeightOffset,
		math.round(pos.Z / GRID_SIZE) * GRID_SIZE
	)
end

-- Válido somente quando o cursor está sobre um plotQuad DO PLAYER
local function isMouseOnPlot(): boolean
	return getHoveredQuad() ~= nil
end

local function destroyGhost()
	if ghostModel then
		ghostModel:Destroy()
		ghostModel = nil
	end
	ghostHeightOffset = 0
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

	-- Distância do pivot (PrimaryPart center) até a borda inferior do modelo.
	-- Garante que a torre grude na superfície do slot independente da estrutura do modelo.
	if ghostModel.PrimaryPart then
		local bCF, bSize  = ghostModel:GetBoundingBox()
		local pivotY      = ghostModel:GetPivot().Position.Y
		ghostHeightOffset = pivotY - (bCF.Position.Y - bSize.Y / 2)
	end
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
	-- Recebe do servidor qual plot pertence a este player
	Remotes.PlotAssigned.OnClientEvent:Connect(function(plot)
		assignedPlot = plot
	end)

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
		local snapped = getSnapPosition()

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
