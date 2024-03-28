//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

`include "rtl/config.v"

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign UART_RTS = UART_CTS;
assign UART_DTR = UART_DSR;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign LED_USER  = vsd_sel & sd_act;
assign LED_DISK  = {1'b1, ~vsd_sel & sd_act};
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[9:8];

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"MC1201;UART115200;",
	"-;",
	"S0,DSKIMG,Mount Drive;",
	"-;",
	"O89,Aspect Ratio,Original,Full Screen,[ARC1],[ARC2];",
	"-;",
	"O4,Timer,On,Off;",
	"O5,CPU slow,Off,On;",
	"O6,Console,Terminal,UART;",
	"OAB,Disk bank,0,1,2,3;",
	"R3,ODT;",
	"-;",
	"T7,Reset Terminal;",
	"R0,Reset;",
	"V,v",`BUILD_DATE 
};

wire forced_scandoubler;
wire  [1:0] buttons;
wire [31:0] status;
wire        ps2_clk;
wire        ps2_data;

wire [31:0] sd_lba_sd;
wire [31:0] sd_lba[1] = '{sd_lba_sd};
wire        sd_rd;
wire        sd_wr;
wire        sd_ack;
wire        sd_ack_conf;
wire  [8:0] sd_buff_addr;    // [7:0] for 16bit BUS WIDE, [8:0] for 8bit BUS WIDE
wire  [7:0] sd_buff_dout;   // [15:0] for 16bit BUS WIDE, [7:0] for 8bit BUS WIDE
wire  [7:0] sd_buff_din_sd; // [15:0] for 16bit BUS WIDE, [7:0] for 8bit BUS WIDE
wire  [7:0] sd_buff_din[1] = '{sd_buff_din_sd}; // [15:0] for 16bit BUS WIDE, [7:0] for 8bit BUS WIDE
wire        sd_buff_wr;

wire        img_mounted;
wire        img_readonly;
wire [63:0] img_size;

wire  [7:0] uart_mode;

hps_io #(.CONF_STR(CONF_STR), .PS2DIV(3200), .WIDE(0)) hps_io
(
	.clk_sys(clk_p),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(),

	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
	.status_menumask({status[5]}),

	.ps2_kbd_clk_out(ps2_clk),
	.ps2_kbd_data_out(ps2_data),
	
	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_din(sd_buff_din),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),
	
	.uart_mode(uart_mode)
	
);

reg vsd_sel = 0;
wire vsdmiso;
always @(posedge clk50) if(img_mounted) vsd_sel <= |img_size;

wire sdcard_miso = vsd_sel ? vsdmiso : SD_MISO;
assign SD_CS   = sdcard_cs | vsd_sel;
assign SD_SCK  = sdcard_sclk & ~vsd_sel;
assign SD_MOSI = sdcard_mosi & ~vsd_sel;

reg sd_act;

always @(posedge clk50) begin
	reg old_mosi, old_miso;
	integer timeout = 0;

	old_mosi <= sdcard_mosi;
	old_miso <= sdcard_miso;

	sd_act <= 0;
	if(timeout < 1000000) begin
		timeout <= timeout + 1;
		sd_act <= 1;
	end

	if((old_mosi ^ sdcard_mosi) || (old_miso ^ sdcard_miso)) timeout <= 0;
end

sd_card #(.WIDE(0)) sd_card
(
	.clk_sys(clk_p),
	.reset( buttons[1] | status[0]),

	.sdhc(1),
	.img_mounted(img_mounted),
   .img_size(img_size),

	.sd_lba(sd_lba_sd),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_din(sd_buff_din_sd),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_wr(sd_buff_wr),

	.clk_spi(clk_p),

	.sck(sdcard_sclk),
	.ss(sdcard_cs | ~vsd_sel),
	.mosi(sdcard_mosi),
	.miso(vsdmiso)
);

wire        clk50;
wire        clk_p;                 
wire        clk_n;                 
wire        clkrdy;         // PLL ready
wire        sdclock;        // тактирование SD-карты

wire        bt_terminal_rst;
wire        bt_timer;       // выключатель таймера
wire        bt_halt;        // пультовое прерывание
wire        reset_key;      // кнопка сброса
wire [1:0]  sw_diskbank;    // линии выбор дисковых банков
wire        sw_console;     // флаг выбора консольного порта, 0 - терминальный модуль, 1 - ИРПС 2
wire        sw_cpuslow;     // включение режима замедления процессора
wire        sdram_ready;         // флаг готовности динамической памяти.
assign      sdram_ready = 1;
wire        sdram_stb;
wire        sdram_ack;
wire [15:0] sdram_dat;

wire vgagreen, vgablue, vgared; // выбор яркости каждого цвета  - сигнал, подаваемый на видео-ЦАП для светящейся и темной точки.   
assign VGA_G = {8{vgagreen}};
assign VGA_B = {8{vgablue}};
assign VGA_R = {8{vgared}};

//***************************************************
//*    Кнопки
//***************************************************
assign      reset_key = ~(RESET | buttons[1] | status[0]);    // кнопка сброса
assign      bt_terminal_rst = ~reset_key;  // сброс терминального модуля - от кнопки и автоматически по готовности PLL
assign      bt_halt = status[3];           // кнопка "пульт"
assign      bt_timer = status[4];          // выключатель таймерного прерывания

//************************************************
//* Переключатели конфигурации
//************************************************
assign sw_diskbank = status[11:10]; // выбор дискового банка на SD-карте
assign sw_console = status[6];      // подключение консольного порта (0 - терминал, 1 - внешние линии UART)
assign sw_cpuslow = status[5];      // включение режима замедления процессора

//************************************************
//* тактовый генератор 
//************************************************
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_p),    // 100МГц прямая фаза, основная тактовая частота
	.outclk_1(clk_n),    // 100МГц инверсная фаза
//	.outclk_2(sdclock),  // 12.5 МГц тактовый сигнал SD-карты
	.outclk_3(clk50),    // 50МГц прямая фаза, основная тактовая частота
	.locked(clkrdy)	     // флаг готовности PLL	
);


