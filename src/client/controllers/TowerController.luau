local CollectionService = game:GetService("CollectionService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")

local UIController        = require(script.Parent.UIController)
local PlacementController = require(script.Parent.PlacementController)
local Remotes             = require(ReplicatedStorage.Shared.network.Remotes)
local TowerStats          = require(ReplicatedStorage.Shared.configs.TowerStats)
local HealthBarUtil       = require(ReplicatedStorage.Shared.utils.HealthBarUtil)

local TOWER_TAG = "Tower"

local TowerController = {}

local player         = Players.LocalPlayer
local mouse          = player:GetMouse()
local selectedBox    = nil
local selectedTower  = nil
local rangeIndicator = nil

-- { [towerModel]: enemyModel } — alvo cosmético atual de cada torre
local towerTargets = {}

local TOWER_BAR_CONFIG = {
	studsOffset = Vector3.new(0, 4, 0),
	maxDistance = 60,
	showLevel   = true,
}

-- ── Efeitos de ataque ─────────────────────────────────────────────────────

local function spawnLaser(towerModel: Model, enemyModel: Model)
	local towerPrimary = towerModel.PrimaryPart
	local enemyPrimary = enemyModel.PrimaryPart
	if not towerPrimary or not enemyPrimary then return end

	local startPos = towerPrimary.Position + Vector3.new(0, towerPrimary.Size.Y * 0.4, 0)
	local endPos   = enemyPrimary.Position
	local length   = (endPos - startPos).Magnitude
	if length < 0.1 then return end

	local laser = Instance.new("Part")
	laser.Name         = "LaserEffect"
	laser.Size         = Vector3.new(0.15, 0.15, length)
	laser.CFrame       = CFrame.new((startPos + endPos) / 2, endPos)
	laser.Anchored     = true
	laser.CanCollide   = false
	laser.CanQuery     = false
	laser.CastShadow   = false
	laser.Material     = Enum.Material.Neon
	laser.Color        = Color3.fromRGB(255, 200, 50)
	laser.Transparency = 0
	laser.Parent       = Workspace

	TweenService:Create(laser, TweenInfo.new(0.12, Enum.EasingStyle.Linear), {
		Transparency = 1,
		Size         = Vector3.new(0.04, 0.04, length),
	}):Play()

	task.delay(0.15, function()
		if laser.Parent then laser:Destroy() end
	end)
end

local function playAttackSound(towerModel: Model)
	local primary = towerModel.PrimaryPart
	if not primary then return end

	local sound = Instance.new("Sound")
	sound.SoundId            = "rbxassetid://9120386436" -- troque pelo ID desejado
	sound.Volume             = 0.35
	sound.RollOffMaxDistance = 50
	sound.Parent             = primary
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 2)
end

-- ── Range indicator ────────────────────────────────────────────────────────

function TowerController:hideRange()
	if rangeIndicator then
		rangeIndicator:Destroy()
		rangeIndicator = nil
	end
end

local function showRange(model: Model)
	TowerController:hideRange()

	local template = ReplicatedStorage:FindFirstChild("RangeIndicator")
	if not template then return end

	local nameVal   = model:FindFirstChild("TowerName")
	local lvlVal    = model:FindFirstChild("Level")
	local towerName = nameVal and nameVal.Value or model.Name
	local level     = lvlVal  and lvlVal.Value  or 1

	local data  = TowerStats[towerName]
	local stats = data and data.Levels and data.Levels[level]
	local range = stats and stats.Range or 0
	if range <= 0 then return end

	rangeIndicator             = template:Clone()
	rangeIndicator.Size        = Vector3.new(0.5, range * 2, range * 2)
	rangeIndicator.Anchored    = true
	rangeIndicator.CanCollide  = false
	rangeIndicator.CanQuery    = false

	local pivot = model:GetPivot()
	rangeIndicator.CFrame = CFrame.new(pivot.Position.X, pivot.Position.Y + 0.25, pivot.Position.Z)
		* CFrame.Angles(0, 0, math.rad(90))
	rangeIndicator.Parent = Workspace
