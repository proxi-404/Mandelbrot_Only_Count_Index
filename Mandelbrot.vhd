-------------------------------------------------------------------------------
-- Mandelbrot overlay
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;
--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;
--use UNISIM.VComponents.all;

use std.textio.all;
use std.env.stop;


entity Mandelbrot is
    generic(
        CountMax : integer := 8
    );
    port (pxl_clk           : in  std_logic;
         clk       : in  std_logic;
         reset : in std_logic;
         index_output : out integer := 0;
         count_output: out std_logic_vector (CountMax downto 0) := (others => '0');
         BtnBar        : IN  std_logic_vector ( 4 DOWNTO 0 );
         SW : in std_logic_vector(7 downto 0)
        );
end Mandelbrot;

architecture Behavioral of Mandelbrot is

    constant MBits : integer := 72;
    constant M_X_Pixels : integer := 256;
    constant log_M_X_Pixels : integer := 8;

    constant M_Y_Pixels : integer := 192;



    signal v_pos                    : integer range 0 to 1023;
    signal h_pos                    : integer range 0 to 1023;
    signal h_ref, v_ref             : integer range 0 to 1023 := 32;

    signal r_in, g_in, b_in      : std_logic_vector(3 downto 0) := (others => '0');
    signal visible_in            : std_logic := '0';
    signal old_visible_in        : std_logic := '0';
    signal H_in, V_in            : std_logic := '0';
    signal r_out, g_out, b_out   : std_logic_vector(3 downto 0) := (others => '0');
    signal visible_out, old_H_in : std_logic := '0';
    signal H_out, V_out          : std_logic := '0';

    signal RADR    					    : integer range 0 to (M_X_Pixels * M_Y_Pixels)-1 := 0;
    signal BMP_pixel                : std_logic_vector(23 downto 0) := (others => '0');
    signal BMP_INPUT 					 : std_logic_vector (CountMax downto 0) := (others => '0');

    signal px_next, py_next : unsigned(10 downto 0) := (others => '0');
    signal X_out : signed(MBits-1 downto 0) := (others => '0');
    signal Y_out : signed(MBits-1 downto 0) := (others => '0');
    signal Pixel_Increment : signed(MBits-1 downto 0):=("00" & "0000000111" & to_signed(0, Mbits - 12)); --x"000000" & x"000000000");   --("00" & "0000001000" & x"000000")
    signal Pixel_Increment_next : signed(MBits-1 downto 0) := (others => '0');
    signal X_next, Y_next : signed(MBits-1 downto 0) := (others => '0');
    signal pixel_done : std_logic := '0';
    signal X_ref : signed(MBits-1 downto 0) := (MBits-1 => '1',MBits-3 => '0',MBits-4 => '0',others => '1');
    signal Y_ref : signed(MBits-1 downto 0) := (MBits-1 => '0',MBits-3 => '1',MBits-9 => '1',others => '0');

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


    --constants for multiplication
    constant calc_stages : integer := 2;-- stages is the number of until you reach a number smaller than 18 e.g. 72 -> 36 -> 18 => results in 2 stages 
    constant calc_num_reg : integer := calc_stages * 11 + 1; -- num of stages * 11 + 1 


    constant MultiplierDelay : integer := calc_num_reg;
    constant SizeOfTm : integer := MultiplierDelay + 4;
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
    signal new_fig     : std_logic := '1';

    type BMP_type is array (integer range <>) of std_logic_vector(CountMax downto 0);
    type BMP_access is access BMP_type;
    signal BMP : BMP_type(0 to (M_X_Pixels*M_Y_Pixels)-1) := (others => (others => '0'));

    -------------------------------------------------------------
    signal reg_count_in : STD_LOGIC_Vector(CountMax downto 0) := (others => '0');
    signal index        : integer range 0 to (M_X_Pixels*M_Y_Pixels)-1;

    signal INPUT_DUL_1	 : std_logic_vector (CountMax downto 0) := (others => '0');
    signal INPUT_DUL_2	 : std_logic_vector (CountMax downto 0) := (others => '0');
    signal INPUT_DUL_3	 : std_logic_vector (CountMax downto 0) := (others => '0');
    signal INPUT_DUL_4	 : std_logic_vector (CountMax downto 0) := (others => '0');
    signal INPUT_DUL_5	 : std_logic_vector (CountMax downto 0) := (others => '0');
    signal INPUT_DUL_6	 : std_logic_vector (CountMax downto 0) := (others => '0');
    signal Pixel_Increment_1 : signed(MBits-1 downto 0) := (others => '0');
    signal Pixel_Increment_2 : signed(MBits-1 downto 0) := (others => '0');
    signal Pixel_Increment_3 : signed(MBits-1 downto 0) := (others => '0');
    signal Pixel_Increment_final : signed(MBits-1 downto 0) := (others => '0');

    -----------------------------------------------------------------
    -- Registers for sign calculation --------------------------------
    signal sign_bit_reg : std_logic_vector (0 to Multiplierdelay -1);
    ---------------------------------------------------------------


    signal X_in, X0_in :  signed(Mbits -1 downto 0) := (others => '0');
    signal Y_in, Y0_in :  signed (Mbits -1 downto 0) := (others => '0');
    signal count_in, count_out : unsigned (countmax downto 0) := (others => '0');
    signal px_next_in, py_next_in : unsigned(10 downto 0) := (others => '0');
