org 100h

section .text
start:
    ; Seed LCG using system timer
    mov ah, 00h
    int 1Ah
    mov word [seed], dx
    mov word [seed+2], cx

    ; Install INT 1Ch handler
    mov ax, 351Ch
    int 21h
    mov [old_int1c_off], bx
    mov [old_int1c_seg], es

    mov ax, 251Ch
    mov dx, timer_isr
    int 21h

    ; Switch to mode 13h
    mov ax, 0013h
    int 10h

    ; ES = 0A000h
    mov ax, cs
    add ax, 0x1000
    mov es, ax

    mov byte [game_state], 0
    mov byte [menu_selection], 0
    jmp menu_loop

main_loop:
    cmp byte [game_state], 0
    je menu_loop

    mov ax, cs
    add ax, 0x1000
    mov es, ax

    ; Clear Buffer
    cmp byte [difficulty], 2
    je .hm_bg
    mov ax, 0101h ; Normal Sky
    mov bx, 0202h ; Normal Floor
    jmp .do_clear
.hm_bg:
    mov ax, 0000h ; Pitch Black Sky
    mov bx, 0000h ; Pitch Black Floor
.do_clear:
    xor di, di
    mov cx, 16000
    rep stosw
    mov cx, 16000
    mov ax, bx
    rep stosw

    ; Check timer for death
    mov ax, [timer_ticks]
    cmp ax, 0
    jg .check_enemy
    jmp game_over_time

.check_enemy:
    mov cx, 2
    mov si, 0
.col_loop:
    mov al, [player_x]
    cmp al, [enemy_x + si]
    jne .col_next
    mov al, [player_y]
    cmp al, [enemy_y + si]
    jne .col_next
    jmp game_over_enemy
.col_next:
    inc si
    loop .col_loop

.check_win:
    mov al, [map_bound]
    cmp byte [player_x], al
    jne .continue_main
    cmp byte [player_y], al
    jne .continue_main
    jmp game_win

.continue_main:
    call render_frame
    call render_minimap

    ; --- Threat Indicator & Heartbeat ---
    cmp byte [difficulty], 2
    jne .skip_threat

    ; Calculate closest enemy
    mov byte [col], 255  ; Use col as a temp variable for Min Distance
    mov cx, 2
    mov si, 0
.threat_calc_loop:
    mov al, [enemy_x + si]
    cmp al, 255
    je .threat_next
    
    ; Manhattan Dist
    mov al, [player_x]
    sub al, [enemy_x + si]
    jns .abs_tx
    neg al
.abs_tx:
    mov dl, al      ; DX = X dist
    mov al, [player_y]
    sub al, [enemy_y + si]
    jns .abs_ty
    neg al
.abs_ty:
    add al, dl      ; AL = Total Dist
    
    cmp al, [col]
    jae .threat_next
    mov [col], al   ; Store new min distance
    mov ah, [enemy_x + si]
    mov [rx_base], ah ; Store closest enemy X
    mov ah, [enemy_y + si]
    mov [ry], ah      ; Store closest enemy Y
.threat_next:
    inc si
    loop .threat_calc_loop

    ; If closest enemy > 4, no threat
    mov cl, [col]
    cmp cl, 4
    jg .skip_threat

    ; Strobe blink timing
    mov ax, [timer_ticks]
    test ax, 2
    jz .skip_threat

    ; --- Directional Strobe ---
    push es
    mov ax, cs
    add ax, 0x1000
    mov es, ax
    
    mov al, [rx_base]
    cmp al, [player_x]
    jg .threat_east
    jl .threat_west
    mov al, [ry]
    cmp al, [player_y]
    jg .threat_south
    jl .threat_north
    jmp .do_beep_pop ; Same tile

.threat_east:
    mov di, 316
    mov cx, 200
.te_loop:
    mov byte [es:di], 4
    mov byte [es:di+1], 4
    mov byte [es:di+2], 4
    mov byte [es:di+3], 4
    add di, 320
    loop .te_loop
    jmp .do_beep_pop

.threat_west:
    mov di, 0
    mov cx, 200
.tw_loop:
    mov byte [es:di], 4
    mov byte [es:di+1], 4
    mov byte [es:di+2], 4
    mov byte [es:di+3], 4
    add di, 320
    loop .tw_loop
    jmp .do_beep_pop

.threat_north:
    mov di, 0
    mov cx, 1280
    mov al, 4
    rep stosb
    jmp .do_beep_pop

.threat_south:
    mov di, 62720
    mov cx, 1280
    mov al, 4
    rep stosb

.do_beep_pop:
    pop es
.do_beep:
    ; Geiger Audio Pulse
    mov al, 0B6h
    out 43h, al
    mov ax, 3000   ; Base pitch
    mov bl, cl
    mov bh, 0
    imul bx, 600   ; Closer = higher pitch
    sub ax, bx
    out 42h, al
    mov al, ah
    out 42h, al
    in al, 61h
    or al, 3
    out 61h, al
    jmp .threat_done

