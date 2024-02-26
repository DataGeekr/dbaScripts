
WITH cteUserPermission
AS (
     SELECT [UserName] = CASE princ .[type]
                              WHEN 'S'
                              THEN princ. [name]
                              WHEN 'U'
                              THEN ulogin. [name] COLLATE Latin1_General_CI_AI
                         END
          , [UserType] = CASE princ .[type]
                              WHEN 'S' THEN 'SQL User'
                              WHEN 'U' THEN 'Windows User'
                         END
                     
          , [DatabaseUserName] = princ.[name]      
          , [Role] = null     
          , [PermissionType] = perm.[permission_name]      
          , [PermissionState] = perm.[state_desc]      
          , [ObjectType] = obj.type_desc
          , [ObjectName] = OBJECT_NAME( perm.major_id )
          , [ColumnName] = col.[name]
     FROM sys .database_principals princ  --database user
          LEFT JOIN
          sys.login_token ulogin --Login accounts
               ON princ. [sid] = ulogin .[sid]
          LEFT JOIN        
          sys.database_permissions perm --Permissions
               ON perm. [grantee_principal_id] = princ .[principal_id]
          LEFT JOIN
          sys.columns col --Table columns 
               ON  col. [object_id] = perm .major_id
               AND col. [column_id] = perm .[minor_id]
          LEFT JOIN
          sys.objects obj
               ON perm. [major_id] = obj .[object_id]
     WHERE princ. [type] in ('S', 'U')

    UNION

    --List permissions by role
    SELECT [UserName] = CASE memberprinc.[type]
                             WHEN 'S' THEN memberprinc .[name]
                             WHEN 'U' THEN ulogin .[name] COLLATE Latin1_General_CI_AI
                        END
         , [UserType] = CASE memberprinc .[type]
                             WHEN 'S' THEN 'SQL User'
                             WHEN 'U' THEN 'Windows User'
                        END
         , [DatabaseUserName] = memberprinc.[name]  
         , [Role] = roleprinc.[name]
         , [PermissionType] = perm.[permission_name]
         , [PermissionState] = perm.[state_desc]      
         , [ObjectType] = obj.type_desc
         , [ObjectName] = OBJECT_NAME( perm.major_id )
         , [ColumnName] = col.[name]
    FROM sys.database_role_members members     --Role/member associations
         INNER JOIN
         sys.database_principals roleprinc --Roles
               ON roleprinc. [principal_id] = members .[role_principal_id]
         INNER JOIN
         sys.database_principals memberprinc --Role members (database users)
               ON memberprinc. [principal_id] = members .[member_principal_id]
         LEFT JOIN
         sys.login_token ulogin --Login accounts
               ON memberprinc. [sid] = ulogin .[sid]
         LEFT JOIN        
         sys.database_permissions perm --Permissions
               ON perm. [grantee_principal_id] = roleprinc .[principal_id]
         LEFT JOIN
         sys.columns col --Table columns
               ON col. [object_id] = perm .major_id
                    AND col. [column_id] = perm .[minor_id]
         LEFT JOIN
         sys.objects obj
               ON perm. [major_id] = obj .[object_id]


    UNION

    -- Permissions granted by public roles
    SELECT [UserName] = '{All Users}'
         , [UserType] = '{All Users}'
         , [DatabaseUserName] = '{All Users}'      
         , [Role] = roleprinc.[name]
         , [PermissionType] = perm.[permission_name]
         , [PermissionState] = perm.[state_desc]   
         , [ObjectType] = obj.type_desc
         , [ObjectName] = OBJECT_NAME( perm.major_id )
         , [ColumnName] = col.[name]
    FROM sys.database_principals roleprinc --Roles
         LEFT JOIN        
         sys.database_permissions perm  --Role permissions
               ON perm. [grantee_principal_id] = roleprinc .[principal_id]
         LEFT JOIN
         sys.columns col --Table columns
               ON col. [object_id] = perm .major_id
               AND col. [column_id] = perm .[minor_id]                  
         INNER JOIN
         sys.objects obj
               ON obj. [object_id] = perm .[major_id]
    WHERE
        --Only roles
        roleprinc .[type] = 'R' AND
        --Only public role
        roleprinc .[name] = 'public' AND
        --Only objects of ours, not the MS objects
        obj .is_ms_shipped = 0
)

SELECT *
FROM cteUserPermission
WHERE (1 =1) AND UserName = 'OabIntegracao'
ORDER BY UserName


    