local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService      = game:GetService("SoundService")
local Workspace         = game:GetService("Workspace")

local Remotes    = require(ReplicatedStorage.Shared.network.Remotes)
local TowerStats = require(ReplicatedStorage.Shared.configs.TowerStats)

local SellController = {}

local player = Players.LocalPlayer
local gui    = player:WaitForChild("PlayerGui")

-- ── Estado ─────────────────────────────────────────────────────────────────

local isOpen    = false
local panel     = nil   -- Frame principal
local listFrame = nil   -- ScrollingFrame dos itens
local emptyLbl  = nil   -- Sobreposto ao listFrame quando inventário está vazio

-- { [towerName] = { count, frame, countLbl, sellBtn } }
local uiRows: { [string]: { count: number, frame: Frame, countLbl: TextLabel, sellBtn: TextButton } } = {}

-- ── Helpers de construção de UI ────────────────────────────────────────────

local function corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
end

local function textLabel(parent: Instance, props: { [string]: any }): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Font       = Enum.Font.Gotham
	lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
	lbl.TextScaled = false
	for k, v in pairs(props) do
		(lbl :: any)[k] = v
	end
	lbl.Parent = parent
	return lbl
end

-- ── Construção do painel (chamado uma vez no init) ─────────────────────────

local function buildUI()
	local existing = gui:FindFirstChild("SellGui")
	if existing then existing:Destroy() end

	local screenGui          = Instance.new("ScreenGui")
	screenGui.Name           = "SellGui"
	screenGui.ResetOnSpawn   = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent         = gui

	-- Painel principal
	panel                   = Instance.new("Frame")
	panel.Name              = "Panel"
	panel.Size              = UDim2.new(0, 480, 0, 440)
	panel.Position          = UDim2.new(0.5, -240, 0.5, -220)
	panel.BackgroundColor3  = Color3.fromRGB(18, 20, 28)
	panel.BorderSizePixel   = 0
	panel.Visible           = false
	panel.Parent            = screenGui
	corner(panel, 14)

	local stroke         = Instance.new("UIStroke")
	stroke.Color         = Color3.fromRGB(180, 140, 40)
	stroke.Thickness     = 1.5
	stroke.Parent        = panel

	-- Cabeçalho
	local header         = Instance.new("Frame")
	header.Name          = "Header"
	header.Size          = UDim2.new(1, 0, 0, 62)
	header.BackgroundColor3 = Color3.fromRGB(26, 28, 38)
	header.BorderSizePixel  = 0
	header.ZIndex        = 2
	header.Parent        = panel
	corner(header, 14)

	-- Cobre os cantos inferiores do header para parecer reto em baixo
	local fix            = Instance.new("Frame")
	fix.Size             = UDim2.new(1, 0, 0.5, 0)
	fix.Position         = UDim2.new(0, 0, 0.5, 0)
	fix.BackgroundColor3 = Color3.fromRGB(26, 28, 38)
	fix.BorderSizePixel  = 0
	fix.ZIndex           = 2
	fix.Parent           = header

	textLabel(header, {
		Name           = "Title",
		Size           = UDim2.new(1, -60, 0, 28),
		Position       = UDim2.new(0, 16, 0, 10),
		Text           = "Sucateiro",
		TextSize       = 22,
		Font           = Enum.Font.GothamBold,
		TextColor3     = Color3.fromRGB(255, 220, 50),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex         = 3,
	})

	textLabel(header, {
		Name           = "Sub",
		Size           = UDim2.new(1, -60, 0, 16),
		Position       = UDim2.new(0, 16, 0, 38),
		Text           = "Venda torres do seu inventario",
		TextSize       = 12,
		TextColor3     = Color3.fromRGB(140, 140, 160),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex         = 3,
	})

	-- Botão fechar
	local closeBtn              = Instance.new("TextButton")
	closeBtn.Name               = "CloseBtn"
	closeBtn.Size               = UDim2.new(0, 36, 0, 36)
	closeBtn.Position           = UDim2.new(1, -48, 0, 13)
	closeBtn.BackgroundColor3   = Color3.fromRGB(200, 55, 55)
	closeBtn.Text               = "X"
	closeBtn.TextColor3         = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize           = 15
	closeBtn.Font               = Enum.Font.GothamBold
	closeBtn.BorderSizePixel    = 0
	closeBtn.ZIndex             = 4
	closeBtn.Parent             = panel
	corner(closeBtn, 8)
	closeBtn.Activated:Connect(function()
		SellController:close()
	end)

	-- ScrollingFrame dos itens
	listFrame                        = Instance.new("ScrollingFrame")
	listFrame.Name                   = "ItemList"
	listFrame.Size                   = UDim2.new(1, -24, 1, -80)
	listFrame.Position               = UDim2.new(0, 12, 0, 70)
	listFrame.BackgroundTransparency = 1
	listFrame.BorderSizePixel        = 0
	listFrame.ScrollBarThickness     = 4
	listFrame.ScrollBarImageColor3   = Color3.fromRGB(180, 140, 40)
	listFrame.CanvasSize             = UDim2.new(0, 0, 0, 0)
	listFrame.AutomaticCanvasSize    = Enum.AutomaticSize.Y
	listFrame.Parent                 = panel

	local listLayout         = Instance.new("UIListLayout")
	listLayout.Padding       = UDim.new(0, 6)
	listLayout.SortOrder     = Enum.SortOrder.Name
	listLayout.Parent        = listFrame

	-- Label sobreposto de inventário vazio (parent no panel, não no listFrame)
	emptyLbl                        = Instance.new("TextLabel")
	emptyLbl.Name                   = "EmptyLabel"
	emptyLbl.Size                   = UDim2.new(1, -24, 1, -80)
	emptyLbl.Position               = UDim2.new(0, 12, 0, 70)
	emptyLbl.BackgroundTransparency = 1
	emptyLbl.Text                   = "Inventario vazio"
	emptyLbl.TextColor3             = Color3.fromRGB(120, 120, 140)
	emptyLbl.TextSize               = 16
	emptyLbl.Font                   = Enum.Font.Gotham
	emptyLbl.Visible                = false
	emptyLbl.Parent                 = panel
