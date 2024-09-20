-- -----------------------------------------------------------------------------
--  Title      : VHDL memory model AXI subordinate
--  Project    : UNKNOWN
-- -----------------------------------------------------------------------------
--  File       : mem_model_axi.vhd
--  Author     : Simon Southwell
--  Created    : 2024-09-13
--  Standard   : VHDL 2008
-- -----------------------------------------------------------------------------
--  Description:
--  A VHDL AXI subordinate wrapper around mem_model
-- -----------------------------------------------------------------------------
--  Copyright (c) 2024 Simon Southwell
-- -----------------------------------------------------------------------------
--
--  This is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation(), either version 3 of the License(), or
--  (at your option) any later version.
--
--  It is distributed in the hope that it will be useful(),
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this code. If not, see <http://www.gnu.org/licenses/>.
--
-- -----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity mem_model_axi is
generic (
    ADDRWIDTH                 : natural range 8 to 128 := 32;
    DATAWIDTH                 : natural range 8 to 128 := 32;
    ID_W_WIDTH                : natural range 4 to 8   := 4;
    ID_R_WIDTH                : natural range 4 to 8   := 4;
    CMDQ_DEPTH                : integer                := 8;
    DATAQ_DEPTH               : integer                := 64
);
port (
    clk                       : in  std_logic;
    nreset                    : in  std_logic;

    -- Write address channel
    awaddr                    : in  std_logic_vector (ADDRWIDTH-1 downto 0);
    awvalid                   : in  std_logic := '0';
    awready                   : out std_logic;
    awlen                     : in  std_logic_vector (7 downto 0) := 8x"0";
    
    -- Unused/fixed at the moment
    awburst                   : in  std_logic_vector (1 downto 0) := "01";
    awsize                    : in  std_logic_vector (2 downto 0) := std_logic_vector(to_unsigned(integer(ceil(log2(real(DATAWIDTH/8)))), 3));
    awid                      : in  std_logic_vector (ID_W_WIDTH-1 downto 0) := (others => '0');

    -- Write Data channel
    wdata                     : in  std_logic_vector (DATAWIDTH-1 downto 0);
    wvalid                    : in  std_logic := '0';
    wready                    : out std_logic;
    wstrb                     : in  std_logic_vector (DATAWIDTH/8-1 downto 0) := (others => '1');

    -- Write response channel
    bvalid                    : out std_logic := '1';
    bready                    : in  std_logic;
    bid                       : out std_logic_vector (ID_W_WIDTH-1 downto 0) := (others => '0');

    -- Read address channel
    araddr                    : in  std_logic_vector (ADDRWIDTH-1 downto 0);
    arvalid                   : in  std_logic;
    arready                   : out std_logic;
    arlen                     : in  std_logic_vector (7 downto 0) := 8x"0";
    
      -- Unused/fixed at the moment
    arburst                   : in  std_logic_vector (1 downto 0) := "01";
    arsize                    : in  std_logic_vector (2 downto 0) := std_logic_vector(to_unsigned(integer(ceil(log2(real(DATAWIDTH/4)))), 3));
    arid                      : in  std_logic_vector (ID_R_WIDTH-1 downto 0) := (others => '0');

    -- Read data/response channel
    rdata                     : out std_logic_vector (DATAWIDTH-1 downto 0);
    rvalid                    : out std_logic;
    rready                    : in  std_logic;
    rlast                     : out std_logic;
    rid                       : out std_logic_vector (ID_R_WIDTH-1 downto 0) := (others => '0')
);
end entity;

architecture behavioural of mem_model_axi is

signal av_rx_address          : std_logic_vector (31 downto 0);
signal av_tx_address          : std_logic_vector (31 downto 0);
signal av_byteenable          : std_logic_vector ( 3 downto 0);
signal av_write               : std_logic;
signal av_writedata           : std_logic_vector (31 downto 0);
signal av_read                : std_logic;
signal av_readdata            : std_logic_vector (31 downto 0);
signal av_readdatavalid       : std_logic;
signal av_rx_waitrequest      : std_logic := '0';
signal av_tx_waitrequest      : std_logic := '0';
signal av_rx_burstcount       : std_logic_vector (11 downto 0) := 12d"1";
signal av_tx_burstcount       : std_logic_vector (11 downto 0) := 12d"1";
signal tx_burst_counter       : unsigned (11 downto 0)         := to_unsigned(0, 12);
signal rx_burst_counter       : unsigned (11 downto 0)         := to_unsigned(0, 12);

