local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local Remotes    = require(ReplicatedStorage.Shared.network.Remotes)
local RarityData = require(ReplicatedStorage.Shared.configs.RarityData)
local StoreItems = require(ReplicatedStorage.Shared.configs.StoreItems)
local TowerStats = require(ReplicatedStorage.Shared.configs.TowerStats)

local StoreController = {}

local player  = Players.LocalPlayer
local gui     = player:WaitForChild("PlayerGui")
local towers  = ReplicatedStorage:WaitForChild("towers", 10)

local MAX_PEDESTAL_COUNT = 5
local GRAY               = Color3.fromRGB(110, 110, 110)
local PANEL_GREEN        = Color3.fromRGB(40, 160, 60)
local PANEL_GRAY         = Color3.fromRGB(70, 70, 80)
local RARITY_ORDER       = { "Comum", "Raro", "Lendario" }

-- ── Estado ─────────────────────────────────────────────────────────────────

local hotspot         = nil
local pedestals       = {}
local pedDisplays     = {}
local countdownThread = nil
local currentSlots    = {}  -- { [towerName] = slotData }

-- ── Referências da shop UI ──────────────────────────────────────────────────

local shopScreen  = nil
local timerLabel  = nil   -- inside shop panel
local clockLabel  = nil   -- world billboard on hotspot
local towerCards  = {}    -- { [towerName] = { frame, nameLbl, stockLbl, buyBtn, rarity } }

-- ── Helpers de instância ───────────────────────────────────────────────────

