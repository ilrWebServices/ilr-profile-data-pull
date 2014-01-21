<?php

/**
 * @file
 * Functions for pulling data from ldap, Activity Insight, and legacy ilr web directory
 *
 *
 */

require 'ilr-faculty-data-conf.php';

function verify_configuration() {
	$result = true;
	$config_vars = [
	'AI_API_URL'
	, 'AI_USERID'
	, 'AI_PWD'
	, 'LDAP_START'
	, 'LDAP_ATTRIBUTES'
	, 'LDAP_FILTER'
	, 'LDAP_SERVER'
	, 'LDAP_PORT'
	, 'LDAP_USERNAME'
	, 'LDAP_PASSWORD'];

	foreach ($config_vars as $config) {
		if (empty($GLOBALS[$config])) {
			$result = false;
		}
	}
	return $result;
}

$LDAP_ATTRIBUTES = ['sn'
	, 'givenname'
	, 'mailnickname'
	, 'title'
	, 'physicaldeliveryofficename'
	, 'telephonenumber'
	, 'displayname'
	, 'department'
	, 'employeetype'
	, 'personaltitle'
	, 'uid'
	, 'mail'];

function query_ai($uri) {
	$curl = curl_init();
	curl_setopt_array($curl, array( CURLOPT_URL => $GLOBALS['AI_API_URL'] . $uri
	, CURLOPT_USERPWD => $GLOBALS['AI_USERID'] . ':' . $GLOBALS['AI_PWD']
	, CURLOPT_ENCODING => 'gzip'
	, CURLOPT_FOLLOWLOCATION => true
	, CURLOPT_POSTREDIR => true
	, CURLOPT_RETURNTRANSFER => true
	));

	$responseData = curl_exec($curl);

	if (curl_errno($curl)) {
		$errorMessage = curl_error($curl);
		// TODO: Handle cURL error
	} else {
		$statusCode = curl_getinfo($curl, CURLINFO_HTTP_CODE);
	}
	curl_close($curl);
	return (object)array("responseData" => $responseData, "statusCode" => $statusCode);
}

function xslt_transform($xml, $xsl, $format='xml') {
	$inputdom =  new DomDocument();
	$inputdom->loadXML($xml);

	$proc = new XSLTProcessor();
	$proc->importStylesheet($xsl);
	$proc->setParameter(null, "", "");
	if ($format == 'xml') {
		return $proc->transformToXML($inputdom);
	} else if ($format == 'doc') {
		return $proc->transformToDoc($inputdom);
	}
}

function doc_append(&$doc1, $doc2) {
	// get 'Data' element of document 1
	// $data = $doc1->getElementsByTagName('Data')->item(0);

	// iterate over 'item' elements of document 2
	$records = $doc2->getElementsByTagName('Record');
	for ($i = 0; $i < $records->length; $i ++) {
	    $record = $records->item($i);

	    // import/copy item from document 2 to document 1
	    $temp = $doc1->importNode($record, true);

	    // append imported item to document 1 'res' element
	    $doc1->getElementsByTagName('Data')->item(0)->appendChild($temp);
	}
}

function get_ilr_profiles_transform_xsl() {
	$xsl = new DOMDocument();
	$xsl->load('digital-measures-faculty-public.xsl');
	return $xsl;
}

function get_ai_departments() {
	$URI = '/SchemaIndex/INDIVIDUAL-ACTIVITIES-University/DEPARTMENT';
	return query_ai($URI);
}

function get_ai_users() {
	$URI = '/User/INDIVIDUAL-ACTIVITIES-University/COLLEGE:School%20of%20Industrial%20and%20Labor%20Relations';
	return query_ai($URI);
}

function get_ai_person($netid) {
	$URI = '/SchemaData/INDIVIDUAL-ACTIVITIES-University/USERNAME:' . $netid;
	return query_ai($URI);
}

function get_ai_record_from_data($xml) {
	$string = str_replace('<?xml version="1.0" encoding="UTF-8"?>', '', $xml);
	$string = preg_replace('/<\/*Data[^>]*>/i', '', $string);
	return $string;
}

