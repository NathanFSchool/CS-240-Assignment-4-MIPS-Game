# Blackjack for MARS 4.5 -- built-in Bitmap Display + Run I/O.
# Bitmap: unit width/height 4, display width/height 512,
# base address 0x10010000 (static data). Connect BEFORE running.
# Leave Settings > Delayed branching OFF (the MARS default).
# One round; no betting, splitting, doubling down, or insurance.
# Enter h/H to hit or s/S to stay, then press Enter.

.data 0x10010000
# 128 x 128 logical pixels, 4 bytes per pixel = 65,536 bytes.
# Keep this FIRST so the bitmap does not overwrite the deck.
framebuffer:    .space 65536

# Four copies of every rank. 1 = Ace; 11 = Jack; 12 = Queen; 13 = King.
deck:           .word 1, 1, 1, 1
                .word 2, 2, 2, 2
                .word 3, 3, 3, 3
                .word 4, 4, 4, 4
                .word 5, 5, 5, 5
                .word 6, 6, 6, 6
                .word 7, 7, 7, 7
                .word 8, 8, 8, 8
                .word 9, 9, 9, 9
                .word 10, 10, 10, 10
                .word 11, 11, 11, 11
                .word 12, 12, 12, 12
                .word 13, 13, 13, 13
deck_count:     .word 52

# Room for up to 52 word-sized cards per hand.
player_hand:    .space 208
dealer_hand:    .space 208
player_count:   .word 0
dealer_count:   .word 0
dealer_hidden:  .word 1
game_result:    .word 0           # 0 playing, 1 win, 2 loss, 3 tie
border_colors:  .word 0x00C5AA68, 0x002ECC71, 0x00E04B47, 0x00FFD24A
input_buffer:   .space 128

welcome:        .asciiz "Welcome to Blackjack!\nGet closer to 21 than the dealer without going over.\nAces count as 1 or 11. Face cards count as 10.\nThe dealer stands on all 17s. Equal scores are a tie.\nBitmap border: green = win, red = loss, yellow = tie.\n\n"
player_label:   .asciiz "Player cards: "
dealer_label:   .asciiz "Dealer cards: "
score_label:    .asciiz "Score: "
separator:      .asciiz ", "
hidden_text:    .asciiz "[hidden]"
ace_text:       .asciiz "Ace"
jack_text:      .asciiz "Jack"
queen_text:     .asciiz "Queen"
king_text:      .asciiz "King"
prompt:         .asciiz "Hit or stay? Enter h or s: "
invalid_input:  .asciiz "Invalid input. Enter only h or s, then press Enter.\n\n"
reveal_text:    .asciiz "\nDealer reveals the hidden card.\n"
player_21:      .asciiz "You have 21. Your turn is over.\n"
dealer_stands:  .asciiz "Dealer stays.\n"
player_bust_msg:.asciiz "You went over 21. Dealer wins!\n"
dealer_bust_msg:.asciiz "Dealer went over 21. You win!\n"
player_bj_msg:  .asciiz "Blackjack! You win!\n"
dealer_bj_msg:  .asciiz "Dealer has blackjack. Dealer wins!\n"
both_bj_msg:    .asciiz "Both have blackjack. Tie game!\n"
win_msg:        .asciiz "You win!\n"
lose_msg:       .asciiz "Dealer wins!\n"
tie_msg:        .asciiz "Equal scores. Tie game!\n"
empty_msg:      .asciiz "No cards remain. Game ended.\n"

