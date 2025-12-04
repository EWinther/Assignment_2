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

--------------------------------------------------------------------------------
--  ACCELERATOR
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
        win_ready: out bit_t;
        finish : out bit_t
    );
end acc;

architecture rtl of acc is

    subtype pixel_t is std_logic_vector(7 downto 0);
    type row_t is array(0 to 351) of pixel_t;
    
    constant IMG_HEIGHT  : integer := 288;                -- 0..287
    constant IMG_WIDTH   : integer := 352;
    constant BURST       : integer := 4;
    constant LAST_COL    : integer := IMG_WIDTH - BURST;  -- 348
    constant FIRST_WIN_COL : integer := 0;                 -- center = 1
    constant LAST_WIN_COL  : integer := IMG_WIDTH - 3;     -- 352-3 = 349, center = 350
    constant WORDS_PER_ROW    : integer := IMG_WIDTH / 4;  -- 352 / 4 = 88
    constant TOTAL_WORDS      : integer := (IMG_WIDTH * IMG_HEIGHT) / 4;
    constant PROCESSED_BASE   : integer := TOTAL_WORDS / 2;  
    
    

   
    -- For filing up buffers
    signal LB0, LB1, LB2 : row_t;
    signal col          : integer range 0 to 351 := 0;
    signal row_cnt      : integer range 0 to 287 := 0;
    signal active_buf   : integer range 0 to 2 := 0;    

    -- FLAGS
    signal Data_ready   : std_logic := '0';
    signal buf_ready    : std_logic := '0';
    signal load_hold    : std_logic := '0';
    signal win_ready_s : std_logic := '0';

    -- For each pixel in the 3x3 window
    signal p00, p01, p02 : pixel_t;
    signal p10, p11, p12 : pixel_t;
    signal p20, p21, p22 : pixel_t;
    signal sobel_out     : pixel_t;

    
    -- Signals from FSM
    ----------------------------------------------------------------
    signal ram_en_s       : std_logic := '0';
    signal ram_we_s       : std_logic := '0';
    signal load_en_s      : std_logic := '0';
    signal do_sobel_s     : std_logic := '0';
    signal write_back_s   : std_logic := '0';
    signal finish_s       : std_logic := '0';

    -- Sobel handshake placeholder
    signal sobel_word : std_logic_vector(31 downto 0) := (others => '0');
    signal sobel_col  : integer range 0 to 351 := 0;
    signal sobel_row  : integer range 0 to 287 := 0;
    signal pixel_cnt  : integer range 0 to 3 := 0;
    signal sobel_word_ready_s : std_logic := '0';


begin            

	-- Load from memory
    ----------------------------------------------------
	Load_proc : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                col <= 0;
                row_cnt <= 0;
                active_buf <= 0;
                data_ready <= '0';
                buf_ready <= '0';
                load_hold <= '0';
                
                LB0 <= (others => (others => '0'));
                LB1 <= (others => (others => '0'));
                LB2 <= (others => (others => '0'));
            
            else 
                if (win_ready_S = '1') and (load_hold = '1') then
                    load_hold <= '0';
                end if;
            
                if (row_cnt = IMG_HEIGHT-1) and (buf_ready = '1') and (win_ready_s = '1') then
                    data_ready <= '1';
                    buf_ready  <= '0';
                end if;
            
                ----------------------------------------------------------------
                if (load_en_s = '1') AND (load_hold = '0') AND (data_ready = '0') then  
                
                    
                    -- 1'st stage: Fill all 3 linebuffers with active_buf
                    ----------------------------------------------------------------
                    if buf_ready = '0' then
                        
                        -- Write 4 pixels to selected buffer
                        case active_buf is 
                              when 0 => 
                                  LB0(col )   <= dataR(31 downto 24);
                                  LB0(col+1)  <= dataR(23 downto 16);
                                  LB0(col+2)  <= dataR(15 downto 8);
                                  LB0(col+3)  <= dataR(7 downto 0);
                              
                              when 1 =>
                                  LB1(col )   <= dataR(31 downto 24);
                                  LB1(col+1)  <= dataR(23 downto 16);
                                  LB1(col+2)  <= dataR(15 downto 8);
                                  LB1(col+3)  <= dataR(7 downto 0);
                              
                              when 2 =>
                                  LB2(col )   <= dataR(31 downto 24);
                                  LB2(col+1)  <= dataR(23 downto 16);
                                  LB2(col+2)  <= dataR(15 downto 8);
                                  LB2(col+3)  <= dataR(7 downto 0);
                              
                              when others =>
                                  null;
                        end case;
                      
                        if col < LAST_COL then
                            col <= col + BURST; --col + 4
                        
                        else
                            col <= 0;
                            
                            if active_buf < 2 then
                                -- Gå videre til næste buffer (0 -> 1 -> 2)
                                active_buf <= active_buf + 1;
                            
                            else
                                -- Alle 3 buffere er nu fyldt første gang
                               -- active_buf <= 0;
                                buf_ready  <= '1';      -- signal til FSM: nu kan Sobel starte
                                
                                if row_cnt < IMG_HEIGHT-1 then
                                   row_cnt <= row_cnt + 1;
                                end if;
                            end if;
                        end if; -- col/LAST_COL


                    
                    -- 2'nd phase: when buf_ready='1' → shift-down:
                    -- LB0 <= LB1, LB1 <= LB2, LB2 <= dataR
                    ----------------------------------------------------------------
                    else  -- buf_ready = '1'

                        LB2(col )   <= dataR(31 downto 24);
                        LB2(col+1)  <= dataR(23 downto 16);
                        LB2(col+2)  <= dataR(15 downto 8);
                        LB2(col+3)  <= dataR(7 downto 0);

                        if col < LAST_COL then
                            col <= col + BURST;
                        else
                            col <= 0;

                            -- when buffer is loaded we shift-down
                            LB0 <= LB1;
                            LB1 <= LB2;

                            -- If Sobel is not done we stop via win_ready/load_hold
                            if (win_ready_s = '0') then
                                load_hold <= '1';
                            else
                                load_hold <= '0';
                            end if;

                            if row_cnt < IMG_HEIGHT-1 then
                               row_cnt <= row_cnt + 1;
                            end if;
                        end if; -- col/LAST_COL

                    end if; -- buf_ready fasevalg

                end if; -- load_en_s & load_hold & not data_ready
    
            end if; -- reset
        end if; -- rising_edge
    end process Load_proc;

    
    ----------------------------------------------------------------
    

    window_proc : process(sobel_col, LB0, LB1, LB2)
