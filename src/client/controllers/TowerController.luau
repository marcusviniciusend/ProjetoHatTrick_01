local CollectionService = game:GetService("CollectionService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")

local UIController        = require(script.Parent.UIController)
local PlacementController = require(script.Parent.PlacementController)
local TowerStats          = require(ReplicatedStorage.Shared.configs.TowerStats)
local HealthBarUtil       = require(ReplicatedStorage.Shared.utils.HealthBarUtil)

local TOWER_TAG = "Tower"

local TowerController = {}

local player         = Players.LocalPlayer
local mouse          = player:GetMouse()
local selectedBox    = nil
local selectedTower  = nil
local rangeIndicator = nil

local TOWER_BAR_CONFIG = {
	studsOffset = Vector3.new(0, 4, 0),
	maxDistance = 60,
	showLevel   = true,
}

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

	rangeIndicator          = template:Clone()
	rangeIndicator.Size     = Vector3.new(0.5, range * 2, range * 2)
	rangeIndicator.Anchored    = true
	rangeIndicator.CanCollide  = false
	rangeIndicator.CanQuery    = false

	local pivot = model:GetPivot()
	rangeIndicator.CFrame = CFrame.new(pivot.Position.X, pivot.Position.Y + 0.25, pivot.Position.Z)
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
