// core_game.vh - Berzerk per-game block (included into the core_top shell)


// -- PLL ---------------------------------------------------------------------
// 74.25 MHz in -> 40 MHz (clk_sys / berzerk.clk_sys)
//                 10 MHz (clk_10 / berzerk.clock_10)
//                 5 MHz  (clk_vid / pixel clock)
//                 5 MHz 90deg (clk_vid_90 / APF DDR pixel clock)
wire clk_sys;
wire clk_10;
wire clk_vid;
wire clk_vid_90;
wire pll_locked;
wire pll_locked_s;

mf_pllbase mp1 (
    .refclk   (clk_74a),
    .rst      (1'b0),
    .outclk_0 (clk_sys),
    .outclk_1 (clk_10),
    .outclk_2 (clk_vid),
    .outclk_3 (clk_vid_90),
    .locked   (pll_locked)
);

synch_3 s_pll (pll_locked, pll_locked_s, clk_74a);



// -- ROM loading via APF bridge -----------------------------------------------
// Image is 0x6000 bytes -> 16-bit dn_addr (entity port is dn_addr[15:0]).

wire [15:0] dn_addr;
wire [7:0]  dn_data;
wire        dn_wr;
reg         rom_loaded_74 = 1'b0;
wire        rom_loaded;
wire        rom_loaded_s = rom_loaded_74;

synch_3 s_rom_to_sys (rom_loaded_74, rom_loaded, clk_sys);

data_loader #(
    .ADDRESS_MASK_UPPER_4 (4'h0),
    .ADDRESS_SIZE         (15),   // 16-bit dn_addr (covers 0x5FFF)
    .OUTPUT_WORD_SIZE     (1)
) u_rom_loader (
    .clk_74a              (clk_74a),
    .clk_memory           (clk_sys),
    .bridge_wr            (bridge_wr),
    .bridge_endian_little (bridge_endian_little),
    .bridge_addr          (bridge_addr),
    .bridge_wr_data       (bridge_wr_data),
    .write_en             (dn_wr),
    .write_addr           (dn_addr),
    .write_data           (dn_data)
);

always @(posedge clk_74a) begin
    if (dataslot_allcomplete)
        rom_loaded_74 <= 1'b1;
end

// -- Reset --------------------------------------------------------------------
wire reset_n_sys;
synch_3 s_resetn (reset_n, reset_n_sys, clk_sys);

reg [7:0] reset_ctr = 8'hFF;
wire      game_reset_n = (reset_ctr == 8'h0) && rom_loaded && reset_n_sys;
wire      game_reset = !game_reset_n;

always @(posedge clk_sys) begin
    if (!pll_locked)
        reset_ctr <= 8'hFF;
    else if (reset_ctr != 8'h0)
        reset_ctr <= reset_ctr - 1'd1;
end

// -- Controller mapping ------------------------------------------------------
// cont1_key bit layout (APF standard):
//   [0] dpad_up  [1] dpad_down  [2] dpad_left  [3] dpad_right
//   [4] face_a   ...   [14] face_select  [15] face_start
//
// Berzerk: 8-way joystick + single Fire button.
wire m_coin   = cont1_key[14] | cont2_key[14];   // SELECT = coin
wire m_start1 = cont1_key[15];                    // START
wire m_start2 = cont2_key[15];                    // START P2

wire m_up1    = cont1_key[0];
wire m_down1  = cont1_key[1];
wire m_left1  = cont1_key[2];
wire m_right1 = cont1_key[3];
wire m_fire1  = cont1_key[4] | cont1_key[5] | cont1_key[6] | cont1_key[7];

wire m_up2    = cont2_key[0];
wire m_down2  = cont2_key[1];
wire m_left2  = cont2_key[2];
wire m_right2 = cont2_key[3];
wire m_fire2  = cont2_key[4] | cont2_key[5] | cont2_key[6] | cont2_key[7];

// -- Berzerk game core (VHDL entity) -------------------------------------------
wire        vid_r, vid_g, vid_b, vid_hi;
wire        vid_hs, vid_vs, vid_hblank, vid_vblank;
wire [15:0] audio_raw;

berzerk berzerk_core (
    .clock_10      (clk_10),
    .clk_sys       (clk_sys),
    .reset         (game_reset),
    .pause         (1'b0),

    .video_r       (vid_r),
    .video_g       (vid_g),
    .video_b       (vid_b),
    .video_hi      (vid_hi),
    .video_clk     (),
    .video_csync   (),
    .video_hs      (vid_hs),
    .video_vs      (vid_vs),
    .video_hb      (vid_hblank),
    .video_vb      (vid_vblank),

    .audio_out     (audio_raw),

    .start2        (m_start2),
    .start1        (m_start1),
    .coin1         (m_coin),
    .cocktail      (1'b0),

    .right1        (m_right1),
    .left1         (m_left1),
    .down1         (m_down1),
    .up1           (m_up1),
    .fire1         (m_fire1),

    .right2        (m_right2),
    .left2         (m_left2),
    .down2         (m_down2),
    .up2           (m_up2),
    .fire2         (m_fire2),

    .dip_f2        (8'h00),
    .dip_f3        (8'h00),

    .dn_addr       (dn_addr),
    .dn_data       (dn_data),
    .dn_wr         (dn_wr && rom_loaded == 1'b0),  // accept writes only during load
    .dn_din        (),
    .dn_nvram      (1'b0),
    .dn_nvram_wr   (1'b0),

    .sw            (10'h0),
    .ledr          (),
    .dbg_cpu_addr  (),
    .dbg_cpu_addr_latch ()
);

// -- Video output -------------------------------------------------------------
// 1bpp RGB + intensity. Expand the way the MiSTer wrapper does in bright mode:
//   3-bit channel = { c, hi & c, c }, then replicate 3 -> 8 bits.
wire [2:0] cr = {vid_r, vid_hi & vid_r, vid_r};
wire [2:0] cg = {vid_g, vid_hi & vid_g, vid_g};
wire [2:0] cb = {vid_b, vid_hi & vid_b, vid_b};

wire [7:0] rgb_r = {cr, cr, cr[2:1]};   // 3 -> 8
wire [7:0] rgb_g = {cg, cg, cg[2:1]};
wire [7:0] rgb_b = {cb, cb, cb[2:1]};

// berzerk deasserts vblank MID-LINE at the frame top (vcnt flips mid-scanline
// in video_gen.vhd), so a raw de = ~(hblank|vblank) goes high partway through
// that transition line and leaks one stray line above the image. The Pocket
// renders the de window exactly (a CRT / MiSTer's HDMI hide it under overscan).
// Resample vblank once per line at the hblank boundary so it can only change
// between lines -> clean 224-line rectangle, no mid-line de glitch. de and the
// RGB blank share vbl_clean in this 40 MHz domain and are registered into
// clk_vid together so they stay aligned.
reg hbl_d_sys = 1'b0;
reg vbl_clean = 1'b1;
always @(posedge clk_sys) begin
    hbl_d_sys <= vid_hblank;
    if (vid_hblank & ~hbl_d_sys)   // hblank rising edge = clean line boundary
        vbl_clean <= vid_vblank;
end

wire        de_sys  = ~(vid_hblank | vbl_clean);
wire [23:0] rgb_sys = de_sys ? {rgb_r, rgb_g, rgb_b} : 24'h0;

reg [23:0] vid_rgb_r;
reg        vid_hs_r, vid_vs_r, vid_de_r;

always @(posedge clk_vid) begin
    vid_rgb_r <= rgb_sys;
    vid_de_r  <= de_sys;
    vid_hs_r  <= vid_hs;
    vid_vs_r  <= vid_vs;
end

assign video_rgb          = vid_rgb_r;
assign video_rgb_clock    = clk_vid;
assign video_rgb_clock_90 = clk_vid_90;
assign video_de           = vid_de_r;
assign video_skip         = 1'b0;
assign video_vs           = vid_vs_r;
assign video_hs           = vid_hs_r;

// -- Audio (16-bit unsigned, box-filter decimate to ~39 kHz I2S) --------------
// berzerk audio_out is 16-bit unsigned (MiSTer wrapper: AUDIO_S = 0).
// Same decimator structure as the other ports (40 MHz / 1024 = 39.0625 kHz).
reg  [9:0]  aud_div     = 10'd0;
reg  [25:0] aud_accum   = 26'd0;
reg  [15:0] audio_s     = 16'd0;

always @(posedge clk_sys) begin
    aud_div <= aud_div + 1'd1;
    if (aud_div == 10'd0) begin
        audio_s   <= aud_accum[25:10];
        aud_accum <= {10'd0, audio_raw};
    end else begin
        aud_accum <= aud_accum + {10'd0, audio_raw};
    end
end

sound_i2s #(
    .CHANNEL_WIDTH (16),
    .SIGNED_INPUT  (0)
) u_sound_i2s (
    .clk_74a    (clk_74a),
    .clk_audio  (clk_sys),
    .audio_l    (audio_s),
    .audio_r    (audio_s),
    .audio_mclk (audio_mclk),
    .audio_dac  (audio_dac),
    .audio_lrck (audio_lrck)
);

