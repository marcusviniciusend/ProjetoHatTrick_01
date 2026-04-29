local services = script.Parent:WaitForChild("services")

-- Deps resolvidos em ordem: cada service só é iniciado após suas deps
local PhysicsService   = require(services.PhysicsService)
local CurrencyService  = require(services.CurrencyService)
local PlotService      = require(services.PlotService)
local TowerService     = require(services.TowerService)    -- depende de EnemyService (lazy via require)
local PlacementService = require(services.PlacementService) -- depende de Currency, Plot, Tower
local WaveService      = require(services.WaveService)     -- inicia EnemyService internamente
local WeaponService    = require(services.WeaponService)

PhysicsService:init()    -- ← primeiro: grupos precisam existir antes de qualquer spawn
CurrencyService:init()
PlotService:init()
TowerService:init()
PlacementService:init()
WaveService:init()       -- ← inicia EnemyService + agenda Wave 1
WeaponService:init()
