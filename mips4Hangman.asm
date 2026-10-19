# Two-player Hangman for MARS 4.5 -- Bitmap Display + Run I/O.
# Bitmap: unit width/height 4, display width/height 512,
# base address 0x10010000 (static data). Connect BEFORE running.
# Leave Settings > Delayed branching OFF.
# Player 1 enters one word of 1-20 letters.
# Player 2 guesses one letter at a time and has 6 lives.
# Blank lines move the secret out of view, but do not erase it.

.data 0x10010000
# 128 x 128 logical pixels, 4 bytes each.
# Keep this buffer FIRST so drawing does not overwrite game data.
framebuffer:      .space 65536

word_length:      .word 0
letters_hidden:   .word 0
lives:            .word 6
guess_count:      .word 0

# Character arrays: one byte per character.
# Strings need one extra byte for the null terminator.
secret_word:      .space 21
displayed_word:   .space 21
guessed_flags:    .space 26       # one flag for each letter a-z
guessed_letters:  .space 27       # guess order, plus null terminator
input_buffer:     .space 128

welcome:          .asciiz "Welcome to Hangman!\nPlayer 2: look away while Player 1 enters the word.\n\n"
word_prompt:      .asciiz "Player 1, enter one word (1-20 letters): "
bad_word_msg:     .asciiz "Enter 1-20 letters only. No spaces, numbers, or punctuation.\n\n"
player2_msg:      .asciiz "Player 2, guess the word!\nYou have 6 lives. Enter one letter per guess.\nInvalid input and repeated guesses do not cost lives.\n\n"
word_label:       .asciiz "Word: "
lives_label:      .asciiz "\nLives: "
guessed_label:    .asciiz "\nGuessed letters: "
none_msg:         .asciiz "(none)"
guess_prompt:     .asciiz "Enter a letter: "
bad_guess_msg:    .asciiz "Invalid input. Enter exactly one letter from a-z.\n"
repeat_msg:       .asciiz "You already guessed that letter. Try another one.\n"
correct_msg:      .asciiz "Correct!\n\n"
wrong_msg:        .asciiz "That letter is not in the word. You lose one life.\n\n"
win_msg:          .asciiz "You revealed the word! Player 2 wins!\n"
lose_msg:         .asciiz "No lives remaining! Player 1 wins!\nThe word was: "
newline:          .asciiz "\n"
blank_line:       .asciiz "\n\n"

# A 16 x 16 head sprite. Each word stores one row's 16 bits.
# Set bits draw the outline; zero bits leave the background.
.align 2
head_sprite:
    .word 0x03C0, 0x0FF0, 0x1C38, 0x300C
    .word 0x6006, 0xC003, 0xC003, 0xC003
    .word 0xC003, 0xC003, 0xC003, 0x6006
    .word 0x300C, 0x1C38, 0x0FF0, 0x03C0

.text
.globl main

main:
    la   $a0, welcome
    jal  print_string
    jal  draw_hangman             # initial display: gallows only

ask_for_word:
    la   $a0, word_prompt
    jal  print_string
    jal  read_word
    beqz $v0, invalid_word

    # read_word returns the validated word's length.
    move $a0, $v0
    jal  initialize_game
    jal  separate_players

    la   $a0, player2_msg
    jal  print_string

game_loop:
    jal  print_state

ask_for_guess:
    la   $a0, guess_prompt
    jal  print_string
    jal  read_guess
    beqz $v0, invalid_guess

    move $a0, $v0
    jal  process_guess

    # process_guess returns -1 = repeated, 0 = wrong, 1 = correct.
    beq  $v0, -1, repeated_guess
    beqz $v0, incorrect_guess

    la   $a0, correct_msg
    jal  print_string
    lw   $t0, letters_hidden
    beqz $t0, player2_wins
    j    game_loop

incorrect_guess:
    la   $a0, wrong_msg
    jal  print_string
    jal  draw_hangman             # add the next body part
    lw   $t0, lives
    beqz $t0, player1_wins
    j    game_loop

invalid_word:
    la   $a0, bad_word_msg
    jal  print_string
    j    ask_for_word

invalid_guess:
    la   $a0, bad_guess_msg
    jal  print_string
    j    ask_for_guess

