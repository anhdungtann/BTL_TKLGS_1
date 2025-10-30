// uart_tx.v
// Simple UART transmitter (LSB first, 1 start bit (0), 8 data bits, 1 stop bit (1))
// Parameter BIT_CYCLES: number of clk cycles per bit time

module uart_tx #(
    parameter BIT_CYCLES = 434  // default for 50MHz/115200 ~ 434
)(
    input  wire clk,
    input  wire rst,
    input  wire tx_start,       // pulse (1 cycle) to start sending
    input  wire [7:0] tx_data,
    output reg  tx_busy,
    output reg  tx_serial
);
    reg [15:0] cycle_cnt;
    reg [3:0] bit_idx;
    reg [7:0] shift_reg;
    reg sending;

    initial begin
        tx_serial = 1'b1;
        tx_busy = 1'b0;
        sending = 1'b0;
        cycle_cnt = 0;
        bit_idx = 0;
        shift_reg = 8'b0;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_serial <= 1'b1;
            tx_busy <= 1'b0;
            sending <= 1'b0;
            cycle_cnt <= 0;
            bit_idx <= 0;
            shift_reg <= 8'b0;
        end else begin
            if (~sending) begin
                if (tx_start) begin
                    // latch data and start
                    shift_reg <= tx_data;
                    sending <= 1'b1;
                    tx_busy <= 1'b1;
                    cycle_cnt <= 0;
                    bit_idx <= 4'd0;
                    tx_serial <= 1'b0; // start bit
                end else begin
                    tx_serial <= 1'b1;
                    tx_busy <= 1'b0;
                end
            end else begin
                // currently sending: count cycles
                if (cycle_cnt < BIT_CYCLES-1) begin
                    cycle_cnt <= cycle_cnt + 1;
                end else begin
                    cycle_cnt <= 0;
                    // advance to next bit
                    if (bit_idx < 8) begin
                        tx_serial <= shift_reg[0]; // send LSB first
                        shift_reg <= {1'b0, shift_reg[7:1]}; // shift right
                        bit_idx <= bit_idx + 1;
                    end else if (bit_idx == 8) begin
                        // send stop bit
                        tx_serial <= 1'b1;
                        bit_idx <= bit_idx + 1;
                    end else begin
                        // finished (bit_idx == 9)
                        sending <= 1'b0;
                        tx_busy <= 1'b0;
                        tx_serial <= 1'b1;
                        bit_idx <= 0;
                    end
                end
            end
        end
    end

endmodule
