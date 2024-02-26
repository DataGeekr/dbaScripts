SELECT  [sa].[account_id]
, [sa].[name] as [Profile_Name]
, [sa].[description]
, [sa].[email_address]
, [sa].[display_name]
, [sa].[replyto_address]
, [ss].[servertype]
, [ss].[servername]
, [ss].[port]
, [ss].[username]
, [ss].[use_default_credentials]
, [ss].[enable_ssl]
FROM msdb.dbo.sysmail_account sa
      INNER JOIN msdb.dbo.sysmail_server ss
ON  sa.account_id = ss.account_id