repeated_guess:
    la   $a0, repeat_msg
    jal  print_string
    j    ask_for_guess

player2_wins:
    jal  print_state
    la   $a0, win_msg
    jal  print_string
    j    exit_program

player1_wins:
    jal  print_state
    la   $a0, lose_msg
    jal  print_string
    la   $a0, secret_word
    jal  print_string
    la   $a0, newline
    jal  print_string

exit_program:
    li   $v0, 10
    syscall

# ------------------------------------------------------------
# normalize_letter($a0 = character)
# Returns a lowercase letter in $v0, or 0 if it is not a letter.
# ------------------------------------------------------------
normalize_letter:
    move $v0, $a0
    blt  $v0, 65, letter_check_lowercase
    bgt  $v0, 90, letter_check_lowercase
    addiu $v0, $v0, 32           # uppercase A-Z -> lowercase a-z

letter_check_lowercase:
    blt  $v0, 97, letter_invalid
    bgt  $v0, 122, letter_invalid
    jr   $ra

letter_invalid:
    li   $v0, 0
    jr   $ra

# read_word
# Reads into input_buffer, validates 1-20 letters, converts to
# lowercase, and removes the newline. Returns length or 0.
read_word:
    addiu $sp, $sp, -16
    sw   $s0, 0($sp)
    sw   $s1, 4($sp)
    sw   $ra, 12($sp)

    li   $v0, 8
    la   $a0, input_buffer
    li   $a1, 128
    syscall
    la   $s0, input_buffer
    li   $s1, 0

word_scan:
    lbu  $a0, 0($s0)
    beqz $a0, word_scan_done
    beq  $a0, 10, word_scan_done
    bge  $s1, 20, word_rejected

    jal  normalize_letter
    beqz $v0, word_rejected
    sb   $v0, 0($s0)
    addiu $s0, $s0, 1
    addiu $s1, $s1, 1
    j    word_scan

word_scan_done:
    beqz $s1, word_rejected
    sb   $zero, 0($s0)
    move $v0, $s1
    j    word_return

word_rejected:
    li   $v0, 0

word_return:
    lw   $s0, 0($sp)
    lw   $s1, 4($sp)
    lw   $ra, 12($sp)
    addiu $sp, $sp, 16
    jr   $ra

# initialize_game($a0 = validated word length)
# Copies the word into secret_word, builds matching dashes,
# and resets the lives and guessed-letter arrays.
initialize_game:
    sw   $a0, word_length
    sw   $a0, letters_hidden
    la   $t0, input_buffer
    la   $t1, secret_word
    la   $t2, displayed_word
    li   $t3, 0

initialize_word_loop:
    beq  $t3, $a0, initialize_word_done
    lbu  $t4, 0($t0)
    sb   $t4, 0($t1)
    li   $t4, 45                 # ASCII '-'
    sb   $t4, 0($t2)
    addiu $t0, $t0, 1
    addiu $t1, $t1, 1
    addiu $t2, $t2, 1
    addiu $t3, $t3, 1
    j    initialize_word_loop

initialize_word_done:
    sb   $zero, 0($t1)
    sb   $zero, 0($t2)
    la   $t0, guessed_flags
    li   $t1, 26

initialize_flags:
    sb   $zero, 0($t0)
    addiu $t0, $t0, 1
    addiu $t1, $t1, -1
    bnez $t1, initialize_flags

    la   $t0, guessed_letters
    sb   $zero, 0($t0)
    sw   $zero, guess_count
    li   $t0, 6
    sw   $t0, lives
    jr   $ra

# read_guess
# Reads a line and accepts exactly one letter followed by Enter.
# Returns the lowercase letter in $v0, or 0 for invalid input.
read_guess:
    addiu $sp, $sp, -8
    sw   $ra, 4($sp)
    li   $v0, 8
    la   $a0, input_buffer
    li   $a1, 128
    syscall

    lbu  $t0, 1($a0)
    beqz $t0, guess_check_letter
    bne  $t0, 10, guess_rejected

guess_check_letter:
    lbu  $a0, 0($a0)
    jal  normalize_letter
    j    guess_return

guess_rejected:
    li   $v0, 0