.skip_threat:
    in al, 61h
    and al, 0FCh
    out 61h, al
.threat_done:

    call render_timer

    ; Wait for VSYNC
    mov dx, 03DAh
.vsync_wait1:
    in al, dx
    test al, 8
    jnz .vsync_wait1
.vsync_wait2:
    in al, dx
    test al, 8
    jz .vsync_wait2

    ; Blit Buffer to VGA
    push ds
    mov ax, cs
    add ax, 0x1000
    mov ds, ax      
    mov ax, 0A000h
    mov es, ax      
    xor si, si
    xor di, di
    cld             ; Ensure forward string operation
    mov cx, 32000   ; Copy 64000 bytes (Full 320x200 screen)
    rep movsw       
    pop ds

    ; Restore ES
    mov ax, cs
    add ax, 0x1000
    mov es, ax

    ; Check Input
    mov ah, 01h
    int 16h
    jz main_loop

    ; Consume key
    mov ah, 00h
    int 16h

    cmp al, 27
    je exit_game
    cmp al, 'w'
    je .move_w
    cmp al, 'W'
    je .move_w
    cmp al, 's'
    je .move_s
    cmp al, 'S'
    je .move_s
    cmp al, 'a'
    je .turn_a
    cmp al, 'A'
    je .turn_a
    cmp al, 'd'
    je .turn_d
    cmp al, 'D'
    je .turn_d
    jmp main_loop

.move_w:
    mov cl, [player_facing]
    call try_move
    jmp main_loop

.move_s:
    mov cl, [player_facing]
    add cl, 2
    and cl, 3
    call try_move
    jmp main_loop

.turn_a:
    dec byte [player_facing]
    and byte [player_facing], 3
    jmp main_loop

.turn_d:
    inc byte [player_facing]
    and byte [player_facing], 3
    jmp main_loop

; try_move: CL = direction (0=N, 1=E, 2=S, 3=W)
try_move:
    mov ch, 0
    mov si, cx
    mov bl, [dir_masks + si]
    mov al, [player_x]
    mov ah, 0
    mov cx, ax
    mov al, [player_y]
    mov dx, ax
    
    push bx
    push cx
    push dx
    imul dx, 15
    add dx, cx
    mov di, dx
    mov al, [maze + di]
    pop dx
    pop cx
    pop bx
    
    and al, bl
    jnz .cant_move
    
    mov al, [player_x]
    add al, [dir_dx + si]
    mov [player_x], al
    mov al, [player_y]
    add al, [dir_dy + si]
    mov [player_y], al
.cant_move:
    ret

exit_game:
    push ds
    lds dx, [old_int1c_off]
    mov ax, 251Ch
    int 21h
    pop ds

    mov ax, 0003h
    int 10h

    int 20h

%include "screens.asm"

; ------------------------------------
timer_isr:
    pushf
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    
    push cs
    pop ds
    
    dec word [timer_ticks]
    
    mov ax, [timer_ticks]
    mov cx, 18
    xor dx, dx
    div cx
    cmp dx, 0
    jne .skip_enemy
    call move_enemy
.skip_enemy:
    
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    popf
    
    ; Far jump to old ISR
    jmp far [cs:old_int1c_off]

; ------------------------------------
random_step:
    mov ax, [seed]
    mov cx, 0x4E6D
    mul cx
    push ax
    push dx
    mov ax, [seed+2]
    mov cx, 0x4E6D
    mul cx
    mov bx, ax
    mov ax, [seed]
    mov cx, 0x41C6
    mul cx
    add bx, ax
    pop dx
    add dx, bx
    pop ax
    add ax, 0x3039
    adc dx, 0
    mov [seed], ax
    mov [seed+2], dx
    mov ax, dx
    ret

move_enemy:
    mov cx, 2
    mov si, 0
.e_loop:
    push cx
    push si

    mov al, [enemy_x + si]
    cmp al, 255
    je .next_enemy

    mov ah, 0
    mov cx, ax
    mov al, [enemy_y + si]
    mov dx, ax

    imul dx, 15
    add dx, cx
    mov di, dx
    mov bl, [maze + di]

    mov al, [enemy_type + si]
    cmp al, 0
    je .smart_random
    jmp .wall_follower

.smart_random:
    mov di, 0
    test bl, 1
    jnz .sr_check_e
    mov byte [open_dirs+di], 0
    inc di
.sr_check_e:
    test bl, 2
    jnz .sr_check_s
    mov byte [open_dirs+di], 1
    inc di
.sr_check_s:
    test bl, 4
    jnz .sr_check_w
    mov byte [open_dirs+di], 2
    inc di
.sr_check_w:
    test bl, 8
    jnz .sr_done_check
    mov byte [open_dirs+di], 3
    inc di