signal aw_q_full              : std_logic;
signal aw_q_empty             : std_logic;
signal aw_q_wdata             : std_logic_vector (ADDRWIDTH+2+3+8+ID_W_WIDTH-1 downto 0);
signal aw_q_rdata             : std_logic_vector (ADDRWIDTH+2+3+8+ID_W_WIDTH-1 downto 0);

signal ar_q_full              : std_logic;
signal ar_q_empty             : std_logic;
signal ar_q_wdata             : std_logic_vector (ADDRWIDTH+2+3+8+ID_R_WIDTH-1 downto 0);
signal ar_q_rdata             : std_logic_vector (ADDRWIDTH+2+3+8+ID_R_WIDTH-1 downto 0);

signal w_q_write              : std_logic;
signal w_q_full               : std_logic;
signal w_q_empty              : std_logic;
signal w_q_wdata              : std_logic_vector (DATAWIDTH+DATAWIDTH/8-1 downto 0);
signal w_q_rdata              : std_logic_vector (DATAWIDTH+DATAWIDTH/8-1 downto 0);

signal hold_rvalid            : std_logic := '0';
signal hold_rdata             : std_logic_vector (DATAWIDTH-1 downto 0);

begin

-- ---------------------------------------------------------
-- Combinatorial logic
-- ---------------------------------------------------------

-- WRITE ADDRESS PORT LOGIC --
awready                       <= not aw_q_full;
aw_q_wdata                    <= awid & awlen & awsize & awburst & awaddr;

-- WRITE DATA PORT LOGIC --
wready                        <= not w_q_full;
w_q_wdata                     <= wstrb & wdata;

-- READ ADDRESS PORT LOGIC --
arready                       <= not ar_q_full;
ar_q_wdata                    <= arid & arlen & arsize & arburst & araddr;

-- READ DATA PORT LOGIC --

-- Output held memory read if read response stalled, else return memory output if valid, else make X
rdata                         <= hold_rdata when hold_rvalid = '1' else av_readdata when av_readdatavalid = '1' else (others => 'X');

-- Read valid when data memory read valid, or read response stalled
rvalid                        <= av_readdatavalid or hold_rvalid;
rlast                         <= '1' when rvalid = '1' and to_integer(rx_burst_counter) <= 1 else '0';

-- MEMORY ACCESS LOGIC --

av_rx_address                 <= ar_q_rdata (ADDRWIDTH-1 downto 0);
av_rx_burstcount              <= "0000" & std_logic_vector(unsigned (ar_q_rdata (ADDRWIDTH+12 downto ADDRWIDTH+5)) + 1);

av_tx_address                 <= aw_q_rdata (ADDRWIDTH-1 downto 0);
av_tx_burstcount              <= "0000" & std_logic_vector(unsigned (aw_q_rdata (ADDRWIDTH+12 downto ADDRWIDTH+5)) + 1);

av_byteenable                 <= w_q_rdata  (DATAWIDTH+DATAWIDTH/8-1 downto DATAWIDTH);
av_writedata                  <= w_q_rdata  (DATAWIDTH-1 downto 0);

-- Write if a write address/data ready and not stalled on write response
av_write                      <= not aw_q_empty and not w_q_empty and not (bvalid and not bready) and not av_tx_waitrequest;

-- Read if a read ready to go and not stalled on read response
av_read                       <= not ar_q_empty and not (rvalid and not rready) and not av_rx_waitrequest;

-- ---------------------------------------------------------
-- Synchronous process
-- ---------------------------------------------------------

process(clk)
  variable tx_burst_cnt_1    : std_logic := '0';
  variable av_tx_burst_cnt_1 : std_logic := '0';
