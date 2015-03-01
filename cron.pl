#!/usr/bin/env perl

use strict;
use warnings;
use diagnostics;
use POSIX;

# TODD
# [ ] put time (and then the cron works in relation with this time)
# [ ] better log (exit codes etc)
# [ ] remeber launched tasks

my $sleeptime = 59;
my $log_file = "./cron.log";

die "No file with tasks - give it to me as an argument" if ( not $ARGV[ 0 ] );
my $tasks_file = $ARGV[ 0 ];
die "The tasks file: $tasks_file was not found." if ( not -e $tasks_file );

### Extracting tasks from the taskfile
sub extract_tasks
{
 my $task = shift;
 my $time_part = 0;
 my $cmd = q{};
 my $this_is_cmd;

 foreach my $file_task ( split( /\s/, $task ) )
 {
  next if $file_task =~ m/^$/ and not $this_is_cmd;
  $time_part++;
  next if ( $time_part < 6 );
  $this_is_cmd = 1;
  $cmd .= "$file_task ";
 }
 $cmd =~ s/\s$//;
 return $cmd;
}

sub is_time
{
 my $task = shift;
 my ( $t_minute, $t_hour, $t_dayofmonth, $t_month, $t_dayofweek );
 
 foreach my $file_task ( split( /\s/, $task ) )
 {
  next if $file_task =~ m/^$/ or not $file_task =~ m/[0-9,\*-\/]+/;
  $t_minute = $file_task and next if not $t_minute;
  $t_hour = $file_task and next if not $t_hour;
  $t_dayofmonth = $file_task and next if not $t_dayofmonth;
  $t_month = $file_task and next if not $t_month;
  $t_dayofweek = $file_task and next if not $t_dayofweek;
 }

 return 0 if not ( is_time_now( $t_minute, strftime( "%M", localtime ) ) );
 return 0 if not ( is_time_now( $t_hour, strftime( "%H", localtime ) ) );
 return 0 if not ( is_time_now( $t_dayofmonth, strftime( "%d", localtime ) ) );
 return 0 if not ( is_time_now( $t_month, strftime( "%m", localtime ) ) );
 return 0 if not ( is_time_now( $t_dayofweek, strftime( "%u", localtime ) ) );
 return 1;
}

sub is_time_now
{
 my $time = shift;
 my $comparetime = shift;

 return if ( $time eq "*" or $time eq "*/1" );
 
 foreach my $v ( split( /\,/, $time ) )
 {
  next if not $v =~ m/^[0-9*]+/;
  return 1 if ( $v =~ m/^[0-9]+$/ and ( $v eq $comparetime or $v eq $comparetime ) );

  if ( $v =~ m/\-/ )
  {
   my ( $from, $to ) = split( /-/, $v );
   if ( $from =~ m/[0-9]+/ and $to =~ m/[0-9]+/ )
   {
    for( ; $from <= $to; $from++ )
    {
     return 1 if ( $from eq $comparetime )
    }
   }
  }

  if ( $v =~ m/^\*\/([0-9]+)$/ )
  {
   my $digit = $1 if $1;
   return 1 if ( $digit and ( $digit eq 1 or ( not $comparetime % $digit ) ) );
  }  
 }
 return 0;
}

sub write_log
{
 my $message = shift;
 my $time = strftime "%Y/%m/%d %H:%M:%S", localtime;
 open my $lf, '>>', $log_file or die "The log file: $log_file couldn't be opened";
  print $lf "[$time] $message\n";
 close $lf;
}

while( 1 )
{
 open my $th, $tasks_file or die "The tasks file: $tasks_file couldn't be opened.";
  while( <$th> )
  {
   my $task = $_;
   if ( is_time( $task ) )
   {
    my $ttask = extract_task( $task );
    system( "$ttask &" );
    write_log( "task [$ttask] was launched." );
   }
  }
 close $th;
 sleep $sleeptime;
}
