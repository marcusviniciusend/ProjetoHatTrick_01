local CollectionService = game:GetService("CollectionService")

local TOWER_TAG = "Tower"

local TowerController = {}

local function getBarColor(pct)
	if pct > 0.6 then
		return Color3.fromRGB(0, 200, 60)
	elseif pct > 0.3 then
		return Color3.fromRGB(255, 165, 0)
	else
		return Color3.fromRGB(220, 40, 40)
	end
end

local function attachHealthBar(tower)
	local primary   = tower.PrimaryPart
	local currentHP = tower:WaitForChild("CurrentHP", 5)
	local maxHP     = tower:WaitForChild("MaxHP",     5)

	if not (primary and currentHP and maxHP) then return end
	if maxHP.Value <= 0 then return end

	local billboard          = Instance.new("BillboardGui")
	billboard.Name           = "HealthBar"
	billboard.Size           = UDim2.new(0, 80, 0, 8)
	billboard.StudsOffset    = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop    = false
	billboard.MaxDistance    = 60
	billboard.ResetOnSpawn   = false
	billboard.Parent         = primary

	local bg                 = Instance.new("Frame")
	bg.Size                  = UDim2.fromScale(1, 1)
	bg.BackgroundColor3      = Color3.fromRGB(25, 25, 25)
	bg.BorderSizePixel       = 0
	bg.Parent                = billboard

	local bar                = Instance.new("Frame")
	bar.Name                 = "Bar"
	bar.AnchorPoint          = Vector2.new(0, 0)
	bar.Size                 = UDim2.fromScale(1, 1)
	bar.BorderSizePixel      = 0
	bar.Parent               = bg

	local function update()
		local pct = math.clamp(currentHP.Value / maxHP.Value, 0, 1)
		bar.Size             = UDim2.fromScale(pct, 1)
		bar.BackgroundColor3 = getBarColor(pct)
		billboard.Enabled    = pct < 1
	end

	currentHP:GetPropertyChangedSignal("Value"):Connect(update)
	update()
end

function TowerController:init()
	for _, tower in ipairs(CollectionService:GetTagged(TOWER_TAG)) do
		task.spawn(attachHealthBar, tower)
	end

	CollectionService:GetInstanceAddedSignal(TOWER_TAG):Connect(function(tower)
		task.spawn(attachHealthBar, tower)
	end)
end

return TowerController
