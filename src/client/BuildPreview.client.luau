local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService") -- Adicionado para a animação

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local gui = player:WaitForChild("PlayerGui")
local itemSelecionado = ""

local GRID_SIZE = 4
local ALTURA_CHAO = 2 

-- Variável pra ver se modo construção tá ativo
local modoConstrucaoAtivo = false
local modoDeletarAtivo = false

-- 1. CRIANDO O BLOCO FANTASMA
local blocoFantasma = Instance.new("Part")
blocoFantasma.Name = "PreviewConstrucao"
blocoFantasma.Size = Vector3.new(4, 4, 4)
blocoFantasma.Anchored = true
blocoFantasma.CastShadow = false
blocoFantasma.CanTouch = false
blocoFantasma.CanCollide = false
blocoFantasma.CanQuery = false 
blocoFantasma.Material = Enum.Material.Neon
blocoFantasma.Transparency = 1 
blocoFantasma.Parent = workspace

-- 2. FUNÇÃO DO GRID
local function travarNoGrid(posicaoMouse)
	local snapX = math.round(posicaoMouse.X / GRID_SIZE) * GRID_SIZE
	local snapZ = math.round(posicaoMouse.Z / GRID_SIZE) * GRID_SIZE
	return Vector3.new(snapX, ALTURA_CHAO, snapZ)
end

-- 3. LOGICA DA TECLA "Q" E "X"
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.Q then
		modoDeletarAtivo = false
		modoConstrucaoAtivo = not modoConstrucaoAtivo

		if modoConstrucaoAtivo then
			blocoFantasma.Transparency = 0.8
			blocoFantasma.Color = Color3.fromRGB(0, 255, 0)
			print("Modo Construção: LIGADO")
		else
			blocoFantasma.Transparency = 1
			print("Modo Construção: DESLIGADO")
		end
	end

	if input.KeyCode == Enum.KeyCode.X then
		modoConstrucaoAtivo = false
		modoDeletarAtivo = not modoDeletarAtivo

		if modoDeletarAtivo then
			blocoFantasma.Transparency = 0.8
			blocoFantasma.Color = Color3.fromRGB(255, 0, 0)
			print("Modo Deletar: LIGADO")
		else
			blocoFantasma.Transparency = 1
			print("Modo Deletar: DESLIGADO")
		end
	end
end)

-- 4. ATUALIZANDO A POSIÇÃO
RunService.RenderStepped:Connect(function()
	-- Corrigido os parênteses para a lógica funcionar perfeitamente
	if (modoConstrucaoAtivo or modoDeletarAtivo) and mouse.Hit then
		local posicaoReal = mouse.Hit.Position
		local posicaoGrid = travarNoGrid(posicaoReal)
		blocoFantasma.Position = posicaoGrid
	end
end)

-- 5. CRIANDO O BLOCO QUANDO CLICAR
mouse.Button1Down:Connect(function()
	if modoConstrucaoAtivo then
		local posicaoClicado = mouse.Hit.Position
		local posicaoBloco = travarNoGrid(posicaoClicado)
		local novoBloco = blocoFantasma:Clone()
		novoBloco.Position = posicaoBloco
		novoBloco.Transparency = 0
		novoBloco.Parent = workspace
	end
end)

-- ==========================================
-- 6. SISTEMA DE INVENTÁRIO COM TWEEN E UISTROKE
-- ==========================================
local inventarioUI = gui:WaitForChild("InventarioUI")
local painel = inventarioUI:WaitForChild("Painel")

-- Mapeando os botões
local botoes = {
	[painel:WaitForChild("BtnToalete")] = "Toalete Basico",
	[painel:WaitForChild("BtnGerador")] = "Gerador de Brainrot",
	[painel:WaitForChild("BtnMuro")] = "Parede Neon"
}

-- Configurações de Tamanho e Borda
local TAMANHO_NORMAL = UDim2.new(0.114, 0, 0.67, 0)
local TAMANHO_SELECIONADO = UDim2.new(0.125, 0, 0.73, 0) -- Levemente maior

local COR_BORDA_NORMAL = Color3.fromRGB(0, 0, 0) -- Preto
local COR_BORDA_SELECIONADA = Color3.fromRGB(255, 255, 255) -- Branco
local ESPESSURA_NORMAL = 1
local ESPESSURA_SELECIONADA = 4

-- Função para resetar todos os botões pro estado original
local function resetarBotoes()
	for btn, _ in pairs(botoes) do
		-- Puxa o UIStroke de dentro do botão (que vi no seu print)
		local stroke = btn:FindFirstChild("UIStroke")
		if stroke then
			stroke.Color = COR_BORDA_NORMAL
			stroke.Thickness = ESPESSURA_NORMAL
		end

		-- Anima de volta pro tamanho normal
		TweenService:Create(btn, TweenInfo.new(0.1), {Size = TAMANHO_NORMAL}):Play()
	end
end

-- O loop que escuta o clique
for botao, nomeDoItem in pairs(botoes) do
	botao.MouseButton1Click:Connect(function()
		itemSelecionado = nomeDoItem
		print("Equipado: " .. itemSelecionado)

		-- Limpa os outros botões e aplica o destaque neste
		resetarBotoes()

		local stroke = botao:FindFirstChild("UIStroke")
		if stroke then
			stroke.Color = COR_BORDA_SELECIONADA
			stroke.Thickness = ESPESSURA_SELECIONADA
		end

		-- Animação do botão "pulando" pra frente
		local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(botao, tweenInfo, {Size = TAMANHO_SELECIONADO}):Play()

		-- Configurações do modo construção
		modoDeletarAtivo = false
		modoConstrucaoAtivo = true
		blocoFantasma.Transparency = 0.5

		-- Mudar o formato do preview dependendo do item selecionado
		if itemSelecionado == "Parede Neon" then
			blocoFantasma.Size = Vector3.new(8, 4, 2)
			blocoFantasma.Color = Color3.fromRGB(255, 0, 255)
		else
			blocoFantasma.Size = Vector3.new(4, 4, 4)
			blocoFantasma.Color = Color3.fromRGB(255, 255, 0)
		end
	end)
end
