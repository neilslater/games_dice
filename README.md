# GamesDice

[![Build Status](https://travis-ci.org/neilslater/games_dice.png?branch=master)](http://travis-ci.org/neilslater/games_dice)

A library for simulating dice, intended for constructing a variety of dice systems as used in
role-playing and board games.

## Description

GamesDice is a gem to automate or simulate a variety of dice rolling systems found in board games and
role-playing games.

GamesDice is designed for systems used to generate integer results, and that do not require the
player to make decisions or apply other rules from the game. There are no game mechanics implemented
in GamesDice (such as the chance to hit in a combat game).

The main features of GamesDice are

 * Uses string dice descriptions, the basics of which are familiar to many game players e.g. '2d6 + 3'
 * Supports common features of dice systems automatically:
   * Re-rolls that replace or modify the previous roll
   * Counting number of "successes" from a set of dice
   * Keeping the best, or worst, results from a set of dice
 * Can explain how a result was achieved in terms of the individual die rolls
 * Can calculate probabilities and expected values (experimental feature)

## Special Note on Versions Prior to 1.0.0

The author is using this code as an exercise in gem "best practice". As such, the gem
will have a limited set of functionality prior to version 1.0.0, and there should be
many small release increments before then.

## Installation

Add this line to your application's Gemfile:

    gem 'games_dice'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install games_dice

## Usage

    require 'games_dice'

    dice = GamesDice.create '4d6+3'
    dice.roll  #  => 17 (e.g.)

## Library API

Although you can refer to the documentation for the contained classes, and use it if needed to
build some exotic dice systems, all you need to know to access the core features is described
here.

### GamesDice factory method

#### GamesDice.create

    dice = GamesDice.create dice_description, prng

Converts a string such as '3d6+6' into a GamesDice::Dice object

Parameters:

 * dice_description is a string such as '3d6' or '2d4-1'. See String Dice Descriptions below for possibilities.
 * prng is optional, if provided it should be an object that has a method 'rand( integer )' that works like Ruby's built-in rand method

Returns a GamesDice::Dice object.

### GamesDice::Dice instance methods

Example results given for '3d6'. Unless noted, methods do not take any parameters.

#### dice.roll

Simulates rolling the dice as they were described in the constructor, and keeps a record of how the
simulation result was achieved.

    dice.roll        # => 12

#### dice.result

Returns the value from the last call to roll. This will be nil if no roll has been made yet.

    dice.result      # => nil
    dice.roll
    dice.result      # => 12

#### dice.explain_result

Returns a string that attempts to show how the result from the last call to roll was composed
from individual results. This will be nil if no roll has been made yet.

    dice.explain_result    # => nil
    dice.roll              # => 12
    dice.explain_result    # => "3d6: 4 + 2 + 6 = 12"

The exact format is the subject of refinement in future versions of the gem.

#### dice.max

Returns the maximum possible value from a roll of the dice. Dice with the possibility of rolling
progressively higher and higher values will return an arbitrary high value.

    dice.max         # => 18

#### dice.min

Returns the minimum possible value from a roll of the dice. Dice with the possibility of rolling
progressively lower and lower values will return an arbitrary low value.

    dice.min         # => 3

#### dice.minmax

Convenience method, returns an array [ dice.min, dice.max ]

    dice.minmax      # => [3,18]

#### dice.probabilities

Calculates probability distribution for the dice.

Returns a GamesDice::Probabilities object that describes the probability distribution.

    probabilities = dice.probabilities

Note that some distributions, involving keeping a number best or worst results, can take
significant time to calculate. If the theoretical distribution would contain a large number
of very low probabilities due to a possibility of large numbers re-rolls, then the
calculations cut short, typically approximating to the nearest 1.0e-10.

### GamesDice::Probabilities instance methods

#### probabilities.to_h

Returns a hash representation of the probability distribution. Each key is a possible result
from rolling the dice (an Integer), and the associated value is the probability of a roll
returning that result (a Float, between 0.0 and 1.0 inclusive).

    distribution = probabilities.to_h
    distribution[3]           # => 0.0046296296296

#### probabilities.max

Returns maximum result in the probability distribution. This may not be the theoretical maximum
possible on the dice, if for example the dice can roll open-ended high results.

    probabilities.max         # => 18

#### probabilities.min

Returns minimum result in the probability distribution. This may not be the theoretical minimum
possible on the dice, if for example the dice can roll open-ended low results.

    probabilities.min         # => 3

#### probabilities.p_eql( n )

Returns the probability of a result equal to the integer n.

    probabilities.p_eql( 3 )  # => 0.004629629629
    probabilities.p_eql( 2 )  # => 0.0

Probabilities below 1e-10 due to requiring long sequences of re-rolls will calculate as 0.0

#### probabilities.p_gt( n )

Returns the probability of a result greater than the integer n.

    probabilities.p_gt( 17 )  # => 0.004629629629
    probabilities.p_gt( 2 )   # => 1.0

#### probabilities.p_ge( n )

Returns the probability of a result greater than or equal to the integer n.

    probabilities.p_ge( 17 )  # => 0.0185185185185
    probabilities.p_ge( 3 )   # => 1.0

#### probabilities.p_le( n )

Returns the probability of a result less than or equal to the integer n.

    probabilities.p_le( 17 )  # => 0.9953703703703
    probabilities.p_le( 3 )   # => 0.0046296296296

#### probabilities.p_lt( n )

Returns the probability of a result less than the integer n.

    probabilities.p_lt( 17 )  # => 0.9953703703703
    probabilities.p_lt( 3 )   # => 0.0

## String Dice Descriptions

The dice descriptions are a mini-language. A simple six-sided die is described like this:

    1d6

where the first integer is the number of dice to add together, and the second number is the number
of sides on each die. Spaces are allowed before the first number, and after the dice description, but
not between either number and the "d".

The dice mini-language allows for adding and subtracting integers and groups of dice in a list, e.g.

    2d6 + 1d4
    1d100 + 1d20 - 5

That is the limit of combining dice and constants though, no multiplications, or bracketed constructs
like "(1d8)d8" - you can still use games_dice to help simulate these, but you will need to add your own
code to do so.

### Die Modifiers

After the number of sides, you may add one or more modifiers, that affect all of the dice in that
"NdX" group. A die modifier can be a single character, e.g.

    1d10x

A die modifier can also be a single letter plus an integer value, e.g.

    1d6r1

You can add comma-seperated parameters to a modifier by using a ":" (colon) character after the
modifier letter, and a "." (full stop) to signify the end of the parameters. What parameters are
accepted, and what they mean, depends on the modifier:

    5d10r:>8,add.

You can use more than one modifier. Modifiers should be separated by a "." (full stop) character, although
this is optional if you use modifiers without parameters:

    5d10r:10,add.k2
    5d10xk2
    5d10x.k2

are all equivalent.

#### Rerolls

You can specify that dice rolling certain values should be re-rolled, and how that re-roll should be
interpretted.

The simple form specifies a low value that will automatically trigger a re-roll and replace:

    1d6r1

When rolled, this die will score from 1 to 6. If it rolls a 1, it will roll again automatically
and use that result instead.

The full version of this modifier, allows you to specify from 1 to 3 parameters:

    1d10r:[VALUE_COMPARISON],[REROLL_TYPE],[LIMIT].

Where:

 * VALUE_COMPARISON is one of >, >=, == (default), <= < plus an integer to set conditions on when the reroll should occur
 * REROLL_TYPE is one of
  * replace (default) - use the new value in place of existing value for the die
  * add - add result of reroll to running total, and ignore any subtract rules
  * subtract - subtract result of reroll from running total, and reverse sense of any further add results
  * use_best - use the new value if it is higher than the existing value
  * use_worst - use the new value if it is higher than the existing value
 * LIMIT is an integer that sets the maximum number of times that the rule can be triggered, the default is 1000

Examples:

    1d6r:1.                # Same as "1d6r1"
    1d10r:10,replace,1.    # Roll a 10-sided die, re-roll a result of 10 and take the value of the second roll
    1d20r:<=10,use_best,1. # Roll a 20-sided die, re-roll a result if 10 or lower, and use best result

#### Maps

You can specify that the value shown on each die is converted to some other set of values. If
you add at least one map modifier, all unmapped values will map to 0 by default.

The simple form specifies a value above which the result is considered to be 1, as in "one success":

    3d10m6

When rolled, this will score from 0 to 3 - the number of the ten-sided dice that scored 6 or higher.

The full version of this modifier, allows you to specify from 1 to 3 parameters:

    3d10m:[VALUE_COMPARISON],[MAP_VALUE],[DESCRIPTION].

Where:

 * VALUE_COMPARISON is one of >, >= (default), ==, <= < plus an integer to set conditions on when the map should occur
 * MAP_VALUE is an integer that will be used in place of a result from a die, default value is 1
  * maps are tested in order that they are declared, and first one that matches is applied
  * when at least one map has been defined, all unmapped values default to 0
 * DESCRIPTION is a word or character to use to denote the map in any explanation

Examples:

    9d6x.m:10.           # Roll 9 six-sided "exploding" dice, and count 1 for any result of 10 or more
    9d6x.m:10,1,S.       # Same as above, but with each success marked with "S" in the explanation


#### Keepers

You can specify that only a sub-set of highest or lowest dice values will contribute to the final
total.

The simple form indicates the number of highest value dice to keep.

    5d10k2

When rolled, this will score from 2 to 20 - the sum of the two highest scoring ten-sided dice, out of
five.

#### Aliases

Some combinations of modifiers crop up in well-known games, and have been allocated single-character
short codes.

This is an alias for "exploding" dice:

    5d10x    # Same as '5d10r:10,add.'

When rolled, this will score from 5 to theoretically any number, as results of 10 on any die mean that
die rolls again and the result is added on.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
