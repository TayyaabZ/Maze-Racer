game_over_time:
game_over_enemy:
    call fill_red_columns
    call beep_descend
    call flush_kb
    
    mov cx, 60
    mov dx, 60
    mov si, 200
    mov di, 80
    mov al, 4
    call draw_rect
    mov cx, 62
    mov dx, 62
    mov si, 196
    mov di, 76
    mov al, 0
    call draw_rect
    
    mov si, str_game_over
    mov dx, 72
    mov bl, 12
    mov bh, 3
    call draw_string_centered
    
    mov al, [difficulty]
    cmp al, 0
    jne .def_harder
    mov si, str_failed_retry
    jmp .def_draw_sub
.def_harder:
    mov si, str_failed_easier
.def_draw_sub:
    mov dx, 95
    mov bl, 15
    mov bh, 2
    call draw_string_centered
    
    mov si, str_r_retry
    mov dx, 112
    mov bl, 14
    mov bh, 2
    call draw_string_centered
    
    mov al, [difficulty]
    cmp al, 0
    je .skip_e
    mov si, str_try_easier
    mov dx, 125
    mov bl, 11
    mov bh, 2
    call draw_string_centered
.skip_e:
    mov si, str_q_quit
    mov dx, 138
    mov bl, 8
    mov bh, 2
    call draw_string_centered

.defeat_loop:
    mov ah, 01h
    int 16h
    jz .defeat_loop
    mov ah, 00h
    int 16h
    
    cmp al, 'r'
    je .retry
    cmp al, 'R'
    je .retry
    cmp al, 'e'
    je .easier
    cmp al, 'E'
    je .easier
    cmp al, 'q'
    je .quit
    cmp al, 'Q'
    je .quit
    jmp .defeat_loop

.easier:
    mov al, [difficulty]
    cmp al, 0
    je .defeat_loop
    dec al
    mov [difficulty], al
    mov byte [game_state], 0
    call flush_kb
    jmp menu_loop

.retry:
    call flush_kb
    mov al, [difficulty]
    cmp al, 0
    je .r_easy
    cmp al, 1
    je .r_normal
    mov word [timer_ticks], 1080
    mov byte [map_size], 15
    mov byte [map_bound], 14
    jmp .r_start
.r_easy:
    mov word [timer_ticks], 3600
    mov byte [map_size], 9
    mov byte [map_bound], 8
    jmp .r_start
.r_normal:
    mov word [timer_ticks], 2160
    mov byte [map_size], 15
    mov byte [map_bound], 14
.r_start:
    mov byte [player_x], 0
    mov byte [player_y], 0
    mov byte [player_facing], 1

    ; Clear enemies off map first
    mov byte [enemy_x], 255
    mov byte [enemy_y], 255
    mov byte [enemy_x+1], 255
    mov byte [enemy_y+1], 255

    mov al, [difficulty]
    cmp al, 0
    je .do_r_gen   ; Easy mode: leave enemies off-map

    ; Normal/Hard: Spawn Enemy 0 (Smart Random) at Bottom-Left
    mov byte [enemy_x], 0
    mov al, [map_bound]
    mov byte [enemy_y], al
    mov byte [enemy_type], 0
    mov byte [enemy_dir], 0 ; Facing North

    ; Normal/Hard: Spawn Enemy 1 (Wall Follower) at Top-Right
    mov al, [map_bound]
    mov byte [enemy_x+1], al
    mov byte [enemy_y+1], 0
    mov byte [enemy_type+1], 1
    mov byte [enemy_dir+1], 2 ; Facing South

.do_r_gen:
    call generate_maze
    mov byte [game_state], 1
    jmp main_loop

.quit:
    jmp exit_game

game_win:
    mov ax, 0A000h
    mov es, ax
    xor di, di
    mov cx, 32000
    mov ax, 0E0Eh
    rep stosw
    call beep_jingle
    call flush_kb
    
    mov cx, 3
.flash_loop:
    push cx
    mov al, 10
    call fill_screen_color
    call delay_short
    mov al, 11
    call fill_screen_color
    call delay_short
    mov al, 14
    call fill_screen_color
    call delay_short
    pop cx
    loop .flash_loop
    
    mov cx, 50
    mov dx, 55
    mov si, 220
    mov di, 90
    mov al, 14
    call draw_rect
    mov cx, 52
    mov dx, 57
    mov si, 216
    mov di, 86
    mov al, 0
    call draw_rect
    
    mov si, str_win
    mov dx, 67
    mov bl, 14
    mov bh, 3
    call draw_string_centered
    
    mov si, str_congrats
    mov dx, 92
    mov bl, 15
    mov bh, 2
    call draw_string_centered
    
    mov si, str_play_again
    mov dx, 110
    mov bl, 10
    mov bh, 2
    call draw_string_centered
    
    mov al, [difficulty]
    cmp al, 2
    je .skip_h
    mov si, str_try_harder
    mov dx, 123
    mov bl, 12
    mov bh, 2
    call draw_string_centered