.sr_done_check:
    cmp di, 0
    je .next_enemy
    cmp di, 1
    je .sr_pick_only

    mov al, [enemy_dir + si]
    add al, 2
    and al, 3
    
    mov dx, di
    mov cx, di
    mov bx, 0
.sr_rem_loop:
    cmp byte [open_dirs+bx], al
    jne .sr_rem_next
    dec dx
    push cx
    push bx
.sr_shift:
    mov cl, [open_dirs+bx+1]
    mov [open_dirs+bx], cl
    inc bx
    cmp bx, 4
    jl .sr_shift
    pop bx
    pop cx
.sr_rem_next:
    inc bx
    loop .sr_rem_loop
    mov di, dx

.sr_pick_only:
    call random_step
    xor dx, dx
    mov cx, di
    div cx
    mov bx, dx
    mov al, [open_dirs+bx]
    jmp .apply_move

.wall_follower:
    mov al, [enemy_dir + si]
    inc al
    and al, 3
    call check_dir_open
    cmp ah, 1
    je .wf_open

    mov al, [enemy_dir + si]
    call check_dir_open
    cmp ah, 1
    je .wf_open

    mov al, [enemy_dir + si]
    add al, 3
    and al, 3
    call check_dir_open
    cmp ah, 1
    je .wf_open

    mov al, [enemy_dir + si]
    add al, 2
    and al, 3
.wf_open:
.apply_move:
    mov bx, si
    mov [enemy_dir + bx], al
    cbw
    mov di, ax
    mov al, [enemy_x + bx]
    add al, [dir_dx + di]
    mov [enemy_x + bx], al
    mov al, [enemy_y + bx]
    add al, [dir_dy + di]
    mov [enemy_y + bx], al

.next_enemy:
    pop si
    pop cx
    inc si
    dec cx
    jnz .e_loop
    ret

check_dir_open:
    push cx
    mov cl, al
    mov ah, 1
    shl ah, cl
    test bl, ah
    jz .is_open
    mov ah, 0
    jmp .chk_ret
.is_open:
    mov ah, 1
.chk_ret:
    pop cx
    ret

; ------------------------------------
generate_maze:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    push ds
    pop es
    
    mov di, maze
    mov cx, 225
    mov al, 0x0F
    rep stosb
    mov di, visited
    mov cx, 225
    mov al, 0
    rep stosb

    mov di, explored
    mov cx, 225
    mov al, 0
    rep stosb

    mov word [m_sp], 2
    mov word [m_stack], 0
    mov byte [visited], 1

.gen_loop:
    cmp word [m_sp], 0
    je .do_braid

    mov bx, [m_sp]
    sub bx, 2
    mov si, [m_stack + bx]

    mov byte [open_dirs], 0
    mov di, 0

    mov ax, si
    mov cl, 15
    div cl
    mov dh, ah ; X
    mov dl, al ; Y

    cmp dl, 0
    jle .check_s
    mov ax, si
    sub ax, 15
    mov bx, ax
    cmp byte [visited + bx], 0
    jne .check_s
    mov byte [open_dirs + di], 0
    inc di

.check_s:
    mov al, [map_bound]
    cmp dl, al
    jge .check_e
    mov ax, si
    add ax, 15
    mov bx, ax
    cmp byte [visited + bx], 0
    jne .check_e
    mov byte [open_dirs + di], 2
    inc di

.check_e:
    mov al, [map_bound]
    cmp dh, al
    jge .check_w
    mov ax, si
    inc ax
    mov bx, ax
    cmp byte [visited + bx], 0
    jne .check_w
    mov byte [open_dirs + di], 1
    inc di

.check_w:
    cmp dh, 0
    jle .done_neighbors
    mov ax, si
    dec ax
    mov bx, ax
    cmp byte [visited + bx], 0
    jne .done_neighbors
    mov byte [open_dirs + di], 3
    inc di

.done_neighbors:
    cmp di, 0
    je .no_unvisited

    call random_step
    xor dx, dx
    mov cx, di
    div cx
    mov bx, dx
    mov al, [open_dirs + bx]

    mov bx, si
    cmp al, 0
    je .rem_n
    cmp al, 1
    je .rem_e
    cmp al, 2
    je .rem_s
    cmp al, 3
    je .rem_w

.rem_n:
    and byte [maze + bx], 0xFE
    sub bx, 15
    and byte [maze + bx], 0xFB
    jmp .push_neighbor
.rem_e:
    and byte [maze + bx], 0xFD
    inc bx
    and byte [maze + bx], 0xF7
    jmp .push_neighbor
.rem_s:
    and byte [maze + bx], 0xFB
    add bx, 15
    and byte [maze + bx], 0xFE
    jmp .push_neighbor
.rem_w:
    and byte [maze + bx], 0xF7
    dec bx
    and byte [maze + bx], 0xFD

