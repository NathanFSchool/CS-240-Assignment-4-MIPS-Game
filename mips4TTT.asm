.data

choose:       .asciiz "Select a square from 1-9: "
wrong:        .asciiz "That square is already full.\n"
invalidmsg:   .asciiz "Invalid choice. Enter a number from 1 to 9.\n"
board_title:  .asciiz "Current Board:\n"
winmsg:       .asciiz "Player wins!\n"
drawmsg:      .asciiz "The game ends in a draw!\n"
newline:	.asciiz "\n"

boardbuf:     .space 32

# x/y offsets for the 12 colored units that form an O
o_points:     .word 2,1, 3,1, 4,1, 1,2, 5,2, 1,3, 5,3, 1,4, 5,4, 2,5, 3,5, 4,5

# 3x5 bitmap patterns for digits 1 through 9.
# Each row uses 3 bits: 4 = left, 2 = middle, 1 = right.
digit_font:   .byte 2,6,2,2,7
              .byte 7,1,7,4,7
              .byte 7,1,7,1,7
              .byte 5,5,7,1,1
              .byte 7,4,7,1,7
              .byte 7,4,7,5,7
              .byte 7,1,2,2,2
              .byte 7,5,7,5,7
              .byte 7,5,7,1,7


.text
.globl main

main:
   # $s0 stores the current player: 1 = X, 2 = O
   li $s0, 1

   # Initialize all nine squares to 0
   li $t1, 0
   li $t2, 0
   li $t3, 0
   li $t4, 0
   li $t5, 0
   li $t6, 0
   li $t7, 0
   li $t8, 0
   li $t9, 0

   # Create and display the initial board
   jal make_board
   jal show_board
   jal draw_bitmap

   j words


words:
   # Print the prompt in Run I/O
   li $v0, 4
   la $a0, choose
   syscall

   # Read an integer from Run I/O
   li $v0, 5
   syscall
   move $a0, $v0

   j square


square:
   beq $a0, 1, one
   beq $a0, 2, two
   beq $a0, 3, three
   beq $a0, 4, four
   beq $a0, 5, five
   beq $a0, 6, six
   beq $a0, 7, seven
   beq $a0, 8, eight
   beq $a0, 9, nine

   # Invalid number
   li $v0, 4
   la $a0, invalidmsg
   syscall
   j words


one:
   bgt $t1, $zero, retry
   move $t1, $s0
   j placed

two:
   bgt $t2, $zero, retry
   move $t2, $s0
   j placed

three:
   bgt $t3, $zero, retry
   move $t3, $s0
   j placed

four:
   bgt $t4, $zero, retry
   move $t4, $s0
   j placed

five:
   bgt $t5, $zero, retry
   move $t5, $s0
   j placed

six:
   bgt $t6, $zero, retry
   move $t6, $s0
   j placed

seven:
   bgt $t7, $zero, retry
   move $t7, $s0
   j placed

eight:
   bgt $t8, $zero, retry
   move $t8, $s0
   j placed

nine:
   bgt $t9, $zero, retry
   move $t9, $s0
   j placed


retry:
   # Print the occupied-square message in Run I/O
   li $v0, 4
   la $a0, wrong
   syscall
   j words


# A move was successfully placed
placed:
   # Rebuild and display the text board
   jal make_board
   jal show_board

   # Redraw the bitmap board
   jal draw_bitmap

   # Check whether someone won
   jal check_win

   # check_win returns 1 in $v0 if someone won
   bnez $v0, won

   # If there is no winner and all nine squares are filled, the game is a draw
   jal check_full
   bnez $v0, draw

   # Change to the other player
   jal swap
   j words


# Switch players
swap:
   beq $s0, 1, change_to_o

   # Player 2 changes to player 1
   li $s0, 1
   jr $ra

change_to_o:
   li $s0, 2
   jr $ra