# Each sprite has 7 rows of 11 bits, stored as halfwords.
# A set bit paints one logical pixel. Index 0 is the card back's ?.
# Indices 1-13 match card ranks. Indices 14-19 draw the captions.
.align 1
rank_sprites:
    .half 112,136,8,16,32,0,32             # 0: ?
    .half 112,136,136,248,136,136,136      # 1: A
    .half 112,136,8,16,32,64,248           # 2
    .half 240,8,8,112,8,8,240             # 3
    .half 16,48,80,144,248,16,16          # 4
    .half 248,128,128,240,8,8,240         # 5
    .half 112,128,128,240,136,136,112      # 6
    .half 248,8,16,32,64,64,64            # 7
    .half 112,136,136,112,136,136,112     # 8
    .half 112,136,136,120,8,8,112         # 9
    .half 270,785,275,277,281,273,910     # 10: both digits
    .half 56,16,16,16,144,144,96          # 11: J
    .half 112,136,136,136,168,144,104     # 12: Q
    .half 136,144,160,192,160,144,136     # 13: K
    .half 240,136,136,136,136,136,240     # 14: D
    .half 248,128,128,240,128,128,248     # 15: E
    .half 128,128,128,128,128,128,248     # 16: L
    .half 240,136,136,240,128,128,128     # 17: P
    .half 240,136,136,240,160,144,136     # 18: R
    .half 136,136,80,32,32,32,32          # 19: Y
dealer_caption: .byte 14,15,1,16,15,18   # DEALER
player_caption: .byte 17,16,1,19,15,18   # PLAYER

.text
.globl main

main:
    la   $a0, welcome
    jal  print_string
    jal  draw_table

    # Seed generator 1 once, using the current system time.
    li   $v0, 30
    syscall
    move $a1, $a0
    li   $a0, 1
    li   $v0, 40
    syscall

    # Deal in the order from your pseudocode.
    # Each call prints the receiving hand immediately.
    jal  give_dealer_card
    jal  give_dealer_card
    jal  give_player_card
    jal  give_player_card

    # $s0 = player score; $s1 = dealer score.
    la   $a0, player_hand
    lw   $a1, player_count
    jal  calculate_score
    move $s0, $v0

    la   $a0, dealer_hand
    lw   $a1, dealer_count
    jal  calculate_score
    move $s1, $v0

    # Check both initial hands before allowing any hits.
    li   $t0, 21
    beq  $s0, $t0, initial_player_blackjack
    beq  $s1, $t0, initial_dealer_blackjack
    j    player_turn

initial_player_blackjack:
    jal  reveal_dealer
    li   $t0, 21
    beq  $s1, $t0, both_blackjack
    la   $a0, player_bj_msg
    j    finish_win

initial_dealer_blackjack:
    jal  reveal_dealer
    la   $a0, dealer_bj_msg
    j    finish_loss

both_blackjack:
    la   $a0, both_bj_msg
    j    finish_tie

player_turn:
    la   $a0, prompt
    jal  print_string
    jal  read_choice

    li   $t0, 1
    beq  $v0, $t0, player_hit
    li   $t0, 2
    beq  $v0, $t0, dealer_turn

    la   $a0, invalid_input
    jal  print_string
    j    player_turn

player_hit:
    jal  give_player_card
    la   $a0, player_hand
    lw   $a1, player_count
    jal  calculate_score
    move $s0, $v0

    bgt  $s0, 21, player_bust
    beq  $s0, 21, player_reaches_21
    j    player_turn

player_reaches_21:
    la   $a0, player_21
    jal  print_string
    j    dealer_turn

dealer_turn:
    jal  reveal_dealer

dealer_loop:
    la   $a0, dealer_hand
    lw   $a1, dealer_count
    jal  calculate_score
    move $s1, $v0

    bgt  $s1, 21, dealer_bust
    bge  $s1, 17, compare_scores
    jal  give_dealer_card
    j    dealer_loop

compare_scores:
    la   $a0, dealer_stands
    jal  print_string
    bgt  $s0, $s1, player_wins
    beq  $s0, $s1, scores_tied
    la   $a0, lose_msg
    j    finish_loss

player_wins:
    la   $a0, win_msg
    j    finish_win

scores_tied:
    la   $a0, tie_msg
    j    finish_tie

player_bust:
    la   $a0, player_bust_msg
    j    finish_loss

dealer_bust:
    la   $a0, dealer_bust_msg
    j    finish_win

finish_win:
    li   $t0, 1
    sw   $t0, game_result
    j    game_over

finish_loss:
    li   $t0, 2
    sw   $t0, game_result
    j    game_over

finish_tie:
    li   $t0, 3
    sw   $t0, game_result

game_over:
    jal  print_string
    jal  draw_table
    li   $v0, 10
    syscall