.push_neighbor:
    mov byte [visited + bx], 1
    mov di, [m_sp]
    mov [m_stack + di], bx
    add word [m_sp], 2
    jmp .gen_loop

.no_unvisited:
    sub word [m_sp], 2
    jmp .gen_loop

.do_braid:
    mov cx, 20      ; Knock down 20 walls
.braid_loop:
    push cx
    call random_step
    xor dx, dx
    mov cx, 225
    div cx
    mov bx, dx      ; Pick random cell (0-224)
    mov al, [maze + bx]
    
    call random_step
    xor dx, dx
    mov cx, 4
    div cx          ; Pick random direction (0-3)
    
    cmp dl, 0
    je .b_n
    cmp dl, 1
    je .b_e
    cmp dl, 2
    je .b_s
.b_w:
    and byte [maze + bx], 0xF7
    cmp bx, 0
    je .b_next
    dec bx
    and byte [maze + bx], 0xFD
    jmp .b_next
.b_n:
    and byte [maze + bx], 0xFE
    cmp bx, 14
    jle .b_next
    sub bx, 15
    and byte [maze + bx], 0xFB
    jmp .b_next
.b_e:
    and byte [maze + bx], 0xFD
    cmp bx, 224
    je .b_next
    inc bx
    and byte [maze + bx], 0xF7
    jmp .b_next
.b_s:
    and byte [maze + bx], 0xFB
    cmp bx, 210
    jge .b_next
    add bx, 15
    and byte [maze + bx], 0xFE
.b_next:
    pop cx
    loop .braid_loop

.gen_done:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ------------------------------------
render_frame:
    mov word [col], 0
.col_loop:
    mov ax, [col]
    sub ax, 160
    imul ax, 8
    mov cx, 5
    cwd
    idiv cx
    mov [rx_base], ax

    mov bl, [player_facing]
    cmp bl, 0
    je .face_N
    cmp bl, 1
    je .face_E
    cmp bl, 2
    je .face_S
    jmp .face_W
.face_N:
    mov ax, [rx_base]
    mov [rx], ax
    mov word [ry], -256
    jmp .start_dda
.face_E:
    mov word [rx], 256
    mov ax, [rx_base]
    mov [ry], ax
    jmp .start_dda
.face_S:
    mov ax, [rx_base]
    neg ax
    mov [rx], ax
    mov word [ry], 256
    jmp .start_dda
.face_W:
    mov word [rx], -256
    mov ax, [rx_base]
    neg ax
    mov [ry], ax
.start_dda:

    mov al, [player_x]
    xor ah, ah
    mov [mapX], ax
    mov al, [player_y]
    mov [mapY], ax

    ; X axis
    mov ax, [rx]
    or ax, ax
    jnz .rx_not_zero
    mov word [tDeltaX], 0xFFFF
    mov word [tMaxX], 0xFFFF
    mov word [stepX], 0
    jmp .do_Y
.rx_not_zero:
    mov bx, ax
    mov word [stepX], 1
    jns .rx_pos
    mov word [stepX], -1
    neg bx
.rx_pos:
    cmp bx, 0
    jne .rx_valid
    mov word [tDeltaX], 0xFFFF
    mov word [tMaxX], 0xFFFF
    jmp .do_Y
.rx_valid:
    mov ax, 1024
    xor dx, dx
    div bx
    mov [tDeltaX], ax
    mov ax, 512
    xor dx, dx
    div bx
    mov [tMaxX], ax

.do_Y:
    mov ax, [ry]
    or ax, ax
    jnz .ry_not_zero
    mov word [tDeltaY], 0xFFFF
    mov word [tMaxY], 0xFFFF
    mov word [stepY], 0
    jmp .dda_loop
.ry_not_zero:
    mov bx, ax
    mov word [stepY], 1
    jns .ry_pos
    mov word [stepY], -1
    neg bx
.ry_pos:
    cmp bx, 0
    jne .ry_valid
    mov word [tDeltaY], 0xFFFF
    mov word [tMaxY], 0xFFFF
    jmp .dda_loop
.ry_valid:
    mov ax, 1024
    xor dx, dx
    div bx
    mov [tDeltaY], ax
    mov ax, 512
    xor dx, dx
    div bx
    mov [tMaxY], ax

.dda_loop:
    mov ax, [tMaxX]
    cmp ax, [tMaxY]
    jae .step_y

.step_x:
    mov dx, [tMaxX]
    mov [t_hit], dx

    mov ax, [mapX]
    mov [old_mapX], ax
    add ax, [stepX]
    mov [mapX], ax

    mov ax, [tDeltaX]
    add [tMaxX], ax

    cmp word [mapX], 0
    jl .hit_found
    mov cl, [map_bound]
    mov ch, 0
    cmp [mapX], cx
    jg .hit_found
    cmp word [mapY], 0
    jl .hit_found
    cmp [mapY], cx
    jg .hit_found

    cmp word [stepX], 0
    jle .check_west
    mov bl, 2 ; East
    jmp .check_wall_x