.skip_h:
    mov si, str_q_quit
    mov dx, 136
    mov bl, 8
    mov bh, 2
    call draw_string_centered

.vic_loop:
    mov ah, 01h
    int 16h
    jz .vic_loop
    mov ah, 00h
    int 16h
    
    cmp al, 'r'
    je .retry
    cmp al, 'R'
    je .retry
    cmp al, 'h'
    je .harder
    cmp al, 'H'
    je .harder
    cmp al, 'q'
    je .quit
    cmp al, 'Q'
    je .quit
    jmp .vic_loop

.harder:
    mov al, [difficulty]
    cmp al, 2
    je .vic_loop
    inc al
    mov [difficulty], al
    mov byte [game_state], 0
    call flush_kb
    jmp menu_loop

.retry:
    call flush_kb
    mov al, [difficulty]
    cmp al, 0
    je .r_easy2
    cmp al, 1
    je .r_normal2
    mov word [timer_ticks], 1080
    mov byte [map_size], 15
    mov byte [map_bound], 14
    jmp .r_start2
.r_easy2:
    mov word [timer_ticks], 3600
    mov byte [map_size], 9
    mov byte [map_bound], 8
    jmp .r_start2
.r_normal2:
    mov word [timer_ticks], 2160
    mov byte [map_size], 15
    mov byte [map_bound], 14
.r_start2:
    mov byte [player_x], 0
    mov byte [player_y], 0
    mov byte [player_facing], 1

    ; Clear enemies off map first
    mov byte [enemy_x], 255
    mov byte [enemy_y], 255
    mov byte [enemy_x+1], 255
    mov byte [enemy_y+1], 255

    mov al, [difficulty]
    cmp al, 0
    je .do_r_gen2   ; Easy mode: leave enemies off-map

    ; Normal/Hard: Spawn Enemy 0 (Smart Random) at Bottom-Left
    mov byte [enemy_x], 0
    mov al, [map_bound]
    mov byte [enemy_y], al
    mov byte [enemy_type], 0
    mov byte [enemy_dir], 0 ; Facing North

    ; Normal/Hard: Spawn Enemy 1 (Wall Follower) at Top-Right
    mov al, [map_bound]
    mov byte [enemy_x+1], al
    mov byte [enemy_y+1], 0
    mov byte [enemy_type+1], 1
    mov byte [enemy_dir+1], 2 ; Facing South

.do_r_gen2:
    call generate_maze
    mov byte [game_state], 1
    jmp main_loop

.quit:
    jmp exit_game

flush_kb:
    mov ah, 01h
    int 16h
    jz .done
    mov ah, 00h
    int 16h
    jmp flush_kb
.done:
    ret

draw_rect:
    push bx
    push es
    mov bx, 0A000h
    mov es, bx
.y_loop:
    push di
    push cx
    mov bx, dx
    imul bx, 320
    add bx, cx
    mov di, bx
    mov bx, si
.x_loop:
    mov byte [es:di], al
    inc di
    dec bx
    jnz .x_loop
    pop cx
    pop di
    inc dx
    dec di
    jnz .y_loop
    pop es
    pop bx
    ret

delay_short:
    push cx
    push dx
    mov cx, 0
    mov dx, 0x4000
    mov ah, 86h
    int 15h
    pop dx
    pop cx
    ret

fill_screen_color:
    push es
    push di
    push cx
    mov bx, 0A000h
    mov es, bx
    mov di, 0
    mov cx, 32000
    mov ah, al
    rep stosw
    pop cx
    pop di
    pop es
    ret

draw_string_centered:
    push si
    push ax
    push dx
    push bx
    mov cx, 0
    push bx         ; Save Scale (BH) and Color (BL)
.len_loop:
    mov bx, cx
    cmp byte [bx+si], 0
    je .len_done
    inc cx
    jmp .len_loop
.len_done:
    pop bx          ; Restore Scale and Color
    mov ax, cx      ; Move string length into AX
    mov cl, bh      ; Move scale (BH) into CL
    mov ch, 0
    imul cx, 6      ; CX = scale * 6 (width per character + spacing)
    imul ax, cx     ; AX = total string width in pixels
    mov cx, 320
    sub cx, ax
    sar cx, 1       ; CX = (320 - total width) / 2 = Starting X Coordinate
