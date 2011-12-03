use strict;
use Test::More 0.87; # done_testing
use Test::LWP::MockSocket::http;
use HTTP::Body;
use SMS::Send;

my %params = (_login => "testlogin", _password => "t3s+pass");

my $test_sender = SMS::Send->new("UK::AA",
  _endpoint => "http://t/sms.cgi", %params);

{
  $LWP_Response = resp("ERR: Invalid.", my $request);

  my $response = $test_sender->send_sms(
    to => "+1234567",
    text => "test message");

  is_deeply(query($request), {
      username => $params{_login},
      password => $params{_password},
      destination => "+1234567",
      message => "test message"
  });

  ok !$response;
  ok $response =~ /ERR: Invalid/;
}

{
  # Yes, A&A do \n and \r\n mixture too
  $LWP_Response = resp("SMS message to 1234\nOK: Queued\r\n", my $request);

  my $response = $test_sender->send_sms(
    to => "+1234567",
    text => "test");

  is_deeply(query($request), {
      username => $params{_login},
      password => $params{_password},
      destination => "+1234567",
      message => "test"
  });

  ok $response;
  ok $response =~ /OK: Queued/;
}

{
  $LWP_Response = resp("OK: Sent.", my $request);

  my $response = $test_sender->send_sms(
    to => "66666666666666",
    text => "test",
    _iccid => "6666666666666666666");

  is_deeply(query($request), {
      username => $params{_login},
      password => $params{_password},
      destination => "66666666666666",
      message => "test",
      iccid   => "6666666666666666666",
  });
  ok $response;
  ok $response =~ /OK: Sent\./;
}

done_testing;

# Testing specific functions

# Set up a callback for use with Test::LWP::MockSocket::http
sub resp {
  my $data = shift;
  my $request = \$_[0];

  sub {
    $$request = $_[1] if $request;
    "HTTP/1.0 " . HTTP::Response->new(200, "OK",
      ['Content-type' => 'text/plain'],
      $data)->as_string
  }
}

# Grab the params out of a request's content
sub query {
  my($request) = @_;
  my $body = HTTP::Body->new($request->content_type, length $request->content);
  $body->add($request->content);
  return $body->param;
}
