// core_top.v - Berzerk (Stern, 1980) core for Analogue Pocket
// Instantiated by apf_top; uses the APF logical port interface.
//
// Dar/darfpga Berzerk core via MiSTer Arcade-Berzerk, berzerk.vhd instantiated
// intact. Single Z80 (T80se) + Votrax SC-01 speech synthesis (berzerk_speech)
// + ptm6840 sound fx. No tiles/sprites: a 256x224 1bpp video buffer + color map.
//
// ROM image (0x6000 bytes, loaded via APF data slot 1 at bridge_addr 0x0):
// 12 parts incl. load-bearing repeats (rom5.5c x4, rom0.1c x2) + speech voice
// ROMs; the berzerk entity demuxes dn_addr internally. See pack_rom.py.
//
// Video: native 15kHz, 5 MHz pixel (clk_sys/8), 256x224 horizontal. The entity
// generates its own hs/vs/hb/vb. RGB is 1bpp + an intensity bit (video_hi),
// expanded to 3bpp the same way the MiSTer wrapper does in "bright" mode.

`default_nettype none

module core_top (

// -- Physical connections ----------------------------------------------------

input  wire        clk_74a,
input  wire        clk_74b,

// Cartridge (unused)
inout  wire [7:0]  cart_tran_bank2,    output wire cart_tran_bank2_dir,
inout  wire [7:0]  cart_tran_bank3,    output wire cart_tran_bank3_dir,
inout  wire [7:0]  cart_tran_bank1,    output wire cart_tran_bank1_dir,
inout  wire [7:4]  cart_tran_bank0,    output wire cart_tran_bank0_dir,
inout  wire        cart_tran_pin30,    output wire cart_tran_pin30_dir,
output wire        cart_pin30_pwroff_reset,
inout  wire        cart_tran_pin31,    output wire cart_tran_pin31_dir,

// IR (unused)
input  wire        port_ir_rx,
output wire        port_ir_tx,
output wire        port_ir_rx_disable,

// Link port (unused)
inout  wire        port_tran_si,       output wire port_tran_si_dir,
inout  wire        port_tran_so,       output wire port_tran_so_dir,
inout  wire        port_tran_sck,      output wire port_tran_sck_dir,
inout  wire        port_tran_sd,       output wire port_tran_sd_dir,

// PSRAM (unused)
output wire [21:16] cram0_a,    inout  wire [15:0] cram0_dq,
input  wire          cram0_wait, output wire        cram0_clk,
output wire          cram0_adv_n, output wire       cram0_cre,
output wire          cram0_ce0_n, output wire       cram0_ce1_n,
output wire          cram0_oe_n,  output wire       cram0_we_n,
output wire          cram0_ub_n,  output wire       cram0_lb_n,

output wire [21:16] cram1_a,    inout  wire [15:0] cram1_dq,
input  wire          cram1_wait, output wire        cram1_clk,
output wire          cram1_adv_n, output wire       cram1_cre,
output wire          cram1_ce0_n, output wire       cram1_ce1_n,
output wire          cram1_oe_n,  output wire       cram1_we_n,
output wire          cram1_ub_n,  output wire       cram1_lb_n,

// SDRAM (unused)
output wire [12:0] dram_a,    output wire [1:0]  dram_ba,
inout  wire [15:0] dram_dq,   output wire [1:0]  dram_dqm,
output wire        dram_clk,  output wire        dram_cke,
output wire        dram_ras_n, output wire       dram_cas_n,
output wire        dram_we_n,

// SRAM (unused)
output wire [16:0] sram_a,    inout  wire [15:0] sram_dq,
output wire        sram_oe_n, output wire        sram_we_n,
output wire        sram_ub_n, output wire        sram_lb_n,

// Misc physical
input  wire        vblank,
output wire        vpll_feed,
output wire        dbg_tx,
input  wire        dbg_rx,
output wire        user1,
input  wire        user2,
inout  wire        aux_sda,
output wire        aux_scl,

// -- Logical connections (to/from apf_top) -----------------------------------

// Video (24-bit RGB + sync, synchronous to video_rgb_clock)
output wire [23:0] video_rgb,
output wire        video_rgb_clock,
output wire        video_rgb_clock_90,
output wire        video_de,
output wire        video_skip,
output wire        video_vs,
output wire        video_hs,

// Audio I2S
output wire        audio_mclk,
input  wire        audio_adc,
output wire        audio_dac,
output wire        audio_lrck,

// APF bridge bus (synchronous to clk_74a)
output wire        bridge_endian_little,
input  wire [31:0] bridge_addr,
input  wire        bridge_rd,
output reg  [31:0] bridge_rd_data,
input  wire        bridge_wr,
input  wire [31:0] bridge_wr_data,

// Controller inputs
input  wire [31:0] cont1_key,
input  wire [31:0] cont2_key,
input  wire [31:0] cont3_key,
input  wire [31:0] cont4_key,
input  wire [31:0] cont1_joy,
input  wire [31:0] cont2_joy,
input  wire [31:0] cont3_joy,
input  wire [31:0] cont4_joy,
input  wire [15:0] cont1_trig,
input  wire [15:0] cont2_trig,
input  wire [15:0] cont3_trig,
input  wire [15:0] cont4_trig

);

// -- Tie off unused physical ports -------------------------------------------
assign port_ir_tx              = 1'b0;
assign port_ir_rx_disable      = 1'b1;

assign cart_tran_bank3         = 8'hZZ;   assign cart_tran_bank3_dir     = 1'b0;
assign cart_tran_bank2         = 8'hZZ;   assign cart_tran_bank2_dir     = 1'b0;
assign cart_tran_bank1         = 8'hZZ;   assign cart_tran_bank1_dir     = 1'b0;
assign cart_tran_bank0         = 4'hF;    assign cart_tran_bank0_dir     = 1'b1;
assign cart_tran_pin30         = 1'b0;    assign cart_tran_pin30_dir     = 1'bZ;
assign cart_pin30_pwroff_reset = 1'b0;
assign cart_tran_pin31         = 1'bZ;    assign cart_tran_pin31_dir     = 1'b0;

assign port_tran_so            = 1'bZ;    assign port_tran_so_dir        = 1'b0;
assign port_tran_si            = 1'bZ;    assign port_tran_si_dir        = 1'b0;
assign port_tran_sck           = 1'bZ;    assign port_tran_sck_dir       = 1'b0;
assign port_tran_sd            = 1'bZ;    assign port_tran_sd_dir        = 1'b0;

assign cram0_a = 6'h0;  assign cram0_dq = 16'hZZZZ; assign cram0_clk = 1'b0;
assign cram0_adv_n = 1'b1; assign cram0_cre = 1'b0;
assign cram0_ce0_n = 1'b1; assign cram0_ce1_n = 1'b1;
assign cram0_oe_n = 1'b1; assign cram0_we_n = 1'b1;
assign cram0_ub_n = 1'b1; assign cram0_lb_n = 1'b1;

assign cram1_a = 6'h0;  assign cram1_dq = 16'hZZZZ; assign cram1_clk = 1'b0;
assign cram1_adv_n = 1'b1; assign cram1_cre = 1'b0;
assign cram1_ce0_n = 1'b1; assign cram1_ce1_n = 1'b1;
assign cram1_oe_n = 1'b1; assign cram1_we_n = 1'b1;
assign cram1_ub_n = 1'b1; assign cram1_lb_n = 1'b1;

assign dram_a = 13'h0; assign dram_ba = 2'h0; assign dram_dq = 16'hZZZZ;
assign dram_dqm = 2'h3; assign dram_clk = 1'b0; assign dram_cke = 1'b0;
assign dram_ras_n = 1'b1; assign dram_cas_n = 1'b1; assign dram_we_n = 1'b1;

assign sram_a = 17'h0; assign sram_dq = 16'hZZZZ;
assign sram_oe_n = 1'b1; assign sram_we_n = 1'b1;
assign sram_ub_n = 1'b1; assign sram_lb_n = 1'b1;

assign vpll_feed = 1'bZ;
assign dbg_tx    = 1'bZ;
assign user1     = 1'bZ;
assign aux_scl   = 1'bZ;

assign bridge_endian_little = 1'b0;  // big-endian

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

// -- APF bridge command handler ----------------------------------------------
wire        reset_n;
wire [31:0] cmd_bridge_rd_data;

wire        status_boot_done  = pll_locked_s;
wire        status_setup_done = rom_loaded_s;
wire        status_running    = 1'b1;

wire        dataslot_requestread;
wire [15:0] dataslot_requestread_id;
wire        dataslot_requestread_ack  = 1'b1;
wire        dataslot_requestread_ok   = 1'b1;

wire        dataslot_requestwrite;
wire [15:0] dataslot_requestwrite_id;
wire [31:0] dataslot_requestwrite_size;
wire        dataslot_requestwrite_ack = 1'b1;
wire        dataslot_requestwrite_ok  = 1'b1;

wire        dataslot_update;
wire [15:0] dataslot_update_id;
wire [31:0] dataslot_update_size;
wire        dataslot_allcomplete;

wire [31:0] rtc_epoch_seconds;
wire [31:0] rtc_date_bcd;
wire [31:0] rtc_time_bcd;
wire        rtc_valid;

wire        savestate_supported   = 1'b0;
wire [31:0] savestate_addr        = 32'h0;
wire [31:0] savestate_size        = 32'h0;
wire [31:0] savestate_maxloadsize = 32'h0;
wire        savestate_start;
wire        savestate_start_ack  = 1'b0;
wire        savestate_start_busy = 1'b0;
wire        savestate_start_ok   = 1'b0;
wire        savestate_start_err  = 1'b0;
wire        savestate_load;
wire        savestate_load_ack  = 1'b0;
wire        savestate_load_busy = 1'b0;
wire        savestate_load_ok   = 1'b0;
wire        savestate_load_err  = 1'b0;
wire        osnotify_inmenu;

reg         target_dataslot_read     = 1'b0;
reg         target_dataslot_write    = 1'b0;
reg         target_dataslot_getfile  = 1'b0;
reg         target_dataslot_openfile = 1'b0;
wire        target_dataslot_ack;
wire        target_dataslot_done;
wire [2:0]  target_dataslot_err;
reg  [15:0] target_dataslot_id         = 16'h0;
reg  [31:0] target_dataslot_slotoffset = 32'h0;
reg  [31:0] target_dataslot_bridgeaddr = 32'h0;
reg  [31:0] target_dataslot_length     = 32'h0;
wire [31:0] target_buffer_param_struct;
wire [31:0] target_buffer_resp_struct;

wire [9:0]  datatable_addr;
wire        datatable_wren;
wire [31:0] datatable_data;
wire [31:0] datatable_q;

core_bridge_cmd icb (
    .clk                       (clk_74a),
    .reset_n                   (reset_n),
    .bridge_endian_little      (bridge_endian_little),
    .bridge_addr               (bridge_addr),
    .bridge_rd                 (bridge_rd),
    .bridge_rd_data            (cmd_bridge_rd_data),
    .bridge_wr                 (bridge_wr),
    .bridge_wr_data            (bridge_wr_data),
    .status_boot_done          (status_boot_done),
    .status_setup_done         (status_setup_done),
    .status_running            (status_running),
    .dataslot_requestread      (dataslot_requestread),
    .dataslot_requestread_id   (dataslot_requestread_id),
    .dataslot_requestread_ack  (dataslot_requestread_ack),
    .dataslot_requestread_ok   (dataslot_requestread_ok),
    .dataslot_requestwrite     (dataslot_requestwrite),
    .dataslot_requestwrite_id  (dataslot_requestwrite_id),
    .dataslot_requestwrite_size(dataslot_requestwrite_size),
    .dataslot_requestwrite_ack (dataslot_requestwrite_ack),
    .dataslot_requestwrite_ok  (dataslot_requestwrite_ok),
    .dataslot_update           (dataslot_update),
    .dataslot_update_id        (dataslot_update_id),
    .dataslot_update_size      (dataslot_update_size),
    .dataslot_allcomplete      (dataslot_allcomplete),
    .rtc_epoch_seconds         (rtc_epoch_seconds),
    .rtc_date_bcd              (rtc_date_bcd),
    .rtc_time_bcd              (rtc_time_bcd),
    .rtc_valid                 (rtc_valid),
    .savestate_supported       (savestate_supported),
    .savestate_addr            (savestate_addr),
    .savestate_size            (savestate_size),
    .savestate_maxloadsize     (savestate_maxloadsize),
    .savestate_start           (savestate_start),
    .savestate_start_ack       (savestate_start_ack),
    .savestate_start_busy      (savestate_start_busy),
    .savestate_start_ok        (savestate_start_ok),
    .savestate_start_err       (savestate_start_err),
    .savestate_load            (savestate_load),
    .savestate_load_ack        (savestate_load_ack),
    .savestate_load_busy       (savestate_load_busy),
    .savestate_load_ok         (savestate_load_ok),
    .savestate_load_err        (savestate_load_err),
    .osnotify_inmenu           (osnotify_inmenu),
    .target_dataslot_read      (target_dataslot_read),
    .target_dataslot_write     (target_dataslot_write),
    .target_dataslot_getfile   (target_dataslot_getfile),
    .target_dataslot_openfile  (target_dataslot_openfile),
    .target_dataslot_ack       (target_dataslot_ack),
    .target_dataslot_done      (target_dataslot_done),
    .target_dataslot_err       (target_dataslot_err),
    .target_dataslot_id        (target_dataslot_id),
    .target_dataslot_slotoffset(target_dataslot_slotoffset),
    .target_dataslot_bridgeaddr(target_dataslot_bridgeaddr),
    .target_dataslot_length    (target_dataslot_length),
    .target_buffer_param_struct(target_buffer_param_struct),
    .target_buffer_resp_struct (target_buffer_resp_struct),
    .datatable_addr            (datatable_addr),
    .datatable_wren            (datatable_wren),
    .datatable_data            (datatable_data),
    .datatable_q               (datatable_q)
);

always @(*) begin
    casex (bridge_addr)
        32'hF8xxxxxx: bridge_rd_data = cmd_bridge_rd_data;
        default:      bridge_rd_data = 32'h0;
    endcase
end

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

endmodule
