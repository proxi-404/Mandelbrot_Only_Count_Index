library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity karatsuba_normal is
    Generic(
        Mbits : natural;
        stages: natural
    );
    Port (
        clk : in std_logic ;
        num : in unsigned (Mbits-1 downto 0) := (others => '0');
        num2 : in unsigned (Mbits-1 downto 0) := (others => '0');
        mult_out : out unsigned((2*Mbits)-1 downto 0) := (others => '0')
    );
end karatsuba_normal;

architecture Behavioral of karatsuba_normal is

    constant add_bits : integer := Mbits/2;

    --output registers with shift registers 
    signal hi_mult_out, hi_mult_shift1, hi_mult_shift2, hi_mult_shift3, mid_mult_out, mid_mult_shift1,
 mid_mult_shift2, mid_mult_shift3, low_mult_out, low_mult_shift1, low_mult_shift2, low_mult_shift3 : unsigned(Mbits-1  downto 0) := (others => '0');

    --multiplication
    signal a0a0, a1a1: unsigned (Mbits-1 downto 0) := (others => '0');
    signal a1a0, tmp0: unsigned(Mbits+1 downto 0) := (others =>'0');
    signal tmp1, tmp1_reg, tmp2: unsigned((2*Mbits)-1 downto 0) := (others => '0');
    signal hi_num1, hi_num2 :  unsigned ((Mbits/2)-1 downto 0):= (others => '0');
    signal lo_num1, lo_num2 :  unsigned ((Mbits/2)-1 downto 0):= (others => '0');
    signal add_res1, add_res2: unsigned ((Mbits/2) downto 0):= (others => '0');

    -- registers for addition pipelining
    signal hi_num1_reg1,hi_num1_reg2,hi_num1_reg3,
 hi_num2_reg1,hi_num2_reg2,hi_num2_reg3 : unsigned ((Mbits/2)-1 downto 0):= (others => '0');
    signal lo_num1_reg1, lo_num1_reg2,lo_num1_reg3,
 lo_num2_reg1, lo_num2_reg2, lo_num2_reg3 : unsigned ((Mbits/2)-1 downto 0):= (others => '0');

    signal lo_add_num1, lo_add_num2 : unsigned ((Mbits/4) downto 0) := (others => '0');
    signal hi_hi_shift1, hi_hi_shift2 ,
 hi_lo_shift1, hi_lo_shift2, lo_shift1, lo_shift2: unsigned ((Mbits/4)-1 downto 0) := (others => '0');
    signal hi_add_num2, hi_add_num1 : unsigned ((Mbits/4) downto 0) := (others => '0');


    --odd case

    signal lo_add_num1_odd, lo_add_num2_odd : unsigned(add_bits/2 downto 0) := (others => '0');
    signal hi_shift1, hi_shift2 : unsigned (add_bits -1 downto add_bits/2) := (others => '0');
    signal lo_shift1_odd, lo_shift2_odd : unsigned (add_bits-1 downto add_bits/2) := (others => '0');
    signal lo_add_shift1, lo_add_shift2 : unsigned(add_bits/2 -1 downto 0) := (others => '0');
    signal hi_add_num1_odd, hi_add_num2_odd : unsigned((add_bits+1)/2 downto 0) := (others => '0');

    -- signals for the carry and carry pipelining
    signal carry1, carry2: std_logic := '0';
    signal carry1_res, carry2_res: unsigned ((Mbits/2)-1 downto 0):= (others => '0');
    signal carry_add_res, carry_shift: unsigned (Mbits+1 downto 0):= (others => '0');

    --type std_logic_reg_type is array(natural range<>) of unsigned;
    signal carry1_reg, carry2_reg : unsigned (0 to (stages-1)*11 +2) :=(others => '0'); -- +3 for last Stage 

    type unsigned_reg is array (natural range<>) of unsigned;
    signal carry_add_reg: unsigned_reg (0 to (stages-1)*11 +1)(Mbits+1 downto 0) := (others => (others => '0'));

    --test registers for addition pipelining
    signal carry1_shift, carry2_shift : std_logic := '0';


