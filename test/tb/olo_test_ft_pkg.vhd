---------------------------------------------------------------------------------------------------
-- Copyright (c) 2026 by Julian Schneider
-- Authors: Julian Schneider
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Description
---------------------------------------------------------------------------------------------------
-- Shared test procedures for the fault-tolerant (ft) area test benches: user-port write helpers
-- and ECC read checks for the ECC RAM wrappers, scrub-pass synchronization helpers for the
-- scrubbed variants, and AXI-Stream push/expect helpers for the ECC FIFO wrappers.

---------------------------------------------------------------------------------------------------
-- Libraries
---------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

library olo;
    use olo.olo_base_pkg_math.all;
    use olo.olo_ft_pkg_ecc.all;

---------------------------------------------------------------------------------------------------
-- Package Header
---------------------------------------------------------------------------------------------------
package olo_test_ft_pkg is

    -- Single-cycle write through a user write port.
    procedure ft_write (
        address        : in natural;
        data           : in natural;
        signal clk     : in std_logic;
        signal addr    : out std_logic_vector;
        signal wr_data : out std_logic_vector;
        signal wr_ena  : out std_logic);

    -- Arm the error injection for the next write (latched by the DUT until a write consumes it).
    procedure ft_preload_flip (
        flip_bits        : in std_logic_vector;
        signal clk       : in std_logic;
        signal inj_flip  : out std_logic_vector;
        signal inj_valid : out std_logic);

    -- Single-cycle write with simultaneous error injection.
    procedure ft_write_flip (
        address          : in natural;
        data             : in natural;
        flip_bits        : in std_logic_vector;
        signal clk       : in std_logic;
        signal addr      : out std_logic_vector;
        signal wr_data   : out std_logic_vector;
        signal wr_ena    : out std_logic;
        signal inj_flip  : out std_logic_vector;
        signal inj_valid : out std_logic);

    -- Issue a user read and check data and ECC flags after the given read latency.
    procedure ft_check_ecc (
        address         : in natural;
        data            : in natural;
        exp_ecc_sec     : in std_logic;
        exp_ecc_ded     : in std_logic;
        latency         : in natural;
        signal clk      : in std_logic;
        signal addr     : out std_logic_vector;
        signal rd_ena   : out std_logic;
        signal rd_data  : in std_logic_vector;
        signal rd_valid : in std_logic;
        signal ecc_sec  : in std_logic;
        signal ecc_ded  : in std_logic;
        message         : in string;
        check_data      : in boolean := true);

    -- Wait for a given number of completed scrub passes (pass_done pulses).
    procedure ft_wait_passes (
        passes           : in positive;
        signal clk       : in std_logic;
        signal pass_done : in std_logic);

    -- Like ft_wait_passes, but also tally how many cycles a watched signal was high over the window.
    procedure ft_count_over_passes (
        passes           : in positive;
        signal clk       : in std_logic;
        signal pass_done : in std_logic;
        signal watched   : in std_logic;
        watched_count    : out natural);

    -- Push one beat through an AXI-Stream master VC. A non-zero flip_bits pattern first arms the
    -- DUT's error-injection latch (drained handshake, one-cycle inj_valid pulse) so the flip is
    -- applied to exactly this beat's codeword.
    procedure ft_push_beat (
        signal net       : inout network_t;
        master           : in axi_stream_master_t;
        signal clk       : in std_logic;
        signal inj_flip  : out std_logic_vector;
        signal inj_valid : out std_logic;
        data             : in std_logic_vector;
        flip_bits        : in std_logic_vector;
        last             : in std_logic := '1');

    -- Queue the expected (data, tuser, tlast) outcome of a beat pushed with the given flip
    -- pattern: the decoder's deterministic output and the SEC/DED flags are computed from the
    -- flipped codeword, so the check succeeds even for DED beats.
    procedure ft_expect_beat (
        signal net : inout network_t;
        slave      : in axi_stream_slave_t;
        data       : in std_logic_vector;
        flip_bits  : in std_logic_vector;
        message    : in string;
        last       : in std_logic := '1');

    -- Compute the decoder's deterministic outcome for a data word stored with the given flip
    -- pattern: the (possibly SEC-corrected) output data and the SEC/DED flags.
    procedure ft_expected_beat (
        data        : in std_logic_vector;
        flip_bits   : in std_logic_vector;
        exp_data    : out std_logic_vector;
        exp_ecc_sec : out std_logic;
        exp_ecc_ded : out std_logic);

