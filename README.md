
# dndtool

### A powerful interactive command line tool for 5e

dndtool gives an interactive environment that combines access to the 5e SRD,
convenience features such as tab completion and regex search, and a suite of helpful tools such
as a calculator, dice rollers, generators etc.
Access to SRD is achieved by virtue of the [D&d 5e SRD API](https://5e-bits.github.io/docs/).


![sreenshot](https://github.com/davebuckingham/dndtool/blob/main/screenshots/screenshot_goblin.png?raw=true)
![sreenshot](https://github.com/davebuckingham/dndtool/blob/main/screenshots/screenshot_spell.png?raw=true)
![sreenshot](https://github.com/davebuckingham/dndtool/blob/main/screenshots/screenshot_plot.png?raw=true)
![sreenshot](https://github.com/davebuckingham/dndtool/blob/main/screenshots/screenshot_list.png?raw=true)



## Docker

The Dockerfile works but I don't know how to make the output go through the 
container terminal. See how the otput gets made in the 'page' function on line 471, which sends the output through `fomat` and `less`. When I run the container, I get the
intro prompt, which doesn't go through 'page', nothing after that.

dndtool is a perl application.
It expects to be able to call the 'bc' calculator and the 'less' paging tool.
If your running dndtool in a linux shell, it will probably work, otherwise it probably wont.


## Installation

### Step 1

Use your package management system to install the following programs:

    perl
    less
    bc


### Step 2

Install the perl dependencies: 'Term::ReadLine::Gnu', 'REST::Client', and 'JSON'.
For example, using cpanm:

    $ cpanm Term::ReadLine::Gnu REST::Client JSON


### Step 3

Run dndtool:

    $ ./dndtool.pl 
    o--{===========>  dndtool 1.0  <===========}--o
    connected to https://www.dnd5eapi.co
    & 

### Step 4 (Optional)
Set up the database.
dndtool will try to connect to a 5e database at `http://localhost:3000`.
If no local database is found, it will instead connect to the database at
`https://www.dnd5eapi.co`. There are two advantages to hosting the database locally.
First, dndtool will run faster, especially when it starts. Second, you can modify
your local database, for example by adding content not in the SRD.
You need git, docker, and docker compose.

    $ git clone https://github.com/5e-bits/5e-srd-api.git
    ...
    $ cd 5e-srd-api/
    $ docker compose pull
    ...
    $ docker compose up -d --build
    ...
    $ cd ../
    $ ./dndtool
    o--{===========>  dndtool 1.0  <===========}--o
    connected to http://localhost:3000
    & 


## Example commands

    ?...............print example commands
    6*3.............perform basic arithmetic (input is passed to bc)
    d...............roll a d20
    d6..............roll a d6
    3d6+1d4+3.......roll 3d6, add 1d4, and add 3
    123 // 5........divide 123 things among 5 people
    database........print all database entries
    [spell name]....look up a spell
    [monster name]..look up a monster
    [topic].........look up a topic
    /[regex]........search the database
    weather.........randomly generate weather
    clear...........clear the screen
    exit,quit,q.....quit


## Rolling dice

A command to roll dice is any number of terms delimited by operators.
An operator is either '+' or '-'.
A term is either an integer or a dice description.
A dice description takes the form 'NdK' where
    'N' is some integer, the number of dice (default 1)
    'd' is the literal character 'd'
    'K' is some integer, what kind of dice (default 20)

Some example commands to roll dice are:

    & 1d20
    & 2d6 + 3
    & 3d8+1d6-4
    & d

Empty input is equivalent to entering '1d20'. So to roll a d20, just hit enter
at the '&' prompt.


## Arithmetic

Any input that contains at least one integer and no letters is passed to the
calculator program 'bc'. For example:

    & 7^2
    49
    & 71/3
    23.66666666666666666666


## Loot divider

The loot divider helps divide something as evenly as possible when perfect
integer division is not possible. To divide using the loot divider (instead of
bc), use two forward slashes. For example:

    & 10 // 3
    2 people get 3. 1 person gets 4.
    & 1337 // 5
    3 people get 267. 2 people get 268.


## Less

dndtool calls the paging program 'less' when it has more than one screen of
output.  In less, you can use the arrow keys to scroll, type '/' to search
forwards, type 'q' to quit, and do many other things.


## Readline and tab completion

dndtool uses gnu readline.
This lets us use the up and down arrows to cycle through
command history and Control-U to clear the current command.  For
tab completion, just type part of a key and then hit tab. If there is one
valid completion, it will be filled in automatically.  If there are multiple
valid completion, hit tab twice to list all options.  Since all database keys
are lower case, tab completion will only work with lower case input.


## Databases

The 'database' command prints the 5e database.
Display a database item by entering its name.


## Searching

If input begins with a forward slash (/), the rest of the input will be used as
a search pattern (regular expression), and dndtool will list entries that match
the pattern.
dndtool assumes that whatever follows a '/' is a valid perl regular expression.
If its not, dndtool may behave unpredictably. If you want to use metacharecters
literally, you have to escape them etc.


## Generators

A generator uses random tables to generate something. For example, the command
'weather' will use the weather table in the DMG and output weather conditions.
Currently, 'weather' is the only generator.


## Clear

Enter the command 'clear' to clear the screen.


## Quit

To quit, enter a quit command ('exit', 'quit', 'q') or send an end-of-file
(Control-D) or interrupt (Control-C).


## Non-interactive mode

If dndtool is invoked with any arguments, the arguments are combined into a
single and evaluated. The output is printed and the program
exits.