guess_return:
    lw   $ra, 4($sp)
    addiu $sp, $sp, 8
    jr   $ra

# process_guess($a0 = lowercase letter)
# Returns -1 for a repeat, 0 for a miss, or 1 for a match.
# Every matching position is revealed. Only a new miss costs a life.
process_guess:
    addiu $t0, $a0, -97          # a=0, b=1, ... z=25
    la   $t1, guessed_flags
    addu $t1, $t1, $t0
    lbu  $t2, 0($t1)
    bnez $t2, process_repeat
    li   $t2, 1
    sb   $t2, 0($t1)

    # Record this letter in the order it was guessed.
    lw   $t0, guess_count
    la   $t1, guessed_letters
    addu $t1, $t1, $t0
    sb   $a0, 0($t1)
    sb   $zero, 1($t1)
    addiu $t0, $t0, 1
    sw   $t0, guess_count

    la   $t0, secret_word
    la   $t1, displayed_word
    lw   $t2, word_length
    li   $t3, 0                  # position
    li   $t4, 0                  # number of matches

process_scan:
    beq  $t3, $t2, process_scan_done
    lbu  $t5, 0($t0)
    bne  $t5, $a0, process_next
    sb   $a0, 0($t1)
    addiu $t4, $t4, 1

process_next:
    addiu $t0, $t0, 1
    addiu $t1, $t1, 1
    addiu $t3, $t3, 1
    j    process_scan

process_scan_done:
    beqz $t4, process_miss
    lw   $t0, letters_hidden
    subu $t0, $t0, $t4
    sw   $t0, letters_hidden
    li   $v0, 1
    jr   $ra

process_miss:
    lw   $t0, lives
    addiu $t0, $t0, -1
    sw   $t0, lives
    li   $v0, 0
    jr   $ra

process_repeat:
    li   $v0, -1
    jr   $ra

# Print the displayed word, remaining lives, and previous guesses.
print_state:
    addiu $sp, $sp, -8
    sw   $ra, 4($sp)
    la   $a0, word_label
    jal  print_string
    la   $a0, displayed_word
    jal  print_string
    la   $a0, lives_label
    jal  print_string
    lw   $a0, lives
    li   $v0, 1
    syscall

    la   $a0, guessed_label
    jal  print_string
    lw   $t1, guess_count
    beqz $t1, print_no_guesses
    la   $t0, guessed_letters

print_guesses_loop:
    lbu  $a0, 0($t0)
    li   $v0, 11
    syscall
    li   $a0, 32                 # space between guessed letters
    li   $v0, 11
    syscall
    addiu $t0, $t0, 1
    addiu $t1, $t1, -1
    bnez $t1, print_guesses_loop
    j    print_state_done

print_no_guesses:
    la   $a0, none_msg
    jal  print_string

print_state_done:
    la   $a0, blank_line
    jal  print_string
    lw   $ra, 4($sp)
    addiu $sp, $sp, 8
    jr   $ra

# Move Player 1's entry out of view before Player 2's turn.
# This is visual separation, not secure password-style input.
separate_players:
    li   $t0, 50
    li   $v0, 11
    li   $a0, 10

separate_loop:
    syscall
    addiu $t0, $t0, -1
    bnez $t0, separate_loop
    jr   $ra

print_string:
    li   $v0, 4
    syscall
    jr   $ra

# ============================================================
# BITMAP GRAPHICS
# Coordinates use a 128 x 128 logical grid.
# With 4 x 4 units, the display is 512 x 512 screen pixels.
# Pixel address = framebuffer + 4 * (y * 128 + x).
# ============================================================

