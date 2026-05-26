`timescale 1ns / 1ps
`default_nettype none

// ==============================================================================
// 1. TOP WRAPPER (Tiny Tapeout Interface)
// ==============================================================================
module tt_um_hardware_anomaly_detection (
    input  wire [7:0] ui_in,   
    output wire [7:0] uo_out,  
    input  wire [7:0] uio_in,  
    output wire [7:0] uio_out, 
    output wire [7:0] uio_oe,  
    input  wire       ena,     
    input  wire       clk,     
    input  wire       rst_n    
);
    serial_anomaly_ctrl ctrl_inst (
        .ui_in(ui_in), .uo_out(uo_out), .uio_in(uio_in), .uio_out(uio_out),
        .uio_oe(uio_oe), .ena(ena), .clk(clk), .rst_n(rst_n)
    );

    wire _unused = &{ena, uio_in, 1'b0};
endmodule

// ==============================================================================
// 2. CONTROLLER SKELETON (Internal Wiring)
// ==============================================================================
module serial_anomaly_ctrl (
    input  wire [7:0] ui_in,   
    output wire [7:0] uo_out,  
    input  wire [7:0] uio_in,  
    output wire [7:0] uio_out, 
    output wire [7:0] uio_oe,  
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    wire [63:0] packet_data;
    wire        packet_ready;
    wire [7:0]  node_x0, node_x1;
    wire        m_axis_tvalid;
    wire [15:0] mac_0, mac_1, mac_2, mac_3;
    wire        core_tvalid;
    wire        score_valid;
    wire [7:0]  final_score, parallel_score;
    wire        irq, done, tx_pin;

    wire bit_in    = ui_in[0];
    wire bit_valid = ui_in[1];
    wire mode_sel  = ui_in[2];

    v2x_input_if u_input (
        .clk(clk), .rst_n(rst_n), .bit_in(bit_in), .bit_valid(bit_valid),
        .packet_data(packet_data), .packet_ready(packet_ready)
    );

    feature_extractor u_extractor (
        .packet_data(packet_data), .node_x0(node_x0), .node_x1(node_x1)
    );

    axi_stream_dma u_dma (
        .clk(clk), .rst_n(rst_n), .packet_ready(packet_ready),
        .m_axis_tready(1'b1), .m_axis_tvalid(m_axis_tvalid)
    );

    systolic_array_core u_core (
        .clk(clk), .rst_n(rst_n), .s_axis_tvalid(m_axis_tvalid),
        .node_x0(node_x0), .node_x1(node_x1), .m_axis_tvalid(core_tvalid),
        .mac_accumulator_0(mac_0), .mac_accumulator_1(mac_1),
        .mac_accumulator_2(mac_2), .mac_accumulator_3(mac_3)
    );

    anomaly_scoring u_scoring (
        .clk(clk), .rst_n(rst_n), .s_axis_tvalid(core_tvalid),
        .mac_accumulator_0(mac_0), .score_valid(score_valid), .final_score(final_score)
    );

    output_endpoints u_endpoints (
        .clk(clk), .rst_n(rst_n), .score_valid(score_valid), .final_score(final_score),
        .parallel_score(parallel_score), .irq(irq), .done(done), .tx_pin(tx_pin)
    );

    assign uo_out  = parallel_score;
    assign uio_out = {5'b00000, tx_pin, irq, done};
    assign uio_oe  = 8'b0000_0111;
endmodule

// ==============================================================================
// 3. LAYER 1: V2X SIPO INGESTION
// ==============================================================================
module v2x_input_if (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        bit_in,
    input  wire        bit_valid,
    output reg  [63:0] packet_data,
    output reg         packet_ready
);
    reg [63:0] shift_reg;
    reg [5:0]  bit_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg    <= 64'h0;
            bit_count    <= 6'd0;
            packet_data  <= 64'h0;
            packet_ready <= 1'b0;
        end else begin
            if (bit_valid) begin
                shift_reg <= {bit_in, shift_reg[63:1]};
                if (bit_count == 6'd63) begin
                    bit_count    <= 6'd0;
                    packet_ready <= 1'b1;
                end else begin
                    bit_count    <= bit_count + 1'b1;
                    packet_ready <= 1'b0;
                end
            end else begin
                packet_ready <= 1'b0;
            end
            if (packet_ready) packet_data <= shift_reg;
        end
    end
endmodule

// ==============================================================================
// 4. LAYER 2: FEATURE EXTRACTOR
// ==============================================================================
module feature_extractor (
    input  wire [63:0] packet_data,
    output wire [7:0]  node_x0,
    output wire [7:0]  node_x1
);
    assign node_x0 = {packet_data[24], packet_data[25], packet_data[26], packet_data[27],
                      packet_data[28], packet_data[29], packet_data[30], packet_data[31]};

    assign node_x1 = {packet_data[16], packet_data[17], packet_data[18], packet_data[19],
                      packet_data[20], packet_data[21], packet_data[22], packet_data[23]};
endmodule

// ==============================================================================
// 5. LAYER 3: AXI-STREAM DMA FLOW CONTROL
// ==============================================================================
module axi_stream_dma (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       packet_ready,
    input  wire       m_axis_tready,
    output reg        m_axis_tvalid
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axis_tvalid <= 1'b0;
        end else begin
            if (packet_ready) m_axis_tvalid <= 1'b1;
            else if (m_axis_tready) m_axis_tvalid <= 1'b0;
        end
    end
endmodule

// ==============================================================================
// 6. LAYER 4: SYSTOLIC NEURAL CORE
// ==============================================================================
module systolic_array_core (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        s_axis_tvalid,
    input  wire [7:0]  node_x0,
    input  wire [7:0]  node_x1,
    output reg         m_axis_tvalid,
    output reg  [15:0] mac_accumulator_0,
    output reg  [15:0] mac_accumulator_1,
    output reg  [15:0] mac_accumulator_2,
    output reg  [15:0] mac_accumulator_3
);
    localparam signed [7:0] W00 = 8'd12;
    localparam signed [7:0] W01 = 8'd88;
    localparam signed [7:0] W10 = -8'd5;
    localparam signed [7:0] W11 = 8'd22;

    wire signed [7:0] signed_x0 = node_x0;
    wire signed [7:0] signed_x1 = node_x1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mac_accumulator_0 <= 16'h0;
            mac_accumulator_1 <= 16'h0;
            mac_accumulator_2 <= 16'h0;
            mac_accumulator_3 <= 16'h0;
            m_axis_tvalid     <= 1'b0;
        end else if (s_axis_tvalid) begin
            if (($signed(signed_x0) * W00) + ($signed(signed_x1) * W01) > 0)
                mac_accumulator_0 <= ($signed(signed_x0) * W00) + ($signed(signed_x1) * W01);
            else mac_accumulator_0 <= 16'h0;

            if (($signed(signed_x0) * W10) + ($signed(signed_x1) * W11) > 0)
                mac_accumulator_1 <= ($signed(signed_x0) * W10) + ($signed(signed_x1) * W11);
            else mac_accumulator_1 <= 16'h0;
                
            m_axis_tvalid <= 1'b1;
        end else begin
            m_axis_tvalid <= 1'b0;
        end
    end
endmodule

// ==============================================================================
// 7. LAYER 5: THREAT SCORING
// ==============================================================================
module anomaly_scoring (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        s_axis_tvalid,
    input  wire [15:0] mac_accumulator_0,
    output reg         score_valid,
    output reg  [7:0]  final_score
);
    localparam THREAT_THRESHOLD = 16'd1500;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            final_score <= 8'h00;
            score_valid <= 1'b0;
        end else if (s_axis_tvalid) begin
            if (mac_accumulator_0 > THREAT_THRESHOLD) final_score <= 8'hFF;
            else final_score <= 8'h00; 
            score_valid <= 1'b1;
        end else begin
            score_valid <= 1'b0;
        end
    end
endmodule

// ==============================================================================
// 8. LAYER 6: OUTPUT ENDPOINTS
// ==============================================================================
module output_endpoints (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       score_valid,
    input  wire [7:0] final_score,
    output reg  [7:0] parallel_score,
    output reg        irq,
    output reg        done,
    output reg        tx_pin
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            parallel_score <= 8'h00;
            irq            <= 1'b0;
            done           <= 1'b0;
            tx_pin         <= 1'b0;
        end else begin
            if (score_valid) begin
                parallel_score <= final_score;
                done           <= 1'b1;
                if (final_score == 8'hFF) irq <= 1'b1;
                else irq <= 1'b0;
            end else begin
                done <= 1'b0;
                irq  <= 1'b0;
            end
        end
    end
endmodule