# Checks all eight possible winning combinations
# Returns $v0 = 1 if there is a winner, otherwise $v0 = 0
check_win:
   # Save return address because this routine calls check_line
   addiu $sp, $sp, -4
   sw $ra, 0($sp)

   # Top row: squares 1, 2, 3
   move $a0, $t1
   move $a1, $t2
   move $a2, $t3
   jal check_line
   bnez $v0, win_found

   # Middle row: squares 4, 5, 6
   move $a0, $t4
   move $a1, $t5
   move $a2, $t6
   jal check_line
   bnez $v0, win_found

   # Bottom row: squares 7, 8, 9
   move $a0, $t7
   move $a1, $t8
   move $a2, $t9
   jal check_line
   bnez $v0, win_found

   # Left column: squares 1, 4, 7
   move $a0, $t1
   move $a1, $t4
   move $a2, $t7
   jal check_line
   bnez $v0, win_found

   # Middle column: squares 2, 5, 8
   move $a0, $t2
   move $a1, $t5
   move $a2, $t8
   jal check_line
   bnez $v0, win_found

   # Right column: squares 3, 6, 9
   move $a0, $t3
   move $a1, $t6
   move $a2, $t9
   jal check_line
   bnez $v0, win_found

   # Diagonal: squares 1, 5, 9
   move $a0, $t1
   move $a1, $t5
   move $a2, $t9
   jal check_line
   bnez $v0, win_found

   # Diagonal: squares 3, 5, 7
   move $a0, $t3
   move $a1, $t5
   move $a2, $t7
   jal check_line
   bnez $v0, win_found

   # No winner
   li $v0, 0
   lw $ra, 0($sp)
   addiu $sp, $sp, 4
   jr $ra

win_found:
   li $v0, 1
   lw $ra, 0($sp)
   addiu $sp, $sp, 4
   jr $ra


# Checks whether three values are equal and nonzero
check_line:
   # Three empty squares do not count as a win
   beq $a0, $zero, no_line

   # First and second squares must match
   bne $a0, $a1, no_line

   # First and third squares must match
   bne $a0, $a2, no_line

   # Winning line found
   li $v0, 1
   jr $ra

no_line:
   li $v0, 0
   jr $ra


# Checks whether all nine squares are occupied
# Returns $v0 = 1 if the board is full, otherwise $v0 = 0
check_full:
   beq $t1, $zero, board_not_full
   beq $t2, $zero, board_not_full
   beq $t3, $zero, board_not_full
   beq $t4, $zero, board_not_full
   beq $t5, $zero, board_not_full
   beq $t6, $zero, board_not_full
   beq $t7, $zero, board_not_full
   beq $t8, $zero, board_not_full
   beq $t9, $zero, board_not_full

   li $v0, 1
   jr $ra

board_not_full:
   li $v0, 0
   jr $ra


# Converts the board values into a text string
make_board:
   addiu $sp, $sp, -4
   sw $ra, 0($sp)

   la $t0, boardbuf

   # Row 1: squares 1, 2, 3
   move $a0, $t1
   jal square_character
   sb $v0, 0($t0)

   li $v0, 124
   sb $v0, 1($t0)

   move $a0, $t2
   jal square_character
   sb $v0, 2($t0)

   li $v0, 124
   sb $v0, 3($t0)

   move $a0, $t3
   jal square_character
   sb $v0, 4($t0)

   li $v0, 10
   sb $v0, 5($t0)

   # Row 2: squares 4, 5, 6
   move $a0, $t4
   jal square_character
   sb $v0, 6($t0)

   li $v0, 124
   sb $v0, 7($t0)

   move $a0, $t5
   jal square_character
   sb $v0, 8($t0)

   li $v0, 124
   sb $v0, 9($t0)

   move $a0, $t6
   jal square_character
   sb $v0, 10($t0)

   li $v0, 10
   sb $v0, 11($t0)

   # Row 3: squares 7, 8, 9
   move $a0, $t7
   jal square_character
   sb $v0, 12($t0)

   li $v0, 124
   sb $v0, 13($t0)

   move $a0, $t8
   jal square_character
   sb $v0, 14($t0)

   li $v0, 124
   sb $v0, 15($t0)

   move $a0, $t9
   jal square_character
   sb $v0, 16($t0)

   # Null terminator
   li $v0, 0
   sb $v0, 17($t0)

   lw $ra, 0($sp)
   addiu $sp, $sp, 4
   jr $ra