# ------------------------------------------------------------
# draw_card
# Returns a random rank in $v0, removing it from the active deck.
# Removal replaces its slot with the last active card, then
# decreases deck_count. No shifting or retrying is necessary.
# ------------------------------------------------------------
draw_card:
    lw   $a1, deck_count
    beqz $a1, deck_empty
    li   $a0, 1
    li   $v0, 42
    syscall                     # $a0 = index, 0 <= index < count

    la   $t0, deck
    sll  $t1, $a0, 2            # index * 4
    addu $t1, $t0, $t1          # address of selected card
    lw   $v0, 0($t1)            # save selected rank for return

    lw   $t2, deck_count
    addiu $t2, $t2, -1          # last active index = count - 1
    sll  $t3, $t2, 2
    addu $t3, $t0, $t3
    lw   $t4, 0($t3)
    sw   $t4, 0($t1)            # fill selected slot with last card
    sw   $zero, 0($t3)          # clear the now-inactive last slot
    sw   $t2, deck_count
    jr   $ra

deck_empty:
    la   $a0, empty_msg
    j    game_over

# These wrappers prepare arguments for the shared give_card.
# j (not jal) lets give_card return directly to the caller.
give_player_card:
    la   $a0, player_hand
    la   $a1, player_count
    la   $a2, player_label
    li   $a3, 0
    j    give_card

give_dealer_card:
    la   $a0, dealer_hand
    la   $a1, dealer_count
    la   $a2, dealer_label
    lw   $a3, dealer_hidden
    j    give_card

# give_card($a0 = hand, $a1 = count address,
#           $a2 = label, $a3 = hide first card)
# Draws, appends to the hand, and prints the updated hand.
give_card:
    addiu $sp, $sp, -24
    sw   $a0, 0($sp)
    sw   $a1, 4($sp)
    sw   $a2, 8($sp)
    sw   $a3, 12($sp)
    sw   $ra, 20($sp)

    jal  draw_card

    lw   $a0, 0($sp)
    lw   $t0, 4($sp)
    lw   $a1, 0($t0)            # current hand count
    sll  $t1, $a1, 2
    addu $t1, $a0, $t1
    sw   $v0, 0($t1)            # hand[count] = drawn rank
    addiu $a1, $a1, 1
    sw   $a1, 0($t0)            # update count in memory

    lw   $a2, 8($sp)
    lw   $a3, 12($sp)
    jal  print_hand
    jal  draw_table

    lw   $ra, 20($sp)
    addiu $sp, $sp, 24
    jr   $ra

# calculate_score($a0 = hand, $a1 = number of cards)
# Returns the best total in $v0. Count Aces as 1 initially;
# upgrade one Ace to 11 only if doing so does not exceed 21.
calculate_score:
    move $t0, $a0
    move $t1, $a1
    li   $t2, 0                  # Ace count
    li   $v0, 0                  # total

score_loop:
    beqz $t1, score_adjust_ace
    lw   $t3, 0($t0)
    beq  $t3, 1, score_ace
    ble  $t3, 10, score_add
    li   $t3, 10                 # Jack, Queen, King = 10
    j    score_add

score_ace:
    addiu $t2, $t2, 1            # rank 1 already contributes 1

score_add:
    addu $v0, $v0, $t3
    addiu $t0, $t0, 4
    addiu $t1, $t1, -1
    j    score_loop

score_adjust_ace:
    beqz $t2, score_done
    addiu $t3, $v0, 10
    bgt  $t3, 21, score_done
    move $v0, $t3

score_done:
    jr   $ra

# print_hand($a0 = hand, $a1 = count, $a2 = label,
#            $a3 = hide first card)
# Does not show a total while the dealer's first card is hidden.
print_hand:
    addiu $sp, $sp, -24
    sw   $s0, 0($sp)
    sw   $s1, 4($sp)
    sw   $s2, 8($sp)
    sw   $s3, 12($sp)
    sw   $ra, 20($sp)
    move $s0, $a0
    move $s1, $a1
    move $s2, $a3
    li   $s3, 0
    move $a0, $a2
    jal  print_string

