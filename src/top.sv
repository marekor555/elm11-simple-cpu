module top(
    input  logic pad_clk_27Mhz,
    input  logic button,
    output logic [5:0] pad_leds
);
    /*
    REG: (A: 0, B: 1)
    ADDR: 11 bits
    
    MEM:
    00001 REG      - STORE 
    00010 REG      - LOAD
    00011 ADDR     - SET ADDR
    00100          - SWITCH A->B B->A
    00111 REG 8bit - SET REG=<8bit>
    
    MATH
    01000          - ADD REGISTERS -> A+B -> A
    01001          - SUBTRACT REGISTERS A-B -> A 
    
    BOOL LOGIC
    10000          - OR ->  A || B B=0
    10001          - AND -> A && B B=0
    10010          - NOT -> A =! A
    10011          - IF A -> JMP B

    EXTRA
    11000 8bit     - JMP 8bit
    11011 15bit     - WAIT <15bit> ms (MAX:32767)
    */


    // // flashing animation
    // logic [19:0] commands[256] = '{
    //     0: 20'b00011_00000000_0000000,    // SET ADDR -> 0
    //     1: 20'b00111_0_00101010_000000,   // set A=0b00101010
    //     2: 20'b00101_000000000000000,     // UNLOCK STORE
    //     3: 20'b00001_0_00000000000000,    // STORE A 
    //     4: 20'b00010_0_00000000000000,    // LOAD TO A
    //     5: 20'b10010_0_0000000000_0000,   // A = !A
    //     6: 20'b00101_000000000000000,     // UNLOCK STORE
    //     7: 20'b00001_0_00000000000000,    // STORE A 
    //     8: 20'b11011_000000011111010,     // WAIT 250ms
    //     9: 20'b11000_00000100_0000000,    //  JMP TO START
    //     default: 20'b0000_0000_0000_0000_0000
    // };

    // // debug
    // logic [19:0] commands[256] = '{
    //     0: 20'b00011_00000000_0000000,    // SET ADDR -> 0
    //     1: 20'b00111_0_00111100_000000,   // set A=0b00111111
    //     3: 20'b00001_0_00000000000000,    // STORE A 
    //     4: 20'b11011_000000011111010,     // WAIT 250ms
    //     5: 20'b11000_00000100_0000000,    //  JMP TO WAIT
    //     default: 20'b0000_0000_0000_0000_0000
    // };

    logic [19:0] commands[256] = '{
        0: 20'b00011_00000000_0000000,  // ADDR=0
        1: 20'b00111_0_00000000_000000, // A = 0
        2: 20'b00111_1_00000001_000000, // B = 1
        3: 20'b01000_000000000000000,   // A = A + B
        4: 20'b00001_0_00000000000000,  // STORE A -> mem[0]
        5: 20'b11011_000000011111010,   // WAIT 250ms
        6: 20'b11000_00000011_0000000,  // JMP 3

        default: 20'b00000_000000000000000
    };
    
    logic [7:0] reg_a = 0, reg_b = 0;
    logic [7:0] programCounter = 0;
    logic [7:0] next_PC;

    logic [7:0] mem[0:2047] = '{
        0: 8'b00_000000, // SET LEDS
        default: 8'b0000_0000
    };

    logic [10:0] mem_addr = 0;

    assign pad_leds = ~mem[0][5:0];
    // assign pad_leds = reg_a[5:0];
    // assign pad_leds = programCounter[5:0];

    logic [32:0] clk = 0;
    logic waiting = 0;

    always_ff @(posedge pad_clk_27Mhz) begin
            next_PC = programCounter + 1;
            case (commands[programCounter][19:15]) // check commands and execute the command
                5'b00001: begin // STORE
                    mem[mem_addr] <= (commands[programCounter][14] == 0) ? reg_a : reg_b;
                end
                5'b00010: begin // LOAD
                    if (commands[programCounter][14] == 0) // REG A
                        reg_a <= mem[mem_addr];
                    else // REG B
                        reg_b <= mem[mem_addr];
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
                end
                5'b01001: begin // SUBSTRACT
                    reg_a <= reg_a - reg_b;
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
                end

                5'b10011: begin // IF A JMP B
                    if (reg_a) begin
                        next_PC = reg_b;
                    end
                end

                5'b11000: begin // JMP 
                    next_PC = commands[programCounter][14:7];
                end
                5'b11011: begin // WAIT
                    if (clk < 32'd27000 * {17'd0, commands[programCounter][14:0]}) begin
                        clk <= clk + 1;
                        next_PC = programCounter; // override program counter
                    end else begin
                        clk <= 0;
                    end
                end
                default: ;
            endcase
            programCounter <= next_PC;
    end
endmodule