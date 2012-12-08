#!/usr/bin/perl 

use DBI;
use Term::ANSIColor qw(:constants);
use Data::Dumper;

$Term::ANSIColor::AUTORESET = 1;

sub dbhandle_get {
	my $info = shift;
	my $handle = DBI->connect("dbi:Oracle:host=$info->{host};sid=$info->{sid}",$info->{user},$info->{pass},{RaiseError=>0,PrintError=>0,ora_session_mode=>2}) or die("connect refused ",$DBI::errstr,"\n");
	return $handle;	
}

sub dbhandle_release {
	my $dbh = shift;
	$dbh->disconnect or die $dbh->errstr;
}

# return multi-array result set,测试
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
			if($tmp_len > $format_len[$k]) {
				$format_len[$k] = $tmp_len; 
			}
		}
		push(@rows,[@arr_temp]);	
	}
	$sth->finish();
	return (\@rows,\@format_len);
}

# format output
sub result_print {
	my ($re,$fmt,$title) = @_;
	my $len;
	for my $k (0..$#$fmt) {
		if($fmt->[$k] < length("$title->[$k]")) {
			$fmt->[$k] = length("$title->[$k]");
		}
		$len += $fmt->[$k] + 2;
		printf "%-$fmt->[$k]s  ",$title->[$k];
	}
	$len += 4;
	printf "\n" . "-" x $len ."\n";
	for my $i (0..$#$re) {
		for my $j (0..$#{$re->[$i]}) {
			printf "%-$fmt->[$j]s  ",${$re->[$i]}[$j]; 
		}
		printf "\n";
	}
}

sub title_make {
	my $sql = shift;
	$sql =~ s/^select\s+(.*)\s+from.*$/\1/i;
	my @cols = map {s/.*\s+(\w+)/\1/;$_} split(/,/,$sql);
	for my $i (0..$#cols) {
		$cols[$i] = uc($cols[$i]);
	}
	return \@cols;
}

sub mess_print {
	$mesg = shift;
	print BOLD WHITE "$mesg\n";
}

my %conn_info = (
	'user' => 'sys',
	'pass' => '123456',
	'host' => 'localhost',
	'sid'  => 'mycatalog' );

#print Dumper(\%conn_info);

my $dbh = dbhandle_get(\%conn_info);

#my $sql = q{select space_usage_kbytes,occupant_name,occupant_desc from v$sysaux_occupants order by 1 desc};
#my $sql = q{select COLUMN_NAME from dba_tab_columns where table_name='T1' and owner='HR'};

#my $head = [uc('space_usage_kbytes'),uc('occupant_name'),uc('occupant_desc')];
#my $head = ['COLUMN_NAME'];


# database overview

mess_print("Database Info");

my $db_ov_sql = q{select dbid,name, created ,log_mode,open_mode,supplemental_log_data_min,platform_name, current_scn,flashback_on from v$database};

my $head = title_make($db_ov_sql);
my ($re_ref,$fmt_arr) = info_fetch($db_ov_sql,$dbh);
result_print($re_ref,$fmt_arr,$head);

# instance overview

mess_print("Instance Info");

my $inst_ov_sql = q{select instance_name,host_name,version,startup_time,status,logins,database_status from v$instance};

$head = title_make($inst_ov_sql);
($re_ref,$fmt_arr) = info_fetch($inst_ov_sql,$dbh);
result_print($re_ref,$fmt_arr,$head);


# pga overview

mess_print("PGA Info");

my $pga_ov_sql = q{select PGA_TARGET_FOR_ESTIMATE/1024/1024 as PGA_TARGET_FOR_ESTIMATE ,PGA_TARGET_FACTOR ,ADVICE_STATUS,BYTES_PROCESSED/1024/1024 as BYTES_PROCESSED ,ESTD_EXTRA_BYTES_RW ,ESTD_PGA_CACHE_HIT_PERCENTAGE ,ESTD_OVERALLOC_COUNT from v$pga_target_advice};

$head = title_make($pga_ov_sql);
($re_ref,$fmt_arr) = info_fetch($pga_ov_sql,$dbh);
result_print($re_ref,$fmt_arr,$head);
dbhandle_release($dbh);



