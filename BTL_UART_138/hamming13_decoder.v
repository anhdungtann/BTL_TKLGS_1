// hamming13_decoder.v
// Hamming (13,8) SECDED decoder
// Inputs: code_in[12:0] with mapping same as encoder
// Outputs: data_out[7:0] (D8..D1), single_error (1 if corrected), double_error (1 if detected)

module hamming13_decoder(
    input  wire [12:0] code_in,
    output reg  [7:0]  data_out,
    output reg         single_error,
    output reg         double_error
);
    // extract bits from code_in according to mapping
    // code_in[12] = p_total (pos13)
    // code_in[11] = d8 (pos12)
    // code_in[10] = d7 (pos11)
    // code_in[9]  = d6 (pos10)
    // code_in[8]  = d5 (pos9)
    // code_in[7]  = p8 (pos8)
    // code_in[6]  = d4 (pos7)
    // code_in[5]  = d3 (pos6)
    // code_in[4]  = d2 (pos5)
    // code_in[3]  = p4 (pos4)
    // code_in[2]  = d1 (pos3)
    // code_in[1]  = p2 (pos2)
    // code_in[0]  = p1 (pos1)

    wire p_total = code_in[12];
    wire d8 = code_in[11];
    wire d7 = code_in[10];
    wire d6 = code_in[9];
    wire d5 = code_in[8];
    wire p8 = code_in[7];
    wire d4 = code_in[6];
    wire d3 = code_in[5];
    wire d2 = code_in[4];
    wire p4 = code_in[3];
    wire d1 = code_in[2];
    wire p2 = code_in[1];
    wire p1 = code_in[0];

    // syndrome bits (check parity equations)
    wire s1 = p1 ^ d1 ^ d2 ^ d4 ^ d5 ^ d7;       // parity check for p1
    wire s2 = p2 ^ d1 ^ d3 ^ d4 ^ d6 ^ d7;       // parity check for p2
    wire s4 = p4 ^ d2 ^ d3 ^ d4 ^ d8;            // parity check for p4
    wire s8 = p8 ^ d5 ^ d6 ^ d7 ^ d8;            // parity check for p8

    wire [3:0] syndrome = {s8, s4, s2, s1}; // binary position (1..12) if non-zero

    // overall parity: XOR of all 13 bits should be 0 for even parity
    wire overall = p_total ^ p1 ^ p2 ^ p4 ^ p8 ^ d1 ^ d2 ^ d3 ^ d4 ^ d5 ^ d6 ^ d7 ^ d8;

    reg [12:0] corrected;
    reg [3:0] pos; // position to flip (1..12)

    always @(*) begin
        single_error = 1'b0;
        double_error = 1'b0;
        corrected = code_in;
        pos = 4'd0;

        if (syndrome != 4'b0000) begin
            // syndrome indicates a position (1..12)
            pos = syndrome;
            if (overall == 1'b1) begin
                // single-bit error at position 'pos' -> correct it
                // flip the bit at index (pos-1) because pos=1 -> code_in[0], pos=12 -> code_in[11]
                corrected[pos-1] = ~corrected[pos-1];
                single_error = 1'b1;
            end else begin
                // syndrome != 0 but overall == 0 -> even parity with non-zero syndrome -> double error
                double_error = 1'b1;
            end
        end else begin
            // syndrome == 0
            if (overall == 1'b1) begin
                // single error at overall parity bit (pos13)
                corrected[12] = ~corrected[12]; // flip p_total
                single_error = 1'b1;
            end else begin
                // no error
            end
        end

        // extract data bits from corrected codeword
        data_out[0] = corrected[2];  // D1 (pos3)
        data_out[1] = corrected[4];  // D2 (pos5)
        data_out[2] = corrected[5];  // D3 (pos6)
        data_out[3] = corrected[6];  // D4 (pos7)
        data_out[4] = corrected[8];  // D5 (pos9)
        data_out[5] = corrected[9];  // D6 (pos10)
        data_out[6] = corrected[10]; // D7 (pos11)
        data_out[7] = corrected[11]; // D8 (pos12)
    end

endmodule
