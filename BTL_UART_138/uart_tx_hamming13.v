// uart_tx_hamming13.v
// UART transmitter with Hamming (13,8) encoding
// Uses standard 8N1 UART: 2 bytes sent for 13-bit codeword

module uart_tx_hamming13 #(
    parameter CLKS_PER_BIT = 8
)(
    input        clk,
    input        rst_n,
    input  [7:0] data_in,      // raw data byte
    input        tx_start,     // pulse to start transmission
    output reg   tx_serial,    // UART TX line
    output reg   tx_done       // goes high when 2 bytes transmitted
);

    // --- Internal states
    localparam IDLE       = 3'd0;
    localparam START_BIT  = 3'd1;
    localparam DATA_BITS  = 3'd2;
    localparam STOP_BIT   = 3'd3;
    localparam CLEANUP    = 3'd4;

    reg [2:0] state;
    reg [3:0] bit_index;
    reg [15:0] clk_count;
    reg [15:0] tx_word;   // 16-bit word to send (2 bytes)
    reg        sending_high_byte;

    // --- instantiate encoder
    wire [12:0] encoded_bits;
    hamming13_encoder encoder_inst (
        .data_in(data_in),
        .code_out(encoded_bits)
    );

    // Prepare 16-bit word from 13-bit codeword
    always @(*) begin
        tx_word = {encoded_bits[12:5], encoded_bits[4:0], 3'b000}; // high byte: 8 MSB, low byte: 5 LSB + 3 padding
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            tx_serial <= 1'b1;
            tx_done <= 1'b0;
            clk_count <= 0;
            bit_index <= 0;
            sending_high_byte <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    tx_serial <= 1'b1;
                    tx_done <= 1'b0;
                    if (tx_start) begin
                        sending_high_byte <= 1'b1;
                        bit_index <= 0;
                        clk_count <= 0;
                        state <= START_BIT;
                    end
                end

                START_BIT: begin
                    tx_serial <= 1'b0;
                    if (clk_count < CLKS_PER_BIT - 1)
                        clk_count <= clk_count + 1;
                    else begin
                        clk_count <= 0;
                        state <= DATA_BITS;
                    end
                end

                DATA_BITS: begin
                    tx_serial <= sending_high_byte ? tx_word[15 - bit_index] : tx_word[7 - bit_index];
                    if (clk_count < CLKS_PER_BIT - 1)
                        clk_count <= clk_count + 1;
                    else begin
                        clk_count <= 0;
                        if (bit_index < 7)
                            bit_index <= bit_index + 1;
                        else begin
                            bit_index <= 0;
                            state <= STOP_BIT;
                        end
                    end
                end

                STOP_BIT: begin
                    tx_serial <= 1'b1;
                    if (clk_count < CLKS_PER_BIT - 1)
                        clk_count <= clk_count + 1;
                    else begin
                        clk_count <= 0;
                        if (sending_high_byte) begin
                            sending_high_byte <= 1'b0;
                            state <= START_BIT; // start sending low byte
                        end else begin
                            state <= CLEANUP;
                            tx_done <= 1'b1;
                        end
                    end
                end

                CLEANUP: begin
                    state <= IDLE;
                    tx_done <= 1'b0;
                end
            endcase
        end
    end

endmodule
