<cfcomponent extends="_DataMgr">

<!--- --------------------- --->
<!--- [ DataMgr Overrides ] --->
<!--- --------------------- --->

<!--- [ Override deleteRecords() ] --->
<cffunction name="deleteRecords" access="public" returntype="void" output="no" hint="I delete the records with the given data.">
	<cfargument name="tablename" type="string" required="yes" hint="The name of the table from which to delete a record.">
	<cfset var local = structNew()>
	<cfset local.fields = getUpdateableFields(arguments.tablename)>
	<cfset local.sqlArray = arrayNew(1)>
	
	<cfif isLogicalDeletion(arguments.tablename)>
		<cfset arguments.data_set = structNew()>
		<cfif structKeyExists(arguments, 'data')><cfset arguments.data_where = arguments.data></cfif>
		
		<cfloop index="i" from="1" to="#ArrayLen(fields)#" step="1">
			<cfif structKeyExists(local.fields[i],"Special") AND local.fields[i].Special EQ "DeletionMark">
				<cfif local.fields[i].CF_DataType EQ "CF_SQL_BIT">
					<cfset arguments.data_set[local.fields[i].ColumnName] = 1>
				<cfelseif local.fields[i].CF_DataType EQ "CF_SQL_DATE" OR local.fields[i].CF_DataType EQ "CF_SQL_DATETIME">
					<cfset arguments.data_set[local.fields[i].ColumnName] = now()>
				</cfif>
			</cfif>
		</cfloop>
		
		<cfset arrayAppend(local.sqlArray, updateRecordsSQL(argumentCollection=arguments))>
	<cfelse>		
		<cfset arrayAppend(local.sqlArray, "DELETE FROM #escape(arguments.tablename)# WHERE	1 = 1")>
		<cfset arrayAppend(local.sqlArray, getWhereSQL(argumentCollection=arguments))>
	</cfif>		

	<cfset runSQLArray(local.sqlArray)>	
</cffunction>


<!--- ---------------------- --->
<!--- [ DataMgr Extensions ] --->
<!--- ---------------------- --->

<!--- [ Extension getColumnList() ] --->
<cffunction name="getColumnList" access="public" returntype="string" output="no" hint="I return the registered list of columns for a table.">
	<cfargument name="tablename" type="string" required="yes" hint="The name of the table from which to delete a record.">
	<cfargument name="includeRelations" type="boolean" default="true" hint="Include Relation Columns">
	<cfset var local = structNew()>
	<cfset local.columnList = ''>
	
	<cfloop array="#getTableData(arguments.tablename)[arguments.tablename]#" index="local.item">
		<cfif arguments.includeRelations
		   || (!arguments.includeRelations && !structKeyExists(local.item, 'relation'))>
			<cfset local.columnList = listAppend(local.columnList, local.item.columnName)>
		</cfif>
	</cfloop>	
	
	<cfreturn local.columnList>	
</cffunction>

<!--- [ Extension getListInSQL() ] --->
<cffunction name="getListInSQL" access="public" returntype="string" output="no" hint="I SQL check a List Property against a List">
	<cfargument name="property" type="string" required="yes" hint="The Property to check agains">
	<cfargument name="list" type="string" required="yes" hint="The List of items to check">
	<cfset var local = {}>
	<cfset local.rtnString = "(1=0">
	<cfset arguments.list = reReplace(arguments.list, '\s*,\s*', ',', 'all')>
	
	<cfloop list="#arguments.list#" index="local.item">
		<cfset local.rtnString &= "
			OR #arguments.property# = '#local.item#'
			OR #arguments.property# LIKE '#local.item#,%' 
			OR #arguments.property# LIKE '%,#local.item#,%' 
			OR #arguments.property# LIKE '%,#local.item#'">
	</cfloop>
	
	<cfreturn local.rtnString & ')'>	
</cffunction>

