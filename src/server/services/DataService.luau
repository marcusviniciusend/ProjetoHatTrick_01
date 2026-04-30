local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

-- Cria o banco de dados principal do jogo
local MainDataStore = DataStoreService:GetDataStore("GameData_V1")

local DataService = {}

-- Cache que guarda os dados de quem está online: { [Player] = table }
DataService.Profiles = {}
DataService.ProfileLoaded = Instance.new("BindableEvent")

-- O "Molde" do seu save. Tudo que o jogador precisa ter fica aqui.
local DATA_TEMPLATE = {
	Currency = {
		Coins = 100,
	},
	Inventory = {
		Towers = {},    -- Ex: {"cannon", "archer_tower"}
		Brainrots = {}  -- Ex: {"jl din din din", "dung dung bumbum"}
	},
	Stats = {
		TimePlayed = 0
	}
}

-- ── Função de Segurança (Reconciliação) ──────────────────────────────────
-- Garante que o save do jogador tenha todas as chaves do Template atual.
local function reconcile(target, template)
	for k, v in pairs(template) do
		if type(v) == "table" then
			if type(target[k]) ~= "table" then
				target[k] = {}
			end
			reconcile(target[k], v)
		elseif target[k] == nil then
			target[k] = v
		end
	end
	return target
end

-- ── Lógica de Carregamento ───────────────────────────────────────────────
function DataService:LoadProfile(player)
	local data = nil

	-- Se estivermos no Roblox Studio, injeta o MOCK (Dinheiro Infinito)
	if RunService:IsStudio() then
		warn(("[DataService] Modo Studio: Mock de dados aplicado para %s."):format(player.Name))
		data = reconcile({}, DATA_TEMPLATE)
		data.Currency.Coins = 999999999
		self.Profiles[player] = data
		self.ProfileLoaded:Fire(player)
		return
	end

	-- Servidor Real: Puxa do banco de dados
	local success, result = pcall(function()
		return MainDataStore:GetAsync(tostring(player.UserId))
	end)

	if success then
		if result then
			-- Jogador antigo: mistura o save dele com o template (caso tenha atualizações no jogo)
			data = reconcile(result, DATA_TEMPLATE)
		else
			-- Jogador novo: ganha um save novinho baseado no template
			data = reconcile({}, DATA_TEMPLATE)
		end
		self.Profiles[player] = data
		self.ProfileLoaded:Fire(player)
	else
		warn(("[DataService] ERRO CRÍTICO ao carregar dados de %s: %s"):format(player.Name, tostring(result)))
		-- Se a internet do servidor piscar e não carregar, kicka o jogador pra ele não perder os dados.
		player:Kick("Erro ao carregar seus dados. Por favor, reconecte-se.")
	end
end

-- ── Lógica de Salvamento ─────────────────────────────────────────────────
function DataService:SaveProfile(player)
	-- Impede de salvar o "dinheiro infinito" se você estiver testando no Studio
	if RunService:IsStudio() then
		self.Profiles[player] = nil
		return
	end

	local data = self.Profiles[player]
	if data then
		local success, err = pcall(function()
			MainDataStore:SetAsync(tostring(player.UserId), data)
		end)
		
		if not success then
			warn(("[DataService] Falha ao salvar dados de %s: %s"):format(player.Name, tostring(err)))
		end
		self.Profiles[player] = nil
	end
end

-- ── Comunicação com outros Services ──────────────────────────────────────
--- @description Retorna a tabela inteira de save do jogador
function DataService:GetProfile(player)
	return self.Profiles[player]
end

-- ── Inicialização ────────────────────────────────────────────────────────
function DataService:init()
	Players.PlayerAdded:Connect(function(player)
		self:LoadProfile(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:SaveProfile(player)
	end)

	-- Salva o dado de todo mundo caso o servidor desligue do nada
	game:BindToClose(function()
		if RunService:IsStudio() then return end
		for _, player in ipairs(Players:GetPlayers()) do
			self:SaveProfile(player)
		end
	end)

	print("[DataService] Banco de dados centralizado pronto.")
end

return DataService