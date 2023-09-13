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
        CountMax : integer := 8;
        M_X_Pixels: integer := 256;
        M_Y_Pixels: integer := 192
    );
    port (
         clk       : in  std_logic;
         reset : in std_logic;
         index_output : out integer range 0 to (M_X_Pixels*M_Y_Pixels)-1 := 0;
         count_output: out std_logic_vector (CountMax downto 0) := (others => '0')
        );
end Mandelbrot;

architecture Behavioral of Mandelbrot is

    constant MBits : integer := 72;

    constant log_M_X_Pixels : integer := 8;



    signal px_next, py_next : unsigned(10 downto 0) := (others => '0');
    signal X_out : signed(MBits-1 downto 0) := (others => '0');
    signal Y_out : signed(MBits-1 downto 0) := (others => '0');
    signal Pixel_Increment : signed(MBits-1 downto 0):=("00" & "0000000111" & to_signed(0, Mbits - 12)); --x"000000" & x"000000000");   --("00" & "0000001000" & x"000000")
    signal Pixel_Increment_next : signed(MBits-1 downto 0) := (others => '0');
    signal X_next, Y_next : signed(MBits-1 downto 0) := (others => '0');
    signal pixel_done : std_logic := '0';
    signal X_ref : signed(MBits-1 downto 0) := (MBits-1 => '1',MBits-3 => '0',MBits-4 => '0',others => '1');
    signal Y_ref : signed(MBits-1 downto 0) := (MBits-1 => '0',MBits-3 => '1',MBits-9 => '1',others => '0');

    --constants for multiplication
    constant calc_stages : integer := 2;-- stages is the number of until you reach a number smaller than 18 e.g. 72 -> 36 -> 18 => results in 2 stages 
    constant calc_num_reg : integer := calc_stages * 11 + 1; -- num of stages * 11 + 1 


    constant MultiplierDelay : integer := calc_num_reg;
    constant SizeOfTm : integer := MultiplierDelay + 4;

    signal new_fig     : std_logic := '1';
    
    -------------------------------------------------------------
    signal count_out : STD_LOGIC_Vector(CountMax downto 0) := (others => '0');
    signal index        : integer range 0 to (M_X_Pixels*M_Y_Pixels)-1;

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
    signal count_in: unsigned (countmax downto 0) := (others => '0');
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
            count_out => count_out,
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

                        --pixel_increment_next <= Pixel_Increment_final - Pixel_Increment_final srl 8;
                        X_ref <= X_ref + (Pixel_Increment_final sll 4); --- ((pixel_increment_next) sll 4);

                        Y_ref <= Y_ref - ((Pixel_Increment_final sll 3) +(Pixel_Increment_final sll 2)); --- ((pixel_increment_next sll 3) + (pixel_increment_next sll 2));

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

                                Pixel_Increment <= Pixel_Increment_final - (Pixel_Increment_final srl 8);

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
            count_output <= count_out;
        end if;
    end process;

end Behavioral;