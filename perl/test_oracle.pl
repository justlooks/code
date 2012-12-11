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

# get head info from sql
sub title_make {
	my $sql = shift;
	$sql =~ s/^select\s+(.*?)\s+from.*$/\1/i;
	my @cols = map {s/.*\s+(\S+)/\1/;
        #print "i get $_\n";    
        $_} split(/ ,/,$sql);
	for my $i (0..$#cols) {
		$cols[$i] = uc($cols[$i]);
	}
	return \@cols;
}

# color output
sub mess_print {
	my($mesg,$fmt) = @_;
	print colored(ucfirst($mesg)."\n",$fmt);
}

# check if input var correct
sub check_var {
	my ($var ,$ck_type ,$ck_list) = @_;
	if ($ck_type eq 'range') {
		if($var <= $ck_list->[1] and $var >= $ck_list->[0]) {
			return 1;
		}	
	} elsif ($ck_type eq 'equal') {
		for my $i (0..$#$ck_list) {
			if($var eq $ck_list->[$i]) {
				return 1;
			}
		}
	}
	return 0;
}

# receive user input
sub until_right {
	my ($prompt,$refuse,$ck_type,$ck_list) = @_;
	while (true) {
		print $prompt;
		chomp($option = <STDIN>);
		if(check_var($option,$ck_type,$ck_list)) {
			last;
		} else {
			print $refuse;
			next;
		}
	}
	return $option;
}

# get CPU&MEM top n pid
sub get_top_n {
	my %ck_options = (
		'CPU' => 3,
		'MEM' => 4
		);	
	my ($option,$topn) = @_;
	@res = map {chomp;$_} `ps auxw|grep [L]OCAL|sort -k$ck_options{$option}nr|awk 'NR>'$topn'{exit}{print \$2}'`;	
	return \@res;
}

# lots of sql - -

