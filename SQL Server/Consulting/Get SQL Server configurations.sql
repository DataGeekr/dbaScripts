select * 
from sys .configurations 
where name in ( 'cost threshold for parallelism' 
                         , 'max worker threads' 
                         , 'max degree of parallelism' 
                         , 'remote admin connections' 
                         , 'max server memory (MB)' 
                         , 'xp_cmdshell' 
                         , 'Ole Automation Procedures' 
                         , 'Agent XPs' 
                        ) 
