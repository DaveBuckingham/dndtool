#!/usr/bin/perl
use warnings;
use strict;
use Term::ReadLine;
use REST::Client;
use JSON;



#      o--|===========>  dndtool  <===========|--o




#my $URL_BASE = 'https://www.dnd5eapi.com';
my $URL_BASE = 'http://localhost:3000';


# THESE MAKE UP THE DATABASE, WILL STORE DATA READ IN FROM FILES
my %spells;
my %definitions;
my %monsters;
my %generators;

my @legal_dice = (4, 6, 8, 10, 12, 20, 100);

my $TERMINAL_WIDTH = 80;
my $HR = '-'x$TERMINAL_WIDTH . "\n";     # HORRIZONTAL RULE


# # WE'LL USE THESE TO READ FILES
# my $path = '/home/xor/dnd/dndtool/';
# my $line;
# my $fh;

# FOR GETTING STUFF FROMT THE 5e DATABASE
my $response;
my %database;
my $client = REST::Client->new();


####################################################################
#                        SUBROUTINES                               #
####################################################################


# PRINT OUT EXAMPLE COMMANDS
sub print_help {
print("?...............print example commands
6*3.............perform basic arithmetic (input is passed to bc)
1d6.............roll a d6
d6..............''
d...............roll a d20 (the default roll)
................''
3d6+1d4-3.......roll 3d6, add 1d4, and subtract 3
plot 2d6+3......plot the distribution for 2d6+3
p 2d6+3.........''
123 // 5........divide 123 things among 5 people
spell name......look up a spell
topic...........look up a topic in the PHB
/pattern........search descriptions for pattern
weather.........randomly generate weather
w...............''
time,t..........print the current time
clear...........clear the screen
c...............''
exit,quit,q.....quit
");
}


# FLOOR A FLOAT
sub floor {
    return $_[0] < 0 ? int($_[0]) - 1 : int($_[0]);
}




# PREPARE AND DISPLAY A LONG STRING
sub page {

    # ESCAPE QUOTES
    my $clean = $_[0] =~ s/"/\\\"/gr;

    # WRAP TEXT
    my $wrapped = `echo '$clean' | fmt -s -w $TERMINAL_WIDTH`;

    # SEND TO LESS
    system("echo \"$wrapped\" | less -FK");
}


# SEARCH DATABASE FOR A REGEX AND PRINT TITLES OF MATCHING ENTRIES
sub search {
    my $pattern = $_[0];
    my $print_string = '';

    foreach my $key (keys(%definitions))
    {
        if (($key =~ m/$pattern/i) || ($definitions{$key}{description} =~ m/$pattern/i))
        {
            $print_string .= "- $key\n";
        }
    }

#     foreach my $key (keys(%spells))
#     {
#         if (($key =~ m/$pattern/i) ||
#             ($spells{$key}{description} =~ m/$pattern/i) ||
#             ($spells{$key}{class} =~ m/$pattern/i) ||
#             ($spells{$key}{materials} =~ m/$pattern/i))
#         {
#             $print_string .= "* $key\n";
#         }
#     }
# 
#     foreach my $key (keys(%monsters))
#     {
#         if (($key =~ m/$pattern/i) ||
#            ($monsters{$key}{description} =~ m/$pattern/i) ||
#            ($monsters{$key}{actions} =~ m/$pattern/i) ||
#            ($monsters{$key}{name} =~ m/$pattern/i) ||
#            ($monsters{$key}{skills} =~ m/$pattern/i) ||
#            ($monsters{$key}{senses} =~ m/$pattern/i) ||
#            ($monsters{$key}{type} =~ m/$pattern/i) ||
#            ($monsters{$key}{size} =~ m/$pattern/i))
#         {
#             $print_string .= "! $key\n";
#         }
#     }

    foreach my $key (keys(%generators))
    {
        if ($key =~ m/$pattern/i)
        {
            $print_string .= "> $key\n";
        }
    }
    $print_string .= "\n";

    page($print_string);
}


# ROLL A DIE
sub roll_die {
    return (int(rand() * $_[0]) + 1);
}


$generators{weather} = sub {
    my $print_string .= '  Temperature: ';
    my $roll = roll_die(20);
    if ($roll <= 14)
    {
        $print_string .= "Normal for the season\n";
    }
    elsif ($roll <= 17)
    {
        $print_string .= roll_die(4) * 10;
        $print_string .= " degrees Fahrenheit colder than normal\n";
    }
    else
    {
        $print_string .= roll_die(4) * 10;
        $print_string .= " degrees Fahrenheit hotter than normal\n";
    }

    $print_string .= '         Wind: ';
    $roll = roll_die(20);
    if ($roll <= 12)
    {
        $print_string .= "None\n";
    }
    elsif ($roll <= 17)
    {
        $print_string .= "Light\n";
    }
    else
    {
        $print_string .= "Strong\n";
    }

    $print_string .= 'Precipitation: ';
    $roll = roll_die(20);
    if ($roll <= 12)
    {
        $print_string .= "None\n";
    }
    elsif ($roll <= 17)
    {
        $print_string .= "Light rain or light snowfall\n";
    }
    else
    {
        $print_string .= "Heavy rain or heavy snowfall\n";
    }

    return $print_string;
};
$generators{w} = $generators{weather};



#PARSE DICE ROLL
#INPUT IS OF THE FORM 'NdKSM' WHERE
#    'N' IS SOME INTEGER (NUMBER OF DICE)
#    'd' IS THE LITERAL CHARACTER 'd'
#    'K' IS SOME INTEGER (WHAT KIND OF DICE)
#    'S' IS EITHER '+' OR '-' (MODIFIER SIGN)
#    'M' IS SOME INTEGER (MODIFIER)
#     AND 'N', 'K', AND 'SM' ARE EACH OPTIONAL
#     DEFAULTS ARE 'N':1, 'K':20, 'SM':+0

sub parse_dice {
    my $exp = $_[0];

    # REMOVE PARENS
    $exp =~ s/^[\s()]*//;
    $exp =~ s/[\s()]*$//;

    # INPUT IS ONE OR MORE TERMS SEPARATED BY A PLUS OR MINUS
    # WHERE A TERM IS EITHER AN INTEGER OR A DIE ROLL OF THE FORM 'NdK'
    # WHERE 'N' AND 'K' ARE INTEGERS AND 'd' IS LITERAL.
    if ($exp !~ m/^\s*((\d*\s*d\s*\d*)|(\d+))(\s*[-+]\s*((\d*\s*d\s*\d*)|(\d+)))*$/) {
        return 0;
    }

    # ALSO MUST HAVE AT LEAST ONE 'd'
    if ($exp !~ m/d/){
        return 0;
    }

    # STRUCTURE TO HOLD PARSE RESULTS
    my %terms = ();
    $terms{'dice'} = ();
    $terms{'constants'} = ();

    # SPLIT INTO TERMS
    my @input_terms = split('\s*[+-]\s*', $exp);
    my @signs = split('\s*[^+-]*\s*', "+$exp");

    # ITERATE OVER TERMS, ADDING TO STRUCTURE
    for (my $i = 0; $i < @input_terms; $i++) {
        my $input_term = $input_terms[$i];
        my $sign = $signs[$i] eq '+' ? 1 : -1;

        # IF TERM IS A DIE ROLL OF THE FORM NdK
        if ($input_term =~ m/^(\d+)?d(\d+)?$/) {

            my %die_term = ('multiplier' => defined $1 ? $1 : 1,
                            'sides'      => defined $2 ? $2 : 20,
                            'sign'       => $sign);

            push(@{$terms{'dice'}}, \%die_term);
        }

        # OTHERWISE, TERM IS AN INT
        elsif ($input_term =~ m/^\d+$/) {
                push(@{$terms{'constants'}}, $input_term * $sign);
        }

        # IT SHOULD NOT BE POSSIBLE TO GET HERE
        else {
            printf("ERROR: %s\n", $input_term);
            die();
        }
    }
    return \%terms;
}

sub roll {
    my $terms = parse_dice($_[0]);
    return 0 if ($terms == 0);

    my $sum = 0;
    my $print_string = "";

    foreach my $die_term (@{$$terms{'dice'}}) {
        for (my $j = 0; $j < $$die_term{'multiplier'}; $j++) {
            my $val = int(rand() * $$die_term{'sides'} + 1) * $$die_term{'sign'};
            $sum += $val;

            $print_string .= sprintf("%sd%-4d%5d", $$die_term{'sign'} == -1 ? '-' : ' ',
                                                   $$die_term{'sides'},
                                                   $val);

            # ADD '!' IF A STRANGELY-SIDED DIE IS USED
            if (! grep { /$$die_term{'sides'}/ } @legal_dice) {
                $print_string .= " !";
            }

            $print_string .= "\n";
        }
    }

    # PRINT OUT ANY CONSTANTS
    foreach my $constant (@{$$terms{'constants'}}) {
        $sum += $constant;
        $print_string .= sprintf("%11d\n", $constant);
    }

    # PRINT THE SUM
    if(@{$$terms{'dice'}} + @{$$terms{'constants'}} > 1 || ${$$terms{'dice'}}[0]{'multiplier'} > 1) {
        $print_string .= sprintf("%11s\n", "-----");
        $print_string .= sprintf("%11d\n", $sum);
    }

    page($print_string);
    return 1;
}


sub plot
{
    my $input = $_[0];

    my $match = ($input =~ s/^\s*(p|plot)(\s+|$)//);

    return 0 if (! $match);

    if ($input =~ m/^\s*$/) {
        print ("nothing to plot\n");
        return 1;
    }

    my $terms = parse_dice($input);
    if ($terms == 0) {
        print ("invalid plot input\n");
        return 1;
    }

    my $scalar = 0;

    my @distribution = (1);
    foreach my $die_term (@{$$terms{'dice'}}) {
        while($$die_term{'multiplier'}--) {
            $scalar ++;

            # DOESN'T WORK
            #my $sides = $$die_term{'sides'} * $$die_term{'sign'};

            # ASSUME ALL DICE ARE POSITIVE
            my $sides = $$die_term{'sides'};

            my @previous_dist = @distribution;

            for (my $i = 1; $i < @previous_dist + $sides - 1; $i++)
            {
                $distribution[$i] += $distribution[$i-1];
                if ($i >= $sides)
                {
                    $distribution[$i] -= $previous_dist[$i-$sides];
                }
            }
        }
    }

    if (@distribution > 31) {
        print("distribution to wide to display\n");
        return 1;
    }

    foreach my $constant (@{$$terms{'constants'}})
    {
        $scalar += $constant;
    }

    print("expected: ");
    print(((@distribution + 1) / 2) + $scalar - 1);
    print("\n");

    my $combinations = 0;

    # GET MAX Y VALUE
    my $y = 0;
    foreach my $d (@distribution)
    {
        ($y = $d) if $d > $y;
        $combinations += $d;
    }

    #print("combinations: ");
    #print($combinations);
    #print("\n");


    my $downsample = 1;
    while ($y / $downsample > 18) {
        $downsample *= 2;
    }

    while ($y > 0)
    {
        my $percent = ($y / $combinations) * 100;
        #printf("%-4d", $y);     # PRINT THE Y AXIS
        #printf("'%04.2f'", $percent);     # PRINT THE Y AXIS
        #printf("%5.2f", $percent);
        foreach my $d (@distribution)
        {
            print($d >= $y ? ' # ' : '   ');
        }
        print("\n");
        $y -= $downsample;
    }
    #print("     ");
    for (my $i = 0; $i < @distribution; $i++)
    {
        printf(" %-2d", $scalar + $i);
    }
    print("\n");

    return 1;
}


# INTIGER DIVISION WIHTOUT REMAINDER
# NOTATION EXAMPLE: '123 // 4'
sub divide_loot {
    my $left = $_[0];
    my $right = $_[1];

    if ($left <= 0 || $right <= 0) {
        return -1;
    }

    my $base = int($left / $right);
    my $higher = $base + 1;

    my $num_higher = $left % $right;
    my $num_base = $right - $num_higher;
    if ($num_higher) {
        my $verb_base = $num_base == 1 ? 'person gets' : 'people get';
        my $verb_higher = $num_higher == 1 ? 'person gets' : 'people get';
        print("$num_base $verb_base $base. $num_higher $verb_higher $higher.\n");
    }
    else {
        print("everyone gets $base.\n");
    }
}


# INTEGER RANK SYNTAX
sub print_level {
    my $val = $_[0];
    return 'cantrip' if $val eq '0';
    return '1st-level' if $val eq '1';
    return '2nd-level' if $val eq '2';
    return '3rd-level' if $val eq '3';
    return "${val}th-level";
}

sub markdown {
    my $print = "";
    my @rows = split(/\n/, $_[0]);
    my $title = $rows[0];
    $title =~ s/^#*\s*//g;
    my $border_len = length($title) + 2;
    $print .= (' ' . '-' x $border_len . " \n");
    $print .= ("| $title |\n");
    $print .= (' ' . '-' x $border_len . " \n");
    foreach my $line (@rows[2..$#rows]) {
        if ($line =~ m/^#/) {
            $line =~ s/#/-/g;
            $print .= "$line\n";
        }
        else {
            $print .= "$line\n";
        }
    }
    return $print;
}


# FORMAT AND PRINT A RULE
sub print_list {
    my $print_string = "";
    foreach my $item (@{$_[0]->{'items'}}) {
        $print_string .= $item . "\n";
    }
    page($print_string);
    return;
}

# FORMAT AND PRINT A RULE
sub print_rule {
    my $print_string = "";
    my %rule = %{$_[0]};
    my $description = request($rule{'url'})->{'desc'};
    $print_string .= (markdown($description));
    $print_string .= "\n";
    page($print_string);
    return;
}

# FORMAT AND PRINT A SPELL
sub print_spell {
    my $print_string = "";
    my %spell = %{$_[0]};

    # SPELL NAME WITH BORDER
    my $border_len = (length $spell{'name'}) + 2;
    $print_string .= (' ' . '~' x $border_len . " \n");
    $print_string .= ("{ $spell{'name'} }\n");
    $print_string .= (' ' . '~' x $border_len . " \n");


    # BASIC SPELL INFO
    my $school = $spell{'school'}->{'name'};
    my $level = $spell{'level'};
    if ($level == 0 ) {
        $print_string .= $school . print_level($level) . "\n";
    }
    else {
        $print_string .= print_level($level) . " " . lc($school) . "\n";
    }

    # SPELL STATS
    $print_string .= "\n";
    $print_string .= "Casting Time: $spell{'casting_time'}";
    $print_string .= "\n";
    $print_string .= "Range: $spell{'range'}";
    $print_string .= "\n";
    $print_string .= "Components: ";
    $print_string .= join(", ", @{$spell{'components'}});
    if($spell{'materials'}) {
        $print_string .= (" ($spell{'material'})");
    }
    $print_string .= "\n";
    $print_string .= "Duration: ";
    #$print_string .= join(", ", @{$spell{'duration'}});
    $print_string .= $spell{'duration'};
    $print_string .= "\n";

    # DESCRIPTION
    $print_string .= "\n";
    foreach my $d (@{$spell{'desc'}}, @{$spell{'highter_level'}}) {
        $print_string .= "$d\n\n";
    }

    # PRINT
    page($print_string);
}

sub fraction {
    return '1/8' if $_[0] == 0.125;
    return '1/4' if $_[0] == 0.25;
    return '1/2' if $_[0] == 0.5;
    return $_[0];
}


# FORMAT AND PRINT A STAT BLOCK
sub print_monster {
    my $print_string = "";
    my %stats = %{$_[0]};


    # NAME WITH BORDER
    my $border_len = (length $stats{'name'}) + 2;
    $print_string .= ('+' . '-' x $border_len . "+\n");
    $print_string .= ("| $stats{'name'} |\n");
    $print_string .= ('+' . '-' x $border_len . "+\n");


    # SIZE, TYPE AND ALIGNMENT
    $print_string .= ($stats{'size'} . " " . $stats{'type'} . ", " . $stats{'alignment'});
    $print_string .= ("\n");


    # ARMOR CLASS
    $print_string .= ("Armor Class: " . $stats{'armor_class'}[0]->{'value'} . ' ');
    if ($stats{'armor_class'}[0]->{'type'} eq 'dex') {
    }
    elsif ($stats{'armor_class'}[0]->{'type'} eq 'natural') {
        $print_string .= '(natural armor)\n';
    }
    elsif ($stats{'armor_class'}[0]->{'type'} eq 'armor') {
        $print_string .= '(';
        foreach my $armor (@{$stats{'armor_class'}[0]->{'armor'}}) {
            $print_string .= $armor->{'name'} . ', ';
        }
        $print_string =~ s/, $//;
        $print_string .= ')\n';
    }
    else {
        die "failed to read armor";
    }


    # HIT POINTS
    $print_string .= "Hit Points: $stats{'hit_points'} ($stats{'hit_points_roll'})\n";


    # SPEED
    $print_string .= "Speed: $stats{'speed'}{'walk'}";
    foreach my $mode ('burrow', 'climb', 'fly', 'swim') {
        if ($stats{'speed'}{$mode}) {
            $print_string .= ", $mode $stats{'speed'}{$mode}";
        }
    }
    $print_string .= "\n";
    $print_string .= $HR;


    # STATS
    $print_string .= ("     ");
    foreach my $stat ('STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA') {
        $print_string .= sprintf("%-12s", $stat);
    }
    $print_string .= ("\n");
    $print_string .= ("   ");
    foreach my $stat ('strength', 'dexterity', 'constitution', 'intelligence', 'wisdom', 'charisma') {
        my $stat_string = ($stats{$stat});
        $stat_string .= " (";
        my $modifier = floor(($stats{$stat} - 10) / 2);
        $stat_string .= '+' if ($modifier >= 0);
        $stat_string .= $modifier;
        $stat_string .= ")";
        $print_string .= sprintf("%-12s", $stat_string);
    }
    $print_string .= "\n";
    $print_string .= $HR;


    # PROPERTIES
    my @properties = ();

    my @saving_throws = ('Saving Throws: ',);
    foreach my $p (@{$stats{'proficiencies'}}) {
        my $id = $p->{'proficiency'}->{'index'};
        if ($id =~ s/^saving-throw-(.)/\U$1/) {
            push(@saving_throws, "$id +$p->{'value'}");
        }
    }
    push(@properties, \@saving_throws);

    my @skills = ('Skills: ',);
    foreach my $p (@{$stats{'proficiencies'}}) {
        my $id = $p->{'proficiency'}->{'index'};
        if ($id =~ s/^skill-(.)/\U$1/) {
            push(@skills, "$id +$p->{'value'}");
        }
    }
    push(@properties, \@skills);

    my @s;
    @s = ();
    foreach my $p (@{$stats{'damage_vulnerabilities'}}) {
        #push(@s, $p);
    }
    push(@properties, ['Damage Vulnerabilities: ', @s]);

    @s = ();
    foreach my $p (@{$stats{'damage_resistances'}}) {
        #push(@s, $p);
    }

    @s = ();
    foreach my $p (@{$stats{'damage_immunities'}}) {
        push(@s, $p);
    }
    push(@properties, ['Damage Immunities: ', @s]);

    @s = ();
    foreach my $p (@{$stats{'condition_immunities'}}) {
        push(@s, $p->{'name'});
    }
    push(@properties, ['Condition Immunities: ', @s]);

    @s = ();
    foreach my $sense (
                       'blindsight',
                       'darkvision',
                       'tremorsense',
                       'truesight', 
                       'passive_perception') {
        if ($stats{'senses'}->{$sense}) {
            push (@s, $sense);
        }
    }
    push(@properties, ['Senses: ', @s]);

    if ($stats{'languages'}) {
        push(@properties, ['Languages: ', $stats{'languages'}]);
    }

    push(@properties, ['Challenge: ', 
                       fraction($stats{'challenge_rating'}) .
                       ' (' . $stats{'xp'} . ')'
                      ]);

    foreach my $property (@properties) {
        if (@{$property} > 1) {
            $print_string .= $property->[0];
            foreach my $item (@{$property}[1..@$property-1]) {
                $print_string .= "$item, ";
            }
            $print_string =~ s/, $//;
            $print_string .= "\n";
        }
    }
    $print_string .= "\n";


    # SPECIAL ABILITIES
    foreach my $a (@{$stats{'special_abilities'}}) {
        $print_string .= $a->{'name'};
        if ($a->{'usage'}) {
            print_string .= print_usage($a->{'usage'});
        }
        $print_string .= ": ";
        $print_string .= $a->{'desc'};
        $print_string .= "\n\n";
    }

    # ACTIONS
    $print_string .= "Actions\n";
    $print_string .= $HR;

    foreach my $a (@{$stats{'actions'}}) {
        $print_string .= $a->{'name'};
        if ($a->{'usage'}) {
            print_string .= print_usage($a->{'usage'});
        }
        $print_string .= ": ";
    }



#
#    $print_string .= $HR;
#    $print_string .= $stats{'description'};
#    $print_string .= "\n";
#    $print_string .= "Actions\n";
#    $print_string .= $stats{'actions'};

    page($print_string);
}


#TRY SENDING USER INPUT TO EACH FUNCTION UNTIL ONE ACCEPTS
sub parse_command {
    my $input = $_[0];

    # IF INPUT CONTAINS 'help', TELL USER HOW TO FIND HELP
    if ($input =~ m/help/) {
        print("(enter '?' for help with dndtool)\n");
    }

    # IF INPUT STARTS WITH '/', RUN A SEARCH
    if ($input =~ m/^\/(.*)$/) {
        search($1);
        return;
    }

    # NOW THAT WE'RE AFTER A POSSIBLE SEARCH,
    # REMOVE LEADING AND TRAILING WHITESPACE
    $input =~ s/^\s*//;
    $input =~ s/\s*$//;

    # INPUT IS EMPTY, ROLL A D20
    if ($input eq '') {
        roll('1d20');
        return;
    }

    # INPUT STARTS WITH '!', SEND THE REST TO BASH
    # todo

    # INPUT CONTAINS A '//', SO RUN THE LOOT DIVIDER
    if ($input =~ m/^(\d.*)\s*\/\/\s*(\d.*)$/) {
        divide_loot($1, $2);
        return;
    }

    if ($input =~ m/^\s*database/) {
        my $print_string = "";
        foreach my $key (sort keys(%database)){
            $print_string .= $database{$key}->{'type'} eq 'spell' ? "* " : 
                             $database{$key}->{'type'} eq 'monster' ? "! " : 
                             '- ';
            $print_string .= $key . "\n";
        }
        page($print_string);
        return;
    }
   
    # LOOK UP INPUT IN DATABASE
    if (exists $database{lc($input)}) {
        my $entry = $database{lc($input)};
        if ($entry->{type} eq 'spell') {
            print_spell(request($entry->{url}));
        }
        elsif ($entry->{type} eq 'rule') {
            print_rule(request($entry->{url}));
        }
        elsif ($entry->{type} eq 'list') {
            print_list($entry);
        }
        elsif ($entry->{type} eq 'monster') {
            print_monster(request($entry->{url}));
        }
        else {
            # THIS COULD BE MORE GRACEFUL
            die 'unknown type: ' . $entry->{type};
        }
        return;
    }


    # SEND INPUT TO THE ROLL PARSER
    if(roll($input))
    {
        return;
    }

    # SEND INPUT TO PLOT
    if(plot($input))
    {
        return;
    }


    # SEND INPUT TO THE GENERATOR
    if (defined $generators{$input}){
        print & { $generators{$input} }();
        return;
    }

    # INPUT CONTAINS A '?', PRINT HELP
    if ($input =~ m/\?/) {
        print_help();
        return;
    }

    # CHECK THE TIME
    if ($input =~ m/^t\s*$|^time\s*$/) {
        print(`date +%r`);
        return;
    }

    # CLEAR THE SCREEN
    if ($input =~ m/^c\s*$|^clear\s*$/) {
        print(`clear` . "\n");
        return;
    }

    # IF IT HAS NUMBERS BUT NO LETTERS, SEND TO bc
    if (($input =~ m/[0-9]/) && ($input !~ m/[a-zA-Z]/)) {
        print(`echo "$_[0]" | bc -l`);
        return;
    }
    
    # GIVE UP
    print("'$input' not found. Enter '?' for help.\n");
    return;
}


sub request {
    my $url_suffix = $_[0];
    $client->GET($URL_BASE . $url_suffix, {'Accept' => 'application/json'});
    die "failed database read" if $client->responseCode() != 200;
    return decode_json($client->responseContent());
}


####################################################################
#                          MAIN PROGRAM                            #
####################################################################


# LOAD SPELLS
foreach my $spell (@{request('/api/spells')->{'results'}}) {
    $database{lc($spell->{'name'})} = {'type' => 'spell',
                                       'id' => $spell->{'index'},
                                       'name' => $spell->{'name'},
                                       'url' => $spell->{'url'}
                                      };
}

# LOAD RULES
foreach my $section ('adventuring', 
                     'appendix',
                     'combat',
                     'equipment',
                     'spellcasting',
                     'using-ability-scores'
                    ) {
    foreach my $rule (@{request('/api/rules/' . $section)->{'subsections'}}) {
        $database{lc($rule->{'name'})} = {'type' => 'rule',
                                          'id' => $rule->{'index'},
                                          'name' => $rule->{'name'},
                                          'section' => $section,
                                          'url' => $rule->{'url'} };
    }
}


# EXAMPLE LIST
#     $database{'colors'} = {'type' => 'list',
#                             'name' => 'Colors',
#                             'items' => ['red', 'green', 'blue'] };

# LOAD MONSTERS
foreach my $monster (@{request('/api/monsters')->{'results'}}) {
    $database{lc($monster->{'name'})} = {'type' => 'monster',
                                      'id' => $monster->{'index'},
                                      'name' => $monster->{'name'},
                                      'url' => $monster->{'url'} };
}






# CHECK FOR COMMAND LINE PARAMTER. IF FOUND, PROCESS INPUT AND QUIT
if (@ARGV > 0) { 
    my $command = join(" ", @ARGV);
    parse_command($command);
    exit(0);
}


# SET UP TERM
my $terminal = Term::ReadLine->new('dnd');
die 'Need Term::ReadLine::Gnu installed' unless $terminal->ReadLine eq 'Term::ReadLine::Gnu';
$terminal->Attribs->ornaments(0);


# TAB COMPLETION
my @tab_completion_words = (keys(%database), keys(%generators), 'database', 'help', 'quit');

$terminal->Attribs->{completion_entry_function} = $terminal->Attribs->{list_completion_function};
$terminal->Attribs->{completion_word} = \@tab_completion_words;

# SEARCH STARTING WITH BEGINNING OF INPUT, NOT LAST WORD
$terminal->Attribs->{completer_word_break_characters} = "";


# PRINT STARTUP MESSAGE
print("o--|===========>  dndtool  <===========|--o\n\n");


# MAIN LOOP
while (1)
{
    # READ FROM PROMPT
    my $command = lc($terminal->readline('& '));

    # DIE IF INPUT IS EOF (CTRL-D)
    if (! defined $command)
    {
        print("\n");
        exit(0);
    }

    # OR IF USER ENTERED A QUIT COMMAND
    exit(0) if ($command =~ m/^quit|^exit|^q$/);

    # OTHERWISE, SEND COMMAND TO PARSER
    parse_command($command);
}


