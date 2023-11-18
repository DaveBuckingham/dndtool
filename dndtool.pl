#!/usr/bin/perl

use warnings;
use strict;
use Term::ReadLine;
use REST::Client;
use JSON;
use Number::Format 'format_number';  # add commas in big numbers



my $url_base;

my @LEGAL_DICE = (4, 6, 8, 10, 12, 20, 100);

my $TERMINAL_WIDTH = 80;
my $HR = '-'x$TERMINAL_WIDTH . "\n";     # HORRIZONTAL RULE

my $response;  # response from database api

my %database;  # stores data that has been retrieved
my %generators;  # e.g. weather generator

my $client = REST::Client->new();

my @URLS = ( '5e-srd-api', 'http://localhost:3000', 'https://www.dnd5eapi.co' );  # attempted in order



####################################################################
#                            COLORS                                #
####################################################################


my %colors = (
    'black'     => "\033[0;30m",
    'red'       => "\033[0;31m",
    'green'     => "\033[0;32m",
    'yellow'    => "\033[0;33m",
    'blue'      => "\033[0;34m",
    'magenta'   => "\033[0;35m",
    'cyan'      => "\033[0;36m",
    'white'     => "\033[0;37m",
    'nocolor'   => "\033[0m"
);

#sub rgb {
#    assert (0 <= $_[0] <= 255);
#}

# because of how less handles escape sequences with the R option,
# our color commands can't span blocks of text.

    $colors{'spell_outline'}                    = $colors{'cyan'};
    $colors{'spell_title'}                      = $colors{'nocolor'};
    $colors{'spell_subtitle'}                   = $colors{'nocolor'};
    $colors{'spell_stats_keys'}                 = $colors{'nocolor'};
    $colors{'spell_stats_values'}               = $colors{'cyan'};
    $colors{'monster_outline'}                  = $colors{'red'};
    $colors{'monster_title'}                    = $colors{'nocolor'};
    $colors{'monster_subtitle'}                 = $colors{'yellow'};
    $colors{'monster_action_name'}              = $colors{'red'};
    $colors{'monster_actions_title'}            = $colors{'yellow'};
    $colors{'monster_special_abilities_keys'}   = $colors{'yellow'};
    $colors{'monster_special_abilities_values'} = $colors{'nocolor'};


# Collorize a string:
# first parameter: string containing ^ symbols to be replacd with colors
# second parameters: an array with length = number of X symbols in the string
sub color_format {
    my $s = $_[0];
    my $f = $_[1];
    foreach my $color ( @$f ) {
        $s =~ s/\^/$color/;
    }
    return $s;
}



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


# GET A RESOURCE FROM THE SERVER
sub request {
    my $url_suffix = $_[0];
    $client->GET($url_base . $url_suffix, {'Accept' => 'application/json'});
    my $code = $client->responseCode();
    die "failed database read: $code" if $code != 200;
    return decode_json($client->responseContent());
}


# SEARCH DATABASE FOR A REGEX AND PRINT TITLES OF MATCHING ENTRIES
sub search {
    my $pattern = $_[0];
    my $print_string = '';

    foreach my $key (keys(%database))
    {
        if (($key =~ m/$pattern/i)) {
            if ($database{$key}->{'type'} eq 'spell') {
                $print_string .= "* ";
            }
            elsif ($database{$key}->{'type'} eq 'monster') {
                $print_string .= "! ";
            }
            else {
                $print_string .= "- ";
            }
            $print_string .= "$key\n";
        }
    }

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


# RANDOMLY GENERATE WEATHER
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


# THE LOOT DIVIDER
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



####################################################################
#                        DICE FUNCTIONS                            #
####################################################################


# ROLL A DIE
sub roll_die {
    return (int(rand() * $_[0]) + 1);
}


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
            if (! grep { /$$die_term{'sides'}/ } @LEGAL_DICE) {
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


# PLOT A ROLL DISTRIBUTION
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
        foreach my $d (@distribution)
        {
            print($d >= $y ? ' # ' : '   ');
        }
        print("\n");
        $y -= $downsample;
    }
    for (my $i = 0; $i < @distribution; $i++)
    {
        printf(" %-2d", $scalar + $i);
    }
    print("\n");

    return 1;
}



####################################################################
#                       FORMATTING                                 #
####################################################################


my $FADE = "------------- - - - - - - - -  -  -  -  -  -\n";

# PREPARE AND DISPLAY A LONG STRING
sub page {
    my $clean = $_[0] =~ s/"/\\\"/gr;  # escape quotes
    system("echo \"$clean\" | fmt -s -w $TERMINAL_WIDTH | less -eFKXR");  # wrap and page

}