BEGIN


    mandelbrot_calc : entity work.mandelbrot_calc
        generic map (
            Mbits => MBits,
            mult_delay => MultiplierDelay,
            sizeoftm => SizeOfTm,
            calc_stages => calc_stages,
            CountMax => CountMax,
            M_X_Pixels => M_X_Pixels,
            log_M_X_Pixels => log_M_X_Pixels,
            M_Y_Pixels => M_Y_Pixels
        )
        port map(
            clk => clk,

            new_fig => new_fig,

            count_in => count_in,
            X_in => X_next,
            Y_in => Y_next,

            X0_in => X_next,
            Y0_in => Y_next,

            PY_Next => py_next,
            PX_next => px_next,

            index_out => index,
            count_out => reg_count_in,
            pixel_done => pixel_done
        );



    ----------------------------------------------------------------------------------------
    -----------------------------Register Duplication---for increment-----------------------
    p_Mandelbrot_Pixel_Increment : process(clk)
    begin
        if rising_edge(clk) then
            if pixel_done='1' then
                Pixel_Increment_1 <= Pixel_Increment;
            end if;
        end if;
    end process;

    Pixel_IncrementDUL_1 : process(clk)
    begin
        if rising_edge(clk) then
            Pixel_Increment_2 <= Pixel_Increment_1;
        end if;
    end process;

    Pixel_IncrementDUL_2 : process(clk)
    begin
        if rising_edge(clk) then
            Pixel_Increment_3 <= Pixel_Increment_2;
        end if;
    end process;

    Pixel_IncrementDUL_3 : process(clk)
    begin
        if rising_edge(clk) then
            Pixel_Increment_final <= Pixel_Increment_3;
        end if;
    end process;

    ----------------------------------------------------------------------------------------
    ----------------------------------------------------------------------------------------
    p_Mandelbrot_next_pixel : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                new_fig <= '1';
                X_ref <= (MBits-1 => '1',MBits-3 => '0',MBits-4 => '0',others => '1');
                Y_ref <= (MBits-1 => '0',MBits-3 => '1',MBits-9 => '1',others => '0');
            else
                if new_fig = '1' then
                    new_fig <= '0';
                    PX_next <= (others => '0');
                    X_next <= X_ref;
                    Y_next <= Y_ref;
                else
                    if pixel_done='1' then
                        if TO_INTEGER(PX_next)=(M_X_Pixels-1) then           -- X overflow
                            PX_next <= (others => '0');
                            X_next  <= X_ref;
                            if TO_INTEGER(PY_next)=(M_Y_Pixels-1) then         -- Y overflow
                                PY_next <= (others => '0');
                                Y_next <= Y_ref;
                                new_fig <= '1';
                            else
                                PY_next <= PY_next + 1;                        -- Y normal
                                Y_next <= Y_next - Pixel_Increment_final;
                                new_fig <= '0';
                            end if;
                        else
                            PX_next <= PX_next + 1;                          -- X normal
                            X_next <= X_next + Pixel_Increment_final;
                            new_fig <= '0';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------------------------
    ---------------------  ZOOM - IN/OUT -----------------------------------------------
    p_test_automatic_zoom : process (clk)
    begin
        if rising_edge(clk) then

            if reset = '1' then
                Pixel_increment_next <= (others => '0');
                X_ref <= (MBits-1 => '1',MBits-3 => '0',MBits-4 => '0',others => '1');
                Y_ref <= (MBits-1 => '0',MBits-3 => '1',MBits-9 => '1',others => '0');
            else
                if new_fig = '1' then
                    if SW(5) = '1' then
                        --Pixel_Increment <= Pixel_Increment_final - (Pixel_Increment_final srl 1);
                        --Pixel_Increment_next <= pixel_increment_final - pixel_increment_final srl 16;
                        pixel_increment_next <= Pixel_Increment_final - Pixel_Increment_final srl 8;
                        --X_ref <= X_ref + (Pixel_Increment_final sll 1) - ((pixel_increment_next) sll 1);
                        X_ref <= X_ref + (Pixel_Increment_final sll 4) - ((pixel_increment_next) sll 4);
                        --Y_ref <= Y_ref - ((Pixel_Increment_final sll 2) +(Pixel_Increment_final sll 1)) - ((pixel_increment_next sll 2) + (pixel_increment_next sll 1));
                        Y_ref <= Y_ref - ((Pixel_Increment_final sll 3) +(Pixel_Increment_final sll 2)) - ((pixel_increment_next sll 3) + (pixel_increment_next sll 2));
                    end if;
                end if;
            end if;
        end if;
    end process;


    pixel_increment_computing : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                Pixel_increment <= ("00" & "0000000111" & to_signed(0, Mbits - 12));
            else
                if pixel_done='1' then
                    if TO_INTEGER(PX_next)=(M_X_Pixels-1) then
                        if TO_INTEGER(PY_next)=(M_Y_Pixels-1) then
                            if SW(5) = '1' then
                                Pixel_Increment <= Pixel_Increment_final - (Pixel_Increment_final srl 8);
                            end if;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;




    p_map_output : process(clk)
    begin
        if rising_edge(clk) then
            index_output <= index;
            count_output <= reg_count_in;
        end if;
    end process;


end Behavioral;