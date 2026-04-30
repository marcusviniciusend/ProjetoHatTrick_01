local HealthBarUtil = {}

local function getBarColor(pct)
	if pct > 0.6 then
		return Color3.fromRGB(0, 200, 60)
	elseif pct > 0.3 then
		return Color3.fromRGB(255, 165, 0)
	else
		return Color3.fromRGB(220, 40, 40)
	end
end

--[[
	Cria e acopla uma barra de HP (BillboardGui) ao PrimaryPart da entidade.

	config:
	  studsOffset  Vector3   posição do billboard acima da entidade (default: 0, 3, 0)
	  maxDistance  number    distância máxima de visibilidade (default: 80)
	  showLevel    boolean   se true, exibe label "Lv.X" e aguarda o IntValue "Level"
]]
function HealthBarUtil.attach(entity: Model, config)
	config = config or {}

	local primary   = entity.PrimaryPart
	local currentHP = entity:WaitForChild("CurrentHP", 5)
	local maxHP     = entity:WaitForChild("MaxHP",     5)

	if not (primary and currentHP and maxHP) then return end
	if maxHP.Value <= 0 then return end

	local levelVal = config.showLevel and entity:WaitForChild("Level", 5) or nil
	local bbHeight = levelVal and 14 or 8

	local billboard          = Instance.new("BillboardGui")
	billboard.Name           = "HealthBar"
	billboard.Size           = UDim2.new(0, 80, 0, bbHeight)
	billboard.StudsOffset    = config.studsOffset or Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop    = false
	billboard.MaxDistance    = config.maxDistance or 80
	billboard.ResetOnSpawn   = false
	billboard.Parent         = primary

	local bg              = Instance.new("Frame")
	bg.Size               = levelVal and UDim2.new(1, 0, 0, 8) or UDim2.fromScale(1, 1)
	bg.BackgroundColor3   = Color3.fromRGB(25, 25, 25)
	bg.BorderSizePixel    = 0
	bg.Parent             = billboard

	local bar             = Instance.new("Frame")
	bar.Name              = "Bar"
	bar.AnchorPoint       = Vector2.new(0, 0)
	bar.Size              = UDim2.fromScale(1, 1)
	bar.BorderSizePixel   = 0
	bar.Parent            = bg

	if levelVal then
		local lvlLabel           = Instance.new("TextLabel")
		lvlLabel.Name            = "LevelLabel"
		lvlLabel.Size            = UDim2.new(1, 0, 0, 6)
		lvlLabel.Position        = UDim2.new(0, 0, -1, 0)
		lvlLabel.BackgroundTransparency = 1
		lvlLabel.TextColor3      = Color3.fromRGB(255, 220, 50)
		lvlLabel.TextScaled      = true
		lvlLabel.Font            = Enum.Font.GothamBold
		lvlLabel.Parent          = billboard

		local function updateLevel()
			lvlLabel.Text = ("Lv.%d"):format(levelVal.Value)
		end
		levelVal:GetPropertyChangedSignal("Value"):Connect(updateLevel)
		updateLevel()
	end

	local function updateHP()
		local pct            = math.clamp(currentHP.Value / maxHP.Value, 0, 1)
		bar.Size             = UDim2.fromScale(pct, 1)
		bar.BackgroundColor3 = getBarColor(pct)
		billboard.Enabled    = pct < 1
	end

	currentHP:GetPropertyChangedSignal("Value"):Connect(updateHP)
	updateHP()
end

return HealthBarUtil