local function corner(parent, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = parent
end
local function stroke(parent, t, col)
	local s = Instance.new("UIStroke"); s.Thickness = t or 2
	s.Color = col or Color3.fromRGB(70, 70, 90); s.Parent = parent
end
local function label(parent, props): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	for k, v in pairs(props) do (l :: any)[k] = v end
	l.Parent = parent
	return l
end
local function button(parent, props): TextButton
	local b = Instance.new("TextButton")
	for k, v in pairs(props) do (b :: any)[k] = v end
	b.Parent = parent
	return b
end

local function getAnchor(pedestal): BasePart?
	if pedestal:IsA("BasePart") then return pedestal :: BasePart end
	if pedestal:IsA("Model") then
		return (pedestal :: Model).PrimaryPart
			or pedestal:FindFirstChildWhichIsA("BasePart") :: BasePart?
	end
	return nil
end

local function topCenter(pedestal): Vector3
	local a = getAnchor(pedestal)
	if not a then return Vector3.zero end
	return Vector3.new(a.Position.X, a.Position.Y + a.Size.Y / 2, a.Position.Z)
end

-- ── Atualização dos cards ──────────────────────────────────────────────────

local function refreshCardStates()
	for towerName, card in pairs(towerCards) do
		local slot    = currentSlots[towerName]
		local rarData = RarityData[card.rarity]

		if slot then
			local depleted = slot.stock <= 0
			card.stockLbl.Text = depleted
				and ("Esgotado (0/%d)"):format(slot.maxStock)
				or  ("x%d em estoque"):format(slot.stock)
			card.stockLbl.TextColor3 = depleted and GRAY or Color3.fromRGB(190, 190, 190)

			card.buyBtn.Text = depleted and "ESGOTADO" or ("$%d"):format(slot.price)
			card.buyBtn.BackgroundColor3 = depleted and PANEL_GRAY or PANEL_GREEN
			card.buyBtn.Active = not depleted
			card.frame.BackgroundTransparency = 0.1
			card.nameLbl.TextColor3 = Color3.fromRGB(240, 240, 240)
		else
			card.stockLbl.Text       = "Fora da rotação"
			card.stockLbl.TextColor3 = GRAY
			card.buyBtn.Text         = "—"
			card.buyBtn.BackgroundColor3 = PANEL_GRAY
			card.buyBtn.Active       = false
			card.frame.BackgroundTransparency = 0.45
			card.nameLbl.TextColor3  = GRAY
		end
	end
end

-- ── Shop UI ─────────────────────────────────────────────────────────────────

local function closeShop()
	if shopScreen then shopScreen.Enabled = false end
end

local function openShop()
	if not shopScreen then return end
	refreshCardStates()
	shopScreen.Enabled = true
end

local function buildShopUI()
	shopScreen              = Instance.new("ScreenGui")
	shopScreen.Name         = "ShopUI"
	shopScreen.ResetOnSpawn = false
	shopScreen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	shopScreen.Enabled      = false
	shopScreen.Parent       = gui

	-- Overlay semi-transparente
	local overlay               = Instance.new("TextButton")
	overlay.Size                = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3    = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.45
	overlay.Text                = ""
	overlay.AutoButtonColor     = false
	overlay.Parent              = shopScreen
	overlay.MouseButton1Click:Connect(closeShop)

	-- Painel principal
	local panel                 = Instance.new("Frame")
	panel.Name                  = "Panel"
	panel.Size                  = UDim2.new(0, 430, 0.88, 0)
	panel.AnchorPoint           = Vector2.new(0.5, 0.5)
	panel.Position              = UDim2.new(0.5, 0, 0.5, 0)
	panel.BackgroundColor3      = Color3.fromRGB(16, 16, 26)
	panel.BackgroundTransparency = 0.04
	panel.Parent                = shopScreen
	corner(panel, 14)
	stroke(panel, 2, Color3.fromRGB(65, 65, 100))

	-- Cabeçalho
	local header                = Instance.new("Frame")
	header.Name                 = "Header"
	header.Size                 = UDim2.new(1, 0, 0, 72)
	header.BackgroundColor3     = Color3.fromRGB(18, 18, 32)
	header.BackgroundTransparency = 0
	header.ClipsDescendants     = true
	header.Parent               = panel
	corner(header, 14)

	-- Bloco inferior do header sem cantos arredondados (para unir com o resto)
	local headerBottom          = Instance.new("Frame")
	headerBottom.Size           = UDim2.new(1, 0, 0.5, 0)
	headerBottom.Position       = UDim2.new(0, 0, 0.5, 0)
	headerBottom.BackgroundColor3 = Color3.fromRGB(18, 18, 32)
	headerBottom.BorderSizePixel = 0
	headerBottom.Parent         = header

	label(header, {
		Name = "Title",
		Size = UDim2.new(0.55, 0, 0.55, 0),
		Position = UDim2.new(0, 16, 0.04, 0),
		TextColor3 = Color3.fromRGB(255, 220, 60),
		TextScaled = true, Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "LOJA",
	})

	timerLabel = label(header, {
		Name = "Timer",
		Size = UDim2.new(0.65, 0, 0.4, 0),
		Position = UDim2.new(0, 16, 0.57, 0),
		TextColor3 = Color3.fromRGB(150, 150, 165),
		TextScaled = true, Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Rotação em: --:--",
	})

	local closeBtn = button(header, {
		Name = "CloseBtn",
		Size = UDim2.new(0, 46, 0, 46),
		Position = UDim2.new(1, -54, 0.5, -23),
		BackgroundColor3 = Color3.fromRGB(190, 45, 45),
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true, Font = Enum.Font.GothamBold,
		Text = "✕", AutoButtonColor = true,
	})
	corner(closeBtn, 8)
	closeBtn.MouseButton1Click:Connect(closeShop)

	-- Divisor
	local div               = Instance.new("Frame")
	div.Size                = UDim2.new(1, -20, 0, 1)
	div.Position            = UDim2.new(0, 10, 0, 72)
	div.BackgroundColor3    = Color3.fromRGB(48, 48, 68)
	div.BorderSizePixel     = 0
	div.Parent              = panel

	-- ScrollingFrame
	local scroll            = Instance.new("ScrollingFrame")
	scroll.Name             = "Scroll"
	scroll.Size             = UDim2.new(1, -10, 1, -82)
	scroll.Position         = UDim2.new(0, 5, 0, 80)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 105)
	scroll.CanvasSize       = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent           = panel

	local list              = Instance.new("Frame")
	list.Name               = "List"
	list.Size               = UDim2.new(1, 0, 0, 0)
	list.AutomaticSize      = Enum.AutomaticSize.Y
	list.BackgroundTransparency = 1
	list.Parent             = scroll

	local listLayout        = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.SortOrder    = Enum.SortOrder.LayoutOrder
	listLayout.Padding      = UDim.new(0, 5)
	listLayout.Parent       = list

	local listPad           = Instance.new("UIPadding")
	listPad.PaddingTop      = UDim.new(0, 4)
	listPad.PaddingBottom   = UDim.new(0, 10)
	listPad.PaddingLeft     = UDim.new(0, 4)
	listPad.PaddingRight    = UDim.new(0, 4)
	listPad.Parent          = list

	-- Constrói seções por raridade com cards de todas as torres
	local order = 0
	for _, rarity in ipairs(RARITY_ORDER) do
		local items = StoreItems[rarity]
		if not items or #items == 0 then continue end

		-- Cabeçalho de seção
		order += 1
		local rarColor   = (RarityData[rarity] and RarityData[rarity].Color) or GRAY
		local secHdr     = Instance.new("Frame")
		secHdr.Name      = "Sec_" .. rarity
		secHdr.Size      = UDim2.new(1, -6, 0, 30)
		secHdr.BackgroundColor3 = rarColor
		secHdr.BackgroundTransparency = 0.35
		secHdr.LayoutOrder = order
		secHdr.Parent    = list
		corner(secHdr, 6)

		label(secHdr, {
			Size = UDim2.new(1, -12, 1, 0),
			Position = UDim2.new(0, 10, 0, 0),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true, Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = rarity:upper(),
		})

		-- Cards das torres desta raridade
		for _, towerName in ipairs(items) do
			if not TowerStats[towerName] then continue end
			order += 1

			local card              = Instance.new("Frame")
			card.Name               = "Card_" .. towerName
			card.Size               = UDim2.new(1, -6, 0, 66)
			card.BackgroundColor3   = Color3.fromRGB(22, 22, 36)
			card.BackgroundTransparency = 0.1
			card.LayoutOrder        = order
			card.Parent             = list
			corner(card, 8)
			stroke(card, 1, Color3.fromRGB(48, 48, 65))

			-- Barra lateral colorida por raridade
			local rarBar            = Instance.new("Frame")
			rarBar.Size             = UDim2.new(0, 5, 0.8, 0)
			rarBar.Position         = UDim2.new(0, 0, 0.1, 0)
			rarBar.BackgroundColor3 = rarColor
			rarBar.BorderSizePixel  = 0
			rarBar.Parent           = card
			corner(rarBar, 3)

			local nameLbl = label(card, {
				Name = "Name",
				Size = UDim2.new(0.56, -10, 0.52, 0),
				Position = UDim2.new(0, 12, 0, 0),
				TextColor3 = Color3.fromRGB(240, 240, 240),
				TextScaled = true, Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = towerName,
			})

			local stockLbl = label(card, {
				Name = "Stock",
				Size = UDim2.new(0.56, -10, 0.38, 0),
				Position = UDim2.new(0, 12, 0.58, 0),
				TextColor3 = Color3.fromRGB(180, 180, 180),
				TextScaled = true, Font = Enum.Font.Gotham,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "Fora da rotação",
			})

			local buyBtn = button(card, {
				Name = "BuyBtn",
				Size = UDim2.new(0.37, -6, 0.68, 0),
				Position = UDim2.new(0.63, 0, 0.16, 0),
				BackgroundColor3 = PANEL_GRAY,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true, Font = Enum.Font.GothamBold,
				Text = "—", AutoButtonColor = true,
				Active = false,
			})
			corner(buyBtn, 8)

			towerCards[towerName] = {
				frame    = card,
				nameLbl  = nameLbl,
				stockLbl = stockLbl,
				buyBtn   = buyBtn,
				rarity   = rarity,
			}

			local capturedName = towerName
			buyBtn.MouseButton1Click:Connect(function()
				local slot = currentSlots[capturedName]
				if not slot or slot.stock <= 0 then return end
				buyBtn.Active = false
				buyBtn.Text   = "..."

				task.spawn(function()
					local result = Remotes.BuyShopItem:InvokeServer(capturedName)
					buyBtn.Active = true
					if result.ok then
						buyBtn.Text = "Comprado!"
						task.wait(0.8)
					else
						buyBtn.Text = result.reason or "Erro"
						task.wait(1.5)
					end
					-- Estado será corrigido pelo próximo ShopUpdated ou pelo refresh
					local s = currentSlots[capturedName]
					if s and s.stock > 0 then
						buyBtn.Text   = ("$%d"):format(s.price)
						buyBtn.Active = true
					else
						buyBtn.Text   = "—"
						buyBtn.Active = false
					end
				end)
			end)
		end
	end
