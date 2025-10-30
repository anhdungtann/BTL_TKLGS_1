// uart_rx_hamming13.v
// UART receiver with Hamming (13,8) SECDED decoding
// Receives 2 bytes for each 13-bit codeword (standard 8N1)

module uart_rx_hamming13 #(
    parameter CLKS_PER_BIT = 8
)(
    input        clk,
    input        rst_n,
    input        rx_serial,
    output reg [7:0] data_out,        // decoded data
    output reg       rx_done,         // pulse when complete
    output reg       single_error,
    output reg       double_error
);

    // --- States
    localparam IDLE       = 3'd0;
    localparam START_BIT  = 3'd1;
    localparam DATA_BITS  = 3'd2;
    localparam STOP_BIT   = 3'd3;
    localparam CLEANUP    = 3'd4;

    reg [2:0] state;
    reg [15:0] clk_count;
    reg [3:0] bit_index;
    reg [15:0] rx_word;  // 16-bit word received
    reg        receiving_high_byte;

    // instantiate decoder
    wire [7:0] decoded_data;
    wire       se, de;
    wire [12:0] code_in;

    // assemble 13-bit codeword from rx_word
    assign code_in = {rx_word[15:8], rx_word[7:3]};

    hamming13_decoder decoder_inst (
        .code_in(code_in),
        .data_out(decoded_data),
        .single_error(se),
        .double_error(de)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            clk_count <= 0;
            bit_index <= 0;
            rx_word <= 16'd0;
            rx_done <= 0;
            single_error <= 0;
            double_error <= 0;
            data_out <= 8'd0;
            receiving_high_byte <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    rx_done <= 1'b0;
                    if (rx_serial == 1'b0) begin
                        state <= START_BIT;
                        clk_count <= 0;
                    end
                end

                START_BIT: begin
                    if (clk_count == (CLKS_PER_BIT/2)) begin
                        if (rx_serial == 1'b0) begin
                            clk_count <= 0;
                            bit_index <= 0;
                            state <= DATA_BITS;
                        end else
                            state <= IDLE;
                    end else
                        clk_count <= clk_count + 1;
                end

                DATA_BITS: begin
                    if (clk_count < CLKS_PER_BIT - 1)
                        clk_count <= clk_count + 1;
                    else begin
                        clk_count <= 0;
                        if (receiving_high_byte)
                            rx_word[15 - bit_index] <= rx_serial;
                        else
                            rx_word[7 - bit_index] <= rx_serial;

                        if (bit_index < 7)
                            bit_index <= bit_index + 1;
                        else begin
                            bit_index <= 0;
                            state <= STOP_BIT;
                        end
                    end
                end

                STOP_BIT: begin
                    if (clk_count < CLKS_PER_BIT - 1)
                        clk_count <= clk_count + 1;
                    else begin
                        clk_count <= 0;
                        if (receiving_high_byte) begin
                            receiving_high_byte <= 1'b0;
                            state <= START_BIT; // start receiving low byte
                        end else begin
                            receiving_high_byte <= 1'b1;
                            data_out <= decoded_data;
                            single_error <= se;
                            double_error <= de;
                            rx_done <= 1'b1;
                            state <= CLEANUP;
                        end
                    end
                end

                CLEANUP: begin
                    state <= IDLE;
                    rx_done <= 1'b0;
                end
            endcase
        end
    end

endmodule
