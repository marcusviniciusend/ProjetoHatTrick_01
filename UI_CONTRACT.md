# Contrato de UI — BrainrotTD
> **Leia antes de criar qualquer elemento no Roblox Studio.**
> O código busca elementos pelos **nomes exatos** listados aqui.
> Um nome errado = feature silenciosamente desativada (sem crash, mas sem funcionar).

---

## ⚠️ Regra Mestra de Arquitetura — Graceful Degradation

O backend **nunca depende** da existência de uma GUI para funcionar.

- O servidor dispara RemoteEvents informando mudanças de estado (inventário, arma equipada, wave, etc.) independentemente de qualquer tela existir
- Os Controllers usam `FindFirstChild` para buscar elementos. Se não encontrar: `warn` silencioso, sem crash, sem quebrar o jogo
- A lógica de combate, dados e waves funciona de forma invisível até que as telas sejam "dropadas" no Studio
- **Nunca adicione `LocalScript` avulsos dentro das GUIs** — toda lógica fica nos Controllers do VS Code

---

## Regras Gerais de Nomenclatura

- **Nunca renomeie** um elemento marcado como `OBRIGATÓRIO`
- Elementos `OPCIONAL` podem não existir — o código lida silenciosamente
- `TextLabel` extras dentro de cards/templates com nome diferente dos mapeados terão `.Text = ""` aplicado automaticamente em runtime (anti-placeholder)
- Decoração livre: `UICorner`, `UIStroke`, `UIGradient`, `ImageLabel`, frames extras de estética não interferem no código

---

## RemoteEvents — Contrato de Comunicação

> A equipe de UI deve escutar estes eventos nos Controllers. O servidor os dispara independentemente da UI existir.

### Torres e Waves
| RemoteEvent | Direção | Quando dispara | O que a UI faz |
|---|---|---|---|
| `PlotAssigned` | Server → Client | Plot atribuído ao jogador | HUDController conecta watcher de HP da base |
| `PhaseChanged` | Server → Client | BuildPhase ↔ CombatPhase | Alterna botões Start/End, bloqueia inventário |
| `WaveUpdate` | Server → Client | Início/fim de wave, countdown | Atualiza `WaveLabel` e `WaveStatusLabel` |
| `PlayerDefeated` | Server → Client | HP da base chega a 0 | Exibe `GameEndFrame` |

### Armas
| RemoteEvent | Direção | Quando dispara | O que a UI faz |
|---|---|---|---|
| `WeaponInventoryUpdated` | Server → Client | Ao comprar ou receber drop | Repopula `WeaponInventoryGui` |
| `WeaponEquipped` | Server → Client | Ao confirmar equip | Atualiza destaque no inventário + `EquippedLabel` |
| `WeaponDropped` | Server → Client | Ao matar boss de wave especial | Exibe `WeaponDropNotification` por 4s e some |
| `OpenWeaponShop` | Server → Client | Proximidade com NPC Armeiro | Abre `WeaponShopGui` |

### RemoteFunctions
| RemoteFunction | Direção | Uso |
|---|---|---|
| `GetMyPlot` | Client → Server | HUDController busca plot proativamente no init (fix race condition) |
| `GetInventory` | Client → Server | UIController busca torres do inventário |
| `GetWeaponInventory` | Client → Server | WeaponController busca armas do jogador |
| `GetEquippedWeapon` | Client → Server | WeaponController busca arma equipada atual |
| `PlaceTower` | Client → Server | PlacementController coloca torre no plot |
| `RequestTowerAction` | Client → Server | Upgrade ou venda de torre colocada |
| `BuyShopItem` | Client → Server | Compra torre na loja de torres |
| `BuyWeapon` | Client → Server | Compra arma na loja de armas |
| `WeaponFire` | Client → Server | Disparo da arma (validado server-side) |

---

## 1. HotbarGui `OBRIGATÓRIO`

Localização: `StarterGui > HotbarGui`

```
HotbarGui                     (ScreenGui)
└─ MainFrame                  [Frame]          OBRIGATÓRIO
   ├─ Build_btn               [TextButton]     OBRIGATÓRIO — abre inventário de torres (tecla 1)
   ├─ Delete_btn              [TextButton]     OBRIGATÓRIO — modo deletar torre (tecla 2)
   └─ Weapon_btn              [TextButton]     OBRIGATÓRIO — modo arma (tecla 3)
└─ Templates                  [Folder]         OBRIGATÓRIO
   └─ hbItem                  [Frame]          OBRIGATÓRIO — template do card de torre
      ├─ Name                 [TextLabel]      OBRIGATÓRIO — nome da torre
      └─ Qtd                  [TextLabel]      OBRIGATÓRIO — quantidade (ex: "3x")
```