my $db_sql = q{select dbid ,name ,created ,current_scn ,log_mode ,open_mode ,force_logging ,flashback_on ,controlfile_type ,last_open_incarnation# ,protection_mode ,platform_name from v$database};
my $inst_sql = q{select instance_name ,thread# redo_thrd ,host_name ,version ,startup_time ,ROUND(TO_CHAR(SYSDATE-startup_time),1) up_days ,parallel in_cluster ,status ,logins ,database_status from v$instance};
my $redo_info_sql = q{select i.instance_name instance_name ,i.thread# redo_thrd ,f.group# groupnum ,f.member redofile ,f.type file_type ,l.status log_status ,round(l.bytes/1024/1024) Mbytes ,l.archived isarchived from gv$logfile f,gv$log l,gv$instance i where f.group#=l.group# and l.thread#=i.thread# and i.inst_id=f.inst_id};

my $tbs_info_sql = q{select f.tablespace_name tablespace_name ,t.status status ,t.contents contents ,t.extent_management extent_management ,t.encrypted encrypted ,t.bigfile bigfile ,f.free_mbytes "free(M)" ,u.total_mbytes "total(M)" ,to_char(round((u.total_mbytes-f.free_mbytes)/u.total_mbytes*100,2),'999.99')||'%' used_persent from (select round(sum(bytes)/1024/1024,2) free_mbytes,tablespace_name from dba_free_space group by tablespace_name) f, (select round(sum(bytes)/1024/1024,2) total_mbytes,tablespace_name from dba_data_files group by tablespace_name) u ,(select tablespace_name, status,contents,extent_management,encrypted,compress_for,bigfile from dba_tablespaces ) t where f.tablespace_name = u.tablespace_name and f.tablespace_name = t.tablespace_name};


my $pga_stat_sql = q{select name ,decode(unit,'bytes',trunc(to_char(value/1024/1024))||' M','percent',to_char(value)||' %',to_char(value)||' times') mbyte from v$pgastat};
my $pga_ad_sql = q{select trunc(pga_target_for_estimate/1024/1024) pga_target_for_est ,to_char(pga_target_factor*100,'999.9')||'%' pga_target_factor ,advice_status ,trunc(bytes_processed/1024/1024) Mbytes_processed ,trunc(estd_extra_bytes_rw/1024/1024) estd_extra_Mbytes_rw ,to_char(estd_pga_cache_hit_percentage,'999')||'%' est_pga_cache_hit_percentage ,estd_overalloc_count from v$pga_target_advice};
my $O1M_info_sql = q{select case when low_optimal_size < 1024*1024 then to_char(low_optimal_size/1024,'999')||'KB' else to_char(low_optimal_size/1024/1024,'999')||'MB' end cache_low ,case when (high_optimal_size+1)<1024*1024 then to_char(high_optimal_size/1024,'999')||'KB' else to_char(high_optimal_size/1024/1024,'999')||'MB' end cache_high ,optimal_executions||'/'||onepass_executions||'/'||multipasses_executions O_1_M  from v$sql_workarea_histogram where total_executions <> 0};
$head = title_make($o1m_stat_sql);

my $sess_sql = q{select s.sid sid ,s.serial# serial ,s.username username,s.program program from v$session s,v$process p where s.paddr=p.addr and p.spid=?};
my $content_sql = q{select t.sql_text sql_text from v$session s,v$process p,v$sqltext_with_newlines t where s.paddr=p.addr and s.sql_hash_value=t.hash_value and p.spid=?};
my $wait_info_sql = q{select p.addr addr ,p.username username ,p.terminal terminal ,p.program program ,s.sid sid ,s.serial# serial ,s.event event ,s.state state ,s.seconds_in_wait wait_seconds ,s.wait_time iswait from v$process p,v$session s where p.addr = s.paddr and p.spid=?};


my %overview = (
	'name' => 'overview',
	'items'  => [ {'desc'=>'database','sql'=>$db_sql}
		     ,{'desc'=>'instance','sql'=>$inst_sql}
		     ,{'desc'=>'tablespace info','sql'=>$tbs_info_sql}
		     ,{'desc'=>'redo info','sql'=>$redo_info_sql} ],
	'dynvar' => 0,
	'flag' => 0		

	);

my %pga = (
	'name' => 'pga info',
	'items' => [ {'desc'=>'pga status','sql'=>$pga_stat_sql}
		    ,{'desc'=>'pga advice','sql'=>$pga_ad_sql}
		    ,{'desc'=>'work area info','sql'=>$O1M_info_sql} ],
	'dynvar' => 0,
	'flag' => 0

	);

my %findsql = (
	'name' => 'find sql',
	'items' => [ {'desc'=>'session info','sql'=>$sess_sql}
		    ,{'desc'=>'sql content','sql'=>$content_sql}
		    ,{'desc'=>'wait event info','sql'=>$wait_info_sql} ],
	'dynvar' => 0, 
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

=pod

my @static_items = (\%overview ,\%pga ,\%sthelse);

for my $i (0..$#static_items) {
	mess_print($static_items[$i]{name},'BOLD WHITE');	
	for my $j (0..$#{$static_items[$i]{items}}) {
		mess_print(${$static_items[$i]{items}}[$j]{desc},'MAGENTA');
		my $head = title_make(${$static_items[$i]{items}}[$j]{sql});
		my ($re_ref,$fmt_arr) = info_fetch(${$static_items[$i]{items}}[$j]{sql},$dbh);
		result_print($re_ref,$fmt_arr,$head);
	}
	#print $static_items[$i]{name},"\n";
}
=cut

my @search_sqls = (\%findsql);

my $boundpmt = "choose CPU-bound/MEM-bound type sql (input 'CPU' or 'MEM') : ";
my $boundrfs = "unrecognized option,input 'CPU' or 'MEM' plz\n";

my $toppmt = "fetch top n records (input 1-50 integer) : ";
my $toprfs = "plz input number which great then zero and less then 51\n";

$type = until_right($boundpmt,$boundrfs,'equal',['CPU','MEM']);
$topn = until_right($toppmt,$toprfs,'range',[1,50]);

$proidarr_ref = get_top_n($type,$topn);

mess_print($findsql{name},'BOLD WHITE');	
mess_print("Top $topn",'GREEN');	

for my $i (0..$#$proidarr_ref) {
	mess_print("== ".($i+1),'GREEN');	
	for my $j (0..$#{$findsql{items}}) {
		mess_print(${$findsql{items}}[$j]{desc},'MAGENTA');
		my $head = title_make(${$findsql{items}}[$j]{sql});
		my ($re_ref,$fmt_arr) = info_fetch(${$findsql{items}}[$j]{sql},$dbh,[$proidarr_ref->[$i]]);
		result_print($re_ref,$fmt_arr,$head);
	}
}



dbhandle_release($dbh);


