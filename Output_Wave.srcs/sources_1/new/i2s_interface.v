`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.10.2024 11:11:34
// Design Name: 
// Module Name: i2s_interface
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
//      This is the i2s_interface specifically for outputing 16-bit audio from the ADAU1761 on the Nexys Video: 
//          https://www.analog.com/media/en/technical-documentation/data-sheets/ADAU1761.pdf
//////////////////////////////////////////////////////////////////////////////////


module i2s_interface (
    input wire rst,
    input wire MCLK,
    output reg BCLK,       // Bit clock output (1.536 MHz)
    output reg LRCLK,       // Word select clock output (96 kHz)
    input wire [15:0] dds_data_left, // DDS output data
    input wire [15:0] dds_data_right,
    output reg sdata      // I2S data output to DAC
);
    reg [15:0] left_data, right_data;
    reg [3:0] bit_cnt;
    reg lr_state = 0;
    
    // Clock division parameters (
    parameter BCLK_DIV = 8;  // Chia MCLK cho 8 ra 3.072 MHz BCLK, 16-bit clocks cho 16-bit data
    parameter LRCLK_DIV = 32; // Chia BCLK cho 32 ra 96 kHz LRCLK, 16-bit clocks m?t xung cho 16-bit data, f_MCLK = 256*f_LRCLK

    reg [7:0] bclk_counter;    // ??m chia BCLK 
    reg [8:0] lrclk_counter;   // ??m chia LRCLK 
    
    initial begin
        BCLK <= 1;
        LRCLK <= 0;
        bclk_counter <= 0;
        lrclk_counter <= 0;
        sdata <= 0;
        bit_cnt <= 0;
    end
    
    // Generate BCLK (1.536 MHz)
    always @(posedge MCLK or posedge rst) begin
        if (BCLK === 'bx || BCLK === 'bz) BCLK <= 1;
        if (rst) begin
            bclk_counter <= 0;
            BCLK <= 1;
        end else if (bclk_counter == (BCLK_DIV/2 - 1)) begin
            bclk_counter <= 0;
            BCLK <= ~BCLK;  // ??i BCLK m?i 4 chu k? MCLK 
        end else begin
            bclk_counter <= bclk_counter + 1;
        end
    end
    
    // Generate LRCLK (96 kHz)
    always @(posedge BCLK or posedge rst) begin
        if (rst) begin
            lrclk_counter <= 0;
            LRCLK <= 0;
        end else if (lrclk_counter == (LRCLK_DIV/2 - 1)) begin
            lrclk_counter <= 0;
            LRCLK <= ~LRCLK;  // ??i LRCLK m?i 16 chu k? BCLK 
        end else begin
            lrclk_counter <= lrclk_counter + 1;
        end
    end

    // Sample DDS output for both channels
    always @(posedge LRCLK) begin
        left_data <= dds_data_left;   // Gán giá tr? DDS cho 2 kênh trái ph?i 
        right_data <= dds_data_right;  // Mono => trái ph?i gi?ng nhau 
    end
    
    // Serial data shifting
    always @(posedge BCLK) begin
        if (sdata === 'bx) sdata <= 0;
        if (LRCLK == 0) begin
            if (bit_cnt<16) begin
                sdata <= left_data[15-bit_cnt]; // Left channel
                bit_cnt <= bit_cnt+1;
            end else begin
                bit_cnt <= 0;
            end
        end else begin
            if (bit_cnt<16) begin
                sdata <= right_data[15-bit_cnt]; // Right channel
                bit_cnt <= bit_cnt+1;
            end else begin
                bit_cnt <= 0;
            end
        end
    end

endmodule
