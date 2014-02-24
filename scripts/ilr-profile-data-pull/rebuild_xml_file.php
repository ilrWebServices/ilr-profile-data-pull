<?php

require 'ilr-faculty-data.php';

if (! verify_configuration()) {
  echo "Error: Please ensure a complete configuration has been supplied for ilr-faculty-data.php.";
  exit();
}

// Run the XSLT transform on the main xml file, which will fold in the fields from lpad and legacy_ilr_directory_HTML
$raw_xml = file_get_contents('xml/ilr_people.xml');
$transformed_xml = 'xml/ilr_profiles_feed.xml';
file_put_contents($transformed_xml, stripEmptyCDATA(xslt_transform($raw_xml, get_ilr_profiles_transform_xsl(), 'xml')));
