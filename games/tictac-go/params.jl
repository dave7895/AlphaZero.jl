Network = SimpleNet

netparams = SimpleNetHP(
    width = 200,
    depth_common = 8,
    use_batch_norm = true,
    batch_norm_momentum = 1.0,
)

self_play = SelfPlayParams(
    num_games = 2000,
    mcts = MctsParams(
        use_gpu = true,
        num_workers = 1,
        num_iters_per_turn = 200,
        cpuct = 1.0,
        temperature = ConstSchedule(1.0),
        dirichlet_noise_ϵ = 0.2,
        dirichlet_noise_α = 1.0,
    ),
)

arena = ArenaParams(
    num_games = 10,
    reset_mcts_every = 1,
    update_threshold = 0.00,
    flip_probability = 0.5,
    mcts = MctsParams(
        self_play.mcts,
        temperature = ConstSchedule(0.3),
        dirichlet_noise_ϵ = 0.1,
    ),
)

learning = LearningParams(
    samples_weighing_policy = LOG_WEIGHT,
    l2_regularization = 1e-4,
    optimiser = CyclicNesterov(
        lr_base = 1e-3,
        lr_high = 1e-2,
        lr_low = 1e-3,
        momentum_high = 0.9,
        momentum_low = 0.8,
    ),
    batch_size = 24,
    loss_computation_batch_size = 1024,
    nonvalidity_penalty = 1.0,
    min_checkpoints_per_epoch = 0,
    max_batches_per_checkpoint = 5_000,
    num_checkpoints = 1,
)

params = Params(
    arena = arena,
    self_play = self_play,
    learning = learning,
    num_iters = 10,
    memory_analysis = MemAnalysisParams(num_game_stages = 5),
    ternary_rewards = true,
    use_symmetries = false,
    mem_buffer_size = PLSchedule(80_000),
)
benchMcts = MctsParams(
    use_gpu = false,
    num_workers = 1,
    num_iters_per_turn = 100,
    cpuct = 0.9,
    temperature = ConstSchedule(1.0),
    dirichlet_noise_ϵ = 0.2,
    dirichlet_noise_α = 1.0,
)
benchmark = [
    Benchmark.Duel(
        Benchmark.NetworkOnly(),
        Benchmark.MctsRollouts(benchMcts),
        num_games = 20,
        flip_probability = 0.5,
    ),
    Benchmark.Duel(
        Benchmark.Full(self_play.mcts),
        Benchmark.MctsRollouts(self_play.mcts),
        num_games = 20,
        flip_probability = 0.4,
    ),
]
