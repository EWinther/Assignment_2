library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity fsm is
    Port ( clk      : in  std_logic;
           reset    : in  std_logic;
           start    : in  std_logic;

           -- Handshakes
           win_ready    : in std_logic;
           data_ready   : in std_logic;
           buf_ready    : in std_logic;
           load_hold    : in std_logic;
           sobel_word_ready : in std_logic;   -- <<-- ny vigtig port

           -- RAM interface
           ram_en   : out std_logic;
           ram_we   : out std_logic;
           load_en  : out std_logic;
           write_back : out std_logic;

           -- status
           finish   : out std_logic
         );
end fsm;


architecture Behavioral of fsm is

    type state_type is (
        IDLE,
        LOAD,
        SOBEL,
        DONE
    );

    signal state, next_state : state_type;

begin

    --------------------------------------------------------------
    -- SEQUENTIAL PART
    --------------------------------------------------------------
    seq: process(clk, reset)
    begin
        if reset = '1' then
            state <= IDLE;
        elsif rising_edge(clk) then
            state <= next_state;
        end if;
    end process;


    --------------------------------------------------------------
    -- COMBINATIONAL FSM
    --------------------------------------------------------------
    comb: process(state, start, win_ready, buf_ready, load_hold,
                  data_ready, sobel_word_ready)
    begin
        
        -- Default output values
        ram_en     <= '0';
        ram_we     <= '0';
        load_en    <= '0';
        write_back <= '0';
        finish     <= '0';

        next_state <= state;

        case state is

        ------------------------------------------------------------------
        when IDLE =>
            if start = '1' then
                next_state <= LOAD;
            else
                next_state <= IDLE;
            end if;

        ------------------------------------------------------------------
        when LOAD =>
            ram_en  <= '1';
            ram_we  <= '0';      -- ALWAYS READ IN LOAD
            load_en <= '1';

            -- stops load until sobel are ready for line shift
            if load_hold = '1' then
                next_state <= SOBEL;
            else
                next_state <= LOAD;
            end if;

        ------------------------------------------------------------------
        when SOBEL =>
            ram_en <= '1';

            -- writes when 4 pix is collected
            if sobel_word_ready = '1' then
                ram_we     <= '1';
                write_back <= '1';
            end if;

            -- pic. is done
            if data_ready = '1' then
                next_state <= DONE;
            
            -- Sobel window ready for line change
            elsif win_ready = '1' then
                next_state <= LOAD;
            
            else
                next_state <= SOBEL;
            end if;

        ------------------------------------------------------------------
        when DONE =>
            finish <= '1';
            next_state <= DONE;

        ------------------------------------------------------------------
        end case;
    end process;

end Behavioral;
