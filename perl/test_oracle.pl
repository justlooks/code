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

sub info_fetch {
	my ($sqlstr,$dbh) = @_;
#	print "1 get $#$re\n";
	my $sth = $dbh->prepare("$sqlstr");
	$sth->execute();
	my $hash_ref;
#	if($re eq 1) {
#		print "return struct\n";
#		my $depref = $sth->fetchrow_arrayref;
#		$sth->finish;
#		return $depref;	
#	}
	while($hash_ref = $sth->fetchrow_hashref) {
		print "i get sth\n";
			print $hash_ref->{COLUMN_NAME},"\n";
	}

}

my %conn_info = (
	'user' => 'sys',
	'pass' => '123456',
	'host' => 'localhost',
	'sid'  => 'mycatalog' );

#print Dumper(\%conn_info);
my $dbh = dbhandle_get(\%conn_info);

#my $sql = q{desc v$instance};
my $sql = q{select COLUMN_NAME from dba_tab_columns where table_name='T1' and owner='HR'};

my $redep = 1;
my $deparr_ref = info_fetch($sql,$dbh);

dbhandle_release($dbh);

print Dumper(@$deparr_ref);

