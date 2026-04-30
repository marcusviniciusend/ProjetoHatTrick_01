local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IS_SERVER = RunService:IsServer()

local folder
if IS_SERVER then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local function getRemote(name, className)
	if IS_SERVER then
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
		return remote
	else
		return folder:WaitForChild(name)
	end
end

return {
	PlaceTower         = getRemote("PlaceTower",         "RemoteFunction"),
	WaveUpdate         = getRemote("WaveUpdate",         "RemoteEvent"),
	RequestWaveStart   = getRemote("RequestWaveStart",   "RemoteEvent"),
	RequestWaveEnd     = getRemote("RequestWaveEnd",     "RemoteEvent"),
	PhaseChanged       = getRemote("PhaseChanged",       "RemoteEvent"),
	RequestTowerAction = getRemote("RequestTowerAction", "RemoteFunction"),
	PlotAssigned       = getRemote("PlotAssigned",       "RemoteEvent"),
	WeaponFire         = getRemote("WeaponFire",         "RemoteEvent"),
	ShopUpdated        = getRemote("ShopUpdated",        "RemoteEvent"),
	BuyShopItem        = getRemote("BuyShopItem",        "RemoteFunction"),
	PlayerDefeated     = getRemote("PlayerDefeated",     "RemoteEvent"),
	OpenShop           = getRemote("OpenShop",           "RemoteEvent"),
	GetInventory       = getRemote("GetInventory",       "RemoteFunction"),
}
