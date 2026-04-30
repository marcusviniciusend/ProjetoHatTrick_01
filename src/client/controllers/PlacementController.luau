local CollectionService = game:GetService("CollectionService")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.network.Remotes)

local PlacementController = {}

local GRID_SIZE  = 6          -- cada slot tem 6x6 studs
local TOWER_TAG  = "Tower"

-- Substitua pelo assetId do cursor de deleção desejado (imagem 64×64 carregada no Roblox).
-- Exemplo: "rbxassetid://SUA_ID_AQUI"
-- Deixe em "" para usar o cursor padrão enquanto o asset não estiver disponível.
local DELETE_CURSOR_ID = ""

local player   = Players.LocalPlayer
local mouse    = player:GetMouse()

local towersFolder = ReplicatedStorage:FindFirstChild("towers")

local blocoFantasma     = nil
local ghostModel        = nil
local ghostHeightOffset = 0
local assignedPlot      = nil
local deleteHighlight   = nil   -- Highlight aplicado à torre sob o cursor no modo deletar

local modoConstrucaoAtivo = false
local modoDeletarAtivo    = false
local torreSelecionada    = nil

-- ── Helpers ────────────────────────────────────────────────────────────────

local function getHoveredQuad(): BasePart?
	if not assignedPlot then return nil end
	local target = mouse.Target
	if target and target.Name == "plotQuad" and target:IsDescendantOf(assignedPlot) then
		return target :: BasePart
	end
	return nil
end

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

local function isMouseOnPlot(): boolean
	return getHoveredQuad() ~= nil
end

-- Verifica se a PrimaryPart de um modelo está dentro da bounding box XZ do plot atribuído.
-- Torres ficam diretamente em Workspace (não dentro do plot), por isso usamos posição.
local function isModelOnMyPlot(model: Model): boolean
	if not assignedPlot then return false end
	local pp = model.PrimaryPart
	if not pp then return false end

	local cf, size
	if assignedPlot:IsA("BasePart") then
		cf, size = assignedPlot.CFrame, assignedPlot.Size
	elseif assignedPlot:IsA("Model") then
		cf, size = assignedPlot:GetBoundingBox()
	else
		return false
	end

	local localPos = cf:PointToObjectSpace(pp.Position)
	local half     = size / 2
	return math.abs(localPos.X) <= half.X and math.abs(localPos.Z) <= half.Z
end

-- Retorna o Model da torre sob o cursor, SE ela pertencer ao plot do player. Nil caso contrário.
local function getHoveredTowerOnMyPlot(): Model?
	local target = mouse.Target
	if not target then return nil end

	local model = target
	while model and not model:IsA("Model") do
		model = model.Parent
	end

	if model
		and CollectionService:HasTag(model, TOWER_TAG)
		and isModelOnMyPlot(model) then
		return model :: Model
	end
	return nil
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

	ghostModel.Parent = Workspace

	if ghostModel.PrimaryPart then
		local bCF, bSize  = ghostModel:GetBoundingBox()
		local pivotY      = ghostModel:GetPivot().Position.Y
		ghostHeightOffset = pivotY - (bCF.Position.Y - bSize.Y / 2)
	end
end

local function setGhostColor(valid: boolean)
	local color = valid and Color3.fromRGB(0, 255, 80) or Color3.fromRGB(220, 40, 40)
	if ghostModel then
		for _, part in ipairs(ghostModel:GetDescendants()) do
			if part:IsA("BasePart") then part.Color = color end
		end
		if ghostModel.PrimaryPart then ghostModel.PrimaryPart.Color = color end
	end
	if blocoFantasma then blocoFantasma.Color = color end
end

local function hideAll()
	blocoFantasma.Transparency = 1
	destroyGhost()
end

local function clearDeleteHighlight()
	if deleteHighlight then
		deleteHighlight.Adornee = nil
		deleteHighlight.Enabled = false
	end
end

