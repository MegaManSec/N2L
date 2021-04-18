#!/usr/local/bin/perl

# N2L
#
# URN to URLs resolver for doi, hdl and ietf namespaces.
#
# Author: andy powell <a.powell@ukoln.ac.uk>
#
# $Id: N2L,v 1.6 1998/10/16 14:40:12 lisap Exp $
#
# IETF namespace resolving code based on that in draft-ietf-urn-ietf-04.txt

# External binary for Handle/DOI resolution :-(
$hdlres = "/opt/bin/hdlres";
# base and pathbase combine to form path to IETF documents for IETF resolution
my($base) = "/n/sunsite.doc.ic.ac.uk/public";
my(%pathbase) = (
  rfc => "Mirrors/ftp.isi.edu/in-notes/rfc",
  fyi => "Mirrors/ftp.isi.edu/in-notes/fyi/fyi",
  std => "Mirrors/ftp.isi.edu/in-notes/std/std",
  bcp => "Mirrors/ftp.isi.edu/in-notes/bcp/bcp"
);
my(%number2date) = (
  41 => "98apr",
  40 => "97dec", 39 => "97aug", 38 => "97apr",
  37 => "96dec", 36 => "96jun", 35 => "96mar",
  34 => "95dec", 33 => "95jul", 32 => "95apr",
  31 => "94dec", 30 => "94jul", 29 => "94mar",
  28 => "93nov", 27 => "93jul", 26 => "93mar",
  25 => "92nov", 24 => "92jul", 23 => "92mar",
  22 => "91nov", 21 => "91jul", 20 => "91mar",
  19 => "90dec" );
my($wgpath) = "/ftp/ietf";
# Host serving IETF documents
my($host) = "sunsite.doc.ic.ac.uk";



my($request);
if ($ENV{'REQUEST_METHOD'} eq "POST") {
  read(STDIN, $request, $ENV{'CONTENT_LENGTH'});
}
elsif ($ENV{'REQUEST_METHOD'} eq "GET" ) {
  $request = $ENV{'QUERY_STRING'};
}
my($accept) = $ENV{'HTTP_ACCEPT'}; #this is the "Accept:" HTTP header

# Check accept
my($type) = "plain";
$type = "uri-list" if $accept =~ /text\/uri-list/;
$type = "html" if $accept =~ /text\/html/;

my($urn) = &url_decode($request);

my($u, $nid, $nss) = split(/:/, $urn, 3);

# Simple checking of "urn:" and that there is a NSS
&urn_error("400 Bad Request", "No 'urn:' prefix") unless $u =~ /^urn$/i;
&urn_error("400 Bad Request", "No namespace specific part") unless $nss;

# Now check NID and resolve
if ($nid =~ /^doi$/i) {
  &resolve_doi($nss);
}
elsif ($nid =~ /^hdl$/i) {
  &resolve_hdl($nss);
}
elsif ($nid =~ /^ietf$/i) {
  if ($nss =~ /^(\w*):(\d*)/i) {
    &resolve_ietf1($1, $2);
  }
  elsif ($nss =~ /mtg-(\d*)-(\w*)/i) {
    &resolve_ietf2($1, $2);
  }
  else {
    &urn_error("400 Bad Request", "Unknown IETF namespace specific part format");
  }
}
elsif ($nid =~ /^isbn$/i) {
    &resolve_isbn($nss);
}
else {
  &urn_error("400 Bad Request", "Unknown namespace");
}

exit 0;

