-------------------------------------------------------------------------------
--  Title      : VHDL package for mem_model and GHDL simulator
--  Project    : UNKNOWN
-------------------------------------------------------------------------------
--  File       : mem_model_pkg_nvc.vhd
--  Author     : Simon Southwell
--  Created    : 2024-09-21
--  Platform   :
--  Standard   : VHDL 2008
-------------------------------------------------------------------------------
--  Description:
--  VHDL package for memory model, defining FLI procedures
-------------------------------------------------------------------------------
--  Copyright (c) 2024 Simon Southwell
-------------------------------------------------------------------------------
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
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package mem_model_pkg is

  type mem_array_t is array (natural range <>) of std_logic_vector;

  procedure MemWrite (
    address   : in  integer;
    data      : in  integer;
    be        : in  integer
  );
  attribute foreign of MemWrite : procedure is "VHPIDIRECT ./VProc.so MemWrite";

  procedure MemRead (
    address   : in  integer;
    data      : out integer;
    be        : in  integer
  );
  attribute foreign of MemRead : procedure is "VHPIDIRECT ./VProc.so MemRead";

end;

package body mem_model_pkg is

  procedure MemWrite (
    address   : in  integer;
    data      : in  integer;
    be        : in  integer
  ) is
  begin
    report "ERROR: foreign subprogram out_params not called";
  end;

  procedure MemRead (
    address   : in  integer;
    data      : out integer;
    be        : in  integer
  ) is
  begin
    report "ERROR: foreign subprogram out_params not called";
  end;

end;