end

-- ── Linha de item ──────────────────────────────────────────────────────────

local function buildRow(name: string, count: number, sellValue: number)
	local row               = Instance.new("Frame")
	row.Name                = "Row_" .. name
	row.Size                = UDim2.new(1, 0, 0, 58)
	row.BackgroundColor3    = Color3.fromRGB(28, 30, 42)
	row.BorderSizePixel     = 0
	row.Parent              = listFrame
	corner(row, 8)

	textLabel(row, {
		Name           = "NameLbl",
		Size           = UDim2.new(0.5, 0, 0, 22),
		Position       = UDim2.new(0, 14, 0, 8),
		Text           = name,
		TextSize       = 14,
		Font           = Enum.Font.GothamBold,
		TextColor3     = Color3.fromRGB(235, 235, 235),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	textLabel(row, {
		Name           = "PriceLbl",
		Size           = UDim2.new(0.5, 0, 0, 16),
		Position       = UDim2.new(0, 14, 0, 32),
		Text           = "Vender por $" .. tostring(sellValue),
		TextSize       = 12,
		TextColor3     = Color3.fromRGB(90, 210, 90),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- Badge de quantidade
	local countLbl              = Instance.new("TextLabel")
	countLbl.Name               = "CountLbl"
	countLbl.Size               = UDim2.new(0, 38, 0, 24)
	countLbl.Position           = UDim2.new(0.56, 0, 0.5, -12)
	countLbl.BackgroundColor3   = Color3.fromRGB(255, 180, 30)
	countLbl.Text               = "x" .. count
	countLbl.TextColor3         = Color3.fromRGB(20, 20, 20)
	countLbl.TextSize           = 13
	countLbl.Font               = Enum.Font.GothamBold
	countLbl.BorderSizePixel    = 0
	countLbl.Parent             = row
	corner(countLbl, 6)

	-- Botão Vender
	local sellBtn               = Instance.new("TextButton")
	sellBtn.Name                = "SellBtn"
	sellBtn.Size                = UDim2.new(0, 90, 0, 34)
	sellBtn.Position            = UDim2.new(1, -104, 0.5, -17)
	sellBtn.BackgroundColor3    = Color3.fromRGB(210, 70, 45)
	sellBtn.Text                = "VENDER"
	sellBtn.TextColor3          = Color3.fromRGB(255, 255, 255)
	sellBtn.TextSize            = 13
	sellBtn.Font                = Enum.Font.GothamBold
	sellBtn.BorderSizePixel     = 0
	sellBtn.Parent              = row
	corner(sellBtn, 8)

	uiRows[name] = {
		count    = count,
		frame    = row,
		countLbl = countLbl,
		sellBtn  = sellBtn,
	}

	sellBtn.Activated:Connect(function()
		local rowData = uiRows[name]
		if not rowData or rowData.count <= 0 then return end
		sellBtn.Active = false

		task.spawn(function()
			local success: boolean = Remotes.RequestSellItem:InvokeServer("Tower", name)

			if success then
				-- Ca-ching!
				local sound      = Instance.new("Sound")
				sound.SoundId    = "rbxassetid://5869888344"  -- troque pelo ID desejado
				sound.Volume     = 0.6
				sound.Parent     = SoundService
				sound:Play()
				game:GetService("Debris"):AddItem(sound, 3)

				rowData.count -= 1
				if rowData.count <= 0 then
					row:Destroy()
					uiRows[name] = nil
					if next(uiRows) == nil and emptyLbl then
						emptyLbl.Visible = true
					end
				else
					countLbl.Text  = "x" .. rowData.count
					sellBtn.Active = true
				end
			else
				sellBtn.Active = true
			end
		end)
	end)
end

-- ── Abrir / Fechar ─────────────────────────────────────────────────────────

function SellController:open()
	if isOpen or not panel then return end
	isOpen = true

	-- Limpa linhas de sessão anterior
	for _, rowData in pairs(uiRows) do
		if rowData.frame and rowData.frame.Parent then
			rowData.frame:Destroy()
		end
	end
	uiRows = {}

	-- Busca inventário no servidor (GetInventory retorna {string})
	local items: { string } = Remotes.GetInventory:InvokeServer()

	-- Agrupa por nome de torre
	local counts: { [string]: number } = {}
	for _, itemName in ipairs(items) do
		counts[itemName] = (counts[itemName] or 0) + 1
	end

	local hasTowers = false
	for itemName, count in pairs(counts) do
		local data = TowerStats[itemName]
		if data then
			local sellValue = math.floor(data.BasePrice * 0.5)
			buildRow(itemName, count, sellValue)
			hasTowers = true
		end
	end

	emptyLbl.Visible = not hasTowers
	panel.Visible    = true
end

function SellController:close()
	isOpen = false
	if panel then panel.Visible = false end
end

-- ── Descoberta do NPC ──────────────────────────────────────────────────────

local function setupNPC(): boolean
	-- Busca recursiva: o NPC pode estar dentro de Map ou outra pasta
	local npc = Workspace:FindFirstChild("SellNPC", true)
	if not npc then return false end

	local prompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then
		warn("[SellController] SellNPC encontrado mas sem ProximityPrompt")
		return false
	end

	prompt.Triggered:Connect(function()
		SellController:open()
	end)

	print("[SellController] NPC conectado.")
	return true
end

-- ── Init ───────────────────────────────────────────────────────────────────

function SellController:init()
	buildUI()

	if not setupNPC() then
		-- NPC pode não ter carregado ainda: aguarda via DescendantAdded
		local conn: RBXScriptConnection
		conn = Workspace.DescendantAdded:Connect(function(desc)
			if desc.Name == "SellNPC" then
				task.wait()  -- aguarda filhos (ProximityPrompt) serem adicionados
				if setupNPC() then
					conn:Disconnect()
				end
			end
		end)
	end
end

return SellController
