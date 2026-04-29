local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").network.Remotes)

local PlotService = {}

local availablePlots = {}   -- { Model | BasePart } ordenados por nome
local plotOwners     = {}   -- { [plot] = userId }

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

	-- Coleta plots e ordena por nome (Plot1, Plot2, …) para atribuição consistente
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

-- Atribui o primeiro plot livre ao player e notifica o cliente.
function PlotService:claimPlot(player: Player)
	for _, plot in ipairs(availablePlots) do
		if not plotOwners[plot] then
			plotOwners[plot] = player.UserId
			print(("[PlotService] '%s' recebeu '%s'"):format(player.Name, plot.Name))
			Remotes.PlotAssigned:FireClient(player, plot)
			return plot
		end
	end
	warn(("[PlotService] Nenhum plot livre para '%s' — adicione mais modelos em Map.Plots"):format(player.Name))
	return nil
end

-- Libera o plot do player que saiu.
function PlotService:releasePlot(player: Player)
	for plot, userId in pairs(plotOwners) do
		if userId == player.UserId then
			plotOwners[plot] = nil
			print(("[PlotService] Plot de '%s' liberado"):format(player.Name))
			return
		end
	end
end

-- Retorna o plot atribuído ao player, ou nil.
function PlotService:getPlot(player: Player)
	for plot, userId in pairs(plotOwners) do
		if userId == player.UserId then
			return plot
		end
	end
	return nil
end

-- Retorna lista de todos os plots que têm um player atribuído.
function PlotService:getActivePlots()
	local plots = {}
	for plot in pairs(plotOwners) do
		table.insert(plots, plot)
	end
	return plots
end

-- Verifica se 'position' está dentro da bounding box XZ do plot do player.
-- Usado pelo PlacementService como trava de segurança server-side.
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
