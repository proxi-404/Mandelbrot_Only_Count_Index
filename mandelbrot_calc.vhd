----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 15.05.2023 16:19:33
-- Design Name: 
-- Module Name: mandelbrot_calc - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity mandelbrot_calc is
    generic (
        Mbits : integer;
        mult_delay : integer;
        sizeoftm : integer;
        calc_stages : integer;
        countmax: integer;
        M_X_Pixels: integer;
        log_m_x_pixels: integer;
        M_Y_Pixels: integer
    );
    port(
        clk: in std_logic ;

        new_fig : in std_logic := '1';

        count_in : in unsigned(Countmax downto 0) := (others => '0');
        X_in : in signed(Mbits -1 downto 0) := (others => '0');
        Y_in : in signed (Mbits -1 downto 0) := (others => '0');

        X0_in : in signed(Mbits -1 downto 0) := (others => '0');
        Y0_in : in signed(Mbits -1 downto 0) := (others => '0');

        PY_Next: in unsigned(10 downto 0) := (others => '0');
        PX_next : in unsigned(10 downto 0) := (others => '0');

        count_out : out std_logic_vector(countmax downto 0) := (others => '0');
        --X_out : out signed(Mbits-1 downto 0) := (others => '0');
        --Y_out : out signed(Mbits-1 downto 0) := (others => '0');
        index_out : out integer range 0 to (M_X_Pixels*M_Y_Pixels)-1;
        pixel_done : inout std_logic := '0'

    );

end mandelbrot_calc;

architecture Behavioral of mandelbrot_calc is

    constant init_ref : integer := 2;

    type array_count_type is array (integer range <>) of unsigned(CountMax downto 0);
    signal array_count: array_count_type(0 to SizeOfTm-1) := (others => (others => '0'));


    type array_pixel_type is array (integer range <>) of signed(MBits-1 downto 0);
    signal array_pixel_X  : array_pixel_type(0 to SizeOfTm-1) := (others => (others => '0'));
    signal array_pixel_Y  : array_pixel_type(0 to SizeOfTm-1) := (others => (others => '0'));
    signal array_pixel_X0 : array_pixel_type(0 to SizeOfTm-1) := (others => (others => '0'));
    signal array_pixel_Y0 : array_pixel_type(0 to SizeOfTm-1) := (others => (others => '0'));

    signal array_inp : integer range 0 to SizeOfTm-1 := 0;
    signal array_ref : integer range 0 to SizeOfTm-1 := init_ref;
    signal array_tmp : integer range 0 to SizeOfTm-1 := 0;
    signal array_tmp0 : integer range 0 to SizeOfTm-1 := 0;
    signal array_ref_final : integer range 0 to SizeOfTm-1 := 0;
    signal free 	  : integer range 0 to SizeOfTm-1 := 0;

    type array_BMP_type is array (integer range <>) of integer range 0 to (M_X_Pixels*M_Y_Pixels)-1;
    signal array_BMP   : array_BMP_type(0 to SizeOfTm-1);

    --- multiplication 
    constant multil_size : integer := MBits;

    signal multil_in_X : signed (multil_size-1 downto 0) := (others => '0');
    signal multil_in_Y : signed (multil_size-1 downto 0) := (others => '0');
    signal multi2_in_X : signed (multil_size-1 downto 0) := (others => '0');
    signal multi2_in_Y : signed (multil_size-1 downto 0) := (others => '0');

    signal multi1_result : signed (2*multil_size-1 downto 0) := (others => '0');
    signal multi2_result : signed (2*multil_size-1 downto 0) := (others => '0');
    signal multi3_result : signed (2*multil_size-1 downto 0) := (others => '0');

    signal multi1_result_tmp : unsigned (2*multil_size-1 downto 0) := (others => '0');
    signal multi2_result_tmp : unsigned (2*multil_size-1 downto 0) := (others => '0');
    signal multi3_result_tmp : unsigned (2*multil_size-1 downto 0) := (others => '0');

    -- Registers for sign calculation --------------------------------

    signal sign_bit_reg : std_logic_vector (0 to mult_delay -1);

    --- Mandelbrot registers 
    signal X_out : signed(MBits-1 downto 0) := (others => '0');
    signal Y_out : signed(MBits-1 downto 0) := (others => '0');



