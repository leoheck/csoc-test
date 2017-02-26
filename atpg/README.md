# CADENCE Encounter Test

## ATPG Generated files

```
dft-psynth --------------------------------------------------------------- ET output files
`--|-- atpg --------------------------------------------------------------
   |   |-- capeta_soc_pads.FULLSCAN.pinassign ---------------------------- Indicação da função dos pinos pro teste
   |   |-- capeta_soc_pads.et_netlist.v ---------------------------------- CSOC netlist (identico ao capeta_soc_pads.v)
   |   |-- capeta_soc_pads.v --------------------------------------------- CSOC netlist
   |   |-- et_checks.sh -------------------------------------------------- Script to check TSV logs?
   |   |-- ncverilog_FULLSCAN.log
   |   |-- run_fullscan_sim ---------------------------------------------- KSH script (run incisive simulator)
   |   |-- runet.atpg ---------------------------------------------------- Script de templade usando com o Encounter Test
   |   |-- tbdata --------------------------------------------------------
   |   |-- Inca_libs_20_49_49 -------------------------------------------- Pasta de trabalho da simulacao
   |   `-- testresults ---------------------------------------------------
   |       `-- verilog --------------------------------------------------- Pasta com arquivos fonte
   |           |-- VER.FULLSCAN.capeta_soc_pads_atpg.data.logic.ex1.ts2 -- Vertores de teste 1
   |           |-- VER.FULLSCAN.capeta_soc_pads_atpg.data.scan.ex1.ts1 --- Vertores de teste 2
   |           |-- VER.FULLSCAN.capeta_soc_pads_atpg.mainsim.v ----------- Main TESTBENCH
   |           `-- cycleMap.FULLSCAN.capeta_soc_pads_atpg ---------------- Tabela com os testes
   |-- capeta_soc_pads.scandef ------------------------------------------- Definicao da(s) scan chain(s)
   |-- capeta_soc_pads_atpg.stil ----------------------------------------- Standard Test Interface Language (STIL)
   |-- capeta_soc_pads_dft_chains.rpt ------------------------------------ Reports
   `-- capeta_soc_pads_dft_setup.rpt ------------------------------------- Reports
```

## ATPG Flow

1. Exportar arquivos de ATPG da sintese lógica/física
2. Executar o Encounter Test (ET) sobre o arquivo exportado `runet.atpg`
3. Executar `run_fullscan_sim` realiza a simulacao com os vetores de teste gerados pelo ET


## Test Vector Formats

File: `VER.FULLSCAN.capeta_soc_pads_atpg.mainsim.v`

```
- Define Variables For All Primary I/O Ports
- Define Variables For All Shift Chains
- Other Definitions
- Instantiate The Structure And Connect To Verilog Variables
- Make Some Other Connections
- Open The File And Run Simulation
- Define Simulation Setup Procedure
- Failset Setup Procedure
- Read Commands And Data And Run Simulation
- Define Test Procedure
- Define Scan Precond Procedure
- Define Scan Precond Bsr Procedure
- Define Scan Sequence Procedure
```


### Testbanch tasks

```
sim_setup ----------------------------------- DEFINE SIMULATION SETUP PROCEDURE
failset_setup ------------------------------- FAILSET SETUP PROCEDURE
sim_vector_file ----------------------------- READ COMMANDS AND DATA AND RUN SIMULATION
test_cycle ---------------------------------- DEFINE TEST PROCEDURE
Scan_Preconditioning_Sequence_FULLSCAN ------ DEFINE SCAN PRECOND PROCEDURE
Scan_Preconditioning_Sequencebsr_FULLSCAN --- DEFINE SCAN PRECOND BSR PROCEDURE
Scan_Sequence_FULLSCAN ---------------------- DEFINE SCAN SEQUENCE PROCEDURE
```

## OPCODE Definitions

There are other opcodes which were not listed here. Manual: `et_ref_testpatterns.pdf`.


```
000 ----------------------------- Stop NCSIM simulation
100 <comment> ------------------- Comment line
200 <stim_PIs> ------------------ Input stimulus for primary inputs (PIs)
201 <stim_CIs> ------------------ Input clock stimulus
202 <resp_POs> ------------------ Expected responses for primary outputs (POs)
203 <global_term> --------------- Global termination value applyed for bidir ports
300 <testMode> <stim_SLs> ------- Scan input stimulus
301 <testMode> <resp_MLs> ------- Contains the expected scan chain values from the design
400 ----------------------------- Invokes test_cycle task
500 ----------------------------- Start of a repeat loop
501 ----------------------------- End of a repeat loop
600 <testMode> <seqNum> <max> --- Invokes any SCAN preconditioning or exit sequences required by the design
900 <patternNumber> ------------- The ATPG pattern number
901 <patternNumber> ------------- The measure ATPG pattern number.
```