.check_west:
    mov bl, 8 ; West
.check_wall_x:
    mov cx, [old_mapX]
    mov dx, [mapY]
    call check_wall_coord
    cmp al, 1
    je .hit_found
    jmp .dda_loop

.step_y:
    mov dx, [tMaxY]
    mov [t_hit], dx

    mov ax, [mapY]
    mov [old_mapY], ax
    add ax, [stepY]
    mov [mapY], ax

    mov ax, [tDeltaY]
    add [tMaxY], ax

    cmp word [mapX], 0
    jl .hit_found
    mov cl, [map_bound]
    mov ch, 0
    cmp [mapX], cx
    jg .hit_found
    cmp word [mapY], 0
    jl .hit_found
    cmp [mapY], cx
    jg .hit_found

    cmp word [stepY], 0
    jle .check_north
    mov bl, 4 ; South
    jmp .check_wall_y
.check_north:
    mov bl, 1 ; North
.check_wall_y:
    mov cx, [mapX]
    mov dx, [old_mapY]
    call check_wall_coord
    cmp al, 1
    je .hit_found
    jmp .dda_loop

.hit_found:
    mov bx, [t_hit]
    cmp bx, 0
    jne .t_nz
    mov bx, 1
.t_nz:
    mov dx, 0
    mov ax, 800
    div bx
    mov [wall_height], ax

    cmp word [wall_height], 200
    jle .height_ok
    mov word [wall_height], 200
.height_ok:
    cmp word [wall_height], 0
    jle .skip_wall_draw

    mov ax, [wall_height]
    shr ax, 1
    mov cx, 100
    sub cx, ax
    mov [start_y], cx

    mov ax, [t_hit]
    shr ax, 4
    mov bx, ax
    cmp bx, 6
    jle .shade_ok
    mov bx, 6
.shade_ok:
    mov al, 7
    cmp bx, 3
    jl .color_done
    mov al, 8
.color_done:
    cmp byte [difficulty], 2
    jne .save_color
    mov al, 42 ; Orange
    cmp bx, 3
    jl .save_color
    mov al, 43 ; Darker Orange
.save_color:
    mov [wall_color], al

    mov di, [start_y]
    imul di, 320
    add di, [col]

    mov cx, [wall_height]
    mov al, [wall_color]
.draw_slice_loop:
    mov [es:di], al
    add di, 320
    dec cx
    jnz .draw_slice_loop

.skip_wall_draw:
    inc word [col]
    cmp word [col], 320
    jl .col_loop
    ret

check_wall_coord:
    push bx
    push cx
    push dx
    imul dx, 15
    add dx, cx
    mov si, dx
    mov al, [maze + si]
    and al, bl
    jz .no_wall
    mov al, 1
    jmp .cw_done
.no_wall:
    mov al, 0
.cw_done:
    pop dx
    pop cx
    pop bx
    ret

; ------------------------------------
render_minimap:
    ; Set current cell to explored
    mov al, [player_y]
    mov ah, 0
    mov dx, ax
    mov al, [player_x]
    mov cx, ax
    imul dx, 15
    add dx, cx
    mov di, dx
    mov byte [explored + di], 1

    ; Calculate dynamic X offset for top-right anchor
    mov al, [map_size]
    mov ah, 0
    imul ax, 3
    mov bx, 315
    sub bx, ax
    mov [m_off_x], bx

    mov word [mmap_bg_y], 10
    mov al, [map_size]
    mov ah, 0
    imul ax, 3
    add ax, 10
    mov bx, ax

.bg_loop:
    mov ax, [mmap_bg_y]
    imul ax, 320
    add ax, [m_off_x]
    mov di, ax
    mov al, [map_size]
    mov ah, 0
    imul ax, 3
    mov cx, ax
    mov al, 0
    rep stosb
    inc word [mmap_bg_y]
    cmp word [mmap_bg_y], bx
    jl .bg_loop

    mov ax, 9
    imul ax, 320
    add ax, [m_off_x]
    dec ax
    mov di, ax
    mov al, [map_size]
    mov ah, 0
    imul ax, 3
    add ax, 2
    mov cx, ax
    mov al, 15
    rep stosb

    mov al, [map_size]
    mov ah, 0
    imul ax, 3
    add ax, 10
    imul ax, 320
    add ax, [m_off_x]
    dec ax
    mov di, ax
    mov al, [map_size]
    mov ah, 0
    imul ax, 3
    add ax, 2
    mov cx, ax
    mov al, 15
    rep stosb

    mov word [mmap_bg_y], 9
    mov al, [map_size]
    mov ah, 0
    imul ax, 3
    add ax, 11
    mov bx, ax