# Redraw the gallows and body parts for the incorrect guesses.
# 1=head, 2=torso, 3=left arm, 4=right arm, 5=left leg, 6=right leg.
draw_hangman:
    addiu $sp, $sp, -8
    sw   $s0, 0($sp)
    sw   $ra, 4($sp)

    # Clear the display.
    li   $a0, 0
    li   $a1, 0
    li   $a2, 128
    li   $a3, 128
    li   $t9, 0x00182330          # dark blue background
    jal  draw_rectangle

    # Gallows base.
    li   $a0, 12
    li   $a1, 116
    li   $a2, 104
    li   $a3, 4
    li   $t9, 0x00C69C6D          # wood color
    jal  draw_rectangle

    # Upright pole.
    li   $a0, 26
    li   $a1, 10
    li   $a2, 4
    li   $a3, 106
    jal  draw_rectangle

    # Top beam. draw_rectangle preserves its argument registers.
    li   $a2, 60
    li   $a3, 4
    jal  draw_rectangle

    # Diagonal support between the pole and beam.
    li   $a0, 45
    li   $a1, 14
    li   $a2, 17
    li   $a3, -1
    jal  draw_diagonal

    # Rope from the beam to the head.
    li   $a0, 82
    li   $a1, 14
    li   $a2, 2
    li   $a3, 10
    li   $t9, 0x00C8B79F
    jal  draw_rectangle

    # Number of incorrect guesses = 6 - lives.
    lw   $s0, lives
    li   $t0, 6
    subu $s0, $t0, $s0
    blez $s0, drawing_done

    # First incorrect guess: head.
    li   $t9, 0x00EEEDE8          # stick figure color
    jal  draw_head
    ble  $s0, 1, drawing_done

    # Second: torso.
    li   $a0, 82
    li   $a1, 40
    li   $a2, 2
    li   $a3, 32
    jal  draw_rectangle
    ble  $s0, 2, drawing_done

    # Third: left arm.
    li   $a0, 82
    li   $a1, 48
    li   $a2, 20
    li   $a3, -1
    jal  draw_diagonal
    ble  $s0, 3, drawing_done

    # Fourth: right arm.
    li   $a3, 1
    jal  draw_diagonal
    ble  $s0, 4, drawing_done

    # Fifth: left leg.
    li   $a0, 82
    li   $a1, 71
    li   $a2, 24
    li   $a3, -1
    jal  draw_diagonal
    ble  $s0, 5, drawing_done

    # Sixth: right leg. The figure is now complete.
    li   $a3, 1
    jal  draw_diagonal

drawing_done:
    lw   $s0, 0($sp)
    lw   $ra, 4($sp)
    addiu $sp, $sp, 8
    jr   $ra

# draw_rectangle($a0=x, $a1=y, $a2=width, $a3=height)
# Extra input: $t9 = RGB color.
# Preserves $a0-$a3 and $t9 so callers can reuse their arguments.
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
    addiu $t0, $t0, 512           # next row: 128 words
    addiu $t2, $t2, -1
    bnez $t2, rectangle_row

rectangle_done:
    jr   $ra

# draw_diagonal($a0=x, $a1=y, $a2=length, $a3=direction)
# Direction -1 goes down-left; +1 goes down-right.
# Extra input: $t9 = color. The line is two pixels thick.
# Preserves $a0-$a3 and $t9.
draw_diagonal:
    blez $a2, diagonal_done
    sll  $t0, $a1, 7
    addu $t0, $t0, $a0
    sll  $t0, $t0, 2
    la   $t1, framebuffer
    addu $t0, $t0, $t1
    addiu $t1, $a3, 128
    sll  $t1, $t1, 2             # advance one row and one column
    move $t2, $a2

diagonal_pixel:
    sw   $t9, 0($t0)
    sw   $t9, 4($t0)
    addu $t0, $t0, $t1
    addiu $t2, $t2, -1
    bnez $t2, diagonal_pixel

diagonal_done:
    jr   $ra

# Draw the 16 x 16 head sprite at logical position (75, 24).
# Extra input: $t9 = color, preserved for the remaining body parts.
draw_head:
    la   $t0, head_sprite
    la   $t1, framebuffer
    addiu $t1, $t1, 12588         # 4 * (24 * 128 + 75)
    li   $t2, 16

head_row:
    lw   $t3, 0($t0)
    move $t4, $t1
    li   $t5, 0x8000             # leftmost of the 16 sprite bits

head_pixel:
    and  $t6, $t3, $t5
    beqz $t6, head_skip_pixel
    sw   $t9, 0($t4)

head_skip_pixel:
    addiu $t4, $t4, 4
    srl  $t5, $t5, 1
    bnez $t5, head_pixel
    addiu $t0, $t0, 4
    addiu $t1, $t1, 512
    addiu $t2, $t2, -1
    bnez $t2, head_row
    jr   $ra

