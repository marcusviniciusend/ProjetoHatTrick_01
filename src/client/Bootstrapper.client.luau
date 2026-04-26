local controllers = script.Parent:WaitForChild("controllers")

local PlacementController = require(controllers.PlacementController)
local UIController        = require(controllers.UIController)

PlacementController:init()
UIController:init()
