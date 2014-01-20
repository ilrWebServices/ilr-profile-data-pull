<cfscript>
	request.df = {};
	request.df.ldap = {};
	request.df.ldap.start = "";
	request.df.ldap.attributes = "uid,displayName";
	request.df.ldap.filter = "";
	request.df.ldap.server = "";
	request.df.ldap.port = 0;
	request.df.ldap.username="";
	request.df.ldap.password = "";
	request.df.ldap.secure = "";

	request.df.ds = {};
	request.df.db.ds_cms = "";
	request.df.db.ds_legacy = "";
	request.df.db.ds_directory_info = "";
</cfscript>
