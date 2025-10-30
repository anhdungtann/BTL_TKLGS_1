// hamming_decoder.v (ĐÃ SỬA LỖI ĐỂ KHỚP ENCODER)
// Giai ma Hamming (8,4) - SECDED

module hamming_decoder(
    input  wire [7:0] code_in,
    output reg  [3:0] data_out,
    output reg        single_error,
    output reg        double_error
);
    // SỬA LỖI MAPPING: Phải khớp với output của hamming_encoder
    // encoder: {p1, p2, d3, p4, d2, d1, d0, p8}
    // bit pos:   7   6   5   4   3   2   1   0
    wire p1 = code_in[7];
    wire p2 = code_in[6];
    wire d1 = code_in[1]; // d1 (D0 của encoder)
    wire p4 = code_in[4];
    wire d2 = code_in[2]; // d2 (D1 của encoder)
    wire d3 = code_in[3]; // d3 (D2 của encoder)
    wire d4 = code_in[5]; // d4 (D3 của encoder)
    wire p8 = code_in[0];

    // syndrome bits
    wire s1 = p1 ^ d1 ^ d2 ^ d4; // check D0,D1,D3
    wire s2 = p2 ^ d1 ^ d3 ^ d4; // check D0,D2,D3
    wire s4 = p4 ^ d2 ^ d3 ^ d4; // check D1,D2,D3

    wire [2:0] syndrome = {s4, s2, s1};
    // overall parity check
    wire overall = p8 ^ p1 ^ p2 ^ d1 ^ p4 ^ d2 ^ d3 ^ d4;

    reg [7:0] corrected;
    integer pos;

    always @(*) begin
        single_error = 1'b0;
        double_error = 1'b0;
        corrected = code_in;

        if (syndrome != 3'b000) begin
            // error detected by syndrome
            if (overall == 1'b1) begin
                // single error -> fix bit
                pos = syndrome; 
                
                // SỬA LỖI CASE STATEMENT: Map syndrome tới ĐÚNG vị trí bit
                case (pos)
                    1: corrected[7] = ~corrected[7]; // Lỗi P1 (bit 7)
                    2: corrected[6] = ~corrected[6]; // Lỗi P2 (bit 6)
                    3: corrected[1] = ~corrected[1]; // Lỗi D0 (d1) (bit 1)
                    4: corrected[4] = ~corrected[4]; // Lỗi P4 (bit 4)
                    5: corrected[2] = ~corrected[2]; // Lỗi D1 (d2) (bit 2)
                    6: corrected[3] = ~corrected[3]; // Lỗi D2 (d3) (bit 3)
                    7: corrected[5] = ~corrected[5]; // Lỗi D3 (d4) (bit 5)
                    default: ;
                endcase
                single_error = 1'b1;
            end else begin
                // syndrome != 0 and overall == 0 -> double error
                double_error = 1'b1;
            end
        end else begin
            // syndrome == 0
            if (overall == 1'b1) begin
                // single error at overall parity bit (P8)
                corrected[0] = ~corrected[0]; // P8 nằm ở bit 0
                single_error = 1'b1;
            end else begin
                // no error
            end
        end

        // SỬA LỖI OUTPUT MAPPING:
        // extract data bits after possible correction
        data_out[0] = corrected[1]; // D0 (d1)
        data_out[1] = corrected[2]; // D1 (d2)
        data_out[2] = corrected[3]; // D2 (d3)
        data_out[3] = corrected[5]; // D3 (d4)
    end

endmodule