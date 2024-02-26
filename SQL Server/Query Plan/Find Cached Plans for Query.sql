SELECT cp.objtype AS ObjectType,
       bucketid,
       OBJECT_NAME(st.objectid, st.dbid) AS ObjectName,
       objtype,
       cp.usecounts AS ExecutionCount,
       st.text AS QueryText,
       qp.query_plan AS QueryPlan
FROM sys.dm_exec_cached_plans AS cp
    CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) AS qp
    CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) AS st
WHERE OBJECT_NAME(st.objectid, st.dbid) = 'spu_CnaWS_ConsultaAdvogado'
      --OR    text LIKE '%'
      OR text LIKE '%COALESCE(EndCom.NumrTelf, EndRes.NumrTelf, EndCom.NumrTelfCel, EndRes.NumrTelfCel, '''')%';