reg [2:0] counter = 0;   // 12.5 МГц тактовый сигнал SD-карты
always @(posedge clk_p)  // Делитель частоты на ??? 8 для SD-Card
    counter <= counter + 1;

assign sdclock = counter[2]; // 12.5 МГц тактовый сигнал SD-карты

//**********************************
//* Модуль RAM
//**********************************
memory #(15) ram
(  .wb_clk_i(wb_clk),
   .wb_adr_i(wb_adr[15:1]),
   .wb_we_i(wb_we),
   .wb_dat_i(wb_out),
   .wb_dat_o(sdram_dat),
   .wb_cyc_i(sdram_stb),
   .wb_stb_i(sdram_stb),
   .wb_sel_i(wb_sel),
   .wb_ack_o(sdram_ack)
);

wire [2:0] vspeed;   // индекс скорости порта

wire        sys_init;         // общий сброс

// шина WISHBONE                                       
wire        wb_clk;                    
wire [15:0] wb_adr;                    
wire [15:0] wb_out;                    
wire [15:0] wb_mux;                    
wire        wb_cyc;                    
wire        wb_we;                     
wire [1:0]  wb_sel;                    
wire        wb_stb;                    
wire        global_ack;                    

// Основная шина процессора
wire        cpu_access_req;          // разрешение доступа к шине
wire [15:0] cpu_adr;                 // шина адреса
wire [15:0] cpu_data_out;            // выход шины данных
wire        cpu_cyc;                 // строб транзакции
wire        cpu_we;                  // направление передачи (1 - от процессора)
wire [1:0]  cpu_bsel;                // выбор байтов из слова
wire        cpu_stb;                 // строб обмена по шине
wire        cpu_ack;                 // подтверждение транзакции

// шина векторов прерываний                                       
wire        vm_una;                    // запрос безадресного чтения
wire        vm_istb;                   // Строб приема вектора прерывания 
wire        vm_iack;                   // подтверждение прерывания
wire [15:0] vm_ivec;                   // вектор прерывания

// сигналы выбора периферии
wire uart1_stb;
wire uart2_stb;
wire sysram_stb;
wire rom_stb;
wire rk11_stb;
wire rk611_stb;
wire lpt_stb;
wire dw_stb;
wire rx_stb;
wire my_stb;
wire kgd_stb;

// линии подтверждения обмена, исходяшие из устройства
wire uart1_ack;
wire uart2_ack;
wire rom_ack;
wire rk11_ack;
wire rk611_ack;
wire lpt_ack;
wire dw_ack;
wire rx_ack;
wire my_ack;
wire kgd_ack;

// линии подтверждения, входящие в DMA-контроллеры устройств
wire rk11_dma_ack;
wire rk611_dma_ack;
wire my_dma_ack;

//  Шины данных от периферии
wire [15:0] uart1_dat;
wire [15:0] uart2_dat;
wire [15:0] rom_dat;
wire [15:0] rk11_dat;
wire [15:0] rk611_dat;
wire [15:0] lpt_dat;
wire [15:0] dw_dat;
wire [15:0] rx_dat;
wire [15:0] my_dat;
wire [15:0] kgd_dat;


// линии процессорных сбросов и прерываний                                       
wire        vm_init_out;               // выход сброса от процессора к устройствам на шине
wire        vm_dclo_in;                // вход сброса
wire        vm_aclo_in;                // прерывание по аварии питания
wire        vm_virq;                   // запрос векторного прерывания

// линии прерывания внешних устройств                                       
wire        irpstx_irq, irpstx_iack;            
wire        irpsrx_irq, irpsrx_iack;            
wire        irpstx2_irq, irpstx2_iack;            
wire        irpsrx2_irq, irpsrx2_iack;            
wire        rk11_irq, rk11_iack;
wire        rk611_irq, rk611_iack;
wire        lpt_irq, lpt_iack;
wire        dw_irq, dw_iack;
wire        rx_irq, rx_iack;
wire        my_irq, my_iack;

wire        global_reset;   // кнопка сброса

// Линии обмена с SD-картой от разных контроллеров
wire         rk_mosi;       // mosi от RK11
wire         rk_cs;         // cs от RK11
wire         rk_sclk;       // sclk от RK11
wire         dm_mosi;       // mosi от RK611
wire         dm_cs;         // cs от RK611
wire         dm_sclk;       // sclk от RK611
wire         dw_mosi;       // mosi от DW
wire         dw_cs;         // cs от DW
wire         dw_sclk;
wire         dx_mosi;       // mosi от DW
wire         dx_cs;         // cs от DW
wire         dx_sclk;
wire         my_mosi;       // mosi от MY
wire         my_cs;         // cs от MY
wire         my_sclk;

// Сигналы диспетчера доступа к SD-карте
wire        rk_sdreq;       // запрос доступа
reg         rk_sdack;       // разрешение доступа
wire        dw_sdreq;
reg         dw_sdack; 
wire        dm_sdreq;
reg         dm_sdack; 
wire        dx_sdreq;
reg         dx_sdack; 
wire        my_sdreq;
reg         my_sdack; 

wire        timer_on;       // разрешение таймера

// линии невекторных прерываний 
assign      sys_init = vm_init_out;   // сброс

// пищалка
wire nbuzzer;
wire buzzer=~nbuzzer;

assign wb_clk=clk_p;

//************************************
//*            VGA
//************************************
// Линии текстового дисплея
wire vgared_t,vgagreen_t,vgablue_t;  // видеосигналы

// Линии графического дисплея
wire vgavideo_g;    // видеовыход 
wire genable;       // включение графического видеовыхода
wire tdisable;      // отключение текстового видеовыхода

// Селектор источника видео
// складываем видеопотоки от обоих видеоконтроллеров
assign vgagreen = (genable & vgavideo_g) | (~tdisable & vgagreen_t);
assign vgared   = (genable & vgavideo_g) | (~tdisable & vgared_t);
assign vgablue  = (genable & vgavideo_g) | (~tdisable & vgablue_t);

 
//********************************************
//* Светодиоды
//********************************************
//assign rk_led = ~rk_sdreq;   // запрос обмена диска RK
//assign dw_led = ~dw_sdreq;   // запрос обмена диска DW
//assign dm_led = ~dm_sdreq;   // запрос обмена диска DW
//assign my_led = ~my_sdreq    // запрос обмена диска MY
//assign dx_led = ~dx_sdreq;   // запрос обмена диска DX
//assign timer_led = ~timer_on;   // индикация включения таймера

