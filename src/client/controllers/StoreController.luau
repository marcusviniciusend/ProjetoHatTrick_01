local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local Remotes    = require(ReplicatedStorage.Shared.network.Remotes)
local RarityData = require(ReplicatedStorage.Shared.configs.RarityData)

local StoreController = {}

local player  = Players.LocalPlayer
local gui     = player:WaitForChild("PlayerGui")
local towers  = ReplicatedStorage:WaitForChild("towers", 10)

local MAX_PEDESTAL_COUNT = 5
local GRAY               = Color3.fromRGB(110, 110, 110)
local PANEL_GREEN        = Color3.fromRGB(40, 160, 60)
local PANEL_GRAY         = Color3.fromRGB(70, 70, 80)

-- ── Estado ─────────────────────────────────────────────────────────────────

local hotspot         = nil
local pedestals       = {}   -- [i] = Instance (BasePart ou Model)
local pedDisplays     = {}   -- [i] = { towerModel, billboard, prompt, towerName }
local clockLabel      = nil
local countdownThread = nil
local currentShop     = nil

-- ── Helpers de instância ───────────────────────────────────────────────────

local function corner(parent, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = parent
end
local function stroke(parent, t, col)
	local s = Instance.new("UIStroke"); s.Thickness = t or 2; s.Color = col or Color3.fromRGB(70,70,90); s.Parent = parent
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

-- ── Painel de Compra ───────────────────────────────────────────────────────

local panelScreen    = nil
local panelNameLbl   = nil
local panelRarLbl    = nil
local panelStockLbl  = nil
local panelPriceLbl  = nil
local panelBuyBtn    = nil
local panelTowerName = nil

local function closePurchasePanel()
	if panelScreen then panelScreen.Enabled = false end
	panelTowerName = nil
end

local function createPurchasePanel()
	panelScreen              = Instance.new("ScreenGui")
	panelScreen.Name         = "StorePanel"
	panelScreen.ResetOnSpawn = false
	panelScreen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	panelScreen.Enabled      = false
	panelScreen.Parent       = gui

	local bg             = Instance.new("Frame")
	bg.Size              = UDim2.new(0, 300, 0, 230)
	bg.Position          = UDim2.new(0.5, -150, 0.5, -115)
	bg.BackgroundColor3  = Color3.fromRGB(16, 16, 26)
	bg.BackgroundTransparency = 0.05
	bg.Parent            = panelScreen
	corner(bg, 12); stroke(bg, 2, Color3.fromRGB(70, 70, 100))

	panelNameLbl = label(bg, {
		Name = "Name", Size = UDim2.new(1, -16, 0, 38),
		Position = UDim2.new(0, 8, 0, 8),
		TextColor3 = Color3.fromRGB(240, 240, 240), TextScaled = true,
		Font = Enum.Font.GothamBold, Text = "",
	})

	local rarFrame       = Instance.new("Frame")
	rarFrame.Size        = UDim2.new(0.5, -12, 0, 30)
	rarFrame.Position    = UDim2.new(0, 8, 0, 52)
	rarFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
	rarFrame.Parent      = bg
	corner(rarFrame, 6)
	panelRarLbl = label(rarFrame, {
		Name = "Rarity", Size = UDim2.new(1, 0, 1, 0),
		TextColor3 = Color3.fromRGB(255, 255, 255), TextScaled = true,
		Font = Enum.Font.GothamBold, Text = "",
	})

	panelStockLbl = label(bg, {
		Name = "Stock", Size = UDim2.new(0.5, -12, 0, 30),
		Position = UDim2.new(0.5, 4, 0, 52),
		TextColor3 = Color3.fromRGB(190, 190, 190), TextScaled = true,
		Font = Enum.Font.Gotham, Text = "",
	})

	panelPriceLbl = label(bg, {
		Name = "Price", Size = UDim2.new(1, -16, 0, 34),
		Position = UDim2.new(0, 8, 0, 90),
		TextColor3 = Color3.fromRGB(255, 220, 60), TextScaled = true,
		Font = Enum.Font.GothamBold, Text = "",
	})

	panelBuyBtn = button(bg, {
		Name = "BuyBtn", Size = UDim2.new(1, -16, 0, 46),
		Position = UDim2.new(0, 8, 0, 134),
		BackgroundColor3 = PANEL_GREEN, Text = "COMPRAR",
		TextColor3 = Color3.fromRGB(255, 255, 255), TextScaled = true,
		Font = Enum.Font.GothamBold, AutoButtonColor = true,
	})
	corner(panelBuyBtn, 8)

	local closeBtn = button(bg, {
		Name = "CloseBtn", Size = UDim2.new(1, -16, 0, 36),
		Position = UDim2.new(0, 8, 0, 188),
		BackgroundColor3 = PANEL_GRAY, Text = "Fechar",
		TextColor3 = Color3.fromRGB(200, 200, 200), TextScaled = true,
		Font = Enum.Font.Gotham, AutoButtonColor = true,
	})
	corner(closeBtn, 8)
	closeBtn.MouseButton1Click:Connect(closePurchasePanel)

	panelBuyBtn.MouseButton1Click:Connect(function()
		local name = panelTowerName
		if not name then return end
		panelBuyBtn.Active = false
		panelBuyBtn.Text   = "..."

		task.spawn(function()
			local result = Remotes.BuyShopItem:InvokeServer(name)
			panelBuyBtn.Active = true
			if result.ok then
				panelBuyBtn.Text = "Comprado!"
				task.wait(0.9)
				closePurchasePanel()
			else
				panelBuyBtn.Text = result.reason or "Erro"
				task.wait(1.5)
				panelBuyBtn.Text = "COMPRAR"
			end
		end)
	end)
end

local function openPurchasePanel(towerName: string, slot)
	if not panelScreen then return end
	panelTowerName = towerName

	local rarData = RarityData[slot.rarity] or { Color = GRAY }
	local depleted = slot.stock <= 0

	panelNameLbl.Text   = towerName
	panelRarLbl.Text    = slot.rarity
	panelRarLbl.Parent.BackgroundColor3 = depleted and GRAY or rarData.Color
	panelStockLbl.Text  = ("Estoque: %d/%d"):format(slot.stock, slot.maxStock)
	panelPriceLbl.Text  = depleted and "ESGOTADO" or ("$%d"):format(slot.price)
	panelPriceLbl.TextColor3 = depleted and GRAY or Color3.fromRGB(255, 220, 60)
	panelBuyBtn.Active       = not depleted
	panelBuyBtn.BackgroundColor3 = depleted and PANEL_GRAY or PANEL_GREEN
	panelBuyBtn.Text         = depleted and "ESGOTADO" or "COMPRAR"
	panelScreen.Enabled      = true
end

-- ── Countdown clock ────────────────────────────────────────────────────────

local function buildClockGui(anchorPart: BasePart)
	local existing = anchorPart:FindFirstChild("ShopClock")
	if existing then existing:Destroy() end

	local bb             = Instance.new("BillboardGui")
	bb.Name              = "ShopClock"
	bb.Size              = UDim2.new(0, 180, 0, 70)
	bb.StudsOffset       = Vector3.new(0, 14, 0)
	bb.AlwaysOnTop       = false
	bb.ResetOnSpawn      = false
	bb.Parent            = anchorPart

	local bg             = Instance.new("Frame")
	bg.Size              = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3  = Color3.fromRGB(10, 10, 20)
	bg.BackgroundTransparency = 0.15
	bg.Parent            = bb
	corner(bg, 10)

	clockLabel = label(bg, {
		Name = "Time", Size = UDim2.new(1, 0, 0.58, 0), Position = UDim2.new(0, 0, 0.06, 0),
		TextColor3 = Color3.fromRGB(255, 220, 60), TextScaled = true,
		Font = Enum.Font.GothamBold, Text = "1:00",
	})
	label(bg, {
		Name = "Sub", Size = UDim2.new(1, 0, 0.32, 0), Position = UDim2.new(0, 0, 0.65, 0),
		TextColor3 = Color3.fromRGB(150, 150, 150), TextScaled = true,
		Font = Enum.Font.Gotham, Text = "Próxima rotação",
	})
end

local function startCountdown(nextRotation: number)
	if countdownThread then task.cancel(countdownThread) end
	countdownThread = task.spawn(function()
		while true do
			local rem = math.max(0, nextRotation - os.time())
			if clockLabel then
				clockLabel.Text = ("%d:%02d"):format(math.floor(rem / 60), rem % 60)
			end
			if rem <= 0 then break end
			task.wait(1)
		end
	end)
end

-- ── Gestão de pedestais ────────────────────────────────────────────────────

local function clearPedestalDisplay(idx: number)
	local d = pedDisplays[idx]
	if not d then return end
	if d.towerModel and d.towerModel.Parent then d.towerModel:Destroy() end
	if d.prompt    and d.prompt.Parent     then d.prompt:Destroy()     end
	local anchor = pedestals[idx] and getAnchor(pedestals[idx])
	if anchor then
		local bb = anchor:FindFirstChild("ShopBillboard")
		if bb then bb:Destroy() end
	end
	pedDisplays[idx] = nil
end

local function buildBillboard(anchor: BasePart): BillboardGui
	local bb          = Instance.new("BillboardGui")
	bb.Name           = "ShopBillboard"
	bb.Size           = UDim2.new(0, 210, 0, 110)
	bb.StudsOffset    = Vector3.new(0, 5, 0)
	bb.AlwaysOnTop    = false
	bb.ResetOnSpawn   = false
	bb.Parent         = anchor

	local bg          = Instance.new("Frame")
	bg.Name           = "BG"
	bg.Size           = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
	bg.BackgroundTransparency = 0.2
	bg.Parent         = bb
	corner(bg, 8)

	label(bg, { Name = "NameLabel",
		Size = UDim2.new(1, -8, 0.38, 0), Position = UDim2.new(0, 4, 0.04, 0),
		TextColor3 = Color3.fromRGB(240, 240, 240), TextScaled = true, Font = Enum.Font.GothamBold, Text = "",
	})

	local rarFrame       = Instance.new("Frame")
	rarFrame.Name        = "RarityFrame"
	rarFrame.Size        = UDim2.new(0.48, -6, 0.34, 0)
	rarFrame.Position    = UDim2.new(0, 4, 0.47, 0)
	rarFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
	rarFrame.Parent      = bg
	corner(rarFrame, 5)
	label(rarFrame, { Name = "RarityLabel",
		Size = UDim2.new(1, 0, 1, 0), TextColor3 = Color3.fromRGB(255,255,255),
		TextScaled = true, Font = Enum.Font.Gotham, Text = "",
	})

	label(bg, { Name = "PriceLabel",
		Size = UDim2.new(0.52, -6, 0.34, 0), Position = UDim2.new(0.48, 2, 0.47, 0),
		TextColor3 = Color3.fromRGB(255, 220, 60), TextScaled = true, Font = Enum.Font.GothamBold, Text = "",
	})

	label(bg, { Name = "StockLabel",
		Size = UDim2.new(1, -8, 0.22, 0), Position = UDim2.new(0, 4, 0.78, 0),
		TextColor3 = Color3.fromRGB(170, 170, 170), TextScaled = true, Font = Enum.Font.Gotham, Text = "",
	})

	return bb
end

local function updateBillboard(bb: BillboardGui, slot, towerName: string, depleted: boolean)
	local bg       = bb:FindFirstChild("BG")
	if not bg then return end

	local rarData  = RarityData[slot.rarity] or { Color = GRAY }
	local nameLbl  = bg:FindFirstChild("NameLabel")
	local rarFrame = bg:FindFirstChild("RarityFrame")
	local rarLbl   = rarFrame and rarFrame:FindFirstChild("RarityLabel")
	local priceLbl = bg:FindFirstChild("PriceLabel")
	local stockLbl = bg:FindFirstChild("StockLabel")

	if depleted then
		bg.BackgroundColor3    = Color3.fromRGB(22, 22, 22)
		if nameLbl  then nameLbl.TextColor3  = GRAY end
		if rarFrame then rarFrame.BackgroundColor3 = GRAY end
		if rarLbl   then rarLbl.Text  = "ESGOTADO"; rarLbl.TextColor3 = Color3.fromRGB(60, 60, 60) end
		if priceLbl then priceLbl.Text = ""; priceLbl.Visible = false end
		if stockLbl then stockLbl.Text = ("0/%d"):format(slot.maxStock); stockLbl.TextColor3 = GRAY end
	else
		bg.BackgroundColor3    = Color3.fromRGB(14, 14, 22)
		if nameLbl  then nameLbl.TextColor3  = Color3.fromRGB(240, 240, 240) end
		if rarFrame then rarFrame.BackgroundColor3 = rarData.Color end
		if rarLbl   then rarLbl.Text  = slot.rarity; rarLbl.TextColor3 = Color3.fromRGB(255,255,255) end
		if priceLbl then priceLbl.Text = ("$%d"):format(slot.price); priceLbl.Visible = true end
		if stockLbl then stockLbl.Text = ("%d/%d"):format(slot.stock, slot.maxStock); stockLbl.TextColor3 = Color3.fromRGB(170,170,170) end
	end

	if nameLbl then nameLbl.Text = towerName end
end

local function setupPedestalSlot(idx: number, slot)
	local pedestal = pedestals[idx]
	if not pedestal then return end

	local anchor = getAnchor(pedestal)
	if not anchor then return end

	clearPedestalDisplay(idx)

	-- Modelo 3D acima do pedestal
	local towerModel = nil
	if towers then
		local template = towers:FindFirstChild(slot.towerName)
		if template then
			towerModel = template:Clone()
			local bCF, bSize = towerModel:GetBoundingBox()
			local pivotY     = towerModel:GetPivot().Position.Y
			local bottomOffset = pivotY - (bCF.Position.Y - bSize.Y / 2)
			local top = topCenter(pedestal)
			towerModel:PivotTo(CFrame.new(top.X, top.Y + bottomOffset + 0.3, top.Z))
			towerModel.Parent = Workspace
			for _, desc in ipairs(towerModel:GetDescendants()) do
				if desc:IsA("BasePart") then
					desc.Anchored   = true
					desc.CanCollide = false
					desc.CanQuery   = false
					if slot.stock <= 0 then desc.Color = GRAY end
				end
			end
		end
	end

	-- Billboard
	local bb = buildBillboard(anchor)
	updateBillboard(bb, slot, slot.towerName, slot.stock <= 0)

	-- ProximityPrompt (só criado se há estoque)
	local prompt = nil
	if slot.stock > 0 then
		prompt              = Instance.new("ProximityPrompt")
		prompt.ObjectText   = slot.towerName
		prompt.ActionText   = ("Comprar  $%d"):format(slot.price)
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.Parent       = anchor

		local capturedName = slot.towerName
		prompt.Triggered:Connect(function()
			-- Busca dados atuais para refletir estoque em tempo real
			if not currentShop then return end
			for _, s in ipairs(currentShop.slots) do
				if s.towerName == capturedName then
					openPurchasePanel(capturedName, s)
					return
				end
			end
		end)
	end

	pedDisplays[idx] = { towerModel = towerModel, billboard = bb, prompt = prompt, towerName = slot.towerName }
end

-- ── Atualização da loja ────────────────────────────────────────────────────

local function discoverHotspot()
	if hotspot then return true end

	hotspot = Workspace:FindFirstChild("Hotspot")
	if not hotspot then
		warn("[StoreController] workspace.Hotspot não encontrado — crie uma pasta/modelo com esse nome no mapa")
		return false
	end

	for i = 1, MAX_PEDESTAL_COUNT do
		local ped = hotspot:FindFirstChild("Pedestal" .. i)
		if ped then pedestals[i] = ped end
	end

	-- Relógio: usa PrimaryPart do Hotspot ou o primeiro pedestal encontrado
	local clockAnchor = (hotspot:IsA("Model") and hotspot.PrimaryPart)
		or hotspot:FindFirstChildWhichIsA("BasePart")
	if clockAnchor then
		buildClockGui(clockAnchor :: BasePart)
	end

	return true
end

local function onShopUpdated(data)
	currentShop = data

	if not discoverHotspot() then return end

	-- Limpa todos os displays
	for i in pairs(pedDisplays) do clearPedestalDisplay(i) end
	pedDisplays = {}

	-- Reconstrói um pedestal por slot
	for i, slot in ipairs(data.slots) do
		setupPedestalSlot(i, slot)
	end

	startCountdown(data.nextRotation)
end

-- ── Init ───────────────────────────────────────────────────────────────────

function StoreController:init()
	createPurchasePanel()
	Remotes.ShopUpdated.OnClientEvent:Connect(onShopUpdated)
	print("[StoreController] Pronto.")
end

return StoreController
