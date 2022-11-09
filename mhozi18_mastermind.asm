# MIPStermind game that allows the user to guess 4-randomly chosen letters by the computer
# @Author Marvin Hozi [mhozi18@georgefox.edu]

.data 
	# Vars used throughout the program
	randWordArray: .space 4		# array of 4 bytes. Each ascii char needs 1 byte of space
	userInput: .space 8			# array for the input of the user (4 chars + \n, multiples of 4 to avoid alignment issues)
	playAgainInput: .space 4 	# We only need 2 bytes here but 4 ensures we avoid word alignment issues later
	welcome: .asciiz "Welcome to MIPStermind\n"
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
###############
# Dfn: Entry point for the program; Main
###############
main:
	jal intro				# Go TO intro 
	
	la $s0, randWordArray	# $s0 = randWordArray
	la $s1, userInput		# $s1 = userInput
	
	la $a0, open			# $a0 = "("
	li $v0, 4				# system service code for printing string
	syscall 
	
	jal generateRand		# generateRand();
	
	la $a0, close 			# $a0 =  ")\n"
	li $v0, 4 				# print("\n"), Print string, not char because \n is not 1 char
	syscall
	
	addi $sp, $sp, -12		# Allocate 3 words onto the stack
	jal gameLoop			# gameLoop();
	
	addi $sp, $sp, 24		# restore the state of the stack
	j exit					# GO TO exit
	
###############
# Dfn: Show the introduction statement to the player
###############
intro:
	la $a0, welcome			# $a0 = welcome 
	li $v0, 4				# print("Welcome to MIPStermind\n")       
	syscall
	
	jr $ra					# Return to Main

###############
# Dfn: Generates 4 random letters between [A-E]
# Pre: randWordArray = null
# Post: randWordArray = Array of 4 ascii chars
###############
generateRand:
	li $a1, 5  				# $a1 = 5: upper boundary for random num generation choose from [0-4 inclusive]
	li $v0, 42  			# $a0 = random(0, 5);
	syscall

	addi $a0, $a0, 65 		# $a0 += 65: Add the base (65) to a number between 0-4(inclusive) 
	sb $a0, 0($s0) 			# randWordArray[i] = $a0
	li $v0, 11   			# print($a0)
	syscall
	
	addi $s0, $s0, 1 		# &randWordArray++
	addi $t0, $t0, 1 		# i++
	
	bne $t0, 4, generateRand	# if (i < 4) GO TO generateRand
	
	# We are done with the loop so we need to clean up our modified registers
	la $s0, randWordArray 	# We operated on $s0 earlier so we must restore the original state
	li $t0, 0				# Restore the loop counter to 0 because we modified it
	jr $ra					# Return to Main

###############
# Dfn: Read 5 bytes (including line feed [\n]) from the player and store them in the array
# Pre: userInput = null
# Post: userInput = Array of 4 ascii chars
###############
readInput:
	la $a0, guessPrompt	# $a0 = "Guess a 4-letter string using only A-E: "
	li $v0, 4			# System service code for printing string
	syscall

	la $a0, userInput	# $a0 = userInput[]
	li $a1, 6			# $a1 = 6: We will read n-1 bytes so 5 characters: 4 chars (4 bytes) + \n (1 byte)
	li $v0, 8			# $v0 = 8: System service code for storing input
	syscall

	jr $ra				# Return to caller
	
###############
# Dfn: Backs up arrays onto the stack to preserve values across guessing tries
###############
backupArraysToStack:
	lw $t0, 0($s0)		# Load the random letters into $s0
	sw $t0, 4($sp)		# Store the random letters into the second word on the stack
	lw $t0, 0($s1)		# Load the input letters into $s1
	sw $t0, 8($sp)		# Store the input letters into the third word on the stack
	li $t0, 0			# Reset the state of $t0
	
	jr $ra # Return to caller
	
###############
# Dfn: Restores backed up arrays to operate on them for every user guess try (counting positions, etc)
###############
restoreArraysFromStack:
	lw $t0, 4($sp)		# Load the 2nd word from the stack into register
	sw $t0, ($s0)		# Store the word from register back into main memory
	lw $t0, 8($sp)		# Load the 3nd word from the stack into register
	sw $t0, ($s1)		# Store the word from register back into main memory
	li $t0, 0			# $t0 = 0: Reset the state
	
	jr $ra				# Return to caller
	
###############
# Dfn: Main loop for the game to keep the game going as long as user tries are wrong
###############
gameLoop:
	sw $ra, 0($sp)			# $ra will be overwritten soon so we need to store the address to our caller (MAIN)
	jal readInput			# Call function to read user input
	jal backupArraysToStack	# Backup our arrays, we are about to operate on them
	addi $s2, $s2, 1		# $s2++: Total tries counter, we need this to stick around
	
	# ASCII "0 + i" to remove matching chars! A neat trick to "take out" matching strings without having
	# them double-counted again when iterating in a double loop. 
	li $t6, 48				# $t6 = 0 			
	
