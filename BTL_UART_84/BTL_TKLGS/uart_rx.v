// uart_rx.v (ĐÃ SỬA LỖI)
// Simple UART receiver matching uart_tx (LSB first, 1 start bit, 8 data bits, 1 stop bit)
// Parameter BIT_CYCLES: number of clk cycles per bit time

module uart_rx #(
    parameter BIT_CYCLES = 434
)(
    input  wire clk,
    input  wire rst,
    input  wire rx_serial,
    output reg  rx_ready,      // pulse 1 clk when byte ready
    output reg [7:0] rx_data
);
    reg [15:0] cycle_cnt;
    reg [3:0] bit_idx;
    reg receiving;
    reg [7:0] shift_reg;
    reg rx_serial_sync0, rx_serial_sync1;
    reg start_edge;
    
    initial begin
        rx_ready = 0;
        rx_data = 8'b0;
        cycle_cnt = 0;
        bit_idx = 0;
        receiving = 0;
        shift_reg = 8'b0;
        rx_serial_sync0 = 1'b1;
        rx_serial_sync1 = 1'b1;
    end

    // simple 2-stage synchronizer
    always @(posedge clk) begin
        rx_serial_sync0 <= rx_serial;
        rx_serial_sync1 <= rx_serial_sync0;
    end

    // SỬA LẠI HOÀN TOÀN FSM LOGIC
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_ready <= 0;
            receiving <= 0;
            cycle_cnt <= 0;
            bit_idx <= 0;
            shift_reg <= 0;
        end else begin
            rx_ready <= 0; // Mặc định là xung 1-cycle

            if (~receiving) begin
                // IDLE: Chờ start bit (cạnh xuống)
                if (rx_serial_sync1 == 1'b0) begin
                    receiving <= 1'b1;
                    // Đặt bộ đếm để chờ TỚI GIỮA start bit
                    cycle_cnt <= BIT_CYCLES/2; 
                    bit_idx <= 0; // 0=start, 1-8=data, 9=stop
                end
            end else begin
                // RECEIVING: Đang trong quá trình nhận 1 frame
                if (cycle_cnt > 0) begin
                    cycle_cnt <= cycle_cnt - 1;
                end else begin
                    // Timer hết hạn -> đã đến giữa bit
                    // Nạp lại timer cho bit tiếp theo
                    cycle_cnt <= BIT_CYCLES - 1;

                    if (bit_idx == 0) begin
                        // Đang ở giữa START bit
                        // (Có thể kiểm tra rx_serial_sync1 == 1'b0 ở đây để chống nhiễu)
                        bit_idx <= bit_idx + 1;
                    end
                    else if (bit_idx <= 8) begin
                        // Đang ở giữa DATA bit (D0..D7)
                        // bit_idx=1 -> D0, bit_idx=8 -> D7
                        shift_reg[bit_idx - 1] <= rx_serial_sync1;
                        bit_idx <= bit_idx + 1;
                    end
                    else begin
                        // bit_idx == 9, đang ở giữa STOP bit
                        // (Có thể kiểm tra rx_serial_sync1 == 1'b1 ở đây)
                        rx_data <= shift_reg;
                        rx_ready <= 1'b1; // Phát xung báo hiệu data sẵn sàng
                        receiving <= 1'b0; // Quay về trạng thái IDLE
                    end
                end
            end
        end
    end

endmodule