begin
  if clk'event and clk = '1' then
  
    tx_burst_cnt_1              := '1' when to_integer(tx_burst_counter) = 1 else '0';
    av_tx_burst_cnt_1           := '1' when to_integer(unsigned(av_tx_burstcount)) = 1 else '0';
    
    -- Set bvalid when written to memory, and hold until bready asserted
    bvalid                      <= ((av_write and (tx_burst_cnt_1 or av_tx_burst_cnt_1)) or (bvalid and not bready)) and nreset;

    -- Held rvalid if read response port stalled
    hold_rvalid                 <= rvalid and not rready and nreset;

    -- Hold the memory read data
    hold_rdata                  <= av_readdata when av_readdatavalid = '1' else hold_rdata;
    
    -- Decrement the burst counter when memory written and not 0
    if av_write = '1' and to_integer(tx_burst_counter) > 0 then
      tx_burst_counter          <= tx_burst_counter - 1;
    end if;
    
    -- if a new write of a burst, set burst counter to burst length
    -- less one (to account for this first write).    
    if av_write = '1' and to_integer(tx_burst_counter) = 0 then
      tx_burst_counter          <= unsigned(av_tx_burstcount) - 1;
    end if;
    
    if rvalid = '1' and rready = '1' and to_integer(rx_burst_counter) > 0 then
      rx_burst_counter          <= rx_burst_counter - 1;
    end if;
    
    if av_read = '1' and to_integer(rx_burst_counter) = 0 then
      rx_burst_counter          <= unsigned(av_rx_burstcount);
    end if;

  end if;
end process;


-- ---------------------------------------------------------
-- Write address queue
-- ---------------------------------------------------------

  aw_q : entity work.mem_model_q
  generic map (
    DEPTH                     => CMDQ_DEPTH,
    WIDTH                     => ADDRWIDTH+2+3+8+ID_W_WIDTH
  )
  port map (
    clk                       => clk,
    reset_n                   => nreset,

    write                     => awvalid,
    wdata                     => aw_q_wdata,
    full                      => aw_q_full,

    read                      => av_write,
    rdata                     => aw_q_rdata,
    empty                     => aw_q_empty,

    clr                       => '0',
    nearly_full               => open
  );

-- ---------------------------------------------------------
-- Write data queue
-- ---------------------------------------------------------

  w_q : entity work.mem_model_q
  generic map (
    DEPTH                     => DATAQ_DEPTH,
    WIDTH                     => DATAWIDTH+DATAWIDTH/8
  )
  port map (
    clk                       => clk,
    reset_n                   => nreset,

    write                     => wvalid,
    wdata                     => w_q_wdata,
    full                      => w_q_full,

    read                      => wvalid,
    rdata                     => w_q_rdata,
    empty                     => w_q_empty,

    clr                       => '0',
    nearly_full               => open
  );

-- ---------------------------------------------------------
-- Read address queue
-- ---------------------------------------------------------

  ar_q : entity work.mem_model_q
  generic map (
    DEPTH                     => CMDQ_DEPTH,
    WIDTH                     => ADDRWIDTH+2+3+8+ID_W_WIDTH
  )
  port map (
    clk                       => clk,
    reset_n                   => nreset,

    write                     => arvalid,
    wdata                     => ar_q_wdata,
    full                      => ar_q_full,

    read                      => av_read,
    rdata                     => ar_q_rdata,
    empty                     => ar_q_empty,

    clr                       => '0',
    nearly_full               => open
  );

-- ---------------------------------------------------------
-- Core memory model
-- ---------------------------------------------------------

  mem : entity work.mem_model
  port map (

    clk                       => clk,
    rst_n                     => nreset,

    address                   => (others => '0'),
    byteenable                => (others => '0'),
    write                     => '0',
    writedata                 => (others => '0'),
    read                      => '0',
    readdata                  => open,
    readdatavalid             => open,

    rx_waitrequest            => av_rx_waitrequest,
    rx_burstcount             => av_rx_burstcount,
    rx_address                => av_rx_address,
    rx_read                   => av_read,
    rx_readdata               => av_readdata,
    rx_readdatavalid          => av_readdatavalid,

    tx_waitrequest            => av_tx_waitrequest,
    tx_burstcount             => av_tx_burstcount,
    tx_address                => av_tx_address,
    tx_write                  => av_write,
    tx_byteenable             => av_byteenable,
    tx_writedata              => av_writedata,

    wr_port_valid             => '0',
    wr_port_data              => (others => '0'),
    wr_port_addr              => (others => '0')

  );

end behavioural;