local controllers = script.Parent:WaitForChild("controllers")

local PlacementController = require(controllers.PlacementController)
local UIController        = require(controllers.UIController)
local HUDController       = require(controllers.HUDController)
local EnemyController     = require(controllers.EnemyController)

-- Cada controller roda independente: um travado não bloqueia os outros
task.spawn(function() PlacementController:init() end)
task.spawn(function() UIController:init() end)
task.spawn(function() HUDController:init() end)
task.spawn(function() EnemyController:init() end)
