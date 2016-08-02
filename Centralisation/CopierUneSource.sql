
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CopierUneSource]') AND type in (N'P', N'PC'))
DROP PROCEDURE CopierUneSource
GO

CREATE PROCEDURE CopierUneSource(
	@IDSourceTarget INT
)
AS
BEGIN
	DECLARE 
	@SourceDatabase VARCHAR(250)
	,@TargetDatabase VARCHAR(250)

	-- TODO Prendre en compte la table TPropagation
	-- TODO Pour éviter les conflits synonym utiliser infostatus, cf. Gestion individuhistory 
	
	SELECT @SourceDatabase = [SourceDatabase],@TargetDatabase=TargetDatabase
	FROM SourceTarget
	WHERE ID=@IDSourceTarget


	

	DECLARE @cur_SQL NVARCHAR(MAX)
	SET @cur_SQL = 'IF EXISTS (SELECT * FROM sys.synonyms WHERE name = ''SysColonne'')  drop synonym SysColonne ; CREATE SYNONYM SysColonne FOR ' + replace(@SourceDatabase,'dbo.','sys.') + 'columns'
	print @cur_SQL
	exec sp_executesql @cur_SQL

	SET @cur_SQL = 'IF EXISTS (SELECT * FROM sys.synonyms WHERE name = ''SysObject'')  drop synonym SysObject ; CREATE SYNONYM SysObject FOR ' + replace(@SourceDatabase,'dbo.','sys.') + 'objects'
	print @cur_SQL
	exec sp_executesql @cur_SQL

	DECLARE @TableName VARCHAR(250)
	,@TabidName VARCHAR(250)

	DECLARE c_table CURSOR FOR
		select [Name] ,[IdNamere] 
		FROM TableACopier T JOIN [SourceTarget_Table] S ON t.ID = S.fk_TableACopier
		WHERE S.[fk_SourceTarget] = @IDSourceTarget
		ORDER by [OrdreExecution]


	OPEN c_table   
	FETCH NEXT FROM c_table INTO @TableName, @TabidName  

	WHILE @@FETCH_STATUS = 0   
	BEGIN   
		-- TODO Gérer les exceptions
		

		print 'Traitement de la table '+ @TableName

		IF OBJECT_ID('tempdb..#IdToUpdate') IS NOT NULL
		DROP TABLE #IdToUpdate

		CREATE TABLE #IdToUpdate(ID INT )

		DECLARE @SQLOld nvarchar(max)
		,@SQLNew nvarchar(max)
		,@SQLFinalUpdate nvarchar(max)
		,@SQLInsert nvarchar(max)
		,@SQLSelectinInsert nvarchar(max)

		SET @SQLOld='SELECT '
		SET @SQLNew='SELECT '
		SET @SQLFinalUpdate='UPDATE OLd SET '
		SET @SQLInsert = 'SET IDENTITY_INSERT ' +  @TargetDatabase + @TableName + ' ON; INSERT INTO  ' + @TargetDatabase + @TableName + '(' + @TabidName 
		SET @SQLSelectinInsert=@TabidName


		SELECT @SQLOld = @SQLOld + c.name + ',' 
		,@SQLNew=@SQLNew+c.name + ',' 
		,@SQLFinalUpdate=CASE WHEN c.name = @TabidName THEN @SQLFinalUpdate ELSE @SQLFinalUpdate + c.name + ' = New.' + c.name + ','    END
		,@SQLInsert = CASE WHEN c.name = @TabidName THEN @SQLInsert ELSE @SQLInsert + ',' + c.name END
		,@SQLSelectinInsert = CASE WHEN c.name = @TabidName THEN @SQLSelectinInsert ELSE @SQLSelectinInsert + ',' + c.name END
		FROM SysColonne c JOIN SysObject o ON c.object_id = o.object_id 
		WHERE o.name = @TableName and o.type='U'
		and c.system_type_id not in (35)


		SET @SQLOld = @SQLOld +'#FROM ' + @TargetDatabase +  @TableName 
		SET @SQLOld = replace(@SQLOld,',#FROM',' FROM')

		SET @SQLNew = @SQLNew +'#FROM ' + @SourceDatabase +  @TableName 
		SET @SQLNew = replace(@SQLNew,',#FROM',' FROM')


		SET @cur_SQL = 'SELECT ' + @TabidName + '  FROM (' + @SQLNew  + ' EXCEPT ' + @SQLOld + ') E'
		INSERT INTO #IdToUpdate
		exec sp_executesql @cur_SQL

		print @cur_SQL

		select * from #IdToUpdate
		--TODO Prendre en compte la table Tpropagation




		SET @SQLFinalUpdate = @SQLFinalUpdate + '#FROM  ' + @TargetDatabase +  @TableName + ' Old  JOIN ' + @SourceDatabase +  @TableName + ' New ON Old.' +  @TabidName + '= New.' +  @TabidName
		SET @SQLFinalUpdate = @SQLFinalUpdate + ' WHERE Old.' + @TabidName + ' IN (SELECT  ID FROM #IdToUpdate) ' 

		SET @SQLFinalUpdate = replace(@SQLFinalUpdate,',#FROM',' FROM')


		-- TODO Gérer les suppressions ???????
		print @SQLFinalUpdate
		exec sp_executesql @SQLFinalUpdate
		


		SET @SQLInsert = @SQLInsert + ') select ' + @SQLSelectinInsert+ ' FROM ' + @SourceDatabase + @TableName + ' New where ' + @TabidName + ' not in (select ' + @TabidName + ' FROM ' + @TargetDatabase + @TableName + ') AND  New.' + @TabidName + ' IN (SELECT  ID FROM #IdToUpdate)  ;SET IDENTITY_INSERT ' +  @TargetDatabase + @TableName + ' OFF '
		print @SQLInsert

		exec sp_executesql @SQLInsert


		FETCH NEXT FROM c_table INTO @TableName, @TabidName  

	END

	CLOSE c_table   
	DEALLOCATE c_table
END