# PRINTING CHALLENGE RATINGS LESS THAN 1
sub format_cr {
    return '1/8' if $_[0] == 0.125;
    return '1/4' if $_[0] == 0.25;
    return '1/2' if $_[0] == 0.5;
    return $_[0];
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


# FORMAT THE MARKDOWN READ FROM THE DB
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


# FORMAT AND PRINT A LIST
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

    $print_string .= $colors{'spell_outline'} . ' ' . ('~' x $border_len) . "\n";
    $print_string .= $colors{'spell_outline'} . '{ ' . $colors{'spell_title'} . $spell{'name'} . $colors{'spell_outline'} . " }\n";
    $print_string .= $colors{'spell_outline'} . ' ' . ('~' x $border_len) . "\n";

    # BASIC SPELL INFO
    my $school = $spell{'school'}->{'name'};
    my $level = $spell{'level'};
    $print_string .= $colors{'spell_subtitle'};
    if ($level == 0 ) {
        $print_string .= $school . ' ' . print_level($level) . "\n";
    }
    else {
        $print_string .= print_level($level) . " " . lc($school) . "\n";
    }
    $print_string .= "\n";

    # COLORIZE THE SPELL STAT
#    sub spell_stat {
#        $print_string .= $colors{'spell_stats_keys'} . "$_[0]: " . $colors{'spell_stats_values'} . $_[1] . "\n";
#    }


    # SPELL STATS
    my $colorpair = [$colors{'spell_stats_keys'}, $colors{'spell_stats_values'}];
    $print_string .= color_format("^Casting Time: ^$spell{'casting_time'}\n", $colorpair);
    $print_string .= color_format("^Range: ^$spell{'range'}\n", $colorpair);
    my $components = join(", ", @{$spell{'components'}});
    if($spell{'materials'}) {
        $components .= (" ($spell{'material'})");
    }
    $print_string .= color_format("^Components: ^$components\n", $colorpair);
    #spell_stat('Duration',  $spell{'duration'});

    # DESCRIPTION
    foreach my $paragraph (@{$spell{'desc'}}, @{$spell{'higher_level'}}) {
        $print_string .= "\n";
        $print_string .= "$paragraph";
        $print_string .= "\n";
    }
    $print_string .= $colors{'nocolor'};

    page($print_string);
}


# FORMAT PRINTING FOR RECHARGE OR USAGE ROLES FOR MONSTER ABILITIES
sub print_usage {
    my $usage = $_[0];
    if ($usage->{'type'} eq 'recharge on roll') {
        my $maximum = $usage->{'dice'};
        $maximum =~ s/^\d*d//;   # e.g. '1d6' becomes '6'
        my $minimum = $usage->{'min_value'};
        if ($maximum > $minimum) {
            return "(recharge $minimum-$maximum)";
        }
        else {
            return "(recharge $maximum)";
        }
    }
    elsif ($usage->{'type'} eq 'per day') {
        return "($usage->{'times'}/Day)";
    }
    else {
        die "unknown usage type $usage->{'type'}";
    }
    return '<usage>';
}


