local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")

local LeaderboardService = {}

local TOP_COUNT        = 10
local REFRESH_INTERVAL = 60

-- DataStores criados de forma protegida: em Studio sem API habilitada,
-- GetDataStore pode falhar. Se falhar, o serviço opera sem persistência.
local waveStore = nil
local nameStore = nil
do
	local ok, err = pcall(function()
		waveStore = DataStoreService:GetOrderedDataStore("BestWave_v1")
		nameStore = DataStoreService:GetDataStore("PlayerNames_v1")
	end)
	if not ok then
		warn("[LeaderboardService] DataStore indisponível:", err)
		warn("[LeaderboardService] Para habilitar no Studio: Game Settings → Security → Enable Studio Access to API Services")
	end
end

-- ── Renderização ───────────────────────────────────────────────────────────

local function findBoard(): BasePart?
	local map   = Workspace:FindFirstChild("Map")
	local board = map and map:FindFirstChild("LeaderboardBoard")
	return (board and board:IsA("BasePart")) and board or nil
end

local function getOrCreateGui(board: BasePart)
	local existing = board:FindFirstChildOfClass("SurfaceGui")
	if existing then return existing end

	local gui           = Instance.new("SurfaceGui")
	gui.Name            = "LeaderboardGui"
	gui.Face            = Enum.NormalId.Front
	gui.PixelsPerStud   = 50
	gui.AlwaysOnTop     = false
	gui.Parent          = board
	return gui
end

local function buildRow(parent: Frame, rank: number, name: string, wave: number, yPos: number)
	local lbl               = Instance.new("TextLabel")
	lbl.Size                = UDim2.new(1, -16, 0, 40)
	lbl.Position            = UDim2.new(0, 8, 0, yPos)
	lbl.BackgroundTransparency = 1
	lbl.Font                = Enum.Font.GothamBold
	lbl.TextScaled          = true
	lbl.TextXAlignment      = Enum.TextXAlignment.Left
	lbl.TextColor3          = rank == 1
		and Color3.fromRGB(255, 215, 0)
		or  Color3.fromRGB(220, 220, 220)
	lbl.Text                = ("#%d  %s  —  Wave %d"):format(rank, name, wave)
	lbl.Parent              = parent
end

local function renderEntries(entries: { { name: string, wave: number } })
	local board = findBoard()
	if not board then return end

	local gui = getOrCreateGui(board)
	for _, child in ipairs(gui:GetChildren()) do child:Destroy() end

	local bg                    = Instance.new("Frame")
	bg.Size                     = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3         = Color3.fromRGB(15, 15, 30)
	bg.BackgroundTransparency   = 0.3
	bg.BorderSizePixel          = 0
	bg.Parent                   = gui

	local title                 = Instance.new("TextLabel")
	title.Size                  = UDim2.new(1, 0, 0, 58)
	title.BackgroundTransparency = 1
	title.Font                  = Enum.Font.GothamBold
	title.TextScaled            = true
	title.TextColor3            = Color3.fromRGB(255, 215, 0)
	title.Text                  = "MELHORES ONDAS"
	title.Parent                = bg

	if #entries == 0 then
		local empty               = Instance.new("TextLabel")
		empty.Size                = UDim2.new(1, 0, 0, 40)
		empty.Position            = UDim2.new(0, 0, 0, 68)
		empty.BackgroundTransparency = 1
		empty.Font                = Enum.Font.Gotham
		empty.TextScaled          = true
		empty.TextColor3          = Color3.fromRGB(140, 140, 140)
		empty.Text                = "Nenhum recorde ainda"
		empty.Parent              = bg
		return
	end

	for i, entry in ipairs(entries) do
		buildRow(bg, i, entry.name, entry.wave, 60 + (i - 1) * 42)
	end
end

-- ── Refresh ────────────────────────────────────────────────────────────────

local function refresh()
	if not waveStore then
		renderEntries({})
		return
	end

	task.spawn(function()
		local okPages, pages = pcall(function()
			return waveStore:GetSortedAsync(false, TOP_COUNT)
		end)
		if not okPages then
			warn("[LeaderboardService] GetSortedAsync falhou:", pages)
			return
		end

		local okPage, page = pcall(function() return pages:GetCurrentPage() end)
		if not okPage then
			warn("[LeaderboardService] GetCurrentPage falhou:", page)
			return
		end

		local entries = {}
		for _, entry in ipairs(page) do
			local wave   = entry.value
			local okN, storedName = pcall(function()
				return nameStore:GetAsync(entry.key)
			end)
			local name = (okN and storedName) or ("[" .. entry.key .. "]")
			table.insert(entries, { name = name, wave = wave })
		end

		renderEntries(entries)
		print(("[LeaderboardService] Board atualizado: %d entrada(s)"):format(#entries))
	end)
end

-- ── API pública ────────────────────────────────────────────────────────────

function LeaderboardService:recordWave(player: Player, wave: number)
	if wave <= 0 or not waveStore then return end
	local userId = tostring(player.UserId)

	task.spawn(function()
		pcall(function() nameStore:SetAsync(userId, player.Name) end)

		local okGet, current = pcall(function() return waveStore:GetAsync(userId) end)
		if okGet and (not current or wave > current) then
			local okSet, err = pcall(function() waveStore:SetAsync(userId, wave) end)
			if not okSet then warn("[LeaderboardService] SetAsync falhou:", err) end
		end
	end)
end

function LeaderboardService:init()
	Players.PlayerAdded:Connect(function(player)
		if not nameStore then return end
		task.spawn(function()
			pcall(function() nameStore:SetAsync(tostring(player.UserId), player.Name) end)
		end)
	end)

	refresh()
	task.spawn(function()
		while true do
			task.wait(REFRESH_INTERVAL)
			refresh()
		end
	end)

	print("[LeaderboardService] Pronto.")
end

return LeaderboardService
