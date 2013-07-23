# GamesDice Changelog

## 0.3.9

 * New methods for inspecting and iterating over potential values in GamesDice::Die
 * Code metric integration and badges for github
 * Non-functional changes to improve code quality metrics on CodeClimate

## 0.3.7

 * Compatibility between pure Ruby and native extension code when handling bad method params
 * Added this changelog to documentation

## 0.3.6

 * Extension building skipped, with fallback to pure Ruby, for JRuby compatibility

## 0.3.5

 * Adjust C code to avoid warnings about C90 compatibility (warnings seen on Travis)
 * Note MIT license in gemspec
 * Add class method GamesDice::Probabilities.implemented_in

## 0.3.3

 * Standardised code for Ruby 1.8.7 compatibility in GamesDice::Probabilities
 * Bug fix for probability calculations where distributions are added with mulipliers e.g. '2d6 - 1d8'

## 0.3.2

 * Bug fix for Ruby 1.8.7 compatibility in GamesDice::Probabilities

## 0.3.1

 * Bug fix for Ruby 1.8.7 compatibility in GamesDice::Probabilities

## 0.3.0

 * Implemented GamesDice::Probabilities as native extension

## 0.2.4

 * Minor speed improvements to GamesDice::Probabilities

## 0.2.3

 * More YARD documentation

## 0.2.2

 * Extended YARD documentation

## 0.2.1

 * Started basic YARD documentation

## 0.2.0

 * First version with a complete feature set