.border_loop:
    mov ax, [mmap_bg_y]
    imul ax, 320
    add ax, [m_off_x]
    dec ax
    mov di, ax
    mov byte [es:di], 15
    mov al, [map_size]
    mov ah, 0
    imul ax, 3
    inc ax
    add di, ax
    mov byte [es:di], 15
    inc word [mmap_bg_y]
    cmp word [mmap_bg_y], bx
    jl .border_loop

    mov word [mmap_y], 0
.my_loop:
    mov word [mmap_x], 0
.mx_loop:
    cmp byte [difficulty], 2
    jne .not_fow
    mov ax, [mmap_y]
    imul ax, 15
    add ax, [mmap_x]
    mov si, ax
    cmp byte [explored + si], 0
    je .skip_cell
.not_fow:
    mov ax, [mmap_y]
    imul ax, 15
    add ax, [mmap_x]
    mov si, ax
    mov bl, [maze + si]

    mov ax, [mmap_x]
    imul ax, 3
    add ax, [m_off_x]
    mov [m_px], ax
    mov ax, [mmap_y]
    imul ax, 3
    add ax, 10
    mov [m_py], ax

    push ax
    push cx
    push di
    mov ax, [m_py]
    imul ax, 320
    add ax, [m_px]
    mov di, ax
    mov cx, 3
.fill_cell_row:
    mov byte [es:di],   8
    mov byte [es:di+1], 8
    mov byte [es:di+2], 8
    add di, 320
    loop .fill_cell_row
    pop di
    pop cx
    pop ax

    test bl, 1
    jz .no_n
    call draw_m_north
.no_n:
    test bl, 2
    jz .no_e
    call draw_m_east
.no_e:
    test bl, 4
    jz .no_s
    call draw_m_south
.no_s:
    test bl, 8
    jz .no_w
    call draw_m_west
.no_w:

.skip_cell:
    inc word [mmap_x]
    mov ax, 0
    mov al, [map_size]
    cmp [mmap_x], ax
    jl .mx_loop
    inc word [mmap_y]
    mov ax, 0
    mov al, [map_size]
    cmp [mmap_y], ax
    jl .my_loop

    mov al, [player_x]
    cbw
    imul ax, 3
    add ax, [m_off_x]
    inc ax
    mov bx, ax
    mov al, [player_y]
    cbw
    imul ax, 3
    add ax, 11
    imul ax, 320
    add bx, ax
    mov di, bx
    mov byte [es:di], 14
    mov byte [es:di+1], 14
    mov byte [es:di+320], 14
    mov byte [es:di+321], 14

    cmp byte [difficulty], 1
    jne .skip_enemy_draw

    mov cx, 2
    mov si, 0
.draw_e_loop:
    push cx
    mov al, [enemy_x + si]
    cmp al, 255
    je .next_e

    cbw
    imul ax, 3
    add ax, [m_off_x]
    inc ax
    mov bx, ax

    mov al, [enemy_y + si]
    cbw
    imul ax, 3
    add ax, 11
    imul ax, 320
    add bx, ax

    mov di, bx
    mov byte [es:di], 4
    mov byte [es:di+1], 4
    mov byte [es:di+320], 4
    mov byte [es:di+321], 4

.next_e:
    inc si
    pop cx
    loop .draw_e_loop

.skip_enemy_draw:

    mov al, [map_bound]
    cbw
    imul ax, 3
    add ax, [m_off_x]
    inc ax
    mov bx, ax
    mov al, [map_bound]
    cbw
    imul ax, 3
    add ax, 11
    imul ax, 320
    add bx, ax
    mov di, bx
    mov byte [es:di],     10
    mov byte [es:di+1],   10
    mov byte [es:di+320], 10
    mov byte [es:di+321], 10

    ret

draw_m_north:
    push ax
    push bx
    push dx
    push di
    mov ax, [m_py]
    imul ax, 320
    add ax, [m_px]
    mov di, ax
    mov byte [es:di], 15
    mov byte [es:di+1], 15
    mov byte [es:di+2], 15
    pop di
    pop dx
    pop bx
    pop ax
    ret

draw_m_south:
    push ax
    push bx
    push dx
    push di
    mov ax, [m_py]
    add ax, 2
    imul ax, 320
    add ax, [m_px]
    mov di, ax
    mov byte [es:di], 15
    mov byte [es:di+1], 15
    mov byte [es:di+2], 15
    pop di
    pop dx
    pop bx
    pop ax
    ret

draw_m_east:
    push ax
    push bx
    push dx
    push di
    mov ax, [m_py]
    imul ax, 320
    add ax, [m_px]
    add ax, 2
    mov di, ax
    mov byte [es:di], 15
    mov byte [es:di+320], 15
    mov byte [es:di+640], 15
    pop di
    pop dx
    pop bx
    pop ax
    ret

