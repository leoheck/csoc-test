
# CSoC Tests [![Build Status](https://travis-ci.org/leoheck/csoc-test.svg?branch=master)](https://travis-ci.org/leoheck/csoc-test)

## Serial Communication

Example for full ATPG test from Cadence ET File:

``
part-tester.py -d /dev/ttyUSB0 -b 9600 -f VER.FULLSCAN.capeta_soc_pads_atpg.data.scan.ex1.ts1
``

## ATPG Files

See instructions in [atpg folder](./atpg/).



<!-- USING for SVG images: https://rawgit.com/ -->
<img align="center" src="https://rawgit.com/leoheck/csoc-test/master/imgs/blocks.svg" width="800px">
<img align="center" src="https://rawgit.com/leoheck/csoc-test/master/imgs/state-machine.svg" width="800px">
<img align="center" src="https://rawgit.com/leoheck/csoc-test/master/imgs/setup.svg" width="800px">
