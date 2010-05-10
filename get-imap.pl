#!/usr/bin/env -S perl -T
	use strict;
	use warnings;
	use v5.10;

	use Mail::IMAPClient::BodyStructure;
	use Mail::IMAPClient;
	use IO::Socket::SSL;
	use Term::ANSIColor;
	use Term::ANSIColor qw(:pushpop);
	use Data::Dumper;
	use Net::SMTP::TLS;

	use constant false => 0;
	use constant true  => 1;

	require './conf.pl';
	if ($@)
	{
		die "config file failed to load...";
	}

sub sendResults {
	my $x = shift;
	my $m_id = shift;
#	print PUSHCOLOR YELLOW . $x . POPCOLOR;
	print"Attempting to connect to SMTP...";
	my $mailer = new Net::SMTP::TLS(
		$Conf::conf{"send-server"},
        Hello   =>      $Conf::conf{"result.host.from"},
        Port    =>      $Conf::conf{"send-server-port"},
        User    =>      $Conf::conf{"username"},
        Password=>      $Conf::conf{"password"},
	) or die ("failed to create session");
	print "We connected ... sending mail";
	$mailer->mail($Conf::conf{"username"});
	$mailer->to($Conf::conf{"result.to"});
	$mailer->data;
	$mailer->datasend("Subject: re $m_id\n");
	$mailer->datasend($x);
	$mailer->dataend;
	print "Quiting...";
	$mailer->quit;
}

sub doCommand {
	my $command = $_[0];
	print "Performing command $command...";
	return `$command 2>&1`;
}

sub doMessage {
	print "Doing a message...\n";
	my %command = ();
	$command{"command"} = undef;
	$command{"reply"} = false;
	my @lines = split('\n',$_[0]);
	my $m_id = $_[1];
	foreach(@lines)
	{
		my @coml = split(":",$_,2);
		print "Command: ". $coml[0];
		print "\nText:" .$coml[1];
		print "\n";
		given(uc $coml[0])
		{
			when("COMMAND")
			{
				$command{"command"} = $coml[1];
				print PUSHCOLOR BLUE . $coml[1] . POPCOLOR ."\n";
			}
			when ("REPLY")
			{
				$command{"reply"} = true;
			}
		}
	}
	my $res;
	if (defined($command{"command"}))
	{
		$res = doCommand($command{"command"});
	}
	sendResults($res, $m_id);
	print "\n";
}

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
			$imap->see($_);
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
			my $envelope = $imap->get_envelope($_)
				or die ("Can't get evnelope: $@\n");			
			my $m_id  =  $envelope->messageid;
			my $m_subject = $envelope->subject;
			my $from_full = $imap->get_header($_,"From");
			my $msg =  $imap->body_string($_);
			if ($from_full ne $Conf::conf{"auth.from"})
			{
				print PUSHCOLOR RED . "Evil from bit" . POPCOLOR . "\n";
				next;
			}
			doMessage($msg, "$m_subject ($m_id)");
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
print "outa here\n";
$imap->close();
$imap->logout();
print "\n";

