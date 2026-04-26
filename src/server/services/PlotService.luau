local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local PlotService = {}

local availablePlots = {}          -- { BasePart | Model }
local plotOwners     = {}          -- { [plot] = userId }

-- ── Setup ──────────────────────────────────────────────────────────────────

function PlotService:init()
	local map = Workspace:WaitForChild("Map", 10)
	if not map then
		warn("[PlotService] Workspace.Map não encontrado — crie a pasta no Studio")
		return
	end

	local plotsFolder = map:WaitForChild("Plots", 10)
	if not plotsFolder then
		warn("[PlotService] Workspace.Map.Plots não encontrado — crie a pasta no Studio")
		return
	end

	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if plot:IsA("BasePart") or plot:IsA("Model") then
			table.insert(availablePlots, plot)
		end
	end

	print(("[PlotService] %d plot(s) carregado(s)"):format(#availablePlots))

	Players.PlayerAdded:Connect(function(player)
		self:claimPlot(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:releasePlot(player)
	end)

	-- Cobre players já conectados (teste em Studio com servidor local)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function() self:claimPlot(player) end)
	end
end

-- ── API pública ────────────────────────────────────────────────────────────

function PlotService:claimPlot(player)
	for _, plot in ipairs(availablePlots) do
		if not plotOwners[plot] then
			plotOwners[plot] = player.UserId
			print(("[PlotService] '%s' recebeu o plot '%s'"):format(player.Name, plot.Name))
			return plot
		end
	end
	warn(("[PlotService] Sem plots disponíveis para '%s'"):format(player.Name))
	return nil
end

function PlotService:releasePlot(player)
	for plot, userId in pairs(plotOwners) do
		if userId == player.UserId then
			plotOwners[plot] = nil
			print(("[PlotService] Plot de '%s' liberado"):format(player.Name))
			return
		end
	end
end

function PlotService:getPlot(player)
	for plot, userId in pairs(plotOwners) do
		if userId == player.UserId then
			return plot
		end
	end
	return nil
end

-- Verifica se 'position' está dentro da área do plot do player
function PlotService:isInsidePlot(player, position)
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

	local local_pos = cf:PointToObjectSpace(position)
	local half      = size / 2
	return math.abs(local_pos.X) <= half.X
		and math.abs(local_pos.Z) <= half.Z
end

return PlotService
