.data 
	randWordArray: .space 4	# array of 4 bytes. Each ascii char takes 1 byte and we need 4 to store 4 random ints.
	userInput: .space 8  # array for the input for the user
	welcome: .asciiz "Welcome to Mastermind\n"	# welcome message
	guessPrompt: .asciiz "Guess a 4-letter string using only A-E: "
	correctLetters: .asciiz "Correct Letters: "
	open: .asciiz "("
	close: .asciiz ")\n\n"

.text

main:
	jal intro
	
	la $s0, randWordArray	# load base address of int array into $s0
	la $s1, userInput	# load base address of input array into $s1
	
	la $a0, open 	# load "(" into $a0
	li $v0, 4 		# system service code for printing string
	syscall 
	
	jal generate_rand
	
	la $a0, close 	# load ")\n" into $a0
	li $v0, 4 		# system service code for printing string, string because we also have \n tacked on
	syscall
	
	addi $sp, $sp, -24 # allocate 6 words onto the stack
	jal outerLoop # go to the outer while loop
	
	addi $sp, $sp, 24 # restore the state of the stack
	j exit
	
intro:
	la $a0, welcome # load the address of the string 
	li $v0, 4		# syscall 4 (print_str)        
	syscall			# print the string
	
	jr $ra

generate_rand:
	li $a1, 5  				# set $a1 to the max bounds for random num generation
	li $v0, 42  			# system service code for generating the random number.
	syscall

	addi $a0, $a0, 65 	# add 65 to a number between 0-4(inclusive) to get a random ascii code representing A-E(inclusive)
	sb $a0, 0($s0) 		# store the ascii code into the first element of the array
	li $v0, 11   		# convert the ascii code to a char and print out the result
	syscall
	
	addi $s0, $s0, 1 	# increment the base address of byte the array by 1 to go to the next byte position
	addi $t0, $t0, 1 	# increment our loop counter by 1
	
	bne $t0, 4, generate_rand	# if the loop is less than 4 iterations, keep going, else exit
	la $s0, randWordArray 	# restore the original address of the array in $s0
	li $t0, 0 # restore the loop counter to 0
	jr $ra

readInput:
	la $a0, guessPrompt # load the address of the input prompt into the arg register
	li $v0, 4	# system service code for printing string
	syscall

	la $a0, userInput # load the array where the user input will go
	li $a1, 6 # we will read n-1 bytes so 5 characters: 4 chars + \n	
	li $v0, 8 #	system service code for storing input
	syscall

	jr $ra # return to caller
	
backupArraysToStack:
	lw $t0, 0($s0)
	sw $t0, 4($sp)
	lw $t0, 0($s1)
	sw $t0, 8($sp)
	li $t0, 0
	
	jr $ra
	
restoreArraysFromStack:
	lw $t0, 4($sp)
	sw $t0, ($s0)
	lw $t0, 8($sp)
	sw $t0, ($s1)
	li $t0, 0
	
	jr $ra
	
outerLoop:
	sw $ra, 0($sp) # store the address back to the caller (main)
	jal readInput # call function to read user input
	jal backupArraysToStack
	addi $s2, $s2, 1 # total tries counter, we need this to stick around
	
outerNumCharsCorrectLoop:
	beq $t1, 4, outerNumCharsCorrectLoopEnd
	
	li $t2, 0
innerLoopStart:
	beq $t2, 4, innerLoopEnd
	addi $t2, $t2, 1
	lbu $t3, 0($s1)
	lbu $t4, 0($s0)
	beq $t3, $t4, zeroBytesAndIncrement
	
continueInnerLoop:
	addi $s0, $s0, 1
	j innerLoopStart

innerLoopEnd:
	addi $t1, $t1, 1
	addi $s1, $s1, 1 
	la $s0, randWordArray
	j outerNumCharsCorrectLoop

outerNumCharsCorrectLoopEnd:
la $s0, randWordArray
la $s1, userInput
jal restoreArraysFromStack
# Good progress! Just zero out the registers used previously, restore the values of the arrays,
# free up the used stack space, prepare for the number position checking loop!
	
	
zeroBytesAndIncrement:
	sb, $zero, 0($s0)
	sb, $zero, 0($s1)
	addi $t5, $t5, 1
	j continueInnerLoop
	
checkCorrectCharsLoop:
	lbu $t1, 0($s0) # load the first character from the random words array
	lbu $t2, 0($s1) # load the first character from the user input array
	beq $t1, $t2, charsMatchIncrement # if the characters match, increment the counter
	
continueCharCorrectLoop: # continue the loop after we increment the counter
	addi $s0, $s0, 1 # go to the next character in the rand char array
	addi $s1, $s1, 1 # go to the next character in the user input array
	addi $t3, $t3, 1 # loop counter
	bne $t3, 4, checkCorrectCharsLoop # restart the loop until we iterate 4 times (4 chars)
	li $t1, 0 # reset the register
	li $t2, 0 # reset the register
	la $s0, randWordArray # reset the address
	la $s1, userInput # reset the address
	
	j outputResultDEBUGGING # FOR DEBUGGING ONLY, JUST WANT TO SEE CORRECT CHAR AMOUNTS
	
charsMatchIncrement: # used to increment the number of correct chars counter
	addi $t4, $t4, 1 # increment by 1
	j continueCharCorrectLoop # continue the character iteration loop
	
outputResultDEBUGGING:	# FOR DEBUGGING ONLY, JUST WANT TO SEE CORRECT CHAR AMOUNTS
	la $a0, correctLetters
	li $v0, 4
	syscall
	
	move $a0, $t4
	li $v0, 1
	syscall
	
	

	# now we need to work on the logic for what happens if the user guess is wrong
	# we also need to track number of correct character positions
	
	lw $ra, 0($sp) # load main's next instruction
	jr $ra # go to main!

exit:
li $v0, 10
syscall 
