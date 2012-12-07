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

# return multi-array result set,返回结果集和格式化长度信息
sub info_fetch {
	my ($sqlstr,$dbh) = @_;
	my $sth = $dbh->prepare("$sqlstr");
	$sth->execute();
	my $arr_ref;
	my @rows = ();
	my @format_len = ();
	while($arr_ref = $sth->fetchrow_arrayref) {
		my @arr_temp = ();
		my $tmp_len;
		for my $k (0..$#$arr_ref) {
			push(@arr_temp,$arr_ref->[$k]);
			$tmp_len = length("$arr_ref->[$k]");
#			print "$tmp_len ---> $arr_ref->[$k] => ".length("$arr_ref->[$k]")."\t";
			if($tmp_len > $format_len[$k]) {
				$format_len[$k] = $tmp_len; 
			}
		}
#		print "\n";
		push(@rows,[@arr_temp]);	
	}
	return (\@rows,\@format_len);
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

my ($re_ref,$fmt_arr) = info_fetch($sql,$dbh);
for my $k (0..$#$fmt_arr) {
	print $fmt_arr->[$k],"\t";
}
print "\n";

dbhandle_release($dbh);



