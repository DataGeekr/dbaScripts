DECLARE @FotoAdvo    VARBINARY(MAX)
      , @NomeAdvo    VARCHAR(84)
      , @DestPath    VARCHAR(MAX)
      , @ObjectToken INT


DECLARE curImageData CURSOR FAST_FORWARD
   FOR
      select img.Foto, m.Nome
      from OabDigital..v_Membro m
      inner join OabDigital..Membro m2 on m.IdenMembro = m2.IdenMembro
      inner join OabDigital..SetorMembro sm on m.IdenMembro = sm.IdenMembro
      inner join IdentidadeDoAdvogadoImg..AdvogadoImagem img on m2.IdtAdvo = img.IdtAdvo
      where sm.IdenOgan in (select IdenOgan from geral..Organizacao where IdenTipoIden = 1)
      and sm.CodiSetr = 124
      and sm.IdenStatus = 5


OPEN curImageData

FETCH NEXT FROM curImageData INTO @FotoAdvo, @NomeAdvo

WHILE @@FETCH_STATUS = 0
BEGIN
SET @DestPath = 'Z:\FotoAdvogado\' + @NomeAdvo + '.jpg'
EXEC sp_OACreate 'ADODB.Stream', @ObjectToken OUTPUT
EXEC sp_OASetProperty @ObjectToken, 'Type', 1
EXEC sp_OAMethod @ObjectToken, 'Open'
EXEC sp_OAMethod @ObjectToken, 'Write', NULL, @FotoAdvo
EXEC sp_OAMethod @ObjectToken, 'SaveToFile', NULL, @DestPath, 2
EXEC sp_OAMethod @ObjectToken, 'Close'
EXEC sp_OADestroy @ObjectToken

FETCH NEXT FROM curImageData INTO @FotoAdvo, @NomeAdvo
END

CLOSE curImageData
DEALLOCATE curImageData