draw_m_west:
    push ax
    push bx
    push dx
    push di
    mov ax, [m_py]
    imul ax, 320
    add ax, [m_px]
    mov di, ax
    mov byte [es:di], 15
    mov byte [es:di+320], 15
    mov byte [es:di+640], 15
    pop di
    pop dx
    pop bx
    pop ax
    ret

; ------------------------------------
render_timer:
    mov ax, [timer_ticks]
    mov cx, 18
    xor dx, dx
    div cx
    
    mov bx, 100
    xor dx, dx
    div bx
    mov [digits+0], al
    mov ax, dx
    mov bl, 10
    div bl
    mov [digits+1], al
    mov [digits+2], ah

    mov al, [digits+0]
    add al, '0'
    mov cx, 10
    mov dx, 10
    mov bl, 15
    mov bh, 3
    call draw_char

    mov al, [digits+1]
    add al, '0'
    mov cx, 28
    mov dx, 10
    mov bl, 15
    mov bh, 3
    call draw_char

    mov al, [digits+2]
    add al, '0'
    mov cx, 46
    mov dx, 10
    mov bl, 15
    mov bh, 3
    call draw_char

    ret

; ------------------------------------
fill_red_columns:
    mov ax, 0A000h
    mov es, ax
    mov cx, 320
    mov word [d_col], 0
.cloop:
    mov di, [d_col]
    mov bx, 200
.yloop:
    mov byte [es:di], 4
    add di, 320
    dec bx
    jnz .yloop
    
    push cx
    mov cx, 0
    mov dx, 0x1000
    mov ah, 86h
    int 15h
    pop cx
    
    inc word [d_col]
    dec cx
    jnz .cloop
    ret

print_game_over:
    mov ah, 02h
    mov bh, 0
    mov dh, 12
    mov dl, 15
    int 10h
    
    mov si, str_game_over
.ploop:
    lodsb
    cmp al, 0
    je .pdone
    mov ah, 0Eh
    mov bl, 15
    int 10h
    jmp .ploop
.pdone:
    ret

print_win:
    mov ah, 02h
    mov bh, 0
    mov dh, 12
    mov dl, 14
    int 10h
    
    mov si, str_win
.ploop2:
    lodsb
    cmp al, 0
    je .pdone2
    mov ah, 0Eh
    mov bl, 0
    int 10h
    jmp .ploop2
.pdone2:
    ret

beep_descend:
    mov bx, 2000
.bloop:
    call play_sound
    add bx, 500
    cmp bx, 8000
    jl .bloop
    call stop_sound
    ret

beep_jingle:
    mov bx, 3000
    call play_sound
    mov bx, 2500
    call play_sound
    mov bx, 2000
    call play_sound
    mov bx, 1500
    call play_sound
    mov bx, 1000
    call play_sound
    call stop_sound
    ret

play_sound:
    mov al, 0B6h
    out 43h, al
    mov ax, bx
    out 42h, al
    mov al, ah
    out 42h, al
    in al, 61h
    or al, 3
    out 61h, al
    push cx
    push dx
    mov cx, 0
    mov dx, 0x8000
    mov ah, 86h
    int 15h
    pop dx
    pop cx
    ret

stop_sound:
    in al, 61h
    and al, 0FCh
    out 61h, al
    ret