# Call external routine to resolve DOI/Handle
sub resolve_doi {
  my($doi) = @_;
  my(@urls);

  &urn_error("400 Bad Request", "Invalid DOI format")
    unless $doi =~ /\d+\.\d+\//;
  open(HDLRES, "$hdlres $doi |" )
    || &urn_error("404 Not Found", "Problem running Handle resolver");
  while (<HDLRES>) {
    push @urls, $_;
  }
  close(HDLRES);
  &urn_error("404 Not Found", "No such DOI") if ($#urls == -1);
  &url_return(@urls);
}

# Call external program to return handle
sub resolve_hdl {
  my($hdl) = @_;
  my(@urls);

  open(HDLRES, "$hdlres $hdl |" )
    || &urn_error("404 Not Found", "Problem running Handle resolver");
  while (<HDLRES>) {
    push @urls, $_;
  }
  close(HDLRES);
  &urn_error("404 Not Found", "No such Handle") if ($#urls == -1);
  &url_return(@urls);
}

# Return list of URLs in requested format
sub url_return {
  my(@urls) = @_;

  print "HTTP/1.0 200 OK\n";
  print "content-type: text/$type\n";
  print "Expires: ", &http_time(time+3600), "\n";
  print "\n";

  print "#$urn\n" if $type eq "uri-list";
  if ($type eq "uri-list" || $type eq "plain") {
    foreach (@urls) {
      print "$_\n";
    }
  }
  if ($type eq "html") {
    print <<EOF;
<HTML>
<TITLE>URN Resolution: N2L</TITLE>
</HEAD>
<BODY>
<H1>
URN Resolution: N2L
</H1>
<H2>URN: $urn</H2>
<HR>
<UL>
EOF
    foreach (@urls) {
      print "<LI><A HREF=\"$_\">$_</A>\n";
    }
    print <<EOF;
</UL>
</BODY>
</HTML>
EOF
  }
}

sub url_decode {
    local($_) = @_;
    tr/+/ /;
    s/%(..)/pack("c",hex($1))/ge;
    $_;
}

sub http_time {
    local($t) = @_;
    local(@T) = gmtime($t);
    local(@WD) = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
    local(@MO) = ( 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    sprintf "%s, %d %s %d %02d:%02d:%02d GMT",
        $WD[$T[6]],
        $T[3],
        $MO[$T[4]],
        $T[5],
        $T[2],$T[1],$T[0];
}

# Return HTTP error
sub urn_error {
  my($code, $diag) = @_; #store failure code here...
  
  print <<EOF;
HTTP/1.0 $code
Content-type: text/html

<HTML>
<HEAD>
<TITLE>URN resolution failed: $code</TITLE>
</HEAD>
<BODY>
<H2>URN to URL resolution failed</H2>
<HR>
<P>
<B>URN</B>: $urn
<BR>
EOF
  print "<B>Reason</B>: $diag\n" if $diag;
  print <<EOF;
</BODY>
</HTML>
EOF
  exit;
}

# Resolve RFCs, FYIs, STDs and BCPs
sub resolve_ietf1 {
  my($flag,@bib,$i,$k,$j,$done,@ref);
  my($l,$link);
  my($scheme, $value) = @_;
  my(@urls);
  $scheme =~ tr/A-Z/a-z/;
  &urn_error("404 Not Found", "Unknown IETF document type")if (!defined $pathbase{$scheme});
  my($try)="$base/$pathbase{$scheme}$value.txt";
  if (-f $try) {
    push(@urls, "http://$host/$pathbase{$scheme}$value.txt");
#    push(@urls, "ftp://$host/$pathbase{$scheme}$value.txt");
#    push(@urls, "gopher://$host:70/0/$pathbase{$scheme}$value.txt");
  }
  $try="$base/$pathbase{$scheme}$value.ps";
  if (-f $try) {
    push(@urls, "http://$host/$pathbase{$scheme}$value.ps");
#    push(@urls, "ftp://$host/$pathbase{$scheme}$value.ps");
#    push(@urls, "gopher://$host:70/0/$pathbase{$scheme}$value.ps");
  }
  $try="$base/$pathbase{$scheme}$value.html";
  if (-f $try) {
    push(@urls, "http://$host/$pathbase{$scheme}$value.html");
#    push(@urls, "ftp://$host/$pathbase{$scheme}$value.html");
  }

  &urn_error("404 Not Found", "No such IETF document") if ($#urls == -1);

  &url_return(@urls);
}

# Don't think this is working yet! :-(
sub resolve_ietf2 {
  my($ietfnum, $sesnam) = @_;
  my(@urls);
  &urn_error("404 Not Found\n") if (!defined $number2date{$ietfnum});
  my($date)=$number2date{$ietfnum};
  my($link)="$wgpath/$sesnam/$sesnam-minutes-$date.txt";
  if (-f $link) {
    $link=~s/^\/ftp\///;
#    my($ftplink)="ftp://$host/$link";
    my($httplink)="http://$host/$link";
    push @urls, $httplink;
#    my($glink)="gopher://$host:70/0/$link";
    &url_return(@urls);
    return;
  }
  my($link)="$wgpath/$date/$sesnam-minutes-$date.txt";
  if (-f $link) {
    $link=~s/^\/ftp\///;
#    my($ftplink)="ftp://$host/$link";
    my($httplink)="http://$host/$link";
    push @urls, $httplink;
#    my($glink)="gopher://$host:70/0/$link";
    &url_return(@urls);
    return;
  }
  &urn_error("404 Not Found\n");
}

# Resolve ISBNs using amazon.co.uk!
sub resolve_isbn {
    my ($nss) = @_;
    my (@urls);

    $nss =~ s/-//g;
    $nss = "http://www.amazon.co.uk/exec/obidos/ASIN/" . $nss . "/";
    push(@urls, $nss);
    &url_return(@urls);
}
