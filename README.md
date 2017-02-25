
# CSoC Tests [![Build Status](https://travis-ci.org/leoheck/csoc-test.svg?branch=master)](https://travis-ci.org/leoheck/csoc-test)

## Files

<!-- ~/Dropbox/CSOC-DFT-Tests/dft-psynth/atpg/testresults/verilog/VER.FULLSCAN.capeta_soc_pads_atpg.data.logic.ex1.ts2
~/Dropbox/CSOC-DFT-Tests/dft-psynth/atpg/testresults/verilog/VER.FULLSCAN.capeta_soc_pads_atpg.data.scan.ex1.ts1 -->

- `VER.FULLSCAN.capeta_soc_pads_atpg.data.logic.ex1.ts2`
- `VER.FULLSCAN.capeta_soc_pads_atpg.data.scan.ex1.ts1`


## ATPG Verilog Commands
```
Codigos de comando dentro do arquivo de ATPG (Cadence ET):
000
100 COMMENT
200 stim_PIs -------------------------- Exemplo: 0XXXXXXXX111XX
201 stim_CIs -------------------------- Exemplo: 0XXXXXXXX1XXXX
202 resp_POs -------------------------- Exemplo: 11110100010
203 global_term_[Z] ------------------- Valor do sinal, todos em alta impedancia (z)
300 MODENUM_[1] stim_SLs stim_SLs ----- Exemplo: 1 1100110011... (acho que tem blocos de 1000 dados)
301 MODENUM_[1] resp_MLs resp_MLs ----- Exemplo: 1 1100110011... (acho que tem blocos de 1000 dados)
400 ----------------------------------- test_cycle
500 ----------------------------------- Não encontrado nos nossos arquivos de teste
501 ----------------------------------- Não encontrado nos nossos arquivos de teste
600 MODENUM_[1] SEQNUM_[1|100|2] MAX -- Exemplo: 1 2 1919
900 PATTERN --------------------------- Exemplo: 1.1.1.2.1.9
901 PATTERN --------------------------- Exemplo: 1.1.1.2.1.9
```

<!-- USING for SVG images: https://rawgit.com/ -->

<!-- ![Alt text](https://rawgit.com/leoheck/nexys2-samples/master/samples/verilog/csoc_test/blocks.svg) -->
<img src="https://rawgit.com/leoheck/csoc-test/master/blocks.svg" width="500px"xcxcxcdsd  >

<!-- ![Alt text](https://rawgit.com/leoheck/nexys2-samples/master/samples/verilog/csoc_test/setup.svg) -->
<img src="https://rawgit.com/leoheck/csoc-test/master/setup.svg" width="800px">

