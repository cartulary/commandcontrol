#!/usr/bin/env perl
	use strict;
	use warnings;
	use Mail::IMAPClient;
	use IO::Socket::SSL;
	use Term::ANSIColor;
	use Term::ANSIColor qw(:pushpop);
	use Conf;

if ($Conf::conf{"get-server-type"} ne "imap")
{
	die("we don't support that type of mailbox yet");
}


print "Connecting to..." . PUSHCOLOR GREEN;
print $Conf::conf{"get-server"} . ":";
print $Conf::conf{"get-server-port"};
print " " . POPCOLOR . "\n";

# Connect to the IMAP server via SSL
my $socket = IO::Socket::SSL->new(
	PeerAddr => $Conf::conf{"get-server"},
	PeerPort => $Conf::conf{"get-server-port"}
   )
	or die "socket(): $@";

print "Attempting to login as ". PUSHCOLOR GREEN . $Conf::conf{"username"}. POPCOLOR ."\n";
my $imap = Mail::IMAPClient->new(
   Socket   => $socket,
   User     => $Conf::conf{"username"},
   Password => $Conf::conf{"password"},
  )
  or die "IMAPClient::new(): $@";

# Listing all of your folders
print "I'm authenticated\n" if $imap->IsAuthenticated();
#my @folders = $imap->folders();
#print join("\n* ", 'Folders:', @folders), "\n";

my $msgcount = $imap->message_count($Conf::conf{"folder.todo"}); 
defined($msgcount) or die "Could not message_count: $@\n";
print "We have $msgcount unread messages in ". $Conf::conf{"folder.todo"}."\n";

if ($msgcount > 0)
{
	print "Attempting to select a folder....";
	if ($imap->selectable($Conf::conf{"folder.todo"}))
	{
		$imap->select($Conf::conf{"folder.todo"}) or die "Could not select: $@\n"	;
		print "done\n";
		print "Getting a list of unseen messages....\n";
		my @unread = $imap->unseen or warn "Could not find unseen msgs: $@\n";
		foreach (@unread)
		{
			print "=======$_=======\n";
			print "Subject:" . $imap->subject($_);
			my $body =  $imap->body_string($_);
			print "Body:" . $body;
			print "\n";
			
		}
	}
	else
	{
		print "but we can't\n";
	}
}
else
{
	print "Not selecting any folder with 0 messages\n";
}

# Say goodbye
$imap->logout();
print "\n";