function write_all_people_to_file() {
	$users = simplexml_load_string(get_ai_users()->responseData);
	$first = true;
	foreach ($users->User as $user) {
		$person = get_ai_person($user->attributes()->username)->responseData;
		if ($first) {
			$person = preg_replace('/<\/Data>/', '', $person);
			file_put_contents("output/all-people.xml", $person);
			$first = false;
		} else {
			$person = preg_replace('/<\/Data>/', '', $person);
			$person = preg_replace('/<Data [^>]+>/', '', $person);
			$person = preg_replace('/<\?xml [^>]+>/', '', $person);
			file_put_contents("output/all-people.xml", $person, FILE_APPEND);
		}
	}
	file_put_contents("output/all-people.xml", '</Data>', FILE_APPEND);
}

function get_legacy_ilr_directory_info() {
	return file_get_contents($GLOBALS['ILR_DIRECTORY_LEGACY_DATA_FEED']);
}

function get_ldap_info($filter, $attributes, $start) {
	$ds=ldap_connect($GLOBALS['LDAP_SERVER']);

	if ($ds) {
		$r=ldap_bind($ds, $GLOBALS['LDAP_USERNAME'], $GLOBALS['LDAP_PASSWORD']);
		$sr=ldap_search($ds, $start, $filter, $attributes);
		$ret = ldap_get_entries($ds, $sr);
		ldap_close($ds);
	    return $ret;
	} else {
		return [];
	}
}

function get_ilr_people_from_ldap() {
	return get_ldap_info($GLOBALS['LDAP_FILTER'], $GLOBALS['LDAP_ATTRIBUTES'], $GLOBALS['LDAP_START']);
}

function ldap2xml($ldap) {
	$result = [];

	if (count($ldap)) {
		$whiteLabels = [];
		$whiteLabels['displayname'] = "ldap_display_name";
		$whiteLabels['physicaldeliveryofficename'] = "ldap_campus_address";
		$whiteLabels['telephonenumber'] = "ldap_campus_phone";
		$whiteLabels['mail'] = "ldap_email";
		$whiteLabels['title'] = "ldap_working_title1";
		$whiteLabels['personaltitle'] = "ldap_working_title2";
		$whiteLabels['employeetype'] = "ldap_employee_type";
		$whiteLabels['department'] = "ldap_department";
		$whiteLabels['uid'] = "ldap_uid";
		$whiteLabels['sn'] = "ldap_last_name";
		$whiteLabels['givenname'] = "ldap_first_name";
		$whiteLabels['mailnickname'] = "ldap_mail_nickname";

	    $result[] = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>";
		$result[] = "<Data dmd:date=\"2010-02-23\" xmlns=\"http://www.digitalmeasures.com/schema/data\" xmlns:dmd=\"http://www.digitalmeasures.com/schema/data-metadata\">";

		foreach($ldap AS $person) {
			if (is_array($person)) {
				$result[] = "\t<Record username=\"" . $person['uid'][0] . "\">";
				foreach ($GLOBALS['LDAP_ATTRIBUTES'] as $attr) {
					if (array_key_exists($attr, $person)) {
						for ($j=0; $j<count($person[$attr])-1; $j++) {
							$suffix = count($person[$attr]) > 2 ? $j + 1 : '';
							if (strlen(trim($person[$attr][$j])) > 0) {
								$result[] = "\t\t<$whiteLabels[$attr]" . "$suffix>" . htmlspecialchars($person[$attr][$j], ENT_QUOTES, "UTF-8") . "</$whiteLabels[$attr]" . "$suffix>";
							} else {
								$result[] = "\t\t<$whiteLabels[$attr]" . "$suffix/>";
							}
						}
					} else {
						$result[] = "\t\t<$whiteLabels[$attr]/>";
					}
				}
				$result[] = "\t</Record>";
			}
	    }
	    $result[] = "</Data>";
	}
	return join("\n", $result);
}

function new_empty_xml_file($filename) {
	return file_put_contents($filename
	, '<?xml version="1.0" encoding="UTF-8"?>
<Data xmlns="http://www.digitalmeasures.com/schema/data" xmlns:dmd="http://www.digitalmeasures.com/schema/data-metadata" dmd:date="2014-01-14">');
}