.draw_loop:
    lodsb
    cmp al, 0
    je .done
    push ax
    push bx
    push cx
    push dx
    push si
    call draw_char
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    
    ; Advance X coordinate for the next letter
    push ax
    mov al, bh      
    mov ah, 0
    imul ax, 6
    add cx, ax
    pop ax
    jmp .draw_loop
.done:
    pop bx
    pop dx
    pop ax
    pop si
    ret

draw_char:
    cmp al, ' '
    je .done
    cmp al, '0'
    jl .check_A
    cmp al, '9'
    jg .check_A
    sub al, '0'
    jmp .got_idx
.check_A:
    cmp al, 'A'
    jl .check_sym
    cmp al, 'Z'
    jg .check_sym
    sub al, 'A'
    add al, 10
    jmp .got_idx
.check_sym:
    cmp al, '>'
    jne .check_bang
    mov al, 37
    jmp .got_idx
.check_bang:
    cmp al, '!'
    jne .check_dot
    mov al, 38
    jmp .got_idx
.check_dot:
    cmp al, '.'
    jne .check_q
    mov al, 39
    jmp .got_idx
.check_q:
    cmp al, '?'
    jne .check_lbracket
    mov al, 40
    jmp .got_idx
.check_lbracket:
    cmp al, '['
    jne .check_rbracket
    mov al, 41
    jmp .got_idx
.check_rbracket:
    cmp al, ']'
    jne .done
    mov al, 42
    jmp .got_idx

.got_idx:
    mov ah, 0
    imul ax, 5
    mov si, font
    add si, ax
    mov word [dc_y], 0
.row_loop:
    mov di, [dc_y]
    push bx             ; Save BH (Scale) and BL (Color)
    mov bx, di
    mov al, [bx+si]     ; Read font byte
    pop bx              ; Restore BH and BL
    mov byte [dc_bits], al
    mov word [dc_x], 0
.col_loop:
    shl byte [dc_bits], 1
    jnc .skip_pix
    mov ax, [dc_x]
    mov ah, 0
    mov al, [dc_x]
    imul bh
    add ax, cx
    mov [dc_px], ax
    mov al, byte [dc_y]
    imul bh
    add ax, dx
    mov [dc_py], ax
    mov byte [dc_sy], 0
.sy_loop:
    mov byte [dc_sx], 0
.sx_loop:
    mov ax, [dc_py]
    add al, [dc_sy]
    adc ah, 0
    imul ax, 320
    mov di, ax
    mov ax, [dc_px]
    add al, [dc_sx]
    adc ah, 0
    add di, ax
    mov al, bl
    mov [es:di], al
    inc byte [dc_sx]
    mov al, [dc_sx]
    cmp al, bh
    jl .sx_loop
    inc byte [dc_sy]
    mov al, [dc_sy]
    cmp al, bh
    jl .sy_loop
.skip_pix:
    inc word [dc_x]
    cmp word [dc_x], 5
    jl .col_loop
    inc word [dc_y]
    cmp word [dc_y], 5
    jl .row_loop
.done:
    ret

draw_menu_item:
    push ax
    push bx
    push cx
    push dx
    push si
    mov [cur_item_idx], bl
    mov [cur_item_y], dx
    mov [cur_item_str], si
    mov cx, 0
.len_loop:
    mov bx, cx
    cmp byte [bx+si], 0
    je .len_done
    inc cx
    jmp .len_loop
.len_done:
    mov ax, cx
    shl ax, 3
    mov [cur_item_w], ax
    mov bx, 320
    sub bx, ax
    sar bx, 1
    mov [cur_item_x], bx
    mov al, [menu_selection]
    cmp al, [cur_item_idx]
    jne .draw_text
    mov cx, 130
    mov dx, [cur_item_y]
    add dx, 3
    mov si, 60
    mov di, 3
    mov al, 4
    call draw_rect
    mov al, [blink_counter]
    test al, 8
    jz .erase_cursor
    mov cx, [cur_item_x]
    sub cx, 16
    mov dx, [cur_item_y]
    mov bl, 14
    mov bh, 2
    mov al, '>'
    call draw_char
    jmp .draw_text
.erase_cursor:
    mov cx, [cur_item_x]
    sub cx, 16
    mov dx, [cur_item_y]
    mov si, 6
    mov di, 10
    mov al, 1
    call draw_rect
.draw_text:
    mov si, [cur_item_str]
    mov dx, [cur_item_y]
    mov bl, 15
    mov bh, 2
    call draw_string_centered
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

