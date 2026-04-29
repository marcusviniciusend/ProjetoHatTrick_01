local CollectionService = game:GetService("CollectionService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")

local PlacementController = require(script.Parent.PlacementController)
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").network.Remotes)

local WeaponController = {}

local ENEMY_TAG      = "Enemy"
local WEAPON_COOLDOWN = 0.4  -- espelho do servidor para evitar envios desnecessários

local player        = Players.LocalPlayer
local mouse         = player:GetMouse()
local shootCooldown = false

local function fireWeapon()
	if shootCooldown then return end
	shootCooldown = true
	task.delay(WEAPON_COOLDOWN, function() shootCooldown = false end)

	-- Origem e direção calculadas a partir da câmera: o servidor faz o raycast definitivo.
	local camera  = Workspace.CurrentCamera
	local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)

	Remotes.WeaponFire:FireServer(unitRay.Origin, unitRay.Direction)
end

function WeaponController:init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if PlacementController:isBuildModeActive() then return end

		local target = mouse.Target
		if not target then return end

		-- Sobe na hierarquia para verificar se o alvo é um inimigo
		local model = target
		while model and not model:IsA("Model") do
			model = model.Parent
		end

		if model and CollectionService:HasTag(model, ENEMY_TAG) then
			fireWeapon()
		end
	end)

	print("[WeaponController] Pronto.")
end

return WeaponController