end package;

---------------------------------------------------------------------------------------------------
-- Package Body
---------------------------------------------------------------------------------------------------
package body olo_test_ft_pkg is

    procedure ft_write (
        address        : in natural;
        data           : in natural;
        signal clk     : in std_logic;
        signal addr    : out std_logic_vector;
        signal wr_data : out std_logic_vector;
        signal wr_ena  : out std_logic) is
    begin
        wait until rising_edge(clk);
        addr    <= toUslv(address, addr'length);
        wr_data <= toUslv(data, wr_data'length);
        wr_ena  <= '1';
        wait until rising_edge(clk);
        wr_ena  <= '0';
        addr    <= toUslv(0, addr'length);
        wr_data <= toUslv(0, wr_data'length);
    end procedure;

    procedure ft_preload_flip (
        flip_bits        : in std_logic_vector;
        signal clk       : in std_logic;
        signal inj_flip  : out std_logic_vector;
        signal inj_valid : out std_logic) is
    begin
        wait until rising_edge(clk);
        inj_flip  <= flip_bits;
        inj_valid <= '1';
        wait until rising_edge(clk);
        inj_flip  <= (inj_flip'range => '0');
        inj_valid <= '0';
    end procedure;

    procedure ft_write_flip (
        address          : in natural;
        data             : in natural;
        flip_bits        : in std_logic_vector;
        signal clk       : in std_logic;
        signal addr      : out std_logic_vector;
        signal wr_data   : out std_logic_vector;
        signal wr_ena    : out std_logic;
        signal inj_flip  : out std_logic_vector;
        signal inj_valid : out std_logic) is
    begin
        wait until rising_edge(clk);
        addr      <= toUslv(address, addr'length);
        wr_data   <= toUslv(data, wr_data'length);
        wr_ena    <= '1';
        inj_flip  <= flip_bits;
        inj_valid <= '1';
        wait until rising_edge(clk);
        wr_ena    <= '0';
        inj_flip  <= (inj_flip'range => '0');
        inj_valid <= '0';
        addr      <= toUslv(0, addr'length);
        wr_data   <= toUslv(0, wr_data'length);
    end procedure;

    procedure ft_check_ecc (
        address         : in natural;
        data            : in natural;
        exp_ecc_sec     : in std_logic;
        exp_ecc_ded     : in std_logic;
        latency         : in natural;
        signal clk      : in std_logic;
        signal addr     : out std_logic_vector;
        signal rd_ena   : out std_logic;
        signal rd_data  : in std_logic_vector;
        signal rd_valid : in std_logic;
        signal ecc_sec  : in std_logic;
        signal ecc_ded  : in std_logic;
        message         : in string;
        check_data      : in boolean := true) is
    begin
        wait until rising_edge(clk);
        addr   <= toUslv(address, addr'length);
        rd_ena <= '1';
        wait until rising_edge(clk);
        addr   <= toUslv(0, addr'length);
        rd_ena <= '0';

        for i in 1 to latency loop
            wait until rising_edge(clk);
        end loop;

        check_equal(rd_valid, '1',         message & " rd_valid");
        check_equal(ecc_sec,  exp_ecc_sec, message & " ecc_sec");
        check_equal(ecc_ded,  exp_ecc_ded, message & " ecc_ded");
        if check_data then
            check_equal(rd_data, toUslv(data, rd_data'length), message & " data");
        end if;
    end procedure;

    procedure ft_wait_passes (
        passes           : in positive;
        signal clk       : in std_logic;
        signal pass_done : in std_logic) is
        variable pass_cnt_v : natural := 0;
    begin

        while pass_cnt_v < passes loop
            wait until rising_edge(clk);
            if pass_done = '1' then
                pass_cnt_v := pass_cnt_v + 1;
            end if;
        end loop;

    end procedure;

    procedure ft_count_over_passes (
        passes           : in positive;
        signal clk       : in std_logic;
        signal pass_done : in std_logic;
        signal watched   : in std_logic;
        watched_count    : out natural) is
        variable pass_cnt_v    : natural := 0;
        variable watched_cnt_v : natural := 0;
    begin

        while pass_cnt_v < passes loop
            wait until rising_edge(clk);
            if watched = '1' then
                watched_cnt_v := watched_cnt_v + 1;
            end if;
            if pass_done = '1' then
                pass_cnt_v := pass_cnt_v + 1;
            end if;
        end loop;

        watched_count := watched_cnt_v;
    end procedure;

    procedure ft_push_beat (
        signal net       : inout network_t;
        master           : in axi_stream_master_t;
        signal clk       : in std_logic;
        signal inj_flip  : out std_logic_vector;
        signal inj_valid : out std_logic;
        data             : in std_logic_vector;
        flip_bits        : in std_logic_vector;
        last             : in std_logic := '1') is
        variable inject_v : boolean := false;
    begin

        for i in flip_bits'range loop
            if flip_bits(i) = '1' then
                inject_v := true;
            end if;
        end loop;

        if inject_v then
            -- Drain so no in-flight handshake races the latch load
            wait_until_idle(net, as_sync(master));
            wait until rising_edge(clk);

            -- One-cycle pulse: load the latch with flip_bits
            inj_flip  <= flip_bits;
            inj_valid <= '1';
            wait until rising_edge(clk);
            inj_valid <= '0';

            push_axi_stream(net, master, data, tlast => last);

            -- Hold inj_flip stable until the push fires; the latch is cleared by the handshake
            wait_until_idle(net, as_sync(master));
            wait until rising_edge(clk);
            inj_flip <= (inj_flip'range => '0');
        else
            push_axi_stream(net, master, data, tlast => last);
        end if;

    end procedure;

    procedure ft_expect_beat (
        signal net : inout network_t;
        slave      : in axi_stream_slave_t;
        data       : in std_logic_vector;
        flip_bits  : in std_logic_vector;
        message    : in string;
        last       : in std_logic := '1') is
        variable exp_data_v  : std_logic_vector(data'length - 1 downto 0);
        variable exp_sec_v   : std_logic;
        variable exp_ded_v   : std_logic;
        variable exp_tuser_v : std_logic_vector(1 downto 0);
    begin
        ft_expected_beat(data, flip_bits, exp_data_v, exp_sec_v, exp_ded_v);
        exp_tuser_v := exp_sec_v & exp_ded_v;

        check_axi_stream(net, slave, exp_data_v, tlast => last, tuser => exp_tuser_v,
            msg                                        => message, blocking => false);
    end procedure;

    procedure ft_expected_beat (
        data        : in std_logic_vector;
        flip_bits   : in std_logic_vector;
        exp_data    : out std_logic_vector;
        exp_ecc_sec : out std_logic;
        exp_ecc_ded : out std_logic) is
        variable codeword_v : std_logic_vector(flip_bits'length - 1 downto 0);
        variable syn_par_v  : std_logic_vector(eccParityBits(data'length) downto 0);
    begin
        codeword_v  := eccEncode(data) xor flip_bits;
        syn_par_v   := eccSyndromeAndParity(codeword_v, data'length);
        exp_data    := eccCorrectData(codeword_v, syn_par_v, data'length);
        exp_ecc_sec := eccSecError(syn_par_v);
        exp_ecc_ded := eccDedError(syn_par_v);
    end procedure;

end package body;