print_hand_loop:
    beq  $s3, $s1, print_hand_score
    beqz $s3, print_hand_card
    la   $a0, separator
    jal  print_string

print_hand_card:
    bnez $s3, print_visible_card
    beqz $s2, print_visible_card
    la   $a0, hidden_text
    jal  print_string
    j    print_hand_next

print_visible_card:
    sll  $t0, $s3, 2
    addu $t0, $s0, $t0
    lw   $a0, 0($t0)
    jal  print_card

print_hand_next:
    addiu $s3, $s3, 1
    j    print_hand_loop

print_hand_score:
    li   $v0, 11
    li   $a0, 10
    syscall                     # newline after card list
    bnez $s2, print_hand_done

    la   $a0, score_label
    jal  print_string
    move $a0, $s0
    move $a1, $s1
    jal  calculate_score
    move $a0, $v0
    li   $v0, 1
    syscall
    li   $v0, 11
    li   $a0, 10
    syscall

print_hand_done:
    li   $v0, 11
    li   $a0, 10
    syscall                     # blank line after each hand update
    lw   $s0, 0($sp)
    lw   $s1, 4($sp)
    lw   $s2, 8($sp)
    lw   $s3, 12($sp)
    lw   $ra, 20($sp)
    addiu $sp, $sp, 24
    jr   $ra

# Reveal and print the dealer's complete hand and score.
reveal_dealer:
    addiu $sp, $sp, -8
    sw   $ra, 4($sp)
    sw   $zero, dealer_hidden
    la   $a0, reveal_text
    jal  print_string
    la   $a0, dealer_hand
    lw   $a1, dealer_count
    la   $a2, dealer_label
    li   $a3, 0
    jal  print_hand
    jal  draw_table
    lw   $ra, 4($sp)
    addiu $sp, $sp, 8
    jr   $ra

# Print the rank passed in $a0. Tail jumps reuse the caller's $ra.
print_card:
    beq  $a0, 1, print_ace
    beq  $a0, 11, print_jack
    beq  $a0, 12, print_queen
    beq  $a0, 13, print_king
    li   $v0, 1
    syscall
    jr   $ra

print_ace:
    la   $a0, ace_text
    j    print_string
print_jack:
    la   $a0, jack_text
    j    print_string
print_queen:
    la   $a0, queen_text
    j    print_string
print_king:
    la   $a0, king_text
    j    print_string

# read_choice returns 1 = hit, 2 = stay, 0 = invalid.
# String input avoids crashing on letters entered as integers.
read_choice:
    li   $v0, 8
    la   $a0, input_buffer
    li   $a1, 128
    syscall
    lbu  $t0, 0($a0)
    lbu  $t1, 1($a0)
    beqz $t0, choice_invalid
    beqz $t1, choice_check
    bne  $t1, 10, choice_invalid  # reject extra characters

choice_check:
    beq  $t0, 104, choice_hit     # h
    beq  $t0, 72, choice_hit      # H
    beq  $t0, 115, choice_stay    # s
    beq  $t0, 83, choice_stay     # S

choice_invalid:
    li   $v0, 0
    jr   $ra
choice_hit:
    li   $v0, 1
    jr   $ra
choice_stay:
    li   $v0, 2
    jr   $ra

print_string:
    li   $v0, 4
    syscall
    jr   $ra

# ============================================================
# BITMAP GRAPHICS
# All coordinates use a 128 x 128 logical grid.
# With 4 x 4 units, MARS displays this as 512 x 512 screen pixels.
# Pixel address = framebuffer + 4 * (y * 128 + x).
# ============================================================

