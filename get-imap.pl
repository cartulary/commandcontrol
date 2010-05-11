#!/usr/bin/env -S perl
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
	use Config::Simple;
	##switch to use Config::Find...
	use File::HomeDir;

	use constant FALSE => 0;
	use constant TRUE  => 1;

my $prog_name = (split "/", $0)[-1];
$prog_name =~ s/\.[^.]*$//;
my $conf_file = File::HomeDir->my_home . "/.$prog_name"."rc";
print "Attempting to open $conf_file\n";
my $cfg = new Config::Simple();
$cfg->read($conf_file) or die $cfg->error;

sub sendResults {
	my $x = shift;
	my $m_id = shift;
#	print PUSHCOLOR YELLOW . $x . POPCOLOR;
	print"Attempting to connect to SMTP...";
	my $mailer = new Net::SMTP::TLS(
		$cfg->param('send.server'),
        Hello   =>      $cfg->param("send.result_host_from"),
        Port    =>      $cfg->param("send.port"),
        User    =>      $cfg->param("auth.user"),
        Password=>      $cfg->param("auth.password"),
	) or die ("failed to create session");
	print "We connected ... sending mail";
	$mailer->mail($cfg->param("auth.username"));
	$mailer->to($cfg->param("send.result_to"));
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
	my %command = (
		command => undef,
		reply => undef,
		hash => undef,
		);
	my @lines = split('\n',$_[0]);
	my $m_id = $_[1];
	#I need to deal with multiline commands eventually
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
				$command{"reply"} = TRUE;
			}
			when ("HASH")
			{
				$command{"hash"} = $coml[1];
			}
			default
			{
				print PUSHCOLOR RED, "Error! Invalid command",POPCOLOR;
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



if (uc $cfg->param("get.type") ne "IMAP" or uc $cfg->param("send.type") ne "SMTP")
{
	die("Right now we only support IMAP+SMTP accounts");
}

print "Connecting to..." . PUSHCOLOR GREEN;
print $cfg->param('get.server') . ":";
print $cfg->param('get.port');
print " " . POPCOLOR . "\n";


# Connect to the IMAP server via SSL
my $socket = IO::Socket::SSL->new(
	PeerAddr => $cfg->param('get.server'),
	PeerPort => $cfg->param('get.port')
   )
	or die "socket(): $@";

print "Attempting to login as ". PUSHCOLOR GREEN . $cfg->param('auth.user'). POPCOLOR ."\n";
#TODO: check to see if send or get have a different more specific username/password....
my $imap = Mail::IMAPClient->new(
   Socket   => $socket,
   User     => $cfg->param('auth.user'),
   Password => $cfg->param('auth.password'),
  )
  or die "IMAPClient::new(): $@";

	# Listing all of your folders
print "I'm authenticated\n" if $imap->IsAuthenticated();
#my @folders = $imap->folders();
#print join("\n* ", 'Folders:', @folders), "\n";

my $folder = $cfg->param("get.folder_todo");
my $msgcount = $imap->message_count($folder); 
defined($msgcount) or die "Could not message_count: $@\n";
print "We have $msgcount unread messages in ". PUSHCOLOR GREEN . $folder. POPCOLOR . "\n";

if ($msgcount > 0)
{
	#I should probably add a if !->exists then ->create thing here...
	print "Attempting to select a folder....";
	if ($imap->selectable($folder))
	{
		$imap->select($folder) or die "Could not select: $@\n"	;
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
			if ($from_full ne $cfg->param('get.from_only'))
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

