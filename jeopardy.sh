#!/bin/bash

main_menu()
{
	echo "=============================================================="
	echo "Welcome to Jeopardy!"
	echo "=============================================================="
	
	echo "Please select from one of the following options:"
	echo "	(p)rint question board"
	echo "	(a)sk a question"
	echo "	(v)iew current winnings"
	echo "	(r)eset game"
	echo "	(x)it"
	echo ""

	#Returns exit code depending on option selected
	read -p "Enter a selection [p/a/v/r/x]: "
	selection="`echo $REPLY | sed -e 's/^[[:space:]]*//'`" #Removes trailing whitespaces
	case $selection in
		[pP]) #Print Question Board
			return 1
			;;
		[aA]) #Ask a question
			return 2
			;;
		[vV]) #View current winnings
			return 3
			;;
		[rR]) #Reset the game
			return 4
			;;
		[xX]) #Exit
			return 5
			;;
		*) #Handles all other inputs
			return 6
			;;
	esac
}

question_board()
{
	echo "=============================================================="
	echo "Question Board"
	echo "=============================================================="
	echo ""

	counter=1
	for category in ./save/categories/* ; do
		category_name="[$counter] $(basename $category): "
		
		#Labels the category as complete if all questions have been answered
		if [ ! -s $category ]
		then
			category_name+="COMPLETE"
		else 
			#Reads lines to output question values from each category
			while IFS= read -r line
			do
				value="$(echo $line | cut -d',' -f 1)"
				category_name+="${value} "
			done < "$category"
		fi
		
		#Displays the category along with all of its question values 
		echo "$category_name"
		counter=$((counter+1))	
	done
}

ask_question()
{
	#Checks if there are any remaining categories left to choose from
	remaining_categories=0
	categories=()
	for category in ./save/categories/* ; do
		categories+=($(basename $category))
		if [ -s $category ]
		then
			remaining_categories=$((remaining_categories+1))
		fi
	done
	
	#If there are no more remaining categories, returns user to main menu
	if [ $remaining_categories -eq 0 ]
	then
		echo "There are no more remaining unattempted questions."
		echo "You will need to reset the game to continue playing." 
		echo ""
	else
	#Displays the question board and allows the user to select a category
		question_board
		echo ""
		while :
		do
			read -p "Select the category by number (Or enter m to return to main menu): "
			category_selected="`echo $REPLY | sed -e 's/^[[:space:]]*//'`"
			case $category_selected in
				[mM])
					#Breaks out of function and returns to main game loop
					return
					;;
				*)
					#Checks if the selected category exists
					if [[ $REPLY -le ${#categories[@]} && $REPLY -gt 0 ]]
					then
						#Checks if the category selected is complete or not
						category_name=${categories[($REPLY - 1)]}
						if [[ -s ./save/categories/$category_name ]]
						then
							#Breaks out of loop once valid category has been completed
							echo "You have chosen the category: $category_name"
							echo ""
							break
						else 
							#Prompts user to select different category as category has been completed
							echo "The category you have selected has already been completed. Please select a different category"
							echo ""
						fi
					else
						#Prompts the user to select a differet category since the number they have chosen is not an option
						echo "You have not entered a valid category number. Please try again"
						echo ""
					fi
					;;
			esac
		done
		sleep 1
				
		#Arrays store question values, questions, and answers
		values=()
		questions=()
		answers=()
		
		category="./save/categories/$category_name"
		#Gathers list of remaining question values, questions and answers
		while IFS= read -r line
		do
			value="$(echo $line | cut -d',' -f 1)"
			value="$(echo $value | sed -e 's/^[[:space:]]*//')" #Trims whitespaces
			values+=($value)
			
			question="$(echo $line | cut -d',' -f 2)"
			question="$(echo $question | sed -e 's/^[[:space:]]*//')" #Trims whitespaces
			questions+=("$question")
			
			answer="$(echo $line | cut -d',' -f 3)"
			answer="$(echo $answer | sed -e 's/^[[:space:]]*//')" #Trims whitespaces
			answers+=("$answer")
		done < "$category"
		
		
		#Displays values for remaining questions	
		echo "These are values for the remaining questions"
		echo "${values[@]}"
		echo ""
		
		#Gets the user to select a question
		while :
		do	
			read -p "Enter the value for the question you would like to answer(Or enter b to return to categories): "
			question_value=$REPLY
			question_value=${question_value//'$'} #Removes dollar signs that are entered			
			question_value="`echo $question_value | sed -e 's/^[[:space:]]*//'`" #Removes trailing whitespaces
			valid_value=false
			
			case $question_value in
			
			[bB])
				#Returns user to question board
				echo "You will be returned to the categories screen"
				read -n 1 -s -p "Press any key to continue ..."
				echo ""
				ask_question
				return
				;;
			*) 
				#Checks if the value entered is available
				for (( i=0; i<${#values[@]}; i=i+1 ))
				do
					if [[ ${values[i]} == $question_value ]]
					then
						valid_value=true
						question_index=$i
						break
					fi
				done
				
				if [ $valid_value == true ]
				then
					break
				fi

				echo "The value you have entered was invalid. Please try again."
				echo ""
				;;
			esac
		done
		
		echo "You have selected $category_name for $question_value. Here is your question" 
		echo "You have selected $category_name for $question_value. Here is your question" | festival --tts
		echo ""
		echo "${questions[$question_index]}" 
		echo "${questions[$question_index]}" | festival --tts
		read -p "Enter your answer here: "
		echo ""
		
		user_answer=$REPLY
		user_answer="`echo $user_answer | sed -e 's/^[[:space:]]*//'`"
		correct_answer=${answers[$question_index]}
		
		#Checks if the user's answer is correct
		if [ "${user_answer,,}" == "${correct_answer,,}" ]
		then
			#Adds question value to winnings if correct
			echo "That is correct"
			echo "That is correct" | festival --tts
			echo "$ $question_value will now be added to your current winnings"
			current_winnings=$((current_winnings+$question_value))
		else 
			#Subtracts question value from winnings if incorrect
			echo "That was incorrect"
			echo "That was incorrect" | festival --tts
			echo "The correct answer was $correct_answer"
			echo "The correct answer was $correct_answer" | festival --tts
			echo "$ $question_value will now be deducted from your current winnings"
			current_winnings=$((current_winnings-$question_value))
		fi
		
		#line number for question in category file
		question_line_number="$(($question_index+1))d"
		
		#Removes question from categories file
		sed -i -e "$question_line_number" $category
				
		#Returns user to question board to select next question
		echo "You will now be returned to the main menu"
	fi
}

display_winnings()
{
	echo "=============================================================="
	echo "View current winnings"
	echo "=============================================================="
	echo ""
	
	display_winnings="Current winnings: "
	
	if [[ $current_winnings -ge 0 ]]
	then
		#Appends positive winnings to string
		display_winnings+="$"
		display_winnings+="${current_winnings}"
	else
		#Appends negative winnings to string
		display_winnings+="-$"
		display_winnings+="${current_winnings#"-"}"

	fi
	
	echo "$display_winnings"
	echo ""
}

create_save()
{
	#Stores save progress for each category
	mkdir $save_directory
	cp -r categories/ save/
	
	#Stores save progress for winnings
	mkdir $save_directory/winnings
	cd $save_directory/winnings
	echo "0" > ./winnings
	cd - > /dev/null
}


#Creates save directory to save game progress if directory doesn't
#already exist
save_directory="./save"
if [ ! -d "$save_directory" ]; 
then 
	create_save
fi

#Loads current winnings for user reading it from save file
current_winnings="$(head -n 1 $save_directory/winnings/winnings)"

#Main game loop
while true
do
	main_menu
	selection=$?
	
	case $selection in
		1) #If the user selects p (print question board)
			question_board
			;;
		[2]) #If the user selects a (Ask question)
			ask_question
			;;
		[3]) #If the user selects v (view current winnings)
			display_winnings
			;;		 
		[4]) #If the user selects r (reset the game)
			read -p "Are you sure you want to reset the game (Enter y or yes): "
			response="`echo $REPLY | sed -e 's/^[[:space:]]*//'`" #Removes trailing whitespaces
			echo ""
			case $response in
				[yY] | [yY][eE][sS]) #If the chooses to reset the game
					echo "Please wait while we reset the game"
					rm -f -r ./save #Deletes save folder
					create_save
					sleep 1
					echo "The game has been reset" 
					current_winnings="$(head -n 1 $save_directory/winnings/winnings)" #Resets current winnings
					;;
				*) #Any other input is considered as the user not wanting to reset the game
					echo "You have chosen not to reset the game"
					echo "You will now be returned to the main menu"
					;;
			esac
			;;
		[5]) #If the user selects x (exit the game)
			read -p "Are you sure you want to exit the game (Enter y or yes): "
			response="`echo $REPLY | sed -e 's/^[[:space:]]*//'`" #Removes trailing whitespaces
			echo ""
			case $response in
				[yY] | [yY][eE][sS])
					echo "Thank you for playing!" 
					sleep 1
					> $save_directory/winnings/winnings # Clears winnings
					echo "$current_winnings" > $save_directory/winnings/winnings #Saves current winnigs in file
					echo "The game will now be exited."
					sleep 1
					exit
					;;
				*)
					echo "You have chosen not to exit the game"
					echo "You will now be returned to the main menu"
					;;
			esac
			;;
		*) #If the user enters none of the options specified
			echo "That is not a valid option, please select one of the options specified"
			;;
	esac
	
	echo ""
	read -n 1 -s -p "Press any key to continue ..."
	echo ""
done


