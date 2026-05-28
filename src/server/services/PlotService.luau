local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").network.Remotes)

local PlotService = {}

local availablePlots = {}   -- { Model | BasePart } ordenados por nome
local plotOwners     = {}   -- { [plot] = userId }

-- ── Helpers internos ───────────────────────────────────────────────────────

-- Retorna o CFrame de spawn do plot: SpawnPoint > BoundingBox center > plot CFrame
local function getPlotSpawnCFrame(plot): CFrame
	local spawnPart = plot:FindFirstChild("SpawnPoint", true)
	if spawnPart and spawnPart:IsA("BasePart") then
		return spawnPart.CFrame
	end
	if plot:IsA("Model") then
		local cf = plot:GetBoundingBox()
		return cf
	end
	if plot:IsA("BasePart") then
		return plot.CFrame
	end
	return CFrame.new(0, 0, 0)
end

-- Retorna uma BasePart adequada para ancorar o BillboardGui
local function getAdornee(plot): BasePart?
	if plot:IsA("BasePart") then return plot end
	local base = plot:FindFirstChild("Base")
	if base and base:IsA("BasePart") then return base end
	if plot:IsA("Model") and plot.PrimaryPart then return plot.PrimaryPart end
	for _, desc in ipairs(plot:GetDescendants()) do
		if desc:IsA("BasePart") then return desc :: BasePart end
	end
	return nil
end

local function setPlotLabel(plot, playerName: string)
	local adornee = getAdornee(plot)
	if not adornee then return end

	local existing = adornee:FindFirstChild("PlotOwnerGui")
	if existing then existing:Destroy() end

	local billboard  = Instance.new("BillboardGui")
	billboard.Name         = "PlotOwnerGui"
	billboard.Size         = UDim2.new(0, 220, 0, 50)
	billboard.StudsOffset  = Vector3.new(0, 8, 0)
	billboard.AlwaysOnTop  = false
	billboard.Parent       = adornee

	local label = Instance.new("TextLabel")
	label.Size                  = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text                  = "Terreno de " .. playerName
	label.TextColor3            = Color3.fromRGB(255, 220, 50)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3      = Color3.fromRGB(0, 0, 0)
	label.Font                  = Enum.Font.GothamBold
	label.TextScaled            = true
	label.Parent                = billboard
end

local function clearPlotLabel(plot)
	local adornee = getAdornee(plot)
	if not adornee then return end
	local gui = adornee:FindFirstChild("PlotOwnerGui")
	if gui then gui:Destroy() end
end

-- ── Setup ──────────────────────────────────────────────────────────────────

function PlotService:init()
	local map = Workspace:WaitForChild("Map", 10)
	if not map then
		warn("[PlotService] Workspace.Map não encontrado")
		return
	end

	local plotsFolder = map:WaitForChild("Plots", 10)
	if not plotsFolder then
		warn("[PlotService] Workspace.Map.Plots não encontrado")
		return
	end

	local collected = {}
	for _, child in ipairs(plotsFolder:GetChildren()) do
		if child:IsA("Model") or child:IsA("BasePart") then
			table.insert(collected, child)
		end
	end
	table.sort(collected, function(a, b) return a.Name < b.Name end)
	availablePlots = collected

	print(("[PlotService] %d plot(s) carregado(s)"):format(#availablePlots))

	Players.PlayerAdded:Connect(function(player)
		self:claimPlot(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:releasePlot(player)
	end)

	-- Cobre players já conectados (teste local no Studio)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function() self:claimPlot(player) end)
	end
end

-- ── API pública ────────────────────────────────────────────────────────────

function PlotService:claimPlot(player: Player)
	for _, plot in ipairs(availablePlots) do
		if not plotOwners[plot] then
			plotOwners[plot] = player.UserId
			print(("[PlotService] '%s' recebeu '%s'"):format(player.Name, plot.Name))
			Remotes.PlotAssigned:FireClient(player, plot)

			-- Teleporte: leva o personagem até o plot agora e a cada respawn
			local function teleportToPlot(character)
				local hrp = character:WaitForChild("HumanoidRootPart", 5)
				if not hrp then return end
				task.wait()  -- aguarda o Roblox finalizar o spawn padrão antes de mover
				if hrp.Parent then
					hrp.CFrame = getPlotSpawnCFrame(plot) + Vector3.new(0, 5, 0)
				end
			end

			player.CharacterAdded:Connect(teleportToPlot)
			if player.Character then
				teleportToPlot(player.Character)
			end

			setPlotLabel(plot, player.Name)
			return plot
		end
	end
	warn(("[PlotService] Nenhum plot livre para '%s' — adicione mais modelos em Map.Plots"):format(player.Name))
	return nil
end

function PlotService:releasePlot(player: Player)
	for plot, userId in pairs(plotOwners) do
		if userId == player.UserId then
			plotOwners[plot] = nil
			clearPlotLabel(plot)
			print(("[PlotService] Plot de '%s' liberado"):format(player.Name))
			return
		end
	end
end

function PlotService:getPlot(player: Player)
	for plot, userId in pairs(plotOwners) do
		if userId == player.UserId then
			return plot
		end
	end
	return nil
end

function PlotService:getOwnerUserId(plot)
	return plotOwners[plot]
end

function PlotService:getActivePlots()
	local plots = {}
	for plot in pairs(plotOwners) do
		table.insert(plots, plot)
	end
	return plots
end

function PlotService:isInsidePlot(player: Player, position: Vector3): boolean
	local plot = self:getPlot(player)
	if not plot then return false end

	local cf, size
	if plot:IsA("BasePart") then
		cf, size = plot.CFrame, plot.Size
	elseif plot:IsA("Model") then
		cf, size = plot:GetBoundingBox()
	else
		return false
	end

	local localPos = cf:PointToObjectSpace(position)
	local half     = size / 2
	return math.abs(localPos.X) <= half.X
		and math.abs(localPos.Z) <= half.Z
end

return PlotService
