local CollectionService = game:GetService("CollectionService")
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")

local UIController        = require(script.Parent.UIController)
local PlacementController = require(script.Parent.PlacementController)

local TOWER_TAG = "Tower"

local TowerController = {}

local player      = Players.LocalPlayer
local mouse       = player:GetMouse()
local selectedBox = nil  -- SelectionBox atual
local selectedTower = nil

-- ── Cores da barra de HP ───────────────────────────────────────────────────

local function getBarColor(pct)
	if pct > 0.6 then
		return Color3.fromRGB(0, 200, 60)
	elseif pct > 0.3 then
		return Color3.fromRGB(255, 165, 0)
	else
		return Color3.fromRGB(220, 40, 40)
	end
end

-- ── HP Bar + Level label ───────────────────────────────────────────────────

local function attachHealthBar(tower)
	local primary   = tower.PrimaryPart
	local currentHP = tower:WaitForChild("CurrentHP", 5)
	local maxHP     = tower:WaitForChild("MaxHP",     5)
	local levelVal  = tower:WaitForChild("Level",     5)

	if not (primary and currentHP and maxHP) then return end
	if maxHP.Value <= 0 then return end

	local billboard          = Instance.new("BillboardGui")
	billboard.Name           = "HealthBar"
	billboard.Size           = UDim2.new(0, 80, 0, 14)
	billboard.StudsOffset    = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop    = false
	billboard.MaxDistance    = 60
	billboard.ResetOnSpawn   = false
	billboard.Parent         = primary

	-- Fundo escuro
	local bg              = Instance.new("Frame")
	bg.Size               = UDim2.new(1, 0, 0, 8)
	bg.BackgroundColor3   = Color3.fromRGB(25, 25, 25)
	bg.BorderSizePixel    = 0
	bg.Parent             = billboard

	-- Barra de HP
	local bar             = Instance.new("Frame")
	bar.Name              = "Bar"
	bar.AnchorPoint       = Vector2.new(0, 0)
	bar.Size              = UDim2.fromScale(1, 1)
	bar.BorderSizePixel   = 0
	bar.Parent            = bg

	-- Label de nível (acima da barra)
	local lvlLabel           = Instance.new("TextLabel")
	lvlLabel.Name            = "LevelLabel"
	lvlLabel.Size            = UDim2.new(1, 0, 0, 6)
	lvlLabel.Position        = UDim2.new(0, 0, -1, 0)
	lvlLabel.BackgroundTransparency = 1
	lvlLabel.TextColor3      = Color3.fromRGB(255, 220, 50)
	lvlLabel.TextScaled      = true
	lvlLabel.Font            = Enum.Font.GothamBold
	lvlLabel.Parent          = billboard

	local function updateHP()
		local pct            = math.clamp(currentHP.Value / maxHP.Value, 0, 1)
		bar.Size             = UDim2.fromScale(pct, 1)
		bar.BackgroundColor3 = getBarColor(pct)
		billboard.Enabled    = pct < 1
	end

	local function updateLevel()
		lvlLabel.Text = ("Lv.%d"):format(levelVal and levelVal.Value or 1)
	end

	currentHP:GetPropertyChangedSignal("Value"):Connect(updateHP)
	if levelVal then
		levelVal:GetPropertyChangedSignal("Value"):Connect(updateLevel)
	end

	updateHP()
	updateLevel()
end

-- ── Seleção de torre ───────────────────────────────────────────────────────

local function deselect()
	if selectedBox then
		selectedBox:Destroy()
		selectedBox  = nil
	end
	selectedTower = nil
	UIController:hideTowerInfo()
end

local function selectTower(tower)
	if selectedTower == tower then
		deselect()
		return
	end

	deselect()
	selectedTower = tower

	selectedBox            = Instance.new("SelectionBox")
	selectedBox.Color3     = Color3.fromRGB(255, 220, 0)
	selectedBox.LineThickness = 0.06
	selectedBox.SurfaceTransparency = 0.8
	selectedBox.SurfaceColor3 = Color3.fromRGB(255, 220, 0)
	selectedBox.Adornee    = tower
	selectedBox.Parent     = workspace

	UIController:showTowerInfo(tower)
end

-- ── Init ───────────────────────────────────────────────────────────────────

function TowerController:init()
	-- HP bars em torres já existentes
	for _, tower in ipairs(CollectionService:GetTagged(TOWER_TAG)) do
		task.spawn(attachHealthBar, tower)
	end
	CollectionService:GetInstanceAddedSignal(TOWER_TAG):Connect(function(tower)
		task.spawn(attachHealthBar, tower)
	end)

	-- Deseleciona quando a torre é removida
	CollectionService:GetInstanceRemovedSignal(TOWER_TAG):Connect(function(tower)
		if selectedTower == tower then deselect() end
	end)

	-- Click para selecionar torre (só fora do modo construção/delete)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if PlacementController:isBuildModeActive() then return end

		local target = mouse.Target
		if not target then deselect(); return end

		-- Sobe na hierarquia para encontrar o Model com a tag Tower
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