; ------------------------------------
section .data
font:
db 01110000b, 01010000b, 01010000b, 01010000b, 01110000b ; 0
db 00100000b, 01100000b, 00100000b, 00100000b, 01110000b ; 1
db 01110000b, 00010000b, 01110000b, 01000000b, 01110000b ; 2
db 01110000b, 00010000b, 01110000b, 00010000b, 01110000b ; 3
db 01010000b, 01010000b, 01110000b, 00010000b, 00010000b ; 4
db 01110000b, 01000000b, 01110000b, 00010000b, 01110000b ; 5
db 01110000b, 01000000b, 01110000b, 01010000b, 01110000b ; 6
db 01110000b, 00010000b, 00100000b, 00100000b, 00100000b ; 7
db 01110000b, 01010000b, 01110000b, 01010000b, 01110000b ; 8
db 01110000b, 01010000b, 01110000b, 00010000b, 01110000b ; 9
db 01000000b, 10100000b, 11100000b, 10100000b, 10100000b ; A
db 11000000b, 10100000b, 11000000b, 10100000b, 11000000b ; B
db 01100000b, 10000000b, 10000000b, 10000000b, 01100000b ; C
db 11000000b, 10100000b, 10100000b, 10100000b, 11000000b ; D
db 11100000b, 10000000b, 11000000b, 10000000b, 11100000b ; E
db 11100000b, 10000000b, 11000000b, 10000000b, 10000000b ; F
db 01100000b, 10000000b, 10100000b, 10100000b, 01100000b ; G
db 10100000b, 10100000b, 11100000b, 10100000b, 10100000b ; H
db 11100000b, 01000000b, 01000000b, 01000000b, 11100000b ; I
db 00100000b, 00100000b, 00100000b, 10100000b, 01000000b ; J
db 10100000b, 11000000b, 10000000b, 11000000b, 10100000b ; K
db 10000000b, 10000000b, 10000000b, 10000000b, 11100000b ; L
db 10100000b, 11100000b, 11100000b, 10100000b, 10100000b ; M
db 11000000b, 10100000b, 10100000b, 10100000b, 10100000b ; N
db 01000000b, 10100000b, 10100000b, 10100000b, 01000000b ; O
db 11000000b, 10100000b, 11000000b, 10000000b, 10000000b ; P
db 01000000b, 10100000b, 10100000b, 01000000b, 00100000b ; Q
db 11000000b, 10100000b, 11000000b, 10100000b, 10100000b ; R
db 01100000b, 10000000b, 01000000b, 00100000b, 11000000b ; S
db 11100000b, 01000000b, 01000000b, 01000000b, 01000000b ; T
db 10100000b, 10100000b, 10100000b, 10100000b, 01100000b ; U
db 10100000b, 10100000b, 10100000b, 10100000b, 01000000b ; V
db 10100000b, 10100000b, 11100000b, 11100000b, 10100000b ; W
db 10100000b, 10100000b, 01000000b, 10100000b, 10100000b ; X
db 10100000b, 10100000b, 01000000b, 01000000b, 01000000b ; Y
db 11100000b, 00100000b, 01000000b, 10000000b, 11100000b ; Z
db 00000000b, 00000000b, 00000000b, 00000000b, 00000000b ; Space (36)
db 10000000b, 11000000b, 11100000b, 11000000b, 10000000b ; > (37)
db 01000000b, 01000000b, 01000000b, 00000000b, 01000000b ; ! (38)
db 00000000b, 00000000b, 00000000b, 00000000b, 01000000b ; . (39)
db 11000000b, 00100000b, 01000000b, 00000000b, 01000000b ; ? (40)
db 11000000b, 10000000b, 10000000b, 10000000b, 11000000b ; [ (41)
db 01100000b, 00100000b, 00100000b, 00100000b, 01100000b ; ] (42)

str_game_over db "GAME OVER", 0
str_win db "YOU ESCAPED!", 0
str_title db "MAZE RUNNER", 0
str_subtitle db "CHOOSE DIFFICULTY", 0
str_easy db "EASY", 0
str_normal db "NORMAL", 0
str_hard db "HARD", 0
str_quit db "QUIT", 0
str_failed_retry db "YOU FAILED. RETRY?", 0
str_failed_easier db "YOU FAILED. TRY EASIER?", 0
str_r_retry db "[R] RETRY", 0
str_e_easy db "[E] EASY MODE", 0
str_n_normal db "[N] NORMAL MODE", 0
str_q_quit db "[Q] QUIT", 0
str_congrats db "CONGRATULATIONS", 0
str_r_play_again db "[R] PLAY AGAIN", 0
str_n_try_normal db "[N] TRY NORMAL", 0
str_h_try_hard db "[H] TRY HARD", 0
str_m_menu db "[M] MENU / DIFFICULTY", 0
str_try_harder db "[H] TRY HARDER", 0
str_try_easier db "[E] TRY EASIER", 0
str_play_again db "[R] PLAY AGAIN", 0

dir_masks db 1, 2, 4, 8
dir_dx db 0, 1, 0, -1
dir_dy db -1, 0, 1, 0

map_size db 15
map_bound db 14

player_x db 1
player_y db 1
player_facing db 1

section .bss
enemy_x resb 2
enemy_y resb 2
enemy_dir resb 2
enemy_type resb 2
maze resb 225
visited resb 225
explored resb 225
m_stack resw 225
m_sp resw 1

difficulty resb 1
game_state resb 1
menu_selection resb 1
blink_counter resb 1
timer_ticks resw 1

cur_item_idx resb 1
cur_item_y resw 1
cur_item_str resw 1
cur_item_w resw 1
cur_item_x resw 1

dc_y resw 1
dc_x resw 1
dc_bits resb 1
dc_px resw 1
dc_py resw 1
dc_sy resb 1
dc_sx resb 1

seed resd 1
old_int1c_off resw 1
old_int1c_seg resw 1

col resw 1
rx_base resw 1
rx resw 1
ry resw 1

mapX resw 1
mapY resw 1
old_mapX resw 1
old_mapY resw 1
stepX resw 1
stepY resw 1
tDeltaX resw 1
tDeltaY resw 1
tMaxX resw 1
tMaxY resw 1
t_hit resw 1
wall_height resw 1
start_y resw 1
wall_color resb 1

mmap_x resw 1
mmap_y resw 1
m_px resw 1
m_py resw 1

digits resb 3
d_px resw 1
d_py resw 1
d_col resw 1

open_dirs resb 4
mmap_bg_y resw 1
m_off_x resw 1