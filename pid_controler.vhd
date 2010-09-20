-------------------------------------------------------------------------------
-- Title      : Digital PID Controler
-- Project    : 
-------------------------------------------------------------------------------
-- File       : pid_controler.vhd
-- Author     : Tomasz Turek  <tomasz.turek@secom.com.pl>
-- Company    : SeCom Sp Z o. o.
-- Created    : 12:56:06 20-07-2010
-- Last update: 09:23:21 16-09-2010
-- Platform   : Xilinx ISE 10.1.03
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2010 SeCom Sp Z o. o.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date                  Version  Author  Description
-- 12:56:06 20-07-2010   1.0      aTomek  Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity pid_controler is

   generic
      (
            iDataWidith    : integer range 8 to 32 := 8;
            iKP            : integer range 0 to 7  := 3;  -- 0 - /2, 1 - /4, 2 - /8, 3 - /16, 4 - /32, 5 - /64, 6 - /128, 7 - /256
            iKI            : integer range 0 to 7  := 2;  -- 0 - /2, 1 - /4, 2 - /8, 3 - /16, 4 - /32, 5 - /64, 6 - /128, 7 - /256
            iKD            : integer range 0 to 7  := 2;  -- 0 - /2, 1 - /4, 2 - /8, 3 - /16, 4 - /32, 5 - /64, 6 - /128, 7 - /256
            iKM            : integer range 0 to 7  := 1;  -- 0 - /1, 1 - /2, 2 - /4, 3 - /8 , 4 - /16, 5 - /32, 6 - /64 , 7 - /128
            iDelayD        : integer range 1 to 16 := 10;
            iWork          : integer range 0 to 1  := 1   -- 0 - ró¿nica sygna³ów steruj¹cych, 1 - b³¹d
            );

   port
      (
            CLK_I               : in  std_logic;
            RESET_I             : in  std_logic;
            -- b³¹d steruj¹cy regulatorem --
            ERROR_I             : in  std_logic_vector(iDataWidith - 1 downto 0);
            -- wartoœæ progowa --
            PATERN_I            : in  std_logic_vector(iDataWidith - 1 downto 0);
            -- wartoœæ aktualna --
            PATERN_ESTIMATION_I : in  std_logic_vector(iDataWidith - 1 downto 0);
            -- poprawka --
            CORRECT_O           : out std_logic_vector(iDataWidith - 1 downto 0)
            );
   
end entity pid_controler;

architecture rtl of pid_controler is
-------------------------------------------------------------------------------
-- functions --
-------------------------------------------------------------------------------
-- purpose: Tworzy wektor z zer
   function f_something ( constant c_size : integer; signal c_value : std_logic) return std_logic_vector is

      variable var_temp : std_logic_vector(c_size - 1 downto 0);
      
   begin  -- function f_zeros

      var_temp := (others => c_value);

      return var_temp;
      
   end function f_something;

-------------------------------------------------------------------------------
-- types --
-------------------------------------------------------------------------------
   type type_sr is array (0 to iDelayD - 1) of std_logic_vector(iDataWidith - 1 downto 0);
   
-------------------------------------------------------------------------------
-- signals --
-------------------------------------------------------------------------------
   signal v_error    : std_logic_vector(iDataWidith - 1 downto 0);
   signal v_error_KM : std_logic_vector(iDataWidith - 1 downto 0);
   signal v_error_KP : std_logic_vector(iDataWidith - 1 downto 0);
   signal v_error_KD : std_logic_vector(iDataWidith - 1 downto 0);
   signal v_error_KI : std_logic_vector(iDataWidith - 1 downto 0);

   signal t_div_late : type_sr;
   signal v_div : std_logic_vector(iDataWidith - 1 downto 0);
   
   signal v_acu_earl : std_logic_vector(iDataWidith - 1 downto 0);
   signal v_acu : std_logic_vector(iDataWidith - 1 downto 0);

   signal v_sum : std_logic_vector(iDataWidith - 1 downto 0);
   
begin  -- architecture rtl

-------------------------------------------------------------------------------
-- main K --
-------------------------------------------------------------------------------

   v_error <= ERROR_I                                                                             when iWork = 1 else
              conv_std_logic_vector(signed(PATERN_I) - signed(PATERN_ESTIMATION_I) , iDataWidith) when iWork = 0 else
              (others => '0');
   
   v_error_KM <= v_error                                                                                                when iKM = 0 else
                 f_something(c_size => iKM , c_value => v_error(iDataWidith - 1)) & v_error(iDataWidith - 1 downto iKM) when iKM > 0 else
                 (others => '0');

   v_error_KP <= f_something(c_size => iKP + 1 , c_value => v_error_KM(iDataWidith - 1)) & v_error_KM(iDataWidith - 1 downto iKP + 1);
   v_error_KD <= f_something(c_size => iKD + 1 , c_value => v_error_KM(iDataWidith - 1)) & v_error_KM(iDataWidith - 1 downto iKD + 1);
   v_error_KI <= f_something(c_size => iKI + 1 , c_value => v_error_KM(iDataWidith - 1)) & v_error_KM(iDataWidith - 1 downto iKI + 1);

   DI00: process (CLK_I) is
   begin  -- process DI00

      if rising_edge(CLK_I) then

         if RESET_I = '1' then

            t_div_late <= (others => (others => '0'));
            v_div      <= (others => '0');
            v_acu      <= (others => '0');
            v_acu_earl <= (others => '0');

         else

            t_div_late <= v_error_KD & t_div_late(0 to iDelayD - 2);

            v_div <= conv_std_logic_vector(signed(v_error_KD) - signed(t_div_late(iDelayD - 1)) , iDataWidith);

            
            v_acu <= conv_std_logic_vector(signed(v_error_KI) + signed(v_acu_earl) , iDataWidith);
            v_acu_earl <= v_acu;
            
            
         end if;
         
      end if;
      
   end process DI00;

   v_sum <= conv_std_logic_vector(signed(v_acu) + signed(v_div) , iDataWidith);
   CORRECT_O <= conv_std_logic_vector(signed(v_error_KP) + signed(v_sum) , iDataWidith) when RESET_I  = '0' else
                (others => '0');
   
end architecture rtl;