begin

    p00 <= LB0(sobel_col);
    p01 <= LB0(sobel_col+1);
    p02 <= LB0(sobel_col+2);

    p10 <= LB1(sobel_col);
    p11 <= LB1(sobel_col+1);
    p12 <= LB1(sobel_col+2);

    p20 <= LB2(sobel_col);
    p21 <= LB2(sobel_col+1);
    p22 <= LB2(sobel_col+2);
end process;
    



-- WRITE BACK PROCESS
-- Packages 4 Sobel pixels into a 32-bit word and writes to RAM
----------------------------------------------------------------
write_proc : process(clk)
variable write_addr : integer; -- For addr calculation
begin
    if rising_edge(clk) then
        if reset = '1' then
            sobel_word <= (others => '0');
            pixel_cnt  <= 0;
            sobel_col  <= 0;
            sobel_row  <= 0;

        else

            if write_back_s = '1' then
                
                -- Put sobel_out into correct byte of sobel_word
                ----------------------------------------------------------------
                case pixel_cnt is 
                    when 0 =>
                        sobel_word(31 downto 24) <= sobel_out;
                    when 1 =>
                        sobel_word(23 downto 16) <= sobel_out;
                    when 2 =>
                        sobel_word(15 downto 8)  <= sobel_out;
                    when 3 =>
                        sobel_word(7 downto 0)   <= sobel_out;
                end case;

                
                -- Increment pixel_cnt
                ----------------------------------------------------------------
                if pixel_cnt < 3 then
                    pixel_cnt <= pixel_cnt + 1;
                else
                    pixel_cnt <= 0;

                    
                    -- FULL 32-bit WORD READY → WRITE TO RAM
                    ----------------------------------------------------------------
                    dataW <= sobel_word;
                    

                    
                    -- UPDATE ADDRESS
                    ----------------------------------------------------------------
                     write_addr :=                      -- addr calculation
                        PROCESSED_BASE                  -- start of processed image
                        + sobel_row * WORDS_PER_ROW     -- row offset
                        + (sobel_col / 4);              -- which 4-pixel block

                    addr <= std_logic_vector(
                        to_unsigned(write_addr, addr'length)); -- to cast the integer to a vector as RAM expects.

                    sobel_word_ready_s <= '1';

                    
                    -- STEP TO NEXT 4-PIXEL BLOCK
                    ------------------------------------------------------------
                    if sobel_col < LAST_WIN_COL then
                        sobel_col <= sobel_col + 1;
                        win_ready_s <= '0';
                    else
                        win_ready_s <= '1';
                        sobel_col <= 0;
                        sobel_row <= sobel_row + 1;
                    end if;

                end if; -- pixel_cnt = 3

            else
                
            end if; -- write_back_s
        end if; -- reset
    end if; -- rising_edge
end process;
    
    
            
    ---------------------------------------------------------------
    -- PORT MAPPING 
    SOBEL_OPS : entity work.sobel_3x3
    port map (
        p00 => p00, p01 => p01, p02 => p02,
        p10 => p10, p11 => p11, p12 => p12,
        p20 => p20, p21 => p21, p22 => p22,
        result_pix => sobel_out
    );

    ----------------------------------------------------------------
    -- FSM
    u_fsm : entity work.fsm
        port map (
            clk               => std_logic(clk),
            reset             => std_logic(reset),
            start             => std_logic(start),

            win_ready         => win_ready_s,
            data_ready        => data_ready,
            buf_ready         => buf_ready,
            load_hold         => load_hold,
            sobel_word_ready => sobel_word_ready_S,
            
            ram_en            => ram_en_s,
            ram_we            => ram_we_s,
            load_en           => load_en_s,
            write_back        => write_back_s,
            finish            => finish_s
        );

    ----------------------------------------------------------------
    -- Output ports
    ----------------------------------------------------------------
    en <= ram_en_s;
    we <= ram_we_s;
    win_ready <= win_ready_s;
    finish <= finish_s;

    
end rtl;
