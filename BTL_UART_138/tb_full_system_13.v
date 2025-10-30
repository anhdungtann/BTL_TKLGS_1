// tb_hamming13_system.v
// Testbench cho hệ thống UART với mã hóa/giải mã Hamming (13,8)
`timescale 1ns/1ps

module tb_full_system_13;
    //==================================================================
    // HÃY SỬA 2 DÒNG DƯỚI ĐÂY ĐỂ THAY ĐỔI BẢN TIN
    //==================================================================
    
    // 1. Đặt số bit thực tế của bản tin
    parameter ACTUAL_BITS = 51; 

    // 2. Gán bản tin của bạn (phải khớp với số bit ở trên)
    //    (Bit MSB bên trái, LSB bên phải)
    reg [ACTUAL_BITS-1:0] actual_data = 51'b110101100111010001010110101001111001101010101010011;

    //==================================================================
    // KHÔNG CẦN SỬA GÌ THÊM BÊN DƯỚI
    //==================================================================

    // parameters
    parameter CLK_FREQ = 50_000_000;
    parameter BAUD = 115200;
    parameter BIT_CYCLES = CLK_FREQ / BAUD; // ~434
    parameter CLK_PERIOD_NS = 1_000_000_000 / CLK_FREQ; // = 20 (ns)
    parameter BIT_TIME_NS = BIT_CYCLES * CLK_PERIOD_NS; // = 8680 (ns)

    // Testbench tự động tính toán kích thước đã đệm (lên bội số của 8 bit)
    parameter PADDED_BITS = ((ACTUAL_BITS + 7) / 8) * 8; 
    parameter NUM_BYTES = PADDED_BITS / 8; // Số byte dữ liệu 8-bit sẽ được gửi
    
    // Thanh ghi lưu trữ dữ liệu đã đệm
    reg [PADDED_BITS-1:0] input_data; 

    // clock / reset
    reg clk = 0;
    reg rst_n = 0; // Modules dùng active-low reset
    always #(CLK_PERIOD_NS/2) clk = ~clk; // #10 clk = ~clk

    // serial channel (corruption)
    wire tx_serial;
    reg serial_corrupt = 0;
    wire serial_line;
    assign serial_line = tx_serial ^ serial_corrupt;
    
    // uart signals
    reg tx_start = 0;
    reg [7:0] tx_data_in = 8'b0; // Dữ liệu 8-bit gốc
    wire tx_done;               // Xung báo hiệu TX đã gửi xong 2 bytes
    
    wire rx_done;               // Xung báo hiệu RX đã nhận/giải mã xong
    wire [7:0] rx_data_out;     // Dữ liệu 8-bit đã giải mã
    wire rx_single_err, rx_double_err;

    // instantiate uart modules (encoder/decoder nằm BÊN TRONG)
    uart_tx_hamming13 #(.CLKS_PER_BIT(BIT_CYCLES)) uart_tx_inst (
        .clk(clk), 
        .rst_n(rst_n), 
        .data_in(tx_data_in), // [cite: 67]
        .tx_start(tx_start),  // [cite: 67]
        .tx_serial(tx_serial),// [cite: 67]
        .tx_done(tx_done)     // [cite: 68]
    );
    
    uart_rx_hamming13 #(.CLKS_PER_BIT(BIT_CYCLES)) uart_rx_inst (
        .clk(clk), 
        .rst_n(rst_n),        // [cite: 26]
        .rx_serial(serial_line), // [cite: 26]
        .data_out(rx_data_out),  // [cite: 26]
        .rx_done(rx_done),       // [cite: 26]
        .single_error(rx_single_err), // 
        .double_error(rx_double_err)  // 
    );
    
    // Logic tạo tín hiệu tx_busy (dựa trên mẫu)
    reg tx_busy = 0;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) tx_busy <= 0;
        else if (tx_start) tx_busy <= 1; // Bắt đầu bận khi có start
        else if (tx_done) tx_busy <= 0;  // Hết bận khi tx_done
    end
    
    // storage arrays
    reg [7:0] input_bytes [0:NUM_BYTES-1];
    reg [7:0] recovered_bytes [0:NUM_BYTES-1];
    integer i, rec_ptr;

    initial begin
        // $dumpfile("wave_hamming13.vcd"); $dumpvars(0, tb_hamming13_system);
        
        // --- Logic PADDING (ĐỆM) tự động (lên bội số 8 bit) ---
        input_data = 0; // Xóa sạch thanh ghi đệm
        // Chép dữ liệu thực tế (ví dụ: 51 bit) vào
        // Các bit cao hơn (ví dụ: 55:51) sẽ vẫn là 0, đóng vai trò là bit đệm
        input_data[ACTUAL_BITS-1:0] = actual_data;
        // --- Kết thúc PADDING ---

        // init
        rst_n = 0; tx_start = 0; serial_corrupt = 0;
        rec_ptr = 0;
        #200; rst_n = 1; #200; // Thả reset (active-low)
        
        // Chuyển bit stream đã đệm (LSB-first) vào mảng byte
        for (i = 0; i < NUM_BYTES; i = i + 1) begin
            // i=0 -> input_data[7:0]
            // i=1 -> input_data[15:8]
            input_bytes[i] = input_data[i*8 +: 8];
        end
        
        $display("ACTUAL_BITS=%0d (PADDED_TO=%0d) NUM_BYTES=%0d", 
                 ACTUAL_BITS, PADDED_BITS, NUM_BYTES);
        
        // run three phases
        $display("\n=== PHASE 1: NO ERROR ===");
        send_all_data(0);

        $display("\n=== PHASE 2: SINGLE-BIT ERROR (should be corrected) ===");
        send_all_data(1);

        $display("\n=== PHASE 3: DOUBLE-BIT ERROR (should be detected) ===");
        send_all_data(2);

        #200000;
        $display("\n=== SIM END ===");
        $finish;
    end

    // task send_all_data
    // Gửi tất cả các byte dữ liệu 8-bit
    task send_all_data;
        input integer error_mode;
        integer kk;
        begin
            rec_ptr = 0;
            for (kk = 0; kk < NUM_BYTES; kk = kk + 1) begin
                tx_data_in = input_bytes[kk]; // [cite: 67]
                
                @(negedge clk);
                // Đợi cho đến khi TX rảnh
                while (tx_busy) @(negedge clk);
                
                tx_start = 1; // [cite: 67]
                @(negedge clk);
                tx_start = 0;
                
                // --- ERROR INJECTION ---
                // (Giống hệt logic của mẫu, sẽ chèn lỗi vào byte UART ĐẦU TIÊN)
                if (error_mode == 0) begin
                    serial_corrupt = 0;
                end else if (error_mode == 1) begin
                    // Phase 2: Chèn 1 lỗi (giữa bit D1)
                    fork
                        begin
                            wait (tx_busy == 1);
                            // Sample time của D1 là 2.5 bit times (Start, D0, D1)
                            #(BIT_TIME_NS * 2 + BIT_TIME_NS / 4); // Chờ 2.25 bit times
                            serial_corrupt = 1;
                            #(BIT_TIME_NS / 2); // Giữ lỗi (từ 2.25 -> 2.75)
                            serial_corrupt = 0;
                        end
                    join
                end else begin
                    // Phase 3: Chèn 2 lỗi (D1 và D5)
                    fork
                        begin
                            wait (tx_busy == 1);
                            
                            // Lỗi 1: Giữa bit D1 (Sample time là 2.5 bits)
                            #(BIT_TIME_NS * 2 + BIT_TIME_NS / 4); // Chờ 2.25 bits
                            serial_corrupt = 1; 
                            #(BIT_TIME_NS / 2); // (kết thúc ở 2.75 bits)
                            serial_corrupt = 0;

                            // Chờ thêm 3.5 bit times nữa để đến giữa bit D5
                            // (Sample time của D5 là 6.5 bits)
                            #(BIT_TIME_NS * 3 + BIT_TIME_NS / 2); 
                            
                            serial_corrupt = 1;
                            #(BIT_TIME_NS / 2); // Giữ lỗi (từ 6.25 -> 6.75)
                            serial_corrupt = 0;
                        end
                    join
                end
                // --- END ERROR INJECTION ---

                // Đợi RX báo nhận xong (rx_done là 1 xung) [cite: 27, 54]
                @(posedge rx_done);
                #1; // Đợi 1ns cho tín hiệu giải mã ổn định
                
                recovered_bytes[rec_ptr] = rx_data_out; // [cite: 26]
                rec_ptr = rec_ptr + 1;
                
                $display("Sent byte #%0d: data_in=0x%02h  decoded_out=0x%02h  single_err=%b double_err=%b",
                         kk, input_bytes[kk], rx_data_out, rx_single_err, rx_double_err);
                         
                // Đợi TX báo gửi xong (tx_done là 1 xung) [cite: 68, 93]
                @(posedge tx_done);
                
                // Thêm một khoảng nghỉ nhỏ giữa các lần gửi
                #(BIT_TIME_NS * 4);
            end
        end
    endtask

endmodule