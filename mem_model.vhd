-- -----------------------------------------------------------------------------
--  Title      : VHDL memory model for simulations
--  Project    : UNKNOWN
-- -----------------------------------------------------------------------------
--  File       : mem_model.vhd
--  Author     : Simon Southwell
--  Created    : 2024-09-011
--  Standard   : VHDL 2008
-- -----------------------------------------------------------------------------
--  Description:
--  This block is a Verilog wrapper around a C/C++ based memory model with
--  various style memory ports, for use in simulations. The full 32 bit address
--  space is available, with the underlying model dynamically allocating memory
--  blocks as they are accessed. It accesses the underlying C model via the
--  VHDL FLI interface.
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

use work.mem_model_pkg.all;

entity mem_model is
  generic (
    TX_WR_DATA_WIDTH      : natural range 32 to 128 := 32
  );
  port (
    clk                   : in  std_logic;
    rst_n                 : in  std_logic;

    -- Register style slave interface
    address               : in  std_logic_vector (31 downto 0) := (others => '0');
    byteenable            : in  std_logic_vector ( 3 downto 0) := (others => '1');
    write                 : in  std_logic                      := '0';
    writedata             : in  std_logic_vector (31 downto 0) := (others => '0');
    read                  : in  std_logic                      := '0';
    readdata              : out std_logic_vector (31 downto 0);
    readdatavalid         : out std_logic;

    -- Burst read style slave interface
    rx_waitrequest        : out std_logic;
    rx_burstcount         : in  std_logic_vector (11 downto 0) := (others => '0');
    rx_address            : in  std_logic_vector (31 downto 0) := (others => '0');
    rx_read               : in  std_logic                      := '0';
    rx_readdata           : out std_logic_vector (31 downto 0) := (others => '0');
    rx_readdatavalid      : out std_logic;

    -- Burst write style slave interface
    tx_waitrequest        : out std_logic;
    tx_burstcount         : in  std_logic_vector (11 downto 0) := 12x"0";
    tx_address            : in  std_logic_vector (31 downto 0) := 32x"0";
    tx_write              : in  std_logic                      := '0';
    tx_writedata          : in  std_logic_vector (TX_WR_DATA_WIDTH-1 downto 0) := (others => '0');

    -- SRAM style write por
    wr_port_valid         : in  std_logic                      := '0';
    wr_port_data          : in  std_logic_vector (31 downto 0) := 32x"0";
    wr_port_addr          : in  std_logic_vector (31 downto 0) := 32x"0"
  );
end entity;

architecture model of mem_model is

  constant ALL_BYTES_EN               : integer := 16#F#;

begin


  -- Update process
  pUPDATE : process

    variable readdata_int             : integer;
    variable rx_readdatavalid_int     : std_logic;
    variable rx_readdata_int          : std_logic_vector(31 downto 0) := (others => '0');
    variable readdata_rx              : integer;
    variable rd_addr                  : integer;
    variable wr_addr                  : integer;
    variable rx_count                 : integer := 0;
    variable tx_count                 : integer := 0;
    variable rx_waitrequest_int       : std_logic := '0';
    variable tx_waitrequest_int       : std_logic := '0';
  begin

    while true loop

      -- Can't have a sensitivity list for the process and process delta cycles in VHDL,
      -- so emulate the clock edge with a wait here.
      wait until clk'event and clk = '1';

      if rst_n = '0' then

        rx_count                 := 0;
        rd_addr                  := 0;

        tx_count                 := 0;
        wr_addr                  := 0;

        tx_waitrequest           <='0';
        rx_waitrequest           <='0';
        rx_readdatavalid         <='0';
        rx_readdatavalid_int     :='0';

        readdata                 <= 32x"00000000";
        readdatavalid            <= '0';

      else

        -- Default some of the outputs
        readdatavalid            <= '0';
        readdata_int             := 0;

        -- Update the output valid signal with that calculated last cycle
        rx_readdatavalid         <= rx_readdatavalid_int;

        -- read data is valid (internally) whenever the RX counter is non-zero
        if rx_count /= 0 then
          rx_readdatavalid_int   := '1';
        else
          rx_readdatavalid_int   := '0';
        end if;

        -- Update RX bus output with value calculated from last cycle
        rx_readdata              <= rx_readdata_int;

        -- Internal read data is updated from that fetched from model last cycle.
        rx_readdata_int          := std_logic_vector(to_signed(readdata_rx, 32));

        -- If a slave read, return memory contents
        if read = '1'  and readdatavalid = '0' then
          MemRead(to_integer(signed(address)), readdata_int, to_integer(unsigned(byteenable)));
          readdatavalid          <= '1';
        end if;
        readdata                 <= std_logic_vector(to_signed(readdata_int, 32));

        -- wait until the negative edge of the clock
        wait until clk'event and clk = '0';

        -- If a slave write, update memory
        if write = '1' then
          MemWrite(to_integer(signed(address)), to_integer(signed(writedata)), to_integer(unsigned(byteenable)));
        end if;

        if tx_count = 0 and rx_count = 0 then
          rx_waitrequest_int     := '0';
        else
          rx_waitrequest_int     := '1';
        end if;
        rx_waitrequest           <= rx_waitrequest_int;

        if rx_count = 0 or tx_count /= 0 then
          tx_waitrequest_int     := '0';
        else
          tx_waitrequest_int     := '1';
        end if;
        tx_waitrequest           <= tx_waitrequest_int;

        -- If a new master read request comes in (and not active), latch the rx_count and address values
        if rx_read = '1' and rx_waitrequest_int = '0' then
           -- Load RX count with burst + 1 as we are going to decrement it immediately
           rx_count              := to_integer(signed(rx_burstcount) + 1);
           rd_addr               := to_integer(signed(rx_address));
        end if;

        -- If a new master write request comes in (and not active), latch the tx_count and address values
        if tx_write = '1' and tx_waitrequest_int = '0' and tx_count = 0 then
           tx_count              := to_integer(signed(tx_burstcount));
           wr_addr               := to_integer(signed(tx_address));
        end if;

        -- If an active read transfer in progress, transfer data
        if rx_count /= 0 then

          MemRead(rd_addr, readdata_rx, ALL_BYTES_EN);
          readdata               <= std_logic_vector(to_signed(readdata_rx, 32));

          -- Decrement the word count
          rx_count               := rx_count - 1;

          -- Increment the read address
          rd_addr                := rd_addr  + 4;

          -- Set the outputs with a valid word
          -- rx_readdatavalid_int = 1'b1;

        end if;

        -- If an active write transfer in progress, transfer data
        if tx_write = '1' and tx_waitrequest_int = '0' and tx_count /= 0 then

          for i in TX_WR_DATA_WIDTH/32-1 downto 0 loop

            MemWrite(wr_addr, to_integer(signed(tx_writedata(i*32+31 downto i*32))), ALL_BYTES_EN);

            -- Increment the write address
            wr_addr              := wr_addr  + 4;
          end loop;

          -- Decrement the word count
          tx_count               := tx_count - 1;

        end if;

        -- If a write port access valid, write data
        if wr_port_valid = '1' then
          MemWrite(to_integer(signed(wr_port_addr)), to_integer(signed(wr_port_data)), ALL_BYTES_EN);
        end if;

      end if;
    end loop;
  end process;

end model;