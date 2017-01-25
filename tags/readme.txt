Easiest way to get access to this tag is to import it as a tabLib:

<cfimport taglib="/model/dataMgr/tags" prefix="dmTag">

After which, you have access to all tags like:

<dmTag:dmQuery dataMgr="{dataMgr}" name="{name}">
	SELECT <dmTag:dmSQL method="getSelectSQL" tablename=''>
	  FROM ...
	 WHERE 1=1
	       <dmTag:dmSQL method="getWhereSQL" tablename="{name}" data="{data}">
</dmTag:dmQuery>
