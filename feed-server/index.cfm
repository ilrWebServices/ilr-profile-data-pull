<cfsetting enableCFoutputOnly = "yes">
<cfinclude template="feed-config.cfm">  <!--- Defines values in request.df struct --->

<cfscript>
  missing_attributes = false;
  for (struct in request.df) {
    for (item in request.df[struct]) {
        if (request.df[struct][item] eq 0 OR Len(Trim(request.df[struct][item])) eq 0) {
          missing_attributes = true;
        }
    }
  }

  if (missing_attributes) {
    writeOutput("Error: Please ensure a complete configuration has been supplied for the feed.");
    abort;
  }

  private string function writeXMLEntity(string name, string text, boolean cdata=false) {

    content = trim(replacenocase(replacenocase(arguments.text, "&nbsp;", " ", "ALL"), " & ", " &amp; ", "ALL"));
    content = replacenocase(content, "<br>", "<br/>", "ALL");
    content = replacenocase(content, "A&M", "A&amp;M", "ALL");

    if (Len(content)) {
      if (arguments.cdata) {
        content = "<![CDATA[ #content# ]]>";
      }
      return "<#arguments.name#>#content#</#arguments.name#>";
    } else {
      return "<#arguments.name#/>";
    }
  }

  private any function newObj(string obj) {
    return CreateObject("component", arguments.obj);
  }

  ldapService = new ldap();
  ldapQry = ldapService.query(argumentCollection=request.df.ldap);
</cfscript>


<cfoutput><?xml version="1.0" encoding="UTF-8"?>
<Data dmd:date="2010-02-23" xmlns="http://www.digitalmeasures.com/schema/data" xmlns:dmd="http://www.digitalmeasures.com/schema/data-metadata">
</cfoutput>