begin

    karatsuba_breakdown :  if (Mbits > 18) generate

        lower :  entity work.karatsuba_normal
            generic map(
                Mbits => Mbits/2,
                stages => stages -1
            )
            port map(
                clk => clk,
                num => lo_num1_reg3,
                num2 => lo_num2_reg3,
                mult_out => low_mult_out
            );
        middle:  entity work.karatsuba_normal
            generic map(
                Mbits => Mbits/2,
                stages => stages -1
            )
            port map(
                clk => clk,
                num => add_res1((Mbits/2)-1 downto 0),
                num2 => add_res2((Mbits/2)-1 downto 0),
                mult_out => mid_mult_out
            );
        high :  entity work.karatsuba_normal
            generic map(
                Mbits => Mbits/2,
                stages => stages -1 
            )
            port map(
                clk => clk,
                num =>  hi_num1_reg3,
                num2 =>  hi_num2_reg3,
                mult_out => hi_mult_out
            );

        else generate 

        p_res_calc: process(clk) 
        begin 
            if rising_edge(clk) then 
            if Mbits <= 18 then 
                mult_out <= num*num2;
                end if;
                end if;
                end process;
    
            end generate;



            addition_pipeline : if Mbits > 18 and (Mbits/2 mod 2) = 0 generate
            p_even_addition: process (clk)
    
            begin
                if rising_edge(clk) then
    
                    hi_num1<= num(Mbits-1 downto Mbits/2);
                    lo_num1 <= num((Mbits/2) -1 downto 0);
    
                    hi_num2<= num2(Mbits-1 downto Mbits/2);
                    lo_num2 <= num2((Mbits/2) -1 downto 0);
    
                    --pipeline addition:
                    lo_add_num1 <=  '0' & hi_num1(hi_num1'length/2 -1 downto 0)+ lo_num1(lo_num1'length/2 -1 downto 0);
                    hi_hi_shift1 <= hi_num1(hi_num1'length -1 downto hi_num1'length/2);
                    hi_lo_shift1 <= lo_num1(lo_num1'length - 1 downto lo_num1'length/2);
    
                    hi_add_num1 <= '0' & hi_hi_shift1 + hi_lo_shift1 + lo_add_num1(lo_add_num1'high);
                    lo_shift1 <= lo_add_num1(lo_add_num1'length -2 downto 0);
                    add_res1 <= hi_add_num1 & lo_shift1;
    
                    lo_add_num2 <= '0' & hi_num2(hi_num2'length/2 -1 downto 0)+ lo_num2(lo_num2'length/2 -1 downto 0);
                    hi_hi_shift2 <= hi_num2(hi_num2'length - 1 downto hi_num2'length/2);
                    hi_lo_shift2 <= lo_num2(lo_num2'length - 1 downto lo_num2'length/2);
    
                    hi_add_num2 <= '0' & hi_hi_shift2 + hi_lo_shift2 + lo_add_num2(lo_add_num2'high);
                    lo_shift2 <= lo_add_num2(lo_add_num2'length -2 downto 0);
                    add_res2 <= hi_add_num2 & lo_shift2;
    
                    -- pipeline input
                    hi_num1_reg1 <= hi_num1;
                    hi_num1_reg2 <= hi_num1_reg1;
                    hi_num1_reg3 <= hi_num1_reg2;
    
                    hi_num2_reg1 <= hi_num2;
                    hi_num2_reg2 <= hi_num2_reg1;
                    hi_num2_reg3 <= hi_num2_reg2;
    
                    lo_num1_reg1 <= lo_num1;
                    lo_num1_reg2 <= lo_num1_reg1;
                    lo_num1_reg3 <= lo_num1_reg2;
    
                    lo_num2_reg1 <= lo_num2;
                    lo_num2_reg2 <= lo_num2_reg1;
                    lo_num2_reg3 <= lo_num2_reg2;
    
                    --carry pipelining 
    
                    carry1_reg <= hi_add_num1(hi_add_num1'high) & carry1_reg(0 to carry1_reg'length-2);
                    carry1 <= carry1_reg(carry1_reg'length-1);
    
                    carry2_reg <= hi_add_num2(hi_add_num2'high) & carry2_reg(0 to carry2_reg'length-2);
                    carry2 <= carry2_reg(carry2_reg'length-1);
    
    
                    carry1_shift <= hi_add_num1(hi_add_num1'high);
                    carry2_shift <= hi_add_num2(hi_add_num2'high);
    
                    --carry calculation 
    
    
    
                    carry1_res <= carry1_shift and add_res2((Mbits/2)-1 downto 0);
                    carry2_res <= carry2_shift and add_res1((Mbits/2)-1 downto 0);
    
    
    
                    carry_add_reg <= (to_unsigned(0, (Mbits/2)+1) & '0' & carry1_res + carry2_res) & carry_add_reg(0 to carry_add_reg'length-2);
    
                    carry_add_res <= carry_add_reg(carry_add_reg'length-1);
    
                    carry_shift <= to_unsigned(0, Mbits) & '0' & (carry1 and carry2);
    
                    --result calculation
    
                    low_mult_shift1 <= low_mult_out ;
                    mid_mult_shift1 <= mid_mult_out ;
                    hi_mult_shift1 <= hi_mult_out;
    
                    low_mult_shift2 <= low_mult_shift1;
                    mid_mult_shift2 <= mid_mult_shift1;
                    hi_mult_shift2 <= hi_mult_shift1;
    
                    low_mult_shift3 <= low_mult_shift2;
                    mid_mult_shift3 <= mid_mult_shift2;
                    hi_mult_shift3 <= hi_mult_shift2;
    
                    a0a0 <= low_mult_shift3;
                    a1a0 <= shift_left(carry_shift, Mbits) + shift_left(carry_add_res, Mbits/2) + mid_mult_shift3;
                    a1a1 <= hi_mult_shift3;
    
                    tmp0 <= a1a0 - a1a1 - a0a0;
                    tmp1 <= a1a1 & a0a0;
                    tmp1_reg <= tmp1;
                    tmp2 <=  to_unsigned(0, Mbits-2) & tmp0;
                    mult_out <=  tmp1_reg + shift_left(tmp2 , (Mbits/2));
                end if;
    
            end process;
    
        elsif Mbits > 18 and (Mbits/2 mod 2) = 1 generate
    
    
    
    
            p_odd_addition : process(clk)
    
    
    
            begin
                if rising_edge(clk) then
                    --report "This is the odd case!";
    
                    hi_num1<= num(Mbits-1 downto Mbits/2);
                    lo_num1 <= num((Mbits/2) -1 downto 0);
    
                    hi_num2<= num2(Mbits-1 downto Mbits/2);
                    lo_num2 <= num2((Mbits/2) -1 downto 0);
    
                    -- pipeline addition
                    lo_add_num1_odd <= '0' & hi_num1(add_bits/2-1 downto 0) + lo_num1(add_bits/2-1 downto 0);
                    hi_shift1 <= hi_num1(add_bits-1 downto add_bits/2);
                    lo_shift1_odd <= lo_num1(add_bits-1 downto add_bits/2);
    
                    lo_add_shift1 <= lo_add_num1_odd(lo_add_num1_odd'length -2 downto 0);
                    hi_add_num1_odd <= '0' & hi_shift1 + lo_shift1_odd + lo_add_num1_odd(lo_add_num1_odd'high);
    
                    add_res1 <= hi_add_num1_odd & lo_add_shift1;
    
                    lo_add_num2_odd <= '0' & hi_num2(add_bits/2-1 downto 0) + lo_num2(add_bits/2-1 downto 0);
                    hi_shift2 <= hi_num2(add_bits -1 downto add_bits/2);
                    lo_shift2_odd <= lo_num2(add_bits -1 downto add_bits/2);
    
                    lo_add_shift2 <= lo_add_num2_odd(lo_add_num2_odd'length -2 downto 0);
                    hi_add_num2_odd <= '0' & hi_shift2 + lo_shift2_odd + lo_add_num2_odd(lo_add_num2_odd'high);
    
                    add_res2 <= hi_add_num2_odd & lo_add_shift2;
    
                    -- pipeline input
                    hi_num1_reg1 <= hi_num1;
                    hi_num1_reg2 <= hi_num1_reg1;
                    hi_num1_reg3 <= hi_num1_reg2;
    
                    hi_num2_reg1 <= hi_num2;
                    hi_num2_reg2 <= hi_num2_reg1;
                    hi_num2_reg3 <= hi_num2_reg2;
    
                    lo_num1_reg1 <= lo_num1;
                    lo_num1_reg2 <= lo_num1_reg1;
                    lo_num1_reg3 <= lo_num1_reg2;
    
                    lo_num2_reg1 <= lo_num2;
                    lo_num2_reg2 <= lo_num2_reg1;
                    lo_num2_reg3 <= lo_num2_reg2;
    
                    --carry pipelining 
    
                    carry1_reg <= hi_add_num1_odd(hi_add_num1_odd'high) & carry1_reg(0 to carry1_reg'length-2);
                    carry1 <= carry1_reg(carry1_reg'length-1);
    
                    carry2_reg <= hi_add_num2_odd(hi_add_num2_odd'high) & carry2_reg(0 to carry2_reg'length-2);
                    carry2 <= carry2_reg(carry2_reg'length-1);
    
    
                    carry1_shift <= hi_add_num1_odd(hi_add_num1_odd'high);
                    carry2_shift <= hi_add_num2_odd(hi_add_num2_odd'high);
    
                    --carry calculation 
    
    
    
                    carry1_res <= carry1_shift and add_res2((Mbits/2)-1 downto 0);
                    carry2_res <= carry2_shift and add_res1((Mbits/2)-1 downto 0);
    
    
    
                    carry_add_reg <= (to_unsigned(0, (Mbits/2)+1) & '0' & carry1_res + carry2_res) & carry_add_reg(0 to carry_add_reg'length-2);
    
                    carry_add_res <= carry_add_reg(carry_add_reg'length-1);
    
                    carry_shift <= to_unsigned(0, Mbits) & '0' & (carry1 and carry2);
    
                    --result calculation
    
                    low_mult_shift1 <= low_mult_out ;
                    mid_mult_shift1 <= mid_mult_out ;
                    hi_mult_shift1 <= hi_mult_out;
    
                    low_mult_shift2 <= low_mult_shift1;
                    mid_mult_shift2 <= mid_mult_shift1;
                    hi_mult_shift2 <= hi_mult_shift1;
    
                    low_mult_shift3 <= low_mult_shift2;
                    mid_mult_shift3 <= mid_mult_shift2;
                    hi_mult_shift3 <= hi_mult_shift2;
    
                    a0a0 <= low_mult_shift3;
                    a1a0 <= shift_left(carry_shift, Mbits) + shift_left(carry_add_res, Mbits/2) + mid_mult_shift3;
                    a1a1 <= hi_mult_shift3;
    
                    tmp0 <= a1a0 - a1a1 - a0a0;
                    tmp1 <= a1a1 & a0a0;
                    tmp1_reg <= tmp1;
                    tmp2 <=  to_unsigned(0, Mbits-2) & tmp0;
                    mult_out <=  tmp1_reg + shift_left(tmp2 , (Mbits/2));
                end if;
    
            end process;
    
        end generate addition_pipeline;
end Behavioral;