# GamesDice

[![Build Status](https://travis-ci.org/neilslater/games_dice.png?branch=master)](http://travis-ci.org/neilslater/games_dice)

A library for simulating dice, intended for constructing a variety of dice systems as used in
role-playing and board games.

## Special Note on Versions Prior to 1.0.0

The author is using this code as an exercise in gem "best practice". As such, the gem
will have a deliberately limited set of functionality prior to version 1.0.0, and there should be
many small release increments before then.

The functionality should expand to cover dice systems seen in many role-playing systems, as it
progresses through 0.x.y versions (in fact much of this code is already written and working, so if
you have a burning need to simulate dice rolls for a specific game, feel free to get in touch).

## Installation

Add this line to your application's Gemfile:

    gem 'games_dice'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install games_dice

## Usage

    require 'games_dice'

    # Simple 6-sided die, more to follow
    d = GamesDice::Die.new( 6 )
    d.roll         # => 4
    d.result       # => 4
    d.explain_roll # => "4"

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