###############
# Dfn: Outer loop for iterating through every user input char
###############
outerCharLoop:
	beq $t1, 4, outerCharLoopEnd	# I know I can simplify to bne , but I truly believe this is a good 
									# balance between readability and performance for a program of this size
	li $t2, 0						# $t2 = 0 : start from beginning of array

###############
# Dfn: Inner loop for iterating through every randomly-generated char for each user input char
###############
innerCharLoop:
	beq $t2, 4, innerLoopEnd		# if ($t2 = 4) GO TO innerLoopEnd
	addi $t2, $t2, 1				# j++
	lbu $t3, 0($s1)					# $t3 = userInput[0]
	lbu $t4, 0($s0)					# $t4 = randWordArray[0]
	beq $t3, $t4, scrambleAndShift	# if (userInput[0] = randWordArray[0]) GO TO scrambleAndShift
	
###############
# Dfn: Set up values for the next run of the outer loop and continue the inner loop
###############
continueInnerLoop:
	addi $s0, $s0, 1 				# &randWordArray++
	j innerCharLoop					# Loop the inner loop again through every random char

###############
# Dfn: Set up the values for the next char from the user input to be matched with the rand char array
###############
innerLoopEnd:
	addi $t1, $t1, 1				# i++
	addi $s1, $s1, 1				# $s1 = &userInput++
	la $s0, randWordArray			# $s0 = randWordArray
	j outerCharLoop					# Keep going until we exhaust user input chars

###############
# Dfn: End outer loop and resets the state of the registers + addresses that we operated on
###############
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
	
###############
# Dfn: Avoid double-counting chars by scarmbling them using the accumulator value (i) + char value
# after the addition, the current byte is rotated to avoid future collision when counting matches
###############
scrambleAndShift:
	addi $t6, $t6, 1				# $t6++
	sb $t6, 0($s0)					# randWordArray[0] = $t6
	addi $t6, $t6, 1				# $t6++
	sb $t6, 0($s1)					# userInput[0] = $t6
	addi $t5, $t5, 1				# $t5++: increment matching chars
	j continueInnerLoop				# Keep checking chars in inner loop
	
###############
# Dfn: Checks matching characters vertically. Compare ArrOne[i] <-> ArrTwo[i], increment correct position.
###############
countValidCharPositions:
	lbu $t1, 0($s0)							# $t1 = randWordArray[0]
	lbu $t2, 0($s1)							# $t2 = userInput[0]
	bne $t1, $t2, continueCharCorrectLoop	# if (randWordArray[0] != userInput[0]) GO TO continueCharCorrectLoop
	addi $t4, $t4, 1 						# $t4++

###############
# Dfn: Proceed to the next character in both: userInput and randWords arrays. Then reset modified registers.
###############
continueCharCorrectLoop:
	addi $s0, $s0, 1						# &randWordArray++
	addi $s1, $s1, 1						# &userInput++
	addi $t3, $t3, 1						# $t3++
	bne $t3, 4, countValidCharPositions		# if ($t3 != 4) GO TO countValidCharPositions
	move $s4, $t4							# $s4 = $t4
	li $t1, 0								# Reset state, callee modified
	li $t2, 0								# Reset state, callee modified
	li $t3, 0								# Reset state, callee modified
	li $t4, 0								# Reset state, callee modified
	la $s0, randWordArray					# Reset the address state
	la $s1, userInput 						# Reset the address state
	
###############
# Dfn: Verify we have 4 correct chars and correct positions then prints results.
###############
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
	
	li $a0, 10								# This just prints a new line :D (Line Feed = 10 in ASCII)
	li $v0, 11
	syscall

	slti $s5, $s3, 4						# If both: char counts and positions are 4, ask if play again...
	slti $s5, $s4, 4
	lw $ra, 0($sp)							# Prepare main address if user won't play again :D
	bne $s5, 0, gameLoop					# If positions && counts != 4, ask for another guess
	
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
	
###############
# Dfn: Re-initialize the game for another round, reset the registers that have existing values
###############
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
	
###############
# Dfn: Print the exit string then go back to main.
###############
endGame:
	la $a0, endStatement					# "Thanks for Playing"
	li $v0, 4
	syscall					

	jr $ra 									# TAKE ME HOMEEEEEE back to MAINNNNNNN!

###############
# Dfn: Exit program cleanly
###############
exit:
	li $v0, 10								
	syscall 
