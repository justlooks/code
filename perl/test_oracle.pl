#!/usr/bin/perl 

use DBI;
use Data::Dumper;


sub dbhandle_get {
	my $info = shift;
	my $handle = DBI->connect("dbi:Oracle:host=$info->{host};sid=$info->{sid}",$info->{user},$info->{pass},{RaiseError=>0,PrintError=>0,ora_session_mode=>2}) or die("connect refused ",$DBI::errstr,"\n");
	return $handle;	
}

sub dbhandle_release {
	my $dbh = shift;
	$dbh->disconnect or die $dbh->errstr;
}

# return multi-array result set
sub info_fetch {
	my ($sqlstr,$dbh) = @_;
	my $sth = $dbh->prepare("$sqlstr");
	$sth->execute();
	my $arr_ref;
	my @rows = ();
	while($arr_ref = $sth->fetchrow_arrayref) {
		my @arr_temp = ();
		for my $k (0..$#$arr_ref) {
			push(@arr_temp,$arr_ref->[$k]);
		}
		push(@rows,[@arr_temp]);	
	}
	return \@rows;
}

my %conn_info = (
	'user' => 'sys',
	'pass' => '123456',
	'host' => 'localhost',
	'sid'  => 'mycatalog' );

#print Dumper(\%conn_info);
my $dbh = dbhandle_get(\%conn_info);

my $sql = q{select space_usage_kbytes,occupant_name,occupant_desc from v$sysaux_occupants order by 1 desc};
#my $sql = q{select COLUMN_NAME from dba_tab_columns where table_name='T1' and owner='HR'};

my $re_ref = info_fetch($sql,$dbh);
print ${$re_ref->[1]}[1],"\n";

dbhandle_release($dbh);


#my $test_ref = [ [ 'a', 'b', 'c' ],[ '2', '3', '4' ] ];
#print ${$test_ref->[1]}[0],"\n";

