# ILR Faculty and Staff Data Aggegation

These scripts pull and aggregate ILR faculty and staff data from Cornell's directory via LDAP, from the legacy web-based directory of ILR's old web site, and from Activity Insight.

The ColdFusion scripts in feed-server are meant to run on a ColdFusion server with access to the Kodiak data source.

get_all_data.php can run locally on the php command line or as a cron job. Output will be saved to a new directory named 'xml'.

Data are formatted and streamlined for consumption by the Drupal Feed module for inclusion in the Profile content type.

Before running:

1. Follow the instructions in feed-server/README.md to ensure that the feed server is configured and running in a known location.
2. Copy example.ilr-faculty-data-conf.php to ilr-faculty-data-conf.php and supply the configuration settings found at [https://cornell.box.com/s/kwevsqueaxuagcb2mqgd](https://cornell.box.com/s/kwevsqueaxuagcb2mqgd). If you have changed the location of the feed-server, then change the configuration accordingly.