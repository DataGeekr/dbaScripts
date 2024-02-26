SELECT session_id
        , wait_type
        , wait_duration_ms
        , blocking_session_id
        , resource_description
        , ResourceType = CASE WHEN Cast(Right( resource_description, Len(resource_description ) - Charindex(':', resource_description, 3 )) AS INT) - 1 % 8088 = 0
                                 THEN 'Is PFS Page'
                               WHEN Cast (Right(resource_description, Len(resource_description ) - Charindex(':', resource_description, 3 )) AS INT) - 2 % 511232 = 0
                                 THEN 'Is GAM Page'
                               WHEN Cast (Right(resource_description, Len(resource_description ) - Charindex(':', resource_description, 3 )) AS INT) - 3 % 511232 = 0
                                 THEN 'Is SGAM Page'
                               ELSE 'Is Not PFS, GAM, or SGAM page'
                          END
FROM sys .dm_os_waiting_tasks
WHERE wait_type LIKE 'PAGE%LATCH_%'
        AND resource_description LIKE '2:%'