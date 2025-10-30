// tb_full_system.v (BẢN SỬA LỖI HOÀN CHỈNH - LINH HOẠT)
`timescale 1ns/1ps

module tb_full_system;
    //==================================================================
    // HÃY SỬA 2 DÒNG DƯỚI ĐÂY ĐỂ THAY ĐỔI BẢN TIN
    //==================================================================
    
    // 1. Đặt số bit thực tế của bản tin
    parameter ACTUAL_BITS = 51; 

    // 2. Gán bản tin của bạn (phải khớp với số bit ở trên)
    reg [ACTUAL_BITS-1:0] actual_data = 51'b1101011001110100010101101010011110011010101010011;

    //==================================================================
    // KHÔNG CẦN SỬA GÌ THÊM BÊN DƯỚI
    //==================================================================

    // parameters
    parameter CLK_FREQ = 50_000_000;
    parameter BAUD = 115200;
    parameter BIT_CYCLES = CLK_FREQ / BAUD; // ~434
    parameter CLK_PERIOD_NS = 1_000_000_000 / CLK_FREQ; // = 20 (ns)
    parameter BIT_TIME_NS = BIT_CYCLES * CLK_PERIOD_NS; // = 8680 (ns)

    // Testbench tự động tính toán kích thước đã đệm
    // Ví dụ: 51 bit -> 52 bit. 10 bit -> 12 bit.
    parameter PADDED_BITS = ((ACTUAL_BITS + 3) / 4) * 4; 

    // Thanh ghi lưu trữ dữ liệu đã đệm
    reg [PADDED_BITS-1:0] input_data; 

    // clock / reset
    reg clk = 0;
    reg rst = 1;
    always #(CLK_PERIOD_NS/2) clk = ~clk; // #10 clk = ~clk

    // serial channel (corruption)
    wire tx_serial;
    reg serial_corrupt = 0;
    wire serial_line;
    assign serial_line = tx_serial ^ serial_corrupt;
    
    // uart signals
    reg tx_start = 0;
    reg [7:0] tx_data = 8'b0;
    wire tx_busy;
    wire rx_ready;
    wire [7:0] rx_data;

    // instantiate uart modules
    uart_tx #(.BIT_CYCLES(BIT_CYCLES)) uart_tx_inst (
        .clk(clk), .rst(rst), .tx_start(tx_start), .tx_data(tx_data),
        .tx_busy(tx_busy), .tx_serial(tx_serial)
    );
    uart_rx #(.BIT_CYCLES(BIT_CYCLES)) uart_rx_inst (
        .clk(clk), .rst(rst), .rx_serial(serial_line),
        .rx_ready(rx_ready), .rx_data(rx_data)
    );
    
    // encoder / decoder
    reg [3:0] enc_in;
    wire [7:0] enc_out;
    hamming_encoder enc_inst(.data_in(enc_in), .code_out(enc_out));

    reg [7:0] dec_in;
    wire [3:0] dec_out;
    wire dec_single_err, dec_double_err;
    hamming_decoder dec_inst(.code_in(dec_in), .data_out(dec_out),
                             .single_error(dec_single_err), .double_error(dec_double_err));
    
    // storage arrays
    reg [7:0] encoded_bytes [0:1023];
    integer enc_count, groups, i, j, rec_ptr, idx, k;
    reg [3:0] recovered [0:1023];
    reg [3:0] nibble;

    initial begin
        // $dumpfile("wave.vcd"); $dumpvars(0, tb_full_system);
        
        // --- Logic PADDING (ĐỆM) tự động ---
        input_data = 0; // Xóa sạch thanh ghi đệm
        // Chép dữ liệu thực tế (ví dụ: 51 bit) vào
        // Các bit cao hơn (ví dụ: bit 52) sẽ vẫn là 0, đóng vai trò là bit đệm
        input_data[ACTUAL_BITS-1:0] = actual_data;
        // --- Kết thúc PADDING ---

        // init
        rst = 1; tx_start = 0; serial_corrupt = 0;
        enc_count = 0; rec_ptr = 0;
        #200; rst = 0; #200;
        
        // Tự động tính toán số nhóm
        groups = (ACTUAL_BITS + 3) / 4;
        enc_count = 0;
        for (i = 0; i < groups; i = i + 1) begin
            idx = i*4;
            // Vòng lặp cuối sẽ tự động lấy các bit đệm
            nibble = input_data[idx +: 4]; 
            enc_in = nibble;
            #20;
            encoded_bytes[enc_count] = enc_out;
            enc_count = enc_count + 1;
        end
        $display("ACTUAL_BITS=%0d (PADDED_TO=%0d) groups=%0d encoded_bytes=%0d", 
                 ACTUAL_BITS, PADDED_BITS, groups, enc_count);
        
        // run three phases
        $display("\n=== PHASE 1: NO ERROR ===");
        send_all_bytes(0);

        $display("\n=== PHASE 2: SINGLE-BIT ERROR (should be corrected) ===");
        send_all_bytes(1);

        $display("\n=== PHASE 3: DOUBLE-BIT ERROR (should be detected) ===");
        send_all_bytes(2);

        #100000;
        $display("\n=== SIM END ===");
        $finish;
    end

    // task send_all_bytes (Đã sửa lỗi time delay của Phase 3)
    task send_all_bytes;
        input integer error_mode;
        integer kk;
        begin
            rec_ptr = 0;
            for (kk = 0; kk < groups; kk = kk + 1) begin // Sửa: lặp qua 'groups' thay vì 'enc_count'
                tx_data = encoded_bytes[kk];
                
                @(negedge clk);
                while (tx_busy) @(negedge clk);
                tx_start = 1;
                @(negedge clk);
                tx_start = 0;
                
                if (error_mode == 0) begin
                    serial_corrupt = 0;
                end else if (error_mode == 1) begin
                    // Phase 2: Chèn 1 lỗi (giữa bit D1)
                    fork
                        begin
                            wait (tx_busy == 1);
                            // Sample time của D1 là 2.5 bit times
                            #(BIT_TIME_NS * 2 + BIT_TIME_NS / 4); // Chờ 2.25 bit times
                            serial_corrupt = 1;
                            #(BIT_TIME_NS / 2); // Giữ lỗi (từ 2.25 -> 2.75)
                            serial_corrupt = 0;
                        end
                    join
                end else begin
                    // Phase 3: Chèn 2 lỗi
                    fork
                        begin
                            wait (tx_busy == 1);
                            
                            // Lỗi 1: Giữa bit D1 (Sample time là 2.5 bits)
                            #(BIT_TIME_NS * 2 + BIT_TIME_NS / 4); // Chờ 2.25 bits
                            serial_corrupt = 1; 
                            #(BIT_TIME_NS / 2); // Giữ lỗi (kết thúc ở 2.75 bits)
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

                // Chờ cho đến khi bộ phát gửi xong
                wait (tx_busy == 0);
                
                // Đọc dữ liệu đã nhận
                dec_in = rx_data;
                #1; // Đợi 1ns cho logic tổ hợp của decoder
                $display("Sent byte #%0d: encoded=0x%02h  rx=0x%02h  decoded_nibble=0x%01h  single_err=%b double_err=%b",
                         kk, encoded_bytes[kk], rx_data, dec_out, dec_single_err, dec_double_err);

                // Thêm một khoảng nghỉ nhỏ giữa các byte
                #(BIT_TIME_NS * 4);
            end
        end
    endtask

endmodule