-- Mapeamento Raridade → Torres disponíveis na loja.
-- Para adicionar uma nova torre: inserir o nome (igual ao TowerStats) no array correto.
local StoreItems: { [string]: { string } } = {
	Comum    = { "Toalete Basico", "Mortair" },
	Raro     = { "Gerador de Brainrot" },
	Lendario = {},
}

return StoreItems