<cfloop query="ldapQry">
  <cfset local.uid = ldapQry.uid>

  <!-- Publications -->
  <cfquery name="getpubvars" datasource="#request.df.db.ds_cms#">
  SELECT  wi.instance, wi.pageID, p.pid,
          uid.argumentValue             AS uid,
          publicationType.argumentValue AS publicationType,
          displayType.argumentValue     AS displayType
  FROM    vWidgetInstances AS wi
          LEFT OUTER JOIN
            pageWidgetArguments AS uid
              ON wi.instance = uid.instance
              AND uid.argumentName = 'uid'
          LEFT OUTER JOIN
            pageWidgetArguments AS publicationType
              ON wi.instance = publicationType.instance
              AND publicationType.argumentName = 'publicationType'
          LEFT OUTER JOIN
            pageWidgetArguments AS displayType
              ON wi.instance = displayType.instance
              AND displayType.argumentName = 'displayType'
          LEFT OUTER JOIN
            people.dbo.people AS p
              ON wi.widgetName = 'publication' AND wi.instance = uid.instance
              AND uid.argumentName = 'uid' AND p.netid = uid.argumentValue
  WHERE   wi.widgetName = 'publication'
          AND uid.argumentValue = '#local.uid#'
  ORDER BY wi.pageID
  </cfquery>

  <cfif getpubvars.recordcount eq 0>
    <cfquery datasource="#request.df.db.ds_directory_info#" name="get">
      SELECT pid
      FROM people
      WHERE netid = '#local.uid#'
    </cfquery>
    <cfif get.recordcount gt 0>
      <cfset queryAddRow(getpubvars)>
      <cfset querySetCell(getpubvars, "instance", '0', 1)>
      <cfset querySetCell(getpubvars, "uid", '#local.uid#', 1)>
      <cfset querySetCell(getpubvars, "pageid", '0', 1)>
      <cfset querySetCell(getpubvars, "pid", '#get.pid#', 1)>
      <cfset querySetCell(getpubvars, "publicationtype", 'doc', 1)>
    </cfif>
  </cfif>

  <cfif getpubvars.recordcount gt 0>
    <cfloop query="getpubvars">
      <cfoutput>
          <Record username="#local.uid#">
      </cfoutput>

      <cfswitch expression="#publicationType#">
        <cfcase value="doc">
          <cfset tmpPublication = newObj("ilr.publication2").get(getpubvars.pid)>
          <cfset publicationDoc = trim(tmpPublication.publicationDoc)>

          <cfif len(publicationDoc) gt 0>
            <cfoutput><ilrweb_publications_doc>#publicationDoc#</ilrweb_publications_doc>
            <ilrweb_publications source="doc"/>
            </cfoutput>
          <cfelse>
            <cfoutput><ilrweb_publications_doc/>
            <ilrweb_publications source="doc"/>
            </cfoutput>
          </cfif>
        </cfcase>

        <cfcase value="text">
          <cfset tmpPublication = newObj("ilr.publication2").get(getpubvars.pid)>
          <cfset publicationText = trim(tmpPublication.publicationText)>

          <cfif len(publicationText) gt 0><cfoutput>
            <ilrweb_publications_doc/>
            <ilrweb_publications source="text"><![CDATA[
            #publicationText#
            ]]></ilrweb_publications></cfoutput>
          <cfelse>
              <cfoutput>
              <ilrweb_publications_doc/>
              <ilrweb_publications source="text"/>
              </cfoutput>
          </cfif>
        </cfcase>

        <cfcase value="database">
          <cfquery datasource="#request.df.db.ds_legacy#" name="getPublications">
            SELECT pt.pt_id, pt.priority, pt.group_title, p.*
            FROM pubtype pt
              INNER JOIN publication p ON p.pub_typeid = pt.pt_id
            WHERE p.staff_id = '#uid#'
            <cfif getpubvars.displayType eq "selected">AND p.pub_selected = 1</cfif>
            ORDER BY pt.priority
          </cfquery>

          <cfif getPublications.recordCount GT 0>
            <cfoutput>
              <ilrweb_publications_doc/>
              <ilrweb_publications source="database"><![CDATA[
          </cfoutput>
            <cfset lastGroupTitle = "">
            <cfloop query="getPublications">
              <cfoutput>
              <cfif group_title neq lastGroupTitle>
                <h3>#group_title#</h3>
                <ul>
                <cfset lastGroupTitle = group_title>
              </cfif>
                <li>
                <cfif len(trim(pub_title))>#pub_title# </cfif>
                <cfif len(trim(pub_otherauthors))> (with #pub_otherauthors#) </cfif>
                <cfif len(trim(pub_publication))>; #pub_publication# </cfif>
                <cfif len(trim(pub_publisher))>; #pub_publisher# </cfif>
                <cfif len(trim(pub_pubdate))>; #pub_pubdate#</cfif>
                <cfif (trim(doc_id) neq "") and (trim(pub_filename) neq "")>&nbsp;&nbsp;<a href="/directory/download.htm?id=#doc_id#" target="_blank">Downloadxxx</a></cfif>
                <cfif len(trim(pub_url))>
                  <cfif ReFindNoCase("http://|ftp://", trim(pub_url)) lt 1>
                    <cfset theURL = "http://#trim(pub_url)#">
                  <cfelse>
                    <cfset theURL = trim(pub_url)>
                  </cfif>
                  &nbsp;&nbsp;<a href="#theURL#">Read it Online</a>
                </cfif>
                </li>
              <cfif currentrow eq recordcount OR group_title[currentrow + 1] neq group_title></ul></cfif>
              </cfoutput>
            </cfloop>
            <cfoutput>
              ]]></ilrweb_publications></cfoutput>
          <cfelse>
            <cfoutput>
            <ilrweb_publications_doc/>
            <ilrweb_publications source="database" />
            </cfoutput>
          </cfif>
        </cfcase>
      </cfswitch>

      <!--- Biography --->
      <cfset widgetText = newObj("ilr.biography").get(getpubvars.pid)>
      <cfoutput>
        #writeXMLEntity("ilrweb_biography", trim(widgetText), true)#</cfoutput>

      <!--- Experience --->
      <cfset widgetText = newObj("ilr.experience").get(getpubvars.pid)>
      <cfoutput>
        #writeXMLEntity("ilrweb_experience", trim(widgetText))#</cfoutput>

      <!--- Research --->
      <cfset widgetText = newObj("ilr.research2").get(getpubvars.pid).researchText>
      <cfoutput>
        #writeXMLEntity("ilrweb_research", trim(widgetText))#</cfoutput>

      <!--- Expertise --->
      <cfquery name="expertiseListAssigned" datasource="#request.df.db.ds_directory_info#">
        SELECT expertiseName, expertiseID
        FROM expertise
        WHERE expertiseID IN (
          SELECT expertiseID
          FROM expertiseAssignment
          WHERE personObjectID = (SELECT personObjectID FROM people WHERE pid = #getpubvars.pid#))
        ORDER BY expertiseName
      </cfquery>

      <cfif expertiseListAssigned.recordcount gt 0>
        <cfoutput>
          <ilrweb_expertise>
          <cfloop query="expertiseListAssigned">
            <ilrweb_expert>#expertiseName#</ilrweb_expert>
          </cfloop>
          </ilrweb_expertise>
        </cfoutput>
      <cfelse>
        <cfoutput>
          <ilrweb_expertise/></cfoutput>
      </cfif>

      <!--- Other Expertise --->
      <cfset widgetText = newObj("ilr.expertise2").get(getpubvars.pid)>
      <cfoutput>
        #writeXMLEntity("ilrweb_other_expertise", trim(widgetText))#</cfoutput>

      <!--- Vita --->
      <cfset tmpVita = newObj("ilr.vita").get(getpubvars.pid)>
      <cfif tmpVita.vita contains '.pdf' AND FileExists('d:/inetpub/ilrwww#tmpVita.vita#')>
        <cfoutput>
          <ilrweb_vita_file>http://www.ilr.cornell.edu#tmpVita.vita#</ilrweb_vita_file>
          <ilrweb_vita_html/>
        </cfoutput>
      <cfelseif len(trim(tmpVita.vitaText))>
        <cfoutput>
          <ilrweb_vita_file/>
          <ilrweb_vita_html><![CDATA[
          #tmpVita.vitaText#
          ]]> </ilrweb_vita_html>
        </cfoutput>
      <cfelse>
        <cfoutput>
          <ilrweb_vita_file/>
          <ilrweb_vita_html/>
        </cfoutput>
      </cfif>

      <!--- image --->
      <cfif FileExists('d:/inetpub/ilrwww/directory/#local.uid#/#local.uid#.jpg')>
        <cfoutput>
          <ilrweb_photo_url>http://www.ilr.cornell.edu/directory/#local.uid#/#local.uid#.jpg</ilrweb_photo_url></cfoutput>
      <cfelse>
        <cfoutput>
          <ilrweb_photo_url/></cfoutput>
      </cfif>

      <cfoutput>
        </Record>
      </cfoutput>
    </cfloop>
  </cfif>
</cfloop>

<cfoutput>
 </Data>
</cfoutput>

<cfsetting enableCFoutputOnly = "no">