menu_loop:
    mov ax, 0A000h
    mov es, ax
    mov di, 0
    mov cx, 32000     ; <--- THIS IS THE FIX
    mov ax, 0101h
    rep stosw
    
    mov cx, 8
    mov dx, 8
    mov si, 304
    mov di, 2
    mov al, 14
    call draw_rect
    mov cx, 8
    mov dx, 190
    mov si, 304
    mov di, 2
    mov al, 14
    call draw_rect
    mov cx, 8
    mov dx, 10
    mov si, 2
    mov di, 180
    mov al, 14
    call draw_rect
    mov cx, 310
    mov dx, 10
    mov si, 2
    mov di, 180
    mov al, 14
    call draw_rect
    
    mov cx, 10
    mov dx, 10
    mov si, 300
    mov di, 1
    mov al, 15
    call draw_rect
    mov cx, 10
    mov dx, 189
    mov si, 300
    mov di, 1
    mov al, 15
    call draw_rect
    mov cx, 10
    mov dx, 11
    mov si, 1
    mov di, 178
    mov al, 15
    call draw_rect
    mov cx, 309
    mov dx, 11
    mov si, 1
    mov di, 178
    mov al, 15
    call draw_rect

    mov si, str_title
    mov dx, 30
    mov bl, 14
    mov bh, 3
    call draw_string_centered
    
    mov si, str_subtitle
    mov dx, 70
    mov bl, 15
    mov bh, 2
    call draw_string_centered
    
    inc byte [blink_counter]
    
    mov bl, 0
    mov dx, 95
    mov si, str_easy
    call draw_menu_item
    
    mov bl, 1
    mov dx, 115
    mov si, str_normal
    call draw_menu_item
    
    mov bl, 2
    mov dx, 135
    mov si, str_hard
    call draw_menu_item
    
    mov bl, 3
    mov dx, 160
    mov si, str_quit
    call draw_menu_item
    
    mov dx, 03DAh
.v1: in al, dx
     test al, 8
     jnz .v1
.v2: in al, dx
     test al, 8
     jz .v2

    mov ah, 01h
    int 16h
    jz menu_loop
    mov ah, 00h
    int 16h
    
    cmp al, 13
    je .enter
    cmp ah, 0x48
    je .up
    cmp ah, 0x50
    je .down
    cmp al, 'w'
    je .up
    cmp al, 'W'
    je .up
    cmp al, 's'
    je .down
    cmp al, 'S'
    je .down
    jmp menu_loop
    
.up:
    dec byte [menu_selection]
    cmp byte [menu_selection], 0xFF
    jne .ok
    mov byte [menu_selection], 3
.ok:
    jmp menu_loop
.down:
    inc byte [menu_selection]
    cmp byte [menu_selection], 4
    jne .ok2
    mov byte [menu_selection], 0
.ok2:
    jmp menu_loop

.enter:
    mov al, [menu_selection]
    cmp al, 3
    je .quit
    
    mov [difficulty], al
    cmp al, 0
    je .easy
    cmp al, 1
    je .normal
.hard:
    mov word [timer_ticks], 1080
    mov byte [map_size], 15
    mov byte [map_bound], 14
    jmp .start_game
.easy:
    mov word [timer_ticks], 3600
    mov byte [map_size], 9
    mov byte [map_bound], 8
    jmp .start_game
.normal:
    mov word [timer_ticks], 2160
    mov byte [map_size], 15
    mov byte [map_bound], 14
.start_game:
    mov byte [player_x], 0
    mov byte [player_y], 0
    mov byte [player_facing], 1

    ; Clear enemies off map first
    mov byte [enemy_x], 255
    mov byte [enemy_y], 255
    mov byte [enemy_x+1], 255
    mov byte [enemy_y+1], 255

    mov al, [difficulty]
    cmp al, 0
    je .do_gen   ; Easy mode: leave enemies off-map

    ; Normal/Hard: Spawn Enemy 0 (Smart Random) at Bottom-Left
    mov byte [enemy_x], 0
    mov al, [map_bound]
    mov byte [enemy_y], al
    mov byte [enemy_type], 0
    mov byte [enemy_dir], 0 ; Facing North

    ; Normal/Hard: Spawn Enemy 1 (Wall Follower) at Top-Right
    mov al, [map_bound]
    mov byte [enemy_x+1], al
    mov byte [enemy_y+1], 0
    mov byte [enemy_type+1], 1
    mov byte [enemy_dir+1], 2 ; Facing South

.do_gen:
    call generate_maze
    mov byte [game_state], 1
    call flush_kb
    jmp main_loop
.quit:
    jmp exit_game