> ⚠️ `TextLabel` extras dentro do `hbItem` com nome diferente de `"Name"` e `"Qtd"` terão `.Text = ""` aplicado automaticamente.

**Comportamento automático:**
- `Build_btn` / tecla `1` → alterna `InventoryOpen` ↔ `Idle`
- `Delete_btn` / tecla `2` → alterna `DeletingTower` ↔ `Idle`
- `Weapon_btn` / tecla `3` → alterna `WeaponMode` ↔ `Idle`
- Em `WeaponMode`: `TowersGui` fecha, build e delete ficam bloqueados
- Em `CombatPhase`: build e delete bloqueados; `WeaponMode` disponível
- Em `BuildPhase`: `WeaponMode` bloqueado

---

## 2. HudUI `OBRIGATÓRIO`

Localização: `StarterGui > HudUI`

```
HudUI                         (ScreenGui)
└─ Frame                      [Frame]          OBRIGATÓRIO
   ├─ PlotButton              [TextButton]     OBRIGATÓRIO — teleporte para o plot
   ├─ StoreButton             [TextButton]     OBRIGATÓRIO — teleporte para a loja de torres
   ├─ BaseHPLabel             [TextLabel]      OBRIGATÓRIO — exibe HP da base (ex: "Base: 80")
   ├─ MoneyLabel              [TextLabel]      OBRIGATÓRIO — exibe dinheiro (ex: "$1200")
   ├─ WaveLabel               [TextLabel]      OBRIGATÓRIO — exibe "Wave 4" ou "Wave 4 [BOSS]"
   └─ WaveStatusLabel         [TextLabel]      OBRIGATÓRIO — exibe status (ex: "EM ANDAMENTO")
└─ GameEndFrame               [Frame]          OPCIONAL
   ├─ TitleLabel              [TextLabel]      OPCIONAL — ex: "DERROTA!"
   ├─ SubLabel                [TextLabel]      OPCIONAL — ex: "Base destruída na wave 4"
   └─ RestartButton           [TextButton]     OPCIONAL — fecha o painel
└─ StartWaveButton            [TextButton]     OBRIGATÓRIO — inicia o combate
└─ EndWaveButton              [TextButton]     OBRIGATÓRIO — encerra o combate manualmente
```

**Comportamento automático:**
- `StartWaveButton` visível na BuildPhase, oculto na CombatPhase
- `EndWaveButton` visível na CombatPhase, oculto na BuildPhase
- `GameEndFrame` aparece ao HP da base chegar a 0 — some ao voltar pra BuildPhase
- `BaseHPLabel` atualiza em tempo real via watcher no `IntValue` da base do plot
- `MoneyLabel` atualiza em tempo real via `leaderstats.Money`

---

## 3. TowersGui (Inventário de Torres) `OBRIGATÓRIO`

Localização: `StarterGui > TowersGui`

```
TowersGui                     (ScreenGui)
└─ MainFrame                  [Frame]          OBRIGATÓRIO
   ├─ ScrollingFrame          [ScrollingFrame] OBRIGATÓRIO — lista de cards de torres
   ├─ StatsPanel              [Frame]          OPCIONAL — painel de stats no hover do card
   ├─ UICorner                [UICorner]       OPCIONAL — estética
   └─ UIStroke                [UIStroke]       OPCIONAL — estética
```

> Cards são gerados dinamicamente a partir do template `hbItem` (ver HotbarGui > Templates). Não adicione cards manualmente no `ScrollingFrame`.

**Comportamento automático:**
- Abre ao clicar `Build_btn` ou pressionar `1` (estado `InventoryOpen`)
- Fecha em `CombatPhase` e em `WeaponMode`
- `StatsPanel` exibe Dano, Alcance e Cooldown ao passar o mouse sobre um card

---

## 4. TowerInfoPanel (Upgrade e Venda de Torre) `OPCIONAL`

Localização: qualquer lugar no `StarterGui` (buscado com `FindFirstChild` recursivo)

> Ainda não existe no Studio. A lógica está 100% pronta — basta criar o Frame com os nomes abaixo.

