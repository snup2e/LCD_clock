`timescale 1ns / 1ps

module lcd_display #(parameter cnt1ms = 100000)(
    input clk,
    input reset,
    output lcd_e,
    output lcd_rs,
    output lcd_rw,
    output [7:0] lcd_data
    );
    
    reg   [31:0] cnt_clk;
    reg    [4:0] cnt_4ms, cnt_100ms, cnt_line;
    reg          tick_1ms, tick_4ms, tick_100ms,tick_line;
    reg    [3:0] lcd_routine;
    reg    [7:0] lcd_data;
    reg          lcd_e;
    
    parameter delay_100ms      = 0;
    parameter function_set     = 1;
    parameter entry_mode       = 2;
    parameter disp_on          = 3;
    parameter disp_line1       = 4;
    parameter disp_line2       = 5;
    parameter display_clear    = 6;
    parameter start_clear      = 7;
    
    parameter address_line1=8'b1000_0000;
    parameter address_line2=8'b1100_0000;

    
    
    /////////////////tick 생성/////////////
    always @(posedge clk)begin
        if(!reset)begin
            cnt_clk<=32'b0;
            tick_1ms<=1'b0;
        end
        else begin
            if(cnt_clk==cnt1ms-1)begin
                cnt_clk<=0;
                tick_1ms<=1;
            end
            else begin
                cnt_clk<=cnt_clk+1;
                tick_1ms<=0;
            end
        end
    end
    
    always @(posedge clk)begin
        if(!reset)begin
            cnt_4ms<=0;
            tick_4ms<=0;
        end
        else begin
            if(tick_1ms)begin
                if(cnt_4ms==3)begin
                    cnt_4ms<=0;
                    tick_4ms<=1;
                end
                else begin
                    cnt_4ms<=cnt_4ms+1;
                end
            end
            else tick_4ms<=0;
        end
    end
    
    always @(posedge clk)begin
        if(!reset)begin
            cnt_100ms<=0;
            tick_100ms<=0;
        end
        else begin
            if(lcd_routine==delay_100ms)begin
                if(tick_4ms)begin
                    if(cnt_100ms==24)begin
                        cnt_100ms<=0;
                        tick_100ms<=1;
                    end
                    else begin
                        cnt_100ms<=cnt_100ms+1;
                    end
                end
            end
            else tick_100ms<=0;
        end
    end
    
    
    always @(posedge clk)begin
        if(!reset)begin
            cnt_line<=0;
            tick_line<=0;
        end
        else begin
            if((lcd_routine==disp_line1)||(lcd_routine==disp_line2))begin
                if(tick_4ms)begin
                    if(cnt_line==16)begin
                        cnt_line<=0;
                        tick_line<=1;
                    end
                    else begin
                        cnt_line<=cnt_line+1;
                    end
                end
                else tick_line<=0;
            end
            else begin
                cnt_line<=0;
                tick_line<=0;
            end
        end
    end
    
    always @(posedge clk)begin
        if(!reset) lcd_routine<=start_clear;
        else begin
            case(lcd_routine)
                delay_100ms     :  if(tick_100ms)  lcd_routine<=function_set;    //lcd_rs=0
                function_set    :  if(tick_4ms)    lcd_routine<=entry_mode;      //lcd_rs=0
                entry_mode      :  if(tick_4ms)    lcd_routine<=disp_on;         //lcd_rs=0
                disp_on         :  if(tick_4ms)    lcd_routine<=disp_line1;      //lcd_rs=0
                disp_line1      :  if(tick_line)   lcd_routine<=disp_line2;      //lcd_rs=1
                disp_line2      :  if(tick_line)   lcd_routine<=disp_line1;      //lcd_rs=1
                start_clear     :  if(tick_4ms)    lcd_routine<=delay_100ms;     //lcd_rs=0
            endcase
        end
    end
    
    assign lcd_rw=0;
    assign lcd_rs=(cnt_line!=0)&&((lcd_routine==disp_line1)||(lcd_routine==disp_line2));
    
    always @(posedge clk)begin
        if(!reset)begin
            lcd_data<=8'b0000_0000;
            lcd_e<=0;
        end
        else begin
            if(tick_1ms)begin
                case(lcd_routine)
                    start_clear : begin
                        lcd_data<=8'b0000_0001;
                        if(cnt_4ms==1) lcd_e<=1;
                        else lcd_e<=0;
                    end
                    
                    delay_100ms : begin
                        lcd_data<=8'b0000_0000;
                        if(cnt_4ms==1) lcd_e<=1;
                        else lcd_e<=0;
                    end
                    
                    function_set : begin
                        lcd_data<=8'b0011_1000;
                        if(cnt_4ms==1) lcd_e<=1;
                        else lcd_e<=0;
                    end
                    
                    entry_mode : begin
                        lcd_data<=8'b0000_0110;
                        if(cnt_4ms==1) lcd_e<=1;
                        else lcd_e<=0;
                    end
                    
                    disp_on : begin
                        lcd_data<=8'b0000_1100;
                        if(cnt_4ms==1) lcd_e<=1;
                        else lcd_e<=0;
                    end
                    
                    disp_line1 : begin
                        if(!cnt_line) lcd_data<=address_line1;
                        else lcd_data<= get_char(0,cnt_line-1);
                        
                        if(cnt_4ms==1) lcd_e<=1;
                        else lcd_e<=0;
                    end
                    
                    disp_line2 : begin
                        if(!cnt_line) lcd_data<=address_line2;
                        else lcd_data<=get_char(1,cnt_line-1);
                        
                        if(cnt_4ms==1) lcd_e<=1;
                        else lcd_e<=0;
                    end

                    display_clear : begin
                        lcd_data<=8'b0000_0001;
                        if(cnt_4ms==1) lcd_e<=1;
                        else lcd_e<=0;
                    end

                    
                endcase
            end
        end
    end
    


/////////////////////// year, date counter ////////////////////
    reg [11:0] year;
    reg [4:0]  month;
    reg [7:0]  day;
    reg [4:0]  hour;
    reg [5:0]  min;
    reg [5:0]  sec;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            year  <= 12'd2024;
            month <= 5'd1;
            day   <= 8'd1;
            hour  <= 5'd0;
            min   <= 6'd0;
            sec   <= 6'd0;
        end else if (fast_tick1s) begin                 ////////inner clock -> fast_tick1s instead of tick1s////////////////
            if (sec == 59) begin sec <= 0;
                if (min == 59) begin min <= 0;
                    if (hour == 23) begin hour <= 0;
                        if (day == days_in_month(month)) begin day <= 1;
                            if (month == 12) begin month <= 1; year <= year + 1; end
                            else month <= month + 1;
                        end else day <= day + 1;
                    end else hour <= hour + 1;
                end else min <= min + 1;
            end else sec <= sec + 1;
        end
    end

    function [7:0] days_in_month;
        input [4:0] m;
        begin
            case (m)
                1,3,5,7,8,10,12: days_in_month = 31;
                4,6,9,11:        days_in_month = 30;
                2:               days_in_month = 28;
                default:         days_in_month = 31;
            endcase
        end
    endfunction

    // 8) CGROM 문자 코드 상수
    localparam [7:0] CG_SPACE  = 8'h20; // nothing
    localparam [7:0] CG_DIGIT0 = 8'h30; // '0'
    localparam [7:0] CG_SLASH  = 8'h2F; // '/'
    localparam [7:0] CG_COLON  = 8'h3A; // ':'

////////////////////CGROM - based character function ////////////////////////
    function [7:0] get_char;
        input        line;       ////////// 0 -> 1st line , 1 -> 2nd line //////////////
        input [4:0]  idx;        ///////// pos //////////////
        begin
            if (!line) begin
                // 날짜 모드: YYYY/MM/DD
                case (idx)
                    0:  get_char = CG_DIGIT0 + (year / 1000);
                    1:  get_char = CG_DIGIT0 + ((year / 100)   % 10);
                    2:  get_char = CG_DIGIT0 + ((year / 10)    % 10);
                    3:  get_char = CG_DIGIT0 + (year           % 10);
                    4:  get_char = CG_SLASH;
                    5:  get_char = CG_DIGIT0 + (month / 10);
                    6:  get_char = CG_DIGIT0 + (month % 10);
                    7:  get_char = CG_SLASH;
                    8:  get_char = CG_DIGIT0 + (day   / 10);
                    9:  get_char = CG_DIGIT0 + (day   % 10);
                    10: get_char = CG_SPACE;
                    11: get_char = CG_SPACE;
                    12: get_char = CG_SPACE;
                    13: get_char = CG_SPACE;
                    14: get_char = CG_SPACE;
                    15: get_char = CG_SPACE;                 
                    default: get_char = CG_SPACE;
                endcase
            end else begin
                // 시간 모드: hh:mm:ss
                case (idx)
                    0:  get_char = CG_DIGIT0 + (hour  / 10);
                    1:  get_char = CG_DIGIT0 + (hour  % 10);
                    2:  get_char = CG_COLON;
                    3:  get_char = CG_DIGIT0 + (min   / 10);
                    4:  get_char = CG_DIGIT0 + (min   % 10);
                    5:  get_char = CG_COLON;
                    6:  get_char = CG_DIGIT0 + (sec   / 10);
                    7:  get_char = CG_DIGIT0 + (sec   % 10);
                    8: get_char = CG_SPACE;
                    9: get_char = CG_SPACE;
                    10: get_char = CG_SPACE;
                    11: get_char = CG_SPACE;              
                    12: get_char = CG_SPACE;
                    13: get_char = CG_SPACE;
                    14: get_char = CG_SPACE;
                    15: get_char = CG_SPACE;
                    default: get_char = CG_SPACE;
                endcase
            end
        end
    endfunction
    
        // 10만배속 전용 내부 틱//
    reg [17:0] fast_sec_cnt;  // 
    reg        fast_tick1s;
    always @(posedge clk or negedge reset) begin
      if (!reset) begin
        fast_sec_cnt  <= 0;
        fast_tick1s   <= 0;
      end else if (fast_sec_cnt == 100-1) begin
        fast_sec_cnt  <= 0;
        fast_tick1s   <= 1;    // 
      end else begin
        fast_sec_cnt  <= fast_sec_cnt + 1;
        fast_tick1s   <= 0;
      end
    end

endmodule

