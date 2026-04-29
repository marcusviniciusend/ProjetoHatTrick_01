local PhysicsService = game:GetService("PhysicsService")

local PhysicsServiceModule = {}

local GROUPS = { "Enemies", "Towers", "Weapons" }

-- false = sem colisão física entre os grupos
local RULES = {
	{ "Enemies", "Enemies", false }, -- inimigos não se empurram
	{ "Enemies", "Towers",  false }, -- inimigos passam por torres
	{ "Enemies", "Default", false }, -- inimigos não colidem com jogadores/terrain
	{ "Weapons", "Default", false }, -- raycast de armas ignora terrain e jogadores
	{ "Weapons", "Towers",  false }, -- raycast de armas ignora torres
	-- "Weapons" ↔ "Enemies" permanece true (padrão): raycasts atingem inimigos
}

function PhysicsServiceModule:init()
	for _, name in ipairs(GROUPS) do
		pcall(PhysicsService.RegisterCollisionGroup, PhysicsService, name)
	end

	for _, rule in ipairs(RULES) do
		local ok, err = pcall(
			PhysicsService.CollisionGroupSetCollidable,
			PhysicsService, rule[1], rule[2], rule[3]
		)
		if not ok then
			warn(("[PhysicsService] Regra %s<>%s falhou: %s"):format(rule[1], rule[2], tostring(err)))
		end
	end

	print("[PhysicsService] Collision groups configurados.")
end

-- Atribui todas as BaseParts de uma instância ao grupo especificado.
function PhysicsServiceModule:assignToGroup(instance: Instance, groupName: string)
	for _, desc in ipairs(instance:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.CollisionGroup = groupName
		end
	end
	if instance:IsA("BasePart") then
		(instance :: BasePart).CollisionGroup = groupName
	end
end

return PhysicsServiceModule
