#!/usr/bin/env python
# The Shebang tells the computer what to call the file with when it runs.
# For more info:https://bash.cyberciti.biz/guide/Shebang  

# Specify config options
# The name we want to say hello to
my_name = "<enter_a_name_here>" 
# The number of times to say hello
num_rep = 1

# Specify /path/to/message.txt file
# Since we are creating our message.txt file inside our GearTutorial 
# directory, we can just specify the path as the name of the file.
custom_message = "<enter_custom_message_filename_here>"

# While the num_rep variable is greater than zero
while (num_rep > 0):
    # Open the file hello.txt with the intent to append
    with open('<enter_output_filename_here>', 'a') as f:
        # Write "Hello, <my_name>! to the file every loop
        f.write("Hello, {}!\n".format(my_name))

    # Print "Hello, <my_name>!" to the terminal every loop
    print("Hello, {}!".format(my_name))

    # Decrease the num_rep variable by one
    num_rep -= 1

# Now read the custom message:
# Open the file with the intent to read
message_file = open(custom_message,'r') 
# Print a blank line to separate the message from the "hello's"
print('\n')
# Read and print the file
print(message_file.read())