end

-- ── Seleção de torre ───────────────────────────────────────────────────────

local function deselect()
	if selectedBox then
		selectedBox:Destroy()
		selectedBox  = nil
	end
	selectedTower = nil
	TowerController:hideRange()
	UIController:hideTowerInfo()
end

local function selectTower(tower)
	if selectedTower == tower then
		deselect()
		return
	end

	deselect()
	selectedTower = tower

	selectedBox                     = Instance.new("SelectionBox")
	selectedBox.Color3              = Color3.fromRGB(255, 220, 0)
	selectedBox.LineThickness       = 0.06
	selectedBox.SurfaceTransparency = 0.8
	selectedBox.SurfaceColor3       = Color3.fromRGB(255, 220, 0)
	selectedBox.Adornee             = tower
	selectedBox.Parent              = Workspace

	showRange(tower)
	UIController:showTowerInfo(tower)
end

-- ── Init ───────────────────────────────────────────────────────────────────

function TowerController:init()
	for _, tower in ipairs(CollectionService:GetTagged(TOWER_TAG)) do
		task.spawn(HealthBarUtil.attach, tower, TOWER_BAR_CONFIG)
	end

	CollectionService:GetInstanceAddedSignal(TOWER_TAG):Connect(function(tower)
		task.spawn(HealthBarUtil.attach, tower, TOWER_BAR_CONFIG)
	end)

	CollectionService:GetInstanceRemovedSignal(TOWER_TAG):Connect(function(tower)
		if selectedTower == tower then deselect() end
		towerTargets[tower] = nil
	end)

	-- Feedback visual: laser + som ao atacar
	Remotes.TowerAttacked.OnClientEvent:Connect(function(towerModel, enemyModel, _towerName)
		if not towerModel or not towerModel.Parent then return end
		if not enemyModel or not enemyModel.Parent then return end
		towerTargets[towerModel] = enemyModel
		spawnLaser(towerModel, enemyModel)
		playAttackSound(towerModel)
	end)

	-- Rotação suave das torres em direção ao alvo cosmético
	RunService.RenderStepped:Connect(function(dt)
		for towerModel, enemyModel in pairs(towerTargets) do
			-- Limpa referências de objetos destruídos
			if not towerModel.Parent or not enemyModel.Parent then
				towerTargets[towerModel] = nil
				continue
			end

			local towerPrimary = towerModel.PrimaryPart
			local enemyPrimary = enemyModel.PrimaryPart
			if not towerPrimary or not enemyPrimary then continue end

			local towerPos   = towerPrimary.Position
			local enemyPos   = enemyPrimary.Position
			-- Somente eixo Y: evita a torre inclinar se o inimigo estiver mais baixo
			local lookTarget = Vector3.new(enemyPos.X, towerPos.Y, enemyPos.Z)
			if (lookTarget - towerPos).Magnitude < 0.1 then continue end

			local turret = towerModel:FindFirstChild("Turret") or towerModel:FindFirstChild("Top")
			if turret and turret:IsA("BasePart") then
				-- Gira só a subpart da torre
				local tp = turret.Position
				turret.CFrame = turret.CFrame:Lerp(
					CFrame.new(tp, Vector3.new(enemyPos.X, tp.Y, enemyPos.Z)),
					math.min(1, dt * 12)
				)
			else
				-- Gira o modelo inteiro (apenas rotação Y)
				local currentCF = towerModel:GetPivot()
				local targetCF  = CFrame.new(currentCF.Position, lookTarget)
				towerModel:PivotTo(currentCF:Lerp(targetCF, math.min(1, dt * 12)))
			end
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if PlacementController:isBuildModeActive() then return end

		local target = mouse.Target
		if not target then deselect(); return end

		local model = target
		while model and not model:IsA("Model") do
			model = model.Parent
		end

		if model and CollectionService:HasTag(model, TOWER_TAG) then
			selectTower(model)
		else
			deselect()
		end
	end)
end

return TowerController
