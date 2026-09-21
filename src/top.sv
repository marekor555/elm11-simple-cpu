module top(
    input  logic pad_clk_27Mhz,
    input  logic button,
    output logic [5:0] pad_leds
);
    /*
    REG: (A: 0, B: 1)
    ADDR: 10 bits
    
    MEM:
    00000 ADDR     - CLEAR
    00001 REG      - STORE 
    00101          - UNLOCK STORE
    00010 REG      - LOAD
    00011 ADDR     - SET ADDR
    00100          - SWITCH A->B B->A
    00111 REG 8bit - SET REG=<8bit>
    
    MATH
    01000          - ADD REGISTERS -> A B=0
    01001          - SUBTRACT REGISTERS A-B -> A B=0 
    
    BOOL LOGIC
    10000          - OR ->  A || B B=0
    10001          - AND -> A && B B=0
    10010          - NOT -> A =! A
    10011          - IF A -> JMP B

    EXTRA
    11000 8bit     - JMP 7bit
    11001          - PUSH LED WITH CURRENT ADDR
    11011 15bit     - WAIT <15bit> ms (MAX:32767)
    */


    // flashing animation
    logic [19:0] commands[256] = '{
        0: 20'b00011_00000000_0000000,    // SET ADDR -> 0
        1: 20'b00111_0_00101010_000000,   // set A=0b00101010
        2: 20'b00101_000000000000000,     // UNLOCK STORE
        3: 20'b00001_0_00000000000000,    // STORE A 
        4: 20'b11001_000000000000000,     // UPDATE LEDS
        5: 20'b00010_0_00000000000000,    // LOAD TO A
        6: 20'b10010_0_0000000000_0000,   // A = !A
        7: 20'b00101_000000000000000,     // UNLOCK STORE
        8: 20'b00001_0_00000000000000,    // STORE A 
        9: 20'b11001_000000000000000,     // UPDATE LEDS
        10: 20'b11011_000000011111010,     // WAIT 250ms
        11: 20'b11000_00000101_0000000,    //  JMP TO START
        default: 20'b0000_0000_0000_0000_0000
    };


    
    logic [7:0] reg_a, reg_b, reg_res;
    logic [7:0] programCounter = 0;
    

    

    logic [7:0] mem[0:2047] = '{
        0: 8'b00_000000, // SET LEDS
        default: 8'b0000_0000
    };
    logic mem_we = 0;
    logic [10:0] mem_addr;
    logic [7:0] mem_in; 
    logic [7:0] mem_out;
    assign mem_out = mem[mem_addr];
    always_ff @(posedge pad_clk_27Mhz) begin
        if (mem_we) mem[mem_addr] <= mem_in;
    end

    logic [7:0] led_reg = 6'b000000;
    assign pad_leds = led_reg;

    logic [32:0] clk = 0;
    logic waiting = 0;

    always_ff @(posedge pad_clk_27Mhz) begin
        // mem_we <= 1'b0;
        if ((button == 1)) begin // if button isnt pressed and clock ticks (every 0.25s)
            if (programCounter != 255) begin 
                programCounter <= programCounter + 1;
            end

            case (commands[programCounter][19:15]) // check commands and execute the command
                5'b00000: begin // CLEAR
                    mem_we <= 1'b1;
                    mem_addr <= commands[programCounter][14:4];
                    mem_in <= 0;
                end
                5'b00001: begin // STORE
                    mem_in <= (commands[programCounter][14] == 0) ? reg_a : reg_b;
                    mem_we <= 1'b0; // close the write behind
                end
                5'b00101: begin // UNLOCK STORE
                    mem_we <= 1'b1; // open the write
                end
                5'b00010: begin // LOAD
                    if (commands[programCounter][14] == 0) // REG A
                        reg_a <= mem_out;
                    else // REG B
                        reg_b <= mem_out;
                end
                5'b00011: begin // SET ADDR
                    mem_addr <= commands[programCounter][14:4];
                end
                5'b00100: begin // SWITCH
                    reg_a <= reg_b;
                    reg_b <= reg_a;
                end
                5'b00111: begin // SET REG
                    if (commands[programCounter][14] == 0) // REG A
                        reg_a <= commands[programCounter][13:6];
                    else // REG B
                        reg_b <= commands[programCounter][13:6];
                end

                5'b01000: begin // ADD
                    reg_a <= reg_a + reg_b;
                    reg_b <= 0;
                end
                5'b01001: begin // SUBSTRACT
                    reg_a <= reg_a - reg_b;
                    reg_b <= 0;
                end

                5'b10000: begin // OR
                    reg_a <= reg_a | reg_b;
                    reg_b <= 0;
                end

                5'b10001: begin // AND
                    reg_a <= reg_a & reg_b;
                    reg_b <= 0;
                end

                5'b10010: begin // NOT
                    reg_a <= ~reg_a;
                    reg_b <= 0;
                end

                5'b10011: begin // IF A JMP B
                    if (reg_a) begin
                        programCounter <= reg_b;
                    end
                end

                5'b11000: begin // JMP 
                    programCounter <= commands[programCounter][14:7];
                end
                5'b11001: begin // PUSH LED
                    led_reg <= mem_out[5:0];
                end
                5'b11011: begin // WAIT
                    if (clk < commands[programCounter][14:0]*27000) begin
                        clk <= clk + 1;
                        programCounter <= programCounter; // override program counter
                    end else begin
                        clk <= 0;
                    end
                end
                default: ;
            endcase
        end
    end
    
endmodule