module ro_bank
    #(parameter RO_COUNT=100)
    (
        input  logic ro_enable,
        output logic bank_out
    );

    // MODIFICATION: wires to hold each RO output
    wire [RO_COUNT-1:0] ro_out;

    genvar i;
    generate 
        for (i=0; i<RO_COUNT; i = i+1) begin: generate_RO
            ro ro_inst (
                .enable(ro_enable), 
                .out(ro_out[i])
            );
        end
    endgenerate

    assign bank_out = ro_out[0];
    
endmodule: ro_bank