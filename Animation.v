module Animation (
	input CLK, RESET,
	input [1:0] BUTTON,
	output reg[3:0] VGA_R, VGA_G, VGA_B,
	output reg VGA_HS, VGA_VS
);

parameter H_FRONT   = 16;
parameter H_SYNC    = 96;
parameter H_BACK    = 48;
parameter H_DISPLAY = 640;

parameter V_FRONT   = 10;
parameter V_SYNC    = 2;
parameter V_BACK    = 33;
parameter V_DISPLAY = 480;

parameter H_SYNC_START    = H_FRONT;
parameter H_SYNC_END      = H_FRONT + H_SYNC - 1;
parameter H_DISPLAY_START = H_FRONT + H_SYNC + H_BACK;
parameter H_MAX           = H_FRONT + H_SYNC + H_BACK + H_DISPLAY - 1;

parameter V_SYNC_START    = V_FRONT;
parameter V_SYNC_END      = V_FRONT + V_SYNC - 1;
parameter V_DISPLAY_START = V_FRONT + V_SYNC + V_BACK;
parameter V_MAX           = V_FRONT + V_SYNC + V_BACK + V_DISPLAY - 1;

reg[255:0] IMG = 256'b_0000011111100000_0001100000011000_0010000000000100_0100000000000010_0100000000000010_1000000000000001_1000000000000001_1000000000000001_1000000000000001_1000000000000001_1000000000000001_0100000000000010_0100000000000010_0010000000000100_0001100000011000_0000011111100000;


// VGAは25MHzで駆動する. CLKは50MHzなので, 半周期のクロックを生成している.

reg VGA_CLK; // VGA用のClock

always @(posedge CLK) begin
	VGA_CLK = ~VGA_CLK;
end


// 縦×横=800*525を使う. 800は2進数では1100100000なので, 10桁必要となる.

reg[9:0] cnt_h = 10'b0; // 横
reg[9:0] cnt_v = 10'b0; // 縦


// チャタリング除去しつつ、表示サイズを変更する

reg[18:0] tmp_cnt = 0;
reg[4:0] size = 10; // 1 <= size <= 30
reg[1:0] out = 0, buffer = 0;

always @(posedge CLK or negedge RESET) begin
	if (!RESET)
		tmp_cnt <= 0;
	else
		tmp_cnt <= tmp_cnt + 1;
end

always @(posedge CLK) begin
	if (tmp_cnt == 0)
		out <= BUTTON;
end

always @(posedge CLK or negedge RESET) begin
	if (!RESET)
		buffer <= 0;
	else
		buffer <= out;
end

assign inc = out[0] & ~buffer[0];
assign dec = out[1] & ~buffer[1];

always @(posedge CLK or negedge RESET) begin
	if (!RESET) size <= 10;
	else if (inc == 1) size <= (size == 30 ? 30 : size + 1);
	else if (dec == 1) size <= (size == 1 ? 1 : size - 1);
end

reg[9:0]	H_DRAW_START = 240,
			H_DRAW_END   = 399,
			V_DRAW_START = 160,
			V_DRAW_END   = 319;

always @(size) begin
	H_DRAW_START <= (H_DISPLAY - size * 16) / 2;
	H_DRAW_END   <= H_DRAW_START + size * 16 - 1;
	V_DRAW_START <= (V_DISPLAY - size * 16) / 2;
	V_DRAW_END   <= V_DRAW_START + size * 16 - 1;
end
	

// 水平・垂直走査信号をカウント

always @(negedge VGA_CLK) begin
	if (cnt_h < H_MAX)
		cnt_h <= cnt_h + 1;
	else begin
		cnt_h <= 10'd0;
		if (cnt_v < V_MAX)
			cnt_v <= cnt_v + 1;
		else
			cnt_v <= 10'd0;
	end
end


// 水平同期信号

always @(posedge VGA_CLK) begin
	if (cnt_h == H_SYNC_START)
		VGA_HS <= 1'b0;
	if (cnt_h == H_SYNC_END)
		VGA_HS <= 1'b1;
end


// 垂直同期信号

always @(posedge VGA_CLK) begin
	if (cnt_v == V_SYNC_START)
		VGA_VS <= 1'b0;
	if (cnt_v == V_SYNC_END)
		VGA_VS <= 1'b1;
end


// 色付け
reg[9:0] i = 1'b0, j = 1'b0;

always @(posedge VGA_CLK) begin
	if (cnt_h < H_DISPLAY_START || cnt_v < V_DISPLAY_START) begin
		// 非表示領域
		VGA_R <= 4'b0000;
		VGA_G <= 4'b0000;
		VGA_B <= 4'b0000;
	end else begin
		i <= cnt_v - V_DISPLAY_START;
		j <= cnt_h - H_DISPLAY_START;
		if (H_DRAW_START <= j && j <= H_DRAW_END && V_DRAW_START <= i && i <= V_DRAW_END) begin
			if (IMG[(j - H_DRAW_START) / size + ((i - V_DRAW_START) / size) * 16] == 1'b1) begin
				VGA_R <= 4'b1111;
				VGA_G <= 4'b0000;
				VGA_B <= 4'b0000;
			end else begin
				VGA_R <= 4'b0000;
				VGA_G <= 4'b0000;
				VGA_B <= 4'b0000;
			end
		end else begin
			VGA_R <= 4'b1111;
			VGA_G <= 4'b1111;
			VGA_B <= 4'b1111;
		end
	end
end

endmodule
