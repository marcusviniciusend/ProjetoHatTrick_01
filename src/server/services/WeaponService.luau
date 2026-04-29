local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local Remotes      = require(ReplicatedStorage:WaitForChild("Shared").network.Remotes)
local EnemyService = require(script.Parent.EnemyService)

local WeaponService = {}

local WEAPON_DAMAGE   = 25   -- dano por tiro
local WEAPON_RANGE    = 300  -- alcance máximo do raycast (studs)
local SHOOT_COOLDOWN  = 0.4  -- segundos entre tiros por jogador
local MAX_ORIGIN_DIST = 60   -- distância máxima entre origem do tiro e HRP do jogador

local cooldowns = {}  -- { [userId]: number } = tick do último disparo

-- RaycastParams criado uma vez: CollisionGroup "Weapons" só acerta o grupo "Enemies".
-- RespectCanCollide = false garante que partes Anchored/CanCollide=false ainda sejam detectadas.
local rayParams = RaycastParams.new()
rayParams.CollisionGroup    = "Weapons"
rayParams.RespectCanCollide = false

function WeaponService:init()
	Remotes.WeaponFire.OnServerEvent:Connect(function(player, origin, direction)
		if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then return end

		local now    = tick()
		local userId = player.UserId
		if cooldowns[userId] and (now - cooldowns[userId]) < SHOOT_COOLDOWN then return end
		cooldowns[userId] = now

		local character = player.Character
		local hrp       = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		if (origin - hrp.Position).Magnitude > MAX_ORIGIN_DIST then return end

		local mag = direction.Magnitude
		if mag < 0.001 then return end
		direction = direction / mag

		local result = Workspace:Raycast(origin, direction * WEAPON_RANGE, rayParams)
		if not result then return end

		local model = result.Instance
		while model and not model:IsA("Model") do
			model = model.Parent
		end
		if not model then return end

		local activeEnemies = EnemyService:getActive()
		local enemyObj      = activeEnemies[model]
		if not enemyObj or enemyObj._dead then return end

		enemyObj:takeDamage(WEAPON_DAMAGE)
	end)

	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player.UserId] = nil
	end)

	print("[WeaponService] Pronto.")
end

return WeaponService
