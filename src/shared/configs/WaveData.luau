-- Configuração do gerador procedural de waves.
-- Edite aqui para ajustar dificuldade, inimigos e recompensas sem tocar no WaveService.

return {

	-- Pool de inimigos comuns. unlockWave = wave mínima para esse inimigo aparecer.
	enemyPool = {
		{
			name       = "Bung Bung",
			baseHP     = 80,
			baseSpeed  = 12,
			speedCap   = 18,   -- velocidade máxima que esse inimigo pode atingir
			baseCount  = 5,
			interval   = 2.0,
			unlockWave = 1,
		},
		{
			name       = "Jota Ele Dim Dim Dim",
			baseHP     = 60,
			baseSpeed  = 22,
			speedCap   = 32,
			baseCount  = 3,
			interval   = 2.5,
			unlockWave = 3,
		},
	},

	-- Boss único spawnado a cada `bossEvery` waves. HP cresce a cada aparição.
	boss = {
		name      = "Bailarina Sapatina Boss",
		baseHP    = 800,
		hpPerBoss = 500,   -- wave 10 = 800 HP, wave 20 = 1300 HP, wave 30 = 1800 HP …
		speed     = 7,
		interval  = 1,
	},

	bossEvery = 10,   -- boss nas waves 10, 20, 30 …

	scaling = {
		hpGrowth       = 0.15,  -- +15% HP por wave
		countGrowth    = 0.8,   -- +0.8 inimigos por wave desbloqueada
		intervalDecay  = 0.05,  -- intervalo de spawn -0.05s por wave desbloqueada
		intervalMin    = 0.5,   -- intervalo mínimo (s)
		speedGrowth    = 0.3,   -- +0.3 speed por wave desbloqueada
		rewardBase     = 100,   -- recompensa na wave 1
		rewardGrowth   = 50,    -- +$50 por wave
		bossRewardMult = 3,     -- waves de boss pagam 3×
	},
}
