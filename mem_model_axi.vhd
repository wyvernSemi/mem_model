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
    
      -- Unused at the moment
    awburst                   : in  std_logic_vector (1 downto 0) := "01";
    awsize                    : in  std_logic_vector (2 downto 0) := std_logic_vector(to_unsigned(integer(ceil(log2(real(DATAWIDTH/8)))), 3));
    awlen                     : in  std_logic_vector (7 downto 0) := 8x"0";
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
    
      -- Unused at the moment
    arburst                   : in  std_logic_vector (1 downto 0) := "01";
    arsize                    : in  std_logic_vector (2 downto 0) := std_logic_vector(to_unsigned(integer(ceil(log2(real(DATAWIDTH/4)))), 3));
    arlen                     : in  std_logic_vector (7 downto 0) := 8x"0";
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

signal av_address             : std_logic_vector (31 downto 0);
signal av_byteenable          : std_logic_vector ( 3 downto 0);
signal av_write               : std_logic;
signal av_writedata           : std_logic_vector (31 downto 0);
signal av_read                : std_logic;
signal av_readdata            : std_logic_vector (31 downto 0);
signal av_readdatavalid       : std_logic;

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

signal rnw_arb                : std_logic;
signal last_rnw               : std_logic := '0';
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
rlast                         <= rvalid;

-- MEMORY ACCESS LOGIC --

-- Select a read if a read command ready and not a write command ready
-- and read was the last access type.
rnw_arb                       <= not ar_q_empty and not (not aw_q_empty and not w_q_empty and last_rnw);

av_address                    <= aw_q_rdata (ADDRWIDTH-1 downto 0)                     when rnw_arb = '0' else ar_q_rdata (ADDRWIDTH-1 downto 0);
av_byteenable                 <= w_q_rdata  (DATAWIDTH+DATAWIDTH/8-1 downto DATAWIDTH) when rnw_arb = '0' else (others => '1') ;

av_writedata                  <= w_q_rdata  (DATAWIDTH-1 downto 0);

-- Write if arbitration selecting writes, and write address/data ready and not stalled on write response
av_write                      <= not rnw_arb and not aw_q_empty and not w_q_empty and not (bvalid and not bready);

-- Read if arbitration selecting reads, and a read ready to go and not stalled on read response
av_read                       <= rnw_arb and not ar_q_empty and not (rvalid and not rready);

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

    address                   => av_address,
    byteenable                => av_byteenable,
    write                     => av_write,
    writedata                 => av_writedata,
    read                      => av_read,
    readdata                  => av_readdata,
    readdatavalid             => av_readdatavalid,

    rx_waitrequest            => open,
    rx_burstcount             => (others => '0'),
    rx_address                => (others => '0'),
    rx_read                   => '0',
    rx_readdata               => open,
    rx_readdatavalid          => open,

    tx_waitrequest            => open,
    tx_burstcount             => (others => '0'),
    tx_address                => (others => '0'),
    tx_write                  => '0',
    tx_writedata              => (others => '0'),

    wr_port_valid             => '0',
    wr_port_data              => (others => '0'),
    wr_port_addr              => (others => '0')

  );

-- ---------------------------------------------------------
-- Synchronous process
-- ---------------------------------------------------------

process(clk)
begin
  if clk'event and clk = '1' then
    -- Set bvalid when written to memory, and hold until bready asserted
    bvalid                      <= (av_write or (bvalid and not bready)) and nreset;

    -- Last access read-not-write status set on read to memory and held, cleared on a write
    last_rnw                    <= (last_rnw or av_read) and not av_write and nreset;
    
    -- Held rvalid if read response port stalled 
    hold_rvalid                 <= rvalid and not rready and nreset;
    
    -- Hold the memory read data
    hold_rdata                  <= av_readdata when av_readdatavalid = '1' else hold_rdata;
    
  end if;
end process;

end behavioural;