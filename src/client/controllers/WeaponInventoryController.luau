local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes     = require(ReplicatedStorage:WaitForChild("Shared").network.Remotes)
local WeaponStats = require(ReplicatedStorage.Shared.configs.WeaponStats)

local WeaponInventoryController = {}

local player = Players.LocalPlayer
local gui    = player:WaitForChild("PlayerGui")

local mainFrame    = nil
local scrollFrame  = nil
local slotTemplate = nil
local equippedLabel = nil
local setupDone    = false

local currentInventory = {}  -- { string } — cache local
local currentEquipped  = nil -- string | nil — cache local

-- ── Cor de destaque para arma equipada ────────────────────────────────────

local EQUIPPED_COLOR  = Color3.fromRGB(255, 200, 50)
local DEFAULT_COLOR   = Color3.fromRGB(80, 80, 80)

-- ── Descoberta de referências ──────────────────────────────────────────────

local function resolveRefs(): boolean
	if setupDone then return mainFrame ~= nil end

	local inventoryGui = gui:FindFirstChild("WeaponInventoryGui")
	if not inventoryGui then return false end

	mainFrame = inventoryGui:FindFirstChild("MainFrame")
	if not mainFrame then return false end

	scrollFrame   = mainFrame:FindFirstChild("ScrollingFrame")
	slotTemplate  = scrollFrame and scrollFrame:FindFirstChild("WeaponSlot_Template")
	equippedLabel = mainFrame:FindFirstChild("EquippedLabel")

	mainFrame.Visible = false
	if slotTemplate then slotTemplate.Visible = false end

	local closeButton = mainFrame:FindFirstChild("CloseButton")
	if closeButton then
		closeButton.MouseButton1Click:Connect(function()
			mainFrame.Visible = false
		end)
	end

	setupDone = true
	return true
end

-- ── Destaque visual do slot equipado ─────────────────────────────────────

local function applyEquippedHighlight()
	if not scrollFrame then return end
	for _, slot in ipairs(scrollFrame:GetChildren()) do
		if slot == slotTemplate then continue end
		local stroke = slot:FindFirstChildWhichIsA("UIStroke")
		if not stroke then continue end
		local nameLbl = slot:FindFirstChild("WeaponName")
		local isEquipped = nameLbl and nameLbl.Text == currentEquipped
		stroke.Color     = isEquipped and EQUIPPED_COLOR or DEFAULT_COLOR
		stroke.Thickness = isEquipped and 3 or 1
	end

	if equippedLabel then
		equippedLabel.Text = currentEquipped or "Nenhuma"
	end
end

-- ── Populate slot ─────────────────────────────────────────────────────────

local function setupSlot(slot: Frame, weaponName: string)
	local nameLbl      = slot:FindFirstChild("WeaponName")
	local typeLbl      = slot:FindFirstChild("WeaponType")
	local specialLbl   = slot:FindFirstChild("IsSpecialLabel")
	local equipBtn     = slot:FindFirstChild("EquipButton")
	local stroke       = slot:FindFirstChildWhichIsA("UIStroke")

	if nameLbl then nameLbl.Text = weaponName end

	local stats = WeaponStats[weaponName]
	if stats then
		if typeLbl    then typeLbl.Text = stats.Type end
		if specialLbl then specialLbl.Visible = stats.IsSpecial == true end
	end

	-- Destaque inicial
	if stroke then
		local isEquipped = weaponName == currentEquipped
		stroke.Color     = isEquipped and EQUIPPED_COLOR or DEFAULT_COLOR
		stroke.Thickness = isEquipped and 3 or 1
	end

	if equipBtn then
		equipBtn.MouseButton1Click:Connect(function()
			task.spawn(function()
				local ok = Remotes.WeaponEquip:InvokeServer(weaponName)
				if not ok then
					warn(("[WeaponInventoryController] Equip negado para '%s'"):format(weaponName))
				end
			end)
		end)
	end
end

-- ── refresh ───────────────────────────────────────────────────────────────

function WeaponInventoryController:refresh(inventory: { string }?)
	if inventory then currentInventory = inventory end
	if not mainFrame then return end
	if not scrollFrame or not slotTemplate then return end

	-- Limpa slots antigos
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child ~= slotTemplate then
			child:Destroy()
		end
	end

	-- Gera um slot por arma
	for _, weaponName in ipairs(currentInventory) do
		local slot   = slotTemplate:Clone()
		slot.Name    = "Slot_" .. weaponName
		slot.Visible = true
		setupSlot(slot, weaponName)
		slot.Parent  = scrollFrame
	end

	applyEquippedHighlight()
end

-- ── Init ──────────────────────────────────────────────────────────────────

function WeaponInventoryController:init()
	-- Escuta atualizações do inventário
	Remotes.WeaponInventoryUpdated.OnClientEvent:Connect(function(inventory: { string })
		currentInventory = inventory
		resolveRefs()
		self:refresh()
	end)

	-- Escuta confirmação de equip para atualizar destaque
	Remotes.WeaponEquipped.OnClientEvent:Connect(function(weaponName: string)
		currentEquipped = weaponName
		resolveRefs()
		applyEquippedHighlight()
	end)

	-- Tenta resolver refs agora
	if not resolveRefs() then
		warn("[WeaponInventoryController] WeaponInventoryGui não encontrada — aguardando equipe de UI")
	end

	-- Fetch proativo: popula inventário e arma equipada ao entrar
	task.spawn(function()
		local inventory = Remotes.GetWeaponInventory:InvokeServer()
		local equipped  = Remotes.GetEquippedWeapon:InvokeServer()
		if inventory then currentInventory = inventory end
		if equipped  then currentEquipped  = equipped  end
		resolveRefs()
		self:refresh()
	end)

	print("[WeaponInventoryController] Pronto.")
end

return WeaponInventoryController
