#!/usr/bin/perl 

use DBI;

#$ENV{ORACLE_HOME}="/opt/oracle/app/oracle/product/11.2.0/dbhome_1";
#$ENV{ORACLE_SID}="mycatalog";
$ENV{LD_LIBRARY_PATH}="/opt/oracle/app/oracle/product/11.2.0/dbhome_1/lib";


$dbh = DBI->connect("dbi:Oracle:mycatalog","hr","hr") or die("DB can not connect!");

print "ok\n";
