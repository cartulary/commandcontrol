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
my @folders = $client->folders();
print join("\n* ", 'Folders:', @folders), "\n";

# Say goodbye
$client->logout();
