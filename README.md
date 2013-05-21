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
build some exotic dice systems, the recommended way to use GamesDice is to create GamesDice::Dice
objects via the factory methods from the GamesDice module, and then use those objects to simulate
dice rolls, explain the results or calculate probabilties as required.

### GamesDice factory methods

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

Calculates probability distribution for the dice. Note that some distributions, involving keeping
a number best or worst results, can take significant time to calculate.

Returns a GamesDice::Probabilities object that describes the probability distribution.

    probabilities = dice.probabilities

### GamesDice::Probabilities instance methods

#### probabilities.to_h

Returns a hash representation of the probability distribution. Each keys is a possible result
from rolling the dice (an Integer), and the associated value is the probability of a roll
returning that value (a Float).

#### probabilities.max

Returns maximum value in the probability distribution. This may not be the theoretical maximum
possible on the dice, if for example the dice can roll open-ended high results.

#### probabilities.min

Returns minimum value in the probability distribution. This may not be the theoretical minimum
possible on the dice, if for example the dice can roll open-ended low results.


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

More complex die modifiers are possible, with parameters supplied in square brackets, and multiple
modifiers should combine as expected e.g.

    5d10r[10,add]k2

#### Rerolls

You can specify that dice rolling certain values should be re-rolled, and how that re-roll should be
interpretted.

The simple form specifies a low value that will automatically trigger a one-time replacement:

    1d6r1

When rolled, this die will score from 1 to 6. If it rolls a 1, it will roll again automatically
and use that result instead.

#### Maps

You can specify that the value shown on each die is converted to some other set of values. If
you add at least one map modifier, all unmapped values will map to 0 by default.

The simple form specifies a value above which the result is considered to be 1, as in "one success":

    3d10m6

When rolled, this will score from 0 to 3 - the number of the ten-sided dice that scored 6 or higher.

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

    5d10x

When rolled, this will score from 5 to theoretically any number, as results of 10 on any die mean that
die rolls again and the result is added on.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
