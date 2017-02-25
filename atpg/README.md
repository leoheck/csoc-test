# CADENCE ET

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


## Testbench Operation

File: `VER.FULLSCAN.capeta_soc_pads_atpg.mainsim.v`

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

1. Os arquivos de teste são lidos

```
+TESTFILE1=$WORKDIR/testresults/verilog/VER.FULLSCAN.capeta_soc_pads_atpg.data.scan.ex1.ts1
+TESTFILE2=$WORKDIR/testresults/verilog/VER.FULLSCAN.capeta_soc_pads_atpg.data.logic.ex1.ts2
```

2. São definidas algumas tarefas

```
sim_setup ----------------------------------- DEFINE SIMULATION SETUP PROCEDURE
failset_setup ------------------------------- FAILSET SETUP PROCEDURE
sim_vector_file ----------------------------- READ COMMANDS AND DATA AND RUN SIMULATION
test_cycle ---------------------------------- DEFINE TEST PROCEDURE
Scan_Preconditioning_Sequence_FULLSCAN ------ DEFINE SCAN PRECOND PROCEDURE
Scan_Preconditioning_Sequencebsr_FULLSCAN --- DEFINE SCAN PRECOND BSR PROCEDURE
Scan_Sequence_FULLSCAN ---------------------- DEFINE SCAN SEQUENCE PROCEDURE
```

## ATPG Commands
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

# Command description from ET Manual

```
100: Cabecalho do arquivo com comentarios
200: Campo com 14 caracteres (valores 01X), estimulos nas entradas
201: Campo com 14 caracteres (valores 01X), estimulos nas entradas
202: Campo com 11 caracteres (valores 01),  deve ser as valores esperados nas saidas
203: Tem um "z"
300: 1, ESPAÇO e STREAM de 1000 caracteres (valores 01): deve ser o stream de dados para entrada/saida
301: 1, ESPAÇO e STREAM de 1000 caracteres (valores 01): deve ser o stream de dados para saida/entrada
400: Sem argumentos, pode indicar o inicio do teste
600: Duas opções: "600 1 1 1" OU "600 1 2 1919": Pode indicar o numero de pulsos de clock
900: Numero no formato "1.2.1.13.13.1", deve indicar o "padrao de teste" sendo validado
901: Numero no formato "1.2.1.13.13.1", deve indicar o "padrao de teste" sendo validado
```