-- ── Init ───────────────────────────────────────────────────────────────────

function PlacementController:init()
	Remotes.PlotAssigned.OnClientEvent:Connect(function(plot)
		assignedPlot = plot
	end)

	blocoFantasma              = Instance.new("Part")
	blocoFantasma.Name         = "GhostPreview"
	blocoFantasma.Anchored     = true
	blocoFantasma.CanCollide   = false
	blocoFantasma.CanQuery     = false
	blocoFantasma.CastShadow   = false
	blocoFantasma.Material     = Enum.Material.Neon
	blocoFantasma.Transparency = 1
	blocoFantasma.Parent       = Workspace

	-- Highlight para indicar a torre que será deletada
	deleteHighlight                   = Instance.new("Highlight")
	deleteHighlight.Name              = "DeleteHighlight"
	deleteHighlight.FillColor         = Color3.fromRGB(220, 50, 50)
	deleteHighlight.FillTransparency  = 0.55
	deleteHighlight.OutlineColor      = Color3.fromRGB(255, 120, 0)
	deleteHighlight.OutlineTransparency = 0
	deleteHighlight.Enabled           = false
	deleteHighlight.Parent            = Workspace

	RunService.RenderStepped:Connect(function()
		if not mouse.Hit then return end

		if modoConstrucaoAtivo then
			local quad    = getHoveredQuad()
			local valid   = quad ~= nil and quad:GetAttribute("Ocupado") ~= true
			local snapped = getSnapPosition()
			if ghostModel and ghostModel.PrimaryPart then
				ghostModel:PivotTo(CFrame.new(snapped))
			else
				blocoFantasma.Position = snapped
			end
			setGhostColor(valid)

		elseif modoDeletarAtivo then
			-- Hover highlight: realça a torre do player sob o cursor
			local tower = getHoveredTowerOnMyPlot()
			if tower then
				deleteHighlight.Adornee = tower
				deleteHighlight.Enabled = true
			else
				clearDeleteHighlight()
			end
		end
	end)

	mouse.Button1Down:Connect(function()
		if modoConstrucaoAtivo and torreSelecionada then
			local quad = getHoveredQuad()
			if quad and quad:GetAttribute("Ocupado") ~= true then
				Remotes.PlaceTower:FireServer(torreSelecionada, quad)
			end

		elseif modoDeletarAtivo then
			local tower = getHoveredTowerOnMyPlot()
			if tower then
				-- Deleção = venda instantânea (50% de reembolso, validado no servidor)
				task.spawn(function()
					Remotes.RequestTowerAction:InvokeServer(tower, "Sell")
				end)
			end
		end
	end)
end

-- ── API pública ────────────────────────────────────────────────────────────

function PlacementController:selectTower(towerName: string, size: Vector3?, color: Color3?)
	torreSelecionada    = towerName
	modoConstrucaoAtivo = true
	modoDeletarAtivo    = false

	makeGhostFor(towerName)

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
	torreSelecionada = nil
	modoDeletarAtivo = not modoDeletarAtivo
	blocoFantasma.Transparency = 1   -- blocoFantasma não é usado no modo deletar

	if modoDeletarAtivo then
		mouse.Icon = DELETE_CURSOR_ID
	else
		mouse.Icon = ""
		clearDeleteHighlight()
	end
end

function PlacementController:setLocked(locked: boolean)
	if locked then
		modoConstrucaoAtivo = false
		modoDeletarAtivo    = false
		torreSelecionada    = nil
		mouse.Icon          = ""
		clearDeleteHighlight()
		hideAll()
	end
end

function PlacementController:isBuildModeActive(): boolean
	return modoConstrucaoAtivo or modoDeletarAtivo
end

function PlacementController:resetAll()
	modoConstrucaoAtivo = false
	modoDeletarAtivo    = false
	torreSelecionada    = nil
	mouse.Icon          = ""
	clearDeleteHighlight()
	hideAll()
end

return PlacementController
