DBCC FREEPROCCACHE
	All plans: DBCC FREEPROCCACHE
	Single Plan: DBCC FREEPROCCACHE(plan_handle)
	All plans for a single database: DBCC FLUSHPROCINDB(DBID)
	
DBCC FREESYSTEMCACHE( 'ALL' [, pool_name ] ) [WITH {[MARK_IN_USE_FOR_REMOVAL], [NO_INFOMSGS]}]
	All ad hoc and prepared plans: DBCC FREESYSTEMCACHE( N'SQL Plans')