# FORMAT AND PRINT A STAT BLOCK
sub print_monster {
    my $print_string = "";
    my %stats = %{$_[0]};

    my $border_len = (length $stats{'name'}) + 2;
    $print_string .= $colors{'monster_outline'} . '+' . ('-' x $border_len) . "+\n";
    $print_string .= $colors{'monster_outline'} . '| ' . $colors{'monster_title'} . $stats{'name'} . $colors{'monster_outline'} . " |\n";
    $print_string .= $colors{'monster_outline'} . '+' . ('-' x $border_len) . "+\n";

    # SIZE, TYPE AND ALIGNMENT
    $print_string .= $colors{'monster_subtitle'};
    $print_string .= ($stats{'size'} . " " . $stats{'type'} . ", " . $stats{'alignment'});
    $print_string .= ("\n\n");

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

    # STATS
    my $width = 8;
    $print_string .= $colors{'monster_outline'};
    $print_string .= '+' . '-' x ($width * 6) . '--+' . "\n";
    $print_string .= $colors{'monster_outline'} . '|' .  $colors{'nocolor'};
    foreach my $stat ('STR ', 'DEX ', 'CON ', 'INT ', 'WIS ', 'CHA ') {
        $print_string .= sprintf("%${width}s", $stat);
    }
    $print_string .= $colors{'monster_outline'} . '  |' .  $colors{'nocolor'};
    $print_string .= ("\n");
    $print_string .= $colors{'monster_outline'} . '|' .  $colors{'nocolor'};
    foreach my $stat ('strength', 'dexterity', 'constitution', 'intelligence', 'wisdom', 'charisma') {
        my $stat_string = ($stats{$stat});
        $stat_string .= "(";
        my $modifier = floor(($stats{$stat} - 10) / 2);
        $stat_string .= '+' if ($modifier >= 0);
        $stat_string .= $modifier;
        $stat_string .= ")";
        $print_string .= sprintf("%${width}s", $stat_string);
    }
    $print_string .= $colors{'monster_outline'} . '  |' .  $colors{'nocolor'};
    $print_string .= "\n";
    $print_string .= $colors{'monster_outline'};
    $print_string .= '+' . '-' x ($width * 6) . '--+' . "\n";

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
            (my $f = $sense) =~ s/passive_perception/passive Perception/;
            push (@s, "$f $stats{'senses'}->{$sense}");
        }
    }
    push(@properties, ['Senses: ', @s]);

    if ($stats{'languages'}) {
        push(@properties, ['Languages: ', $stats{'languages'}]);
    }

    push(@properties, ['Challenge: ', 
                       format_cr($stats{'challenge_rating'}) .
                       ' (' . format_number($stats{'xp'}) . ' XP)'
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
        my $key = $a->{'name'};
        if ($a->{'usage'}) {
            $key .= ' ' . print_usage($a->{'usage'});
        }
        $key .= ": ";
        my $val .= $a->{'desc'};
        my $colorpair = [$colors{'monster_special_abilities_keys'}, $colors{'monster_special_abilities_values'}];
        $print_string .= color_format("^$key^$val\n\n", $colorpair);
    }




    # ACTIONS
    $print_string .= $colors{'monster_actions_title'};
    $print_string .= "Actions\n";
    $print_string .= $colors{'monster_outline'} . $FADE;

    foreach my $a (@{$stats{'actions'}}) {
        $print_string .= $colors{'monster_action_name'};
        $print_string .= $a->{'name'};
        if ($a->{'usage'}) {
            $print_string .= ' ' . print_usage($a->{'usage'});
        }
        $print_string .= ": ";
        $print_string .= $colors{'nocolor'};
        $a->{'desc'} =~ s/target/mmm/g;
        $print_string .= $a->{'desc'};
        $print_string .= "\n\n";
    }
    $print_string =~ s/\n$//;



    # LEGENDARY ACTIONS

    $print_string .= "\n";
    if (@{$stats{'legendary_actions'}} != 0) {
        $print_string .= $colors{'monster_actions_title'};
        $print_string .= "Legendary Actions\n";
        $print_string .= $colors{'monster_outline'} . $FADE;
    }

    foreach my $a (@{$stats{'legendary_actions'}}) {
        $print_string .= $colors{'monster_action_name'};
        $print_string .= $a->{'name'};
        if ($a->{'usage'}) {
            $print_string .= ' ' . print_usage($a->{'usage'});
        }
        $print_string .= ": ";
        $print_string .= $colors{'nocolor'};
        $print_string .= $a->{'desc'};
        $print_string .= "\n\n";
    }
    $print_string =~ s/\n$//;

    page($print_string);
}



####################################################################
#                     PARSE USER INPUT                             #
####################################################################


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

    # PRINT THE DATABASE
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

    # IF INPUT CONTAINS '?', PRINT HELP
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



####################################################################
#                          MAIN PROGRAM                            #
####################################################################


# PRINT STARTUP MESSAGE
open(FH, '<', 'VERSION') or die $!;
my $version = <FH>;
chomp $version;
close(FH);


# FIND DATABASE
foreach my $url (@URLS) {
    $client->GET($url, {'Accept' => 'application/json'});
    if ($client->responseCode() == 200) {
        $url_base = $url;
        last;
    }
}
die "database connection failed\n" if !$url_base;


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


# PRINT BANNER
page(color_format("^o--{^===========>  ^dndtool $version  ^<===========^}--o", [
    $colors{'yellow'},
    $colors{'cyan'},
    $colors{'nocolor'},
    $colors{'cyan'}, 
    $colors{'yellow'}]));

page("connected to $url_base");


# MAIN LOOP
while (1)
{
    # READ FROM PROMPT
    my $input = $terminal->readline('& ');

    # QUIT IF INPUT IS EOF (CTRL-D)
    if (! defined $input) {
        print("\n");
        exit(0);
    }

    my $command = lc($input);

    # OR IF USER ENTERED A QUIT COMMAND
    exit(0) if ($command =~ m/^quit|^exit|^q$/);

    # OTHERWISE, SEND COMMAND TO PARSER
    parse_command($command);
}