begin
    multiplier_1 : entity work.karatsuba_normal -- X
        generic map(
            Mbits => Mbits,
            stages => calc_stages
        )
        port map (
            clk		=> clk,
            num			=> unsigned(abs(multil_in_X)),--   unsigned(abs(X_in_reg(X_in_reg'length -1))),
            num2			=> unsigned(abs(multil_in_X)),--unsigned(abs(X_in_reg(X_in_reg'length -1))),
            mult_out	=> multi1_result_tmp);

    multiplier_2 : entity work.karatsuba_normal -- Y 
        generic map(
            Mbits => Mbits,
            stages => calc_stages
        )
        port map (
            clk		=> clk,
            num			=> unsigned(abs(multil_in_Y)),--unsigned(abs(Y_in_reg(Y_in_reg'length -1))), -- for now shifted after fixing karatsuba for odd length inputs
            num2			=> unsigned(abs(multil_in_Y)),--unsigned(abs(Y_in_reg(Y_in_reg'length -1))),
            mult_out	=> multi2_result_tmp);

    multiplier_3 : entity work.karatsuba_normal --XY
        generic map(
            Mbits => Mbits,
            stages => calc_stages
        )
        port map (
            clk		=> clk,
            num			=> unsigned(abs(multi2_in_X)),--unsigned(abs(X2_in_reg(X2_in_reg'length-1))),
            num2			=> unsigned(abs(multi2_in_Y)),--unsigned(abs(Y2_in_reg(Y2_in_reg'length-1))),
            mult_out	=> multi3_result_tmp);

    p_mandelbrot_input : process(clk)
        variable array_inp_tmp : integer range 0 to SizeOfTm-1 ;
    begin
        if rising_edge(clk) then
            array_inp_tmp := array_inp;
            multil_in_X <= array_pixel_X(array_inp_tmp); --x
            --multi1_in_B <= array_pixel_X(array_inp_tmp);
            multil_in_Y <= array_pixel_Y(array_inp_tmp); -- y
            --multi2_in_B <= array_pixel_Y(array_inp_tmp);
            multi2_in_X <= array_pixel_X(array_inp_tmp); -- xy
            multi2_in_Y <= array_pixel_Y(array_inp_tmp);
        end if;
    end process;

    ref_inp : process(clk)
    begin
        if rising_edge(clk) then
            if new_fig = '1' then
                array_inp <= 0;
                array_ref <= init_ref;
            else
                if array_inp = SizeOfTm-1 then
                    array_inp <= 0;
                else
                    array_inp <= array_inp + 1;
                end if;
                if array_ref = SizeOfTm-1 then
                    array_ref <= 0;
                else
                    array_ref <= array_ref + 1;
                end if;
            end if;
        end if;
    end process;

    result_conv2mandelbrot : process(clk)
    begin
        if rising_edge(clk) then
            multi1_result <= signed(multi1_result_tmp);
            multi2_result <= signed(multi2_result_tmp);

            --- Sign Bit calculation ---- 
            sign_bit_reg <= (multi2_in_X(multi2_in_X'high) xor multi2_in_Y(multi2_in_Y 'high)) & sign_bit_reg(0 to sign_bit_reg'length -2);

            if sign_bit_reg(sign_bit_reg'length -1) = '1' then

                multi3_result <= signed((not multi3_result_tmp) + 1);
            else
                multi3_result <= signed(multi3_result_tmp);
            end if;

        end if;
    end process;

    P_mandelbrot_step1: process (clk)
        variable X_SQ : signed((2*MBits)-1 downto 0);
        variable Y_SQ : signed((2*MBits)-1 downto 0);
        variable SQ_sum : signed((2*MBits)-1 downto 0);
        variable Xtmp : signed((2*MBits)-1 downto 0);
        variable Ytmp : signed((2*MBits)-1 downto 0);
        variable array_ref_tmp : integer range 0 to SizeOfTm-1 := 0;
    begin
        if rising_edge(clk) then
            X_SQ := signed(multi1_result);
            Y_SQ := signed(multi2_result);
            SQ_sum := X_SQ + Y_SQ;
            array_ref_tmp := array_ref;
            if SQ_sum(SQ_sum'high-1)='1' OR array_count(array_ref_tmp)(CountMax)='1' then
                pixel_done <= '1';
            else
                pixel_done <= '0';
            end if;

            if array_pixel_X0(array_ref_tmp)(array_pixel_X0'high) = '0' then
                Xtmp := (X_SQ - Y_SQ) + (array_pixel_X0(array_ref_tmp)(array_pixel_X0'high) & array_pixel_X0(array_ref_tmp)(array_pixel_X0'high) & array_pixel_X0(array_ref_tmp) & to_signed(0, Mbits - 2) );  --X"0000_0000" & "00" & X"0000_0000_0");   --x*x - y*y + x0
            else
                Xtmp := (X_SQ - Y_SQ) + (array_pixel_X0(array_ref_tmp)(array_pixel_X0'high) & array_pixel_X0(array_ref_tmp)(array_pixel_X0'high) & array_pixel_X0(array_ref_tmp) & to_signed(1, Mbits - 2));--X"1111_1111" & "11" & X"1111_1111_1");
            end if;

            if array_pixel_Y0(array_ref_tmp)(array_pixel_Y0'high) = '0' then
                Ytmp := signed(multi3_result) + (array_pixel_Y0(array_ref_tmp)(array_pixel_Y0'high) & array_pixel_Y0(array_ref_tmp)(array_pixel_Y0'high) & array_pixel_Y0(array_ref_tmp)(array_pixel_Y0'high)  & array_pixel_Y0(array_ref_tmp) & to_signed(0, Mbits - 3));-- X"0000_0000" & "0" & X"0000_0000_0");
            else
                Ytmp := signed(multi3_result) + (array_pixel_Y0(array_ref_tmp)(array_pixel_Y0'high) & array_pixel_Y0(array_ref_tmp)(array_pixel_Y0'high) & array_pixel_Y0(array_ref_tmp)(array_pixel_Y0'high)  & array_pixel_Y0(array_ref_tmp) & to_signed(1, Mbits - 3));--X"1111_1111" & "1" & X"1111_1111_1");
            end if;
            X_out <= Xtmp(Xtmp'high-2 downto Xtmp'high-2-Mbits+1); --sdd.dd
            Y_out <= Ytmp(Ytmp'high-3 downto Xtmp'high-3-Mbits+1);
            array_tmp <= array_ref_tmp;
        end if;
    end process;

    p_Mandelbrot_step2_Mux : process(clk) --clk_process
    begin
        if rising_edge(clk) then
            if pixel_done='1' then
                array_BMP(array_tmp)        <= TO_INTEGER(PY_next & PX_next(log_M_X_Pixels-1 downto 0));
                array_pixel_X0(array_tmp)   <= X0_in;
                array_pixel_Y0(array_tmp)   <= Y0_in;
                array_pixel_X(array_tmp)    <= X_in;
                array_pixel_Y(array_tmp)    <= Y_in;
                array_count(array_tmp)      <= (others => '0');
                
                --output
                count_out <= STD_LOGIC_Vector(array_count(array_tmp));
                index_out <= array_BMP(array_tmp);
                
            elsif pixel_done='0' then
                array_pixel_X(array_tmp)    <= X_out;
                array_pixel_Y(array_tmp)    <= Y_out;
                array_count(array_tmp)      <= array_count(array_tmp) + 1;
            end if;
        end if;
    end process;

end Behavioral;