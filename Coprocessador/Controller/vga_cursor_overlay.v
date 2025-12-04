module vga_cursor_overlay (
    input wire clk_vga, 
    input wire reset_n,
    
    
    input wire [7:0] pixel_in,
    
    input wire [9:0] vga_x,
    input wire [9:0] vga_y,
    input wire vga_blank,
    
    input wire cursor_enable,   
    input wire [9:0] cursor_x,  
    input wire [9:0] cursor_y,  
    
    input wire selection_enable,
    input wire [9:0] sel_x1,
    input wire [9:0] sel_y1,
    input wire [9:0] sel_x2,      
    input wire [9:0] sel_y2,
    
    input wire [9:0] img_offset_x,
    input wire [9:0] img_offset_y,
    input wire [9:0] img_width,  
    input wire [9:0] img_height, 
    
    output wire [7:0] pixel_out
);

    parameter CURSOR_SIZE = 2;
    parameter CURSOR_COLOR = 8'hFF;
    parameter SEL_COLOR = 8'hFF;
    
    wire in_image = (vga_x >= img_offset_x && vga_x < img_offset_x + img_width) &&
                    (vga_y >= img_offset_y && vga_y < img_offset_y + img_height);
    
    wire [9:0] img_x = (vga_x - img_offset_x);
    wire [9:0] img_y = (vga_y - img_offset_y);
    
    wire [9:0] img_x_scaled = (img_width == 320) ? (img_x >> 1) : 
                              (img_width == 640) ? (img_x >> 2) :
                              (img_width == 80)  ? (img_x << 1) :
                              (img_width == 40)  ? (img_x << 2) :
                              img_x;
                              
    wire [9:0] img_y_scaled = (img_height == 240) ? (img_y >> 1) :
                              (img_height == 480) ? (img_y >> 2) :
                              (img_height == 60)  ? (img_y << 1) :
                              (img_height == 30)  ? (img_y << 2) :
                              img_y;
    
    wire [10:0] cursor_dx = (img_x_scaled > cursor_x) ? 
                            (img_x_scaled - cursor_x) : 
                            (cursor_x - img_x_scaled);
                            
    wire [10:0] cursor_dy = (img_y_scaled > cursor_y) ? 
                            (img_y_scaled - cursor_y) : 
                            (cursor_y - img_y_scaled);
    
    wire cursor_h_line = (cursor_dy == 0) && (cursor_dx <= CURSOR_SIZE + 1);
    wire cursor_v_line = (cursor_dx == 0) && (cursor_dy <= CURSOR_SIZE + 1);
    
    wire cursor_center = (cursor_dx <= 1) && (cursor_dy <= 1);
    
    wire is_cursor = cursor_enable && in_image && 
                     (cursor_h_line || cursor_v_line || cursor_center);
    
  
    wire [9:0] sel_x_min = (sel_x1 < sel_x2) ? sel_x1 : sel_x2;
    wire [9:0] sel_x_max = (sel_x1 < sel_x2) ? sel_x2 : sel_x1;
    wire [9:0] sel_y_min = (sel_y1 < sel_y2) ? sel_y1 : sel_y2;
    wire [9:0] sel_y_max = (sel_y1 < sel_y2) ? sel_y2 : sel_y1;
    
    wire on_top_edge    = (img_y_scaled == sel_y_min) && 
                          (img_x_scaled >= sel_x_min) && 
                          (img_x_scaled <= sel_x_max);
                          
    wire on_bottom_edge = (img_y_scaled == sel_y_max) && 
                          (img_x_scaled >= sel_x_min) && 
                          (img_x_scaled <= sel_x_max);
                          
    wire on_left_edge   = (img_x_scaled == sel_x_min) && 
                          (img_y_scaled >= sel_y_min) && 
                          (img_y_scaled <= sel_y_max);
                          
    wire on_right_edge  = (img_x_scaled == sel_x_max) && 
                          (img_y_scaled >= sel_y_min) && 
                          (img_y_scaled <= sel_y_max);
    
    wire is_selection = selection_enable && in_image &&
                        (on_top_edge || on_bottom_edge || 
                         on_left_edge || on_right_edge);
    
    reg [7:0] pixel_out_reg;
    
    always @(posedge clk_vga or negedge reset_n) begin
        if (!reset_n) begin
            pixel_out_reg <= 8'd0;
        end else begin
            if (!vga_blank) begin
                pixel_out_reg <= 8'd0;
            end else if (is_cursor) begin
                pixel_out_reg <= CURSOR_COLOR;
            end else if (is_selection) begin
                pixel_out_reg <= SEL_COLOR;
            end else begin
                pixel_out_reg <= pixel_in;
            end
        end
    end
    
    assign pixel_out = pixel_out_reg;

endmodule
