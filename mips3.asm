.data
  isEmpty:   .asciiz "Input is empty."
  isInvalid: .asciiz "Invalid base-35 number."
  tooLong:    .asciiz "Input is too long."
  userInput:    .space  512

.text

j main

empty_input:
  la $a0, isEmpty
  li $v0, 4
  syscall
  j exit

invalid_input:
  la $a0, isInvalid
  li $v0, 4
  syscall
  j exit

long_input:
  la $a0, tooLong
  li $v0, 4
  syscall
  j exit

main:
  li $v0, 8
  la $a0, userInput
  li $a1, 100
  syscall

del_left_pad:
  li $t8, 32 # space
  lb $t9, 0($a0)
  beq $t8, $t9, del_first_char
  move $t9, $a0
  j input_len

del_first_char:
  addi $a0, $a0, 1
  j del_left_pad

input_len:
  addi $t0, $t0, 0    # length
  addi $t1, $t1, 10   # newline
  add $t4, $0, $a0    #store string start address
  #t4 used before init

len_iteration:
  lb $t2, 0($a0)    #load curr byte
  beqz $t2, after_len_found
  beq $t2, $t1, after_len_found
  addi $a0, $a0, 1
  addi $t0, $t0, 1
  j len_iteration

after_len_found:
  beqz $t0, empty_input
  slti $t3, $t0, 5
  beqz $t3, long_input
  move $a0, $t4
  j check_validity

check_validity:
  lb $t5, 0($a0)
  beqz $t5, prepare_for_conversion
  beq $t5, $t1, prepare_for_conversion
  slti $t6, $t5, 48                 # if char < ascii(48),  input invalid,   ascii(48) = 0
  bne $t6, $zero, invalid_input
  slti $t6, $t5, 58                 # if char < ascii(58),  input is valid,  ascii(58) = 9
  bne $t6, $zero, step_char_forward
  slti $t6, $t5, 65                 # if char < ascii(65),  input invalid,   ascii(97) = A
  bne $t6, $zero, invalid_input
  slti $t6, $t5, 89                 # if char < ascii(88),  input is valid,  ascii(89) = Y
  bne $t6, $zero, step_char_forward
  slti $t6, $t5, 97                 # if char < ascii(97),  input invalid,   ascii(97) = a
  bne $t6, $zero, invalid_input
  slti $t6, $t5, 122                # if char < ascii(122), input is valid, ascii(122) = z
  bne $t6, $zero, step_char_forward
  bgt $t5, 121, invalid_input   # if char > ascii(121), input invalid,  ascii(121) = y

step_char_forward:
  addi $a0, $a0, 1
  j check_validity

prepare_for_conversion:
  move $a0, $t4
  addi $t7, $t7, 0
  add $s0, $s0, $t0
  addi $s0, $s0, -1	
  li $s3, 3
  li $s2, 2
  li $s1, 1
  li $s5, 0


  move $a1, $t0
  addi $sp, $sp, -8
  sw $a0, 0($sp)
  sw $a1, 4($sp)
  jal convert_func

  #now we just have to print the returned value.
  lw $t0, 0($sp)
  addi $sp, $sp, 4
  move $a0, $t0
  li $v0, 1
  syscall
  
  li $v0, 10  #exit syscall  (we can't do jr $ra here since $ra was overwritten when we called the subprogram)
  syscall
  

convert_func:  #arguments: $a0 = arr addr, $a1 = length of arr
	lw $a0, 0($sp)
  lw $a1, 4($sp)
  addi $sp, $sp, 8 #deallocating the space

  addi $sp, $sp -16
  sw $ra, 0($sp)
  sw $s0, 4($sp)  #used to store the place value of the current digit
  sw $s1, 8($sp)		#used to hold the arr addr
  sw $s2, 12($sp)	#used to store the length of the arr

  move $s1, $a0 #moves arr addr to $s1
  beq $a1, $0, return0 #base case
  addi $s2, $a1, -1 # moves decremented length into $s2

  
  addi $a0, $0, 35 #base = 35
  addi $a1, $a1, -1 #length = length -1
  jal pow
  lb $t1, 0($s1)
  
  slti $t6, $s4, 58
  bne $t6, $zero, base_ten_conv
  slti $t6, $s4, 88
  bne $t6, $zero, base_35_upper_conv
  slti $t6, $s4, 122
  bne $t6, $zero, base_35_lower_conv

base_ten_conv:
  addi $t1, $t1, -48
  j serialize_result

base_35_upper_conv:
  addi $t1, $t1, -54
  j serialize_result

base_35_lower_conv:
  addi $t1, $t1, -87

serialize_result:

  mul $s0, $v0, $t1 #value = digit * pow_result
  addi $s1, $s1, 1 # string address= string address + 1

  move $a0, $s1
  move $a1, $s2
  addi $sp, $sp, -8
  sw $a0, 0($sp)
  sw $a1, 4($sp)
  jal convert_func
  lw $v0, 0($sp) #retreive return value
  addi $sp, $sp, 4 # deallocate space
  add $v0, $s0, $v0 #returns place value of curr digit + the conversion value from the rest of the number
  lw $ra, 0($sp)
  lw $s0,  4($sp)
  lw $s1,  8($sp)
  lw $s2,  12($sp)
  addi $sp, $sp, 16
  addi $sp, $sp, -4
  sw $v0, 0($sp) #puts return value on stack
  jr $ra
	
return0:
  move $v0, $0	 #we need to put $0 into $v0
  lw $ra, 0($sp)
  lw $s0,  4($sp)
  lw $s1,  8($sp)
  lw $s2,  12($sp)
  addi $sp, $sp, 16
  addi $sp, $sp, -4
  sw $v0, 0($sp) #puts return value on stack
  jr $ra
	
pow:		#a0 = base, a1 = exponent
  move $s0, $a0


  addi $sp, $sp, -8 
  sw $ra, 0($sp)  #This stores $ra in the address stored in $sp
  sw $s0, 4($sp) 
  
  #now we need to load it back from the stack at the end of the function using 'lw' again with $s0
  beq $a1, $0, return_1 #checks if the exponent is 0

  add $a0, $0, $s0  #set $a0 to the base (which is the same)
  sub $a1, $a1, 1		#set $a1 to the decremented exponent
  jal pow #now we need to get the return value and multiply it by the base. 
  mul $t0, $s0, $v0
  #now to return it, we'll put this product into $v0, using 'move'
  move $v0, $t0   #we need to swap these since the first register is always the destination register
  
  lw $ra, 0($sp)
  lw $s0, 4($sp) #  now we need to deallocate the space
  addi $sp, $sp, 8  #now let's deallocate the space.  pretty much.
  jr $ra 
  
return_1:
  li $v0, 1			
  lw $ra, 0($sp) 
  lw $s0, 4($sp) # I copied this line here, since we need to deallocate in all the space we allocated in both the base case and the recursive case
  addi $sp, $sp, 8  #we were supposed to deallocate 8 bytes here since that's what we allocated
  jr $ra