//**************************************************************
//*   Модуль формирования сбросов
//**************************************************************

wbc_rst reset
(
   .osc_clk(clk50),             // основной клок 50 МГц
   .sys_clk(wb_clk),            // сигнал синхронизации  wishbone
   .pll_lock(clkrdy),           // сигнал готовности PLL
   .button(reset_key),          // кнопка сброса
   .sys_ready(sdram_ready),     // вход готовности системных компонентов (влияет на sys_rst)
   .sys_dclo(vm_dclo_in),   
   .sys_aclo(vm_aclo_in),
   .global_reset(global_reset)  // выход кнопки сброса 
);

//**********************************************************
//*       Процессорная плата
//**********************************************************
`BOARD cpu(
// Синхросигналы  
   .clk_p(clk_p),
   .clk_n(clk_n),
   .cpuslow(sw_cpuslow),              // Режим замедления процессора

// Шина Wishbone                                       
   .cpu_gnt_i(cpu_access_req),     // 1 - разрешение cpu работать с шиной
                                   // 0 - DMA с внешними устройствами, cpu отключен от шины и бесконечно ждет ответа  ack
   .cpu_adr_o(cpu_adr),            // выход шины адреса
   .cpu_dat_o(cpu_data_out),       // выход шины данных
   .cpu_dat_i(wb_mux),             // вход шины данных
   .cpu_cyc_o(cpu_cyc),            // Строб цила wishbone
   .cpu_we_o(cpu_we),              // разрешение записи
   .cpu_sel_o(cpu_bsel),           // выбор байтов для передачи
   .cpu_stb_o(cpu_stb),            // строб данных

   .sysram_stb(sysram_stb),        // строб обращения к системной памяти
   .global_ack(cpu_ack),           // подтверждение обмена от памяти и устройств страницы ввода-вывода
   
// Сбросы и прерывания
   .vm_init(vm_init_out),          // Выход сброса для периферии
   .dclo(vm_dclo_in),              // Вход сброса процессора
   .aclo(vm_aclo_in),              // Сигнал аварии питания
   .halt(bt_halt),                 // Прерывание входа в пультовоый режим
   .virq(vm_virq),                 // Векторное прерывание

// Шины обработки прерываний                                       
   .ivec(vm_ivec),                 // Шина приема вектора прерывания
   .istb(vm_istb),                 // Строб приема вектора прерывания
   .iack(vm_iack),                 // Подтверждение приема вектора прерывания
   
   .timer_button(bt_timer),    // кнопка включения-отключения таймера
   .timer_status(timer_on)         // линия индикатора состояния таймера
   
);

//**********************************
//* Пзу пользователя 140000-157777
//**********************************
`ifdef userrom
reg rom_ack0;
reg rom_ack1;

user_rom rom(
   .address(wb_adr[12:1]),
   .clock(wb_clk),
   .q(rom_dat)
);
// формирователь cигнала подверждения транзакции с задержкой на 1 такт
always @ (posedge wb_clk)  begin
   rom_ack0 <= wb_cyc & rom_stb & ~wb_we;
   rom_ack1 <= wb_cyc & rom_ack0 & ~wb_we;
end
assign rom_ack=rom_ack1;
`else
assign rom_ack=1'b0;
`endif

//**********************************
// Выбор консольного порта
//**********************************
wire  uart1_txd, uart1_rxd;   // линии ИРПС 1
wire  uart2_txd, uart2_rxd;   // линии ИРПС 2
wire  terminal_tx,terminal_rx;// линии аппаратного терминала

