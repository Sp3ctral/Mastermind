.data 
	randWordArray: .space 4	# array of 4 bytes. Each ascii char takes 1 byte and we need 4 to store 4 random ints.
	userInput: .space 8  # array for the input for the user
	playAgainInput: .space 4
	welcome: .asciiz "Welcome to MIPStermind\n"	# welcome message
	guessPrompt: .asciiz "Guess a 4-letter string using only A-E: "
	correctLetters: .asciiz "Correct Letters: "
	correctPositions: .asciiz "\nCorrect Positions: "
	congratsOne: .asciiz "Great Job, It took you only "
	congratsTwo: .asciiz " guesse(s)!\n\n"
	playAgain: .asciiz "Do you want to play again (Y/N)? "
	endStatement: .asciiz "Thanks for Playing"
	open: .asciiz "("
	close: .asciiz ")\n\n"

.text

main:
	jal intro	# Go to the introduction procedure
	
	la $s0, randWordArray	# load base address of int array
	la $s1, userInput		# load base address of input storage array
	
	la $a0, open	# load "(" into $a0
	li $v0, 4		# system service code for printing string
	syscall 
	
	jal generate_rand	# Generate 4 random numbers
	
	la $a0, close 		# load ")\n"
	li $v0, 4 			# system service code for printing string, not char because we also have \n tacked on
	syscall
	
	addi $sp, $sp, -12	# Allocate 3 words onto the stack
	jal outerLoop		# go to the outer "while true" game loop
	
	addi $sp, $sp, 24	# restore the state of the stack
	j exit				# Exit safely!!!
	
# Show the intro statements to the player
intro:
	la $a0, welcome		# Load the address of the string 
	li $v0, 4			# Print the welcome statement        
	syscall
	
	jr $ra	# Go back to the caller, we don't need to clean up these register, we will overwrite them later

# Generate 4 random numbers and store them into an array
generate_rand:
	li $a1, 5  				# Set the upper boundary for random num generation (0-4 inclusive)
	li $v0, 42  			# System service code for generating the random number.
	syscall

	addi $a0, $a0, 65 	# Add the base (65) to a number between 0-4(inclusive) to get ascii char (A-E inclusive)
	sb $a0, 0($s0) 		# Store the ascii code into ith position of the array
	li $v0, 11   		# Convert the ascii code to a char and print out the result
	syscall
	
	addi $s0, $s0, 1 	# Increment the base address of byte the array by 1 to go to the next position
	addi $t0, $t0, 1 	# Increment our loop counter by 1
	
	bne $t0, 4, generate_rand	# If the loop is less than 4 iterations, keep going, else exit it
	
	# We are done with the loop so we need to clean up our modified registers
	la $s0, randWordArray 	# We operated on $s0 earlier so we must restore the original state
	li $t0, 0				# Restore the loop counter to 0 because we modified it
	jr $ra					# Return to the caller

# Read 5 bytes (including line feed [\n]) from the player and store them in the array
readInput:
	la $a0, guessPrompt	# Load the address of the input prompt into the arg register
	li $v0, 4			# System service code for printing string
	syscall

	la $a0, userInput	# Load the array where the user input will go
	li $a1, 6			# We will read n-1 bytes so 5 characters: 4 chars (4 bytes) + \n (1 byte)
	li $v0, 8			# System service code for storing input
	syscall

	jr $ra				# Return to caller
	
# We need to backup our arrays onto the stack before we modify them so we can operate on them again
backupArraysToStack:
	lw $t0, 0($s0)		# Load the random letters into $s0
	sw $t0, 4($sp)		# Store the random letters into the second word on the stack
	lw $t0, 0($s1)		# Load the input letters into $s1
	sw $t0, 8($sp)		# Store the input letters into the third word on the stack
	li $t0, 0			# Reset the state of $t0
	
	jr $ra # Return to caller
	
# We need to restore backed up stack arrays into memory to operate on them again [Counting correct positions]
restoreArraysFromStack:
	lw $t0, 4($sp)		# Load the 2nd word from the stack into register
	sw $t0, ($s0)		# Store the word from register back into main memory
	lw $t0, 8($sp)		# Load the 3nd word from the stack into register
	sw $t0, ($s1)		# Store the word from register back into main memory
	li $t0, 0			# Reset the state
	
	jr $ra				# Return to caller
	
# This is our main game loop. Sort of like a "while true" but not really...
outerLoop:
	sw $ra, 0($sp)			# $ra will be overwritten soon so we need to store the address to our caller (MAIN)
	jal readInput			# Call function to read user input
	jal backupArraysToStack	# Backup our arrays, we are about to operate on them
	addi $s2, $s2, 1		# Total tries counter, we need this to stick around, this loop won't reset it
	
	# ASCII "0 + i" to remove matching chars! A neat trick to "take out" matching strings without having
	# them double-counted again when iterating in a double loop. 
	# would love your input on this trick!
	li $t6, 48				
	
# Loop that iterates through the user input array (i=0, i < 4, i++)
outerCharLoop:
	beq $t1, 4, outerCharLoopEnd	# I know I can simplify to bne , but I truly believe this is a good balance
									# between readability and performance
	li $t2, 0						# Reset our inner loop i to start from the beginning of the rand word array

# Loop that iterates through the random word array (j=0, j < 4, j++)
innerCharLoop:
	beq $t2, 4, innerLoopEnd		# Restart the loop as until we hit 4 iterations
	addi $t2, $t2, 1				#  j++
	lbu $t3, 0($s1)					# Load into $t3 the first char from the user input
	lbu $t4, 0($s0)					# Load into $t4 the first char from the user input
	beq $t3, $t4, scrambleBytesAndShift	# If the chars are equal, scramble them
	