# Converts a square value into an ASCII character
# 0 = ~, 1 = X, 2 = O
square_character:
   beq $a0, 0, character_empty
   beq $a0, 1, character_x
   beq $a0, 2, character_o

   # Default to empty
   li $v0, 126
   jr $ra

character_empty:
   li $v0, 126
   jr $ra

character_x:
   li $v0, 88
   jr $ra

character_o:
   li $v0, 79
   jr $ra


# Prints the text board in Run I/O
show_board:
   li $v0, 4
   la $a0, board_title
   syscall

   li $v0, 4
   la $a0, boardbuf
   syscall

   # Print a blank line after each board state
   li $v0, 4
   la $a0, newline
   syscall

   jr $ra


# Draws the board to the MARS Bitmap Display.
# Assumes a 32x32 grid of display units and uses $gp as the base.
# Saves $t0-$t9 because the board state is stored in $t1-$t9.
draw_bitmap:
   addiu $sp, $sp, -48
   sw $t0, 0($sp)
   sw $t1, 4($sp)
   sw $t2, 8($sp)
   sw $t3, 12($sp)
   sw $t4, 16($sp)
   sw $t5, 20($sp)
   sw $t6, 24($sp)
   sw $t7, 28($sp)
   sw $t8, 32($sp)
   sw $t9, 36($sp)
   sw $ra, 40($sp)

   # Fill all 32x32 units with a light background color.
   move $t0, $gp
   li   $t1, 1024
   li   $t2, 0x00F4F4F4

bitmap_clear_loop:
   sw   $t2, 0($t0)
   addiu $t0, $t0, 4
   addiu $t1, $t1, -1
   bnez $t1, bitmap_clear_loop

   # Draw vertical grid lines at x = 11 and x = 19.
   li   $t0, 4

bitmap_vertical_loop:
   sll  $t1, $t0, 7
   addiu $t1, $t1, 44
   addu $t1, $t1, $gp
   li   $t2, 0x00202020
   sw   $t2, 0($t1)
   addiu $t1, $t1, 32
   sw   $t2, 0($t1)

   addiu $t0, $t0, 1
   slti $t3, $t0, 27
   bnez $t3, bitmap_vertical_loop

   # Draw horizontal grid lines at y = 11 and y = 19.
   li   $t0, 4
   li   $t4, 11
   sll  $t4, $t4, 7

bitmap_horizontal_loop:
   sll  $t1, $t0, 2
   addu $t1, $t1, $t4
   addu $t1, $t1, $gp
   li   $t2, 0x00202020
   sw   $t2, 0($t1)
   addiu $t1, $t1, 1024
   sw   $t2, 0($t1)

   addiu $t0, $t0, 1
   slti $t3, $t0, 27
   bnez $t3, bitmap_horizontal_loop

   # Draw each square. Empty squares display their number.
   # Cell positions are x/y = 4, 12, or 20.

   lw   $a0, 4($sp)
   li   $a1, 4
   li   $a2, 4
   li   $a3, 1
   jal  draw_symbol

   lw   $a0, 8($sp)
   li   $a1, 12
   li   $a2, 4
   li   $a3, 2
   jal  draw_symbol

   lw   $a0, 12($sp)
   li   $a1, 20
   li   $a2, 4
   li   $a3, 3
   jal  draw_symbol

   lw   $a0, 16($sp)
   li   $a1, 4
   li   $a2, 12
   li   $a3, 4
   jal  draw_symbol

   lw   $a0, 20($sp)
   li   $a1, 12
   li   $a2, 12
   li   $a3, 5
   jal  draw_symbol

   lw   $a0, 24($sp)
   li   $a1, 20
   li   $a2, 12
   li   $a3, 6
   jal  draw_symbol

   lw   $a0, 28($sp)
   li   $a1, 4
   li   $a2, 20
   li   $a3, 7
   jal  draw_symbol

   lw   $a0, 32($sp)
   li   $a1, 12
   li   $a2, 20
   li   $a3, 8
   jal  draw_symbol

   lw   $a0, 36($sp)
   li   $a1, 20
   li   $a2, 20
   li   $a3, 9
   jal  draw_symbol

   # Restore registers, including the board values in $t1-$t9.
   lw   $ra, 40($sp)
   lw   $t9, 36($sp)
   lw   $t8, 32($sp)
   lw   $t7, 28($sp)
   lw   $t6, 24($sp)
   lw   $t5, 20($sp)
   lw   $t4, 16($sp)
   lw   $t3, 12($sp)
   lw   $t2, 8($sp)
   lw   $t1, 4($sp)
   lw   $t0, 0($sp)
   addiu $sp, $sp, 48
   jr   $ra


