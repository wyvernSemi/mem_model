-- ====================================================================
--
-- VHDL Verilog APB bus functional model (BFM) wrapper for mem_model.
--
-- Copyright (c) 2024 Simon Southwell.
--
-- Implements minimal compliant completer interface at 32-bits wide.
-- Also has a vectored irq input.
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

entity mem_model_apb is
generic (
    ADDRWIDTH                 : integer := 32; -- For future proofing. Do not change.
    DATAWIDTH                 : integer := 32 -- For future proofing. Do not change.
);
port (
    pclk                      : in  std_logic;
    presetn                   : in  std_logic;

    psel                      : in  std_logic;

    paddr                     : in  std_logic_vector (ADDRWIDTH-1 downto 0);
    pwdata                    : in  std_logic_vector (DATAWIDTH-1 downto 0);
    pwrite                    : in  std_logic;
    penable                   : in  std_logic;

    pstrb                     : in  std_logic_vector (DATAWIDTH/8-1 downto 0);
    pprot                     : in  std_logic_vector (2 downto 0);

    prdata                    : out std_logic_vector (DATAWIDTH-1 downto 0);
    pready                    : out std_logic;
    pslverr                   : out std_logic
);
end entity;

architecture bfm of mem_model_apb is

signal mem_write              : std_logic;
signal mem_read               : std_logic;
signal mem_readdatavalid      : std_logic;
signal mem_readdata           : std_logic_vector(DATAWIDTH-1 downto 0);
signal mem_writedata          : std_logic_vector(DATAWIDTH-1 downto 0);
signal mem_addr               : std_logic_vector(ADDRWIDTH-1 downto 0);
signal mem_be                 : std_logic_vector(DATAWIDTH/8-1 downto 0);

signal addr_phase             : std_logic;
signal data_phase             : std_logic;

begin

-- ---------------------------------------------------------
-- Combinatorial logic
-- ---------------------------------------------------------

-- Pass address, write data and write strobes straight through to memory
mem_addr                      <= paddr;
mem_writedata                 <= pwdata;
mem_be                        <= pstrb;

-- In address phase when selected and PENABLE low and data phase when PENABLE high
addr_phase                    <= psel and not penable;
data_phase                    <= psel and     penable;

-- Write to memory in the address phase
mem_write                     <= pwrite and addr_phase;

-- Read from memory in the address phase
mem_read                      <= not pwrite and addr_phase;

-- Signal pready immediately in data phase of write or, when reading, in the data phase and read data valid from memory
pready                        <= (pwrite and data_phase) or (not pwrite and data_phase and mem_readdatavalid);

-- Export memory read data directly from memory
prdata                        <= mem_readdata;

-- No possible error conditions
pslverr                       <= '0';

-- ---------------------------------------------------------
-- Core memory model
-- ---------------------------------------------------------

  mem : entity work.mem_model
  generic map (
    EN_READ_QUEUE             => false,
    REG_READ_OVERLAP          => false
  )
  port map (
    clk                       => pclk,
    rst_n                     => presetn,
                            
    address                   => mem_addr,
    byteenable                => mem_be,
    write                     => mem_write,
    writedata                 => mem_writedata,
    read                      => mem_read,
    readdata                  => mem_readdata,
    readdatavalid             => mem_readdatavalid,
                            
    rx_waitrequest            => open,
    rx_burstcount             => 12x"000",
    rx_address                => (others => '0'),
    rx_read                   => '0',
    rx_readdata               => open,
    rx_readdatavalid          => open,
                             
    tx_waitrequest            => open,
    tx_burstcount             => 12x"000",
    tx_address                => (others => '0'),
    tx_write                  => '0',
    tx_writedata              => (others => '0'),
    tx_byteenable             => (others => '0'),
                           
    wr_port_valid             => '0',
    wr_port_data              => (others => '0'),
    wr_port_addr              => (others => '0')
  );

end bfm;