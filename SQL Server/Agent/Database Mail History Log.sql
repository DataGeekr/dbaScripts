SELECT items.subject 
     , items.recipients 
     , items.copy_recipients 
     , items.blind_copy_recipients 
     , items.sent_status 
     , items.send_request_date 
     , items.sent_date 
     , l.description 
FROM  msdb.dbo.sysmail_faileditems AS items 
      LEFT OUTER JOIN 
      msdb.dbo.sysmail_event_log AS l 
            ON items.mailitem_id = l.mailitem_id 
WHERE items.last_mod_date > DATEADD(DAY, -1, GETDATE()) 
ORDER BY items.mailitem_id DESC;

