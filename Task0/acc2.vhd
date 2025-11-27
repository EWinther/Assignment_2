-- -----------------------------------------------------------------------------
--
--  Title      :  Edge-Detection design project - task 2.
--             :
--  Developers :  YOUR NAME HERE - s??????@student.dtu.dk
--             :  YOUR NAME HERE - s??????@student.dtu.dk
--             :
--  Purpose    :  This design contains an entity for the accelerator that must be build
--             :  in task two of the Edge Detection design project. It contains an
--             :  architecture skeleton for the entity as well.
--             :
--  Revision   :  1.0   ??-??-??     Final version
--             :
--
-- -----------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- The entity for task two. Notice the additional signals for the memory.
-- reset is active high.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity acc is
    port(
        clk    : in  bit_t;             -- The clock.
        reset  : in  bit_t;             -- The reset signal. Active high.
        addr   : out halfword_t;        -- Address bus for data.
        dataR  : in  word_t;            -- The data bus.
        dataW  : out word_t;            -- The data bus.
        en     : out bit_t;             -- Request signal for data.
        we     : out bit_t;             -- Read/Write signal for data.
        start  : in  bit_t;
        finish : out bit_t
    );
end acc;

--------------------------------------------------------------------------------
-- The desription of the accelerator.
--------------------------------------------------------------------------------

architecture rtl of acc is

    constant TOTAL_PIXELS  : integer := 352*288;
    constant WORDS_PER_IMG : integer := TOTAL_PIXELS/4;
    constant SRC_BASE      : integer := 0;
    constant DST_BASE      : integer := WORDS_PER_IMG;

    type state_t is (IDLE, READ, WAIT_1, WAIT_2, WRITE, NEXT_State, DONE);--
    signal state : state_t;

    signal word_index : integer := 0;
    signal read_buf   : std_logic_vector(31 downto 0);

    function invert4(w : std_logic_vector(31 downto 0))
        return std_logic_vector is
        variable r : std_logic_vector(31 downto 0);
        variable b : unsigned(7 downto 0);
    begin
        for i in 0 to 3 loop
            b := unsigned(w(8*i+7 downto 8*i));
            r(8*i+7 downto 8*i) := std_logic_vector(to_unsigned(255,8) - b);
        end loop;
        return r;
    end function;

begin
    process(clk, reset)
    begin
        if reset = '1' then
            state <= IDLE;
            finish <= '0';
            en <= '0';
            we <= '0';
            addr <= (others => '0');
            word_index <= 0;

        elsif rising_edge(clk) then
            case state is

                when IDLE =>
                    finish <= '0';
                    if start = '1' then
                        word_index <= 0;
                        state <= READ;
                    end if;

                when READ =>
                    en   <= '1';
                    we   <= '0';
                    addr <= std_logic_vector(to_unsigned(SRC_BASE + word_index, 16));
--                    read_buf <= dataR;
--                    state <= WRITE;
                    state <= WAIT_1;

                when WAIT_1 =>
                    state <= WAIT_2;
                When WAIT_2 =>
                    read_buf <= dataR;
                    state <= WRITE;

                when WRITE =>
                    en    <= '1';
                    we    <= '1';
                    addr  <= std_logic_vector(to_unsigned(DST_BASE + word_index, 16));
                    dataW <= invert4(read_buf);
                    state <= NEXT_state;

                when NEXT_state =>
                    en <= '0';
                    we <= '0';

                    if word_index = WORDS_PER_IMG-1 then
                        state <= DONE;
                    else
                        word_index <= word_index + 1;
                        state <= READ;
                    end if;

                when DONE =>
                    finish <= '1';
                    state <= IDLE;

            end case;
        end if;
    end process;

end rtl;