```
TowerInfoPanel                [Frame]          OPCIONAL
├─ NameLabel                  [TextLabel]      OPCIONAL — "NomeDaTorre — Lv.2"
├─ StatsLabel                 [TextLabel]      OPCIONAL — stats atuais vs próximo nível
├─ NextStatsLabel             [TextLabel]      OPCIONAL — "Nível máximo" se maxado
├─ UpgradeButton              [TextButton]     OPCIONAL — "Upgrade $200"
├─ SellButton                 [TextButton]     OPCIONAL — "Vender +$100"
└─ CloseButton                [TextButton]     OPCIONAL — fecha o painel
```

**Comportamento automático:**
- Abre ao clicar numa torre colocada no plot
- `UpgradeButton` some se a torre estiver no nível máximo
- Fecha ao clicar fora ou em `CloseButton`
- Atualiza em tempo real se o dinheiro mudar enquanto o painel está aberto

---

## 5. ShopGui (Loja de Torres) `OBRIGATÓRIO`

Localização: `StarterGui > ShopGui`

```
ShopGui                       (ScreenGui)
└─ MainFrame                  [Frame]          OBRIGATÓRIO
   ├─ CloseButton             [TextButton]     OBRIGATÓRIO — fecha a loja
   ├─ RefreshButton           [TextButton]     OPCIONAL — futuro
   └─ Background              [Frame]          OBRIGATÓRIO
      └─ ScrollingFrame       [ScrollingFrame] OBRIGATÓRIO
         └─ ItemCard_Template [Frame]          OBRIGATÓRIO — template (Visible = false)
            ├─ TowerName      [TextLabel]      OBRIGATÓRIO — nome da torre
            ├─ PriceText      [TextLabel]      OBRIGATÓRIO — preço (ex: "$500")
            ├─ Rarity         [TextLabel]      OBRIGATÓRIO — raridade (ex: "Comum")
            ├─ StockCount     [TextLabel]      OBRIGATÓRIO — estoque (ex: "x3 left")
            └─ BuyButton      [ImageButton]    OBRIGATÓRIO — botão de compra
```

**Comportamento automático:**
- Abre via `OpenShop` (RemoteEvent do servidor ao entrar na área)
- Estoque e preços atualizados automaticamente via `ShopUpdated`
- Torres exibidas nos pedestais 3D automaticamente (`Workspace > TowerNPC > Pedestal1..5`)

---

## 6. WeaponShopGui (Loja de Armas) `OPCIONAL`

Localização: `StarterGui > WeaponShopGui`

> GUI separada do `ShopGui`. Aberta pelo NPC **Armeiro** via `ProximityPrompt`.
> No MVP: auto-equip ao comprar. `WeaponInventoryGui` para troca manual vem depois.

```
WeaponShopGui                 (ScreenGui)
└─ MainFrame                  [Frame]          OBRIGATÓRIO
   ├─ CloseButton             [TextButton]     OBRIGATÓRIO — fecha a loja
   └─ ScrollingFrame          [ScrollingFrame] OBRIGATÓRIO
      └─ WeaponCard_Template  [Frame]          OBRIGATÓRIO — template (Visible = false)
         ├─ WeaponName        [TextLabel]      OBRIGATÓRIO — nome da arma
         ├─ WeaponType        [TextLabel]      OBRIGATÓRIO — "Melee" ou "Ranged"
         ├─ PriceText         [TextLabel]      OBRIGATÓRIO — preço (ex: "$300")
         ├─ DamageText        [TextLabel]      OPCIONAL — stat de dano
         ├─ PassiveText       [TextLabel]      OPCIONAL — descrição da passiva
         └─ BuyButton         [TextButton]     OBRIGATÓRIO — comprar arma
```

> ⚠️ Armas especiais (drops de boss) **nunca aparecem aqui** — só as 3 da loja.
> ⚠️ `WeaponCard_Template` deve ter `Visible = false`.

**Armas disponíveis na loja (geradas dinamicamente):**
| Arma | Tipo | Passiva |
|---|---|---|
| Espada dos Bárbaros | Melee | — |
| Arco e Flecha das Arqueiras | Ranged | — |
| Adagas dos Goblins | Melee | +1 moeda por acerto |

---

## 7. WeaponInventoryGui (Inventário de Armas) `OPCIONAL`

Localização: `StarterGui > WeaponInventoryGui`

> No MVP: auto-equip ao receber arma. Esta tela existe para trocar armas manualmente no futuro.