# Draws an X, O, or the number for an empty square.
# $a0 = square value; $a1/$a2 = cell position; $a3 = square index
draw_symbol:
   beq  $a0, $zero, draw_empty_index

   li   $t0, 1
   beq  $a0, $t0, draw_x

   li   $t0, 2
   beq  $a0, $t0, draw_o

   jr   $ra

draw_empty_index:
   move $a0, $a3
   j draw_digit


# Draw an X using two diagonal strokes.
draw_x:
   li   $t2, 0x00005AA8

   # First diagonal starts at (x+1, y+1)
   addiu $t3, $a1, 1
   addiu $t4, $a2, 1
   sll  $t4, $t4, 7
   sll  $t3, $t3, 2
   addu $t5, $gp, $t4
   addu $t5, $t5, $t3

   # Second diagonal starts at (x+5, y+1)
   addiu $t3, $a1, 5
   sll  $t3, $t3, 2
   addu $t6, $gp, $t4
   addu $t6, $t6, $t3

   li   $t7, 0

draw_x_loop:
   sw   $t2, 0($t5)
   sw   $t2, 0($t6)

   addiu $t5, $t5, 132
   addiu $t6, $t6, 124

   addiu $t7, $t7, 1
   slti $t8, $t7, 5
   bnez $t8, draw_x_loop

   jr   $ra


# Draw an O using a small ring of colored units.
draw_o:
   la   $t0, o_points
   li   $t1, 12
   move $t2, $a1
   move $t3, $a2
   li   $t4, 0x00D1495B

draw_o_loop:
   lw   $t5, 0($t0)
   lw   $t6, 4($t0)

   addu $t5, $t5, $t2
   addu $t6, $t6, $t3
   sll  $t6, $t6, 7
   sll  $t5, $t5, 2
   addu $t7, $gp, $t6
   addu $t7, $t7, $t5

   sw   $t4, 0($t7)

   addiu $t0, $t0, 8
   addiu $t1, $t1, -1
   bnez $t1, draw_o_loop

   jr   $ra


# Draws a 3x5 digit in an empty square.
# $a0 = digit, $a1 = cell x, $a2 = cell y
draw_digit:
   # Find the first byte for this digit: (digit - 1) * 5
   addiu $t1, $a0, -1
   sll  $t2, $t1, 2
   addu $t2, $t2, $t1

   la   $t0, digit_font
   addu $t0, $t0, $t2

   # Center the 3x5 digit in the 7x7 cell.
   addiu $t3, $a1, 2
   addiu $t4, $a2, 1

   li   $t9, 0
   li   $a0, 0x00607080

digit_row_loop:
   lbu  $t5, 0($t0)
   li   $t6, 4
   li   $t7, 0

   # Start address for this row of the digit.
   addu $t2, $t4, $t9
   sll  $t2, $t2, 7
   addu $t2, $t2, $gp

digit_column_loop:
   and  $t8, $t5, $t6
   beq  $t8, $zero, digit_skip_pixel

   # Write a colored unit for each set bit.
   addu $t8, $t3, $t7
   sll  $t8, $t8, 2
   addu $t8, $t8, $t2
   sw   $a0, 0($t8)

digit_skip_pixel:
   srl  $t6, $t6, 1
   addiu $t7, $t7, 1
   slti $t8, $t7, 3
   bnez $t8, digit_column_loop

   addiu $t0, $t0, 1
   addiu $t9, $t9, 1
   slti $t8, $t9, 5
   bnez $t8, digit_row_loop

   jr   $ra


won:
   # Print the winning message in Run I/O
   li $v0, 4
   la $a0, winmsg
   syscall
   j end


draw:
   # Print the draw message in Run I/O
   li $v0, 4
   la $a0, drawmsg
   syscall
   j end


end:
   li $v0, 10
   syscall