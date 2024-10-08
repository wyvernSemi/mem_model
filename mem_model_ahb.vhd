-- ====================================================================
--
-- VHDL AHB bus functional model (BFM) wrapper for mem_model.
--
-- Copyright (c) 2024 Simon Southwell.
--
-- Implements minimal compliant manager interface at 32-bits wide.
-- Also has a vectored irq input. Does not (yet) utilise VProc's burst
-- capabilities.
--
-- This file is part of VProc.
--
-- VProc is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- VProc is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with VProc. If not, see <http://www.gnu.org/licenses/>.
--
-- ====================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mem_model_ahb is
generic (
    ADDRWIDTH                 : integer := 32; -- For future proofing. Do not change.
    DATAWIDTH                 : integer := 32  -- For future proofing. Do not change.0
);
port (
    hclk                      : in  std_logic;
    hresetn                   : in  std_logic;

    hsel                      : in  std_logic := '0';
    haddr                     : in  std_logic_vector (ADDRWIDTH-1 downto 0);
    hwdata                    : in  std_logic_vector (DATAWIDTH-1 downto 0);
    hwrite                    : in  std_logic := '0';
    hburst                    : in  std_logic_vector (2 downto 0) := "000";
    hsize                     : in  std_logic_vector (2 downto 0) := "010";
    htrans                    : in  std_logic_vector (1 downto 0) := "00";
    hmastlock                 : in  std_logic := '0';
    hwstrb                    : in  std_logic_vector (DATAWIDTH/8-1 downto 0) := (others => '1');

    hrdata                    : out std_logic_vector (DATAWIDTH-1 downto 0);
    hready                    : out std_logic;
    hresp                     : out std_logic
);
end entity;

architecture bfm of mem_model_ahb is

constant AHB_SIZE_WORD        : std_logic_vector (2 downto 0) := "010";

constant AHB_BURST_SINGLE     : std_logic_vector (2 downto 0) := "000";
constant AHB_BURST_INCR       : std_logic_vector (2 downto 0) := "001";

constant AHB_TRANS_IDLE       : std_logic_vector (1 downto 0) := "00";
constant AHB_TRANS_BUSY       : std_logic_vector (1 downto 0) := "01";
constant AHB_TRANS_NONSEQ     : std_logic_vector (1 downto 0) := "10";
constant AHB_TRANS_SEQ        : std_logic_vector (1 downto 0) := "11";

signal   active_access        : std_logic;
signal   mem_write            : std_logic;
signal   mem_read             : std_logic;
signal   mem_readdatavalid    : std_logic;
signal   mem_readdata         : std_logic_vector (DATAWIDTH-1 downto 0);
signal   mem_addr             : std_logic_vector (ADDRWIDTH-1 downto 0);
signal   mem_addr_rw          : std_logic_vector (ADDRWIDTH-1 downto 0);

signal   burst_rd_addr        : std_logic_vector (ADDRWIDTH-1 downto 0);
signal   hburst_not_sgl_incr  : std_logic;
signal   hburst_sgl           : std_logic;
signal   htrans_not_idle      : std_logic;
signal   hsize_not_word       : std_logic;
signal   mem_addr_phase       : std_logic_vector (ADDRWIDTH-1 downto 0);
signal   mem_write_phase      : std_logic;
signal   hwstrb_phase         : std_logic_vector (DATAWIDTH/8-1 downto 0);

begin
-- ---------------------------------------------------------
-- Combinatorial logic
-- ---------------------------------------------------------

-- Give error if selected, not idle, not a single or an undefined length incrementing burst, and not a 32 bit word transfer
hburst_not_sgl_incr           <= '1' when hburst(2 downto 1) /= "00" else '0';
hburst_sgl                    <= '1' when hburst  = AHB_BURST_SINGLE else '0';
htrans_not_idle               <= '1' when htrans /= AHB_TRANS_IDLE   else '0';
hsize_not_word                <= '1' when hsize  /= AHB_SIZE_WORD    else '0';

hresp                         <= hsel and htrans_not_idle and (hburst_not_sgl_incr or hsize_not_word);

-- Access is active if selected, NONSEQ or SEQ and not an illegal transfer type
active_access                 <=     hsel   and htrans(1) and not hresp;
mem_write                     <=     hwrite and active_access;
mem_read                      <= not hwrite and active_access and not (hburst_sgl and mem_readdatavalid);
mem_addr                      <= haddr when mem_readdatavalid = '0' else burst_rd_addr;
mem_addr_rw                   <= mem_addr_phase when mem_write_phase = '1' else mem_addr;

-- The memory model won't stall on any access.
hready                        <= '1' ;

hrdata                        <= mem_readdata when mem_readdatavalid = '1' else (others => 'X');

-- ---------------------------------------------------------
-- Synhronous process
-- ---------------------------------------------------------

process (hclk, hresetn)
begin
  if hresetn = '0' then
    burst_rd_addr             <= (others => '0');
    mem_write_phase           <= '0';
  elsif hclk'event and hclk = '1' then
  
     mem_write_phase          <= mem_write;
     hwstrb_phase             <= hwstrb;
     mem_addr_phase           <= mem_addr;
  
     if hburst = AHB_BURST_INCR and (htrans = AHB_TRANS_NONSEQ or htrans = AHB_TRANS_SEQ) then
        burst_rd_addr         <= std_logic_vector(unsigned(haddr)         + 4) when not mem_readdatavalid else
                                 std_logic_vector(unsigned(burst_rd_addr) + 4);
     end if;
  end if;
end process;

-- ---------------------------------------------------------
-- Core memory model
-- ---------------------------------------------------------

  mem : entity work.mem_model
  generic map (
    EN_READ_QUEUE             => false,
    REG_READ_OVERLAP          => true
  )
  port map (
    clk                       => hclk,
    rst_n                     => hresetn,

    address                   => mem_addr_rw,
    byteenable                => hwstrb_phase,
    write                     => mem_write_phase,
    writedata                 => hwdata,
    read                      => mem_read,
    readdata                  => mem_readdata,
    readdatavalid             => mem_readdatavalid,

    rx_waitrequest            => open,
    rx_burstcount             => (others => '0'),
    rx_address                => haddr,
    rx_read                   => '0',
    rx_readdata               => open,
    rx_readdatavalid          => open,

    tx_waitrequest            => open,
    tx_burstcount             => (others => '0'),
    tx_address                => (others => '0'),
    tx_write                  => '0',
    tx_writedata              => (others => '0'),
    tx_byteenable             => (others => '0'),

    wr_port_valid             => '0',
    wr_port_data              => (others => '0'),
    wr_port_addr              => (others => '0')
  );

end bfm;