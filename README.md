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
will have a deliberately limited set of functionality prior to version 1.0.0, and there should be
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

#### GamesDice.create dice_description, prng

Converts a string such as '3d6+6' into a GamesDice::Dice object

Parameters:

 * dice_description is a string such as '3d6' or '2d4-1'. See String Dice Descriptions below for possibilities.
 * prng is optional, if provided it should be an object that has a method 'rand( integer )' that works like Ruby's built-in rand method

Returns a GamesDice::Dice object.

### GamesDice::Dice instance methods

#### dice.roll

Simulates rolling the dice as they were described in the constructor, and keeps a record of how the
simulation result was achieved.

Takes no parameters.

Returns the integer result of the roll.

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

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
