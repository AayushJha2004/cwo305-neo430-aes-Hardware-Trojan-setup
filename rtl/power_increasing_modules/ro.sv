module ro
    #(parameter NO_STAGES = 103)
    (
        input  logic enable,
        output logic out 
    );
    
    (*DONT_TOUCH = "yes"*) logic [NO_STAGES-1:0] osc;
 
    assign osc[0] = enable? ~osc[NO_STAGES-1] : 1'b0;
    genvar i;
    generate
        for (i=1; i < NO_STAGES; i++) begin: generate_stages
            assign osc[i] = ~osc[i-1];
        end
    endgenerate
    
    assign out = osc[NO_STAGES-1];
    
endmodule: ro
   