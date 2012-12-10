#!/usr/bin/perl 

use DBI;
#use Term::ANSIColor qw(:constants colored);
use Term::ANSIColor qw(colored);
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

# return multi-array result set
sub info_fetch {
	my ($sqlstr,$dbh,$isbind) = @_;
	my $sth = $dbh->prepare("$sqlstr");
	if($isbind) {
		$sth->execute($isbind->[0]);
	} else {
		$sth->execute();
	}
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
	my($mesg,$fmt) = @_;
	print colored(ucfirst($mesg)."\n",$fmt);
}

my $db_sql = q{select dbid ,name ,created ,current_scn ,log_mode ,open_mode ,force_logging ,flashback_on ,controlfile_type ,last_open_incarnation# ,protection_mode ,platform_name from v$database};
my $inst_sql = q{select instance_name ,thread# redo_thrd ,host_name ,version ,startup_time ,ROUND(TO_CHAR(SYSDATE-startup_time),1) up_days ,parallel in_cluster ,status ,logins ,database_status from v$instance};
my $redo_info_sql = q{select i.instance_name instance_name ,i.thread# redo_thrd ,f.group# groupnum ,f.member redofile ,f.type file_type ,l.status log_status ,round(l.bytes/1024/1024) Mbytes ,l.archived isarchived from gv$logfile f,gv$log l,gv$instance i where f.group#=l.group# and l.thread#=i.thread# and i.inst_id=f.inst_id};

my $pga_stat_sql = q{select name ,decode(unit,'bytes',trunc(to_char(value/1024/1024))||' M','percent',to_char(value)||' %',to_char(value)||' times') mbyte from v$pgastat};
my $pga_ad_sql = q{select trunc(pga_target_for_estimate/1024/1024) pga_target_for_est ,to_char(pga_target_factor*100,'999.9')||'%' pga_target_factor ,advice_status ,trunc(bytes_processed/1024/1024) Mbytes_processed ,trunc(estd_extra_bytes_rw/1024/1024) estd_extra_Mbytes_rw ,to_char(estd_pga_cache_hit_percentage,'999')||'%' est_pga_cache_hit_percentage ,estd_overalloc_count from v$pga_target_advice};
my $O1M_info_sql = q{select case when low_optimal_size < 1024*1024 then to_char(low_optimal_size/1024,'999')||'KB' else to_char(low_optimal_size/1024/1024,'999')||'MB' end cache_low ,case when (high_optimal_size+1)<1024*1024 then to_char(high_optimal_size/1024,'999')||'KB' else to_char(high_optimal_size/1024/1024,'999')||'MB' end cache_high ,optimal_executions||'/'||onepass_executions||'/'||multipasses_executions O_1_M  from v$sql_workarea_histogram where total_executions <> 0};
$head = title_make($o1m_stat_sql);

my %overview = (
	'name' => 'overview',
	'items'  => [ {'desc'=>'database','sql'=>$db_sql}
		     ,{'desc'=>'instance','sql'=>$inst_sql}
		     ,{'desc'=>'redo info','sql'=>$redo_info_sql} ],
	'flag' => 0		

	);

my %pga = (
	'name' => 'pga info',
	'items' => [ {'desc'=>'pga status','sql'=>$pga_stat_sql}
		    ,{'desc'=>'pga advice','sql'=>$pga_ad_sql}
		    ,{'desc'=>'work area info','sql'=>$O1M_info_sql} ],
	'flag' => 0

	);

my %sthelse = (
	'name' => 'sthelse',
	'items' => [ {'desc' =>'haha','sql'=>'no'} ],
	'flag' => 1
);


my %conn_info = (
	'user' => 'sys',
	'pass' => '123456',
	'host' => 'localhost',
	'sid'  => 'mycatalog' );

#print Dumper(\%conn_info);

my $dbh = dbhandle_get(\%conn_info);

my @ck_db_items = (\%overview ,\%pga ,\%sthelse);

for my $i (0..$#ck_db_items) {
	mess_print($ck_db_items[$i]{name},'BOLD WHITE');	
	for my $j (0..$#{$ck_db_items[$i]{items}}) {
		mess_print(${$ck_db_items[$i]{items}}[$j]{desc},'MAGENTA');
		my $head = title_make(${$ck_db_items[$i]{items}}[$j]{sql});
		my ($re_ref,$fmt_arr) = info_fetch(${$ck_db_items[$i]{items}}[$j]{sql},$dbh);
		result_print($re_ref,$fmt_arr,$head);
	}
	#print $ck_db_items[$i]{name},"\n";
}
#print Dumper(\@ck_db_items);




=pod
# database overview

mess_print("Database Info");

my $db_ov_sql = q{select dbid ,name ,created ,current_scn ,log_mode ,open_mode ,force_logging ,flashback_on ,controlfile_type ,last_open_incarnation# ,protection_mode ,platform_name from v$database};

# supplemental_log_data_min||'/'||supplemental_log_data_fk||'/'||supplemental_log_data_ui||'/'||supplemental_log_data_all "supplemental_log_min/fk/ui/all"

my $head = title_make($db_ov_sql);
my ($re_ref,$fmt_arr) = info_fetch($db_ov_sql,$dbh);
result_print($re_ref,$fmt_arr,$head);

# instance overview

mess_print("Instance Info");

my $inst_ov_sql = q{select instance_name ,thread# redo_thrd ,host_name ,version ,startup_time ,ROUND(TO_CHAR(SYSDATE-startup_time),1) up_days ,parallel in_cluster ,status ,logins ,database_status from v$instance};

$head = title_make($inst_ov_sql);
($re_ref,$fmt_arr) = info_fetch($inst_ov_sql,$dbh);
result_print($re_ref,$fmt_arr,$head);

# redo log info
mess_print("Redo log Info");

my $redo_info_sql = q{select i.instance_name instance_name ,i.thread# redo_thrd ,f.group# groupnum ,f.member redofile ,f.type file_type ,l.status log_status ,round(l.bytes/1024/1024) Mbytes ,l.archived isarchived from gv$logfile f,gv$log l,gv$instance i where f.group#=l.group# and l.thread#=i.thread# and i.inst_id=f.inst_id};
$head = title_make($redo_info_sql);
($re_ref,$fmt_arr) = info_fetch($redo_info_sql,$dbh);
result_print($re_ref,$fmt_arr,$head);


# pga overview

mess_print("PGA Info");

my $pga_stat_sql = q{select name ,decode(unit,'bytes',trunc(to_char(value/1024/1024))||' M','percent',to_char(value)||' %',to_char(value)||' times') mbyte from v$pgastat};
$head = title_make($pga_stat_sql);
($re_ref,$fmt_arr) = info_fetch($pga_stat_sql,$dbh);
result_print($re_ref,$fmt_arr,$head);


my $pga_ov_sql = q{select trunc(pga_target_for_estimate/1024/1024) pga_target_for_est ,to_char(pga_target_factor*100,'999.9')||'%' pga_target_factor ,advice_status ,trunc(bytes_processed/1024/1024) Mbytes_processed ,trunc(estd_extra_bytes_rw/1024/1024) estd_extra_Mbytes_rw ,to_char(estd_pga_cache_hit_percentage,'999')||'%' est_pga_cache_hit_percentage ,estd_overalloc_count from v$pga_target_advice};

$head = title_make($pga_ov_sql);
($re_ref,$fmt_arr) = info_fetch($pga_ov_sql,$dbh);
result_print($re_ref,$fmt_arr,$head);

my $o1m_stat_sql = q{select case when low_optimal_size < 1024*1024 then to_char(low_optimal_size/1024,'999')||'KB' else to_char(low_optimal_size/1024/1024,'999')||'MB' end cache_low ,case when (high_optimal_size+1)<1024*1024 then to_char(high_optimal_size/1024,'999')||'KB' else to_char(high_optimal_size/1024/1024,'999')||'MB' end cache_high ,optimal_executions||'/'||onepass_executions||'/'||multipasses_executions O_1_M  from v$sql_workarea_histogram where total_executions <> 0};
$head = title_make($o1m_stat_sql);
($re_ref,$fmt_arr) = info_fetch($o1m_stat_sql,$dbh);
result_print($re_ref,$fmt_arr,$head);


mess_print("Find info by OS process id");

my $sess_sql = q{select s.sid sid ,s.serial# serial ,s.username username,s.program program from v$session s,v$process p where s.paddr=p.addr and p.spid=?};
my $content_sql = q{select t.sql_text sql_text from v$session s,v$process p,v$sqltext_with_newlines t where s.paddr=p.addr and s.sql_hash_value=t.hash_value and p.spid=?};
$head = title_make($sess_sql);
($re_ref,$fmt_arr) = info_fetch($sess_sql,$dbh,[5273]);
result_print($re_ref,$fmt_arr,$head);

$head = title_make($content_sql);
($re_ref,$fmt_arr) = info_fetch($content_sql,$dbh,[5273]);
result_print($re_ref,$fmt_arr,$head);

my $wait_info_sql = q{select p.addr addr ,p.username username ,p.terminal terminal ,p.program program ,s.sid sid ,s.serial# serial ,s.event event ,s.state state ,s.seconds_in_wait wait_seconds ,s.wait_time iswait from v$process p,v$session s where p.addr = s.paddr and p.spid=?};
$head = title_make($wait_info_sql);
($re_ref,$fmt_arr) = info_fetch($wait_info_sql,$dbh,[5273]);
result_print($re_ref,$fmt_arr,$head);


mess_print("I/O Section");

my $redo_io_sql = q{
with log_history as
     (select thread#,first_time,
             lag(first_time) over (order by thread#,sequence#) last_first_time,
             (first_time-lag(first_time) over (order by thread#,sequence#))*24*60 last_log_time_minutes,
             lag(thread#) over (order by thread#,sequence#) last_thread#
      from v$log_history)
select round(min(last_log_time_minutes),2) min_minutes,
       round(max(last_log_time_minutes),2) max_minutes,
       round(avg(last_log_time_minutes),2) avg_minutes
from log_history
where last_first_time IS NOT NULL and last_thread#=thread# and first_time > sysdate-1};

=cut

dbhandle_release($dbh);



