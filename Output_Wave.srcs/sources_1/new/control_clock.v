`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.10.2024 21:27:29
// Design Name: 
// Module Name: control_clock
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module control_clock(
    input wire i2c_clk,           // System clock
    input wire reset,         // Active low reset
    input wire start,
    output reg SCL,       // I2C clock line
    inout wire SDA,       // I2C data line
    output reg config_done    // Configuration done signal
);

    // I2C Parameters
    parameter I2C_ADDRESS = 7'b0111010;   // ADAU1761 I²C address bits [6:0]
    parameter I2C_WRITE = 1'b0;           // R/W bit: 0 for Write
    parameter I2C_FREQ_DIV = 1000;         // Clock divider for I²C clock

    // I2C State Machine States
    parameter IDLE       = 3'b000;
    parameter START      = 3'b001;
    parameter SEND_ADDR  = 3'b010;
    parameter SEND_DATA  = 3'b011;
    parameter STOP       = 3'b100;
    parameter DONE       = 3'b101;

    // Registers to configure ADAU1761 DAC output
    parameter DAC_REG_ADDR = 8'b00000000;       // Example register to configure DAC
    parameter DAC_ENABLE_VAL = 8'b11000011;     // Value to enable DAC output

    // Internal signals
    reg [7:0] i2c_data;       // Data to be sent over I²C
    reg [2:0] state;          // State machine current state
    reg [9:0] sclk_counter;        // Clock divider counter
    reg sda_out;              // SDA output
    reg sda_dir;              // SDA direction (1 = output, 0 = input)
    reg [3:0] bit_count;      // Counts bits sent on SDA
//    reg start_condition;      // Start condition signal
    
    // Tri-state buffer for SDA
    assign SDA = (sda_dir) ? sda_out : 1'bz;
    initial begin 
        SCL <= 0;
        sclk_counter <= 0;
    end
    // Clock Divider for I²C SCL generation / Toggle start_condition
    always @(posedge i2c_clk or posedge reset) begin
        //SCL
        if (SCL === 'bx || SCL === 'bz) begin 
            SCL <= 0;
        end
        if (reset) begin
            sclk_counter <= 0;
            SCL <= 1;
        end else if (sclk_counter == (I2C_FREQ_DIV/2 - 1)) begin
            sclk_counter <= 0;
            SCL <= ~SCL;  
        end else begin
            sclk_counter <= sclk_counter + 1;
        end
    end

    // I²C State Machine
    always @(posedge SCL or negedge reset) begin
        if (!reset) begin
            state <= IDLE;
            sda_out <= 1;
            sda_dir <= 1;
            config_done <= 0;
            bit_count <= 0;
        end else begin
            case (state)
                IDLE: begin
                    sda_out <= 1;  // SDA idle state (high)
                    sda_dir <= 1;  // Set SDA as output
                    config_done <= 0;
                    if (start) begin
                        state <= START;
                    end
                end

                START: begin
                    // Generate Start Condition (SDA goes low while SCL is high)
                    sda_out <= 0;
                    state <= SEND_ADDR;
                    bit_count <= 0;
                end

                SEND_ADDR: begin
                    // Send 7-bit I²C address + Write bit (total 8 bits)
                    if (bit_count < 8) begin
                        sda_out <= (I2C_ADDRESS[6 - bit_count]);  // Send address bits
                        bit_count <= bit_count + 1;
                    end else begin
                        sda_out <= I2C_WRITE;  // Send Write bit (0)
                        bit_count <= 0;
                        state <= SEND_DATA;
                    end
                end

                SEND_DATA: begin
                    // Send register address and data (DAC_REG_ADDR and DAC_ENABLE_VAL)
                    if (bit_count < 8) begin
                        sda_out <= DAC_REG_ADDR[7 - bit_count];  // Send register address bits
                        bit_count <= bit_count + 1;
                    end else begin
                        sda_out <= DAC_ENABLE_VAL[7 - bit_count];  // Send data (DAC enable value)
                        if (bit_count == 7) begin
                            bit_count <= 0;
                            state <= STOP;
                        end else begin
                            bit_count <= bit_count + 1;
                        end
                    end
                end

                STOP: begin
                    // Generate Stop Condition (SDA goes high while SCL is high)
                    sda_out <= 1;
                    config_done <= 1;  // Configuration is done
                    state <= DONE;
                end

                DONE: begin
                    // Stay in DONE state until reset
                    config_done <= 1;
                end

                default: state <= IDLE;
            endcase
        end
    end
    
endmodule
