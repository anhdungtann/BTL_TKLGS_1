// hamming_encoder.v
// Ma hoa Hamming(8,4): 4 bit data -> 8 bit code (3 parity + 1 parity tong)

module hamming_encoder(
    input  [3:0] data_in,   // D3 D2 D1 D0
    output [7:0] code_out   // P1 P2 D3 P4 D2 D1 D0 P8
);
    wire p1, p2, p4, p8;

    // Tinh cac bit parity
    assign p1 = data_in[0] ^ data_in[1] ^ data_in[3]; // P1 bao D0,D1,D3
    assign p2 = data_in[0] ^ data_in[2] ^ data_in[3]; // P2 bao D0,D2,D3
    assign p4 = data_in[1] ^ data_in[2] ^ data_in[3]; // P4 bao D1,D2,D3
    assign p8 = p1 ^ p2 ^ p4 ^ data_in[0] ^ data_in[1] ^ data_in[2] ^ data_in[3]; // parity tong

    // Ghep ma
    assign code_out = {p1, p2, data_in[3], p4, data_in[2], data_in[1], data_in[0], p8};
endmodule