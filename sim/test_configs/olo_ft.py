# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2026 by Julian Schneider
# All rights reserved.
# Authors: Julian Schneider
# ---------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------------------------------
from .utils import named_config

# ---------------------------------------------------------------------------------------------------
# Functionality
# ---------------------------------------------------------------------------------------------------

def add_configs(olo_tb):
    """
    Add all fault-tolerant testbench configurations to the VUnit Library
    :param olo_tb: Testbench library
    """

    # Width sweep: two powers of two and one non-power-of-two to exercise the SECDED math
    # at an "odd" width.
    Widths = [8, 13, 32]

    ### olo_ft_ecc_encode ###
    # Encoder Pipeline_g is capped at 0..1 (combinational or one register near output).
    tb = olo_tb.test_bench('olo_ft_ecc_encode_tb')
    for Width in Widths:
        named_config(tb, {'Width_g': Width})
    for Pipeline in [0, 1]:
        named_config(tb, {'Pipeline_g': Pipeline})
    # Backpressure coverage: exercise the codec's UseReady_g=true shadow-register path with
    # randomized stalls on both ends. Sweeps Pipeline_g so both the pass-through (Pipeline_g=0)
    # and the registered (Pipeline_g=1) configurations are stressed.
    for Pipeline in [0, 1]:
        named_config(tb, {'Stalling_g': True, 'Pipeline_g': Pipeline})

    ### olo_ft_ecc_decode ###
    # Decoder Pipeline_g is capped at 0..2 (combinational / register-near-output /
    # distributed pipeline). Same width sweep as encode.
    tb = olo_tb.test_bench('olo_ft_ecc_decode_tb')
    for Width in Widths:
        named_config(tb, {'Width_g': Width})
    for Pipeline in [0, 1, 2]:
        named_config(tb, {'Pipeline_g': Pipeline})
    # Backpressure coverage: exercise the codec's UseReady_g=true shadow-register path with
    # randomized stalls on both ends. Pipeline_g=2 in particular places back-to-back beats
    # in the syndrome stage and the correction stage simultaneously, which is the most
    # demanding configuration for the distributed pipeline.
    for Pipeline in [0, 1, 2]:
        named_config(tb, {'Stalling_g': True, 'Pipeline_g': Pipeline})

    ### olo_ft_private_scrubber ###
    # Unit test bench for the private scrubber engine (behavioral RAM model, direct port control).
    # It deliberately does NOT use run_all_in_same_sim so the test cases can carry per-test
    # configurations: free-running cases sweep TotalReadLatency_g x SinglePortRam_g, paced cases
    # enable the pacer through the integer ScrubPeriodMs_g generic (GHDL cannot override real
    # generics on the command line; the TB converts to the real ScrubPeriod_g at the generic map).
    tb = olo_tb.test_bench('olo_ft_private_scrubber_tb')
    free_running_tests = [
        'FreeRunPassCadence',
        'ScrubRepairsSec',
        'ScrubDoesNotWriteDed',
        'PartialTrafficCompletesPass',
        'ReadSaturationStarves',
        'WriteTrafficBlocksWriteback',
        'UserWriteToInFlightAddrSweep',
        'AbortPreservesAddr',
        'WritebackDataStableDuringWait',
        'EnableSuspendsScrubbing',
        'ResetMidPassSweep',
    ]
    paced_tests = [
        'PacedOnePassPerPeriod',
        'PacedOverrunWhenStarved',
        'PacedEnableDropNoOverrun',
        'PacedRepairsSec',
    ]
    for name in free_running_tests:
        test = tb.test(name)
        for Latency in [1, 2, 3]:
            for SinglePort in [False, True]:
                named_config(test, {'TotalReadLatency_g': Latency, 'SinglePortRam_g': SinglePort})
    for name in paced_tests:
        test = tb.test(name)
        for Latency, SinglePort in [(1, False), (3, False), (1, True)]:
            named_config(test, {'TotalReadLatency_g': Latency, 'SinglePortRam_g': SinglePort,
                                'ScrubClkHz_g': 10000, 'ScrubPeriodMs_g': 15})


    ### olo_ft_ram_tdp ###
    tb = olo_tb.test_bench('olo_ft_ram_tdp_tb')
    for RamBehav in ['RBW', 'WBR']:
        named_config(tb, {'RamBehavior_g': RamBehav})
    for ReadLatency in [1, 2]:
        named_config(tb, {'RamRdLatency_g': ReadLatency})
    for Width in Widths:
        named_config(tb, {'Width_g': Width})
    for EccPipeline in [0, 1, 2]:
        named_config(tb, {'EccPipeline_g': EccPipeline})

    ### olo_ft_ram_sdp ###
    tb = olo_tb.test_bench('olo_ft_ram_sdp_tb')
    for RamBehav in ['RBW', 'WBR']:
        for Async in [True, False]:
            named_config(tb, {'RamBehavior_g': RamBehav, 'IsAsync_g': Async})
    for ReadLatency in [1, 2]:
        named_config(tb, {'RamRdLatency_g': ReadLatency})
    for Width in Widths:
        named_config(tb, {'Width_g': Width})
    for EccPipeline in [0, 1, 2]:
        named_config(tb, {'EccPipeline_g': EccPipeline})

    ### olo_ft_ram_sdp_scrub ###
    tb = olo_tb.test_bench('olo_ft_ram_sdp_scrub_tb')
    for RamBehav in ['RBW', 'WBR']:
        named_config(tb, {'RamBehavior_g': RamBehav})
    for RamRdLatency in [1, 2]:
        for EccPipeline in [0, 1, 2]:
            named_config(tb, {'RamRdLatency_g': RamRdLatency,
                              'EccPipeline_g': EccPipeline})
    for Width in Widths:
        named_config(tb, {'Width_g': Width})

    ### olo_ft_ram_sp ###
    tb = olo_tb.test_bench('olo_ft_ram_sp_tb')
    for RamBehav in ['RBW', 'WBR']:
        named_config(tb, {'RamBehavior_g': RamBehav})
    for ReadLatency in [1, 2]:
        named_config(tb, {'RamRdLatency_g': ReadLatency})
    for Width in Widths:
        named_config(tb, {'Width_g': Width})
    for EccPipeline in [0, 1]:
        named_config(tb, {'EccPipeline_g': EccPipeline})

    ### olo_ft_ram_sp_scrub ###
    tb = olo_tb.test_bench('olo_ft_ram_sp_scrub_tb')
    for RamBehav in ['RBW', 'WBR']:
        named_config(tb, {'RamBehavior_g': RamBehav})
    for RamRdLatency in [1, 2]:
        for EccPipeline in [0, 1, 2]:
            named_config(tb, {'RamRdLatency_g': RamRdLatency,
                              'EccPipeline_g': EccPipeline})
    for Width in Widths:
        named_config(tb, {'Width_g': Width})

    ### olo_ft_fifo_sync ###
    tb = olo_tb.test_bench('olo_ft_fifo_sync_tb')
    for Width in Widths:
        named_config(tb, {'Width_g': Width})
    # Sweep the full entity range (0..2), matching the ft RAM test benches
    for EccPipeline in [0, 1, 2]:
        named_config(tb, {'EccPipeline_g': EccPipeline})

    ### olo_ft_fifo_async ###
    tb = olo_tb.test_bench('olo_ft_fifo_async_tb')
    for Width in Widths:
        named_config(tb, {'Width_g': Width})
    for Opt in ['SPEED', 'LATENCY']:
        named_config(tb, {'Optimization_g': Opt})
    # Sweep the full entity range (0..2), matching the ft RAM test benches
    for EccPipeline in [0, 1, 2]:
        named_config(tb, {'EccPipeline_g': EccPipeline})

    ### olo_ft_fifo_packet ###
    tb = olo_tb.test_bench('olo_ft_fifo_packet_tb')
    for Width in Widths:
        named_config(tb, {'Width_g': Width})
    for FeatureSet in ['FULL', 'DROP_ONLY']:
        named_config(tb, {'FeatureSet_g': FeatureSet})
    # Sweep the full entity range (0..2), matching the ft RAM test benches
    for EccPipeline in [0, 1, 2]:
        named_config(tb, {'EccPipeline_g': EccPipeline})

    ### olo_ft_cc_pulse ###
    tb = olo_tb.test_bench('olo_ft_cc_pulse_tb')
    # Clock ratios within the valid range for the Fig. 14 pulse handshake.
    # Design constraint: input pulse must return to zero before the feedback round-trip
    # completes (approximately f_out < SyncStages_g * f_in).
    for N, D in [(1, 1), (3, 2), (2, 3), (1, 5), (2, 5)]:
        named_config(tb, {'ClockRatio_N_g': N, 'ClockRatio_D_g': D})
    for Stages in [3, 4]:
        named_config(tb, {'SyncStages_g': Stages})

    ### olo_ft_cc_bits ###
    tb = olo_tb.test_bench('olo_ft_cc_bits_tb')
    # Same clock-ratio coverage as olo_base_cc_bits
    for N, D in [(1, 1), (3, 2), (2, 3), (5, 1), (1, 5)]:
        named_config(tb, {'ClockRatio_N_g': N, 'ClockRatio_D_g': D})
    for Stages in [2, 3, 4]:
        named_config(tb, {'SyncStages_g': Stages})

    ### olo_ft_cc_reset ###
    tb = olo_tb.test_bench('olo_ft_cc_reset_tb')
    for N, D in [(1, 1), (3, 2), (2, 3), (5, 1), (1, 5)]:
        named_config(tb, {'ClockRatio_N_g': N, 'ClockRatio_D_g': D})
    for Stages in [2, 3, 4]:
        named_config(tb, {'SyncStages_g': Stages})