`ifdef KSM_module
assign UART_TXD = (sw_console == 0)? uart2_txd : uart1_txd;
assign terminal_rx = (sw_console == 0)? uart1_txd : uart2_txd;
assign uart1_rxd = (sw_console == 0)? terminal_tx : UART_RXD;
assign uart2_rxd = (sw_console == 0)? UART_RXD : terminal_tx;
`else
assign UART_TXD = uart1_txd;
assign uart1_rxd = UART_RXD;
`endif

//**********************************************
// Выбор скорости последовательных портов
//**********************************************
wire [31:0] uart1_speed;  // скорость ИРПС 1
wire [31:0] uart2_speed;  // скорость ИРПС 2
wire [31:0] baud2;        // делитель скорости второго порта ИРПС

// Согласование скорости с терминальным модулем
wire [31:0]   terminal_baud;    // делитель, соответствующий текущей скорости терминала                     
assign  terminal_baud = 
  (vspeed == 3'd0)   ? 32'd767: 32'D0 | // 1200
  (vspeed == 3'd1)   ? 32'd383: 32'D0 | // 2400
  (vspeed == 3'd2)   ? 32'd191: 32'D0 | // 4800
  (vspeed == 3'd3)   ? 32'd95: 32'D0 |  // 9600
  (vspeed == 3'd4)   ? 32'd47: 32'D0 |  // 19200
  (vspeed == 3'd5)   ? 32'd23: 32'D0 |  // 38400
  (vspeed == 3'd6)   ? 32'd15: 32'D0 |  // 57600
  (vspeed == 3'd6)   ? 32'd7:  32'D0 ;  // 115200
                       
// Выбор скорости второго UART                        
// assign  baud2 = 921600/`UART2SPEED-1;
assign baud2 = 
  (`UART2SPEED == 3'd0)   ? 32'd767: // 1200
  (`UART2SPEED == 3'd1)   ? 32'd383: // 2400
  (`UART2SPEED == 3'd2)   ? 32'd191: // 4800
  (`UART2SPEED == 3'd3)   ? 32'd95:  // 9600
  (`UART2SPEED == 3'd4)   ? 32'd47:  // 19200
  (`UART2SPEED == 3'd5)   ? 32'd23:  // 38400
  (`UART2SPEED == 3'd6)   ? 32'd15:  // 57600
                            32'd7;   // 115200

// Селектор делителей скорости обоих портов в зависимости от того, кто из них подключен к терминалу
`ifdef KSM_module
assign uart1_speed = (sw_console == 0)? terminal_baud : baud2;
assign uart2_speed = (sw_console == 0)? baud2 : terminal_baud;
`else
assign uart1_speed = baud2;
assign uart2_speed = baud2;
`endif

//**********************************
//*     ирпс1 (консоль)
//**********************************
wbc_uart #(.REFCLK(`clkref)) uart1
(
   .wb_clk_i(wb_clk),
   .wb_rst_i(sys_init),
   .wb_adr_i(wb_adr[2:0]),
   .wb_dat_i(wb_out),
   .wb_dat_o(uart1_dat),
   .wb_cyc_i(wb_cyc),
   .wb_we_i(wb_we),
   .wb_stb_i(uart1_stb),
   .wb_ack_o(uart1_ack),

   .txd(uart1_txd),
   .rxd(uart1_rxd),

   .tx_cts_i(1'b0),
   .tx_irq_o(irpstx_irq),
   .tx_iack_i(irpstx_iack),
   .rx_irq_o(irpsrx_irq),
   .rx_iack_i(irpsrx_iack),

   .cfg_bdiv(uart1_speed),
   .cfg_nbit(2'b11),
   .cfg_nstp(1'b1),
   .cfg_pena(1'b0),
   .cfg_podd(1'b0)
);

//**********************************
//*     ирпс2
//**********************************
`ifdef IRPS2_module
wbc_uart #(.REFCLK(`clkref)) uart2
(
   .wb_clk_i(wb_clk),
   .wb_rst_i(sys_init),
   .wb_adr_i(wb_adr[2:0]),
   .wb_dat_i(wb_out),
   .wb_dat_o(uart2_dat),
   .wb_cyc_i(wb_cyc),
   .wb_we_i(wb_we),
   .wb_stb_i(uart2_stb),
   .wb_ack_o(uart2_ack),

   .tx_cts_i(1'b0),
   .txd(uart2_txd),
   .rxd(uart2_rxd),

   .tx_irq_o(irpstx2_irq),
   .tx_iack_i(irpstx2_iack),
   .rx_irq_o(irpsrx2_irq),
   .rx_iack_i(irpsrx2_iack),

   .cfg_bdiv(uart2_speed),
   .cfg_nbit(2'b11),
   .cfg_nstp(1'b1),
   .cfg_pena(1'b0),
   .cfg_podd(1'b0)
);
`else 
assign uart2_dat='1;
assign uart2_txd=1'b1;
assign uart2_ack=0;
assign irpstx2_irq=1'b0;
assign irpsrx2_irq=1'b0;
`endif

//**********************************
//*   Текстовый терминал КСМ
//**********************************
wire [10:0] col;  // колонка X, 0-1055
wire [9:0]  row;  // строка Y, 0-627

`ifdef KSM_module

ksm terminal(
   // VGA
   .vgahs(vgah), 
   .vgavs(vgav), 
   .vgared(vgared_t),
   .vgagreen(vgagreen_t),
   .vgablue(vgablue_t),
   // Последовательный порт
   .tx(terminal_tx), 
   .rx(terminal_rx), 
   // Клавиатура
   .ps2_clk(ps2_clk), 
   .ps2_data(ps2_data), 
   
   .buzzer(nbuzzer),            // пищалка
   
   .vspeed(vspeed),             // текущая скорость порта
   .initspeed(`TERMINAL_SPEED), // начальная скорость порта
   
   .col(col),
   .row(row),
   
   .clk50(clk50), 
   .reset(bt_terminal_rst),         // сброс видеоподсистемы
	
   .hblank(HBlank),
   .vblank(VBlank)

//	.ce_pix(ce_pix),
//	.vgaclk(CLK_VIDEO)
);
`else
assign nbuzzer=1'b0;
assign vgah=1'b0;
assign vgav=1'b0;
assign vgared_t=1'b0;
assign vgagreen_t=1'b0;
assign vgablue_t=1'b0;
`endif

//**********************************
//*  Графическая подсистема КГД
//**********************************
`ifdef KGD_module
kgd graphics(
   .wb_clk_i(wb_clk),
   .wb_rst_i(sys_init),
   .wb_adr_i(wb_adr[2:0]),
   .wb_dat_i(wb_out),
   .wb_dat_o(kgd_dat),
   .wb_cyc_i(wb_cyc),
   .wb_we_i(wb_we),
   .wb_stb_i(kgd_stb),
   .wb_sel_i(wb_sel), 
   .wb_ack_o(kgd_ack),
   
   .clk50 (clk50),
   
   .vreset(bt_terminal_rst),  // сброс графической подсистемы
   .vgavideo(vgavideo_g),  // видеовыход 
   .col(col),              // счетчик видеостолбцов
   .row(row),              // счетчик видеострок
   .tdisable(tdisable),    // отключение тектового экрана
   .genable(genable)       // подключение графического экрана
);
`else 
assign kgd_ack=1'b0;
assign tdisable=1'b0;
assign genable=1'b0;
assign vgavideo_g=1'b0;
`endif

//**********************************
//*  ИРПР
//**********************************
`ifdef IRPR_module
irpr printer (
   .wb_clk_i(wb_clk),
   .wb_rst_i(sys_init),
   .wb_adr_i(wb_adr[1:0]),
   .wb_dat_i(wb_out),
   .wb_dat_o(lpt_dat),
   .wb_cyc_i(wb_cyc),
   .wb_we_i(wb_we),
   .wb_stb_i(lpt_stb),
   .wb_ack_o(lpt_ack),
   .irq(lpt_irq),
   .iack(lpt_iack),
   // интерфейс к принтеру
   .lp_data(lp_data),     // данные для передачи к принтеру
   .lp_stb_n(lp_stb_n),   // строб записи в принтер
   .lp_init_n(lp_init_n), // строб сброса
   .lp_busy(lp_busy),     // сигнал занятости принтера
   .lp_err_n(lp_err_n)    // сигнал ошибки
);
`else 
assign lpt_ack=1'b0;
assign lpt_irq=1'b0;
`endif



//****************************************************
//*  Дисковый контроллер RK11D
//****************************************************

// Сигналы запроса-подтверждения DMA
wire rk11_dma_req;
wire rk11_dma_gnt;

// выходная шина DMA
wire [15:0] rk11_adr;                     
wire        rk11_dma_stb;
wire        rk11_dma_we;
wire [15:0] rk11_dma_out;

wire [3:0]  rksddebug;

`ifdef RK_module

rk11 rkdisk (

// шина wishbone
   .wb_clk_i(wb_clk),      // тактовая частота шины
   .wb_rst_i(sys_init),    // сброс
   .wb_adr_i(wb_adr[3:0]), // адрес 
   .wb_dat_i(wb_out),      // входные данные
   .wb_dat_o(rk11_dat),    // выходные данные
   .wb_cyc_i(wb_cyc),      // начало цикла шины
   .wb_we_i(wb_we),        // разрешение записи (0 - чтение)
   .wb_stb_i(rk11_stb),    // строб цикла шины
   .wb_sel_i(wb_sel),      // выбор конкретных байтов для записи - старший, младший или оба
   .wb_ack_o(rk11_ack),    // подтверждение выбора устройства

// обработка прерывания   
   .irq(rk11_irq),         // запрос
   .iack(rk11_iack),       // подтверждение
   
// DMA
   .dma_req(rk11_dma_req), // запрос DMA
   .dma_gnt(rk11_dma_gnt), // подтверждение DMA
   .dma_adr_o(rk11_adr),   // выходной адрес при DMA-обмене
   .dma_dat_i(wb_mux),     // входная шина данных DMA
   .dma_dat_o(rk11_dma_out), // выходная шина данных DMA
   .dma_stb_o(rk11_dma_stb), // строб цикла шины DMA
   .dma_we_o(rk11_dma_we),   // направление передачи DMA (0 - память->диск, 1 - диск->память) 
   .dma_ack_i(rk11_dma_ack), // Ответ от устройства, с которым идет DMA-обмен
   
// интерфейс SD-карты
   .sdcard_cs(rk_cs), 
   .sdcard_mosi(rk_mosi), 
   .sdcard_miso(sdcard_miso), 
   .sdcard_sclk(rk_sclk),

   .sdclock(sdclock),
   .sdreq(rk_sdreq),
   .sdack(rk_sdack),
   .sdmode(`RK_sdmode),           // режим ведущего-ведомого
   
// Адрес массива дисков на карте
   .start_offset({1'b0,sw_diskbank,18'h0}),

// отладочные сигналы
   .sdcard_debug(rksddebug)
   ); 

`else 
assign rk11_ack=1'b0;
assign rk11_dma_req=1'b0;
assign rk_sdreq = 1'b0;
assign rk11_irq=1'b0;
`endif

  
//****************************************************
//*  Дисковый контроллер RK611
//****************************************************

// Сигналы запроса-подтверждения DMA
wire rk611_dma_req;
wire rk611_dma_gnt;

// выходная шина DMA
wire [17:0] rk611_adr;                     
wire        rk611_dma_stb;
wire        rk611_dma_we;
wire [15:0] rk611_dma_out;

`ifdef DM_module

rk611 dmdisk (

// шина wishbone
   .wb_clk_i(wb_clk),      // тактовая частота шины
   .wb_rst_i(sys_init),    // сброс
   .wb_adr_i(wb_adr[4:0]), // адрес 
   .wb_dat_i(wb_out),      // входные данные
   .wb_dat_o(rk611_dat),    // выходные данные
   .wb_cyc_i(wb_cyc),      // начало цикла шины
   .wb_we_i(wb_we),        // разрешение записи (0 - чтение)
   .wb_stb_i(rk611_stb),    // строб цикла шины
   .wb_sel_i(wb_sel),      // выбор конкретных байтов для записи - старший, младший или оба
   .wb_ack_o(rk611_ack),    // подтверждение выбора устройства

// обработка прерывания   
   .irq(rk611_irq),         // запрос
   .iack(rk611_iack),       // подтверждение
   
// DMA
   .dma_req(rk611_dma_req), // запрос DMA
   .dma_gnt(rk611_dma_gnt), // подтверждение DMA
   .dma_adr_o(rk611_adr),   // выходной адрес при DMA-обмене
   .dma_dat_i(wb_mux),     // входная шина данных DMA
   .dma_dat_o(rk611_dma_out), // выходная шина данных DMA
   .dma_stb_o(rk611_dma_stb), // строб цикла шины DMA
   .dma_we_o(rk611_dma_we),   // направление передачи DMA (0 - память->диск, 1 - диск->память) 
   .dma_ack_i(rk611_dma_ack), // Ответ от устройства, с которым идет DMA-обмен
   
// интерфейс SD-карты
   .sdcard_cs(dm_cs), 
   .sdcard_mosi(dm_mosi), 
   .sdcard_miso(sdcard_miso), 
   .sdcard_sclk(dm_sclk),

   .sdclock(sdclock),
   .sdreq(dm_sdreq),
   .sdack(dm_sdack),
   .sdmode(`DM_sdmode),           // режим ведущего-ведомого
   
// Адрес массива дисков на карте
//   .start_offset({1'b0,sw_diskbank,18'h0}),
   .start_offset({1'b0, sw_diskbank,22'h330000})

   ); 

`else 
assign rk611_ack=1'b0;
assign rk611_dma_req=1'b0;
assign dm_sdreq = 1'b0;
assign rk611_irq=1'b0;
`endif

  
//**********************************
//*   Дисковый контроллер DW
//**********************************
wire [3:0] dwsddebug;

`ifdef DW_module

dw hdd(
// шина wishbone
   .wb_clk_i(wb_clk),   // тактовая частота шины
   .wb_rst_i(sys_init),   // сброс
   .wb_adr_i(wb_adr[4:0]),   // адрес 
   .wb_dat_i(wb_out),   // входные данные
   .wb_dat_o(dw_dat),   // выходные данные
   .wb_cyc_i(wb_cyc),   // начало цикла шины
   .wb_we_i(wb_we),     // разрешение записи (0 - чтение)
   .wb_stb_i(dw_stb),   // строб цикла шины
   .wb_sel_i(wb_sel),   // выбор конкретных байтов для записи - старший, младший или оба
   .wb_ack_o(dw_ack),   // подтверждение выбора устройства

// обработка прерывания   
   .irq(dw_irq),        // запрос
   .iack(dw_iack),      // подтверждение
   
   
// интерфейс SD-карты
   .sdcard_cs(dw_cs), 
   .sdcard_mosi(dw_mosi), 
   .sdcard_miso(sdcard_miso), 
   .sdcard_sclk(dw_sclk),
   
   .sdclock(sdclock),
   .sdreq(dw_sdreq),
   .sdack(dw_sdack),
   .sdmode(`DW_sdmode),          

// Адрес массива дисков на карте
   .start_offset({1'b0,sw_diskbank,18'hc000}),
   
// отладочные сигналы
   .sdcard_debug(dwsddebug)
   ); 

`else 
assign dw_ack=1'b0;
assign dw_sdreq = 1'b0;
assign dw_irq=1'b0;
`endif


//**********************************
//*   Дисковый контроллер RX01
//**********************************
wire [3:0] rxsddebug;

`ifdef DX_module

rx01 dxdisk (
// шина wishbone
   .wb_clk_i(wb_clk),      // тактовая частота шины
   .wb_rst_i(sys_init),    // сброс
   .wb_adr_i(wb_adr[1:0]), // адрес 
   .wb_dat_i(wb_out),      // входные данные
   .wb_dat_o(rx_dat),      // выходные данные
   .wb_cyc_i(wb_cyc),      // начало цикла шины
   .wb_we_i(wb_we),        // разрешение записи (0 - чтение)
   .wb_stb_i(rx_stb),      // строб цикла шины
   .wb_sel_i(wb_sel),      // выбор конкретных байтов для записи - старший, младший или оба
   .wb_ack_o(rx_ack),      // подтверждение выбора устройства

// обработка прерывания   
   .irq(rx_irq),           // запрос
   .iack(rx_iack),         // подтверждение
   
   
// интерфейс SD-карты
   .sdcard_cs(dx_cs), 
   .sdcard_mosi(dx_mosi), 
   .sdcard_miso(sdcard_miso), 
   .sdcard_sclk(dx_sclk),

   .sdmode(`DX_sdmode),          
   .sdreq(dx_sdreq),
   .sdack(dx_sdack),
   .sdclock(sdclock),
   
// Адрес массива дисков на карте
   .start_offset({1'b0,sw_diskbank,18'h2c000}),
   
// отладочные сигналы
   .sdcard_debug(rxsddebug)
   ); 

`else 
assign rx_ack=1'b0;
assign dx_sdreq = 1'b0;
assign rx_irq=1'b0;
`endif
   
//****************************************************
//*  Дисковый контроллер MY
//****************************************************

// Сигналы запроса-подтверждения DMA
wire my_dma_req;
wire my_dma_gnt;

// выходная шина DMA
wire [15:0]  my_adr;                     
wire         my_dma_stb;
wire         my_dma_we;
wire [15:0]  my_dma_out;

wire [3:0]   mysddebug;


`ifdef MY_module

fdd_my mydisk (

// шина wishbone
   .wb_clk_i(wb_clk),       // тактовая частота шины
   .wb_rst_i(sys_init),     // сброс
   .wb_adr_i(wb_adr[3:0]),  // адрес 
   .wb_dat_i(wb_out),       // входные данные
   .wb_dat_o(my_dat),       // выходные данные
   .wb_cyc_i(wb_cyc),       // начало цикла шины
   .wb_we_i(wb_we),         // разрешение записи (0 - чтение)
   .wb_stb_i(my_stb),       // строб цикла шины
   .wb_sel_i(wb_sel),       // выбор конкретных байтов для записи - старший, младший или оба
   .wb_ack_o(my_ack),       // подтверждение выбора устройства

// обработка прерывания   
   .irq(my_irq),            // запрос
   .iack(my_iack),          // подтверждение
   
// DMA
   .dma_req(my_dma_req),    // запрос DMA
   .dma_gnt(my_dma_gnt),    // подтверждение DMA
   .dma_adr_o(my_adr),      // выходной адрес при DMA-обмене
   .dma_dat_i(wb_mux),      // входная шина данных DMA
   .dma_dat_o(my_dma_out),  // выходная шина данных DMA
   .dma_stb_o(my_dma_stb),  // строб цикла шины DMA
   .dma_we_o(my_dma_we),    // направление передачи DMA (0 - память->диск, 1 - диск->память) 
   .dma_ack_i(my_dma_ack),  // Ответ от устройства, с которым идет DMA-обмен
   
// интерфейс SD-карты
   .sdcard_cs(my_cs), 
   .sdcard_mosi(my_mosi), 
   .sdcard_miso(sdcard_miso), 
   .sdcard_sclk(my_sclk),

   .sdclock(sdclock),
   .sdreq(my_sdreq),
   .sdack(my_sdack),
   .sdmode(`MY_sdmode),          
   
// Адрес массива дисков на карте
   .start_offset({1'b0,sw_diskbank,18'h2e000}),

// отладочные сигналы
   .sdcard_debug(mysddebug)
   ); 

