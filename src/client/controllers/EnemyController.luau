local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HealthBarUtil = require(ReplicatedStorage.Shared.utils.HealthBarUtil)

local ENEMY_TAG = "Enemy"

local EnemyController = {}

local ENEMY_BAR_CONFIG = {
	studsOffset = Vector3.new(0, 3, 0),
	maxDistance = 80,
}

-- ── Init ───────────────────────────────────────────────────────────────────

function EnemyController:init()
	for _, enemy in ipairs(CollectionService:GetTagged(ENEMY_TAG)) do
		task.spawn(HealthBarUtil.attach, enemy, ENEMY_BAR_CONFIG)
	end

	CollectionService:GetInstanceAddedSignal(ENEMY_TAG):Connect(function(enemy)
		task.spawn(HealthBarUtil.attach, enemy, ENEMY_BAR_CONFIG)
	end)
end

return EnemyController
