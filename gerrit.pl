#!/usr/bin/env perl

use strict;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Cwd 'getcwd';
use Term::ANSIColor;
use JSON::PP;

sub die_usage($exit_code = 0) {
  printf "usage: gerrit <subcmd> [<arg>...]\n";
  exit $exit_code;
}

sub die_error($msg, @args) {
  my $err = colored "error:", "bold red";
  die sprintf "$err $msg\n", @args;
}

sub trim($str) {
  $str =~ s/^\s+|\s+$//g;
  return $str;
}

sub first_line($str) {
  (split '\n', $str)[0]
}

sub capture($cmd) {
  my $output = `$cmd`;
  die_error "cammand '$cmd' returned $?" if $? != 0;
  trim $output;
}

sub git(@args) {
  my $msg = sprintf "git %s\n", join(' ', @args);
  print colored $msg, "bold";
  my $ret = system 'git', @args;
  die_error "git returned $ret" if $ret != 0;
  return $ret;
}

sub git_check_repo() {
  `git rev-parse --show-toplevel`;
  die_error "not a git repository" if $? != 0;
}

sub git_head()     { capture "git rev-parse HEAD" }
sub git_branch()   { capture "git rev-parse --abbrev-ref HEAD" }
sub git_origin()   { capture "git remote show" }

sub git_repo_url() {
  my $origin = git_origin;
  capture "git remote get-url $origin"
}

sub git_upstream() {
  my $remote = capture "git rev-parse --abbrev-ref \@{u}";
  my ($origin, $branch) = ($1, $2) if $remote =~ m{^(.+?)/(.*)};
  die_error "origin invalid: $remote" if $origin ne git_origin;
  return $branch;
}

sub git_server() {
  return $1 if git_repo_url =~ m{^(.+://.+?)/.*$};
  die_error "unable to parse git URL";
}

sub subcmd_help(@) {
  die_usage 0;
}

sub subcmd_query(@args) {
  push @args, git_head if not @args;
  system 'ssh', git_server, 'gerrit', 'query', @args;
}

sub subcmd_branch(@args) {
  my $origin = git_origin;
  my $upstream = git_upstream;
  while (my $branch = shift @args) {
    git 'checkout', '-b', $branch;
    git 'branch', '-u', "$origin/$upstream";
  }
}

sub subcmd_origin(@) {
  git 'checkout', git_upstream;
}

sub subcmd_pick(@args) {
  my $current_branch = git_branch;
  my $head = git_head;
  my $origin = git_origin;
  for my $branch (@args) {
    my $tmp_branch = "pick/$head";
    git 'checkout', $branch;
    git 'checkout', '-b', $tmp_branch;
    git 'cherry-pick', $head;
    git 'push', $origin, "HEAD:refs/for/$branch", "--no-thin";
    git 'checkout', $current_branch;
    git 'branch', '-D', $tmp_branch;
  }
}

sub subcmd_push(@) {
  my $origin = git_origin;
  my $upstream = git_upstream;
  git 'commit', '--amend', '--no-edit';
  git 'push', $origin, "HEAD:refs/for/$upstream", "--no-thin";
}

sub subcmd_download(@args) {
  my $server = git_server;
  for my $arg (@args) {
    my $resp_json = capture "ssh $server gerrit query $arg --current-patch-set --format JSON";
    my $resp = decode_json first_line $resp_json;
    my $ref = $resp->{currentPatchSet}->{ref};
    die_error "no commit found for $arg" if not defined $ref;
    git 'fetch', git_repo_url, $ref;
    git 'cherry-pick', 'FETCH_HEAD';
  }
}

git_check_repo;
my $subcmd = shift;
die_usage 1 if not defined $subcmd;
my $handler = "subcmd_$subcmd";
die_usage 1 if not exists &$handler;
(\&$handler)->(@ARGV);

