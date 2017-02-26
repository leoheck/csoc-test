
# CSoC Tests [![Build Status](https://travis-ci.org/leoheck/csoc-test.svg?branch=master)](https://travis-ci.org/leoheck/csoc-test)

## Serial Communication

Example for full ATPG test from Cadence ET File:

``
part-tester.py -d /dev/ttyUSB0 -b 9600 -f VER.FULLSCAN.capeta_soc_pads_atpg.data.scan.ex1.ts1
``

## ATPG Files

See instructions in [atpg folder](./atpg/).



<!-- ## State Machine -->
<!-- ## Setup -->

<!-- USING for SVG images: https://rawgit.com/ -->
<!-- ![Alt text](https://rawgit.com/leoheck/nexys2-samples/master/samples/verilog/csoc_test/blocks.svg) -->
<img src="https://rawgit.com/leoheck/csoc-test/master/blocks.svg" width="500px">

<!-- ![Alt text](https://rawgit.com/leoheck/nexys2-samples/master/samples/verilog/csoc_test/setup.svg) -->
<img src="https://rawgit.com/leoheck/csoc-test/master/setup.svg" width="800px">