```
WeaponInventoryGui            (ScreenGui)
└─ MainFrame                  [Frame]          OBRIGATÓRIO
   ├─ CloseButton             [TextButton]     OBRIGATÓRIO — fecha o inventário
   ├─ EquippedLabel           [TextLabel]      OPCIONAL — nome da arma equipada
   └─ ScrollingFrame          [ScrollingFrame] OBRIGATÓRIO
      └─ WeaponSlot_Template  [Frame]          OBRIGATÓRIO — template (Visible = false)
         ├─ WeaponName        [TextLabel]      OBRIGATÓRIO — nome da arma
         ├─ WeaponType        [TextLabel]      OPCIONAL — "Melee" / "Ranged"
         ├─ IsSpecialLabel    [TextLabel]      OPCIONAL — "⚡ Especial" se for drop de boss
         └─ EquipButton       [TextButton]     OBRIGATÓRIO — equipar esta arma
```

**Comportamento automático:**
- Populado via `WeaponInventoryUpdated` (RemoteEvent)
- `EquipButton` dispara `WeaponEquip` pro servidor — servidor confirma e dispara `WeaponEquipped`
- Arma equipada fica destacada visualmente (destaque via código, não manual)

---

## 8. WeaponDropNotification (Notificação de Boss Drop) `OPCIONAL`

Localização: qualquer lugar no `StarterGui` (buscado com `FindFirstChild` recursivo)

> Frame flutuante épico. **Some automaticamente após 4 segundos.** Sem botão de fechar — não trava o jogador durante o caos da wave.

```
WeaponDropNotification        [Frame]          OPCIONAL
├─ WeaponNameLabel            [TextLabel]      OPCIONAL — nome da arma (ex: "Espada do Rei Bárbaro")
├─ WeaponTypeLabel            [TextLabel]      OPCIONAL — "Melee" / "Ranged"
└─ FlavorLabel                [TextLabel]      OPCIONAL — texto épico (ex: "Arma lendária obtida!")
```

> Se o frame não existir, a notificação é silenciosa — nenhum erro gerado.

**Mapeamento boss → arma:**
| Wave | Arma dropada | Tipo |
|---|---|---|
| 100 | Espada do Rei Bárbaro | Melee — Cleave |
| 200 | Besta da Rainha Arqueira | Ranged — projétil ultra-rápido |
| 300 | Cajado da Bruxa | Ranged — Splash Damage |
| 400 | Cajado da Bruxa Sombria | Melee — alto dano |

---

## 9. Workspace (Objetos 3D referenciados pelo código)

```
Workspace
└─ Map
   └─ Plots
      └─ [NomeDoPLot]         [Model]
         ├─ SpawnPoint        [BasePart]  OBRIGATÓRIO — ponto de spawn do jogador no plot
         ├─ Base              [BasePart]  OBRIGATÓRIO — base que os inimigos atacam
         │  └─ HP             [IntValue]  OBRIGATÓRIO — HP inicial (ex: 100)
         └─ Waypoints         [Folder]    OBRIGATÓRIO
            ├─ 1              [BasePart]  — primeiro waypoint dos inimigos
            ├─ 2              [BasePart]
            └─ ...            (sequencial, sem pular números)
└─ TowerNPC                   [Model]     — área da loja de torres
   ├─ PrimaryPart             [BasePart]  — âncora do relógio de rotação
   ├─ Pedestal1               [BasePart/Model] — vitrine da torre 1
   ├─ Pedestal2               ...
   └─ Pedestal5               (até 5 pedestais)
└─ StoreTp                    [BasePart]  — destino do teleporte "Store"
└─ Armeiro                    [Model]     — NPC da loja de armas
   └─ PrimaryPart             [BasePart]  — âncora do ProximityPrompt
```

---

## Checklist para a Equipe de UI/HUD

Antes de "dropar" uma GUI no Studio, confirme:

- [ ] O nome da ScreenGui está **exato** conforme este contrato
- [ ] A hierarquia interna (quais frames ficam dentro de quais) está **exata**
- [ ] Elementos `OBRIGATÓRIO` existem com o **nome exato** (case-sensitive)
- [ ] Templates de cards têm `Visible = false`
- [ ] Nenhum `LocalScript` foi adicionado dentro da GUI
- [ ] Testou no Studio e verificou no Output que nenhum `warn` de "não encontrado" disparou

---

## Resumo de Regras

| | Posso renomear? | Posso mover? | Posso adicionar filhos? |
|---|---|---|---|
| **OBRIGATÓRIO** | ❌ Nunca | ❌ Respeitar hierarquia | ✅ Decoração livre |
| **OPCIONAL** | ✅ Com cuidado | ✅ Qualquer lugar no StarterGui | ✅ Decoração livre |
| **Templates** | ❌ Nunca o template | ✅ Dentro da GUI correta | ✅ Mas TextLabels extras terão texto limpo |
