#!/usr/bin/perl 

use DBI;
#use Term::ANSIColor qw(:constants colored);
use Term::ANSIColor qw(colored);
use Data::Dumper;

$Term::ANSIColor::AUTORESET = 1;

# todo 添加查询某个用户的权限，表空间配额，角色 

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
	print colored(ucfirst($mesg),$fmt);
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


#----------------------------------------------------
#
#   tasks function
#
#----------------------------------------------------

sub query_user {
	my $dbh = shift;
	my $list_users_sql = q{select username from dba_users where username is not null};
	my ($users, undef) = info_fetch($list_users_sql, $dbh); 
	my @users = ();
	print "Total ".($#$users+1)." users in database \n";
	for my $i (0..$#$users) {
		push @users ,$users->[$i][0];
		printf "%-25s  ",$users->[$i][0];
		print "\n" unless ($i+1)%6;
	}
	print "\n";
	my $list_role_sql = q{select granted_role ,admin_option ,default_role from dba_role_privs where grantee=?};
	my $list_syspriv_sql = q{select privilege ,admin_option from  dba_sys_privs where grantee=?};
	my $list_objpriv_sql = q{select owner ,table_name ,grantor ,privilege ,grantable ,hierarchy from dba_tab_privs where grantee=?};

	my $op_user_priv = [ {'desc'=>'user roles','sql'=>$list_role_sql}
		    	    ,{'desc'=>'user sys priv','sql'=>$list_syspriv_sql}
			    ,{'desc'=>'user obj priv','sql'=>$list_objpriv_sql} ];

	my $userpmt = "pick a username for query ,or enter q for quit(case-sensitive) : ";
	my $userrfs = "not a correct username in database,try again\n";
	my $username = until_right($userpmt,$userrfs,'equal',[@users,'q']);

	for my $j (0..$#$op_user_priv) {
		mess_print(${$op_user_priv->[$j]}{desc}."\n\n",'BOLD WHITE');
		my $head = title_make(${$op_user_priv->[$j]}{sql});
		my ($re_ref,$fmt_arr) = info_fetch(${$op_user_priv->[$j]}{sql},$dbh,[$username]);
		result_print($re_ref,$fmt_arr,$head);
		print "\n";
	}	
}

# lots of sql - -

my $db_sql = q{select dbid ,name ,created ,current_scn ,log_mode ,open_mode ,force_logging ,flashback_on ,controlfile_type ,last_open_incarnation# ,protection_mode ,platform_name from v$database};
my $inst_sql = q{select instance_name ,thread# redo_thrd ,host_name ,version ,startup_time ,ROUND(TO_CHAR(SYSDATE-startup_time),1) up_days ,parallel in_cluster ,status ,logins ,database_status from v$instance};
my $redo_info_sql = q{select i.instance_name instance_name ,i.thread# redo_thrd ,f.group# groupnum ,f.member redofile ,f.type file_type ,l.status log_status ,round(l.bytes/1024/1024) Mbytes ,l.archived isarchived from gv$logfile f,gv$log l,gv$instance i where f.group#=l.group# and l.thread#=i.thread# and i.inst_id=f.inst_id};

my $tbs_info_sql = q{select f.tablespace_name tablespace_name ,t.status status ,t.contents contents ,t.extent_management extent_management ,t.encrypted encrypted ,t.bigfile bigfile ,f.free_mbytes "free(M)" ,u.total_mbytes "total(M)" ,to_char(round((u.total_mbytes-f.free_mbytes)/u.total_mbytes*100,2),'999.99')||'%' used_persent from (select round(sum(bytes)/1024/1024,2) free_mbytes,tablespace_name from dba_free_space group by tablespace_name) f, (select round(sum(bytes)/1024/1024,2) total_mbytes,tablespace_name from dba_data_files group by tablespace_name) u ,(select tablespace_name, status,contents,extent_management,encrypted,compress_for,bigfile from dba_tablespaces ) t where f.tablespace_name = u.tablespace_name and f.tablespace_name = t.tablespace_name};
my $data_file_sql = q{select file_id ,relative_fno ,tablespace_name ,bytes/1024/1024 "size(M)" ,file_name ,status ,online_status ,autoextensible from dba_data_files order by tablespace_name};
my $comps_sql = q{select comp_id ,comp_name ,version ,status ,modified ,control ,schema ,procedure from dba_registry order by comp_name};


my $pga_stat_sql = q{select name ,decode(unit,'bytes',trunc(to_char(value/1024/1024))||' M','percent',to_char(value)||' %',to_char(value)||' times') mbyte from v$pgastat};
my $pga_ad_sql = q{select trunc(pga_target_for_estimate/1024/1024) pga_target_for_est ,to_char(pga_target_factor*100,'999.9')||'%' pga_target_factor ,advice_status ,trunc(bytes_processed/1024/1024) Mbytes_processed ,trunc(estd_extra_bytes_rw/1024/1024) estd_extra_Mbytes_rw ,to_char(estd_pga_cache_hit_percentage,'999')||'%' est_pga_cache_hit_percentage ,estd_overalloc_count from v$pga_target_advice};
my $O1M_info_sql = q{select case when low_optimal_size < 1024*1024 then to_char(low_optimal_size/1024,'999')||'KB' else to_char(low_optimal_size/1024/1024,'999')||'MB' end cache_low ,case when (high_optimal_size+1)<1024*1024 then to_char(high_optimal_size/1024,'999')||'KB' else to_char(high_optimal_size/1024/1024,'999')||'MB' end cache_high ,optimal_executions||'/'||onepass_executions||'/'||multipasses_executions O_1_M  from v$sql_workarea_histogram where total_executions <> 0};
$head = title_make($o1m_stat_sql);

my $bsetinfo_sql = q{select bs.recid recid ,bp.piece# pieceno ,bp.copy# copyno ,bp.recid bp_key ,DECODE(bs.controlfile_included,'NO','-',bs.controlfile_included)||'  '||DECODE(backup_type,'L','Archived Redo Logs','D','Datafile Full Backup','D','Datafile Full Backup','I','Incremental Backup') "controlfile_included&type" ,TO_CHAR(bs.completion_time,'DD-MON-YYYY HH24:MI:SS') completion_time ,DECODE(status,'A','Available','D','Deleted','X','Expired') status ,handle handle from v$backup_set bs, v$backup_piece bp where bs.set_stamp = bp.set_stamp and bs.set_count = bp.set_count and bp.status in ('A','X') and bs.controlfile_included != 'NO' order by bs.recid, piece#};
my $bpicinfo_sql = q{select bs.recid bs_key ,bp.piece# pieceno ,bp.copy# copyno ,bp.recid bp_key ,DECODE(status,'A','Available','D','Deleted','X','Expired') status ,handle handle ,TO_CHAR(bp.start_time,'mm-dd-yy HH24:MI:SS') start_time ,TO_CHAR(bp.completion_time,'mm-dd-yy HH24:MI:SS') completion_time ,to_char(bp.elapsed_seconds,'99.9') elapsed_seconds from v$backup_set bs,v$backup_piece bp where bs.set_stamp = bp.set_stamp and bs.set_count = bp.set_count and bp.status in ('A','X') order by bs.recid,piece#};
my $spfile_sql = q{select bs.recid bs_key ,bp.piece# pieceno ,bp.copy# copyno ,bp.recid bp_key ,sp.spfile_included spfile_included ,TO_CHAR(bs.completion_time,'DD-MON-YYYY HH24:MI:SS') completion_time ,DECODE(status,'A','Available','D','Deleted','X','Expired') status ,handle handle from v$backup_set bs,v$backup_piece bp,(select distinct set_stamp, set_count ,'YES' spfile_included from v$backup_spfile) sp where bs.set_stamp = bp.set_stamp and bs.set_count = bp.set_count and bp.status in ('A','X') and bs.set_stamp = sp.set_stamp and bs.set_count = sp.set_count order by bs.recid,piece#};

my $snap_set_info_sql = q{select dbid ,snap_interval ,retention ,topnsql from dba_hist_wr_control};

my $sess_sql = q{select s.sid sid ,s.serial# serial ,s.username username ,s.program program ,to_char(logon_time,'yyyy-mm-dd hh24:mi:ss') login_time from v$session s,v$process p where s.paddr=p.addr and p.spid=?};
my $content_sql = q{select t.sql_text sql_text from v$session s,v$process p,v$sqltext_with_newlines t where s.paddr=p.addr and s.sql_hash_value=t.hash_value and p.spid=?};
my $wait_info_sql = q{select p.addr addr ,p.username username ,p.terminal terminal ,p.program program ,p.pga_used_mem/1024 pga_usedKbytes ,p.pga_alloc_mem/1024 pga_allocKbytes ,p.pga_freeable_mem/1024 pga_freeKbytes ,pga_max_mem/1024 as pga_maxKbytes ,s.sid sid ,s.serial# serial ,s.event event ,s.state state ,s.seconds_in_wait wait_seconds ,s.wait_time iswait from v$process p,v$session s where p.addr = s.paddr and p.spid=?};

my $user_all_sql = q{select username from dba_users};
my $user_role_sql = q{select * from dba_role_privs where grantee=?};


my %overview = (
	'name' => 'overview',
	'items'  => [ {'desc'=>'database','sql'=>$db_sql}
		     ,{'desc'=>'instance','sql'=>$inst_sql}
		     ,{'desc'=>'tablespace info','sql'=>$tbs_info_sql}
		     ,{'desc'=>'redo info','sql'=>$redo_info_sql}
		     ,{'desc'=>'datafile info','sql'=>$data_file_sql}
		     ,{'desc'=>'db components','sql'=>$comps_sql} ],
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

# not yet
my %backup = (
	'name' => 'backup information',
	'items' => [ {'desc'=>'backup set info','sql'=>$bsetinfo_sql} 
		    ,{'desc'=>'backup piece info','sql'=>$bpicinfo_sql}
		    ,{'desc'=>'spfile info','sql'=>$spfile_sql} ],
	'flag' => 0
	);
# end not yet

# AWR report
my %awr = (
	'name' => 'awr infor',
	'items' => [ {'desc'=>'snapshot setting info','sql'=>$snap_set_info_sql} ],
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

my %userinfo = (
	'name' => 'find user',
	'item' => [ {'desc'=>'user role','sql'=>$user_role_sql}
		   ,{'desc'=>'all users','sql'=>$user_all_sql} ],
		
	'flag' => 0
	);

my %sthelse = (
	'name' => 'sthelse',
	'items' => [ {'desc' =>'haha','sql'=>'no'} ],
	'flag' => 0
);

my $test_sql = q{select DBMS_METADATA.GET_DDL('TABLE','T1') content from dual};
my %test = (
	'name' => 'for test',
	'items' => [ {'desc'=>'test item','sql'=>$test_sql} ],
	'flag' => 1
	);


my %conn_info = (
	'user' => 'sys',
	'pass' => '123456',
	'host' => 'localhost',
	'sid'  => 'mycatalog' );

#print Dumper(\%conn_info);


my $dbh = dbhandle_get(\%conn_info);

#$dbh->{LongReadLen} = 9000000;
#$dbh->{LongTruncOk} = 0;

=pod

my @static_items = (\%overview ,\%pga ,\%backup ,\%awr ,\%sthelse);

# pring manu
my $spline= '=' x 90;

mess_print($spline."\n",'BOLD WHITE');
print "\n";
for my $i (0..$#static_items) {

	mess_print(($i+1).'. '.$static_items[$i]{name}."\t",'BOLD WHITE');
}
print "\n";
print "\n";
mess_print($spline."\n",'BOLD WHITE');

print "choose items which you want to view (seperate by ','): ";
my @items_cfg = split /\s*,\s*/, (chomp($_=<STDIN>),$_);

if($#items_cfg == -1) {
	print "not pick items\n";
	exit;
}

for $i (0..$#items_cfg) {
	print "i pick $items_cfg[$i] $#items_cfg \n";
	$static_items[($items_cfg[$i]-1)]{flag} = 1;
}

for my $i (0..$#static_items) {
	if($static_items[$i]{flag} == 1) {
		mess_print($static_items[$i]{name}."\n",'BOLD WHITE');	
		for my $j (0..$#{$static_items[$i]{items}}) {
			mess_print(${$static_items[$i]{items}}[$j]{desc}."\n",'MAGENTA');
			my $head = title_make(${$static_items[$i]{items}}[$j]{sql});
			my ($re_ref,$fmt_arr) = info_fetch(${$static_items[$i]{items}}[$j]{sql},$dbh);
			result_print($re_ref,$fmt_arr,$head);
		}
	#print $static_items[$i]{name},"\n";
	}
}

=cut

=pod
my @tasks = (\%findsql ,\%userinfo);

mess_print($spline."\n",'BOLD WHITE');
print "\n";
for my $i (0..$#tasks) {

        mess_print(($i+1).'. '.$tasks[$i]{name}."\t",'BOLD WHITE');
}
print "\n";
print "\n";
mess_print($spline."\n",'BOLD WHITE');

print "choose task which you want to perform (only one task): ";
my @tasks_cfg = split /\s*,\s*/, (chomp($_=<STDIN>),$_);

if($#tasks_cfg == -1) {
        print "not pick items\n";
        exit;
}

for $i (0..$#tasks_cfg) {
        print "i pick tasks --> $tasks_cfg[$i] $#tasks_cfg \n";
        $static_items[($tasks_cfg[$i]-1)]{flag} = 1;
}
=cut



=pod

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

=cut

#-------------------
#
#   function test
#
#-------------------

query_user($dbh);

dbhandle_release($dbh);
