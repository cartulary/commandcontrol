#!/usr/bin/env perl
	use strict;
	use warnings;
	use Mail::IMAPClient::BodyStructure;
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
print "We have $msgcount unread messages in ". PUSHCOLOR GREEN . $Conf::conf{"folder.todo"}. POPCOLOR . "\n";

if ($msgcount > 0)
{
	#I should probably add a if !->exists then ->create thing here...
	print "Attempting to select a folder....";
	if ($imap->selectable($Conf::conf{"folder.todo"}))
	{
		$imap->select($Conf::conf{"folder.todo"}) or die "Could not select: $@\n"	;
		print "done\n";
		print "Getting a list of unseen messages....\n";
		my @unread = $imap->unseen or warn "Could not find unseen msgs: $@\n";
		foreach (@unread)
		{
			print PUSHCOLOR BLUE . "=======$_=======" . POPCOLOR . "\n";
			print "Getting body structure...\n";
			my $body = $imap->get_bodystructure($_)
				or die "Could not get_bodystructure: $@\n";
			if ($body->bodytype ne "TEXT" or $body->bodysubtype ne "PLAIN")
			{
				print PUSHCOLOR RED . "I don't deal with " . $body->bodytype . "/" . $body->bodysubtype . " messages" . POPCOLOR . "\n";
				next;
			}
			print "Continue the parse...\n";
			#print "params: " . $body->bodyparams(). "\n";
			print "bodydisp: " . $body->bodydisp. "\n";
			print "bodyid: " . $body->bodyid . "\n";
			print "bodydesc: " . $body->bodydesc . "\n";
			print "bodyenc: " . $body->bodyenc . "\n";
			print "bodysize: " . $body->bodysize . "\n";
			print "bodylang: " . $body->bodylang . "\n";
			print "textlines: " . $body->textlines . "\n";
			my $envelope = $imap->get_envelope($_)
				or die ("Can't get evnelope: $@\n");			
			print "Subject:". $envelope->subject ."\n";
			print "inreplyto". $envelope->inreplyto . "\n";
			print "from" . $envelope->from . "\n";
			print "messageid" . $envelope->messageid . "\n";
			print "bcc" . $envelope->bcc . "\n";
			print "date" . $envelope->date . "\n";
			print "Reply to:";
#			foreach($envelope->replyto)
#			{
#				print "$_;";
#			}
			print "\n";
			print "sender" . $envelope->sender . "\n";
			print "cc" . $envelope->cc . "\n";
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