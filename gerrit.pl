#!/usr/bin/env perl

use strict;
use warnings;
use feature 'signatures', 'say';
no warnings 'experimental::signatures';

use Term::ANSIColor;
use JSON::PP;
use String::Util 'trim';
use IPC::System::Simple 'system', 'capture';

sub die_usage($exit_code = 0) {
  say "Usage: gerrit <subcmd> [<arg>...]";
  say "Available subcmd:";
  for (grep { /^subcmd_/ } keys %main::) {
    say $_ if s/^subcmd_//g;
  }
  exit $exit_code;
}

sub first_line($str) {
  (split '\n', $str)[0]
}

sub git(@args) {
  say colored join(' ', 'git', @args), "bold";
  system 'git', @args;
}

sub git_check_repo() { capture "git rev-parse --show-toplevel" }
sub git_head()       { capture "git rev-parse HEAD" }
sub git_branch()     { capture "git rev-parse --abbrev-ref HEAD" }
sub git_origin()     { capture "git remote show" }

sub git_repo_url() {
  my $origin = git_origin;
  capture "git remote get-url $origin"
}

sub git_upstream() {
  my $remote = capture "git rev-parse --abbrev-ref \@{u}";
  my ($origin, $branch) = ($1, $2) if $remote =~ m{^(.+?)/(.*)};
  die "origin invalid: $remote" if $origin ne git_origin;
  return $branch;
}

sub git_server() {
  return $1 if git_repo_url =~ m{^(.+://.+?)/.*$};
  die "unable to parse git URL";
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
    die "no commit found for $arg" if not defined $ref;
    git 'fetch', git_repo_url, $ref;
    git 'cherry-pick', 'FETCH_HEAD';
  }
}

eval {
  git_check_repo;
  my $subcmd = shift;
  die_usage 1 if not defined $subcmd;
  my $handler = "subcmd_$subcmd";
  die_usage 1 if not exists &$handler;
  (\&$handler)->(@ARGV);
};

if ($@) {
  my $err = colored "error:", "bold red";
  die "$err $@";
}