# Redraw the background, border, captions, and both hands.
draw_table:
    addiu $sp, $sp, -8
    sw   $ra, 4($sp)

    li   $a0, 0
    li   $a1, 0
    li   $a2, 128
    li   $a3, 128
    li   $t9, 0x00104432         # dark green table
    jal  draw_rectangle

    # Choose the border color from the game's result.
    lw   $t0, game_result
    sll  $t0, $t0, 2
    la   $t1, border_colors
    addu $t0, $t0, $t1
    lw   $t9, 0($t0)

    li   $a0, 0
    li   $a1, 0
    li   $a2, 128
    li   $a3, 2
    jal  draw_rectangle          # top border
    li   $a1, 126
    jal  draw_rectangle          # bottom border
    li   $a0, 0
    li   $a1, 2
    li   $a2, 2
    li   $a3, 124
    jal  draw_rectangle          # left border
    li   $a0, 126
    jal  draw_rectangle          # right border

    li   $a0, 4
    li   $a1, 63
    li   $a2, 120
    li   $a3, 1
    li   $t9, 0x00C5AA68
    jal  draw_rectangle          # divide the two hands

    la   $a0, dealer_caption
    li   $a1, 5
    jal  draw_caption
    la   $a0, player_caption
    li   $a1, 69
    jal  draw_caption

    la   $a0, dealer_hand
    lw   $a1, dealer_count
    li   $a2, 16
    lw   $a3, dealer_hidden
    jal  draw_hand

    la   $a0, player_hand
    lw   $a1, player_count
    li   $a2, 80
    li   $a3, 0
    jal  draw_hand

    lw   $ra, 4($sp)
    addiu $sp, $sp, 8
    jr   $ra

# draw_rectangle($a0=x, $a1=y, $a2=width, $a3=height)
# Extra input: $t9 = RGB color. This routine leaves $t9 and $a0-$a3
# unchanged, allowing the border calls above to reuse arguments.
draw_rectangle:
    blez $a2, rectangle_done
    blez $a3, rectangle_done
    sll  $t0, $a1, 7
    addu $t0, $t0, $a0
    sll  $t0, $t0, 2
    la   $t1, framebuffer
    addu $t0, $t0, $t1
    move $t2, $a3

rectangle_row:
    move $t3, $t0
    move $t4, $a2
rectangle_pixel:
    sw   $t9, 0($t3)
    addiu $t3, $t3, 4
    addiu $t4, $t4, -1
    bnez $t4, rectangle_pixel
    addiu $t0, $t0, 512          # next row: 128 words
    addiu $t2, $t2, -1
    bnez $t2, rectangle_row
rectangle_done:
    jr   $ra

# draw_sprite($a0=x, $a1=y, $a2=sprite index, $a3=color)
# Paints the sprite's set bits; zero bits leave the background.
draw_sprite:
    li   $t0, 14                 # 7 halfwords per sprite
    mul  $t0, $a2, $t0
    la   $t1, rank_sprites
    addu $t0, $t0, $t1
    li   $t1, 0                  # row number

sprite_row:
    lhu  $t2, 0($t0)
    addu $t3, $a1, $t1
    sll  $t3, $t3, 7
    addu $t3, $t3, $a0
    sll  $t3, $t3, 2
    la   $t4, framebuffer
    addu $t3, $t3, $t4
    li   $t5, 1024               # start with bit 10

sprite_pixel:
    and  $t6, $t2, $t5
    beqz $t6, sprite_skip
    sw   $a3, 0($t3)
sprite_skip:
    addiu $t3, $t3, 4
    srl  $t5, $t5, 1
    bnez $t5, sprite_pixel
    addiu $t0, $t0, 2
    addiu $t1, $t1, 1
    blt  $t1, 7, sprite_row
    jr   $ra

# draw_card_sprite($a0=x, $a1=y, $a2=rank)
# Rank 0 draws the patterned blue card back instead of its value.
draw_card_sprite:
    addiu $sp, $sp, -16
    sw   $s0, 0($sp)
    sw   $s1, 4($sp)
    sw   $s2, 8($sp)
    sw   $ra, 12($sp)
    move $s0, $a0
    move $s1, $a1
    move $s2, $a2

    li   $a2, 14
    li   $a3, 20
    li   $t9, 0x000A2018         # card outline
    jal  draw_rectangle

    addiu $a0, $s0, 1
    addiu $a1, $s1, 1
    li   $a2, 12
    li   $a3, 18
    li   $t9, 0x00FFF9E8         # face-up card
    bnez $s2, card_fill
    li   $t9, 0x002C5CA0         # face-down card