end

-- ── Countdown ──────────────────────────────────────────────────────────────

local function startCountdown(nextRotation: number)
	if countdownThread then task.cancel(countdownThread) end
	countdownThread = task.spawn(function()
		while true do
			local rem = math.max(0, nextRotation - os.time())
			local txt  = ("%d:%02d"):format(math.floor(rem / 60), rem % 60)
			if timerLabel  then timerLabel.Text  = "Rotação em: " .. txt end
			if clockLabel  then clockLabel.Text  = txt              end
			if rem <= 0    then break end
			task.wait(1)
		end
		if timerLabel then timerLabel.Text = "Rotacionando..." end
		if clockLabel then clockLabel.Text  = "..."            end
	end)
end

-- ── Billboard de relógio no hotspot (informacional) ───────────────────────

local function buildClockGui(anchor: BasePart)
	local existing = anchor:FindFirstChild("ShopClock")
	if existing then existing:Destroy() end

	local bb             = Instance.new("BillboardGui")
	bb.Name              = "ShopClock"
	bb.Size              = UDim2.new(0, 180, 0, 70)
	bb.StudsOffset       = Vector3.new(0, 14, 0)
	bb.AlwaysOnTop       = false
	bb.Parent            = anchor

	local bg             = Instance.new("Frame")
	bg.Size              = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3  = Color3.fromRGB(10, 10, 20)
	bg.BackgroundTransparency = 0.15
	bg.Parent            = bb
	corner(bg, 10)

	clockLabel = label(bg, {
		Name = "Time",
		Size = UDim2.new(1, 0, 0.58, 0),
		Position = UDim2.new(0, 0, 0.06, 0),
		TextColor3 = Color3.fromRGB(255, 220, 60),
		TextScaled = true, Font = Enum.Font.GothamBold,
		Text = "--:--",
	})
	label(bg, {
		Name = "Sub",
		Size = UDim2.new(1, 0, 0.32, 0),
		Position = UDim2.new(0, 0, 0.65, 0),
		TextColor3 = Color3.fromRGB(150, 150, 150),
		TextScaled = true, Font = Enum.Font.Gotham,
		Text = "Próxima rotação",
	})
