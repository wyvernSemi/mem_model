-- -----------------------------------------------------------------------------
--  Title      : VHDL memory model burst receiver command queue
--  Project    : UNKNOWN
-- -----------------------------------------------------------------------------
--  File       : mem_model_q.vhd
--  Author     : Simon Southwell
--  Created    : 2024-09-12
--  Standard   : VHDL 2008
-- -----------------------------------------------------------------------------
--  Description:
--  This block is a FIFO used as the RX burst interface command queue
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

entity mem_model_q is
generic (
  DEPTH                       : integer := 4;
  WIDTH                       : integer := 32+12;
  NEARLYFULL                  : integer := DEPTH/2
);
port (
  clk                         : in  std_logic;
  reset_n                     : in  std_logic;

  clr                         : in  std_logic := '0';

  write                       : in  std_logic;
  wdata                       : in  std_logic_vector(WIDTH-1 downto 0);

  read                        : in  std_logic;
  rdata                       : out std_logic_vector(WIDTH-1 downto 0);

  empty                       : out std_logic;
  full                        : out std_logic;
  nearly_full                 : out std_logic
  
);
end entity;

architecture behavioural of mem_model_q is

type mem_array_t is array (natural range <>) of std_logic_vector;

constant LOG2DEPTH            : integer := integer(ceil(log2(real(DEPTH))));

signal mem                    : mem_array_t (0 to DEPTH-1)(WIDTH-1 downto 0);
signal wptr                   : unsigned (LOG2DEPTH downto 0);
signal rptr                   : unsigned (LOG2DEPTH downto 0);

-- The number of words in the FIFO is the write pointer minus the read pointer
signal word_count             : unsigned (LOG2DEPTH downto 0);

begin

word_count                    <= wptr - rptr;
                              
rdata                         <= mem(to_integer(rptr(LOG2DEPTH-1 downto 0)));

process (clk, reset_n)
begin
  if reset_n = '0' then

    wptr                       <= (others => '0');
    rptr                       <= (others => '0');
    empty                      <= '1';
    full                       <= '0';
    nearly_full                <= '0';

  elsif clk'event and clk = '1' then

    -- If a write arrives, and not full, write to memory and update write pointer
    if write and not full then
      mem(to_integer(wptr(LOG2DEPTH-1 downto 0))) <= wdata;
      wptr                     <= wptr + 1;
    end if;

    -- If a read arrives, and not empty, fetch data from memory and update read pointer
    if read and not empty then
      rptr                     <= rptr + 1;
    end if;

    -- If writing, but not reading, update full status when last space being written.
    -- The nearly full flag is asserted when about to reach the threshold, or is greater.
    -- A write (without read) always clears the empty flag
    if write and not (read and not empty) then
      full                     <= '1' when (word_count >= DEPTH-1)      else '0';
      nearly_full              <= '1' when (word_count >= NEARLYFULL-1) else '0';
      empty                    <= '0';
    end if;

    -- If reading (but not writing), update empty status when last data is being read.
    -- The nearly full flag is deasserted when about to drop below the threshold, or
    -- is smaller. A read (without a write), always clears the full status.
    if read and not (write and not full) then
      empty                    <= '1' when (word_count <= 1)          else '0';
      nearly_full              <= '0' when (word_count <= NEARLYFULL) else '1';
      full                     <= '0';
    end if;
  end if;
end process;

end behavioural;