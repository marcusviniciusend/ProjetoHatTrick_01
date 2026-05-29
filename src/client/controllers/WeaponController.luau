local CollectionService = game:GetService("CollectionService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")

local Remotes     = require(ReplicatedStorage:WaitForChild("Shared").network.Remotes)
local WeaponStats = require(ReplicatedStorage.Shared.configs.WeaponStats)

-- Graceful degradation: UIController pode falhar ao carregar sem quebrar este controller
local UIController = nil
pcall(function()
    UIController = require(script.Parent.UIController)
end)

local WeaponController = {}

local ENEMY_TAG = "Enemy"

local player         = Players.LocalPlayer
local equippedWeapon = nil  -- cache local — evita InvokeServer a cada disparo
local lastShootTime  = 0

-- ── Helpers ────────────────────────────────────────────────────────────────

local function isWeaponMode(): boolean
    if not UIController then return false end
    local ok, state = pcall(function() return UIController:getState() end)
    return ok and state == "WeaponMode"
end

local function getHRP(): BasePart?
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function findNearestEnemy(hrp: BasePart): Model?
    local tagged        = CollectionService:GetTagged(ENEMY_TAG)
    local nearest, best = nil, math.huge
    for _, model in ipairs(tagged) do
        if not model.Parent then continue end
        local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
        if not root then continue end
        local dist = (root.Position - hrp.Position).Magnitude
        if dist < best then
            nearest = model
            best    = dist
        end
    end
    return nearest
end

-- ── Efeito visual melee ────────────────────────────────────────────────────

local function spawnMeleeEffect(hrp: BasePart, range: number)
    local effect            = Instance.new("Part")
    effect.Size             = Vector3.new(range, 3, range)
    effect.Material         = Enum.Material.Neon
    effect.Color            = Color3.fromRGB(255, 200, 50)
    effect.Transparency     = 0.75
    effect.CanCollide       = false
    effect.CastShadow       = false
    effect.Anchored         = true
    effect.CFrame           = hrp.CFrame + hrp.CFrame.LookVector * (range / 2)
    effect.Parent           = Workspace
    task.delay(0.15, function() effect:Destroy() end)
end

-- ── Projétil visual ranged ─────────────────────────────────────────────────

local function spawnProjectile(hrp: BasePart, enemyModel: Model, stats, isSplash: boolean)
    local color = isSplash
        and Color3.fromRGB(180, 50, 255)   -- roxo para splash
        or  Color3.fromRGB(255, 180, 50)   -- laranja para homing
    local speed = stats.ProjectileSpeed or 80

    local proj          = Instance.new("Part")
    proj.Size           = Vector3.new(0.4, 0.4, 0.4)
    proj.Shape          = Enum.PartType.Ball
    proj.Material       = Enum.Material.Neon
    proj.Color          = color
    proj.CastShadow     = false
    proj.CanCollide     = false
    proj.Anchored       = true
    proj.CFrame         = CFrame.new(hrp.Position + hrp.CFrame.LookVector * 2)
    proj.Parent         = Workspace

    local conn
    conn = RunService.RenderStepped:Connect(function(dt)
        local root = enemyModel:FindFirstChild("HumanoidRootPart") or enemyModel.PrimaryPart
        if not root or not enemyModel.Parent then
            proj:Destroy()
            conn:Disconnect()
            return
        end

        local targetPos = root.Position
        local delta     = targetPos - proj.Position
        local dist      = delta.Magnitude

        if dist <= 3 then
            if isSplash then
                Remotes.WeaponFire:FireServer({ type = "Splash", position = targetPos })
            else
                Remotes.WeaponFire:FireServer({ type = "Ranged", target = enemyModel })
            end
            proj:Destroy()
            conn:Disconnect()
            return
        end

        proj.CFrame = CFrame.new(proj.Position + delta.Unit * math.min(speed * dt, dist))
    end)
end

-- ── Lógica de disparo ──────────────────────────────────────────────────────

local function fire()
    if not isWeaponMode() then return end

    if not equippedWeapon then
        warn("[WeaponController] Nenhuma arma equipada")
        return
    end

    local stats = WeaponStats[equippedWeapon]
    if not stats then
        warn(("[WeaponController] WeaponStats não encontrado para '%s'"):format(tostring(equippedWeapon)))
        return
    end

    local now = tick()
    if now - lastShootTime < stats.Cooldown then return end
    lastShootTime = now

    local hrp = getHRP()
    if not hrp then return end

    if stats.Type == "Melee" then
        local range = stats.CleaveRange or stats.FrontRange or 6
        Remotes.WeaponFire:FireServer({ type = "Melee" })
        spawnMeleeEffect(hrp, range)
    else
        local enemy = findNearestEnemy(hrp)
        if not enemy then return end
        spawnProjectile(hrp, enemy, stats, stats.SplashRadius ~= nil)
    end
end

-- ── Init ───────────────────────────────────────────────────────────────────

function WeaponController:init()
    -- Mantém cache sincronizado com o servidor
    Remotes.WeaponEquipped.OnClientEvent:Connect(function(weaponName: string)
        equippedWeapon = weaponName
    end)

    -- Fetch proativo: resolve race condition caso WeaponEquipped já tenha disparado
    task.spawn(function()
        local equipped = Remotes.GetEquippedWeapon:InvokeServer()
        if equipped and not equippedWeapon then
            equippedWeapon = equipped
        end
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        fire()
    end)

    print("[WeaponController] Pronto.")
end

return WeaponController