card_fill:
    jal  draw_rectangle
    bnez $s2, card_rank

    # Two decorative stripes on the hidden card.
    addiu $a0, $s0, 2
    addiu $a1, $s1, 2
    li   $a2, 10
    li   $a3, 2
    li   $t9, 0x006FA1DC
    jal  draw_rectangle
    addiu $a1, $s1, 16
    jal  draw_rectangle

card_rank:
    addiu $a0, $s0, 2
    addiu $a1, $s1, 6
    move $a2, $s2
    li   $a3, 0x00101820
    bnez $s2, card_draw_rank
    li   $a3, 0x00FFF9E8
card_draw_rank:
    jal  draw_sprite

    lw   $s0, 0($sp)
    lw   $s1, 4($sp)
    lw   $s2, 8($sp)
    lw   $ra, 12($sp)
    addiu $sp, $sp, 16
    jr   $ra

# draw_hand($a0=hand, $a1=count, $a2=starting y, $a3=hide first)
# Seven cards per row. A second row handles unusually long hands.
draw_hand:
    addiu $sp, $sp, -32
    sw   $s0, 0($sp)
    sw   $s1, 4($sp)
    sw   $s2, 8($sp)
    sw   $s3, 12($sp)
    sw   $s4, 16($sp)
    sw   $s5, 20($sp)
    sw   $ra, 28($sp)
    move $s0, $a0
    move $s1, $a1
    move $s2, $a2
    move $s3, $a3
    li   $s4, 0
    li   $s5, 8

draw_hand_loop:
    beq  $s4, $s1, draw_hand_done
    bge  $s4, 14, draw_hand_done  # keep drawing inside two rows
    move $a0, $s5
    move $a1, $s2
    lw   $a2, 0($s0)
    bnez $s4, draw_hand_visible
    beqz $s3, draw_hand_visible
    li   $a2, 0                  # replace hidden rank with back
draw_hand_visible:
    jal  draw_card_sprite
    addiu $s0, $s0, 4
    addiu $s4, $s4, 1
    addiu $s5, $s5, 16
    blt  $s5, 120, draw_hand_loop
    li   $s5, 8
    addiu $s2, $s2, 23
    j    draw_hand_loop

draw_hand_done:
    lw   $s0, 0($sp)
    lw   $s1, 4($sp)
    lw   $s2, 8($sp)
    lw   $s3, 12($sp)
    lw   $s4, 16($sp)
    lw   $s5, 20($sp)
    lw   $ra, 28($sp)
    addiu $sp, $sp, 32
    jr   $ra

# draw_caption($a0=address of six sprite indices, $a1=y)
draw_caption:
    addiu $sp, $sp, -24
    sw   $s0, 0($sp)
    sw   $s1, 4($sp)
    sw   $s2, 8($sp)
    sw   $s3, 12($sp)
    sw   $ra, 20($sp)
    move $s0, $a0
    move $s2, $a1
    li   $s1, 5
    li   $s3, 6

caption_loop:
    move $a0, $s1
    move $a1, $s2
    lbu  $a2, 0($s0)
    li   $a3, 0x00E6D69A
    jal  draw_sprite
    addiu $s0, $s0, 1
    addiu $s1, $s1, 6
    addiu $s3, $s3, -1
    bnez $s3, caption_loop

    lw   $s0, 0($sp)
    lw   $s1, 4($sp)
    lw   $s2, 8($sp)
    lw   $s3, 12($sp)
    lw   $ra, 20($sp)
    addiu $sp, $sp, 24
    jr   $ra
#print a message saying start the game 
#deal two cards to the dealer and then two cards to the player 
#check if  either player has 21
#if they do, end the game otherwise keep playing 
#ask the player if they want to hit or stay 
#if hit, they get a new card, and then check if they have over 21 
	#if so end the game 
	#if not then ask them to hit or stay again
#if stay then play passes to dealer

#check if dealer has over 16
#if not they hit 
	#check if they have over 21
		#if yes the game ends
		#if not check if they have over 16 and repeat
#if so they stay

#after both players have stayed check their scores
#if dealer - player >= 0, the player loses game 
#if not then player wins the game

#end program



