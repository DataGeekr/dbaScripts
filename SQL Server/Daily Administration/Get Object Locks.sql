SELECT   t1.resource_type
       , t1.resource_database_id
       , t1.resource_associated_entity_id
       , t1.request_mode
       , t1.request_session_id
       , t2.blocking_session_id
       , o1.name 'object name'
       , o1.type_desc 'object descr'
       , p1.partition_id 'partition id'
       , p1.rows 'partition/page rows'
       , a1.type_desc 'index descr'
       , a1.container_id 'index/page container_id'
FROM     sys.dm_tran_locks AS t1
         INNER JOIN sys.dm_os_waiting_tasks AS t2
            ON t1.lock_owner_address = t2.resource_address
         LEFT OUTER JOIN sys.objects o1
            ON o1.object_id = t1.resource_associated_entity_id
         LEFT OUTER JOIN sys.partitions p1
            ON p1.hobt_id = t1.resource_associated_entity_id
         LEFT OUTER JOIN sys.allocation_units a1
            ON a1.allocation_unit_id = t1.resource_associated_entity_id;