local services = script.Parent:WaitForChild("services")

-- Deps resolvidos em ordem: cada service só é iniciado após suas deps
local DataService         = require(services.DataService)
local PhysicsService      = require(services.PhysicsService)
local CurrencyService     = require(services.CurrencyService)
local InventoryService    = require(services.InventoryService)
local PlotService         = require(services.PlotService)
local TowerService        = require(services.TowerService)
local PlacementService    = require(services.PlacementService)
local LeaderboardService  = require(services.LeaderboardService)
local WaveService         = require(services.WaveService)
local WeaponService       = require(services.WeaponService)
local StoreService        = require(services.StoreService)
local SellService         = require(services.SellService)

DataService:init()          -- ← primeiro: registra PlayerAdded antes de todos os outros
PhysicsService:init()       -- ← grupos precisam existir antes de qualquer spawn
CurrencyService:init()
InventoryService:init()     -- ← antes de PlacementService e StoreService
PlotService:init()
TowerService:init()
PlacementService:init()
LeaderboardService:init()   -- ← antes do WaveService (WaveService depende dele)
WaveService:init()          -- ← inicia EnemyService + agenda Wave 1
WeaponService:init()
StoreService:init()
SellService:init()         -- ← após InventoryService e CurrencyService
