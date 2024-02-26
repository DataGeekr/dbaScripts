DECLARE @CoreCount int;
DECLARE @NumaNodes int;

SET @CoreCount = (SELECT i.cpu_count from sys.dm_os_sys_info i);
SET @NumaNodes = (
    SELECT MAX(c.memory_node_id) + 1
    FROM sys.dm_os_memory_clerks c
    WHERE memory_node_id < 64
    );

IF @CoreCount > 4 /* If less than 5 cores, don't bother.*/
BEGIN
    DECLARE @MaxDOP int ;

    /* 3/4 of Total Cores in Machine */
    SET @MaxDOP = @CoreCount * 0.75;

    /* if @MaxDOP is greater than the per NUMA node
       Core Count, set @MaxDOP = per NUMA node core count
    */
    IF @MaxDOP > (@CoreCount / @NumaNodes)
        SET @MaxDOP = (@CoreCount / @NumaNodes ) * 0.75;

    /*
        Reduce @MaxDOP to an even number
    */
    SET @MaxDOP = @MaxDOP - ( @MaxDOP % 2);

    /* Cap MAXDOP at 8, according to Microsoft */
    IF @MaxDOP > 8 SET @MaxDOP = 8;

    PRINT 'Suggested MAXDOP = ' + CAST( @MaxDOP as varchar(max));
END
ELSE
BEGIN
    PRINT 'Suggested MAXDOP = 0 since you have less than 4 cores total.' ;
    PRINT 'This is the default setting, you likely do not need to do' ;
    PRINT 'anything.';
END