`else 
assign my_ack=1'b0;
assign my_dma_req=1'b0;
assign my_sdreq = 1'b0;
assign my_irq=1'b0;
`endif

//**********************************
//*  Диспетчер доступа к SD-карте
//**********************************
//always @(posedge wb_clk) 
reg [1:0] my_sdreq_filter;
reg [1:0] rk_sdreq_filter;
reg [1:0] dw_sdreq_filter;
reg [1:0] dm_sdreq_filter;
reg [1:0] dx_sdreq_filter;

// фильтрация сигналов запроса
always @(posedge sdclock) begin
  my_sdreq_filter[0]=my_sdreq;
  my_sdreq_filter[1]=my_sdreq_filter[0];
  
  dx_sdreq_filter[0]=dx_sdreq;
  dx_sdreq_filter[1]=dx_sdreq_filter[0];
  
  dw_sdreq_filter[0]=dw_sdreq;
  dw_sdreq_filter[1]=dw_sdreq_filter[0];
  
  dm_sdreq_filter[0]=dm_sdreq;
  dm_sdreq_filter[1]=dm_sdreq_filter[0];
  
  rk_sdreq_filter[0]=rk_sdreq;
  rk_sdreq_filter[1]=rk_sdreq_filter[0];
end  
  
always @(posedge sdclock) begin
   // сброс
   if (sys_init == 1'b1) begin
      rk_sdack <= 1'b0;
      dw_sdack <= 1'b0;
      dm_sdack <= 1'b0;
      dx_sdack <= 1'b0;
      my_sdack <= 1'b0;
   end   
   else
   // поиск контроллера, желающего доступ к карте
    if ((rk_sdack == 1'b0) && (dm_sdack == 1'b0) && (dw_sdack == 1'b0) && (dx_sdack == 1'b0) && (my_sdack == 1'b0)) begin 
       // неактивное состояние - ищем источник запроса 
       if (rk_sdreq == 1'b1) rk_sdack <=1'b1;
       else if (dw_sdreq_filter[1] == 1'b1) dw_sdack <=1'b1;
       else if (dm_sdreq_filter[1] == 1'b1) dm_sdack <=1'b1;
       else if (dx_sdreq_filter[1] == 1'b1) dx_sdack <=1'b1;
       else if (my_sdreq_filter[1] == 1'b1) my_sdack <=1'b1;
    end    
    else 
    // активное состояние - ждем освобождения карты
       if ((rk_sdack == 1'b1) && rk_sdreq_filter[1] == 1'b0) rk_sdack <= 1'b0;
       else if ((dw_sdack == 1'b1) && (dw_sdreq_filter[1] == 1'b0)) dw_sdack <= 1'b0;
       else if ((dm_sdack == 1'b1) && (dm_sdreq_filter[1] == 1'b0)) dm_sdack <= 1'b0;
       else if ((dx_sdack == 1'b1) && (dx_sdreq_filter[1] == 1'b0)) dx_sdack <= 1'b0;
       else if ((my_sdack == 1'b1) && (my_sdreq_filter[1] == 1'b0)) my_sdack <= 1'b0;
end
   
//**********************************
//* Мультиплексор линий SD-карты
//**********************************
wire sdcard_mosi =
         dw_sdack? dw_mosi: // DW
         dm_sdack? dm_mosi: // DM
         dx_sdack? dx_mosi: // DX
         my_sdack? my_mosi: // MY
         rk_sdack? rk_mosi: // RK
                   `def_mosi; // по умолчанию - контроллер с ведущим SDSPI

wire sdcard_cs =
         dw_sdack? dw_cs:   // DW
         dm_sdack? dm_cs:   // DM
         dx_sdack? dx_cs:   // DX
         my_sdack? my_cs:   // MY
         rk_sdack? rk_cs:   // RK
                   `def_cs;   // по умолчанию - контроллер с ведущим SDSPI
                   
wire sdcard_sclk = 						 
         dw_sdack? dw_sclk:   // DW
         dm_sdack? dm_sclk:   // DM
         dx_sdack? dx_sclk:   // DX
         my_sdack? my_sclk:   // MY
         rk_sdack? rk_sclk:   // RK
                   `def_sclk;   // по умолчанию - контроллер с ведущим SDSPI
            
//**********************************
//*  Контроллер прерываний
//**********************************
wbc_vic #(.N(10)) vic
(
   .wb_clk_i(wb_clk),
   .wb_rst_i(vm_dclo_in),
   .wb_irq_o(vm_virq),
   .wb_dat_o(vm_ivec),
   .wb_stb_i(vm_istb),
   .wb_ack_o(vm_iack),
//         UART1-Tx     UART1-Rx   UART2-Tx    UART2-Rx     RK-11D        IRPR           DW         RX-11         MY         DM
   .ivec({16'o000064, 16'o000060, 16'o000334,  16'o000330, 16'o000220,  16'o000330, 16'o000300, 16'o000264, 16'o000170, 16'o000210 }),   // векторы
   .ireq({irpstx_irq, irpsrx_irq, irpstx2_irq, irpsrx2_irq, rk11_irq,     lpt_irq,    dw_irq,     rx_irq,      my_irq,  rk611_irq  }),   // запрос прерывания
   .iack({irpstx_iack,irpsrx_iack,irpstx2_iack,irpsrx2_iack,rk11_iack,    lpt_iack,   dw_iack,    rx_iack,     my_iack, rk611_iack })    // подтверждение прерывания
);

//*****************************************************************************
//* Диспетчер доступа к общей шине по запросу от разных мастеров (арбитр DMA)
//*****************************************************************************
reg rk11_dma_state;
reg my_dma_state;
reg rk611_dma_state;
// линии подтверждения разрешения доступа к шине
assign rk11_dma_gnt = rk11_dma_state;
assign rk611_dma_gnt = rk611_dma_state;
assign my_dma_gnt = my_dma_state;
assign cpu_access_req = ~ (rk11_dma_state | rk611_dma_state | my_dma_state);

always @(posedge wb_clk) 
   if (sys_init == 1'b1) begin
      rk11_dma_state <= 1'b0;
      rk611_dma_state <= 1'b0;
      my_dma_state <= 1'b0;
   end   
  // переключение источника - только в отсутствии активного цикла шины
   else if (wb_cyc == 1'b0) begin
     if (rk11_dma_req == 1'b1)  rk11_dma_state <= 1'b1;  // запрос от RK11
     else if (my_dma_req == 1'b1)  my_dma_state <= 1'b1; // запрос от MY
     else if (rk611_dma_req == 1'b1)  rk611_dma_state <= 1'b1; // запрос от DM
     else begin
        // нет активных DMA-запросов - шина подключается к процессору
        rk11_dma_state <= 1'b0;       
        rk611_dma_state <= 1'b0;       
        my_dma_state <= 1'b0;       
     end
  end

 
//*******************************************************************
//*  Коммутатор источника управления (мастера) шины wishbone
//*******************************************************************
assign wb_adr =   (rk11_dma_state) ? rk11_adr : 16'o0
                | (rk611_dma_state) ? rk611_adr[15:0] : 16'o0
                | (my_dma_state)   ? my_adr   : 16'o0
                | (cpu_access_req) ? cpu_adr  : 16'o0;
                                           
assign wb_out =   (rk11_dma_state) ? rk11_dma_out: 16'o0
                | (rk611_dma_state) ? rk611_dma_out: 16'o0 
                | (my_dma_state)   ? my_dma_out  : 16'o0
                | (cpu_access_req) ? cpu_data_out: 16'o0;
                                           
assign wb_cyc = (rk11_dma_state == 1'b1) ? rk11_dma_req:
                (rk611_dma_state == 1'b1) ? rk611_dma_req:
                (my_dma_state == 1'b1)   ? my_dma_req:
                                           cpu_cyc;
                                           
assign wb_we =  (rk11_dma_state == 1'b1) ? rk11_dma_we:
                (rk611_dma_state == 1'b1) ? rk611_dma_we:
                (my_dma_state == 1'b1)   ? my_dma_we:
                                           cpu_we;
                                           
assign wb_sel =   (rk11_dma_state|rk611_dma_state|my_dma_state) ? 2'b11: cpu_bsel;
                                          
assign wb_stb = (rk11_dma_state == 1'b1) ? rk11_dma_stb:
                (rk611_dma_state == 1'b1) ? rk611_dma_stb:
                (my_dma_state == 1'b1)   ? my_dma_stb:
                                           cpu_stb;
                                           
assign cpu_ack = ((
                  rk11_dma_state | 
                  rk611_dma_state | 
                  my_dma_state) == 1'b0) ? global_ack: 1'b0;
                  
assign rk11_dma_ack = (rk11_dma_state == 1'b1) ? global_ack: 1'b0;
assign rk611_dma_ack = (rk611_dma_state == 1'b1) ? global_ack: 1'b0;
assign my_dma_ack = (my_dma_state == 1'b1) ? global_ack: 1'b0;
  
//*******************************************************************
//*  Сигналы управления шины wishbone
//******************************************************************* 

// Страница ввода-выводв
assign uart1_stb  = wb_stb & wb_cyc & (wb_adr[15:3] == (16'o177560 >> 3));   // ИРПС консольный (TT) - 177560-177566 
assign uart2_stb  = wb_stb & wb_cyc & (wb_adr[15:3] == (16'o176500 >> 3));   // ИРПС дополнительный - 176500-177506
assign lpt_stb    = wb_stb & wb_cyc & (wb_adr[15:2] == (16'o177514 >> 2));   // ИРПР (LP) - 177514-177516
assign rk11_stb   = wb_stb & wb_cyc & (wb_adr[15:4] == (16'o177400 >> 4));   // RK - 177400-177416
assign rk611_stb  = wb_stb & wb_cyc & (wb_adr[15:5] == (16'o177440 >> 5));   // DM - 177440-177476
assign dw_stb     = wb_stb & wb_cyc & (wb_adr[15:5] == (16'o174000 >> 5));   // DW - 174000-174026
assign rx_stb     = wb_stb & wb_cyc & (wb_adr[15:2] == (16'o177170 >> 2));   // DX - 177170-177172
assign my_stb     = wb_stb & wb_cyc & (wb_adr[15:2] == (16'o172140 >> 2));   // MY - 172140-172142 
assign kgd_stb    = wb_stb & wb_cyc & (wb_adr[15:3] == (16'o176640 >> 3));   // КГД - 176640-176646

// ПЗУ пользователя
`ifdef userrom
assign rom_stb = wb_stb & wb_cyc & (wb_adr[15:13] == 3'b110);
`else
assign rom_stb=1'b0;
`endif

// Размещение основной памяти : 
// + если требуется, добавляется служебная область памяти по сигналу sysram_stb процессорной платы
`ifdef userrom
// вариант при наличии ПЗУ пользователя - RAM находится в пространстве 000000 - 137777 
assign sdram_stb =  (wb_stb & wb_cyc & (wb_adr[15:14] != 2'b11)) | sysram_stb;
`else
// вариант без ПЗУ - RAM находится в пространстве 000000 - 157777 
assign sdram_stb =  (wb_stb & wb_cyc & (wb_adr[15:13] != 3'b111)) | sysram_stb;
`endif

// Сигналы подтверждения - собираются через OR со всех устройств
assign global_ack  = sdram_ack | rom_ack | uart1_ack | uart2_ack | rk11_ack | rk611_ack | lpt_ack | dw_ack | rx_ack | my_ack | kgd_ack;

// Мультиплексор выходных шин данных всех устройств
assign wb_mux = 
       (sdram_stb ? sdram_dat : 16'o000000)
     | (rom_stb   ? rom_dat   : 16'o000000)
     | (uart1_stb ? uart1_dat : 16'o000000)
     | (uart2_stb ? uart2_dat : 16'o000000)
     | (rk11_stb  ? rk11_dat  : 16'o000000)
     | (rk611_stb ? rk611_dat : 16'o000000)
     | (lpt_stb   ? lpt_dat   : 16'o000000)
     | (dw_stb    ? dw_dat    : 16'o000000)
     | (rx_stb    ? rx_dat    : 16'o000000)
     | (my_stb    ? my_dat    : 16'o000000)
     | (kgd_stb   ? kgd_dat   : 16'o000000)
;

////////////-----------------------------------------------
///---------------------------------------------------------
wire HBlank;
wire vgah;
wire VBlank;
wire vgav;


assign CLK_VIDEO = clk50;
assign CE_PIXEL  = 1;

assign VGA_DE = ~(HBlank | VBlank);
assign VGA_HS = ~vgah;
assign VGA_VS = ~vgav;
assign VGA_SL    = 0;
assign VGA_F1    = 0;
assign VGA_SCALER= 0;

assign AUDIO_S   = 0;
assign AUDIO_L   = {15{buzzer}};
assign AUDIO_R   = {15{buzzer}};
assign AUDIO_MIX = 0;

endmodule
