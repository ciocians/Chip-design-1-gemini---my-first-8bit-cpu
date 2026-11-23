/*
 * Tiny Tapeout Wrapper for Your 8-bit Standalone CPU!
 * Paste this into `src/project.v` in your Tiny Tapeout GitHub repo.
 */
`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs -> CPU wb_data[7:0]
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path  -> {4'b0, pc[3:0]}
    output wire [7:0] uio_oe,   // IOs: Enable path (1=output)
    input  wire       ena,      // Always 1 when the design is powered
    input  wire       clk,      // Clock
    input  wire       rst_n     // Active-low reset (0 = reset, 1 = run)
);
    wire [3:0] pc;
    wire [7:0] wb_data;

    // Instantiate your Standalone 8-bit CPU (note: rst_n is inverted to active-high rst)
    cpu_top my_cpu (
        .clk     (clk),
        .rst     (~rst_n),
        .pc      (pc),
        .wb_data (wb_data)
    );

    assign uo_out  = wb_data;
    assign uio_out = {4'b0000, pc};
    assign uio_oe  = 8'b0000_1111; // Lower 4 uio pins are outputs (pc[3:0])

    // Prevent unused input warnings
    wire _unused = &{ena, ui_in, uio_in, 1'b0};
endmodule

// ---------------- Your Standalone 8-bit CPU ----------------

module cpu_top (
    input  wire       clk,
    input  wire       rst,
    output reg  [3:0] pc,
    output wire [7:0] wb_data
);
    always @(posedge clk) begin
        if (rst)
            pc <= 4'd0;
        else
            pc <= pc + 4'd1;
    end

    wire [15:0] instr;
    imem rom (.addr(pc), .instr(instr));

    wire [2:0] op   = instr[15:13];
    wire [1:0] dst  = instr[12:11];
    wire [1:0] src1 = instr[10:9];
    wire [1:0] src2 = instr[8:7];
    wire [7:0] imm  = instr[7:0];

    wire [7:0] reg_a, reg_b, alu_result;
    wire       alu_zero;

    assign wb_data = (op == 3'd5) ? imm : alu_result;

    regfile rf (
        .clk(clk), .rst(rst), .wr_en(1'b1), .wr_addr(dst), .wr_data(wb_data),
        .rd_addr1(src1), .rd_addr2(src2), .rd_data1(reg_a), .rd_data2(reg_b)
    );

    alu my_alu (.a(reg_a), .b(reg_b), .op(op), .result(alu_result), .zero(alu_zero));
endmodule

module imem (
    input  wire [3:0]  addr,
    output reg  [15:0] instr
);
    localparam [2:0] OP_ADD = 3'd0, OP_SUB = 3'd1, OP_AND = 3'd2,
                     OP_OR  = 3'd3, OP_XOR = 3'd4, OP_LDI = 3'd5;
    localparam [1:0] R0 = 2'd0, R1 = 2'd1, R2 = 2'd2, R3 = 2'd3;

    always @(*) begin
        case (addr)
            4'd0: instr = {OP_LDI, R0, 3'd0, 8'd10};
            4'd1: instr = {OP_LDI, R1, 3'd0, 8'd25};
            4'd2: instr = {OP_ADD, R2, R0, R1, 7'd0};
            4'd3: instr = {OP_SUB, R3, R2, R0, 7'd0};
            4'd4: instr = {OP_ADD, R0, R3, R2, 7'd0};
            default: instr = 16'd0;
        endcase
    end
endmodule

module regfile (
    input  wire       clk,
    input  wire       rst,
    input  wire       wr_en,
    input  wire [1:0] wr_addr,
    input  wire [7:0] wr_data,
    input  wire [1:0] rd_addr1,
    input  wire [1:0] rd_addr2,
    output wire [7:0] rd_data1,
    output wire [7:0] rd_data2
);
    reg [7:0] regs [0:3];
    assign rd_data1 = regs[rd_addr1];
    assign rd_data2 = regs[rd_addr2];

    always @(posedge clk) begin
        if (rst) begin
            regs[0] <= 8'd0; regs[1] <= 8'd0;
            regs[2] <= 8'd0; regs[3] <= 8'd0;
        end else if (wr_en) begin
            regs[wr_addr] <= wr_data;
        end
    end
endmodule

module alu (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire [2:0] op,
    output reg  [7:0] result,
    output wire       zero
);
    always @(*) begin
        case (op)
            3'd0: result = a + b;
            3'd1: result = a - b;
            3'd2: result = a & b;
            3'd3: result = a | b;
            3'd4: result = a ^ b;
            default: result = 8'd0;
        endcase
    end
    assign zero = (result == 8'd0);
endmodule
