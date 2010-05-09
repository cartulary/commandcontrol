#!/usr/bin/env perl
use strict;
use warnings;
use Mail::IMAPClient;
use IO::Socket::SSL;

use Conf;

if ($Conf::conf{"get-server-type"} ne "imap")
{
	die("we don't support that type of mailbox yet");
}

print "Connecting to...";
print $Conf::conf{"get-server"} . ":" . $Conf::conf{"get-server-port"} ."\n";
# Connect to the IMAP server via SSL
my $socket = IO::Socket::SSL->new(
	PeerAddr => $Conf::conf{"get-server"},
	PeerPort => $Conf::conf{"get-server-port"}
   )
	or die "socket(): $@";

print "Attempting to login as ". $Conf::conf{"username"}."\n";
my $client = Mail::IMAPClient->new(
   Socket   => $socket,
   User     => $Conf::conf{"username"},
   Password => $Conf::conf{"password"},
  )
  or die "IMAPClient::new(): $@";

# Listing all of your folders
print "I'm authenticated\n" if $client->IsAuthenticated();
#my @folders = $client->folders();
#print join("\n* ", 'Folders:', @folders), "\n";

my $msgcount = $client->message_count($Conf::conf{"folder.todo"}); 
defined($msgcount) or die "Could not message_count: $@\n";
print "We have $msgcount unread messages in ". $Conf::conf{"folder.todo"}."\n";

if ($msgcount > 0)
{
	print "Attempting to select a folder....";
	if ($client->selectable($Conf::conf{"folder.todo"}))
	{
		$client->select($Conf::conf{"folder.todo"}) or die "Could not select: $@\n"	;
		print "done\n";
	}
	else
	{
		print "but we can't";
	}
}
else
{
	print "Not selecting any folder with 0 messages";
}

# Say goodbye
$client->logout();
print "\n";