end

-- ── Vitrine dos pedestais (3D apenas, sem ProximityPrompt) ────────────────

local function clearPedestalDisplay(idx: number)
	local d = pedDisplays[idx]
	if not d then return end
	if d.towerModel and d.towerModel.Parent then d.towerModel:Destroy() end
	pedDisplays[idx] = nil
end

local function setupPedestalVitrine(idx: number, slot)
	local pedestal = pedestals[idx]
	if not pedestal or not towers then return end
	clearPedestalDisplay(idx)

	local template = towers:FindFirstChild(slot.towerName)
	if not template then return end

	local towerModel = template:Clone()
	local top        = topCenter(pedestal)
	local bCF, bSize = towerModel:GetBoundingBox()
	local pivotY     = towerModel:GetPivot().Position.Y
	local bottomOff  = pivotY - (bCF.Position.Y - bSize.Y / 2)
	towerModel:PivotTo(CFrame.new(top.X, top.Y + bottomOff + 0.3, top.Z))
	towerModel.Parent = Workspace

	for _, desc in ipairs(towerModel:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Anchored   = true
			desc.CanCollide = false
			desc.CanQuery   = false
		end
	end

	pedDisplays[idx] = { towerModel = towerModel }
end

-- ── Descoberta do Hotspot ──────────────────────────────────────────────────

local function hidePedestals()
	for _, ped in pairs(pedestals) do
		if ped:IsA("BasePart") then
			ped.Transparency = 1
		else
			for _, p in ipairs(ped:GetDescendants()) do
				if p:IsA("BasePart") then
					p.Transparency = 1
				end
			end
		end
	end
end

local function discoverHotspot()
	if hotspot then return true end

	hotspot = Workspace:FindFirstChild("Hotspot")
	if not hotspot then
		warn("[StoreController] workspace.Hotspot não encontrado — crie um Model/BasePart com esse nome no mapa")
		return false
	end
	for i = 1, MAX_PEDESTAL_COUNT do
		local ped = hotspot:FindFirstChild("Pedestal" .. i)
		if ped then pedestals[i] = ped end
	end
	hidePedestals()

	-- Aguarda a âncora criada pelo servidor para fixar o relógio de contagem
	task.spawn(function()
		local anchor = hotspot:WaitForChild("StoreAnchor", 10)
			or hotspot:FindFirstChildWhichIsA("BasePart", true)
		if anchor then
			pcall(buildClockGui, anchor)
		end
	end)

	return true
end

-- ── Atualização da loja ────────────────────────────────────────────────────

local function onShopUpdated(data)
	-- Reconstrói mapa de slots
	currentSlots = {}
	for _, slot in ipairs(data.slots) do
		currentSlots[slot.towerName] = slot
	end

	if not discoverHotspot() then return end

	-- Atualiza vitrine nos pedestais
	for i in pairs(pedDisplays) do clearPedestalDisplay(i) end
	pedDisplays = {}
	for i, slot in ipairs(data.slots) do
		setupPedestalVitrine(i, slot)
	end

	startCountdown(data.nextRotation)

	-- Atualiza cards se a UI estiver aberta
	if shopScreen and shopScreen.Enabled then
		refreshCardStates()
	end
end

-- ── Init ───────────────────────────────────────────────────────────────────

function StoreController:init()
	local buildOk, buildErr = pcall(buildShopUI)
	if not buildOk then
		warn("[StoreController] buildShopUI erro:", buildErr)
	end

	Remotes.ShopUpdated.OnClientEvent:Connect(onShopUpdated)
	Remotes.OpenShop.OnClientEvent:Connect(openShop)

	task.spawn(function()
		local ok, err = pcall(discoverHotspot)
		if not ok then warn("[StoreController] discoverHotspot erro:", err) end
	end)

	print("[StoreController] Pronto.")
end

return StoreController
