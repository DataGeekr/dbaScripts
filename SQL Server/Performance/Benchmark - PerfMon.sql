Counters para criação do benchmark

Memory
     Available Mbytes - Quantidade de memória física, em MB, imediatamente disponível para um processo ou uso do sistema.
     Page Faults/sec - Quantidade de falhas de páginas não encontradas em memória. Hard faults requerem acesso ao disco.
     Pages/sec - Taxa na qual páginas são lidas ou escritas para o disco para resolver hard faults.

PhysicalDisk
     % Disk Time - Porcentagem de tempo gasto que o disco selecionado ficou ocupado servindo requisições de IO.
     Avg. Disk sec/Read - Tempo médio, em segundos, de uma lida de dados no disco.
     Avg. Disk sec/Write - Tempo médio, em segundos, de uma escrita de dados no disco.
     Current Disk Queue Length - Número de requisições realizadas sobre um disco no momento em que foi coletado.
     Disk Bytes/sec - Taxa de bytes que são transferidos para ou do disco durante operações de IO.
     Disk Transfers/sec - Taxa de operações de leitura e escrita no disco.

Processor
     % Privileged Time - Porcentagem de tempo gasto em threads de processos executando código em modo privilegiado.
     % Processor Time - Porcentagem de atividade do processador. (>80% = problem)

SQLServer:Access Methods
     FreeSpace Scans/sec - Núm. de scans por seg. iniciados para pesquisar por espaço livre dentro das páginas já alocadas para modificar fragmentos do registro.
     Full Scans/sec - Número de full scans irrestritos. Podem ser por tabela base ou full index scans.

SQLServer:Buffer Manager
     Buffer cache hit radio - Porcentagem de páginas encontradas no Buffer Pool que não precisaram ser lidos do disco. <97% = potencial memory pressure.
     Checkpoint pages/sec - Número de páginas que foram liberadas pelo checkpoint ou operações que requerem que pág. sujas sejam liberadas.
     Lazy writes/sec - Número de buffers escritos pelo gerenciador do Lazy Writer para o disco. Causado por grandes data cache flushes ou memory pressure. 
     Page life expectancy - Segundos que uma página ficará no buffer sem referência (<300 = problem)

SQLServer: General Statistics
     User Connections - Número de usuários conectados ao sistema.
     
SQLServer:Latches
     Total Latch Wait Time(ms) - Total de tempo de espera, em ms, para requisições de trava no último segundo.

SQLServer:Locks
     Lock Timeouts/sec - Número de requisições de lock que tiveram time out. Inclui NOWAIT locks.
     Lock Wait Time(ms) - Total de espera, em ms, por locks no último segundo.
     Number of Deadlocks/sec - Número de requisições de locks que resultaram em timeout.

SQLServer:Memory Manager
     Memory Grants Pending - Número atual de processos esperando por liberação de espaço de trabalho em memória.
     Target Server Memory(KB) - Tamanho ideal de memória que o servidor é capaz de consumir.
     Total Server Memory(KB) - Total de memória dinâmica que o servidor está atualmente consumindo.

SQLServer:Plan Cache
     Cache Hit Ratio:SQL Plans - <70% indica baixo reuso de planos.

SQLServer:SQL Statistics
     Batch Requests/sec - Número de requisições batch recebidas pelo servidor.
     SQL Compilations/sec - (Comparar com Batch Requests/sec)
     SQL Re-Compilations/sec - (Comparar com Batch Requests/sec)

System
     Context Switches/sec - (limite: >5000 x processor) Causas potenciais podem incluir outras aplicações no servidor ou outras instance.
     Processor Queue Length - (limite: >5 x processor) Causas potenciais podem incluir outras aplicações no servidor, compilações ou recompilações.
     