# After the main body of the inner loop is done we set up for next run of outer loop
continueInnerLoop:
	addi $s0, $s0, 1 				# Go to the next address of the random char array
	j innerCharLoop					# Loop the inner loop again through every random char

# Set up the values for the next char from the user input to be matched with the rand char array
innerLoopEnd:
	addi $t1, $t1, 1				# i++
	addi $s1, $s1, 1				# Move to the next user input string
	la $s0, randWordArray			# Start from the first rand char array position again
	j outerCharLoop					# Keep going until we exhaust user input chars

# Our double loop ends so we must reset the state of the registers + addresses that we operated on
outerCharLoopEnd:
la $s0, randWordArray				# Reset the address of the rand char array
la $s1, userInput					# Reset the address of user the input char array
move $s3, $t5						# Store how many chars are correct (persist to $s3)

li $t1, 0							# Reset state, callee modified
li $t2, 0							# Reset state, callee modified
li $t3, 0							# Reset state, callee modified
li $t4, 0							# Reset state, callee modified
li $t5, 0							# Reset state, callee modified
li $t6, 0							# Reset state, callee modified

jal restoreArraysFromStack			# Restore array clones since we now need to count correct positions	
j countValidCharPositions			# Start counting the char correct positions
	
# Strategy: Set the bytes that match to 0 + i, 0 + i + 1 so they never collide and trigger a false match
# when double looping. Fool-proof O(1) solution that negates performance loss of double looping.
# ALTERNATIVE STRATEGY: Shift bytes of the matching bytes.
scrambleBytesAndShift:
	addi $t6, $t6, 1				# Add 1 to $t6 so it's now 1 for first run
	sb $t6, 0($s0)					# Set the ith matching byte to $t6
	addiu $t6, $t6, 1				# Add 1 to $t6 so it's now 1 + previous value of $t6
	sb $t6, 0($s1)					# Set the jth matching byte to $t6 + prev value of $t6
	addi $t5, $t5, 1				# Increment matching chars++
	j continueInnerLoop				# Keep checking chars in inner loop
	
# STRATEGY: align chars and check vertically. Compare Arr[i] <-> ArrTwo[i], then increment correct position
countValidCharPositions:
	lbu $t1, 0($s0)							# Load the first character from the random words array
	lbu $t2, 0($s1)							# Load the first character from the user input array
	bne $t1, $t2, continueCharCorrectLoop	# Sync positions and restart loop
	addi $t4, $t4, 1 						# matching chars num++

continueCharCorrectLoop:
	addi $s0, $s0, 1						# Go to the next character in the rand char array
	addi $s1, $s1, 1						# Go to the next character in the user input array
	addi $t3, $t3, 1						# Loop counter++
	bne $t3, 4, countValidCharPositions		# Restart the loop until we iterate 4 times (4 chars)
	move $s4, $t4							# Store num of matching chars to $s4 persist
	li $t1, 0								# Reset state, callee modified
	li $t2, 0								# Reset state, callee modified
	li $t3, 0								# Reset state, callee modified
	li $t4, 0								# Reset state, callee modified
	la $s0, randWordArray					# Reset the address state
	la $s1, userInput 						# Reset the address state
	
verifyCharsAndOutputResults:
	la $a0, correctLetters					# Print correct letter amounts string
	li $v0, 4
	syscall
	
	move $a0, $s3							# Print correct letter amounts integer
	li $v0, 1
	syscall
	
	la $a0, correctPositions				# Print correct letter positions string
	li $v0, 4
	syscall
	
	move $a0, $s4							# Print correct letter amounts integer
	li $v0, 1
	syscall
	
	li $a0, 10								# This just prints a new line :D (LF = 10 in ASCII)
	li $v0, 11
	syscall

	slti $s5, $s3, 4						# If both: char counts and positions are 4, ask if play again...
	slti $s5, $s4, 4
	lw $ra, 0($sp)							# Prepare main address if user won't play again :D
	bne $s5, 0, outerLoop					# If positions && counts != 4, ask for another guess
	
	la $a0, congratsOne						# Positions && Counts == 4? Prompt user to play again. They won
	li $v0, 4
	syscall
	
	move $a0, $s2							# Print how many guesses it took
	li $v0, 1
	syscall
	
	la $a0, congratsTwo						# Just the word "guesse(s)"
	li $v0, 4
	syscall
	
	la $a0, playAgain						# Prompt if the user wants to play again
	li $v0, 4
	syscall
	
	la $a0, playAgainInput					# Capture their input for playing again or not
	li $a1, 3
	li $v0, 8
	syscall		
	
	lbu $t0, playAgainInput					# Load the play again response and compare immediate with 'N'
	bne $t0, 'N', reInit					# If play again, sweep registers.
	j endGame								# Else, end game
	
reInit: 
	li $t0, 0								# Reset states
	li $s2, 0								
	li $s3, 0								
	li $s4, 0								
	li $s5, 0
	
	li $a0, 10								# This just prints a new line :D (LF = 10 in ASCII)
	li $v0, 11								# Makes the console log look nicer!
	syscall
	j main									# After sweeping registers, restart game with clean state
	
endGame:
	la $a0, endStatement					# Thank you for playing!
	li $v0, 4
	syscall					

	jr $ra 									# TAKE ME HOMEEEEEE!

exit:
	li $v0, 10								# Exit cleanly
	syscall 

# It took more time to write comments that the actual coding for this assignment... I am sad :(
