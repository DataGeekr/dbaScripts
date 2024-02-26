SELECT value_name,
       value_data ,
       registry_key
FROM  sys .dm_server_registry
where value_name like 'SQLArg%';