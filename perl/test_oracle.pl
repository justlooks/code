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
	print "\n";
}

sub title_make {
	my $sql = shift;
	$sql =~ s/^select\s+(.*)\s+from.*$/\1/i;
	my @cols = map {s/.*\s+(\S+)/\1/;
        #print "i get $_\n";    
        $_} split(/ ,/,$sql);
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


=pod
# database overview

mess_print("Database Info");

my $db_ov_sql = q{select dbid,name ,created ,log_mode ,open_mode ,supplemental_log_data_min ,platform_name ,current_scn ,flashback_on from v$database};

my $head = title_make($db_ov_sql);
my ($re_ref,$fmt_arr) = info_fetch($db_ov_sql,$dbh);
result_print($re_ref,$fmt_arr,$head);

# instance overview

mess_print("Instance Info");

my $inst_ov_sql = q{select instance_name ,host_name ,version ,startup_time ,status ,logins ,database_status from v$instance};

$head = title_make($inst_ov_sql);
($re_ref,$fmt_arr) = info_fetch($inst_ov_sql,$dbh);
result_print($re_ref,$fmt_arr,$head);

=cut

# pga overview

mess_print("PGA Info");

my $pga_stat_sql = q{select name ,decode(unit,'bytes',trunc(to_char(value/1024/1024))||' M','percent',to_char(value)||' %',to_char(value)||' times') mbyte from v$pgastat};
$head = title_make($pga_stat_sql);
($re_ref,$fmt_arr) = info_fetch($pga_stat_sql,$dbh);
result_print($re_ref,$fmt_arr,$head);

#my $pga_ov_sql = q{select PGA_TARGET_FOR_ESTIMATE/1024/1024 as PGA_TARGET_FOR_ESTIMATE ,PGA_TARGET_FACTOR ,ADVICE_STATUS,BYTES_PROCESSED/1024/1024 as BYTES_PROCESSED ,ESTD_EXTRA_BYTES_RW ,ESTD_PGA_CACHE_HIT_PERCENTAGE ,ESTD_OVERALLOC_COUNT from v$pga_target_advice};

my $pga_ov_sql = q{select trunc(pga_target_for_estimate/1024/1024) pga_target_for_est ,to_char(pga_target_factor*100,'999.9')||'%' pga_target_factor ,advice_status ,trunc(bytes_processed/1024/1024) Mbytes_processed ,trunc(estd_extra_bytes_rw/1024/1024) estd_extra_Mbytes_rw ,to_char(estd_pga_cache_hit_percentage,'999')||'%' est_pga_cache_hit_percentage ,estd_overalloc_count from v$pga_target_advice};

$head = title_make($pga_ov_sql);
($re_ref,$fmt_arr) = info_fetch($pga_ov_sql,$dbh);
result_print($re_ref,$fmt_arr,$head);

my $o1m_stat_sql = q{select case when low_optimal_size < 1024*1024 then to_char(low_optimal_size/1024,'999')||'KB' else to_char(low_optimal_size/1024/1024,'999')||'MB' end cache_low ,case when (high_optimal_size+1)<1024*1024 then to_char(high_optimal_size/1024,'999')||'KB' else to_char(high_optimal_size/1024/1024,'999')||'MB' end cache_high ,optimal_executions||'/'||onepass_executions||'/'||multipasses_executions O_1_M  from v$sql_workarea_histogram where total_executions <> 0};
$head = title_make($o1m_stat_sql);
($re_ref,$fmt_arr) = info_fetch($o1m_stat_sql,$dbh);
result_print($re_ref,$fmt_arr,$head);

dbhandle_release($dbh);



