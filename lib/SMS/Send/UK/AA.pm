package SMS::Send::UK::AA;
# ABSTRACT: Send SMS messages using Andrews and Arnold's gateway
use strict;
use parent qw(SMS::Send::Driver);

use Carp qw(croak);
use LWP::UserAgent 6.00; # We need proper SSL support
use HTTP::Request::Common;
use URI;

use SMS::Send::UK::AA::Response;

use constant DEFAULT_ENDPOINT => "https://sms.aa.net.uk/sms.cgi";

my @supported_params = qw(
  limit sendtime replace flash report costcentre private originator udh iccid
);

sub new {
  my($class, %args) = @_;

  my $self = bless {
    _endpoint   => delete $args{_endpoint} || DEFAULT_ENDPOINT,
    _username   => delete $args{_login},
    _password   => delete $args{_password},
  }, $class;

  my $ssl_verify = exists $args{_ssl_verify} ? delete $args{_ssl_verify} : 1;
  $self->{ua} = $self->_create_ua($ssl_verify);

  for my $param(@supported_params) {
    if(exists $args{"_" . $param}) {
      $self->{"_" . $param} = delete $args{"_" . $param};
    }
  }

  if(%args) {
    croak "Unknown arguments: ", join ",", keys %args;
  }

  return $self;
}

sub send_sms {
  my $self = shift;

  # send_sms params can also be set in the constructor
  my $request = _construct_request(%$self, @_);

  my $response = $self->{ua}->request($request);
  my $okay = $response->is_success && $response->content =~ /^OK:/m;

  # This is rather yuck -- the SMS::Send API is basically true/false, I could
  # just stick the error in $@ but that seems a bit untidy, so instead return a
  # magic thing that can be false but still contain a string.
  return SMS::Send::UK::AA::Response->new($okay, $response->content);
}

sub _create_ua {
  my($self, $ssl_verify) = @_;

  my $ua = LWP::UserAgent->new;
  $ua->env_proxy;

  if($ssl_verify && URI->new($self->{_endpoint})->secure) {
    require LWP::Protocol::https;
    require CACertOrg::CA;

    $ua->ssl_opts(
      verify_hostnames => 1,
      SSL_ca_file      => CACertOrg::CA::SSL_ca_file()
    );
  }

  return $ua;
}

sub _construct_request {
  my(%params) = @_;

  my $endpoint = delete $params{_endpoint};

  my %data;
  $data{message}     = delete $params{text};
  $data{destination} = delete $params{to};

  for my $name(keys %params) {
    next unless $name =~ /^_/;
    $data{substr $name, 1} = $params{$name};
  }

  return POST $endpoint, \%data;
}

1;

__END__

=head1 SYNOPSIS

  use SMS::Send;

  my $sender = SMS::Send->new("UK::AA",
    _login    => '0123xxxxxx',
    _password => 'secret');

  my $sent = $sender->send_sms(
    text => 'y u no txt bak',
    to   => '+44 7xxx xxxxx'
  );

  if($sent) {
    say "Message successfully sent";
  }

=head1 DESCRIPTION

This is a L<SMS::Send> compatible module that sends using the UK based provider
L<Andrews and Arnold Ltd|http://aa.net.uk> (A&A). You will need a VoIP account
with A&A in order to use this module.

=head1 PARAMETERS

Certain private parmaters not part of L<SMS::Send>'s API are implemented by
this module. They all begin with an underscore (C<_>). See the A&A docs for
full details if not explained here.

=head2 Constructor parameters

=over 4

=item * _login

Must be provided, your A&A VoIP username.

=item * _password

Must be provided, password associated with the above.

=item * _endpoint

Set to the URI of an endpoint implementing this interface if a different
endpoint to the default is needed. This module defaults to
C<https://sms.aa.net.uk/sms.cgi>, if for some reason SSL doesn't work for you,
you might want to set it to the non-SSL version.

=item * _ssl_verify

Set to a false value to disable SSL verification. This will automatically be
disabled if you supply a HTTP URI above.

=back

=head2 C<send_sms> parameters

These parameters may be provided to either the constructor or the C<send_sms>
method.

=over 4

=item * _limit

Limit number of parts.

=item * _sendtime

Specify a time in the future to send the message.

=item * _replace

Replace a previous message from this originator.

=item * _flash

I<Flash> the message on the phone's screen.

=item * _report

URL or email of where to send a delivery report.

=item * _costcentre

Reported on XML bill.

=item * _private

Do not show the text on the bill.

=item * _originator

Set a specific sender.

=item * _udh

User data header, in hex.

=item * _iccid

Send to a specific SIM -- you'll also need to specify the C<to> field as this
in order for L<SMS::Send> to be happy.

=back

=head1 SEE ALSO

=over 4

=item *

L<SMS::Send>

=item *

The HTTP interface this module implements is documented here:
L<http://aa.net.uk/kb-telecoms-sms.html>.

=back
