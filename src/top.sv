module top(
    input  logic pad_clk_27Mhz,
    input  logic button,
    output logic [5:0] pad_leds
);
    /*
    more technical table of registers, also much more useful(hopefully)
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
    10010          - NOT -> A = ~A
    10011          - IF A -> JMP B
    10111 <8bit>   - IF A = <8bit> -> JMP B

    EXTRA
    11000 8bit     - JMP 8bit
    11011 15bit     - WAIT <15bit> ms (MAX:32767)
    */


    

    // very simple flashing animation
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

    // the animation from the README
    logic [19:0] commands[256] = '{
        0:  20'b00011_00000000_0000000,   // ADDR=0
        1:  20'b00111_0_00000000_000000,  // A = 0
        2:  20'b00111_1_00000001_000000,  // B = 1
        3:  20'b01000_000000000000000,    // A = A + B
        4:  20'b00001_0_00000000000000,   // STORE A -> mem[0]
        5:  20'b11011_000000001100100,    // WAIT 100ms
        6:  20'b00111_1_00001001_000000,  // B = 9
        7:  20'b10111_00111111_0000000,   // IF A = 0b00111111 JMP B(9)
        8:  20'b11000_00000010_0000000,   // JMP 2

        9:  20'b00111_0_00000000_000000,  // A = 0
        10: 20'b00001_0_00000000000000,   // STORE A -> mem[0]
        12: 20'b11011_000001111101000,    // WAIT 1s
        13: 20'b10010_000000000000000,    // A = ~A
        14: 20'b00001_0_00000000000000,   // STORE A -> mem[0]
        15: 20'b11011_000000011111010,    // WAIT 1s
        16: 20'b10010_000000000000000,    // A = ~A
        17: 20'b00001_0_00000000000000,   // STORE A -> mem[0]
        18: 20'b11011_000000011111010,    // WAIT 1s
        19: 20'b11000_00000001_0000000,   // JMP 1

        default: 20'b00000_000000000000000
    };
    
    logic [7:0] reg_a = 0, reg_b = 0;
    logic [7:0] programCounter = 0;
    logic [7:0] next_PC;

    /* syn_ramstyle = "block" */ logic [7:0] mem[0:2047];
    initial begin
        mem = '{default: 8'h00};
    end
    logic [10:0] mem_addr = 0;

    // for WAIT
    logic [32:0] waitClk = 0;
    logic waiting = 0;

    // anti lag for commands and mem to set in after each command
    // for some reason there needs to be a 1 tick delay after each command
    logic cpuState = 1;
    logic [4:0] command = 0;
    logic [14:0] rest = 0;


    // this is required so that mem synths into the more optimized RAM 
    logic [5:0] led_reg = 0;
    assign pad_leds = ~led_reg;


    always_ff @(posedge pad_clk_27Mhz) begin
        if (cpuState == 1) begin
            // Cut out the command into parts
            // This also fixes a delay problem with commands memory
            command <= commands[programCounter][19:15];
            rest <= commands[programCounter][14:0];
            cpuState <= 0;

            led_reg <= mem[0][5:0]; // set leds
        end else begin
            next_PC = programCounter + 1;
            case (command) // check commands and execute the command
                5'b00001: begin // STORE
                    mem[mem_addr] <= (rest[14] == 0) ? reg_a : reg_b;
                end
                5'b00010: begin // LOAD
                    if (rest[14] == 0) // REG A
                        reg_a <= mem[mem_addr];
                    else // REG B
                        reg_b <= mem[mem_addr];
                end
                5'b00011: begin // SET ADDR
                    mem_addr <= rest[14:4];
                end
                5'b00100: begin // SWITCH
                    reg_a <= reg_b;
                    reg_b <= reg_a;
                end
                5'b00111: begin // SET REG
                    if (rest[14] == 0) // REG A
                        reg_a <= rest[13:6];
                    else // REG B
                        reg_b <= rest[13:6];
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
                5'b10111: begin // IF A=<8bit> JMP B
                    if (reg_a == rest[14:7]) begin
                        next_PC = reg_b;
                    end
                end
                5'b11000: begin // JMP 
                    next_PC = rest[14:7];
                end
                5'b11011: begin // WAIT
                    // half of the cycles eaten by waiting so it is 13500
                    if (waitClk < 32'd13500 * {17'd0, rest[14:0]}) begin 
                        waitClk <= waitClk + 1;
                        next_PC = programCounter; // override program counter
                    end else begin
                        waitClk <= 0;
                    end
                end
                default: ;
            endcase
            programCounter <= next_PC;
            cpuState <= 1;
        end
    end
endmodule