<!--- [ Function: getRecordCount() ] --->
<cffunction name="getRecordCount" access="public" returntype="numeric" output="no" hint="I return the record count of a query">
	<cfset var local = {}>
	<cfset local.sqlArray = getRecordsSql(argumentCollection = arguments)>	
	<cfset local.sqlArray[2] = ["COUNT(*) rtnCount"]>
	<cfloop from="7" to="#arrayLen(local.sqlArray)#" index="local.item">
		<cfset arrayDeleteAt(local.sqlArray, 7)>
	</cfloop>

	<cfreturn runSqlArray(local.sqlArray).rtnCount>	
</cffunction>

<!--- [ Function: sqlArrayToSql() - Returns SQL from a SQL Array ] --->
<cffunction name="sqlArrayToSql" access="public" returntype="string" hint="">
	<cfargument name="sqlArray" type="array" required="yes">
	<cfset var local = {}>
	<cfset arguments.sqlArray = cleanSQLArray(arguments.sqlarray)>
	<cfset local.rtnString = ''>
	
	<cfloop from="1" to="#arrayLen(arguments.sqlArray)#" step="1" index="local.ii">
		<cfif IsSimpleValue(arguments.sqlArray[local.ii])>
			<cfset local.rtnString &= ' ' & trim(DMPreserveSingleQuotes(arguments.sqlArray[local.ii]))>
		<cfelseif IsStruct(arguments.sqlArray[local.ii])>
			<cfset arguments.sqlArray[local.ii] = queryparam(argumentCollection=arguments.sqlArray[local.ii])>
			<cfswitch expression="#arguments.sqlArray[local.ii].cfsqltype#">
				<cfcase value="CF_SQL_BIT"><cfset rtnString &= ' ' & getBooleanSqlValue(arguments.sqlArray[local.ii].value)></cfcase>
				<cfcase value="CF_SQL_DATE,CF_SQL_DATETIME"><cfset rtnString &= ' ' & CreateODBCDateTime(arguments.sqlArray[local.ii].value)></cfcase>
				<cfcase value="CF_SQL_TIME,CF_SQL_TIMESTAMP"><cfset rtnString &= ' ' & CreateODBCDateTime(arguments.sqlArray[local.ii].value)></cfcase>
				<cfcase value="CF_SQL_BIGINT,CF_SQL_DECIMAL,CF_SQL_DOUBLE,CF_SQL_FLOAT,CF_SQL_INTEGER,CF_SQL_MONEY,CF_SQL_MONEY4,CF_SQL_NUMERIC,CF_SQL_REAL,CF_SQL_SMALLINT,CF_SQL_TINYINT">
					<cfset rtnString &= ' ' & arguments.sqlArray[local.ii].value>
				</cfcase>
				<cfdefaultcase>
					<cfif arguments.sqlArray[local.ii].value IS 'NULL'>
						<cfset rtnString &= ' ' & arguments.sqlArray[local.ii].value>
					<cfelse>
						<cfif getDatabaseDriver() EQ 'mySql'>
							<cfset rtnString &= " CAST('" & arguments.sqlArray[local.ii].value & "' AS CHAR)">
						
						<cfelse>
							<cfset arguments.sqlArray[local.ii].value = replace(arguments.sqlArray[local.ii].value, "'", "''", "all")>
							<cfset arguments.sqlArray[local.ii].length = structKeyExists(arguments.sqlArray[local.ii], 'length')? arguments.sqlArray[local.ii].length : 'MAX'>
							<cfset rtnString &= " CAST('" & arguments.sqlArray[local.ii].value & "' AS [" & listLast(arguments.sqlArray[local.ii].cfsqltype, '_') & '](' & arguments.sqlArray[local.ii].length  & '))'>
						</cfif>
					</cfif>
				</cfdefaultcase>
			</cfswitch>
		</cfif>
	</cfloop>

	<cfreturn local.rtnString>
</cffunction>
</cfcomponent>