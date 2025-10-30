// hamming13_encoder.v
// Hamming (13,8) SECDED encoder
// Mapping: see comments in surrounding chat message

module hamming13_encoder(
    input  wire [7:0] data_in,   // D8..D1 (data_in[7] = D8 ... data_in[0] = D1)
    output wire [12:0] code_out  // 13-bit codeword [12]=p_total .. [0]=p1
);
    // extract data bits for clarity
    wire d1 = data_in[0];
    wire d2 = data_in[1];
    wire d3 = data_in[2];
    wire d4 = data_in[3];
    wire d5 = data_in[4];
    wire d6 = data_in[5];
    wire d7 = data_in[6];
    wire d8 = data_in[7];

    // parity bits (Hamming)
    // p1 covers positions 3,5,7,9,11 -> d1,d2,d4,d5,d7
    wire p1 = d1 ^ d2 ^ d4 ^ d5 ^ d7;

    // p2 covers positions 3,6,7,10,11 -> d1,d3,d4,d6,d7
    wire p2 = d1 ^ d3 ^ d4 ^ d6 ^ d7;

    // p4 covers positions 5,6,7,12 -> d2,d3,d4,d8
    wire p4 = d2 ^ d3 ^ d4 ^ d8;

    // p8 covers positions 9,10,11,12 -> d5,d6,d7,d8
    wire p8 = d5 ^ d6 ^ d7 ^ d8;

    // overall parity bit (even parity across entire codeword)
    wire p_total = p1 ^ p2 ^ p4 ^ p8 ^ d1 ^ d2 ^ d3 ^ d4 ^ d5 ^ d6 ^ d7 ^ d8;

    // assemble codeword (MSB = bit12)
    // {p_total, d8, d7, d6, d5, p8, d4, d3, d2, p4, d1, p2, p1}
    assign code_out = { p_total, d8, d7, d6, d5, p8, d4, d3, d2, p4, d1, p2, p1 };

endmodule
