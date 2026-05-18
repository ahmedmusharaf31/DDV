module register (
    input  logic        clk,
    input  logic        rst_,
    input  logic        enable,
    input  logic [7:0]  data,
    output logic [7:0]  out
);

    always_ff @(posedge clk or negedge rst_) begin
        if (!rst_)
            out <= 8'b0;
        else if (enable)
            out <= data;
        else
            out <= out;
    end

endmodule